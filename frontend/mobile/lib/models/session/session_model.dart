import '../analysis/analysis_result.dart';
import 'package:flutter/foundation.dart';
import 'session_tag.dart';

enum SessionMode {
  dating,
  interview,
  business,
  coaching,
}

enum AnalysisLevel {
  basic,
  standard,
  premium,
}

enum RecordingRetention {
  none,
  sevenDays,
  thirtyDays,
}

class SessionModel {
  final String id;
  final String? name;
  final SessionMode mode;
  final AnalysisLevel analysisLevel;
  final RecordingRetention recordingRetention;
  final DateTime createdAt;
  final DateTime? endedAt;
  final Duration duration;
  final bool isSmartWatchConnected;
  final String? recordingPath;
  final String? transcription;
  final List<SessionTag>? tags;
  final AnalysisResult? analysisResult;

  SessionModel({
    required this.id,
    this.name,
    required this.mode,
    required this.analysisLevel,
    required this.recordingRetention,
    required this.createdAt,
    this.endedAt,
    required this.duration,
    required this.isSmartWatchConnected,
    this.recordingPath,
    this.transcription,
    this.tags,
    this.analysisResult,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'],
      name: json['name'],
      mode: SessionMode.values.byName(json['mode']),
      analysisLevel: AnalysisLevel.values.byName(json['analysisLevel']),
      recordingRetention:
          RecordingRetention.values.byName(json['recordingRetention']),
      createdAt: DateTime.parse(json['createdAt']),
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      duration: Duration(seconds: json['durationSeconds']),
      isSmartWatchConnected: json['isSmartWatchConnected'],
      recordingPath: json['recordingPath'],
      transcription: json['transcription'],
      tags: json['tags'] != null
          ? (json['tags'] as List)
              .map((tag) => SessionTag.fromJson(tag))
              .toList()
          : null,
      analysisResult: json['analysisResult'] != null
          ? AnalysisResult.fromJson(json['analysisResult'])
          : null,
    );
  }

  // API 응답에서 SessionModel 생성
  factory SessionModel.fromApiJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? json['session_id'],
      name: json['title'] ?? json['name'],
      mode: _parseSessionMode(json['type'] ?? json['mode']),
      analysisLevel: _parseAnalysisLevel(json['custom_settings']?['analysis_level'] ?? 'basic'),
      recordingRetention: _parseRecordingRetention(json['custom_settings']?['recording_retention'] ?? 'none'),
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
      duration: Duration(seconds: json['duration_seconds'] ?? json['durationSeconds'] ?? 0),
      isSmartWatchConnected: json['custom_settings']?['is_smart_watch_connected'] ?? json['isSmartWatchConnected'] ?? false,
      recordingPath: json['recording_path'] ?? json['recordingPath'],
      transcription: json['transcription'],
      tags: json['tags'] != null
          ? (json['tags'] as List)
              .map((tag) => SessionTag.fromJson(tag))
              .toList()
          : null,
      analysisResult: json['analysis_result'] != null || json['analysisResult'] != null
          ? AnalysisResult.fromJson(json['analysis_result'] ?? json['analysisResult'])
          : null,
    );
  }

  // 문자열을 SessionMode로 변환
  static SessionMode _parseSessionMode(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'dating':
        return SessionMode.dating;
      case 'interview':
        return SessionMode.interview;
      case 'business':
      case 'meeting':
        return SessionMode.business;
      case 'coaching':
      case 'presentation':
        return SessionMode.coaching;
      default:
        return SessionMode.dating; // 기본값
    }
  }

  // 문자열을 AnalysisLevel로 변환
  static AnalysisLevel _parseAnalysisLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'basic':
        return AnalysisLevel.basic;
      case 'standard':
      case 'detailed':
        return AnalysisLevel.standard;
      case 'premium':
      case 'comprehensive':
        return AnalysisLevel.premium;
      default:
        return AnalysisLevel.basic; // 기본값
    }
  }

  // 문자열을 RecordingRetention으로 변환
  static RecordingRetention _parseRecordingRetention(String? retention) {
    switch (retention?.toLowerCase()) {
      case 'none':
        return RecordingRetention.none;
      case 'seven_days':
      case 'sevendays':
      case 'week':
        return RecordingRetention.sevenDays;
      case 'thirty_days':
      case 'thirtydays':
      case 'month':
        return RecordingRetention.thirtyDays;
      default:
        return RecordingRetention.none; // 기본값
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mode': mode.name,
      'analysisLevel': analysisLevel.name,
      'recordingRetention': recordingRetention.name,
      'createdAt': createdAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'isSmartWatchConnected': isSmartWatchConnected,
      'recordingPath': recordingPath,
      'transcription': transcription,
      'tags': tags?.map((tag) => tag.toJson()).toList(),
      'analysisResult': analysisResult?.toJson(),
    };
  }

  SessionModel copyWith({
    String? id,
    String? name,
    SessionMode? mode,
    AnalysisLevel? analysisLevel,
    RecordingRetention? recordingRetention,
    DateTime? createdAt,
    DateTime? endedAt,
    Duration? duration,
    bool? isSmartWatchConnected,
    String? recordingPath,
    String? transcription,
    List<SessionTag>? tags,
    AnalysisResult? analysisResult,
  }) {
    return SessionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      analysisLevel: analysisLevel ?? this.analysisLevel,
      recordingRetention: recordingRetention ?? this.recordingRetention,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      isSmartWatchConnected:
          isSmartWatchConnected ?? this.isSmartWatchConnected,
      recordingPath: recordingPath ?? this.recordingPath,
      transcription: transcription ?? this.transcription,
      tags: tags ?? this.tags,
      analysisResult: analysisResult ?? this.analysisResult,
    );
  }
}

