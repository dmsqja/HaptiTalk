// 세션 분석 지표 모델
class SessionMetrics {
  final double totalDuration; // 총 시간 (초)
  final bool audioRecorded; // 오디오 녹음 여부
  final SpeakingMetrics speakingMetrics; // 말하기 지표
  final EmotionMetrics emotionMetrics; // 감정 지표
  final ConversationMetrics conversationMetrics; // 대화 지표
  final TopicMetrics topicMetrics; // 주제 지표

  SessionMetrics({
    required this.totalDuration,
    required this.audioRecorded,
    required this.speakingMetrics,
    required this.emotionMetrics,
    required this.conversationMetrics,
    required this.topicMetrics,
  });

  factory SessionMetrics.fromJson(Map<String, dynamic> json) {
    return SessionMetrics(
      totalDuration: json['totalDuration'] as double,
      audioRecorded: json['audioRecorded'] as bool,
      speakingMetrics: SpeakingMetrics.fromJson(json['speakingMetrics']),
      emotionMetrics: EmotionMetrics.fromJson(json['emotionMetrics']),
      conversationMetrics:
          ConversationMetrics.fromJson(json['conversationMetrics']),
      topicMetrics: TopicMetrics.fromJson(json['topicMetrics']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDuration': totalDuration,
      'audioRecorded': audioRecorded,
      'speakingMetrics': speakingMetrics.toJson(),
      'emotionMetrics': emotionMetrics.toJson(),
      'conversationMetrics': conversationMetrics.toJson(),
      'topicMetrics': topicMetrics.toJson(),
    };
  }

  // 주요 감정 라벨 반환
  String get mainEmotionLabel {
    // 감정 지표를 기반으로 주요 감정 라벨 계산
    if (emotionMetrics.averageLikeability >= 75) {
      return '긍정적';
    } else if (emotionMetrics.averageLikeability >= 50) {
      return '중립적';
    } else {
      return '개선 필요';
    }
  }

  // 호감도 퍼센트 반환 (정수형)
  String get likabilityPercent {
    return emotionMetrics.averageLikeability.round().toString();
  }
}

// 말하기 관련 지표
class SpeakingMetrics {
  final double speechRate; // 말하기 속도 (WPM)
  final double tonality; // 음성 톤 (%)
  final double clarity; // 명확성 (%)
  final List<HabitPattern> habitPatterns; // 습관적 패턴

  SpeakingMetrics({
    required this.speechRate,
    required this.tonality,
    required this.clarity,
    required this.habitPatterns,
  });

  factory SpeakingMetrics.fromJson(Map<String, dynamic> json) {
    return SpeakingMetrics(
      speechRate: json['speechRate'] as double,
      tonality: json['tonality'] as double,
      clarity: json['clarity'] as double,
      habitPatterns: (json['habitPatterns'] as List<dynamic>)
          .map((e) => HabitPattern.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speechRate': speechRate,
      'tonality': tonality,
      'clarity': clarity,
      'habitPatterns': habitPatterns.map((e) => e.toJson()).toList(),
    };
  }
}

// 습관적 패턴
class HabitPattern {
  final String type; // 패턴 유형 (예: '습관어 반복', '말 끊기')
  final int count; // 발생 횟수
  final String description; // 설명
  final List<String>? examples; // 예시

  HabitPattern({
    required this.type,
    required this.count,
    required this.description,
    this.examples,
  });

