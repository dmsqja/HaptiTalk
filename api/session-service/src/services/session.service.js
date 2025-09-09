const {Session, SESSION_TYPES, SESSION_STATUS, getDefaultSettings} = require('../models/session.model');
const {redisUtils, CHANNELS} = require('../config/redis');
const logger = require('../utils/logger');
const {Op} = require('sequelize');
const {Participant} = require('../models/participant.model');
const { v4: uuidv4 } = require('uuid');
const { getCollection } = require('../config/mongodb');

/**
 * 세션 서비스 클래스
 * 세션 생성, 관리, 조회, 종료 등의 비즈니스 로직을 처리
 */
class SessionService {
    /**
     * 새 세션 생성
     * @param {Object} sessionData 세션 생성 데이터
     * @returns {Promise<Object>} 생성된 세션 객체
     */
    async createSession(sessionData) {
        const {user_id, title, type, custom_settings = {}, id} = sessionData;

        // 세션 타입 유효성 검사
        if (!Object.values(SESSION_TYPES).includes(type)) {
            throw new Error(`Invalid session type: ${type}`);
        }

        // 기본 설정 가져오기
        const defaultSettings = getDefaultSettings(type);

        // 사용자 커스텀 설정과 기본 설정 병합
        const mergedSettings = this.mergeSettings(defaultSettings, custom_settings);

        logger.info(`새 세션 생성 시작: 사용자 ${user_id}, 타입 ${type}`, {
            title,
            settings: mergedSettings,
            customId: id
        });

        try {
            // 세션 레코드 생성 (id가 제공되면 사용, 없으면 자동 생성)
            const sessionRecord = {
                user_id,
                title,
                type,
                status: SESSION_STATUS.CREATED,
                settings: mergedSettings,
                metadata: {
                    device_info: sessionData.device_info || {},
                    location: sessionData.location || null,
                    participants: sessionData.participants || [],
                    tags: sessionData.tags || [],
                }
            };

            // id가 제공되면 사용
            if (id) {
                sessionRecord.id = id;
            }

            const session = await Session.create(sessionRecord);

            // MongoDB에도 세션 정보 저장
            try {
                const sessionsCollection = await getCollection('sessions');
                const mongoDoc = {
                    sessionId: session.id,
                    userId: session.user_id,
                    title: session.title,
                    type: session.type,
                    status: session.status,
                    settings: session.settings || {},
                    metadata: session.metadata || {},
                    createdAt: session.created_at ? new Date(session.created_at) : new Date(),
                    updatedAt: session.updated_at ? new Date(session.updated_at) : new Date()
                };
                
                // null이 아닌 선택적 필드들만 추가
                if (session.start_time) {
                    mongoDoc.startTime = new Date(session.start_time);
                }
                if (session.end_time) {
                    mongoDoc.endTime = new Date(session.end_time);
                }
                if (session.duration !== null && session.duration !== undefined) {
                    mongoDoc.duration = session.duration;
                }
                
                // MongoDB 저장 데이터 준비 완료
                await sessionsCollection.insertOne(mongoDoc);
                logger.info(`MongoDB에 세션 정보 저장 성공: ${session.id}`);
            } catch (mongoError) {
                logger.error(`MongoDB 세션 저장 실패 (상세):`, {
                    sessionId: session.id,
                    error: mongoError.message,
                    code: mongoError.code,
                    writeErrors: mongoError.writeErrors || null
                });
                // MongoDB 저장 실패해도 PostgreSQL 세션은 유지
            }

            // Redis에 세션 구성 캐싱
            await redisUtils.set(
                redisUtils.keys.sessionConfig(session.id),
                {
                    id: session.id,
                    user_id: session.user_id,
                    type: session.type,
                    settings: session.settings
                },
                86400 // 24시간 TTL
            );

            // 세션 상태 Redis에 저장
            await redisUtils.set(
                redisUtils.keys.sessionStatus(session.id),
                {
                    status: SESSION_STATUS.CREATED,
                    start_time: null,
                    last_activity: new Date().toISOString()
                },
                86400 // 24시간 TTL
            );

            // 사용자의 세션 목록에 추가
            await redisUtils.addToList(
                redisUtils.keys.userSessions(user_id),
                {
                    id: session.id,
                    title: session.title,
                    type: session.type,
                    created_at: session.created_at
                }
            );

            // 세션 생성 이벤트 발행
            await redisUtils.publish(CHANNELS.SESSION_CREATED, {
                session_id: session.id,
                user_id: session.user_id,
                type: session.type,
                timestamp: new Date().toISOString()
            });

            logger.info(`세션 생성 성공: ${session.id}`, {
                userId: session.user_id,
                sessionType: session.type,
                sessionTitle: session.title
            });
            
            return session;
        } catch (error) {
            logger.error('Error in createSession:', error);
            throw error;
        }
    }

