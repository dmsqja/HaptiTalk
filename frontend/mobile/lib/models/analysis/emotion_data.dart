class EmotionData {
  final double timestamp; // 초 단위 시간
  final String emotionType; // 감정 유형 (예: '긍정적', '부정적', '중립적' 등)
  final double value; // 감정 강도 (0-100%)
  final String? description; // 감정에 대한 설명

  EmotionData({
    required this.timestamp,
    required this.emotionType,
    required this.value,
    this.description,
  });

  factory EmotionData.fromJson(Map<String, dynamic> json) {
    return EmotionData(
      timestamp: (json['timestamp'] as num).toDouble(),
      emotionType: json['emotionType'] as String,
      value: (json['value'] as num).toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'emotionType': emotionType,
      'value': value,
      'description': description,
    };
  }
}

// 시간에 따른 감정 변화 포인트
class EmotionChangePoint {
  final String time; // 표시용 시간 (예: "00:15:38")
  final double timestamp; // 실제 초 단위 시간
  final String description; // 변화 설명
  final double emotionValue; // 감정 값
  final String label; // 포인트에 표시될 라벨
  final List<String> topics; // 관련 주제

  EmotionChangePoint({
    required this.time,
    required this.timestamp,
    required this.description,
    required this.emotionValue,
    required this.label,
    this.topics = const [],
  });

  factory EmotionChangePoint.fromJson(Map<String, dynamic> json) {
    return EmotionChangePoint(
      time: json['time'] as String,
      timestamp: (json['timestamp'] as num).toDouble(),
      description: json['description'] as String,
      emotionValue: (json['emotionValue'] as num).toDouble(),
      label: json['label'] as String,
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'timestamp': timestamp,
      'description': description,
      'emotionValue': emotionValue,
      'label': label,
      'topics': topics,
    };
  }
}
