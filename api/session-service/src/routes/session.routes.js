const express = require('express');
const {body, param, query} = require('express-validator');
const sessionController = require('../controllers/session.controller');
const authMiddleware = require('../middleware/auth.middleware');
const validationMiddleware = require('../middleware/validation.middleware');
const {SESSION_TYPES} = require('../models/session.model');

const router = express.Router();

/**
 * 세션 라우트 정의
 */

/**
 * @route POST /api/v1/sessions/validate
 * @desc 세션 유효성 검증 (서비스 간 통신용)
 * @access Service
 */
router.post(
    '/validate',
    authMiddleware.validateServiceToken, // 서비스 토큰 검증
    [
        body('sessionId').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        body('userId').isUUID(4).withMessage('유효한 사용자 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.validateSession
);

/**
 * @route POST /api/v1/sessions
 * @desc 새 세션 생성 (사용자 요청 및 서비스 간 통신 모두 지원)
 * @access Private or Service
 */
router.post(
    '/',
    // 서비스 토큰 또는 JWT 토큰 둘 다 허용
    (req, res, next) => {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: '인증 토큰이 필요합니다.'
            });
        }
        
        const token = authHeader.split(' ')[1];
        const serviceToken = process.env.INTER_SERVICE_TOKEN || 'default-service-token';
        
        // 서비스 토큰인 경우
        if (token === serviceToken) {
            return authMiddleware.validateServiceToken(req, res, next);
        } else {
            // JWT 토큰인 경우
            return authMiddleware.verifyToken(req, res, next);
        }
    },
    [
        body('title').isString().notEmpty().withMessage('세션 제목은 필수입니다'),
        body('type').isIn(Object.values(SESSION_TYPES)).withMessage('유효한 세션 타입이 아닙니다'),
        body('custom_settings').optional().isObject().withMessage('세션 설정은 객체 형태여야 합니다')
    ],
    validationMiddleware.validate,
    sessionController.createSession
);

/**
 * @route GET /api/v1/sessions
 * @desc 사용자의 세션 목록 조회
 * @access Private
 */
router.get(
    '/',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        query('status').optional().isString().withMessage('유효한 상태 값이 아닙니다'),
        query('type').optional().isIn(Object.values(SESSION_TYPES)).withMessage('유효한 세션 타입이 아닙니다'),
        query('limit').optional().isInt({min: 1, max: 100}).withMessage('limit은 1-100 사이의 정수여야 합니다'),
        query('offset').optional().isInt({min: 0}).withMessage('offset은 0 이상의 정수여야 합니다'),
        query('sort').optional().isString().withMessage('정렬 필드는 문자열이어야 합니다'),
        query('order').optional().isIn(['ASC', 'DESC']).withMessage('정렬 순서는 ASC 또는 DESC여야 합니다')
    ],
    validationMiddleware.validate,
    sessionController.getUserSessions
);

/**
 * @route GET /api/v1/sessions/:id
 * @desc 세션 상세 정보 조회
 * @access Private or Service
 */
router.get(
    '/:id',
    // 서비스 토큰 또는 JWT 토큰 둘 다 허용
    (req, res, next) => {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: '인증 토큰이 필요합니다.'
            });
        }
        
        const token = authHeader.split(' ')[1];
        const serviceToken = process.env.INTER_SERVICE_TOKEN || 'default-service-token';
        
        // 서비스 토큰인 경우
        if (token === serviceToken) {
            return authMiddleware.validateServiceToken(req, res, next);
        } else {
            // JWT 토큰인 경우
            return authMiddleware.verifyToken(req, res, next);
        }
    },
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.getSession
);

/**
 * @route PUT /api/v1/sessions/:id
 * @desc 세션 정보 업데이트
 * @access Private
 */
router.put(
    '/:id',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        body('title').optional().isString().withMessage('세션 제목은 문자열이어야 합니다'),
        body('status').optional().isString().withMessage('세션 상태는 문자열이어야 합니다'),
        body('settings').optional().isObject().withMessage('세션 설정은 객체 형태여야 합니다'),
        body('metadata').optional().isObject().withMessage('세션 메타데이터는 객체 형태여야 합니다'),
        validationMiddleware.validate
    ],
    sessionController.updateSession
);

/**
 * @route POST /api/v1/sessions/:id/end
 * @desc 세션 종료
 * @access Private
 */
router.post(
    '/:id/end',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        body('summary').optional().isObject().withMessage('세션 요약은 객체 형태여야 합니다'),
        validationMiddleware.validate
    ],
    sessionController.endSession
);

/**
 * @route PUT /api/v1/sessions/:id/summary
 * @desc 세션 요약 정보 업데이트
 * @access Private
 */
router.put(
    '/:id/summary',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        body('summary').isObject().withMessage('세션 요약은 객체 형태여야 합니다'),
        validationMiddleware.validate
    ],
    sessionController.updateSummary
);

/**
 * @route POST /api/v1/sessions/:id/timer/setup
 * @desc 발표 타이머 설정
 * @access Private
 */
router.post(
    '/:id/timer/setup',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        body('duration_minutes').optional().isInt({min: 1, max: 180}).withMessage('발표 시간은 1-180분 사이여야 합니다'),
        body('alerts').optional().isObject().withMessage('알림 설정은 객체 형태여야 합니다'),
        validationMiddleware.validate
    ],
    sessionController.setupTimer
);

/**
 * @route POST /api/v1/sessions/:id/timer/start
 * @desc 타이머 시작
 * @access Private
 */
router.post(
    '/:id/timer/start',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.startTimer
);

/**
 * @route POST /api/v1/sessions/:id/timer/pause
 * @desc 타이머 일시 중지
 * @access Private
 */
router.post(
    '/:id/timer/pause',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.pauseTimer
);

/**
 * @route POST /api/v1/sessions/:id/timer/resume
 * @desc 타이머 재개
 * @access Private
 */
router.post(
    '/:id/timer/resume',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.resumeTimer
);

/**
 * @route POST /api/v1/sessions/:id/timer/reset
 * @desc 타이머 리셋
 * @access Private
 */
router.post(
    '/:id/timer/reset',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.resetTimer
);

/**
 * @route GET /api/v1/sessions/:id/timer
 * @desc 타이머 상태 조회
 * @access Private
 */
router.get(
    '/:id/timer',
    authMiddleware.verifyToken, // JWT 토큰 검증 추가
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.getTimerStatus
);

/**
 * @route GET /api/v1/sessions/:id/status
 * @desc 세션 상태 조회
 * @access Private or Service
 */
router.get(
    '/:id/status',
    // 서비스 토큰 또는 JWT 토큰 둘 다 허용
    (req, res, next) => {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: '인증 토큰이 필요합니다.'
            });
        }
        
        const token = authHeader.split(' ')[1];
        const serviceToken = process.env.INTER_SERVICE_TOKEN || 'default-service-token';
        
        // 서비스 토큰인 경우
        if (token === serviceToken) {
            return authMiddleware.validateServiceToken(req, res, next);
        } else {
            // JWT 토큰인 경우
            return authMiddleware.verifyToken(req, res, next);
        }
    },
    [
        param('id').isUUID(4).withMessage('유효한 세션 ID가 아닙니다'),
        validationMiddleware.validate
    ],
    sessionController.getSessionStatus
);

module.exports = router;