    /**
     * 세션 정보 조회
     * @param {string} sessionId 세션 ID
     * @returns {Promise<Object>} 세션 객체
     */
    async getSession(sessionId) {
        try {
            // 1차: Redis 캐시에서 조회
            const cachedStatus = await redisUtils.get(redisUtils.keys.sessionStatus(sessionId));

            if (cachedStatus) {
                // 캐시된 상태가 있으면 데이터베이스에서 세션 정보 조회
                const dbSession = await Session.findByPk(sessionId);

                if (!dbSession) {
                    throw new Error(`Session not found: ${sessionId}`);
                }

                logger.debug(`세션 조회 성공 (캐시): ${sessionId}`);
                return {
                    ...dbSession.get({plain: true}),
                    cached_status: cachedStatus
                };
            }

            // 2차: PostgreSQL에서 조회
            let session = await Session.findByPk(sessionId);

            if (!session) {
                // 3차: MongoDB에서 조회 (백업)
                try {
                    const sessionsCollection = await getCollection('sessions');
                    const mongoSession = await sessionsCollection.findOne({ sessionId });
                    
                    if (mongoSession) {
                        logger.debug(`세션 조회 성공 (MongoDB): ${sessionId}`);
                        return {
                            id: mongoSession.sessionId,
                            user_id: mongoSession.userId,
                            title: mongoSession.title,
                            type: mongoSession.type,
                            status: mongoSession.status,
                            start_time: mongoSession.startTime,
                            end_time: mongoSession.endTime,
                            duration: mongoSession.duration,
                            settings: mongoSession.settings,
                            metadata: mongoSession.metadata,
                            created_at: mongoSession.createdAt,
                            updated_at: mongoSession.updatedAt
                        };
                    }
                } catch (mongoError) {
                    logger.warn(`MongoDB에서 세션 조회 실패: ${mongoError.message}`, { sessionId });
                }

                logger.warn(`세션 조회 실패 - 존재하지 않는 세션: ${sessionId}`);
                throw new Error(`Session not found: ${sessionId}`);
            }

            logger.debug(`세션 조회 성공 (DB): ${sessionId}`);
            return session;
        } catch (error) {
            logger.error(`Error getting session ${sessionId}:`, error);
            throw error;
        }
    }

    /**
     * 사용자의 세션 목록 조회
     * @param {string} userId 사용자 ID
     * @param {Object} options 조회 옵션 (필터 등)
     * @returns {Promise<Array>} 세션 객체 배열
     */
    async getUserSessions(userId, options = {}) {
        const {status, type, limit = 10, offset = 0, sort = 'created_at', order = 'DESC'} = options;

        // 기본 조건: 사용자 ID 필터
        const where = {user_id: userId};

        // 상태 필터 적용
        if (status) {
            where.status = status;
        }

        // 타입 필터 적용
        if (type) {
            where.type = type;
        }

        try {
            // 데이터베이스에서 세션 목록 조회
            const sessions = await Session.findAndCountAll({
                where,
                limit,
                offset,
                order: [[sort, order]],
                attributes: [
                    'id', 'title', 'type', 'status', 'start_time', 'end_time',
                    'duration', 'created_at', 'updated_at'
                ]
            });

            logger.info(`사용자 세션 목록 조회 성공: ${userId}`, {
                sessionCount: sessions.count,
                limit: limit,
                offset: offset
            });

            return sessions;
        } catch (error) {
            logger.error(`Error getting sessions for user ${userId}:`, error);
            throw error;
        }
    }

