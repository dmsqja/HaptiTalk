import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/analysis/analysis_result.dart';
import '../repositories/analysis_repository.dart';

class AnalysisProvider extends ChangeNotifier {
  final AnalysisRepository _analysisRepository;

  AnalysisResult? _currentAnalysis;
  List<AnalysisResult> _analysisHistory = [];
  bool _isAnalyzing = false;
  String? _transcription;
  String? _feedback;
  String _emotionState = '긍정적';
  int _speakingSpeed = 85;
  int _likability = 78;
  int _interest = 92;
  List<String> _suggestedTopics = [];
  bool _isLoading = false;
  String? _error;

  // 실시간 분석을 위한 스트림 컨트롤러
  StreamController<AnalysisResult>? _analysisStreamController;
  Stream<AnalysisResult>? _analysisStream;

  AnalysisProvider({required AnalysisRepository analysisRepository})
      : _analysisRepository = analysisRepository;

  // Getters
  AnalysisResult? get currentAnalysis => _currentAnalysis;
  List<AnalysisResult> get analysisHistory => _analysisHistory;
  bool get isAnalyzing => _isAnalyzing;
  String? get transcription => _transcription;
  String? get feedback => _feedback;
  String get emotionState => _emotionState;
  int get speakingSpeed => _speakingSpeed;
  int get likability => _likability;
  int get interest => _interest;
  List<String> get suggestedTopics => _suggestedTopics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<AnalysisResult>? get analysisStream => _analysisStream;

  // 분석 시작
  Future<void> startAnalysis(String sessionId) async {
    try {
      _setLoading(true);

      // 초기 상태 설정
      _isAnalyzing = true;
      _transcription = '';
      _feedback = '';
      _suggestedTopics = [];

      // 실시간 분석을 위한 스트림 컨트롤러 생성
      _analysisStreamController = StreamController<AnalysisResult>.broadcast();
      _analysisStream = _analysisStreamController?.stream;

      // 실제 앱에서는 repository를 통해 분석 시작하고 스트림 구독
      // 이 예제에서는 더미 데이터 사용
      _setupDummyAnalysis(sessionId);

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // 예시용 더미 분석 데이터 설정
  void _setupDummyAnalysis(String sessionId) {
    // 초기 추천 주제 설정
    _suggestedTopics = ['여행 경험', '좋아하는 여행지', '사진 취미', '역사적 장소', '제주도 명소'];
    notifyListeners();

    // 약간의 지연 후 첫 번째 분석 결과 발행
    Future.delayed(Duration(seconds: 3), () {
      if (!_isAnalyzing) return;

      _transcription = '저는 평소에 여행을 좋아해서 시간이 날 때마다 이곳저곳 다니는 편이에요.';
      notifyListeners();

      // 더 많은 지연 후 업데이트된 결과 발행
      Future.delayed(Duration(seconds: 5), () {
        if (!_isAnalyzing) return;

        _transcription =
            '저는 평소에 여행을 좋아해서 시간이 날 때마다 이곳저곳 다니는 편이에요. 사진 찍는 것도 좋아해서 여행지에서 사진을 많이 찍어요.';
        _speakingSpeed = 90;
        _feedback = '말하기 속도가 빨라지고 있어요. 좀 더 천천히 말해보세요.';
        notifyListeners();

        // 마지막 업데이트
        Future.delayed(Duration(seconds: 7), () {
          if (!_isAnalyzing) return;

          _transcription =
              '저는 평소에 여행을 좋아해서 시간이 날 때마다 이곳저곳 다니는 편이에요. 사진 찍는 것도 좋아해서 여행지에서 사진을 많이 찍어요. 특히 자연 경관이 아름다운 곳이나 역사적인 장소를 방문하는 걸 좋아합니다. 최근에는 제주도에 다녀왔는데, 정말 예뻤어요. 다음에는 어디로 여행 가보셨나요?';
          _likability = 78;
          _interest = 92;
          notifyListeners();
        });
      });
    });
  }

  // 분석 종료
  Future<void> stopAnalysis(String sessionId) async {
    if (!_isAnalyzing) return;

    try {
      _setLoading(true);

      _isAnalyzing = false;

      // 실시간 분석 스트림 닫기
      await _analysisStreamController?.close();
      _analysisStreamController = null;

      // 최종 분석 결과 생성
      _currentAnalysis = await _analysisRepository.getAnalysisResult(sessionId);

      // 분석 결과를 기록에 추가
      if (_currentAnalysis != null) {
        _analysisHistory.add(_currentAnalysis!);
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // 특정 세션의 분석 결과 조회
  Future<AnalysisResult?> getSessionAnalysis(String sessionId) async {
    try {
      _setLoading(true);

      final result = await _analysisRepository.getAnalysisResult(sessionId);

      _setLoading(false);
      return result;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // 분석 기록 조회
  Future<void> fetchAnalysisHistory() async {
    try {
      _setLoading(true);

      _analysisHistory = await _analysisRepository.getAnalysisHistory();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _error = null;
    notifyListeners();
  }

  // 에러 설정
  void _setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _analysisStreamController?.close();
    super.dispose();
  }

  // 세션 ID로 분석 결과를 가져오는 메서드
  Future<AnalysisResult> getAnalysisResult(String sessionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _analysisRepository.getAnalysisResult(sessionId);
      _currentAnalysis = result;

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      print('Error in getAnalysisResult: $e');
      // 오류가 발생해도 기본 데이터를 반환
      return await _analysisRepository.getAnalysisResult('default');
    }
  }

  // 분석 결과 상태 초기화
  void clearAnalysisResult() {
    _currentAnalysis = null;
    _error = null;
    notifyListeners();
  }

  // 분석 결과 삭제
  Future<void> deleteAnalysisResult(String sessionId) async {
    try {
      _setLoading(true);

      await _analysisRepository.deleteAnalysisResult(sessionId);

      // 로컬 기록에서도 제거
      _analysisHistory.removeWhere((analysis) => analysis.sessionId == sessionId);

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }
}
