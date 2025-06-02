import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import 'stt_websocket_service.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final STTWebSocketService _sttService = STTWebSocketService();
  
  bool _isRecording = false;
  bool _isInitialized = false;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  
  // 30초 버퍼링 관련 변수들
  List<int> _audioBuffer = [];
  Timer? _bufferTimer;
  static const Duration bufferDuration = Duration(seconds: 30); // 30초 단위로 전송
  static const int maxBufferSize = 30 * 16000 * 2; // 30초 * 샘플레이트 * 2바이트(16bit)
  
  // 실제 기기용 안전한 오디오 설정
  static const int sampleRate = 16000; // 원래대로 되돌림 (더 안전함)
  static const int bitRate = 128000; 
  static const int numChannels = 1; // 모노

  // 상태 getter
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;

  // 싱글톤 패턴
  static final AudioService _instance = AudioService._internal();
  AudioService._internal();
  factory AudioService() => _instance;

  /// 오디오 서비스 초기화
  Future<bool> initialize() async {
    try {
      print('📱 실제 기기 오디오 초기화 시작...');
      
      // 마이크 권한 확인 및 요청
      final hasPermission = await _requestMicrophonePermission();
      if (!hasPermission) {
        print('❌ 마이크 권한이 필요합니다');
        return false;
      }

      // 레코더 초기화 확인
      final isRecorderInitialized = await _recorder.hasPermission();
      if (!isRecorderInitialized) {
        print('❌ 오디오 레코더 초기화 실패');
        return false;
      }

      _isInitialized = true;
      print('✅ AudioService 초기화 완료 (sampleRate: $sampleRate, channels: $numChannels)');
      return true;
    } catch (e) {
      print('❌ AudioService 초기화 실패: $e');
      return false;
    }
  }

  /// 마이크 권한 요청
  Future<bool> _requestMicrophonePermission() async {
    try {
      print('🔍 마이크 권한 상태 확인 중...');
      
      // 1. record 패키지로 먼저 권한 확인 (더 정확함)
      final hasRecordPermission = await _recorder.hasPermission();
      print('🎤 record 패키지 권한 상태: $hasRecordPermission');
      
      // record 패키지에서 권한이 있다고 하면 바로 성공 처리
      if (hasRecordPermission) {
        print('✅ record 패키지에서 마이크 권한 확인됨 - 진행');
        return true;
      }
      
      // 2. permission_handler로 상태 확인
      final currentStatus = await Permission.microphone.status;
      print('📱 permission_handler 권한 상태: $currentStatus');
      
      if (currentStatus.isGranted) {
        print('✅ permission_handler에서도 권한 허용됨');
        return true;
      }
      
      if (currentStatus.isPermanentlyDenied) {
        print('❌ 마이크 권한이 영구적으로 거부됨');
        print('📱 iOS 설정 > 개인정보 보호 및 보안 > 마이크에서 HaptiTalk을 허용해주세요');
        
        // 설정 앱으로 이동 제안
        await Permission.microphone.request(); // 한 번 더 시도
        final retryStatus = await Permission.microphone.status;
        
        if (retryStatus.isGranted) {
          print('✅ 재시도로 권한 허용됨');
          return true;
        }
        
        // 여전히 안 되면 설정으로 이동
        print('🔧 설정 앱으로 이동하여 수동으로 권한을 허용해주세요');
        return false;
      }
      
      // 3. denied 상태이면 권한 요청
      if (currentStatus.isDenied) {
        print('📲 마이크 권한 요청 팝업 표시 시도...');
        
        final requestResult = await Permission.microphone.request();
        print('📋 권한 요청 결과: $requestResult');
        
        if (requestResult.isGranted) {
          print('✅ 마이크 권한 허용됨');
          return true;
        } else {
          print('❌ 마이크 권한 거부됨: $requestResult');
          return false;
        }
      }
      
      // 4. 최종 확인 - record 패키지 우선
      final finalRecordCheck = await _recorder.hasPermission();
      print('🔄 최종 record 패키지 권한 확인: $finalRecordCheck');
      
      if (finalRecordCheck) {
        print('✅ record 패키지에서 최종 권한 확인 - 성공 처리');
        return true;
      }
      
      return false;
      
    } catch (e) {
      print('❌ 마이크 권한 확인/요청 실패: $e');
      
      // 예외 발생 시에도 record 패키지로 한 번 더 확인
      try {
        final fallbackCheck = await _recorder.hasPermission();
        print('🆘 예외 발생 시 fallback 권한 확인: $fallbackCheck');
        return fallbackCheck;
      } catch (fallbackError) {
        print('❌ fallback 권한 확인도 실패: $fallbackError');
        return false;
      }
    }
  }

  /// 실시간 음성 녹음 시작
  Future<bool> startRealTimeRecording() async {
    if (!_isInitialized) {
      print('❌ AudioService가 초기화되지 않았습니다');
      return false;
    }

    if (_isRecording) {
      print('⚠️ 이미 녹음 중입니다');
      return true;
    }

    try {
      // STT WebSocket 연결 확인
      if (!_sttService.isConnected) {
        print('🔌 STT WebSocket 연결 시도...');
        await _sttService.connect();
        await Future.delayed(Duration(milliseconds: 1000)); 
        
        if (!_sttService.isConnected) {
          print('❌ STT 연결 실패 - 녹음 시작 중단');
          return false;
        }
      }

      print('🎤 실시간 오디오 스트림 시작 시도...');
      
      // 최소한의 설정으로 AudioUnit 에러 방지
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: numChannels,
          // 문제가 될 수 있는 설정들 제거
          // autoGain, echoCancel, noiseSuppress 등은 AudioUnit 에러 원인이 될 수 있음
        ),
      );

      print('✅ 오디오 스트림 생성 성공');

      // STT 녹음 시작
      await _sttService.startRecording();
      print('✅ STT 녹음 시작 성공');

      // 30초 버퍼 초기화
      _audioBuffer.clear();
      
      // 30초 타이머 시작
      _startBufferTimer();

      // 오디오 스트림 리스닝 (버퍼링 방식)
      _audioStreamSubscription = stream.listen(
        (audioData) {
          try {
            // 오디오 데이터를 버퍼에 추가
            _audioBuffer.addAll(audioData);
            
            // 버퍼 크기 제한 (메모리 보호)
            if (_audioBuffer.length > maxBufferSize) {
              print('⚠️ 오디오 버퍼 크기 초과, 강제 전송');
              _sendBufferedAudio();
            }
            
            // 5초마다 버퍼 상태 로그 (디버깅용)
            if (DateTime.now().millisecondsSinceEpoch % 5000 < 200) {
              print('📊 오디오 버퍼 상태: ${_audioBuffer.length} bytes / ${maxBufferSize} bytes');
            }
          } catch (e) {
            print('❌ 오디오 데이터 버퍼링 실패: $e');
          }
        },
        onError: (error) {
          print('❌ 오디오 스트림 에러: $error');
          // 에러 발생 시 자동 재시작 시도
          _handleAudioError(error);
        },
        onDone: () {
          print('📡 오디오 스트림 종료');
          _isRecording = false;
          _bufferTimer?.cancel();
        },
      );

      _isRecording = true;
      print('🎤 실시간 음성 녹음 시작 완료');
      return true;

    } catch (e) {
      print('❌ 실시간 녹음 시작 실패: $e');
      // 실패 시 정리 작업
      await _cleanupAfterError();
      return false;
    }
  }

  /// 오디오 에러 처리
  void _handleAudioError(dynamic error) async {
    print('🔧 오디오 에러 처리 시작: $error');
    
    // 현재 스트림 정리
    await _cleanupAfterError();
    
    // 잠시 대기 후 재시작 시도
    await Future.delayed(Duration(milliseconds: 500));
    
    if (_isInitialized) {
      print('🔄 오디오 스트림 자동 재시작 시도...');
      final restarted = await startRealTimeRecording();
      if (restarted) {
        print('✅ 오디오 스트림 자동 재시작 성공');
      } else {
        print('❌ 오디오 스트림 자동 재시작 실패');
      }
    }
  }

  /// 에러 후 정리 작업
  Future<void> _cleanupAfterError() async {
    try {
      _isRecording = false;
      _bufferTimer?.cancel();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _recorder.stop();
      await _sttService.stopRecording();
      _audioBuffer.clear();
      print('🧹 에러 후 정리 작업 완료');
    } catch (e) {
      print('❌ 정리 작업 중 에러: $e');
    }
  }

  /// 음성 녹음 중지
  Future<void> stopRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      // 마지막 버퍼 전송
      if (_audioBuffer.isNotEmpty) {
        print('📤 마지막 오디오 버퍼 전송: ${_audioBuffer.length} bytes');
        _sendBufferedAudio();
      }
      
      // 타이머 및 스트림 정리
      _bufferTimer?.cancel();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // 레코더 중지
      await _recorder.stop();

      // STT 녹음 중지
      await _sttService.stopRecording();

      _isRecording = false;
      _audioBuffer.clear();
      print('🛑 음성 녹음 중지');

    } catch (e) {
      print('❌ 녹음 중지 실패: $e');
    }
  }

  /// 일시 정지
  Future<void> pauseRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      // 현재 버퍼 전송
      if (_audioBuffer.isNotEmpty) {
        print('📤 일시정지 전 오디오 버퍼 전송: ${_audioBuffer.length} bytes');
        _sendBufferedAudio();
      }
      
      _bufferTimer?.cancel();
      await _recorder.pause();
      await _sttService.stopRecording();
      print('⏸️ 녹음 일시 정지');
    } catch (e) {
      print('❌ 녹음 일시 정지 실패: $e');
    }
  }

  /// 재개
  Future<void> resumeRecording() async {
    try {
      await _recorder.resume();
      await _sttService.startRecording();
      _startBufferTimer(); // 타이머 재시작
      print('▶️ 녹음 재개');
    } catch (e) {
      print('❌ 녹음 재개 실패: $e');
    }
  }

  /// 오디오 레벨 가져오기 (음성 감지용)
  Future<double> getAudioLevel() async {
    try {
      final amplitude = await _recorder.getAmplitude();
      return amplitude.current;
    } catch (e) {
      return 0.0;
    }
  }

  /// STT 서비스와 연결 상태 확인
  bool get isSTTConnected => _sttService.isConnected;

  /// STT 메시지 스트림
  Stream<dynamic>? get sttMessageStream => _sttService.messageStream;

  /// 언어 변경
  Future<void> changeLanguage(String language) async {
    await _sttService.changeLanguage(language);
  }

  /// 서비스 해제
  Future<void> dispose() async {
    await stopRecording();
    _bufferTimer?.cancel();
    await _audioStreamSubscription?.cancel();
    await _recorder.dispose();
    _sttService.disconnect();
    _audioBuffer.clear();
    
    _isInitialized = false;
    print('🧹 AudioService 해제');
  }

  /// 현재 오디오 설정 정보
  Map<String, dynamic> getAudioConfig() {
    return {
      'sampleRate': sampleRate,
      'bitRate': bitRate,
      'numChannels': numChannels,
      'isRecording': _isRecording,
      'isInitialized': _isInitialized,
      'isSTTConnected': isSTTConnected,
    };
  }

  /// 30초 타이머 시작
  void _startBufferTimer() {
    _bufferTimer = Timer.periodic(bufferDuration, (Timer timer) {
      _sendBufferedAudio();
    });
  }

  /// 버퍼링된 오디오 전송
  void _sendBufferedAudio() {
    if (_audioBuffer.isNotEmpty) {
      final audioData = Uint8List.fromList(_audioBuffer);
      _sttService.sendAudioData(audioData);
      _audioBuffer.clear();
    }
  }
} 