    /**
     * 세션 업데이트
     * @param {string} sessionId 세션 ID
     * @param {Object} updateData 업데이트할 데이터
     * @returns {Promise<Object>} 업데이트된 세션 객체
     */
    async updateSession(sessionId, updateData) {
        try {
            const session = await Session.findByPk(sessionId);

            if (!session) {
                throw new Error(`Session not found: ${sessionId}`);
            }

            // 업데이트 가능한 필드 목록
            const updatableFields = ['title', 'status', 'metadata'];
            const updates = {};

            // 업데이트 가능한 필드만 필터링
            Object.keys(updateData).forEach(key => {
                if (updatableFields.includes(key)) {
                    updates[key] = updateData[key];
                }
            });

            // 설정 업데이트 특별 처리
            if (updateData.settings) {
                updates.settings = this.mergeSettings(session.settings, updateData.settings);
            }

            // 세션 업데이트
            await session.update(updates);

            // Redis 캐시 업데이트
            if (updateData.settings) {
                const cachedConfig = await redisUtils.get(redisUtils.keys.sessionConfig(sessionId));
                if (cachedConfig) {
                    await redisUtils.set(
                        redisUtils.keys.sessionConfig(sessionId),
                        {
                            ...cachedConfig,
                            settings: updates.settings
                        },
                        86400 // 24시간 TTL
                    );
                }
            }

            // 상태 업데이트 시 Redis 상태 캐시 업데이트
            if (updateData.status) {
                const cachedStatus = await redisUtils.get(redisUtils.keys.sessionStatus(sessionId));
                if (cachedStatus) {
                    await redisUtils.set(
                        redisUtils.keys.sessionStatus(sessionId),
                        {
                            ...cachedStatus,
                            status: updateData.status,
                            last_activity: new Date().toISOString()
                        },
                        86400 // 24시간 TTL
                    );
                }

                // 상태 변경에 따른 추가 처리
                switch (updateData.status) {
                    case SESSION_STATUS.ACTIVE:
                        // 세션 시작 처리
                        if (!session.start_time) {
                            await session.update({start_time: new Date()});
                            logger.info(`세션 시작: ${sessionId}`, {
                                userId: session.user_id,
                                sessionType: session.type,
                                startTime: new Date().toISOString()
                            });
                        }
                        break;

                    case SESSION_STATUS.ENDED:
                        // 세션 종료 처리
                        if (!session.end_time) {
                            const endTime = new Date();
                            const duration = session.start_time
                                ? Math.floor((endTime - new Date(session.start_time)) / 1000)
                                : 0;

                            await session.update({
                                end_time: endTime,
                                duration
                            });

                            logger.info(`세션 자동 종료: ${sessionId}`, {
                                userId: session.user_id,
                                duration: duration,
                                endTime: endTime.toISOString()
                            });
                        }
                        break;
                }
            }

            // 세션 업데이트 이벤트 발행
            await redisUtils.publish(CHANNELS.SESSION_UPDATED, {
                session_id: session.id,
                user_id: session.user_id,
                type: session.type,
                status: session.status,
                timestamp: new Date().toISOString()
            });

            logger.info(`세션 업데이트 성공: ${sessionId}`, {
                updatedFields: Object.keys(updates),
                newStatus: session.status
            });
            
            return session;
        } catch (error) {
            logger.error(`Error updating session ${sessionId}:`, error);
            throw error;
        }
    }

