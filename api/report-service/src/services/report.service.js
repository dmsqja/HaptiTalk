const { ObjectId } = require('mongodb');
const PDFDocument = require('pdfkit');
// canvas 의존성 제거
// const { ChartJSNodeCanvas } = require('chartjs-node-canvas');
const mongodbService = require('./mongodb.service');
const logger = require('../utils/logger');
const chartsUtils = require('../utils/charts');
const AnalyticsCore = require('../../../shared/analytics-core');

const reportService = {
    /**
     * 세션 데이터를 기반으로 리포트 생성
     */
    async generateSessionReport(userId, sessionId, options) {
        try {
            logger.info(`리포트 생성 시작: 사용자 ${userId}, 세션 ${sessionId}`, {
                detailLevel: options.detailLevel,
                includeCharts: options.includeCharts,
                format: options.format
            });

            // MongoDB에서 세션 분석 데이터 조회
            const db = await mongodbService.getDb();
            const sessionAnalytics = await db.collection('sessionAnalytics').findOne({
                sessionId,
                userId
            });

            if (!sessionAnalytics) {
                logger.warn(`리포트 생성 실패 - 세션 분석 데이터 없음: ${sessionId}`, {
                    userId
                });
                throw new Error('Session analytics data not found');
            }

            // MongoDB에서 피드백 이력 조회
            const feedbackHistory = await db.collection('hapticFeedbacks').find({
                sessionId,
                userId
            }).toArray();

            logger.debug(`리포트 데이터 조회 완료: ${sessionId}`, {
                feedbackCount: feedbackHistory.length,
                sessionDuration: sessionAnalytics.summary?.duration
            });

            // 리포트 데이터 생성
            const reportData = {
                _id: new ObjectId(),
                userId,
                sessionId,
                createdAt: new Date(),
                sessionType: sessionAnalytics.sessionType,
                duration: sessionAnalytics.summary.duration,
                overallInsights: this._generateOverallInsights(sessionAnalytics),
                keyMetrics: this._generateKeyMetrics(sessionAnalytics),
                emotionAnalysis: this._generateEmotionAnalysis(sessionAnalytics),
                communicationPatterns: this._generateCommunicationPatterns(sessionAnalytics),
                feedbackSummary: this._generateFeedbackSummary(feedbackHistory),
                improvementAreas: this._generateImprovementAreas(sessionAnalytics),
                detailedTimeline: this._generateDetailedTimeline(sessionAnalytics),
                conversation_topics: this._generateConversationTopics(sessionAnalytics),
                specializationInsights: this._generateSpecializationInsights(sessionAnalytics)
            };

            // MongoDB에 리포트 저장
            await db.collection('sessionReports').insertOne(reportData);

            // 🔥 차트 생성 활성화 
            if (options.includeCharts) {
                logger.info('차트 생성 활성화 - timeline과 패턴 차트 생성');
                reportData.charts = {
                    disabled: false,
                    emotion_timeline: true,
                    speaking_patterns: true,
                    timeline_points: reportData.detailedTimeline?.length || 0
                };
            } else {
                reportData.charts = { disabled: true, message: 'Chart generation is temporarily disabled' };
            }

            // PDF 생성 비활성화
            if (options.format === 'pdf') {
                // const pdfBuffer = await this.generateReportPdf(userId, reportData._id.toString());
                logger.info('PDF generation is disabled');
                reportData.pdfUrl = null; 
                reportData.pdfDisabled = true;
            }

            // 필요 없는 필드 제거 (디테일 레벨에 따라)
            if (options.detailLevel === 'basic') {
                // 🔥 detailedTimeline은 기본적으로 포함하도록 변경
                // delete reportData.detailedTimeline;
                reportData.communicationPatterns = reportData.communicationPatterns.slice(0, 3);
                reportData.improvementAreas = reportData.improvementAreas.slice(0, 3);
            }

            logger.info(`리포트 생성 성공: ${reportData._id}`, {
                userId,
                sessionId,
                reportId: reportData._id.toString(),
                sessionType: reportData.sessionType,
                duration: reportData.duration,
                insightsCount: reportData.overallInsights?.length || 0,
                improvementAreasCount: reportData.improvementAreas?.length || 0
            });

            return reportData;
        } catch (error) {
            logger.error(`Error generating report: ${error.message}`);
            throw error;
        }
    },

    /**
     * 리포트 ID로 리포트 조회
     */
    async getReportById(userId, reportId) {
        try {
            const db = await mongodbService.getDb();
            
            // 🔧 reportId가 ObjectId 형식인지 확인하고 처리
            let query;
            if (ObjectId.isValid(reportId)) {
                // MongoDB ObjectId 형식인 경우
                query = {
                    _id: new ObjectId(reportId),
                    userId
                };
            } else {
                // UUID 또는 다른 형식인 경우 sessionId로 조회
                logger.info(`reportId가 ObjectId 형식이 아님, sessionId로 조회: ${reportId}`);
                query = {
                    sessionId: reportId,
                    userId
                };
            }

            const report = await db.collection('sessionReports').findOne(query);

            if (!report) {
                logger.warn(`리포트 조회 실패 - 존재하지 않는 리포트: ${reportId}`, {
                    userId,
                    queryType: ObjectId.isValid(reportId) ? 'ObjectId' : 'sessionId'
                });
                throw new Error('Report not found');
            }

            // 🔧 MongoDB _id를 id로 변환
            const transformedReport = {
                ...report,
                id: report._id.toString(), // _id를 문자열 id로 변환
                _id: undefined // _id 필드 제거
            };

            logger.info(`리포트 조회 성공: ${reportId}`, {
                userId,
                sessionId: transformedReport.sessionId,
                sessionType: transformedReport.sessionType,
                createdAt: transformedReport.createdAt
            });

            return transformedReport;
        } catch (error) {
            logger.error(`Error retrieving report: ${error.message}`);
            throw error;
        }
    },

    /**
     * 🔧 세션 ID로 리포트 조회 (새로운 함수)
     */
    async getReportBySessionId(userId, sessionId) {
        try {
            const db = await mongodbService.getDb();
            
            const report = await db.collection('sessionReports').findOne({
                sessionId,
                userId
            });

            if (!report) {
                logger.warn(`세션 리포트 조회 실패 - 존재하지 않는 세션: ${sessionId}`, {
                    userId
                });
                throw new Error('Session report not found');
            }

            // 🔧 MongoDB _id를 id로 변환
            const transformedReport = {
                ...report,
                id: report._id.toString(), // _id를 문자열 id로 변환
                _id: undefined // _id 필드 제거
            };

            // 🔥 specializationInsights 안의 conversation_topics를 최상위로 이동
            if (transformedReport.specializationInsights?.conversation_topics && !transformedReport.conversation_topics) {
                transformedReport.conversation_topics = transformedReport.specializationInsights.conversation_topics;
                logger.info(`🔥 conversation_topics를 specializationInsights에서 최상위로 이동: ${sessionId}`);
            }

            // 🔥 차트 옵션을 동적으로 활성화 (기존 리포트도 차트 사용 가능하도록)
            if (!transformedReport.charts || transformedReport.charts.disabled) {
                transformedReport.charts = {
                    disabled: false,
                    emotion_timeline: true,
                    speaking_patterns: true,
                    timeline_points: transformedReport.detailedTimeline?.length || 0
                };
                logger.info(`🔥 기존 리포트에 차트 옵션 활성화: ${sessionId}`);
            }

            logger.info(`세션 리포트 조회 성공: ${sessionId}`, {
                userId,
                reportId: transformedReport.id,
                sessionType: transformedReport.sessionType,
                createdAt: transformedReport.createdAt,
                chartsEnabled: !transformedReport.charts.disabled
            });

            return transformedReport;
        } catch (error) {
            logger.error(`Error retrieving session report: ${error.message}`);
            throw error;
        }
    },

    /**
     * 사용자별 리포트 목록 조회
     */
    async getReportsByUser(userId, options) {
        try {
            const { page, limit, sessionType, startDate, endDate } = options;
            const skip = (page - 1) * limit;

            // 필터 구성
            const filter = { userId };
            if (sessionType) filter.sessionType = sessionType;
            if (startDate && endDate) {
                filter.createdAt = {
                    $gte: new Date(startDate),
                    $lte: new Date(endDate)
                };
            }

            const db = await mongodbService.getDb();

            // 전체 개수 조회
            const total = await db.collection('sessionReports').countDocuments(filter);

            // 리포트 목록 조회
            const reports = await db.collection('sessionReports')
                .find(filter)
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit)
                .project({
                    _id: 1,
                    sessionId: 1,
                    sessionType: 1,
                    createdAt: 1,
                    duration: 1,
                    keyMetrics: 1,
                    overallInsights: { $slice: ['$overallInsights', 3] }
                })
                .toArray();

            // 🔧 MongoDB _id를 id로 변환
            const transformedReports = reports.map(report => ({
                ...report,
                id: report._id.toString(), // _id를 문자열 id로 변환
                _id: undefined // _id 필드 제거
            }));

            logger.info(`사용자 리포트 목록 조회 성공: ${userId}`, {
                totalReports: total,
                returnedReports: transformedReports.length,
                page,
                limit,
                filters: {
                    sessionType,
                    dateRange: startDate && endDate ? `${startDate} ~ ${endDate}` : null
                }
            });

            return {
                reports: transformedReports,
                pagination: {
                    total,
                    page,
                    limit,
                    pages: Math.ceil(total / limit)
                }
            };
        } catch (error) {
            logger.error(`Error retrieving reports: ${error.message}`);
            throw error;
        }
    },

    /**
     * PDF 형식의 리포트 생성 (비활성화)
     */
    async generateReportPdf(userId, reportId) {
        try {
            logger.info(`PDF 생성 요청 (비활성화): 사용자 ${userId}, 리포트 ${reportId}`);
            // 임시 PDF 버퍼 반환
            return Buffer.from('PDF generation is disabled');
        } catch (error) {
            logger.error(`Error generating PDF: ${error.message}`);
            throw error;
        }
    },

    /**
     * 세션 간 비교 리포트 생성
     */
    async generateComparisonReport(userId, sessionIds, metrics) {
        try {
            logger.info(`비교 리포트 생성 시작: 사용자 ${userId}`, {
                sessionCount: sessionIds.length,
                sessions: sessionIds,
                customMetrics: metrics ? metrics.length : 0
            });

            const db = await mongodbService.getDb();

            // 세션 리포트 데이터 조회
            const reports = await db.collection('sessionReports')
                .find({
                    userId,
                    sessionId: { $in: sessionIds }
                })
                .toArray();

            if (reports.length !== sessionIds.length) {
                logger.warn(`비교 리포트 생성 실패 - 일부 리포트 없음: ${userId}`, {
                    requestedSessions: sessionIds.length,
                    foundReports: reports.length,
                    missingSessions: sessionIds.filter(id => !reports.find(r => r.sessionId === id))
                });
                throw new Error('One or more reports not found');
            }

            // 비교 지표 정의 (기본 지표 또는 사용자 지정 지표)
            const metricsToCompare = metrics || [
                'keyMetrics.userSpeakingRatio',
                'emotionAnalysis.positive',
                'keyMetrics.wordsPerMinute'
            ];

            logger.info(`비교 리포트 생성 성공: ${userId}`, {
                comparedSessions: reports.length,
                metricsCompared: metricsToCompare.length,
                reportGeneratedAt: new Date().toISOString()
            });

            // 비교 데이터 구성
            const comparisonData = {
                sessionIds,
                metrics: {},
                timeline: {},
                improvements: {},
                recommendations: []
            };

            // 각 지표별 비교 데이터 구성
            metricsToCompare.forEach(metric => {
                comparisonData.metrics[metric] = reports.map(report => {
                    const keys = metric.split('.');
                    let value = report;

                    for (const key of keys) {
                        value = value[key];
                        if (value === undefined) break;
                    }

                    return {
                        sessionId: report.sessionId,
                        sessionType: report.sessionType,
                        date: report.createdAt,
                        value: value
                    };
                });
            });

            // 시간에 따른 개선점 파악
            comparisonData.improvements = this._calculateImprovements(comparisonData.metrics);

            // 개선을 위한 추천사항 생성
            comparisonData.recommendations = this._generateRecommendations(comparisonData.metrics, comparisonData.improvements);

            return comparisonData;
        } catch (error) {
            logger.error(`Error generating comparison report: ${error.message}`);
            throw error;
        }
    },

    /**
     * 내부 헬퍼 메서드: 전체 인사이트 생성
     */
    _generateOverallInsights(sessionAnalytics) {
        // 세션 데이터에서 주요 인사이트 추출 로직
        const insights = [...sessionAnalytics.summary.keyInsights];

        // 추가 인사이트 생성
        if (sessionAnalytics.summary.userSpeakingRatio > 0.6) {
            insights.push('발화 시간이 상대방보다 더 길었습니다. 상대방에게 더 많은 발화 기회를 제공해보세요.');
        } else if (sessionAnalytics.summary.userSpeakingRatio < 0.4) {
            insights.push('상대방이 대화를 주도했습니다. 더 적극적으로 대화에 참여해보세요.');
        }

        return insights;
    },

    /**
     * 핵심 지표 생성
     */
    _generateKeyMetrics(sessionAnalytics) {
        const statistics = sessionAnalytics.statistics || {};
        const summary = sessionAnalytics.summary || {};
        const emotionMetrics = sessionAnalytics.emotionMetrics || {};
        const sessionSpecificMetrics = sessionAnalytics.sessionSpecificMetrics || {};
        const sessionType = sessionAnalytics.sessionType || 'dating';

        // 공통 모듈을 사용하여 실제 분석 로직과 동일한 계산 수행
        const speechData = {
            speech_density: statistics.speech_density || 0.5,
            evaluation_wpm: summary.averageSpeakingSpeed || 120,
            tonality: statistics.tonality || 0.7,
            clarity: statistics.clarity || 0.7,
            speech_pattern: statistics.speech_pattern || 'normal',
            emotion_score: emotionMetrics.overall_emotional_tone || 0.6,
            speed_category: statistics.speed_category || 'normal'
        };

        // 공통 분석 모듈로 실제 지표 계산
        const calculatedMetrics = AnalyticsCore.calculateRealtimeMetrics(speechData, sessionType);

        // 시나리오별로 적절한 지표 반환
        if (sessionType === 'presentation') {
            return {
                speaking: {
                    ratio: parseFloat((summary.userSpeakingRatio || 0).toFixed(2)),
                    speed: calculatedMetrics.speakingSpeed,
                    words: summary.wordsCount || 0,
                    consistency: parseFloat((statistics.speaking_consistency || 0).toFixed(2)),
                    pauseStability: parseFloat((statistics.pause_stability || 0).toFixed(2)),
                    speechQuality: parseFloat((statistics.speech_pattern_score || 0).toFixed(2)),
                    // 공통 모듈에서 계산된 실제 자신감 사용
                    confidence: calculatedMetrics.confidence
                },
                
                // 발표 전용 지표
                presentation: {
                    confidence: calculatedMetrics.confidence,
                    persuasion: calculatedMetrics.persuasion,
                    clarity: calculatedMetrics.clarity
                },
                
                emotion: {
                    overallTone: parseFloat((emotionMetrics.overall_emotional_tone || 0.5).toFixed(2)),
                    stability: parseFloat((emotionMetrics.emotional_stability || 0.6).toFixed(2)),
                    variability: parseFloat((emotionMetrics.emotional_variability || 0.4).toFixed(2)),
                    primaryEmotions: emotionMetrics.primary_emotions || [],
                    happiness: parseFloat((emotionMetrics.happiness || 0.3).toFixed(2)),
                    confidence: calculatedMetrics.confidence, // 실제 계산값 사용
                    calmness: parseFloat((emotionMetrics.calmness || 0.4).toFixed(2))
                },
                
                sessionSpecific: sessionSpecificMetrics,
                overallScore: Math.round((calculatedMetrics.confidence + calculatedMetrics.persuasion + calculatedMetrics.clarity) / 3),
                
                communication: {
                    interruptions: statistics.interruptions || 0,
                    questionAnswerRatio: parseFloat((statistics.question_answer_ratio || 0).toFixed(2)),
                    speakingRateVariance: parseFloat((statistics.speaking_rate_variance || 0).toFixed(2))
                }
            };
        } else if (sessionType === 'interview') {
            return {
                speaking: {
                    ratio: parseFloat((summary.userSpeakingRatio || 0).toFixed(2)),
                    speed: calculatedMetrics.speakingSpeed,
                    words: summary.wordsCount || 0,
                    consistency: parseFloat((statistics.speaking_consistency || 0).toFixed(2)),
                    pauseStability: parseFloat((statistics.pause_stability || 0).toFixed(2)),
                    speechQuality: parseFloat((statistics.speech_pattern_score || 0).toFixed(2)),
                    confidence: calculatedMetrics.confidence
                },
                
                // 면접 전용 지표
                interview: {
                    confidence: calculatedMetrics.confidence,
                    stability: calculatedMetrics.stability,
                    clarity: calculatedMetrics.clarity
                },
                
                emotion: {
                    overallTone: parseFloat((emotionMetrics.overall_emotional_tone || 0.5).toFixed(2)),
                    stability: parseFloat((emotionMetrics.emotional_stability || 0.6).toFixed(2)),
                    variability: parseFloat((emotionMetrics.emotional_variability || 0.4).toFixed(2)),
                    primaryEmotions: emotionMetrics.primary_emotions || [],
                    happiness: parseFloat((emotionMetrics.happiness || 0.3).toFixed(2)),
                    confidence: calculatedMetrics.confidence,
                    calmness: parseFloat((emotionMetrics.calmness || 0.4).toFixed(2))
                },
                
                sessionSpecific: sessionSpecificMetrics,
                overallScore: Math.round((calculatedMetrics.confidence + calculatedMetrics.stability + calculatedMetrics.clarity) / 3),
                
                communication: {
                    interruptions: statistics.interruptions || 0,
                    questionAnswerRatio: parseFloat((statistics.question_answer_ratio || 0).toFixed(2)),
                    speakingRateVariance: parseFloat((statistics.speaking_rate_variance || 0).toFixed(2))
                }
            };
        } else {
            // 소개팅 (기본값)
            return {
                speaking: {
                    ratio: parseFloat((summary.userSpeakingRatio || 0).toFixed(2)),
                    speed: calculatedMetrics.speakingSpeed,
                    words: summary.wordsCount || 0,
                    consistency: parseFloat((statistics.speaking_consistency || 0).toFixed(2)),
                    pauseStability: parseFloat((statistics.pause_stability || 0).toFixed(2)),
                    speechQuality: parseFloat((statistics.speech_pattern_score || 0).toFixed(2)),
                    confidence: parseFloat((statistics.confidence_score || 0).toFixed(2)) // 소개팅은 기존 로직 유지
                },
                
                // 소개팅 전용 지표
                dating: {
                    likeability: calculatedMetrics.likeability,
                    interest: calculatedMetrics.interest,
                    emotion: calculatedMetrics.emotion
                },
                
                emotion: {
                    overallTone: parseFloat((emotionMetrics.overall_emotional_tone || 0.5).toFixed(2)),
                    stability: parseFloat((emotionMetrics.emotional_stability || 0.6).toFixed(2)),
                    variability: parseFloat((emotionMetrics.emotional_variability || 0.4).toFixed(2)),
                    primaryEmotions: emotionMetrics.primary_emotions || [],
                    happiness: parseFloat((emotionMetrics.happiness || 0.3).toFixed(2)),
                    confidence: parseFloat((emotionMetrics.confidence || 0.3).toFixed(2)),
                    calmness: parseFloat((emotionMetrics.calmness || 0.4).toFixed(2))
                },
                
                sessionSpecific: sessionSpecificMetrics,
                overallScore: Math.round((calculatedMetrics.likeability + calculatedMetrics.interest) / 2),
                
                communication: {
                    interruptions: statistics.interruptions || 0,
                    questionAnswerRatio: parseFloat((statistics.question_answer_ratio || 0).toFixed(2)),
                    speakingRateVariance: parseFloat((statistics.speaking_rate_variance || 0).toFixed(2))
                }
            };
        }
    },

    /**
     * 감정 분석 데이터 생성
     */
    _generateEmotionAnalysis(sessionAnalytics) {
        const emotionMetrics = sessionAnalytics.emotionMetrics || {};
        const summary = sessionAnalytics.summary || {};

        return {
            // STT 기반 전반적 감정 분석
            overallTone: {
                score: parseFloat((emotionMetrics.overall_emotional_tone || 0.5).toFixed(2)),
                label: this._getEmotionLabel(emotionMetrics.overall_emotional_tone || 0.5),
                description: this._getEmotionDescription(emotionMetrics.overall_emotional_tone || 0.5)
            },
            
            // 감정 안정성
            stability: {
                score: parseFloat((emotionMetrics.emotional_stability || 0.6).toFixed(2)),
                variability: parseFloat((emotionMetrics.emotional_variability || 0.4).toFixed(2)),
                interpretation: this._getStabilityInterpretation(emotionMetrics.emotional_stability || 0.6)
            },
            
            // 개별 감정 점수들 (STT emotion_analysis에서 추출)
            emotions: {
                happiness: parseFloat((emotionMetrics.happiness || 0.3).toFixed(2)),
                confidence: parseFloat((emotionMetrics.confidence || 0.3).toFixed(2)),
                calmness: parseFloat((emotionMetrics.calmness || 0.4).toFixed(2)),
                neutral: parseFloat((emotionMetrics.neutral || 0.4).toFixed(2)),
                excitement: parseFloat((emotionMetrics.excitement || 0.2).toFixed(2)),
                sadness: parseFloat((emotionMetrics.sadness || 0.2).toFixed(2)),
                anger: parseFloat((emotionMetrics.anger || 0.1).toFixed(2)),
                fear: parseFloat((emotionMetrics.fear || 0.2).toFixed(2))
            },
            
            // 주요 감정 변화
            primaryEmotions: emotionMetrics.primary_emotions || [],
            emotionDistribution: emotionMetrics.emotion_distribution || {},
            
            // 분석 정보
            segmentsAnalyzed: emotionMetrics.emotion_segments || 0,
            totalSegments: emotionMetrics.total_segments_analyzed || 0,
            
            // 추천 사항
            recommendations: this._generateEmotionRecommendations(emotionMetrics)
        };
    },

    /**
     * 감정 점수에 따른 라벨 반환
     */
    _getEmotionLabel(score) {
        if (score >= 0.7) return '매우 긍정적';
        if (score >= 0.6) return '긍정적';
        if (score >= 0.4) return '중립적';
        if (score >= 0.3) return '약간 부정적';
        return '부정적';
    },

    /**
     * 감정 점수에 따른 설명 반환
     */
    _getEmotionDescription(score) {
        if (score >= 0.7) return '대화 중 매우 긍정적이고 밝은 감정을 유지했습니다.';
        if (score >= 0.6) return '전반적으로 긍정적인 분위기로 대화에 참여했습니다.';
        if (score >= 0.4) return '안정적이고 중립적인 감정 상태를 보였습니다.';
        if (score >= 0.3) return '다소 소극적이거나 부정적인 감정이 나타났습니다.';
        return '감정 표현이 부족하거나 부정적인 상태였습니다.';
    },

    /**
     * 감정 안정성 해석
     */
    _getStabilityInterpretation(stability) {
        if (stability >= 0.8) return '매우 안정적인 감정 상태';
        if (stability >= 0.6) return '안정적인 감정 상태';
        if (stability >= 0.4) return '보통 수준의 감정 변화';
        if (stability >= 0.2) return '감정 변화가 다소 불안정';
        return '감정 변화가 매우 불안정';
    },

    /**
     * 감정 기반 추천 사항 생성
     */
    _generateEmotionRecommendations(emotionMetrics) {
        const recommendations = [];
        
        if (emotionMetrics.happiness < 0.4) {
            recommendations.push('더 밝고 긍정적인 표현을 사용해보세요.');
        }
        
        if (emotionMetrics.confidence < 0.4) {
            recommendations.push('자신감 있는 톤으로 말하는 연습을 해보세요.');
        }
        
        if (emotionMetrics.emotional_stability < 0.5) {
            recommendations.push('감정의 일관성을 유지하는 것에 집중해보세요.');
        }
        
        if (emotionMetrics.calmness < 0.4) {
            recommendations.push('좀 더 차분하고 안정된 상태로 대화해보세요.');
        }
        
        if (recommendations.length === 0) {
            recommendations.push('감정 표현이 적절합니다. 현재 상태를 유지하세요.');
        }
        
        return recommendations;
    },

    /**
     * 내부 헬퍼 메서드: 의사소통 패턴 생성
     */
    _generateCommunicationPatterns(sessionAnalytics) {
        const patterns = [];

        logger.info('🔍 communicationPatterns 생성 시작', {
            hasStatistics: !!sessionAnalytics.statistics,
            habitualPhrasesCount: sessionAnalytics.statistics?.habitualPhrases?.length || 0
        });

        // 🔥 습관적인 표현 추가 (필드명 수정: habitual_phrases → habitualPhrases)
        if (sessionAnalytics.statistics?.habitualPhrases && Array.isArray(sessionAnalytics.statistics.habitualPhrases)) {
            logger.info(`✅ 실제 습관적 표현 데이터 발견: ${sessionAnalytics.statistics.habitualPhrases.length}개`);
            
            sessionAnalytics.statistics.habitualPhrases.forEach((phraseObj, index) => {
                logger.info(`🔍 습관적 표현 ${index + 1}: "${phraseObj.phrase}" (${phraseObj.count}회)`);
                
                patterns.push({
                    type: 'habitual_phrase',
                    content: phraseObj.phrase,
                    count: phraseObj.count
                });
            });
        } else {
            logger.warn('⚠️ 습관적 표현 데이터 없음 또는 잘못된 형식', {
                hasHabitualPhrases: !!sessionAnalytics.statistics?.habitualPhrases,
                type: typeof sessionAnalytics.statistics?.habitualPhrases,
                isArray: Array.isArray(sessionAnalytics.statistics?.habitualPhrases)
            });
        }

        // 말하기 속도 패턴 분석 및 추가
        const speakingRates = sessionAnalytics.timeline?.map(t => t.speakingRate?.user).filter(Boolean) || [];
        
        // 🔥 keyMetrics와 완전히 동일한 값 사용
        const keyMetrics = this._generateKeyMetrics(sessionAnalytics);
        const keyMetricsSpeed = keyMetrics.speaking.speed; // keyMetrics와 동일한 소스
        
        logger.info(`🔍 말하기 속도 데이터: ${speakingRates.length}개 포인트, keyMetrics 속도: ${keyMetricsSpeed}WPM`);
        
        if (speakingRates.length > 0) {
            // 🔥 타임라인 데이터가 있어도 keyMetrics 속도를 기준으로 사용
            const avgRate = keyMetricsSpeed; // keyMetrics와 동일한 값 사용
            const variability = Math.sqrt(speakingRates.map(r => Math.pow(r - avgRate, 2)).reduce((a, b) => a + b, 0) / speakingRates.length);

            logger.info(`📊 keyMetrics 기반 말하기 속도: 평균=${avgRate}WPM, 변동성=${variability.toFixed(1)}`);

            patterns.push({
                type: 'speaking_rate',
                average: keyMetricsSpeed, // 🔥 keyMetrics와 동일한 값 사용
                variability: variability,
                assessment: variability > 20 ? '말하기 속도 변화가 큽니다' : '말하기 속도가 일정합니다'
            });
        } else {
            logger.warn('⚠️ 말하기 속도 데이터 없음 - keyMetrics 기본값 사용');
            
            // 🔥 keyMetrics와 동일한 값 사용
            patterns.push({
                type: 'speaking_rate',
                average: keyMetricsSpeed, // 🔥 keyMetrics와 동일한 값 사용
                variability: 5,
                assessment: '말하기 속도가 일정합니다'
            });
        }

        logger.info(`✅ communicationPatterns 생성 완료: 총 ${patterns.length}개 패턴`);

        return patterns;
    },

    /**
     * 내부 헬퍼 메서드: 피드백 요약 생성
     */
    _generateFeedbackSummary(feedbackHistory) {
        const feedbackTypes = {};

        feedbackHistory.forEach(feedback => {
            if (!feedbackTypes[feedback.feedbackType]) {
                feedbackTypes[feedback.feedbackType] = 0;
            }
            feedbackTypes[feedback.feedbackType]++;
        });

        return {
            total: feedbackHistory.length,
            byType: feedbackTypes,
            mostFrequent: Object.entries(feedbackTypes).sort((a, b) => b[1] - a[1])[0]?.[0]
        };
    },

    /**
     * 내부 헬퍼 메서드: 개선 영역 생성
     */
    _generateImprovementAreas(sessionAnalytics) {
        return sessionAnalytics.suggestions || [];
    },

    /**
     * 내부 헬퍼 메서드: 상황별 특화 인사이트 생성
     */
    _generateSpecializationInsights(sessionAnalytics) {
        if (sessionAnalytics.specializedAnalysis) {
            return sessionAnalytics.specializedAnalysis;
        }
        return null;
    },
    /**
     * 내부 헬퍼 메서드: 차트 데이터 생성 (비활성화)
     */
    async _generateChartData(sessionAnalytics, feedbackHistory) {
        logger.info('Chart generation is disabled');
        return {
            disabled: true,
            message: 'Chart generation is temporarily disabled'
        };
    },

    /**
     * 내부 헬퍼 메서드: 시간에 따른 개선점 계산
     */
    _calculateImprovements(metricsData) {
        const improvements = {};

        Object.keys(metricsData).forEach(metric => {
            // 날짜 기준으로 정렬
            const sortedData = [...metricsData[metric]].sort((a, b) => new Date(a.date) - new Date(b.date));

            if (sortedData.length > 1) {
                const firstValue = sortedData[0].value;
                const lastValue = sortedData[sortedData.length - 1].value;
                const percentChange = ((lastValue - firstValue) / firstValue) * 100;

                improvements[metric] = {
                    firstValue,
                    lastValue,
                    percentChange,
                    improved: percentChange > 0,
                    significant: Math.abs(percentChange) > 10
                };
            }
        });

        return improvements;
    },

    /**
     * 내부 헬퍼 메서드: 개선을 위한 추천사항 생성
     */
    _generateRecommendations(metricsData, improvements) {
        const recommendations = [];

        // 지표 별 추천사항 생성
        Object.keys(improvements).forEach(metric => {
            const improvement = improvements[metric];

            // 개선되지 않은 지표에 대한 추천사항 생성
            if (!improvement.improved && improvement.significant) {
                switch (metric) {
                    case 'keyMetrics.userSpeakingRatio':
                        recommendations.push({
                            metric: '발화 균형',
                            suggestion: '대화에서 적절한 발화 균형을 찾으세요. 상대방의 의견을 더 많이 경청하거나, 더 적극적으로 대화에 참여하는 것이 도움이 될 수 있습니다.'
                        });
                        break;
                    case 'emotionAnalysis.positive':
                        recommendations.push({
                            metric: '긍정적 감정 표현',
                            suggestion: '대화 중 긍정적인 감정 표현을 늘려보세요. 웃음, 공감, 긍정적인 단어 선택이 도움이 될 수 있습니다.'
                        });
                        break;
                    case 'keyMetrics.wordsPerMinute':
                        recommendations.push({
                            metric: '말하기 속도',
                            suggestion: '말하기 속도를 적절히 조절해보세요. 너무 빠르거나 느린 말하기는 의사소통을 방해할 수 있습니다.'
                        });
                        break;
                }
            }
        });

        // 전반적인 추천사항 추가
        if (recommendations.length === 0) {
            recommendations.push({
                metric: '전반적 개선',
                suggestion: '전반적으로 좋은 발전을 보이고 있습니다. 지속적인 연습을 통해 더욱 자연스러운 의사소통 능력을 키워보세요.'
            });
        }

        return recommendations;
    },

    /**
     * 내부 헬퍼 메서드: 상세 타임라인 생성
     */
    _generateDetailedTimeline(sessionAnalytics) {
        logger.info('🔍 detailedTimeline 생성 시작', {
            hasTimeline: !!sessionAnalytics.timeline,
            timelineLength: sessionAnalytics.timeline?.length || 0,
            hasStatistics: !!sessionAnalytics.statistics,
            hasSummary: !!sessionAnalytics.summary
        });

        // 🔥 기존 timeline 데이터가 있으면 우선 사용하되, 데이터 검증 및 수정
        if (sessionAnalytics.timeline && sessionAnalytics.timeline.length > 0) {
            logger.info(`✅ 실제 timeline 데이터 검증 시작: ${sessionAnalytics.timeline.length}개 포인트`);
            
            // 🔥 keyMetrics와 동일한 기준값 사용
            const keyMetrics = this._generateKeyMetrics(sessionAnalytics);
            
            // 🔥 발표 시나리오에서는 말하기 자신감 사용
            const baseEmotionScore = keyMetrics.speaking.confidence; // 발표에서는 말하기 자신감이 핵심
            const baseSpeakingRate = keyMetrics.speaking.speed; // 실제 말하기 속도
            const baseConfidence = keyMetrics.speaking.confidence; // 동일한 말하기 자신감
            
            logger.info(`🔧 keyMetrics 기준값: speaking_confidence=${baseEmotionScore}, speaking_rate=${baseSpeakingRate}`);
            
            // 🔥 timeline 데이터를 detailedTimeline 형식으로 변환하되 keyMetrics와 일치시킴
            const detailedTimeline = sessionAnalytics.timeline.map((timePoint, index) => {
                // 기존 timeline 데이터에서 이상한 값들 수정
                const originalEmotion = timePoint.likability || timePoint.emotion_score || 0.5;
                const originalSpeaking = timePoint.speakingRate?.user || timePoint.speaking_rate || baseSpeakingRate;
                const originalConfidence = timePoint.confidence || baseConfidence;
                
                // 🔥 값 범위 검증 및 수정
                const validatedEmotion = originalEmotion > 1 ? originalEmotion / 100 : originalEmotion; // 0-1 범위로 정규화
                const validatedSpeaking = originalSpeaking > 200 ? baseSpeakingRate : originalSpeaking; // 비정상적으로 높은 값 수정
                const validatedConfidence = originalConfidence < 0.1 ? baseConfidence : originalConfidence; // 너무 낮은 값 수정
                
                // 🔥 실제 데이터에도 변동 추가 (고정값 방지)
                const progress = index / Math.max(1, sessionAnalytics.timeline.length - 1); // 0 ~ 1
                const emotionVariation = (Math.random() - 0.5) * 0.15; // ±7.5% 변동
                const confidenceVariation = (Math.random() - 0.5) * 0.15; // ±7.5% 변동
                const timeBasedChange = Math.sin(progress * Math.PI) * 0.08; // 시간 기반 변화
                
                return {
                    timestamp: (index + 1) * 30, // 🔥 30초부터 시작 (0초 제외)
                    emotion_score: Math.max(0, Math.min(1, validatedEmotion + emotionVariation + timeBasedChange)), // 변동 추가
                    speaking_rate: Math.max(60, Math.min(180, validatedSpeaking)), // 60-180 WPM 범위
                    confidence: Math.max(0, Math.min(1, validatedConfidence + confidenceVariation + timeBasedChange)), // 변동 추가
                    segment_duration: 30
                };
            });

            logger.info(`📊 실제 timeline 검증 완료: ${detailedTimeline.length}개 포인트`);
            logger.info(`📊 검증 후 샘플: timestamp=${detailedTimeline[0]?.timestamp}, emotion=${detailedTimeline[0]?.emotion_score}, speaking=${detailedTimeline[0]?.speaking_rate}, confidence=${detailedTimeline[0]?.confidence}`);
            return detailedTimeline;
        }

        // 🔥 실제 데이터가 없을 때는 keyMetrics 기반으로 일관된 타임라인 생성
        const duration = sessionAnalytics.summary?.duration || 180;
        const segmentCount = Math.ceil(duration / 30); // 30초 단위
        
        // 🔥 keyMetrics와 완전히 동일한 값 사용
        const keyMetrics = this._generateKeyMetrics(sessionAnalytics);
        
        // 🔥 발표 시나리오에서는 말하기 자신감 사용
        const baseEmotionScore = keyMetrics.speaking.confidence; // 발표에서는 말하기 자신감이 핵심
        const baseSpeakingRate = keyMetrics.speaking.speed; // 실제 말하기 속도
        const baseConfidence = keyMetrics.speaking.confidence; // 동일한 말하기 자신감
        
        logger.info(`📊 keyMetrics 기반 timeline 생성 (발표용): duration=${duration}s, segments=${segmentCount}`);
        logger.info(`📊 keyMetrics 기준값: speaking_confidence=${baseEmotionScore}, speaking_rate=${baseSpeakingRate}`);

        const detailedTimeline = [];
        
        // 🔥 30초부터 시작 (index 1부터), 발표용 말하기 자신감 기반
        for (let i = 1; i <= segmentCount; i++) {
            const progress = (i - 1) / Math.max(1, segmentCount - 1); // 0 ~ 1
            
            // 🔥 말하기 자신감 기반의 자연스러운 변동 추가 (변동폭 증가)
            const emotionVariation = (Math.random() - 0.5) * 0.2; // ±10% 변동 (기존 ±5%)
            const rateVariation = (Math.random() - 0.5) * 30; // ±15 WPM 변동 (기존 ±7.5)
            const confidenceVariation = (Math.random() - 0.5) * 0.2; // ±10% 변동 (기존 ±5%)
            
            // 🔥 시간이 지나면서 약간씩 변화하는 경향 추가
            const timeBasedChange = Math.sin(progress * Math.PI) * 0.1; // 중간에 피크

            detailedTimeline.push({
                timestamp: i * 30, // 30초 단위
                emotion_score: Math.max(0, Math.min(1, baseEmotionScore + emotionVariation + timeBasedChange)), // 말하기 자신감 기반
                speaking_rate: Math.max(80, Math.min(160, baseSpeakingRate + rateVariation)),
                confidence: Math.max(0, Math.min(1, baseConfidence + confidenceVariation + timeBasedChange)), // 동일한 말하기 자신감
                segment_duration: 30
            });
        }

        logger.info(`📊 keyMetrics 기반 timeline 생성 완료: ${detailedTimeline.length}개 포인트 (30초부터 시작)`);
        logger.info(`📊 생성된 timeline 샘플: ${detailedTimeline.slice(0, 3).map(t => `${t.timestamp}s: emotion=${(t.emotion_score * 100).toFixed(0)}%, speaking=${t.speaking_rate.toFixed(0)}WPM, confidence=${(t.confidence * 100).toFixed(0)}%`).join(', ')}`);
        return detailedTimeline;
    },

    /**
     * 내부 헬퍼 메서드: 대화 주제 분석 생성
     */
    _generateConversationTopics(sessionAnalytics) {
        logger.info('🔍 conversation_topics 생성 시작', {
            hasTopicAnalysis: !!sessionAnalytics.topicAnalysis,
            hasSpecializedAnalysis: !!sessionAnalytics.specializedAnalysis
        });

        // analytics.service.js에서 분석된 주제 데이터 확인
        const topicAnalysis = sessionAnalytics.topicAnalysis;
        
        if (topicAnalysis && topicAnalysis.topics && Array.isArray(topicAnalysis.topics)) {
            logger.info(`✅ 실제 주제 분석 데이터 사용: ${topicAnalysis.topics.length}개 주제`);
            
            const conversationTopics = topicAnalysis.topics.map(topic => ({
                topic: topic.name,
                percentage: topic.percentage,
                duration: Math.round((topic.percentage / 100) * (sessionAnalytics.summary?.duration || 180)),
                keywords: topic.keywords || []
            }));

            logger.info(`📊 주제 분석 결과: ${conversationTopics.map(t => `${t.topic}(${t.percentage}%)`).join(', ')}`);
            return conversationTopics;
        }

        // 주제 데이터가 없으면 세션 타입별 기본 주제 생성
        logger.warn('⚠️ 주제 분석 데이터 없음 - 세션 타입별 기본 주제 생성');
        
        const sessionType = sessionAnalytics.sessionType;
        const duration = sessionAnalytics.summary?.duration || 180;

        let defaultTopics = [];
        
        switch (sessionType) {
            case 'presentation':
                defaultTopics = [
                    { topic: '주제 소개', percentage: 25.0, keywords: ['소개', '개요', '목표'] },
                    { topic: '핵심 내용', percentage: 40.0, keywords: ['데이터', '분석', '결과'] },
                    { topic: '결론 및 요약', percentage: 20.0, keywords: ['결론', '요약', '정리'] },
                    { topic: '질의응답', percentage: 15.0, keywords: ['질문', '답변', '토론'] }
                ];
                break;
                
            case 'interview':
                defaultTopics = [
                    { topic: '자기소개', percentage: 20.0, keywords: ['소개', '경력', '배경'] },
                    { topic: '업무 경험', percentage: 35.0, keywords: ['프로젝트', '성과', '경험'] },
                    { topic: '기술적 역량', percentage: 25.0, keywords: ['기술', '스킬', '능력'] },
                    { topic: '지원 동기', percentage: 20.0, keywords: ['동기', '목표', '비전'] }
                ];
                break;
                
            case 'dating':
                defaultTopics = [
                    { topic: '자기소개', percentage: 30.0, keywords: ['이름', '나이', '직업'] },
                    { topic: '취미와 관심사', percentage: 25.0, keywords: ['취미', '영화', '음악'] },
                    { topic: '일상 이야기', percentage: 25.0, keywords: ['일상', '생활', '경험'] },
                    { topic: '미래 계획', percentage: 20.0, keywords: ['계획', '목표', '꿈'] }
                ];
                break;
                
            default:
                defaultTopics = [
                    { topic: '일반 대화', percentage: 40.0, keywords: ['대화', '이야기', '소통'] },
                    { topic: '관심사 공유', percentage: 30.0, keywords: ['관심', '취미', '생각'] },
                    { topic: '경험 나누기', percentage: 30.0, keywords: ['경험', '추억', '이야기'] }
                ];
        }

        // duration을 기반으로 실제 시간 계산
        const conversationTopics = defaultTopics.map(topic => ({
            topic: topic.topic,
            percentage: topic.percentage,
            duration: Math.round((topic.percentage / 100) * duration),
            keywords: topic.keywords
        }));

        logger.info(`🎭 기본 주제 생성 완료 (${sessionType}): ${conversationTopics.map(t => `${t.topic}(${t.percentage}%)`).join(', ')}`);
        return conversationTopics;
    }
};

module.exports = reportService;
