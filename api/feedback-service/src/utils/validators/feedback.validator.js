const { body } = require('express-validator');

/**
 * 실시간 피드백 생성 유효성 검사
 */
const generateFeedback = [
    body('session_id')
        .isString().withMessage('세션 ID는 문자열이어야 합니다.')
        .isLength({ min: 36, max: 36 }).withMessage('세션 ID는 36자여야 합니다.'),

    body('context')
        .isObject().withMessage('컨텍스트는 객체여야 합니다.'),

    body('context.current_speaking_pace')
        .optional()
        .isFloat({ min: 0 }).withMessage('말하기 속도는 0 이상의 숫자여야 합니다.'),

    body('context.current_volume')
        .optional()
        .isFloat({ min: 0, max: 100 }).withMessage('음량은 0~100 사이의 숫자여야 합니다.'),

    body('context.current_emotion')
        .optional()
        .isString().withMessage('감정은 문자열이어야 합니다.'),

    body('context.interaction_state')
        .optional()
        .isString().withMessage('상호작용 상태는 문자열이어야 합니다.')
        .isIn(['user_speaking', 'other_speaking', 'silence', 'overlapping']).withMessage('유효하지 않은 상호작용 상태입니다.'),

    body('context.silence_duration')
        .optional()
        .isFloat({ min: 0 }).withMessage('침묵 지속 시간은 0 이상의 숫자여야 합니다.'),

    body('context.interest_level')
        .optional()
        .isFloat({ min: 0, max: 1 }).withMessage('관심도는 0~1 사이의 숫자여야 합니다.'),

    body('context.previous_interest_level')
        .optional()
        .isFloat({ min: 0, max: 1 }).withMessage('이전 관심도는 0~1 사이의 숫자여야 합니다.'),

    body('device_id')
        .isString().withMessage('기기 ID는 문자열이어야 합니다.')
        .isLength({ min: 36, max: 36 }).withMessage('기기 ID는 36자여야 합니다.'),
];

/**
 * STT 분석 결과 처리 유효성 검사
 */
const processSTTAnalysis = [
    body('sessionId')
        .isString().withMessage('세션 ID는 문자열이어야 합니다.')
        .isLength({ min: 1 }).withMessage('세션 ID는 필수입니다.'),

    body('text')
        .isString().withMessage('텍스트는 문자열이어야 합니다.')
        .isLength({ min: 1 }).withMessage('텍스트는 필수입니다.'),

    body('speechMetrics')
        .optional()
        .isObject().withMessage('음성 메트릭은 객체여야 합니다.'),

    body('speechMetrics.evaluationWpm')
        .optional()
        .isFloat({ min: 0, max: 1000 }).withMessage('말하기 속도(WPM)는 0~1000 사이의 숫자여야 합니다.'),

    body('speechMetrics.pauseMetrics')
        .optional()
        .isObject().withMessage('일시정지 메트릭은 객체여야 합니다.'),

    body('speechMetrics.pauseMetrics.count')
        .optional()
        .isInt({ min: 0 }).withMessage('일시정지 횟수는 0 이상의 정수여야 합니다.'),

    body('speechMetrics.pauseMetrics.averageDuration')
        .optional()
        .isFloat({ min: 0 }).withMessage('평균 일시정지 지속시간은 0 이상의 숫자여야 합니다.'),

    body('emotionAnalysis')
        .optional()
        .isObject().withMessage('감정 분석은 객체여야 합니다.'),

    body('emotionAnalysis.primaryEmotion')
        .optional()
        .isObject().withMessage('주요 감정은 객체여야 합니다.'),

    body('emotionAnalysis.primaryEmotion.emotionKr')
        .optional()
        .isString().withMessage('감정(한국어)은 문자열이어야 합니다.'),

    body('emotionAnalysis.primaryEmotion.probability')
        .optional()
        .isFloat({ min: 0, max: 1 }).withMessage('감정 확률은 0~1 사이의 숫자여야 합니다.'),

    body('scenario')
        .optional()
        .isString().withMessage('시나리오는 문자열이어야 합니다.')
        .isIn(['interview', 'dating', 'business', 'general']).withMessage('유효하지 않은 시나리오입니다.'),

    body('language')
        .optional()
        .isString().withMessage('언어는 문자열이어야 합니다.')
        .isIn(['ko', 'en']).withMessage('지원하지 않는 언어입니다.'),
];

/**
 * 피드백 수신 확인 유효성 검사
 */
const acknowledgeFeedback = [
    body('received_at')
        .optional()
        .isISO8601().withMessage('수신 시간은 ISO 8601 형식의 날짜여야 합니다.'),

    body('user_action')
        .optional()
        .isString().withMessage('사용자 액션은 문자열이어야 합니다.')
        .isIn(['acknowledged', 'ignored']).withMessage('유효하지 않은 사용자 액션입니다.'),
];

module.exports = {
    generateFeedback,
    processSTTAnalysis,
    acknowledgeFeedback
};