    /**
     * 세션 종료
     * @param {string} sessionId 세션 ID
     * @param {Object} summaryData 세션 요약 데이터 (선택)
     * @returns {Promise<Object>} 종료된 세션 객체
     */
    async endSession(sessionId, summaryData = null) {
        try {
            const session = await Session.findByPk(sessionId);

            if (!session) {
                throw new Error(`Session not found: ${sessionId}`);
            }

            // 이미 종료된 세션인지 확인
            if (session.status === SESSION_STATUS.ENDED) {
                return session;
            }

            const endTime = new Date();
            const duration = session.start_time
                ? Math.floor((endTime - new Date(session.start_time)) / 1000)
                : 0;

            // 세션 업데이트
            const updates = {
                status: SESSION_STATUS.ENDED,
                end_time: endTime,
                duration
            };

            // 요약 데이터가 있으면 추가
            if (summaryData) {
                updates.summary = summaryData;
            }

            await session.update(updates);

            // Redis 캐시 업데이트
            const cachedStatus = await redisUtils.get(redisUtils.keys.sessionStatus(sessionId));
            if (cachedStatus) {
                await redisUtils.set(
                    redisUtils.keys.sessionStatus(sessionId),
                    {
                        status: SESSION_STATUS.ENDED,
                        end_time: endTime.toISOString(),
                        duration,
                        last_activity: new Date().toISOString()
                    },
                    86400 // 24시간 TTL
                );
            }

            // 세션 종료 이벤트 발행
            await redisUtils.publish(CHANNELS.SESSION_ENDED, {
                session_id: session.id,
                user_id: session.user_id,
                type: session.type,
                duration,
                timestamp: new Date().toISOString()
            });

            logger.info(`세션 종료 성공: ${sessionId}`, {
                userId: session.user_id,
                sessionType: session.type,
                duration: duration,
                startTime: session.start_time,
                endTime: endTime.toISOString()
            });
            
            return session;
        } catch (error) {
            logger.error(`Error ending session ${sessionId}:`, error);
            throw error;
        }
    }

    /**
     * 세션 요약 데이터 업데이트
     * @param {string} sessionId 세션 ID
     * @param {Object} summaryData 세션 요약 데이터
     * @returns {Promise<Object>} 업데이트된 세션 객체
     */
    async updateSessionSummary(sessionId, summaryData) {
        try {
            const session = await Session.findByPk(sessionId);

            if (!session) {
                logger.warn(`세션 요약 업데이트 실패 - 존재하지 않는 세션: ${sessionId}`);
                throw new Error(`Session not found: ${sessionId}`);
            }

            await session.update({summary: summaryData});
            
            logger.info(`세션 요약 업데이트 성공: ${sessionId}`, {
                userId: session.user_id,
                summaryKeys: Object.keys(summaryData || {})
            });
            
            return session;
        } catch (error) {
            logger.error(`Error updating session summary ${sessionId}:`, error);
            throw error;
        }
    }

    /**
     * 발표 타이머 설정
     * @param {string} sessionId 세션 ID
     * @param {Object} timerSettings 타이머 설정
     * @returns {Promise<Object>} 설정된 타이머 정보
     */
    async setupPresentationTimer(sessionId, timerSettings) {
        try {
            const session = await this.getSession(sessionId);

            if (session.type !== SESSION_TYPES.PRESENTATION) {
                throw new Error(`Session is not a presentation type: ${sessionId}`);
            }

            // 타이머 설정 업데이트
            const settings = session.settings;

            if (!settings.presentation_specific) {
                settings.presentation_specific = {};
            }

            if (!settings.presentation_specific.timer) {
                settings.presentation_specific.timer = {};
            }

            // 타이머 설정 병합
            const currentTimer = settings.presentation_specific.timer;
            const newTimer = {
                ...currentTimer,
                ...timerSettings,
                enabled: true
            };

            settings.presentation_specific.timer = newTimer;

            // 세션 설정 업데이트
            await this.updateSession(sessionId, {settings});

            // Redis에 타이머 정보 저장
            const timerData = {
                duration_seconds: (newTimer.duration_minutes || 10) * 60,
                alerts: newTimer.alerts || {
                    halfway: true,
                    five_minutes: true,
                    two_minutes: true,
                    thirty_seconds: true
                },
                start_time: null,
                end_time: null,
                status: 'ready'
            };

            await redisUtils.set(
                redisUtils.keys.sessionTimer(sessionId),
                timerData,
                86400 // 24시간 TTL
            );

            return timerData;
        } catch (error) {
            logger.error(`Error setting up presentation timer for session ${sessionId}:`, error);
            throw error;
        }
    }

