const httpStatus = require('http-status');
const sessionService = require('../services/session.service');
const timerService = require('../services/timer.service');
const logger = require('../utils/logger');
const { withMongoResilience, withRedisResilience } = require('../utils/serviceClient');

/**
 * 세션 컨트롤러
 * 세션 관련 API 엔드포인트 핸들러 구현
 */
const sessionController = {
    /**
     * 세션 생성
     * POST /api/v1/sessions
     */
    createSession: async (req, res, next) => {
        try {
            const {title, type, custom_settings, device_info, location, participants, tags, id, user_id} = req.body;

            // 사용자 ID 결정 (서비스 요청 vs 사용자 요청)
            let sessionUserId;
            if (req.isServiceRequest) {
                // 서비스 간 통신의 경우 body에서 user_id 사용
                if (!user_id) {
                    return res.status(httpStatus.BAD_REQUEST).json({
                        success: false,
                        message: '서비스 요청 시 user_id가 필요합니다.'
                    });
                }
                sessionUserId = user_id;
            } else {
                // JWT 인증 미들웨어에서 설정한 사용자 ID 가져오기
                sessionUserId = req.user.id;
            }

            // 세션 생성 서비스 호출 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.createSession({
                    user_id: sessionUserId,
                    title,
                    type,
                    custom_settings,
                    device_info,
                    location,
                    participants,
                    tags,
                    id  // 서비스에서 전달한 특정 ID 사용 (있는 경우)
                }),
                { operationName: 'create_session' }
            );

            res.status(httpStatus.CREATED).json({
                success: true,
                data: {
                    id: session.id,
                    title: session.title,
                    type: session.type,
                    status: session.status,
                    created_at: session.created_at
                },
                message: '세션이 성공적으로 생성되었습니다.'
            });
        } catch (error) {
            logger.error('Session creation error:', error);
            next(error);
        }
    },

    /**
     * 세션 정보 조회
     * GET /api/v1/sessions/:id
     */
    getSession: async (req, res, next) => {
        try {
            const {id} = req.params;

            // 세션 조회 서비스 호출 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { 
                    operationName: 'get_session',
                    fallbackKey: 'getSession'
                }
            );

            // 사용자 권한 확인 (본인의 세션만 조회 가능 - 서비스 요청 제외)
            if (!req.isServiceRequest && session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션에 접근할 권한이 없습니다.'
                });
            }

            res.status(httpStatus.OK).json({
                success: true,
                data: session
            });
        } catch (error) {
            logger.error(`Get session error for ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 사용자의 세션 목록 조회
     * GET /api/v1/sessions
     */
    getUserSessions: async (req, res, next) => {
        try {
            const {status, type, limit, offset, sort, order} = req.query;
            const user_id = req.user.id;

            // 세션 목록 조회 서비스 호출 (회복성 패턴 적용)
            const {rows: sessions, count} = await withMongoResilience(
                async () => sessionService.getUserSessions(user_id, {
                    status,
                    type,
                    limit: limit ? parseInt(limit, 10) : 10,
                    offset: offset ? parseInt(offset, 10) : 0,
                    sort: sort || 'created_at',
                    order: order || 'DESC'
                }),
                { operationName: 'get_user_sessions' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: {
                    sessions,
                    total: count,
                    limit: limit ? parseInt(limit, 10) : 10,
                    offset: offset ? parseInt(offset, 10) : 0
                }
            });
        } catch (error) {
            logger.error('Get user sessions error:', error);
            next(error);
        }
    },

    /**
     * 세션 정보 업데이트
     * PUT /api/v1/sessions/:id
     */
    updateSession: async (req, res, next) => {
        try {
            const {id} = req.params;
            const updateData = req.body;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_update' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션을 업데이트할 권한이 없습니다.'
                });
            }

            // 세션 업데이트 서비스 호출 (회복성 패턴 적용)
            const updatedSession = await withMongoResilience(
                async () => sessionService.updateSession(id, updateData),
                { operationName: 'update_session' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: updatedSession,
                message: '세션이 성공적으로 업데이트되었습니다.'
            });
        } catch (error) {
            logger.error(`Update session error for ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 세션 종료
     * POST /api/v1/sessions/:id/end
     */
    endSession: async (req, res, next) => {
        try {
            const {id} = req.params;
            const {summary} = req.body;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_end' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션을 종료할 권한이 없습니다.'
                });
            }

            // 세션 종료 서비스 호출 (회복성 패턴 적용)
            const endedSession = await withMongoResilience(
                async () => sessionService.endSession(id, summary),
                { operationName: 'end_session' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: {
                    id: endedSession.id,
                    status: endedSession.status,
                    duration: endedSession.duration,
                    end_time: endedSession.end_time
                },
                message: '세션이 성공적으로 종료되었습니다.'
            });
        } catch (error) {
            logger.error(`End session error for ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 세션 요약 정보 업데이트
     * PUT /api/v1/sessions/:id/summary
     */
    updateSummary: async (req, res, next) => {
        try {
            const {id} = req.params;
            const {summary} = req.body;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_summary' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션의 요약 정보를 업데이트할 권한이 없습니다.'
                });
            }

            // 세션 요약 업데이트 서비스 호출 (회복성 패턴 적용)
            await withMongoResilience(
                async () => sessionService.updateSessionSummary(id, summary),
                { operationName: 'update_session_summary' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                message: '세션 요약 정보가 성공적으로 업데이트되었습니다.'
            });
        } catch (error) {
            logger.error(`Update summary error for session ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 발표 타이머 설정
     * POST /api/v1/sessions/:id/timer/setup
     */
    setupTimer: async (req, res, next) => {
        try {
            const {id} = req.params;
            const timerSettings = req.body;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_timer' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션의 타이머를 설정할 권한이 없습니다.'
                });
            }

            // 타이머 설정 서비스 호출 (회복성 패턴 적용)
            const timerData = await withRedisResilience(
                async () => sessionService.setupPresentationTimer(id, timerSettings),
                { operationName: 'setup_timer' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: timerData,
                message: '발표 타이머가 성공적으로 설정되었습니다.'
            });
        } catch (error) {
            logger.error(`Setup timer error for session ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 타이머 시작
     * POST /api/v1/sessions/:id/timer/start
     */
    startTimer: async (req, res, next) => {
        try {
            const {id} = req.params;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_timer_start' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션의 타이머를 시작할 권한이 없습니다.'
                });
            }

            // 타이머 시작 서비스 호출 (회복성 패턴 적용)
            const timerData = await withRedisResilience(
                async () => timerService.startTimer(id),
                { operationName: 'start_timer' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: timerData,
                message: '타이머가 시작되었습니다.'
            });
        } catch (error) {
            logger.error(`Start timer error for session ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 타이머 일시 중지
     * POST /api/v1/sessions/:id/timer/pause
     */
    pauseTimer: async (req, res, next) => {
        try {
            const {id} = req.params;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_timer_pause' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션의 타이머를 일시 중지할 권한이 없습니다.'
                });
            }

            // 타이머 일시 중지 서비스 호출 (회복성 패턴 적용)
            const timerData = await withRedisResilience(
                async () => timerService.pauseTimer(id),
                { operationName: 'pause_timer' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: timerData,
                message: '타이머가 일시 중지되었습니다.'
            });
        } catch (error) {
            logger.error(`Pause timer error for session ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 타이머 재개
     * POST /api/v1/sessions/:id/timer/resume
     */
    resumeTimer: async (req, res, next) => {
        try {
            const {id} = req.params;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_timer_resume' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션의 타이머를 재개할 권한이 없습니다.'
                });
            }

            // 타이머 재개 서비스 호출 (회복성 패턴 적용)
            const timerData = await withRedisResilience(
                async () => timerService.resumeTimer(id),
                { operationName: 'resume_timer' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: timerData,
                message: '타이머가 재개되었습니다.'
            });
        } catch (error) {
            logger.error(`Resume timer error for session ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 타이머 리셋
     * POST /api/v1/sessions/:id/timer/reset
     */
    resetTimer: async (req, res, next) => {
        try {
            const {id} = req.params;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_timer_reset' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션의 타이머를 리셋할 권한이 없습니다.'
                });
            }

            // 타이머 리셋 서비스 호출 (회복성 패턴 적용)
            const timerData = await withRedisResilience(
                async () => timerService.resetTimer(id),
                { operationName: 'reset_timer' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: timerData,
                message: '타이머가 리셋되었습니다.'
            });
        } catch (error) {
            logger.error(`Reset timer error for session ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 타이머 상태 조회
     * GET /api/v1/sessions/:id/timer
     */
    getTimerStatus: async (req, res, next) => {
        try {
            const {id} = req.params;

            // 먼저 세션 조회하여 사용자 권한 확인 (회복성 패턴 적용)
            const session = await withMongoResilience(
                async () => sessionService.getSession(id),
                { operationName: 'get_session_for_timer_status' }
            );

            if (session.user_id !== req.user.id) {
                return res.status(httpStatus.FORBIDDEN).json({
                    success: false,
                    message: '이 세션의 타이머 상태를 조회할 권한이 없습니다.'
                });
            }

            // 타이머 상태 조회 서비스 호출 (회복성 패턴 적용)
            const timerData = await withRedisResilience(
                async () => timerService.getTimerStatus(id),
                { operationName: 'get_timer_status' }
            );

            res.status(httpStatus.OK).json({
                success: true,
                data: timerData
            });
        } catch (error) {
            logger.error(`Get timer status error for session ID ${req.params.id}:`, error);
            next(error);
        }
    },

    /**
     * 세션 유효성 검증
     * POST /api/v1/sessions/validate
     */
    validateSession: async (req, res, next) => {
        try {
            const { sessionId, userId } = req.body;

            if (!sessionId || !userId) {
                return res.status(httpStatus.BAD_REQUEST).json({
                    success: false,
                    message: '세션 ID와 사용자 ID가 필요합니다.'
                });
            }

            // 세션 조회 (회복성 패턴 적용)
            try {
                const session = await withMongoResilience(
                    async () => sessionService.getSession(sessionId),
                    { operationName: 'validate_session' }
                );
                
                // 세션 상태 확인
                if (session.status !== 'active') {
                    return res.status(httpStatus.OK).json({
                        success: true,
                        data: {
                            isValid: false,
                            reason: 'inactive_session'
                        }
                    });
                }

                // 소유자 확인
                if (session.user_id === userId) {
                    return res.status(httpStatus.OK).json({
                        success: true,
                        data: {
                            isValid: true,
                            role: 'owner'
                        }
                    });
                }

                // 참가자 확인 (회복성 패턴 적용)
                const isParticipant = await withMongoResilience(
                    async () => sessionService.isSessionParticipant(sessionId, userId),
                    { operationName: 'check_participant' }
                );
                
                return res.status(httpStatus.OK).json({
                    success: true,
                    data: {
                        isValid: isParticipant,
                        role: isParticipant ? 'participant' : null,
                        reason: !isParticipant ? 'not_participant' : null
                    }
                });
            } catch (error) {
                // 세션 찾을 수 없음
                return res.status(httpStatus.OK).json({
                    success: true,
                    data: {
                        isValid: false,
                        reason: 'session_not_found'
                    }
                });
            }
        } catch (error) {
            logger.error(`세션 유효성 검증 오류:`, error);
            next(error);
        }
    },

    /**
     * 세션 상태 조회
     * GET /api/v1/sessions/:id/status
     */
    getSessionStatus: async (req, res, next) => {
        try {
            const { id } = req.params;

            // 세션 상세 정보 조회 (회복성 패턴 적용)
            try {
                const session = await withMongoResilience(
                    async () => sessionService.getSession(id),
                    { operationName: 'get_session_status' }
                );
                
                // 개별 사용자 세션이므로 참가자는 세션 소유자만
                const participants = [{
                    userId: session.user_id,
                    joinedAt: session.created_at,
                    status: 'active',
                    connected: true
                }];
                
                // 현재 실시간 분석 기능은 미구현 상태이므로 null 반환
                const latestAnalysis = null;
                
                res.status(httpStatus.OK).json({
                    success: true,
                    data: {
                        sessionId: id,
                        title: session.title,
                        status: session.status,
                        type: session.type,
                        startTime: session.created_at,
                        endTime: session.end_time,
                        duration: session.duration,
                        ownerId: session.user_id,
                        participants,
                        participantsCount: participants.length,
                        latestAnalysis
                    }
                });
            } catch (error) {
                return res.status(httpStatus.NOT_FOUND).json({
                    success: false,
                    message: '세션을 찾을 수 없습니다.'
                });
            }
        } catch (error) {
            logger.error(`세션 상태 조회 오류:`, error);
            next(error);
        }
    }
};

module.exports = sessionController;
