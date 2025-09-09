const httpStatus = require('http-status');
const authService = require('../services/auth.service');
const emailService = require('../services/email.service');
const tokenService = require('../services/token.service');
const logger = require('../utils/logger');
const { metrics } = require('../utils/metrics');
const { withDbResilience } = require('../utils/serviceClient');

const authController = {
    /**
     * Register a new user
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    register: async (req, res, next) => {
        try {
            const {email, password, username, device_info} = req.body;

            // Register user with resilience
            const newUser = await withDbResilience(
                async () => authService.register({email, password, username}),
                { operationName: 'user_registration' }
            );

            // Send verification email with resilience
            if (newUser.verification_token) {
                try {
                    await withDbResilience(
                        async () => emailService.sendVerificationEmail(
                            newUser.email,
                            newUser.verification_token
                        ),
                        { 
                            operationName: 'send_verification_email',
                            fallbackKey: 'email',
                            resilienceOptions: {
                                timeout: 5000 // 이메일 전송은 더 긴 타임아웃
                            }
                        }
                    );
                } catch (emailError) {
                    // 이메일 전송 실패는 치명적이지 않으므로 로깅만 하고 계속 진행
                    logger.error('Failed to send verification email', { 
                        error: emailError.message,
                        email: newUser.email 
                    });
                }
            }

            // Record successful registration in metrics
            metrics.registrationsTotal.inc({ status: 'success' });

            // Return response
            return res.status(httpStatus.CREATED).json({
                success: true,
                data: {
                    user: {
                        id: newUser.id,
                        email: newUser.email,
                        is_verified: newUser.is_verified
                    }
                },
                message: 'Registration successful. Please verify your email.'
            });
        } catch (error) {
            // Record failed registration in metrics
            metrics.registrationsTotal.inc({ status: 'failed' });
            next(error);
        }
    },

    /**
     * Login user
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    login: async (req, res, next) => {
        try {
            const {email, password, device_info} = req.body;

            // Login user with resilience
            const {user, tokens} = await withDbResilience(
                async () => authService.login(email, password, device_info),
                { 
                    operationName: 'user_login',
                    fallbackKey: 'login'
                }
            );

            // Record successful login in metrics
            metrics.loginAttemptsTotal.inc({ status: 'success' });

            // Return response
            return res.status(httpStatus.OK).json({
                success: true,
                data: {
                    user,
                    access_token: tokens.access.token,
                    refresh_token: tokens.refresh.token,
                    expires_in: Math.floor((tokens.access.expires - new Date()) / 1000)
                },
                message: 'Login successful'
            });
        } catch (error) {
            // Record failed login in metrics
            metrics.loginAttemptsTotal.inc({ status: 'failed' });
            next(error);
        }
    },

    /**
     * Logout user
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    logout: async (req, res, next) => {
        try {
            const authHeader = req.headers.authorization;
            const accessToken = authHeader.split(' ')[1];
            const {refresh_token} = req.body;

            // Logout user with resilience
            await withDbResilience(
                async () => authService.logout(accessToken, refresh_token),
                { operationName: 'user_logout' }
            );

            // Return response
            return res.status(httpStatus.OK).json({
                success: true,
                message: 'Logout successful'
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * Refresh token
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    refreshToken: async (req, res, next) => {
        try {
            const {refresh_token} = req.body;

            // Refresh token with resilience
            const tokens = await withDbResilience(
                async () => authService.refreshAuth(refresh_token),
                { 
                    operationName: 'token_refresh',
                    fallbackKey: 'refresh_token'
                }
            );

            // Record successful token refresh in metrics
            metrics.tokenRefreshTotal.inc({ status: 'success' });

            // Return response
            return res.status(httpStatus.OK).json({
                success: true,
                data: {
                    access_token: tokens.access.token,
                    refresh_token: tokens.refresh.token,
                    expires_in: Math.floor((tokens.access.expires - new Date()) / 1000)
                },
                message: 'Token refreshed successfully'
            });
        } catch (error) {
            // Record failed token refresh in metrics
            metrics.tokenRefreshTotal.inc({ status: 'failed' });
            next(error);
        }
    },

    /**
     * Check token status
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    checkTokenStatus: async (req, res, next) => {
        try {
            const authHeader = req.headers.authorization;
            
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                return res.status(httpStatus.BAD_REQUEST).json({
                    success: false,
                    message: 'Access token is required'
                });
            }
            
            const token = authHeader.split(' ')[1];
            
            // Check token status with resilience
            const status = await withDbResilience(
                async () => tokenService.checkTokenStatus(token),
                { operationName: 'check_token_status' }
            );
            
            return res.status(httpStatus.OK).json({
                success: true,
                data: status
            });
        } catch (error) {
            next(error);
        }
    },
    
    /**
     * Proactively refresh token
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    proactiveTokenRefresh: async (req, res, next) => {
        try {
            const authHeader = req.headers.authorization;
            
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                return res.status(httpStatus.BAD_REQUEST).json({
                    success: false,
                    message: 'Access token is required'
                });
            }
            
            const token = authHeader.split(' ')[1];
            
            // Try to refresh token proactively with resilience
            const newToken = await withDbResilience(
                async () => tokenService.proactiveTokenRefresh(token),
                { operationName: 'proactive_token_refresh' }
            );
            
            if (!newToken) {
                return res.status(httpStatus.OK).json({
                    success: true,
                    data: {
                        refreshed: false,
                        message: 'Token refresh not needed'
                    }
                });
            }
            
            // Record successful proactive token refresh in metrics
            metrics.tokenRefreshTotal.inc({ status: 'success' });
            
            return res.status(httpStatus.OK).json({
                success: true,
                data: {
                    refreshed: true,
                    access_token: newToken.token,
                    expires_in: Math.floor((newToken.expires - new Date()) / 1000)
                },
                message: 'Token refreshed proactively'
            });
        } catch (error) {
            // Record failed proactive token refresh in metrics
            metrics.tokenRefreshTotal.inc({ status: 'failed' });
            next(error);
        }
    },

    /**
     * Verify email
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    verifyEmail: async (req, res, next) => {
        try {
            const {token} = req.query;

            if (!token) {
                return res.status(httpStatus.BAD_REQUEST).json({
                    success: false,
                    message: 'Verification token is required'
                });
            }

            // Verify email with resilience
            const user = await withDbResilience(
                async () => authService.verifyEmail(token),
                { operationName: 'verify_email' }
            );

            // Return response
            return res.status(httpStatus.OK).json({
                success: true,
                data: {
                    user
                },
                message: 'Email verified successfully'
            });
        } catch (error) {
            next(error);
        }
    },

    /**
     * Request password reset
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    forgotPassword: async (req, res, next) => {
        try {
            const {email} = req.body;

            if (!email) {
                return res.status(httpStatus.BAD_REQUEST).json({
                    success: false,
                    message: 'Email is required'
                });
            }

            // Request password reset with resilience
            try {
                const result = await withDbResilience(
                    async () => authService.requestPasswordReset(email),
                    { 
                        operationName: 'request_password_reset',
                        fallbackKey: 'password_reset'
                    }
                );

                // Send password reset email with resilience
                if (result.resetToken) {
                    await withDbResilience(
                        async () => emailService.sendPasswordResetEmail(
                            result.email,
                            result.resetToken
                        ),
                        { 
                            operationName: 'send_password_reset_email',
                            resilienceOptions: {
                                timeout: 5000
                            }
                        }
                    );
                }
            } catch (error) {
                // 보안을 위해 에러가 발생해도 동일한 응답 반환
                logger.error('Password reset error', { error: error.message, email });
            }

            // Return response (always the same for security)
            return res.status(httpStatus.OK).json({
                success: true,
                message: 'If your email is registered, you will receive a password reset link'
            });
        } catch (error) {
            // Return the same response even if there's an error (for security)
            return res.status(httpStatus.OK).json({
                success: true,
                message: 'If your email is registered, you will receive a password reset link'
            });
        }
    },

    /**
     * Reset password
     * @param {Object} req - Express request object
     * @param {Object} res - Express response object
     * @param {Function} next - Express next function
     */
    resetPassword: async (req, res, next) => {
        try {
            const {token, password} = req.body;

            if (!token || !password) {
                return res.status(httpStatus.BAD_REQUEST).json({
                    success: false,
                    message: 'Token and password are required'
                });
            }

            // Reset password with resilience
            const user = await withDbResilience(
                async () => authService.resetPassword(token, password),
                { operationName: 'reset_password' }
            );

            // Return response
            return res.status(httpStatus.OK).json({
                success: true,
                data: {
                    user
                },
                message: 'Password reset successfully'
            });
        } catch (error) {
            next(error);
        }
    }
};

module.exports = authController;