    /**
     * 설정 병합 유틸리티 함수
     * @param {Object} baseSettings 기본 설정
     * @param {Object} customSettings 사용자 커스텀 설정
     * @returns {Object} 병합된 설정
     */
    mergeSettings(baseSettings, customSettings) {
        // 깊은 복사로 기본 설정 복제
        const mergedSettings = JSON.parse(JSON.stringify(baseSettings));

        // 커스텀 설정을 재귀적으로 병합
        const recursiveMerge = (target, source) => {
            for (const key in source) {
                if (source[key] !== null && typeof source[key] === 'object' && !Array.isArray(source[key])) {
                    // 대상이 객체가 아니면 객체로 초기화
                    if (!target[key] || typeof target[key] !== 'object') {
                        target[key] = {};
                    }
                    recursiveMerge(target[key], source[key]);
                } else {
                    // 객체가 아닌 경우 직접 값 할당
                    target[key] = source[key];
                }
            }
        };

        recursiveMerge(mergedSettings, customSettings);
        return mergedSettings;
    }

    /**
     * 사용자가 세션 참가자인지 확인
     * @param {string} sessionId - 세션 ID
     * @param {string} userId - 사용자 ID
     * @returns {Promise<boolean>} - 참가자 여부
     */
    async isSessionParticipant(sessionId, userId) {
        try {
            // 세션 참가자 테이블에서 조회
            const participant = await Participant.findOne({
                where: {
                    session_id: sessionId,
                    user_id: userId
                }
            });

            return !!participant; // 참가자 존재 여부 반환
        } catch (error) {
            logger.error(`Session participant check error for session ${sessionId}, user ${userId}:`, error);
            return false;
        }
    }

    /**
     * 세션 참가자 목록 조회
     * @param {string} sessionId - 세션 ID
     * @returns {Promise<Array>} - 참가자 목록
     */
    async getSessionParticipants(sessionId) {
        try {
            // 세션 참가자 테이블에서 모든 참가자 조회
            const participants = await Participant.findAll({
                where: {
                    session_id: sessionId
                },
                attributes: ['user_id', 'joined_at', 'status']
            });

            // Redis에서 현재 접속 중인 참가자 정보 조회
            const redisClient = redisUtils.getClient();
            const connectedParticipantsKey = `session:participants:${sessionId}`;
            const connectedParticipantIds = await redisClient.smembers(connectedParticipantsKey);

            return participants.map(p => ({
                userId: p.user_id,
                joinedAt: p.joined_at,
                status: p.status,
                connected: connectedParticipantIds.includes(p.user_id)
            }));
        } catch (error) {
            logger.error(`Session participants retrieval error for session ${sessionId}:`, error);
            return [];
        }
    }

    /**
     * 세션 최신 분석 결과 조회
     * @param {string} sessionId - 세션 ID
     * @returns {Promise<Object|null>} - 최신 분석 결과
     */
    async getLatestAnalysis(sessionId) {
        try {
            // Redis에서 최신 분석 결과 조회
            const redisClient = redisUtils.getClient();
            const analysisKey = `analysis:latest:${sessionId}`;
            const analysisData = await redisClient.get(analysisKey);
            
            if (analysisData) {
                return JSON.parse(analysisData);
            }
            
            // Redis에 없는 경우 분석 서비스에서 조회 (미구현)
            return null;
        } catch (error) {
            logger.error(`Latest analysis retrieval error for session ${sessionId}:`, error);
            return null;
        }
    }
}

// SessionService 인스턴스 생성 및 export
const sessionService = new SessionService();
module.exports = sessionService;