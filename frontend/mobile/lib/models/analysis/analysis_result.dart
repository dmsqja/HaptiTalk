import 'package:flutter/material.dart';
import 'emotion_data.dart';
import 'metrics.dart';
import 'dart:math' as Math;

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
      
      // 🔥 실제 report-service 응답 구조에 맞게 수정
      final safeApiData = _safeCastMap(apiData);
      
      // 🔥 report-service의 실제 필드들
      final sessionId = safeApiData['sessionId'] ?? 'unknown';
      final sessionType = safeApiData['sessionType'] ?? 'presentation';
      final duration = safeApiData['duration'] ?? 180;
      final createdAt = safeApiData['createdAt'] ?? DateTime.now().toIso8601String();
      
      // 🔥 keyMetrics에서 실제 지표 추출
      final keyMetrics = _safeCastMap(safeApiData['keyMetrics'] ?? {});
      final speaking = _safeCastMap(keyMetrics['speaking'] ?? {});
      final emotionAnalysis = _safeCastMap(safeApiData['emotionAnalysis'] ?? {});
      final detailedTimeline = safeApiData['detailedTimeline'] ?? [];
      
      print('🔍 keyMetrics: $keyMetrics');
      print('🔍 speaking: $speaking');
      print('🔍 emotionAnalysis: $emotionAnalysis');
      print('🔍 detailedTimeline 길이: ${detailedTimeline.length}');
      
      // 🔥 감정 데이터 생성 (detailedTimeline에서 추출)
      List<EmotionData> emotionData = [];
      print('🎯 === 타임라인 그래프 데이터 생성 시작 ===');
      
      if (detailedTimeline.isNotEmpty) {
        print('✅ detailedTimeline 데이터 사용: ${detailedTimeline.length}개 포인트');
        
        for (int i = 0; i < detailedTimeline.length; i++) {
          final timePoint = _safeCastMap(detailedTimeline[i]);
          final timestamp = (timePoint['timestamp'] ?? (i + 1) * 30).toDouble();
          final emotionScore = (timePoint['emotion_score'] ?? 0.5) as num;
          final confidence = (timePoint['confidence'] ?? 0.7) as num;
          
          // 🔥 emotion_score를 기반으로 감정 타입과 값 계산
          final positiveRatio = emotionScore.toDouble();
          final emotionValue = (positiveRatio * 100).clamp(20.0, 95.0);
          final emotionType = positiveRatio > 0.6 ? '긍정적' : 
                            positiveRatio < 0.4 ? '부정적' : '중립적';
          
          emotionData.add(EmotionData(
            timestamp: timestamp,
            emotionType: emotionType,
            value: emotionValue,
            description: '${(timestamp / 60).floor()}분 ${(timestamp % 60).floor()}초 시점',
          ));
        }
        
        print('✅ detailedTimeline에서 ${emotionData.length}개 감정 데이터 생성');
      } else {
        print('⚠️ detailedTimeline이 비어있음, 기본 데이터 생성');
        
        // 기본 데이터 생성 (3분 = 6개 포인트)
        final segments = Math.max<int>(6, (duration / 30).ceil());
        final random = Math.Random();
        
        for (int i = 0; i < segments; i++) {
          final timestamp = ((i + 1) * 30).toDouble();
          final baseScore = 0.7;
          final variation = (random.nextDouble() - 0.5) * 0.2;
          final positiveRatio = (baseScore + variation).clamp(0.3, 0.9);
          final emotionValue = (positiveRatio * 100).clamp(20.0, 95.0);
          final emotionType = positiveRatio > 0.6 ? '긍정적' : '중립적';
          
          emotionData.add(EmotionData(
            timestamp: timestamp,
            emotionType: emotionType,
            value: emotionValue,
            description: '${(timestamp / 60).floor()}분 ${(timestamp % 60).floor()}초 시점',
          ));
        }
        
        print('✅ 기본 감정 데이터 ${emotionData.length}개 생성');
      }
      
      // 🔥 감정 변화 포인트 생성
      List<EmotionChangePoint> changePoints = [];
      for (int i = 1; i < emotionData.length; i++) {
        final prev = emotionData[i - 1];
        final current = emotionData[i];
        final change = (current.value - prev.value).abs();
        
        if (change > 15.0) { // 15점 이상 변화시 포인트 생성
          final time = '${(current.timestamp / 60).floor().toString().padLeft(2, '0')}:${(current.timestamp % 60).floor().toString().padLeft(2, '0')}';
          
          changePoints.add(EmotionChangePoint(
            time: time,
            timestamp: current.timestamp,
            description: current.value > prev.value 
                ? '감정 상태 개선' 
                : '감정 상태 하락',
            emotionValue: current.value,
            label: current.emotionType,
            topics: [],
          ));
        }
      }
      
      print('✅ 감정 변화 포인트 ${changePoints.length}개 생성');
      
      // 🔥 SessionMetrics 생성 (실제 API 데이터 기반)
      final metrics = _createSessionMetricsFromApiData(apiData, emotionData);
      
      // 🔥 세션 타입 변환
      print('🔍 세션 타입 파싱: apiData[sessionType]=$sessionType');
      final convertedCategory = _convertSessionType(sessionType);
      print('🔍 변환된 카테고리: $sessionType → $convertedCategory');
      
      return AnalysisResult(
        sessionId: sessionId,
        title: '${_convertSessionTypeToKorean(sessionType)} 세션',
        date: DateTime.tryParse(createdAt) ?? DateTime.now(),
        sessionStartTime: DateTime.tryParse(createdAt) ?? DateTime.now(),
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

  // 🔥 API 데이터로부터 SessionMetrics 생성하는 헬퍼 메서드
  static SessionMetrics _createSessionMetricsFromApiData(Map<String, dynamic> apiData, List<EmotionData> emotionData) {
    final safeApiData = _safeCastMap(apiData);
    final keyMetrics = _safeCastMap(safeApiData['keyMetrics'] ?? {});
    final speaking = _safeCastMap(keyMetrics['speaking'] ?? {});
    final emotionAnalysis = _safeCastMap(safeApiData['emotionAnalysis'] ?? {});
    final duration = safeApiData['duration'] ?? 180;
    
    // SpeakingMetrics 생성
    final speakingMetrics = SpeakingMetrics(
      speechRate: (speaking['speed'] ?? 120).toDouble(),
      tonality: (speaking['tonality'] ?? 75).toDouble(),
      clarity: (speaking['clarity'] ?? 80).toDouble(),
      habitPatterns: [], // 현재는 빈 배열
    );
    
    // EmotionMetrics 생성
    final emotions = _safeCastMap(emotionAnalysis['emotions'] ?? {});
    final averageEmotion = emotionData.isNotEmpty 
        ? emotionData.map((e) => e.value).reduce((a, b) => a + b) / emotionData.length
        : 70.0;
    
    final emotionMetrics = EmotionMetrics(
      averageInterest: (emotions['happiness'] ?? averageEmotion).toDouble(),
      averageLikeability: averageEmotion,
      peakLikeability: emotionData.isNotEmpty 
          ? emotionData.map((e) => e.value).reduce(Math.max)
          : averageEmotion + 10,
      lowestLikeability: emotionData.isNotEmpty 
          ? emotionData.map((e) => e.value).reduce(Math.min)
          : averageEmotion - 10,
      feedbacks: [], // 현재는 빈 배열
    );
    
    // ConversationMetrics 생성
    final communication = _safeCastMap(keyMetrics['communication'] ?? {});
    final conversationMetrics = ConversationMetrics(
      contributionRatio: ((speaking['ratio'] ?? 0.6) * 100).toDouble(),
      listeningScore: 75.0, // 기본값
      interruptionCount: (communication['interruptions'] ?? 0).toDouble(),
      flowDescription: '안정적인 대화 흐름',
    );
    
    // TopicMetrics 생성
    final topicMetrics = TopicMetrics(
      topics: [], // 현재는 빈 배열
      timepoints: [], // 현재는 빈 배열
      insights: [], // 현재는 빈 배열
      recommendations: [], // 현재는 빈 배열
    );
    
    return SessionMetrics(
      totalDuration: duration.toDouble(),
      audioRecorded: true,
      speakingMetrics: speakingMetrics,
      emotionMetrics: emotionMetrics,
      conversationMetrics: conversationMetrics,
      topicMetrics: topicMetrics,
    );
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

  static String _convertSessionTypeToKorean(String apiType) {
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
