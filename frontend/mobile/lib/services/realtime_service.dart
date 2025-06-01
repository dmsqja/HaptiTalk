import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:logger/logger.dart';
import '../config/app_config.dart';
import '../models/stt/stt_response.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final Logger _logger = Logger();
  IO.Socket? _socket;
  String? _currentSessionId;

  // 햅틱 피드백 수신 콜백
  Function(Map<String, dynamic>)? _onHapticFeedback;

  bool get isConnected => _socket?.connected ?? false;

  /// realtime-service에 연결
  Future<bool> connect(String sessionId, String accessToken) async {
    try {
      _currentSessionId = sessionId;
      
      // Kong WebSocket 라우트에 맞는 Socket.IO 서버 URL
      final baseUrl = AppConfig.apiBaseUrl.replaceFirst('/api/v1', '');
      _logger.i('💡 Socket.IO 연결 시도: $baseUrl');
      
      _socket = IO.io(baseUrl, { // baseUrl을 사용하되 path는 자동으로 /socket.io 추가됨
        'transports': ['websocket', 'polling'], // polling도 추가 (fallback)
        'autoConnect': false, // 수동 연결로 변경
        'forceNew': true,
        'timeout': 20000,
        'extraHeaders': {
          'Authorization': 'Bearer $accessToken', // 헤더로 JWT 전송
        },
        'query': {
          'sessionId': sessionId,
          'token': accessToken, // 쿼리로도 토큰 전송 (백업)
        },
        'auth': {
          'token': accessToken, // auth로도 토큰 전송 (백업)
        },
      });

      // 연결 이벤트 리스너
      _socket!.on('connect', (_) {
        _logger.i('✅ realtime-service WebSocket 연결 성공');
        // 연결 후 세션 입장
        _joinSession(sessionId);
      });

      _socket!.on('disconnect', (reason) {
        _logger.w('⚠️ realtime-service WebSocket 연결 해제: $reason');
      });

      _socket!.on('connect_error', (error) {
        _logger.e('❌ realtime-service WebSocket 연결 오류: $error');
      });

      // 햅틱 피드백 수신
      _socket!.on('haptic_feedback', (data) {
        _logger.i('📳 햅틱 피드백 수신: $data');
        if (_onHapticFeedback != null) {
          _onHapticFeedback!(Map<String, dynamic>.from(data));
        }
      });

      // 수동으로 연결 시작
      _socket!.connect();

      // 연결 완료까지 대기 (최대 10초)
      int attempts = 0;
      while (!_socket!.connected && attempts < 50) { // 10초 대기
        await Future.delayed(Duration(milliseconds: 200));
        attempts++;
      }
      
      if (_socket!.connected) {
        _logger.i('Socket.IO 연결 성공 - attempts: $attempts');
        return true;
      } else {
        _logger.e('Socket.IO 연결 타임아웃');
        return false;
      }
    } catch (e) {
      _logger.e('realtime-service 연결 실패: $e');
      return false;
    }
  }

  /// 세션 입장
  void _joinSession(String sessionId) {
    if (_socket?.connected == true) {
      _socket!.emit('join_session', {'sessionId': sessionId});
      _logger.i('세션 입장 요청: $sessionId');
    }
  }

  /// STT 분석 결과를 realtime-service로 전송
  Future<bool> sendSTTResult({
    required String sessionId,
    required STTResponse sttResponse,
    required String scenario,
    required String language,
    required String accessToken,
  }) async {
    try {
      final requestData = {
        'sessionId': sessionId,
        'text': sttResponse.text,
        'scenario': scenario,
        'language': language,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // speechMetrics가 있으면 추가
      if (sttResponse.metadata?['speechMetrics'] != null) {
        requestData['speechMetrics'] = sttResponse.metadata!['speechMetrics'];
      }

      // emotionAnalysis가 있으면 추가
      if (sttResponse.metadata?['emotionAnalysis'] != null) {
        requestData['emotionAnalysis'] = sttResponse.metadata!['emotionAnalysis'];
      }

      _logger.d('realtime-service로 STT 결과 전송: ${json.encode(requestData)}');

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/realtime/analyze-stt-result'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _logger.i('STT 결과 전송 성공: ${responseData['success']}');
        
        if (responseData['feedback'] != null) {
          _logger.i('피드백 생성됨: ${responseData['feedback']['type']}');
        }
        
        return true;
      } else {
        _logger.e('STT 결과 전송 실패: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.e('STT 결과 전송 오류: $e');
      return false;
    }
  }

  /// 햅틱 피드백 수신 콜백 설정
  void setHapticFeedbackCallback(Function(Map<String, dynamic>) callback) {
    _onHapticFeedback = callback;
  }

  /// 연결 해제
  void disconnect() {
    if (_currentSessionId != null && _socket?.connected == true) {
      _socket!.emit('leave_session', {'sessionId': _currentSessionId});
    }
    
    _socket?.disconnect();
    _socket = null;
    _currentSessionId = null;
    _onHapticFeedback = null;
    _logger.i('realtime-service 연결 해제');
  }
} 