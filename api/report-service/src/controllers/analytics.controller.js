const analyticsService = require('../services/analytics.service');
const logger = require('../utils/logger');
const { formatResponse, formatErrorResponse } = require('../utils/responseFormatter');

/**
 * 세그먼트 데이터 저장 (30초마다 호출)
 */
const saveSegment = async (req, res) => {
    try {
        const { sessionId } = req.params;
        const { segmentIndex, timestamp, transcription, analysis, hapticFeedbacks, suggestedTopics } = req.body;
        const userId = req.user.id;

        logger.info(`세그먼트 저장 요청: sessionId=${sessionId}, segmentIndex=${segmentIndex}, userId=${userId}`);
        const segmentData = {
            sessionId,
            userId,
            segmentIndex: parseInt(segmentIndex, 10),
            timestamp: new Date(timestamp),
            transcription: transcription || '',
            analysis: analysis || {},
            hapticFeedbacks: hapticFeedbacks || [],
            suggestedTopics: suggestedTopics || []
        };
        const result = await analyticsService.saveSegment(segmentData);

        logger.info(`세그먼트 저장 완료: sessionId=${sessionId}, segmentIndex=${segmentIndex}`);

        return formatResponse(res, 200, true, {
            sessionId,
            segmentIndex,
            savedAt: new Date()
        }, '세그먼트가 성공적으로 저장되었습니다');

    } catch (error) {
        logger.error(`세그먼트 저장 실패: ${error.message}`, { 
            sessionId: req.params.sessionId,
            segmentIndex: req.body.segmentIndex,
            userId: req.user?.id,
            error: error.stack,
            mongoError: error.errInfo || null,
            writeErrors: error.writeErrors || null
        });

        if (error.code === 11000) {
            return formatErrorResponse(res, 409, '이미 존재하는 세그먼트입니다');
        }

        return formatErrorResponse(res, 500, '세그먼트 저장 중 오류가 발생했습니다');
    }
};

/**
 * 세션의 모든 세그먼트 조회
 */
const getSegments = async (req, res) => {
    try {
        const { sessionId } = req.params;
        const userId = req.user.id;

        logger.info(`세그먼트 조회 요청: sessionId=${sessionId}, userId=${userId}`);

        const segments = await analyticsService.getSegmentsBySession(sessionId, userId);

        logger.info(`세그먼트 조회 완료: sessionId=${sessionId}, count=${segments.length}`);

        return formatResponse(res, 200, true, {
            sessionId,
            totalSegments: segments.length,
            segments
        }, '세그먼트를 성공적으로 조회했습니다');

    } catch (error) {
        logger.error(`세그먼트 조회 실패: ${error.message}`, { 
            sessionId: req.params.sessionId,
            userId: req.user?.id,
            error: error.stack 
        });

        return formatErrorResponse(res, 500, '세그먼트 조회 중 오류가 발생했습니다');
    }
};

/**
 * 세션 종료 및 최종 분석 데이터 생성
 */
const finalizeSession = async (req, res) => {
    try {
        const { sessionId } = req.params;
        const { sessionType, totalDuration } = req.body;
        const userId = req.user.id;

        logger.info(`세션 종료 처리 요청: sessionId=${sessionId}, userId=${userId}, sessionType=${sessionType}`);

        // 1. 모든 세그먼트 조회
        const segments = await analyticsService.getSegmentsBySession(sessionId, userId);
        
        if (segments.length === 0) {
            logger.warn(`세션 종료 처리 실패: 세그먼트가 없음 - sessionId=${sessionId}`);
            return formatErrorResponse(res, 404, '분석할 세그먼트 데이터가 없습니다');
        }

        // 2. sessionAnalytics 생성
        const sessionAnalytics = await analyticsService.generateSessionAnalytics(
            sessionId, 
            userId, 
            sessionType, 
            segments, 
            totalDuration
        );

        logger.info(`세션 분석 완료: sessionId=${sessionId}, totalSegments=${segments.length}`);

        return formatResponse(res, 200, true, {
            sessionId,
            totalSegments: segments.length,
            analytics: sessionAnalytics
        }, '세션이 성공적으로 종료되고 분석이 완료되었습니다');

    } catch (error) {
        logger.error(`세션 종료 처리 실패: ${error.message}`, { 
            sessionId: req.params.sessionId,
            userId: req.user?.id,
            error: error.stack 
        });

        return formatErrorResponse(res, 500, '세션 종료 처리 중 오류가 발생했습니다');
    }
};

/**
 * 세그먼트 데이터 업데이트
 */
const updateSegment = async (req, res) => {
    try {
        const { sessionId, segmentIndex } = req.params;
        const { analysis, hapticFeedbacks } = req.body;
        const userId = req.user.id;

        logger.info(`세그먼트 업데이트 요청: sessionId=${sessionId}, segmentIndex=${segmentIndex}, userId=${userId}`);

        const updateData = {};
        if (analysis) updateData.analysis = analysis;
        if (hapticFeedbacks) updateData.hapticFeedbacks = hapticFeedbacks;

        const result = await analyticsService.updateSegment(
            sessionId, 
            parseInt(segmentIndex), 
            userId, 
            updateData
        );

        if (!result) {
            return formatErrorResponse(res, 404, '업데이트할 세그먼트를 찾을 수 없습니다');
        }

        logger.info(`세그먼트 업데이트 완료: sessionId=${sessionId}, segmentIndex=${segmentIndex}`);

        return formatResponse(res, 200, true, {
            sessionId,
            segmentIndex: parseInt(segmentIndex),
            updatedAt: new Date()
        }, '세그먼트가 성공적으로 업데이트되었습니다');

    } catch (error) {
        logger.error(`세그먼트 업데이트 실패: ${error.message}`, { 
            sessionId: req.params.sessionId,
            segmentIndex: req.params.segmentIndex,
            userId: req.user?.id,
            error: error.stack 
        });

        return formatErrorResponse(res, 500, '세그먼트 업데이트 중 오류가 발생했습니다');
    }
};

module.exports = {
    saveSegment,
    getSegments,
    finalizeSession,
    updateSegment
}; 