  factory HabitPattern.fromJson(Map<String, dynamic> json) {
    return HabitPattern(
      type: json['type'] as String,
      count: json['count'] as int,
      description: json['description'] as String,
      examples: (json['examples'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'count': count,
      'description': description,
      'examples': examples,
    };
  }
}

// 감정 관련 지표
class EmotionMetrics {
  final double averageInterest; // 평균 관심도 (%)
  final double averageLikeability; // 평균 호감도 (%)
  final double peakLikeability; // 최고 호감도 (%)
  final double lowestLikeability; // 최저 호감도 (%)
  final List<EmotionFeedback> feedbacks; // 감정 관련 피드백

  EmotionMetrics({
    required this.averageInterest,
    required this.averageLikeability,
    required this.peakLikeability,
    required this.lowestLikeability,
    required this.feedbacks,
  });

  factory EmotionMetrics.fromJson(Map<String, dynamic> json) {
    return EmotionMetrics(
      averageInterest: json['averageInterest'] as double,
      averageLikeability: json['averageLikeability'] as double,
      peakLikeability: json['peakLikeability'] as double,
      lowestLikeability: json['lowestLikeability'] as double,
      feedbacks: (json['feedbacks'] as List<dynamic>)
          .map((e) => EmotionFeedback.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'averageInterest': averageInterest,
      'averageLikeability': averageLikeability,
      'peakLikeability': peakLikeability,
      'lowestLikeability': lowestLikeability,
      'feedbacks': feedbacks.map((e) => e.toJson()).toList(),
    };
  }
}

// 감정 피드백
class EmotionFeedback {
  final String type; // 피드백 유형 (예: '긍정적인 포인트', '개선 포인트')
  final String content; // 피드백 내용

  EmotionFeedback({
    required this.type,
    required this.content,
  });

  factory EmotionFeedback.fromJson(Map<String, dynamic> json) {
    return EmotionFeedback(
      type: json['type'] as String,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
    };
  }
}

// 대화 관련 지표
class ConversationMetrics {
  final double contributionRatio; // 대화 기여도 (%)
  final double listeningScore; // 경청 지수 (%)
  final double interruptionCount; // 말 끊기 횟수
  final String flowDescription; // 대화 흐름 설명

  ConversationMetrics({
    required this.contributionRatio,
    required this.listeningScore,
    required this.interruptionCount,
    required this.flowDescription,
  });

  factory ConversationMetrics.fromJson(Map<String, dynamic> json) {
    return ConversationMetrics(
      contributionRatio: json['contributionRatio'] as double,
      listeningScore: json['listeningScore'] as double,
      interruptionCount: json['interruptionCount'] as double,
      flowDescription: json['flowDescription'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contributionRatio': contributionRatio,
      'listeningScore': listeningScore,
      'interruptionCount': interruptionCount,
      'flowDescription': flowDescription,
    };
  }
}

// 주제 관련 지표
class TopicMetrics {
  final List<ConversationTopic> topics; // 주제 목록
  final List<TopicTimepoint> timepoints; // 시간에 따른 주제 변화
  final List<TopicInsight> insights; // 주제별 인사이트
  final List<RecommendedTopic> recommendations; // 추천 주제

  TopicMetrics({
    required this.topics,
    required this.timepoints,
    required this.insights,
    required this.recommendations,
  });

  factory TopicMetrics.fromJson(Map<String, dynamic> json) {
    return TopicMetrics(
      topics: (json['topics'] as List<dynamic>)
          .map((e) => ConversationTopic.fromJson(e as Map<String, dynamic>))
          .toList(),
      timepoints: (json['timepoints'] as List<dynamic>)
          .map((e) => TopicTimepoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      insights: (json['insights'] as List<dynamic>)
          .map((e) => TopicInsight.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => RecommendedTopic.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topics': topics.map((e) => e.toJson()).toList(),
      'timepoints': timepoints.map((e) => e.toJson()).toList(),
      'insights': insights.map((e) => e.toJson()).toList(),
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
    };
  }
}

// 대화 주제
class ConversationTopic {
  final String name; // 주제명
  final double percentage; // 비율 (%)
  final bool isPrimary; // 주요 주제 여부

  ConversationTopic({
    required this.name,
    required this.percentage,
    this.isPrimary = false,
  });

  factory ConversationTopic.fromJson(Map<String, dynamic> json) {
    return ConversationTopic(
      name: json['name'] as String,
      percentage: json['percentage'] as double,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'percentage': percentage,
      'isPrimary': isPrimary,
    };
  }
}

// 시간에 따른 주제 변화
class TopicTimepoint {
  final String time; // 표시용 시간 (예: "00:15:38")
  final double timestamp; // 실제 초 단위 시간
  final String description; // 설명
  final List<String> topics; // 관련 주제

  TopicTimepoint({
    required this.time,
    required this.timestamp,
    required this.description,
    required this.topics,
  });

  factory TopicTimepoint.fromJson(Map<String, dynamic> json) {
    return TopicTimepoint(
      time: json['time'] as String,
      timestamp: json['timestamp'] as double,
      description: json['description'] as String,
      topics:
          (json['topics'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'timestamp': timestamp,
      'description': description,
      'topics': topics,
    };
  }
}

// 주제별 인사이트
class TopicInsight {
  final String topic; // 주제명
  final String insight; // 인사이트 내용

  TopicInsight({
    required this.topic,
    required this.insight,
  });

  factory TopicInsight.fromJson(Map<String, dynamic> json) {
    return TopicInsight(
      topic: json['topic'] as String,
      insight: json['insight'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'insight': insight,
    };
  }
}

// 추천 주제
class RecommendedTopic {
  final String topic; // 주제명
  final String description; // 설명
  final List<String> questions; // 관련 질문

  RecommendedTopic({
    required this.topic,
    required this.description,
    required this.questions,
  });

  factory RecommendedTopic.fromJson(Map<String, dynamic> json) {
    return RecommendedTopic(
      topic: json['topic'] as String,
      description: json['description'] as String,
      questions:
          (json['questions'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'description': description,
      'questions': questions,
    };
  }
}
