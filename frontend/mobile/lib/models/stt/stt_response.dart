class STTResponse {
  final String type;
  final String? message;
  final String? connectionId;
  final String? text;
  final bool? isFinal;
  final int? segmentId;
  final double? confidence;
  final List<STTWord>? words;
  final Map<String, dynamic>? metadata;

  STTResponse({
    required this.type,
    this.message,
    this.connectionId,
    this.text,
    this.isFinal,
    this.segmentId,
    this.confidence,
    this.words,
    this.metadata,
  });

  factory STTResponse.fromJson(Map<String, dynamic> json) {
    // metadata에 모든 추가 데이터 포함
    Map<String, dynamic> metadata = {};
    
    // 기본 metadata가 있으면 포함
    if (json['metadata'] != null) {
      metadata.addAll(json['metadata'] as Map<String, dynamic>);
    }
    
    // speech_metrics 추가
    if (json['speech_metrics'] != null) {
      metadata['speech_metrics'] = json['speech_metrics'];
    }
    
    // emotion_analysis 추가
    if (json['emotion_analysis'] != null) {
      metadata['emotion_analysis'] = json['emotion_analysis'];
    }
    
    // variability_metrics 추가
    if (json['variability_metrics'] != null) {
      metadata['variability_metrics'] = json['variability_metrics'];
    }
    
    // syllable_metrics 추가
    if (json['syllable_metrics'] != null) {
      metadata['syllable_metrics'] = json['syllable_metrics'];
    }
    
    // segments 추가
    if (json['segments'] != null) {
      metadata['segments'] = json['segments'];
    }
    
    // scenario, language 등 추가 정보도 포함
    if (json['scenario'] != null) {
      metadata['scenario'] = json['scenario'];
    }
    if (json['language'] != null) {
      metadata['language'] = json['language'];
    }
    if (json['language_probability'] != null) {
      metadata['language_probability'] = json['language_probability'];
    }

    return STTResponse(
      type: json['type'] as String,
      message: json['message'] as String?,
      connectionId: json['connection_id'] as String?,
      text: json['text'] as String?,
      isFinal: json['is_final'] as bool?,
      segmentId: json['segment_id'] as int?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      words: json['words'] != null
          ? (json['words'] as List)
              .map((word) => STTWord.fromJson(word))
              .toList()
          : null,
      metadata: metadata.isNotEmpty ? metadata : null,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {
      'type': type,
      'message': message,
      'connection_id': connectionId,
      'text': text,
      'is_final': isFinal,
      'segment_id': segmentId,
      'confidence': confidence,
      'words': words?.map((word) => word.toJson()).toList(),
    };
    
    // metadata의 모든 내용을 최상위 레벨로 복사
    if (metadata != null) {
      result.addAll(metadata!);
    }
    
    return result;
  }

  bool get isConnected => type == 'connected';
  bool get isTranscription => type == 'transcription';
  bool get isStatus => type == 'status';
  bool get isError => type == 'error';

  @override
  String toString() {
    return 'STTResponse(type: $type, text: $text, isFinal: $isFinal)';
  }
}

class STTWord {
  final String word;
  final double start;
  final double end;
  final double confidence;

  STTWord({
    required this.word,
    required this.start,
    required this.end,
    required this.confidence,
  });

  factory STTWord.fromJson(Map<String, dynamic> json) {
    return STTWord(
      word: json['word'] as String? ?? '',
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      end: (json['end'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'start': start,
      'end': end,
      'confidence': confidence,
    };
  }

  @override
  String toString() {
    return 'STTWord(word: $word, start: $start, end: $end, confidence: $confidence)';
  }
} 