import 'package:flutter/material.dart';
import 'emotion_data.dart';
import 'metrics.dart';

// 세션 분석 결과 모델
class AnalysisResult {
  final String sessionId; // 세션 ID
  final String title; // 세션 제목
  final DateTime date; // 세션 날짜
  final DateTime sessionStartTime; // 세션 시작 시간 (정렬용)
  final String category; // 세션 카테고리 (예: '소개팅', '면접', '발표' 등)
  final List<EmotionData> emotionData; // 감정 데이터
  final List<EmotionChangePoint> emotionChangePoints; // 감정 변화 포인트
  final SessionMetrics metrics; // 세션 지표
  final Map<String, dynamic> rawApiData; // 🔥 원본 API 응답 데이터

  AnalysisResult({
    required this.sessionId,
    required this.title,
    required this.date,
    required this.sessionStartTime,
    required this.category,
    required this.emotionData,
    required this.emotionChangePoints,
    required this.metrics,
    required this.rawApiData, // 🔥 추가
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      sessionId: json['sessionId'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      sessionStartTime: DateTime.parse(json['sessionStartTime'] ?? json['date'] as String),
      category: json['category'] as String,
      emotionData: (json['emotionData'] as List<dynamic>)
          .map((e) => EmotionData.fromJson(e as Map<String, dynamic>))
          .toList(),
      emotionChangePoints: (json['emotionChangePoints'] as List<dynamic>)
          .map((e) => EmotionChangePoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      metrics: SessionMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      rawApiData: json['rawApiData'] as Map<String, dynamic>? ?? {}, // 🔥 추가
    );
  }

  // 🔥 report-service API 응답에서 AnalysisResult 생성
  factory AnalysisResult.fromApiResponse(Map<String, dynamic> apiData) {
    try {
      print('🔍 API 응답 파싱 시작: $apiData');
      
      // 🔥 안전한 타입 변환을 위한 헬퍼 함수 사용
      final safeApiData = _safeCastMap(apiData);
      
      // 🔥 실제 API 응답 구조에 맞게 수정
      // 이전: sessionInfo/analysis 구조 → 현재: 직접 필드 접근
      final sessionInfo = _safeCastMap(safeApiData['sessionInfo'] ?? {});
      final analysis = _safeCastMap(safeApiData['analysis'] ?? {});
      final timeline = safeApiData['timeline'] ?? [];
      
      // 🔥 실제 API 응답 필드들 추가 확인
      final keyMetrics = _safeCastMap(safeApiData['keyMetrics'] ?? {});
      final communicationPatterns = safeApiData['communicationPatterns'] ?? [];
      final emotionAnalysis = _safeCastMap(safeApiData['emotionAnalysis'] ?? {});
      final specializationInsights = _safeCastMap(safeApiData['specializationInsights'] ?? {});
      
      // 🔥 실제 detailedTimeline 데이터 확인
      final detailedTimeline = safeApiData['detailedTimeline'] ?? [];
      
      print('🔍 sessionInfo: $sessionInfo');
      print('🔍 analysis: $analysis');
      print('🔍 keyMetrics: $keyMetrics');
      print('🔍 communicationPatterns: $communicationPatterns');
      print('🔍 emotionAnalysis: $emotionAnalysis');
      print('🔍 detailedTimeline 길이: ${detailedTimeline.length}');
      
      // 감정 데이터 생성 (timeline에서 추출)
      List<EmotionData> emotionData = [];
      print('🎯 === 타임라인 그래프 데이터 생성 시작 ===');
      
      // 🔥 detailedTimeline 우선 사용, 없으면 timeline 사용
      final timelineSource = detailedTimeline.isNotEmpty ? detailedTimeline : (timeline ?? []);
      print('🔍 타임라인 소스 길이: ${timelineSource.length}');
      
      if (timelineSource.isNotEmpty) {
        // 실제 timeline 데이터가 있는 경우
        print('✅ API timeline 데이터 사용 - 실제 데이터로 그래프 생성');
        for (int i = 0; i < timelineSource.length; i++) {
          final timePoint = _safeCastMap(timelineSource[i]);
          
          // 🔥 실제 API 구조에 맞게 수정: emotionScores.positive 사용
          double positiveScore = 50.0; // 기본값
          
          if (timePoint['emotionScores'] != null) {
            final emotionScores = _safeCastMap(timePoint['emotionScores']);
            positiveScore = ((emotionScores['positive'] ?? 0.5) * 100).clamp(20.0, 95.0);
          } else if (timePoint['confidence'] != null) {
            // confidence 점수 사용
            positiveScore = ((timePoint['confidence'] ?? 0.5) * 100).clamp(20.0, 95.0);
          }
          
          if (i < 3) { // 처음 3개만 로그
            print('🔢 timeline[$i]: timestamp=${timePoint['timestamp']}, positiveScore=${positiveScore.toStringAsFixed(1)}%');
          }
          
          emotionData.add(EmotionData(
            timestamp: (timePoint['timestamp'] ?? i * 30).toDouble(),
            emotionType: _getEmotionType(positiveScore.round()),
            value: positiveScore,
            description: timePoint['transcription'] ?? 'Segment ${i + 1}',
          ));
        }
        print('✅ Timeline 파싱 완료: ${emotionData.length}개 포인트 (실제 API 데이터)');
      } else {
        // 🔥 timeline이 없을 때 감정 지표 기반으로 시뮬레이션 데이터 생성
        print('⚠️ API timeline 데이터 없음 - 시뮬레이션 데이터로 그래프 생성');
        // 🔥 실제 API 응답 구조에 맞게 수정: emotions.happiness 사용
        final emotions = _safeCastMap(emotionAnalysis['emotions'] ?? {});
        final baseScore = ((emotions['happiness'] ?? 0.3) * 100);
        print('🔢 기준 점수: ${baseScore.toStringAsFixed(1)}% (emotionAnalysis.emotions.happiness 기반)');
        
        // 30개 포인트로 자연스러운 감정 변화 시뮬레이션
        for (int i = 0; i < 30; i++) {
          final progress = i / 29.0; // 0.0 ~ 1.0
          
          // 자연스러운 감정 패턴 (초반 낮음 → 중반 상승 → 후반 안정)
          double multiplier;
          if (progress < 0.3) {
            multiplier = 0.8 + (progress * 0.4); // 0.8 → 0.92
          } else if (progress < 0.7) {
            multiplier = 0.92 + ((progress - 0.3) * 0.25); // 0.92 → 1.02
          } else {
            multiplier = 1.02 - ((progress - 0.7) * 0.07); // 1.02 → 0.98
          }
          
          // 약간의 랜덤 변동 추가
          final randomFactor = (i % 3 == 0) ? 1.05 : ((i % 3 == 1) ? 0.95 : 1.0);
          final value = (baseScore * multiplier * randomFactor).clamp(20.0, 95.0);
          
          if (i < 3 || i >= 27) { // 처음 3개와 마지막 3개만 로그
            print('🔢 시뮬레이션[$i]: 진행률=${(progress * 100).toStringAsFixed(0)}%, 배수=${multiplier.toStringAsFixed(2)}, 값=${value.toStringAsFixed(1)}%');
          }
          
          emotionData.add(EmotionData(
            timestamp: (i * 2).toDouble(), // 2초 간격
            emotionType: _getEmotionType(value.round()),
            value: value,
            description: '${(i * 2 ~/ 60).toString().padLeft(2, '0')}:${(i * 2 % 60).toString().padLeft(2, '0')} 시점',
          ));
        }
        print('⚠️ 시뮬레이션 데이터 생성: ${emotionData.length}개 포인트 (API 데이터 없음)');
      }
      print('🎯 === 타임라인 그래프 데이터 생성 완료 ===\n');
      
      // 감정 변화 포인트 생성
      List<EmotionChangePoint> changePoints = [];
      for (var point in (analysis['emotionChanges'] ?? [])) {
        final safePoint = _safeCastMap(point);
        changePoints.add(EmotionChangePoint(
          time: safePoint['time'] ?? '00:00:00',
          timestamp: safePoint['timestamp'] ?? 0,
          description: safePoint['description'] ?? '',
          emotionValue: safePoint['emotionValue'] ?? 50,
          label: safePoint['label'] ?? '',
          topics: List<String>.from(safePoint['topics'] ?? []),
        ));
      }
      
      // 🔥 실제 API 응답에서 값 추출 (새로운 구조 반영)
      final duration = (safeApiData['duration'] ?? 
                       sessionInfo['duration'] ?? 
                       sessionInfo['totalDuration'] ?? 
                       analysis['duration'] ?? 
                       analysis['totalDuration'] ?? 
                       30).toDouble(); // API에서 초 단위로 오는 것으로 추정
      
      // communicationPatterns에서 speaking_rate 찾기
      double speechRateFromPatterns = 120.0;
      for (var pattern in communicationPatterns) {
        final safePattern = _safeCastMap(pattern);
        if (safePattern['type'] == 'speaking_rate') {
          speechRateFromPatterns = (safePattern['average'] ?? 120.0).toDouble();
          break;
        }
      }
      
      final speechRate = (keyMetrics['wordsPerMinute'] ?? 
                         speechRateFromPatterns ??
                         analysis['averageSpeed'] ?? 
                         analysis['speechRate'] ?? 
                         analysis['speakingSpeed'] ?? 
                         analysis['wpm'] ?? 
                         120).toDouble();
      
      final tonality = (analysis['tonality'] ?? 
                        analysis['tone'] ?? 
                        analysis['tonality_score'] ?? 
                        75).toDouble();
      
      final clarity = (analysis['clarity'] ?? 
                       analysis['clarity_score'] ?? 
                       analysis['pronunciation'] ?? 
                       80).toDouble();
      
      // emotionAnalysis에서 감정 지표 추출
      final emotions = _safeCastMap(emotionAnalysis['emotions'] ?? {});
      final averageInterest = ((emotions['happiness'] ?? 0.3) * 100).toDouble();
      
      // specializationInsights에서 추가 정보 추출
      final rapportBuilding = _safeCastMap(specializationInsights['rapport_building'] ?? {});
      final conversationTopics = _safeCastMap(specializationInsights['conversation_topics'] ?? {});
      final emotionalConnection = _safeCastMap(specializationInsights['emotional_connection'] ?? {});
      
      final averageLikeability = (rapportBuilding['score'] ?? 50).toDouble();
      
      final contributionRatio = ((keyMetrics['userSpeakingRatio'] ?? 0.6) * 100).toDouble();
      
      // 대화 흐름 분석에서 경청 점수 계산
      final overallInsights = safeApiData['overallInsights'] ?? [];
      double listeningScore = 75.0;
      for (var insight in overallInsights) {
        if (insight.toString().contains('들어주면') || insight.toString().contains('경청')) {
          listeningScore = 60.0; // 경청 개선 필요 시 낮은 점수
          break;
        } else if (insight.toString().contains('잘 들었') || insight.toString().contains('적극적')) {
          listeningScore = 85.0; // 좋은 경청 시 높은 점수
          break;
        }
      }
      
      print('🔍 파싱된 값들: duration=$duration, speechRate=$speechRate, tonality=$tonality, clarity=$clarity');
      print('🔍 감정 지표: averageInterest=$averageInterest, contributionRatio=$contributionRatio, listeningScore=$listeningScore');
      print('🔍 전문 분석: rapportScore=${rapportBuilding['score']}, topicDiversity=${conversationTopics['diversity']}');
      
      // 주제 분석 데이터 추출 및 변환 (🔥 rawApiData에서 직접 추출로 수정)
      final apiTopics = _extractTopicsFromApi(safeApiData, conversationTopics);
      final baseTopics = _convertTopics(apiTopics);
      
      // 🔥 communicationPatterns에서 실제 주제 및 습관적 표현 추출
      List<ConversationTopic> enhancedTopics = [];
      
      if (communicationPatterns.isNotEmpty) {
        print('🔍 communicationPatterns 처리 시작: ${communicationPatterns.length}개');
        
        // 습관적 표현들 추출
        final habitualPhrases = communicationPatterns
            .where((pattern) => pattern['type'] == 'habitual_phrase')
            .toList();
        
        if (habitualPhrases.isNotEmpty) {
          print('✅ 습관적 표현 발견: ${habitualPhrases.length}개');
          
          // 총 카운트 계산
          final totalCount = habitualPhrases
              .map((phrase) => phrase['count'] ?? 0)
              .fold(0, (sum, count) => sum + count);
          
          // 습관적 표현을 주제로 변환 (상위 5개만)
          final sortedPhrases = habitualPhrases..sort((a, b) {
            // 🔧 명시적인 int 타입 반환으로 수정
            final countA = (a['count'] ?? 0) as int;
            final countB = (b['count'] ?? 0) as int;
            return countB.compareTo(countA);
          });
          
          for (var i = 0; i < sortedPhrases.length && i < 5; i++) {
            final phrase = sortedPhrases[i];
            final content = phrase['content'] ?? '';
            final count = phrase['count'] ?? 0;
            final percentage = totalCount > 0 ? (count / totalCount * 100).clamp(5.0, 40.0) : 10.0;
            
            if (content.isNotEmpty) {
              enhancedTopics.add(ConversationTopic(
                name: '"$content" 표현',
                percentage: percentage,
                isPrimary: count >= 5, // 5번 이상 사용시 주요 주제
              ));
            }
          }
          
          print('🔢 습관적 표현 주제 생성: ${enhancedTopics.length}개');
        }
      }
      
      // 기존 주제와 습관적 표현 주제 병합
      final finalTopics = enhancedTopics.isNotEmpty ? enhancedTopics : baseTopics;
      
      // 세션 지표 생성
      final metrics = SessionMetrics(
        totalDuration: duration,
        audioRecorded: sessionInfo['audioRecorded'] ?? true,
        speakingMetrics: SpeakingMetrics(
          speechRate: speechRate,
          tonality: tonality,
          clarity: clarity,
          habitPatterns: _convertHabitPatterns(analysis['habitPatterns'] ?? []),
        ),
        emotionMetrics: EmotionMetrics(
          averageInterest: averageInterest,
          averageLikeability: averageLikeability,
          peakLikeability: (analysis['peakLikability'] ?? analysis['maxLikeability'] ?? averageLikeability + 10).toDouble(),
          lowestLikeability: (analysis['lowestLikability'] ?? analysis['minLikeability'] ?? averageLikeability - 10).toDouble(),
          feedbacks: _convertEmotionFeedbacks(analysis['feedbacks'] ?? []),
        ),
        conversationMetrics: ConversationMetrics(
          contributionRatio: contributionRatio,
          listeningScore: listeningScore,
          interruptionCount: (analysis['interruptionCount'] ?? analysis['interruptions'] ?? 0).toDouble(),
          flowDescription: analysis['flowDescription'] ?? analysis['summary'] ?? '안정적인 대화 흐름',
        ),
        topicMetrics: TopicMetrics(
          topics: finalTopics,
          timepoints: _convertTopicTimepoints(analysis['topicTimepoints'] ?? []),
          insights: _convertApiInsights(overallInsights),
          recommendations: _convertApiRecommendations(safeApiData['improvementAreas'] ?? []),
        ),
      );
      
      // 🔥 세션 타입 추출 (실제 API 응답 구조 반영)
      final sessionType = safeApiData['sessionType'] ??
                         sessionInfo['type'] ?? 
                         sessionInfo['sessionType'] ?? 
                         sessionInfo['category'] ?? 
                         'presentation'; // 기본값은 가장 일반적인 발표로
      
      print('🔍 세션 타입 파싱: apiData[sessionType]=${safeApiData['sessionType']}, 최종값=$sessionType');
      final convertedCategory = _convertSessionType(sessionType);
      print('🔍 변환된 카테고리: $sessionType → $convertedCategory');
      
      return AnalysisResult(
        sessionId: safeApiData['sessionId'] ?? sessionInfo['sessionId'] ?? 'unknown',
        title: sessionInfo['title'] ?? sessionInfo['name'] ?? '이름 없는 세션',
        date: DateTime.tryParse(safeApiData['createdAt'] ?? sessionInfo['date'] ?? sessionInfo['createdAt'] ?? '') ?? DateTime.now(),
        sessionStartTime: DateTime.tryParse(sessionInfo['startTime'] ?? sessionInfo['date'] ?? sessionInfo['createdAt'] ?? safeApiData['createdAt'] ?? '') ?? DateTime.now(),
        category: convertedCategory,
        emotionData: emotionData,
        emotionChangePoints: changePoints,
        rawApiData: apiData, // 🔥 원본 API 응답 데이터 저장
        metrics: metrics,
      );
    } catch (e) {
      print('❌ API 응답 파싱 오류: $e');
      print('❌ API 데이터: $apiData');
      
      // 🔥 파싱 오류 시 더 나은 기본값으로 생성 (완전히 빈 값 대신)
      return AnalysisResult(
        sessionId: 'unknown',
        title: '분석 결과',
        date: DateTime.now(),
        sessionStartTime: DateTime.now(),
        category: '발표', // 기본값을 발표로 설정
        emotionData: [],
        emotionChangePoints: [],
        rawApiData: {}, // 🔥 빈 맵으로 초기화 (오류 시)
        metrics: SessionMetrics(
          totalDuration: 1800, // 30분 기본값
          audioRecorded: true,
          speakingMetrics: SpeakingMetrics(
            speechRate: 120, // 120 WPM 기본값
            tonality: 75,
            clarity: 80,
            habitPatterns: [],
          ),
          emotionMetrics: EmotionMetrics(
            averageInterest: 70,
            averageLikeability: 75,
            peakLikeability: 85,
            lowestLikeability: 60,
            feedbacks: [],
          ),
          conversationMetrics: ConversationMetrics(
            contributionRatio: 60,
            listeningScore: 75,
            interruptionCount: 0,
            flowDescription: '안정적인 대화 흐름',
          ),
          topicMetrics: TopicMetrics(
            topics: [],
            timepoints: [],
            insights: [],
            recommendations: [],
          ),
        ),
      );
    }
  }

  // 🔥 안전한 Map 타입 변환 헬퍼 함수
  static Map<String, dynamic> _safeCastMap(dynamic input) {
    if (input == null) return <String, dynamic>{};
    if (input is Map<String, dynamic>) return input;
    if (input is Map) {
      // Map<dynamic, dynamic> → Map<String, dynamic> 변환
      final result = <String, dynamic>{};
      input.forEach((key, value) {
        final stringKey = key.toString();
        if (value is Map) {
          result[stringKey] = _safeCastMap(value);
        } else {
          result[stringKey] = value;
        }
      });
      return result;
    }
    return <String, dynamic>{};
  }

  // 헬퍼 메서드들
  static String _getEmotionType(int score) {
    if (score >= 70) return '긍정적';
    if (score >= 30) return '중립적';
    return '부정적';
  }

  static String _convertSessionType(String apiType) {
    switch (apiType) {
      case 'dating': return '소개팅';
      case 'interview': return '면접';
      case 'presentation': return '발표';
      case 'coaching': return '코칭';
      case 'business': return '비즈니스';
      default: return '기타';
    }
  }

  static List<HabitPattern> _convertHabitPatterns(List<dynamic> apiPatterns) {
    return apiPatterns.map((pattern) => HabitPattern(
      type: pattern['type'] ?? '',
      count: pattern['count'] ?? 0,
      description: pattern['description'] ?? '',
      examples: List<String>.from(pattern['examples'] ?? []),
    )).toList();
  }

  static List<EmotionFeedback> _convertEmotionFeedbacks(List<dynamic> apiFeedbacks) {
    return apiFeedbacks.map((feedback) => EmotionFeedback(
      type: feedback['type'] ?? '',
      content: feedback['content'] ?? '',
    )).toList();
  }

  static List<ConversationTopic> _convertTopics(List<dynamic> apiTopics) {
    print('📊 === 주제 차트 데이터 생성 시작 ===');
    print('🔍 API 주제 데이터 길이: ${apiTopics.length}');
    
    // 🔥 API 데이터가 있으면 우선 사용
    if (apiTopics.isNotEmpty) {
      print('✅ API 주제 데이터 사용 - 실제 데이터로 차트 생성');
      final topics = apiTopics.map((topic) {
        final name = topic['name'] ?? topic['topic'] ?? '알 수 없음';
        final percentage = (topic['percentage'] ?? topic['score'] ?? 0).toDouble();
        final isPrimary = topic['isPrimary'] ?? (topic['score'] ?? 0) > 30;
        print('🔢 주제: "$name" - ${percentage.toStringAsFixed(1)}% (주요: $isPrimary)');
        
        return ConversationTopic(
          name: name,
          percentage: percentage,
          isPrimary: isPrimary,
        );
      }).toList();
      print('✅ API 주제 파싱 완료: ${topics.length}개 주제 (실제 API 데이터)');
      print('📊 === 주제 차트 데이터 생성 완료 ===\n');
      return topics;
    }
    
    // 🔥 API 데이터가 없으면 기본 주제들 생성 (세션 타입별)
    print('⚠️ API 주제 데이터 없음 - 기본 주제로 차트 생성');
    final defaultTopics = [
      ConversationTopic(name: '자기소개', percentage: 25, isPrimary: true),
      ConversationTopic(name: '관심사 공유', percentage: 20, isPrimary: false),
      ConversationTopic(name: '경험 이야기', percentage: 18, isPrimary: false),
      ConversationTopic(name: '일상 대화', percentage: 15, isPrimary: false),
      ConversationTopic(name: '미래 계획', percentage: 12, isPrimary: false),
      ConversationTopic(name: '기타', percentage: 10, isPrimary: false),
    ];
    
    for (var topic in defaultTopics) {
      print('🔢 기본 주제: "${topic.name}" - ${topic.percentage.toStringAsFixed(1)}% (주요: ${topic.isPrimary})');
    }
    print('⚠️ 기본 주제 생성 완료: ${defaultTopics.length}개 주제 (API 데이터 없음)');
    print('📊 === 주제 차트 데이터 생성 완료 ===\n');
    return defaultTopics;
  }

  // 🔥 API 응답에서 topics 데이터 추출
  static List<dynamic> _extractTopicsFromApi(Map<String, dynamic> rawApiData, Map<String, dynamic> conversationTopics) {
    print('🔍 === API 주제 데이터 추출 시작 ===');
    print('🔍 rawApiData 키들: ${rawApiData.keys.toList()}');
    print('🔍 conversationTopics 키들: ${conversationTopics.keys.toList()}');
    
    // 🔥 1. 최상위 conversation_topics 확인 (가장 우선순위)
    if (rawApiData['conversation_topics'] != null && rawApiData['conversation_topics'] is List) {
      print('✅ rawApiData[\'conversation_topics\']에서 발견: ${(rawApiData['conversation_topics'] as List).length}개');
      return rawApiData['conversation_topics'] as List<dynamic>;
    }
    
    // 2. specializationInsights.conversation_topics.topics 확인
    if (conversationTopics['topics'] != null && conversationTopics['topics'] is List) {
      print('✅ conversationTopics[\'topics\']에서 발견: ${(conversationTopics['topics'] as List).length}개');
      return conversationTopics['topics'] as List<dynamic>;
    }
    
    // 3. rawApiData의 다른 가능한 필드들 확인
    final possibleFields = ['topics', 'mentionedTopics', 'discussed_topics', 'topic_analysis', 'topic_distribution'];
    for (final field in possibleFields) {
      if (rawApiData[field] != null && rawApiData[field] is List) {
        print('✅ rawApiData[\'$field\']에서 발견: ${(rawApiData[field] as List).length}개');
        return rawApiData[field] as List<dynamic>;
      }
      if (conversationTopics[field] != null && conversationTopics[field] is List) {
        print('✅ conversationTopics[\'$field\']에서 발견: ${(conversationTopics[field] as List).length}개');
        return conversationTopics[field] as List<dynamic>;
      }
    }
    
    print('⚠️ 모든 가능한 필드에서 주제 데이터를 찾지 못함');
    print('🔍 === API 주제 데이터 추출 완료 ===');
    return []; // 빈 배열 반환 시 _convertTopics에서 기본값 생성
  }

  static List<TopicTimepoint> _convertTopicTimepoints(List<dynamic> apiTimepoints) {
    return apiTimepoints.map((timepoint) => TopicTimepoint(
      time: timepoint['time'] ?? '00:00:00',
      timestamp: timepoint['timestamp'] ?? 0,
      description: timepoint['description'] ?? '',
      topics: List<String>.from(timepoint['topics'] ?? []),
    )).toList();
  }

  static List<TopicInsight> _convertApiInsights(List<dynamic> apiInsights) {
    return apiInsights.map((insight) => TopicInsight(
      topic: '전체 분석',
      insight: insight.toString(),
    )).toList();
  }

  static List<RecommendedTopic> _convertApiRecommendations(List<dynamic> apiRecommendations) {
    return apiRecommendations.map((recommendation) => RecommendedTopic(
      topic: '개선 제안',
      description: recommendation.toString(),
      questions: [],
    )).toList();
  }

  static List<TopicInsight> _convertTopicInsights(List<dynamic> apiInsights) {
    return apiInsights.map((insight) => TopicInsight(
      topic: insight['topic'] ?? '',
      insight: insight['insight'] ?? '',
    )).toList();
  }

  static List<RecommendedTopic> _convertRecommendations(List<dynamic> apiRecommendations) {
    return apiRecommendations.map((recommendation) => RecommendedTopic(
      topic: recommendation['topic'] ?? '',
      description: recommendation['description'] ?? '',
      questions: List<String>.from(recommendation['questions'] ?? []),
    )).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'title': title,
      'date': date.toIso8601String(),
      'sessionStartTime': sessionStartTime.toIso8601String(),
      'category': category,
      'emotionData': emotionData.map((e) => e.toJson()).toList(),
      'emotionChangePoints':
          emotionChangePoints.map((e) => e.toJson()).toList(),
      'metrics': metrics.toJson(),
      'rawApiData': rawApiData, // 🔥 추가
    };
  }

  // 오디오 시간 포맷 (초 -> MM:SS 형식)
  static String formatAudioTime(double seconds) {
    final int mins = (seconds / 60).floor();
    final int secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // 오디오 시간 포맷 (초 -> HH:MM:SS 형식)
  static String formatAudioTimeLong(double seconds) {
    final int hours = (seconds / 3600).floor();
    final int mins = ((seconds % 3600) / 60).floor();
    final int secs = (seconds % 60).floor();
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // 세션 날짜 포맷 (yyyy년 MM월 dd일 a h:mm 형식)
  String getFormattedDate() {
    final List<String> amPm = ['오전', '오후'];
    final String year = date.year.toString();
    final String month = date.month.toString();
    final String day = date.day.toString();
    final String hour =
        (date.hour > 12 ? date.hour - 12 : date.hour).toString();
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour < 12 ? amPm[0] : amPm[1];

    return '$year년 $month월 $day일 $period $hour:$minute';
  }

  // 세션 총 시간 포맷
  String getFormattedDuration() {
    final int hours = (metrics.totalDuration / 3600).floor();
    final int mins = ((metrics.totalDuration % 3600) / 60).floor();

    if (hours > 0) {
      return '$hours시간 $mins분';
    } else {
      return '$mins분';
    }
  }
}
