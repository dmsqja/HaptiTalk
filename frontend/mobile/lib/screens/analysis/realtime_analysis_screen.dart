import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../constants/colors.dart';
import '../../models/analysis/analysis_result.dart';
import '../../models/session/session_model.dart';
import '../../models/stt/stt_response.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/watch_service.dart';
import '../../services/audio_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/analysis/metrics_card.dart';
import '../analysis/analysis_summary_screen.dart';
import '../../services/auth_service.dart';

class RealtimeAnalysisScreen extends StatefulWidget {
  final String sessionId;

  const RealtimeAnalysisScreen({Key? key, required this.sessionId})
      : super(key: key);

  @override
  _RealtimeAnalysisScreenState createState() => _RealtimeAnalysisScreenState();
}

class _RealtimeAnalysisScreenState extends State<RealtimeAnalysisScreen> {
  late Timer _timer;
  late Timer _watchSyncTimer;
  final WatchService _watchService = WatchService();
  final AudioService _audioService = AudioService();
  final RealtimeService _realtimeService = RealtimeService();

  int _seconds = 0;
  bool _isRecording = false;
  bool _isWatchConnected = false;
  bool _isRealtimeConnected = false;
  String _transcription = '';
  String _feedback = '';
  List<String> _suggestedTopics = [];
  bool _isAudioInitialized = false;
  StreamSubscription? _sttSubscription;

  // 분석 데이터 (실제 AI 결과로 업데이트)
  String _emotionState = '대기 중';
  int _speakingSpeed = 0;
  int _likability = 0;
  int _interest = 0;
  String _currentScenario = 'dating'; // 기본 시나리오

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _startTimer();
    _checkWatchConnection();
    _startWatchSync();