class SessionTag {
  final String id;
  final String name;
  final String? color;

  SessionTag({
    required this.id,
    required this.name,
    this.color,
  });

  factory SessionTag.fromJson(Map<String, dynamic> json) {
    return SessionTag(
      id: json['id'],
      name: json['name'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }
}

// 세션 모델
class Session {
  final String id; // 세션 ID
  final String title; // 세션 제목
  final DateTime date; // 세션 날짜
  final double duration; // 세션 지속 시간 (초)
  final String category; // 세션 카테고리 (예: '소개팅', '면접', '발표' 등)
  final List<SessionTag> tags; // 세션 태그
  final bool hasAudio; // 오디오 존재 여부
  final bool hasAnalysisResult; // 분석 결과 존재 여부

  Session({
    required this.id,
    required this.title,
    required this.date,
    required this.duration,
    required this.category,
    this.tags = const [],
    this.hasAudio = false,
    this.hasAnalysisResult = false,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
      duration: (json['duration'] as num).toDouble(),
      category: json['category'] as String,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => SessionTag.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasAudio: json['hasAudio'] as bool? ?? false,
      hasAnalysisResult: json['hasAnalysisResult'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'duration': duration,
      'category': category,
      'tags': tags.map((e) => e.toJson()).toList(),
      'hasAudio': hasAudio,
      'hasAnalysisResult': hasAnalysisResult,
    };
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
    final int hours = (duration / 3600).floor();
    final int mins = ((duration % 3600) / 60).floor();

    if (hours > 0) {
      return '$hours시간 $mins분';
    } else {
      return '$mins분';
    }
  }

  // 복사본 생성
  Session copyWith({
    String? id,
    String? title,
    DateTime? date,
    double? duration,
    String? category,
    List<SessionTag>? tags,
    bool? hasAudio,
    bool? hasAnalysisResult,
  }) {
    return Session(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      hasAudio: hasAudio ?? this.hasAudio,
      hasAnalysisResult: hasAnalysisResult ?? this.hasAnalysisResult,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Session &&
        other.id == id &&
        other.title == title &&
        other.date == date &&
        other.duration == duration &&
        other.category == category &&
        listEquals(other.tags, tags) &&
        other.hasAudio == hasAudio &&
        other.hasAnalysisResult == hasAnalysisResult;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        date.hashCode ^
        duration.hashCode ^
        category.hashCode ^
        tags.hashCode ^
        hasAudio.hashCode ^
        hasAnalysisResult.hashCode;
  }
}
