const httpStatus = require('http-status');
const User = require('../models/user.model');
const tokenService = require('./token.service');
const logger = require('../utils/logger');
const {v4: uuidv4} = require('uuid');
const axios = require('axios'); // User Service API 호출용

const MAX_LOGIN_ATTEMPTS = 5;
const LOCK_TIME_MINUTES = 30;

// User Service URL 설정
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:3004';

const authService = {
    /**
     * Register a new user
     * @param {Object} userData - User registration data
     * @returns {Object} - Created user object
     */
    register: async (userData) => {
        try {
            // Check if user with email already exists
            const existingUser = await User.findByEmail(userData.email);
            if (existingUser) {
                logger.warn(`회원가입 실패 - 이미 등록된 이메일: ${userData.email}`);
                const error = new Error('Email already registered');
                error.statusCode = httpStatus.CONFLICT;
                throw error;
            }

            // Create verification token
            const verificationToken = uuidv4();

            // Create new user
            const user = await User.create({
                email: userData.email,
                password_hash: userData.password,
                verification_token: verificationToken,
                is_active: true,
                is_verified: false
            });

            logger.info(`회원가입 성공: ${userData.email} (ID: ${user.id})`);

            // User Service에 프로필 생성 요청
            try {
                await createUserProfile(user.id, userData.email, userData.username);
                logger.info(`프로필 생성 성공: ${userData.email} (ID: ${user.id})`);
            } catch (profileError) {
                logger.error(`프로필 생성 실패: ${userData.email} (ID: ${user.id})`, {
                    error: profileError.message
                });
                // 프로필 생성 실패는 치명적이지 않으므로 회원가입은 계속 진행
            }

            return {
                id: user.id,
                email: user.email,
                is_verified: user.is_verified,
                verification_token: user.verification_token
            };
        } catch (error) {
            logger.error('Error registering user:', error);
            throw error;
        }
    },

    /**
     * Login with email and password
     * @param {string} email - User email
     * @param {string} password - User password
     * @param {Object} deviceInfo - User device information
     * @returns {Object} - User object and tokens
     */
    login: async (email, password, deviceInfo) => {
        try {
            // Find user by email
            const user = await User.findByEmail(email);
            if (!user) {
                logger.warn(`로그인 실패 - 존재하지 않는 이메일: ${email}`);
                const error = new Error('Invalid email or password');
                error.statusCode = httpStatus.UNAUTHORIZED;
                throw error;
            }

            // Check if account is locked
            if (user.locked_until && user.locked_until > new Date()) {
                logger.warn(`로그인 실패 - 계정 잠금: ${email} (잠금 해제: ${user.locked_until})`);
                const error = new Error('Account is locked. Try again later');
                error.statusCode = httpStatus.FORBIDDEN;
                error.lockUntil = user.locked_until;
                throw error;
            }

            // Verify password
            const isPasswordValid = await user.validPassword(password);
            if (!isPasswordValid) {
                // Increment login attempts
                await User.incrementLoginAttempts(user.id);

                // Check if account should be locked
                if (user.login_attempts + 1 >= MAX_LOGIN_ATTEMPTS) {
                    await User.lockAccount(user.id, LOCK_TIME_MINUTES);
                    logger.warn(`계정 잠금 처리: ${email} (로그인 시도 횟수 초과)`);
                    const error = new Error(`Account locked due to too many failed attempts. Try again after ${LOCK_TIME_MINUTES} minutes`);
                    error.statusCode = httpStatus.FORBIDDEN;
                    throw error;
                }

                logger.warn(`로그인 실패 - 잘못된 비밀번호: ${email} (시도 횟수: ${user.login_attempts + 1})`);
                const error = new Error('Invalid email or password');
                error.statusCode = httpStatus.UNAUTHORIZED;
                throw error;
            }

            // Password is valid, reset login attempts
            await User.resetLoginAttempts(user.id);

            // Update last login timestamp
            await user.update({last_login: new Date()});

            // Generate auth tokens
            const tokens = await tokenService.generateAuthTokens(user);

            logger.info(`로그인 성공: ${email} (ID: ${user.id})`, {
                userId: user.id,
                deviceInfo: deviceInfo ? {
                    type: deviceInfo.type,
                    os: deviceInfo.os,
                    browser: deviceInfo.browser
                } : null,
                lastLogin: user.last_login
            });

            return {
                user: {
                    id: user.id,
                    email: user.email,
                    is_verified: user.is_verified
                },
                tokens
            };
        } catch (error) {
            logger.error('Error during login:', error);
            throw error;
        }
    },

    /**
     * Logout user
     * @param {string} accessToken - JWT access token
     * @param {string} refreshToken - JWT refresh token
     */
    logout: async (accessToken, refreshToken) => {
        try {
            // Revoke tokens
            await Promise.all([
                tokenService.revokeAccessToken(accessToken),
                tokenService.revokeRefreshToken(refreshToken)
            ]);

            logger.info('로그아웃 성공', {
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logger.error('Error during logout:', error);
            throw error;
        }
    },

    /**
     * Refresh auth tokens
     * @param {string} refreshToken - JWT refresh token
     * @returns {Object} - New access and refresh tokens
     */
    refreshAuth: async (refreshToken) => {
        try {
            // Verify refresh token
            const refreshTokenPayload = await tokenService.verifyRefreshToken(refreshToken);

            // Get user
            const user = await User.findByPk(refreshTokenPayload.sub);
            if (!user) {
                throw new Error('User not found');
            }

            // Revoke old refresh token
            await tokenService.revokeRefreshToken(refreshToken);

            // Generate new tokens
            const tokens = await tokenService.generateAuthTokens(user);

            logger.info(`토큰 갱신 성공: ${user.email} (ID: ${user.id})`);

            return tokens;
        } catch (error) {
            logger.error('Error refreshing auth:', error);
            throw error;
        }
    },

    /**
     * Verify email
     * @param {string} verificationToken - Email verification token
     * @returns {Object} - Updated user
     */
    verifyEmail: async (verificationToken) => {
        try {
            // Find user with verification token
            const user = await User.findOne({where: {verification_token: verificationToken}});
            if (!user) {
                logger.warn(`이메일 인증 실패 - 유효하지 않은 토큰: ${verificationToken}`);
                const error = new Error('Invalid or expired verification token');
                error.statusCode = httpStatus.BAD_REQUEST;
                throw error;
            }

            // Update user
            await user.update({
                is_verified: true,
                verification_token: null
            });

            logger.info(`이메일 인증 성공: ${user.email} (ID: ${user.id})`);

            return {
                id: user.id,
                email: user.email,
                is_verified: true
            };
        } catch (error) {
            logger.error('Error verifying email:', error);
            throw error;
        }
    },

    /**
     * Request password reset
     * @param {string} email - User email
     * @returns {Object} - Reset token info
     */
    requestPasswordReset: async (email) => {
        try {
            // Find user by email
            const user = await User.findByEmail(email);
            if (!user) {
                logger.info(`비밀번호 재설정 요청 - 존재하지 않는 이메일: ${email}`);
                // For security, don't reveal that email doesn't exist
                return {message: 'If your email is registered, you will receive a password reset link'};
            }

            // Generate reset token
            const resetToken = uuidv4();
            const resetTokenExpires = new Date(Date.now() + 3600000); // 1 hour

            // Update user
            await user.update({
                reset_token: resetToken,
                reset_token_expires_at: resetTokenExpires
            });

            logger.info(`비밀번호 재설정 토큰 생성: ${email}`, {
                userId: user.id,
                expiresAt: resetTokenExpires
            });

            return {
                email: user.email,
                resetToken,
                expiresAt: resetTokenExpires
            };
        } catch (error) {
            logger.error('Error requesting password reset:', error);
            throw error;
        }
    },

    /**
     * Reset password
     * @param {string} resetToken - Password reset token
     * @param {string} newPassword - New password
     * @returns {Object} - Updated user
     */
    resetPassword: async (resetToken, newPassword) => {
        try {
            // Find user with reset token
            const user = await User.findOne({
                where: {
                    reset_token: resetToken,
                    reset_token_expires_at: {[User.Op.gt]: new Date()}
                }
            });

            if (!user) {
                logger.warn(`비밀번호 재설정 실패 - 유효하지 않은 토큰: ${resetToken}`);
                const error = new Error('Invalid or expired reset token');
                error.statusCode = httpStatus.BAD_REQUEST;
                throw error;
            }

            // Update user password
            await user.update({
                password_hash: newPassword,
                reset_token: null,
                reset_token_expires_at: null,
                login_attempts: 0,
                locked_until: null
            });

            logger.info(`비밀번호 재설정 성공: ${user.email} (ID: ${user.id})`);

            return {
                id: user.id,
                email: user.email
            };
        } catch (error) {
            logger.error('Error resetting password:', error);
            throw error;
        }
    }
};

/**
 * User Service에 프로필 생성 요청
 * @param {string} userId - 사용자 ID
 * @param {string} email - 사용자 이메일
 */
const createUserProfile = async (userId, email, username) => {
    try {
        const response = await axios.post(`${USER_SERVICE_URL}/api/v1/users/profile/create`, {
            userId: userId,
            email: email,
            username: username
        }, {
            timeout: 5000, // 5초 타임아웃
            headers: {
                'Content-Type': 'application/json',
                'X-Service-Name': 'auth-service'
            }
        });
        
        if (response.status === 200 || response.status === 201) {
            return response.data;
        } else {
            throw new Error(`User Service API 응답 오류: ${response.status}`);
        }
    } catch (error) {
        if (error.code === 'ECONNREFUSED') {
            throw new Error('User Service에 연결할 수 없습니다');
        } else if (error.code === 'ENOTFOUND') {
            throw new Error('User Service 호스트를 찾을 수 없습니다');
        } else if (error.response) {
            throw new Error(`User Service API 오류: ${error.response.status} - ${error.response.data?.message || error.response.statusText}`);
        } else {
            throw new Error(`User Service 호출 실패: ${error.message}`);
        }
    }
};

module.exports = authService;