    // 초기 추천 주제 설정
    _suggestedTopics = ['여행 경험', '좋아하는 여행지', '사진 취미', '역사적 장소', '제주도 명소'];
  }

  @override
  void dispose() {
    _timer.cancel();
    _watchSyncTimer.cancel();
    _sttSubscription?.cancel();
    _audioService.dispose();
    _realtimeService.disconnect();
    super.dispose();
  }

  /// 서비스 초기화
  Future<void> _initializeServices() async {
    try {
      // AudioService 초기화
      final initialized = await _audioService.initialize();
      if (initialized) {
        setState(() {
          _isAudioInitialized = true;
        });
        
        // STT 메시지 스트림 구독
        _subscribeToSTTMessages();
        
        // Realtime Service 연결
        await _connectToRealtimeService();
        
        // 🎤 자동으로 녹음 시작
        await _startRecordingAutomatically();
        
        // 📳 Watch 세션 시작 및 테스트 햅틱 피드백 전송
        await _startWatchSession();
        
        print('✅ 실시간 분석 서비스 초기화 완료');
      } else {
        print('❌ AudioService 초기화 실패');
        _showErrorSnackBar('마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
      }
    } catch (e) {
      print('❌ 서비스 초기화 실패: $e');
      _showErrorSnackBar('서비스 초기화에 실패했습니다: $e');
    }
  }

  /// 자동으로 녹음 시작
  Future<void> _startRecordingAutomatically() async {
    if (!_isAudioInitialized) {
      print('❌ 자동 녹음 시작 실패: AudioService가 초기화되지 않음');
      return;
    }

    try {
      print('🎤 자동 녹음 시작 시도...');
      final success = await _audioService.startRealTimeRecording();
      if (success) {
        setState(() {
          _isRecording = true;
        });
        print('✅ 자동 녹음 시작 성공');
      } else {
        print('❌ 자동 녹음 시작 실패');
        _showErrorSnackBar('자동 녹음 시작에 실패했습니다. 수동으로 녹음을 시작해주세요.');
      }
    } catch (e) {
      print('❌ 자동 녹음 시작 예외: $e');
      _showErrorSnackBar('자동 녹음 시작 중 오류가 발생했습니다: $e');
    }
  }

  /// Realtime Service 연결
  Future<void> _connectToRealtimeService() async {
    try {
      // AuthService에서 실제 액세스 토큰 가져오기
      final authService = AuthService();
      final accessToken = await authService.getAccessToken();
      
      if (accessToken == null) {
        print('❌ realtime-service 연결 실패: 액세스 토큰 없음');
        _showErrorSnackBar('인증 토큰이 없습니다. 다시 로그인해주세요.');
        return;
      }
      
      final connected = await _realtimeService.connect(widget.sessionId, accessToken);
      
      setState(() {
        _isRealtimeConnected = connected;
      });
      
      if (connected) {
        print('✅ realtime-service 연결 성공');
        
        // 햅틱 피드백 콜백 설정
        _realtimeService.setHapticFeedbackCallback(_handleHapticFeedback);
      } else {
        print('❌ realtime-service 연결 실패');
        _showErrorSnackBar('실시간 서비스 연결에 실패했습니다');
      }
    } catch (e) {
      print('❌ realtime-service 연결 오류: $e');
      _showErrorSnackBar('실시간 서비스 연결 오류: $e');
    }
  }

  /// 햅틱 피드백 처리
  void _handleHapticFeedback(Map<String, dynamic> feedbackData) {
    print('🔔 햅틱 피드백 수신: $feedbackData');
    
    final feedbackType = feedbackData['type'] as String?;
    final message = feedbackData['message'] as String?;
    final hapticPattern = feedbackData['hapticPattern'] as String?;
    final visualCue = feedbackData['visualCue'] as Map<String, dynamic>?;
    
    // UI 업데이트
    if (message != null) {
      setState(() {
        _feedback = message;
      });
    }
    
    // Apple Watch 햅틱 전송
    if (hapticPattern != null && _isWatchConnected) {
      _sendHapticToWatch(feedbackType ?? 'general', hapticPattern, message ?? '');
    }
    
    // 시각적 피드백 표시
    if (visualCue != null) {
      _showVisualFeedback(visualCue);
    }
  }

  /// Apple Watch 햅틱 전송
  Future<void> _sendHapticToWatch(String type, String pattern, String message) async {
    try {
      // WatchService는 message 파라미터만 받으므로 형식을 맞춰서 전송
      final hapticMessage = '$type: $message';
      await _watchService.sendHapticFeedback(hapticMessage);
      print('📱 Apple Watch 햅틱 전송: $type - $pattern');
    } catch (e) {
      print('❌ Apple Watch 햅틱 전송 실패: $e');
    }
  }

  /// 시각적 피드백 표시
  void _showVisualFeedback(Map<String, dynamic> visualCue) {
    final color = visualCue['color'] as String?;
    final text = visualCue['text'] as String?;
    
    if (color != null && text != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: _hexToColor(color),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Hex 컬러 문자열을 Color로 변환
  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  /// STT 메시지 스트림 구독
  void _subscribeToSTTMessages() {
    _sttSubscription = _audioService.sttMessageStream?.listen(
      (response) {
        if (mounted) {
          _handleSTTResponse(response);
        }
      },
      onError: (error) {
        print('❌ STT 스트림 에러: $error');
        _showErrorSnackBar('음성 인식 오류: $error');
      },
    );
  }

  /// STT 응답 처리 및 realtime-service로 전송
  void _handleSTTResponse(STTResponse response) {
    setState(() {
      switch (response.type) {
        case 'connected':
          print('✅ STT 연결됨: ${response.connectionId}');
          break;
          
        case 'transcription':
          if (response.text != null && response.text!.isNotEmpty) {
            // STT 결과에서 분석 데이터 추출 및 화면 업데이트
            _updateAnalysisFromSTT(response);
            
            if (response.isFinal == true) {
              // 최종 전사 결과 - realtime-service로 전송
              _transcription += '${response.text} ';
              _sendToRealtimeService(response);
            } else {
              // 임시 전사 결과 (실시간 업데이트)
              final sentences = _transcription.split(' ');
              if (sentences.isNotEmpty) {
                sentences[sentences.length - 1] = response.text!;
                _transcription = sentences.join(' ');
              } else {
                _transcription = response.text!;
              }
            }
          }
          break;
          
        case 'status':
          print('ℹ️ STT 상태: ${response.message}');
          break;
          
        case 'error':
          print('❌ STT 에러: ${response.message}');
          _showErrorSnackBar('음성 인식 오류: ${response.message}');
          break;
      }
    });
  }

  /// STT 결과에서 분석 데이터를 추출하여 화면 상태 업데이트
  void _updateAnalysisFromSTT(STTResponse response) {
    try {
      // JSON에서 직접 데이터 추출 (STTResponse.fromJson에서 파싱된 데이터 사용)
      final rawData = response.toJson();
      
      // 이전 값들 저장 (변화 감지용)
      final prevSpeakingSpeed = _speakingSpeed;
      final prevEmotionState = _emotionState;
      final prevInterest = _interest;
      final prevLikability = _likability;
      
      // speech_metrics 처리
      final speechMetrics = rawData['speech_metrics'] as Map<String, dynamic>?;
      if (speechMetrics != null) {
        // 말하기 속도 업데이트
        final evaluationWpm = speechMetrics['evaluation_wpm'] as num?;
        if (evaluationWpm != null) {
          _speakingSpeed = evaluationWpm.round();
          print('📊 말하기 속도 업데이트: $_speakingSpeed WPM');
        }
        
        // 속도 카테고리에 따른 감정 상태 업데이트
        final speedCategory = speechMetrics['speed_category'] as String?;
        if (speedCategory != null) {
          _emotionState = _mapSpeedToEmotion(speedCategory);
          print('📊 감정 상태 업데이트: $_emotionState (속도: $speedCategory)');
        }
        
        // 말하기 패턴에 따른 관심도 업데이트
        final speechPattern = speechMetrics['speech_pattern'] as String?;
        if (speechPattern != null) {
          _interest = _mapPatternToInterest(speechPattern);
          print('📊 관심도 업데이트: $_interest (패턴: $speechPattern)');
        }
        
        // 발화 밀도에 따른 호감도 업데이트
        final speechDensity = speechMetrics['speech_density'] as num?;
        if (speechDensity != null) {
          _likability = _mapDensityToLikability(speechDensity.toDouble());
          print('📊 호감도 업데이트: $_likability (밀도: ${speechDensity.toStringAsFixed(2)})');
        }
      }
      
      // emotion_analysis 처리 (있는 경우)
      final emotionAnalysis = rawData['emotion_analysis'] as Map<String, dynamic>?;
      if (emotionAnalysis != null) {
        final emotion = emotionAnalysis['emotion'] as String?;
        if (emotion != null) {
          _emotionState = emotion;
          print('📊 감정 분석 업데이트: $_emotionState');
        }
      }
      
      // 텍스트 내용 기반 피드백 생성
      final text = response.text ?? '';
      if (text.isNotEmpty) {
        _generateTextBasedFeedback(text, speechMetrics);
      }
      
      // 📳 중요한 변화가 있을 때 바로 Apple Watch로 햅틱 피드백 전송
      _sendImmediateHapticFeedback(
        prevSpeakingSpeed: prevSpeakingSpeed,
        prevEmotionState: prevEmotionState,
        prevInterest: prevInterest,
        prevLikability: prevLikability,
        speechMetrics: speechMetrics,
      );
      
    } catch (e) {
      print('❌ STT 분석 데이터 처리 오류: $e');
    }
  }

  /// 중요한 변화 감지 시 즉시 햅틱 피드백 전송
  Future<void> _sendImmediateHapticFeedback({
    required int prevSpeakingSpeed,
    required String prevEmotionState,
    required int prevInterest,
    required int prevLikability,
    Map<String, dynamic>? speechMetrics,
  }) async {
    if (!_isWatchConnected) {
      print('⚠️ Watch 연결 안됨, 햅틱 피드백 스킵');
      return;
    }

    List<String> hapticMessages = [];

    try {
      // 1. 말하기 속도 변화 (20 WPM 이상 차이날 때)
      if ((_speakingSpeed - prevSpeakingSpeed).abs() >= 20) {
        if (_speakingSpeed > 180) {
          hapticMessages.add('🚀 말하기 속도가 너무 빨라요! ($_speakingSpeed WPM)');
        } else if (_speakingSpeed < 80) {
          hapticMessages.add('🐌 조금 더 활발하게 대화해보세요 ($_speakingSpeed WPM)');
        } else if (_speakingSpeed > prevSpeakingSpeed) {
          hapticMessages.add('📈 말하기 속도가 좋아지고 있어요!');
        }
      }

      // 2. 호감도 변화 (15% 이상 차이날 때)
      if ((_likability - prevLikability).abs() >= 15) {
        if (_likability > prevLikability) {
          hapticMessages.add('💕 호감도가 상승했어요! ($_likability%)');
        } else {
          hapticMessages.add('📉 조금 더 적극적으로 대화해보세요');
        }
      }

      // 3. 관심도 변화 (20% 이상 차이날 때)
      if ((_interest - prevInterest).abs() >= 20) {
        if (_interest > prevInterest) {
          hapticMessages.add('⭐ 상대방의 관심을 끌고 있어요! ($_interest%)');
        }
      }

      // 4. 감정 상태 변화
      if (_emotionState != prevEmotionState && _emotionState != '대기 중') {
        hapticMessages.add('😊 감정 상태: $_emotionState');
      }

      // 5. 특별한 패턴 감지
      if (speechMetrics != null) {
        final speechPattern = speechMetrics['speech_pattern'] as String?;
        final speedCategory = speechMetrics['speed_category'] as String?;
        
        if (speechPattern == 'very_sparse') {
          hapticMessages.add('💭 더 연결된 대화를 시도해보세요');
        } else if (speechPattern == 'continuous' && speedCategory == 'normal') {
          hapticMessages.add('✨ 완벽한 대화 패턴이에요!');
        }
        
        if (speedCategory == 'very_fast') {
          hapticMessages.add('⏰ 잠깐 숨을 고르고 천천히 말해보세요');
        }
      }

      // 6. 긍정적인 피드백 (높은 수치일 때)
      if (_likability >= 80 && _interest >= 80) {
        hapticMessages.add('🎉 환상적인 대화입니다!');
      }

      // 햅틱 메시지가 있으면 전송 (최대 2개까지)
      final messagesToSend = hapticMessages.take(2).toList();
      for (String message in messagesToSend) {
        await _watchService.sendHapticFeedback(message);
        print('📳 즉시 햅틱 피드백 전송: $message');
        
        // 메시지 간 간격 (0.5초)
        if (messagesToSend.length > 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      // 피드백이 있으면 화면에도 표시
      if (messagesToSend.isNotEmpty) {
        _feedback = messagesToSend.join('\n');
      }

    } catch (e) {
      print('❌ 즉시 햅틱 피드백 전송 실패: $e');
    }
  }

  /// 속도 카테고리를 감정으로 매핑
  String _mapSpeedToEmotion(String speedCategory) {
    switch (speedCategory) {
      case 'very_slow':
        return '침착함';
      case 'slow':
        return '안정적';
      case 'normal':
        return '자연스러움';
      case 'fast':
        return '활발함';
      case 'very_fast':
        return '흥미로움';
      default:
        return '대기 중';
    }
  }

  /// 말하기 패턴을 관심도로 매핑 (0-100)
  int _mapPatternToInterest(String speechPattern) {
    switch (speechPattern) {
      case 'very_sparse':
        return 30; // 띄엄띄엄 말하면 관심도 낮음
      case 'staccato':
        return 50; // 끊어서 말하면 보통
      case 'normal':
        return 70; // 일반적이면 적당한 관심
      case 'continuous':
        return 85; // 연속적이면 높은 관심
      case 'steady':
        return 80; // 일정하면 안정적 관심
      case 'variable':
        return 75; // 변화가 있으면 적당한 관심
      default:
        return 0;
    }
  }

  /// 발화 밀도를 호감도로 매핑 (0-100)
  int _mapDensityToLikability(double speechDensity) {
    if (speechDensity < 0.3) {
      return 20; // 발화 밀도가 낮으면 호감도 낮음
    } else if (speechDensity < 0.5) {
      return 40;
    } else if (speechDensity < 0.7) {
      return 60;
    } else if (speechDensity < 0.8) {
      return 80;
    } else {
      return 90; // 발화 밀도가 높으면 호감도 높음
    }
  }

  /// 텍스트 내용 기반 피드백 생성
  void _generateTextBasedFeedback(String text, Map<String, dynamic>? speechMetrics) {
    String feedback = '';
    
    // 말하기 속도 피드백
    if (speechMetrics != null) {
      final speedCategory = speechMetrics['speed_category'] as String?;
      final evaluationWpm = speechMetrics['evaluation_wpm'] as num?;
      
      if (speedCategory == 'very_fast' && evaluationWpm != null) {
        feedback = '말하기 속도가 조금 빠른 편입니다 (${evaluationWpm.round()} WPM)';
      } else if (speedCategory == 'very_slow') {
        feedback = '조금 더 활발하게 대화해보세요';
      } else if (speedCategory == 'normal') {
        feedback = '자연스러운 말하기 속도입니다';
      }
      
      // 발화 패턴 피드백
      final speechPattern = speechMetrics['speech_pattern'] as String?;
      if (speechPattern == 'very_sparse') {
        if (feedback.isNotEmpty) feedback += '\n';
        feedback += '더 연결된 대화를 시도해보세요';
      }
    }
    
    // 텍스트 길이 기반 피드백
    if (text.length > 100) {
      if (feedback.isNotEmpty) feedback += '\n';
      feedback += '좋습니다! 적극적으로 대화하고 있어요';
    }
    
    if (feedback.isNotEmpty) {
      _feedback = feedback;
    }
  }

  /// STT 결과를 realtime-service로 전송
  Future<void> _sendToRealtimeService(STTResponse response) async {
    if (!_isRealtimeConnected) {
      print('⚠️ realtime-service 연결 안됨, STT 결과 전송 스킵');
      return;
    }

    try {
      // AuthService에서 실제 액세스 토큰 가져오기
      final authService = AuthService();
      final accessToken = await authService.getAccessToken();
      
      if (accessToken == null) {
        print('❌ STT 결과 전송 실패: 액세스 토큰 없음');
        return;
      }
      
      final success = await _realtimeService.sendSTTResult(
        sessionId: widget.sessionId,
        sttResponse: response,
        scenario: _currentScenario,
        language: 'ko',
        accessToken: accessToken,
      );
      
      if (success) {
        print('✅ STT 결과를 realtime-service로 전송 성공');
      } else {
        print('❌ STT 결과 realtime-service 전송 실패');
      }
    } catch (e) {
      print('❌ STT 결과 전송 오류: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  // Watch 연결 상태 확인
  Future<void> _checkWatchConnection() async {
    try {
      final isConnected = await _watchService.isWatchConnected();
      setState(() {
        _isWatchConnected = isConnected;
      });
    } catch (e) {
      print('Watch 연결 상태 확인 실패: $e');
    }
  }

  // Watch와 주기적 동기화
  void _startWatchSync() {
    _watchSyncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _syncWithWatch();
    });
  }

  // Watch에 실시간 데이터 전송
  Future<void> _syncWithWatch() async {
    if (!_isWatchConnected) return;

    try {
      // 실시간 분석 데이터를 구조화된 형태로 전송
      await _watchService.sendRealtimeAnalysis(
        likability: _likability,
        interest: _interest,
        speakingSpeed: _speakingSpeed,
        emotion: _emotionState,
        feedback: _feedback,
        elapsedTime: _formatTime(_seconds),
      );

      // 중요한 피드백이 있을 때만 별도 햅틱 알림
      if (_feedback.isNotEmpty && _feedback.contains('속도')) {
        await _watchService.sendHapticFeedback(_feedback);
      }
    } catch (e) {
      print('Watch 동기화 실패: $e');
    }
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleRecording() async {
    if (!_isAudioInitialized) {
      _showErrorSnackBar('오디오 서비스가 초기화되지 않았습니다');
      return;
    }

    if (_isRecording) {
      // 녹음 중지
      await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
      });
    } else {
      // 녹음 시작
      final success = await _audioService.startRealTimeRecording();
      if (success) {
        setState(() {
          _isRecording = true;
        });
      } else {
        _showErrorSnackBar('녹음 시작에 실패했습니다');
      }
    }
  }

  void _endSession() async {
    _timer.cancel();
    _watchSyncTimer.cancel();

    // 오디오 녹음 중지
    await _audioService.stopRecording();

    // Watch에 세션 종료 알림
    try {
      await _watchService.stopSession();
    } catch (e) {
      print('Watch 세션 종료 알림 실패: $e');
    }

    // 세션 종료 및 분석 결과 저장
    Provider.of<AnalysisProvider>(context, listen: false)
        .stopAnalysis(widget.sessionId);

    // 메인 화면의 분석 탭으로 이동 (인덱스 1)
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
      arguments: {'initialTabIndex': 1},
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Watch 세션 시작 및 테스트 햅틱 전송
  Future<void> _startWatchSession() async {
    try {
      // Watch 세션 시작
      await _watchService.startSession('dating');
      print('✅ Watch 세션 시작 성공');
      
      // 2초 후 테스트 햅틱 피드백 전송
      await Future.delayed(Duration(seconds: 2));
      
      if (_isWatchConnected) {
        await _watchService.sendHapticFeedback('🎙️ HaptiTalk 실시간 분석이 시작되었습니다!');
        print('📳 세션 시작 햅틱 피드백 전송 완료');
        
        // 5초 후 추가 테스트 햅틱
        await Future.delayed(Duration(seconds: 3));
        await _watchService.sendHapticFeedback('💡 음성을 인식하고 있습니다. 자연스럽게 대화해보세요!');
        print('📳 음성 인식 안내 햅틱 피드백 전송 완료');
      } else {
        print('⚠️ Watch가 연결되지 않아 햅틱 피드백을 보낼 수 없습니다');
      }
    } catch (e) {
      print('❌ Watch 세션 시작 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildSessionHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildTranscriptionArea(),
                      const SizedBox(height: 20),
                      _buildMetricsSection(),
                      const SizedBox(height: 15),
                      if (_feedback.isNotEmpty) _buildFeedbackSection(),
                      const SizedBox(height: 15),
                      _buildSuggestedTopicsSection(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
            _buildControlsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.black.withOpacity(0.2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 18),
                const SizedBox(width: 5),
                Text(
                  '소개팅',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatTime(_seconds),
            style: TextStyle(
              color: AppColors.lightText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              // STT 연결 상태
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _audioService.isSTTConnected ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'STT',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 15),
              // Watch 연결 상태
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isWatchConnected ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Watch',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 15),
              // 녹음 상태
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '녹음중',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.text_snippet,
                color: AppColors.lightText,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '실시간 음성 인식',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _transcription.isEmpty ? '음성을 인식하고 있습니다...' : _transcription,
            style: TextStyle(
              color: _transcription.isEmpty ? AppColors.disabledText : AppColors.lightText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '주요 지표',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                '실시간',
                style: TextStyle(
                  color: AppColors.disabledText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: '감정 상태',
                  value: _emotionState,
                  icon: Icons.sentiment_satisfied_alt,
                  isTextValue: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: '말하기 속도',
                  value: '$_speakingSpeed/분',
                  icon: Icons.speed,
                  progressValue: _speakingSpeed / 200,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: '호감도',
                  value: '$_likability%',
                  icon: Icons.favorite,
                  progressValue: _likability / 100,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: '관심도',
                  value: '$_interest%',
                  icon: Icons.star,
                  progressValue: _interest / 100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    bool isTextValue = false,
    double? progressValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.lightText,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Icon(icon, size: 16, color: AppColors.lightText),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: AppColors.lightText,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _feedback,
              style: TextStyle(
                color: AppColors.lightText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedTopicsSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 5),
              Text(
                '추천 대화 주제',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _suggestedTopics.map((topic) {
              bool isHighlighted = topic == '여행 경험';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.darkCardBackground,
                  border: isHighlighted
                      ? Border.all(color: AppColors.primary)
                      : null,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  topic,
                  style: TextStyle(
                    color: isHighlighted
                        ? AppColors.accentLight
                        : AppColors.lightText,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      color: AppColors.darkBackground,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[700],
            child: IconButton(
              icon: const Icon(Icons.pause, color: Colors.white),
              onPressed: () async {
                if (_isRecording) {
                  await _audioService.pauseRecording();
                }
              },
            ),
          ),
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.red,
            child: IconButton(
              icon: const Icon(Icons.stop, color: Colors.white),
              onPressed: _endSession,
            ),
          ),
          CircleAvatar(
            radius: 25,
            backgroundColor: _isRecording 
                ? Colors.red 
                : (_isAudioInitialized ? Colors.green : Colors.grey[700]),
            child: IconButton(
              icon: Icon(
                _isRecording ? Icons.mic : Icons.mic_off,
                color: Colors.white,
              ),
              onPressed: _toggleRecording,
            ),
          ),
        ],
      ),
    );
  }
}
