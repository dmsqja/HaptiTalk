const jwt = require('jsonwebtoken');
const {v4: uuidv4} = require('uuid');
const JWT_CONFIG = require('../config/jwt');
const {redisHelpers} = require('../config/redis');
const logger = require('../utils/logger');

const tokenService = {
    /**
     * Generate access and refresh tokens
     * @param {Object} user - User object
     * @returns {Object} - Access and refresh tokens with expiration
     */
    generateAuthTokens: async (user) => {
        try {
            // Generate token payloads
            const tokenPayload = {
                sub: user.id,
                email: user.email,
                type: 'access',
                kid: process.env.JWT_APP_KEY_ID
            };

            const refreshTokenId = uuidv4();
            const refreshPayload = {
                sub: user.id,
                jti: refreshTokenId, // JWT ID for token identification
                type: 'refresh'
            };

            // Generate JWT tokens with kid in header
            const accessToken = jwt.sign(
                tokenPayload,
                JWT_CONFIG.ACCESS_TOKEN.SECRET,
                {
                    expiresIn: JWT_CONFIG.ACCESS_TOKEN.EXPIRES_IN,
                    header: {
                        kid: process.env.JWT_APP_KEY_ID
                    }
                }
            );

            const refreshToken = jwt.sign(
                refreshPayload,
                JWT_CONFIG.REFRESH_TOKEN.SECRET,
                {
                    expiresIn: JWT_CONFIG.REFRESH_TOKEN.EXPIRES_IN,
                    header: {
                        kid: process.env.JWT_APP_KEY_ID
                    }
                }
            );

            // Decode tokens to get expiration time
            const decodedAccess = jwt.decode(accessToken);
            const decodedRefresh = jwt.decode(refreshToken);

            // Store refresh token in Redis
            const refreshExpirySeconds = Math.floor(decodedRefresh.exp - decodedRefresh.iat);
            await redisHelpers.storeRefreshToken(refreshTokenId, user.id, refreshExpirySeconds);

            // Store access token metadata for refresh optimization
            await redisHelpers.storeTokenMetadata(accessToken, {
                userId: user.id,
                refreshTokenId,
                createdAt: decodedAccess.iat,
                expiresAt: decodedAccess.exp
            });

            logger.info(`인증 토큰 생성 성공: ${user.id}`, {
                userId: user.id,
                email: user.email,
                accessTokenExpiresAt: new Date(decodedAccess.exp * 1000),
                refreshTokenExpiresAt: new Date(decodedRefresh.exp * 1000)
            });

            return {
                access: {
                    token: accessToken,
                    expires: new Date(decodedAccess.exp * 1000)
                },
                refresh: {
                    token: refreshToken,
                    expires: new Date(decodedRefresh.exp * 1000)
                }
            };
        } catch (error) {
            logger.error('Error generating auth tokens:', error);
            throw new Error('Failed to generate authentication tokens');
        }
    },

    /**
     * Generate session token for real-time connections
     * @param {string} userId - User ID
     * @param {string} sessionId - Session ID
     * @returns {Object} - Session token with expiration
     */
    generateSessionToken: (userId, sessionId) => {
        try {
            const payload = {
                sub: userId,
                session: sessionId,
                type: 'session'
            };

            const sessionToken = jwt.sign(
                payload,
                JWT_CONFIG.SESSION_TOKEN.SECRET,
                {
                    expiresIn: JWT_CONFIG.SESSION_TOKEN.EXPIRES_IN,
                    header: {
                        kid: process.env.JWT_APP_KEY_ID
                    }
                }
            );

            const decoded = jwt.decode(sessionToken);

            logger.info(`세션 토큰 생성 성공: ${userId}`, {
                userId,
                sessionId,
                expiresAt: new Date(decoded.exp * 1000)
            });

            return {
                token: sessionToken,
                expires: new Date(decoded.exp * 1000)
            };
        } catch (error) {
            logger.error('Error generating session token:', error);
            throw new Error('Failed to generate session token');
        }
    },

    /**
     * Verify access token
     * @param {string} token - JWT token
     * @param {boolean} allowExpiringSoon - Whether to allow token that is expiring soon
     * @returns {Object} - Decoded token payload and token status
     */
    verifyAccessToken: async (token, allowExpiringSoon = false) => {
        try {
            // Check if token is blacklisted
            const isBlacklisted = await redisHelpers.isTokenBlacklisted(token);
            if (isBlacklisted) {
                throw new Error('Token has been revoked');
            }

            // Decode token without verification to check expiration
            const decoded = jwt.decode(token);
            if (!decoded) {
                throw new Error('Invalid token format');
            }

            const now = Math.floor(Date.now() / 1000);
            const timeUntilExpiry = decoded.exp - now;
            
            // Calculate if token is expiring soon (less than 5 minutes)
            const isExpiringSoon = timeUntilExpiry > 0 && timeUntilExpiry < 300;

            if (isExpiringSoon && !allowExpiringSoon) {
                // Return payload but with expiringSoon flag
                return {
                    payload: decoded,
                    status: 'expiring_soon',
                    expiresIn: timeUntilExpiry
                };
            }

            // Verify token with JWT library
            const verified = jwt.verify(token, JWT_CONFIG.ACCESS_TOKEN.SECRET);
            
            logger.debug(`액세스 토큰 검증 성공: ${verified.sub}`, {
                userId: verified.sub,
                status: 'valid',
                expiresIn: timeUntilExpiry
            });
            
            return {
                payload: verified,
                status: 'valid',
                expiresIn: timeUntilExpiry
            };
        } catch (error) {
            if (error.name === 'JsonWebTokenError') {
                throw new Error('Invalid token');
            } else if (error.name === 'TokenExpiredError') {
                throw new Error('Token expired');
            }
            throw error;
        }
    },

    /**
     * Check if token is expiring soon
     * @param {string} token - JWT token
     * @returns {Object} - Status information
     */
    checkTokenStatus: async (token) => {
        try {
            // Decode token without verification
            const decoded = jwt.decode(token);
            if (!decoded) {
                return { 
                    valid: false, 
                    status: 'invalid',
                    message: 'Invalid token format'
                };
            }

            const now = Math.floor(Date.now() / 1000);
            
            // Check if already expired
            if (decoded.exp <= now) {
                return { 
                    valid: false, 
                    status: 'expired',
                    message: 'Token has expired' 
                };
            }

            // Check if expiring soon (less than 5 minutes)
            const timeUntilExpiry = decoded.exp - now;
            const isExpiringSoon = timeUntilExpiry < 300;

            if (isExpiringSoon) {
                return { 
                    valid: true, 
                    status: 'expiring_soon',
                    expiresIn: timeUntilExpiry,
                    message: 'Token is expiring soon' 
                };
            }

            return { 
                valid: true, 
                status: 'valid',
                expiresIn: timeUntilExpiry,
                message: 'Token is valid' 
            };
        } catch (error) {
            logger.error('Error checking token status:', error);
            return { 
                valid: false, 
                status: 'error',
                message: 'Error checking token' 
            };
        }
    },

    /**
     * Verify refresh token
     * @param {string} token - JWT refresh token
     * @returns {Object} - Decoded token payload
     */
    verifyRefreshToken: async (token) => {
        try {
            const decoded = jwt.verify(token, JWT_CONFIG.REFRESH_TOKEN.SECRET);

            // Check if token type is refresh
            if (decoded.type !== 'refresh') {
                throw new Error('Invalid token type');
            }

            // Check if token exists in Redis
            const userId = await redisHelpers.getUserIdFromRefreshToken(decoded.jti);
            if (!userId) {
                throw new Error('Token not found or expired');
            }

            // Verify that the token belongs to the user
            if (userId !== decoded.sub) {
                throw new Error('Token does not match user');
            }

            logger.debug(`리프레시 토큰 검증 성공: ${decoded.sub}`, {
                userId: decoded.sub,
                tokenId: decoded.jti
            });

            return decoded;
        } catch (error) {
            if (error.name === 'JsonWebTokenError') {
                throw new Error('Invalid token');
            } else if (error.name === 'TokenExpiredError') {
                throw new Error('Token expired');
            }
            throw error;
        }
    },

    /**
     * Verify session token
     * @param {string} token - JWT session token
     * @returns {Object} - Decoded token payload
     */
    verifySessionToken: (token) => {
        try {
            const decoded = jwt.verify(token, JWT_CONFIG.SESSION_TOKEN.SECRET);

            // Check if token type is session
            if (decoded.type !== 'session') {
                throw new Error('Invalid token type');
            }

            logger.debug(`세션 토큰 검증 성공: ${decoded.sub}`, {
                userId: decoded.sub,
                sessionId: decoded.session
            });

            return decoded;
        } catch (error) {
            if (error.name === 'JsonWebTokenError') {
                throw new Error('Invalid token');
            } else if (error.name === 'TokenExpiredError') {
                throw new Error('Token expired');
            }
            throw error;
        }
    },

    /**
     * Revoke access token (add to blacklist)
     * @param {string} token - JWT token
     */
    revokeAccessToken: async (token) => {
        try {
            const decoded = jwt.decode(token);
            if (!decoded) {
                throw new Error('Invalid token');
            }

            // Add token to blacklist in Redis
            await redisHelpers.blacklistToken(token, decoded.exp);
            
            // Remove token metadata
            await redisHelpers.removeTokenMetadata(token);

            logger.info(`액세스 토큰 폐기 성공: ${decoded.sub}`, {
                userId: decoded.sub,
                tokenType: decoded.type
            });
        } catch (error) {
            logger.error('Error revoking access token:', error);
            throw error;
        }
    },

    /**
     * Revoke refresh token
     * @param {string} token - JWT refresh token
     */
    revokeRefreshToken: async (token) => {
        try {
            const decoded = jwt.decode(token);
            if (!decoded || !decoded.jti) {
                throw new Error('Invalid token');
            }

            // Remove refresh token from Redis
            await redisHelpers.removeRefreshToken(decoded.jti);

            logger.info(`리프레시 토큰 폐기 성공: ${decoded.sub}`, {
                userId: decoded.sub,
                tokenId: decoded.jti
            });
        } catch (error) {
            logger.error('Error revoking refresh token:', error);
            throw error;
        }
    },
    
    /**
     * Proactively refresh an access token that's about to expire
     * @param {string} accessToken - Current access token
     * @returns {Object} - New access token information or null if not needed
     */
    proactiveTokenRefresh: async (accessToken) => {
        try {
            const status = await tokenService.checkTokenStatus(accessToken);
            
            // Only refresh if token is expiring soon but still valid
            if (status.status !== 'expiring_soon') {
                return null;
            }
            
            // Get token metadata from Redis
            const metadata = await redisHelpers.getTokenMetadata(accessToken);
            if (!metadata) {
                return null;
            }
            
            // Get user info
            const user = { id: metadata.userId };
            
            // Generate a new access token only
            const tokenPayload = {
                sub: user.id,
                email: user.email,
                type: 'access'
            };
            
            const newAccessToken = jwt.sign(
                tokenPayload,
                JWT_CONFIG.ACCESS_TOKEN.SECRET,
                {
                    expiresIn: JWT_CONFIG.ACCESS_TOKEN.EXPIRES_IN,
                    header: {
                        kid: process.env.JWT_APP_KEY_ID
                    }
                }
            );
            
            const decodedAccess = jwt.decode(newAccessToken);
            
            // Store new token metadata
            await redisHelpers.storeTokenMetadata(newAccessToken, {
                userId: user.id,
                refreshTokenId: metadata.refreshTokenId,
                createdAt: decodedAccess.iat,
                expiresAt: decodedAccess.exp
            });
            
            // Blacklist the old token
            await redisHelpers.blacklistToken(accessToken, jwt.decode(accessToken).exp);
            
            logger.info(`토큰 사전 갱신 성공: ${user.id}`, {
                userId: user.id,
                newTokenExpiresAt: new Date(decodedAccess.exp * 1000)
            });
            
            return {
                token: newAccessToken,
                expires: new Date(decodedAccess.exp * 1000)
            };
        } catch (error) {
            logger.error('Error in proactive token refresh:', error);
            return null;
        }
    }
};

module.exports = tokenService;