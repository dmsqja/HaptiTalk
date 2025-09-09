const {validationResult, body} = require('express-validator');
const httpStatus = require('http-status');

// Validation middleware
const validate = (schemas) => {
    return async (req, res, next) => {
        await Promise.all(schemas.map(schema => schema.run(req)));

        const errors = validationResult(req);
        if (errors.isEmpty()) {
            return next();
        }

        const formattedErrors = errors.array().map(error => ({
            field: error.param,
            message: error.msg
        }));

        return res.status(httpStatus.UNPROCESSABLE_ENTITY).json({
            success: false,
            message: 'Validation Error',
            errors: formattedErrors
        });
    };
};

// Auth validation schemas
const authValidation = {
    register: [
        body('email')
            .isEmail().withMessage('Email must be a valid email address')
            .normalizeEmail()
            .trim(),
        body('password')
            .isLength({min: 8}).withMessage('Password must be at least 8 characters long')
            .matches(/\d/).withMessage('Password must contain at least one number')
            .matches(/[a-zA-Z]/).withMessage('Password must contain at least one letter'),
        body('username')
            .optional()
            .isLength({min: 2, max: 50}).withMessage('Username must be between 2-50 characters')
            .trim(),
        body('device_info')
            .optional()
            .isObject().withMessage('Device info must be an object')
    ],

    login: [
        body('email')
            .isEmail().withMessage('Email must be a valid email address')
            .normalizeEmail()
            .trim(),
        body('password')
            .isLength({min: 1}).withMessage('Password is required'),
        body('device_info')
            .optional()
            .isObject().withMessage('Device info must be an object')
    ],

    refreshToken: [
        body('refresh_token')
            .isString().withMessage('Refresh token is required')
            .notEmpty().withMessage('Refresh token cannot be empty')
    ]
};

// 서비스 인증 유효성 검사 스키마
const serviceAuthValidation = {
    generateToken: [
        body('serviceId')
            .isString().withMessage('서비스 ID는 문자열이어야 합니다')
            .notEmpty().withMessage('서비스 ID는 필수입니다'),
        body('serviceSecret')
            .isString().withMessage('서비스 비밀키는 문자열이어야 합니다')
            .notEmpty().withMessage('서비스 비밀키는 필수입니다')
    ],

    verifyToken: [
        body('token')
            .isString().withMessage('토큰은 문자열이어야 합니다')
            .notEmpty().withMessage('토큰은 필수입니다')
    ],

    revokeToken: [
        body('token')
            .isString().withMessage('토큰은 문자열이어야 합니다')
            .notEmpty().withMessage('토큰은 필수입니다')
    ]
};

// Device validation schemas
const deviceValidation = {
    registerDevice: [
        body('device_type')
            .isIn(['mobile', 'watch', 'tablet']).withMessage('Device type must be mobile, watch, or tablet'),
        body('device_token')
            .optional()
            .isString().withMessage('Device token must be a string'),
        body('device_name')
            .optional()
            .isString().withMessage('Device name must be a string')
            .isLength({max: 100}).withMessage('Device name must be at most 100 characters'),
        body('device_model')
            .optional()
            .isString().withMessage('Device model must be a string')
            .isLength({max: 100}).withMessage('Device model must be at most 100 characters'),
        body('os_version')
            .optional()
            .isString().withMessage('OS version must be a string')
            .isLength({max: 50}).withMessage('OS version must be at most 50 characters'),
        body('app_version')
            .optional()
            .isString().withMessage('App version must be a string')
            .isLength({max: 50}).withMessage('App version must be at most 50 characters'),
        body('is_watch')
            .optional()
            .isBoolean().withMessage('Is watch flag must be a boolean'),
        body('paired_device_id')
            .optional()
            .isUUID(4).withMessage('Paired device ID must be a valid UUID v4')
    ],

    updateDevice: [
        body('device_name')
            .optional()
            .isString().withMessage('Device name must be a string')
            .isLength({max: 100}).withMessage('Device name must be at most 100 characters'),
        body('device_token')
            .optional()
            .isString().withMessage('Device token must be a string'),
        body('os_version')
            .optional()
            .isString().withMessage('OS version must be a string')
            .isLength({max: 50}).withMessage('OS version must be at most 50 characters'),
        body('app_version')
            .optional()
            .isString().withMessage('App version must be a string')
            .isLength({max: 50}).withMessage('App version must be at most 50 characters')
    ],

    pairDevices: [
        body('watch_device_id')
            .isUUID(4).withMessage('Watch device ID must be a valid UUID v4')
    ]
};

module.exports = {
    validate,
    authValidation,
    serviceAuthValidation,
    deviceValidation
};