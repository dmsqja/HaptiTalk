import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../config/app_config.dart';
import '../models/stt/stt_response.dart';

class STTWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  StreamController<STTResponse>? _messageController;
  bool _isConnected = false;
  bool _isRecording = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  String _language = 'ko';
  String? _connectionId;
  
  static const int maxReconnectAttempts = 3;
  static const Duration reconnectDelay = Duration(seconds: 2);

  // 메시지 스트림
  Stream<STTResponse>? get messageStream => _messageController?.stream;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  String? get connectionId => _connectionId;

  // 싱글톤 패턴
  static final STTWebSocketService _instance = STTWebSocketService._internal();
  STTWebSocketService._internal();
  factory STTWebSocketService() => _instance;

  // WebSocket 연결
  Future<void> connect({String language = 'ko'}) async {
    try {
      _language = language;
      
      // STT WebSocket URL 생성
      final sttUrl = '${AppConfig.sttBaseUrl}/api/v1/stt/stream?language=$_language';
      
      print('🔌 STT WebSocket 연결 시도: $sttUrl');
      
      // WebSocket 연결
      _channel = IOWebSocketChannel.connect(sttUrl);
      _messageController = StreamController<STTResponse>.broadcast();

      // 메시지 수신 리스너
      _subscription = _channel!.stream.listen(
        (message) {
          try {
            print('📨 STT 원본 메시지 수신: $message');
            final data = json.decode(message);
            print('📊 STT JSON 파싱 성공: $data');
            
            final response = STTResponse.fromJson(data);
            
            // 연결 ID 저장
            if (response.type == 'connected' && response.connectionId != null) {
              _connectionId = response.connectionId;
              print('✅ STT WebSocket 연결 성공: $_connectionId');
            }
            
            _messageController?.add(response);
            print('📨 STT 메시지 수신: ${response.type} - ${response.text ?? response.message}');
          } catch (e, stackTrace) {
            print('❌ STT 메시지 파싱 실패: $e');
            print('📋 원본 메시지: $message');
            print('🔍 스택 트레이스: $stackTrace');
            
            // 기본 에러 응답 생성
            final errorResponse = STTResponse(
              type: 'error',
              message: 'JSON 파싱 실패: $e',
            );
            _messageController?.add(errorResponse);
          }
        },
        onError: (error) {
          print('❌ STT WebSocket 에러: $error');
          _isConnected = false;
          _attemptReconnect();
        },
        onDone: () {
          print('📡 STT WebSocket 연결 종료');
          _isConnected = false;
          _attemptReconnect();
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;

    } catch (e) {
      print('❌ STT WebSocket 연결 실패: $e');
      _isConnected = false;
      _attemptReconnect();
    }
  }

  // 음성 인식 시작
  Future<void> startRecording() async {
    if (!_isConnected) {
      throw Exception('STT WebSocket이 연결되지 않았습니다');
    }

    try {
      // JSON 형식으로 start 명령 전송
      final startCommand = json.encode({
        'command': 'start_recording'
      });
      _channel?.sink.add(startCommand);
      _isRecording = true;
      print('🎤 STT 음성 인식 시작');
    } catch (e) {
      print('❌ STT 음성 인식 시작 실패: $e');
      rethrow;
    }
  }

  // 음성 인식 중지
  Future<void> stopRecording() async {
    if (!_isConnected) {
      return;
    }

    try {
      // JSON 형식으로 stop 명령 전송
      final stopCommand = json.encode({
        'command': 'stop_recording'
      });
      _channel?.sink.add(stopCommand);
      _isRecording = false;
      print('🛑 STT 음성 인식 중지');
    } catch (e) {
      print('❌ STT 음성 인식 중지 실패: $e');
    }
  }

  // 오디오 데이터 전송
  void sendAudioData(Uint8List audioData) {
    if (_isConnected && _isRecording && _channel != null) {
      try {
        _channel!.sink.add(audioData);
        // print('🎵 오디오 데이터 전송: ${audioData.length} bytes');
      } catch (e) {
        print('❌ 오디오 데이터 전송 실패: $e');
      }
    }
  }

  // 언어 변경
  Future<void> changeLanguage(String language) async {
    if (!_isConnected) {
      return;
    }

    try {
      _language = language;
      _channel?.sink.add('language:$language');
      print('🌐 STT 언어 변경: $language');
    } catch (e) {
      print('❌ STT 언어 변경 실패: $e');
    }
  }

  // 재연결 시도
  void _attemptReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('❌ STT WebSocket 재연결 시도 한계 도달');
      return;
    }

    _reconnectAttempts++;
    
    print('🔄 STT WebSocket 재연결 시도 ${_reconnectAttempts}/${maxReconnectAttempts}');
    
    _reconnectTimer = Timer(reconnectDelay, () {
      connect(language: _language);
    });
  }

  // 연결 해제
  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _messageController?.close();
    
    _isConnected = false;
    _isRecording = false;
    _reconnectAttempts = 0;
    _connectionId = null;
    
    print('📡 STT WebSocket 연결 해제');
  }

  // 강제 재연결
  Future<void> forceReconnect() async {
    disconnect();
    await Future.delayed(Duration(milliseconds: 500));
    await connect(language: _language);
  }

  // 연결 상태 확인
  Future<bool> checkConnection() async {
    return _isConnected;
  }
} 