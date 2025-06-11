import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/analysis/analysis_result.dart';
import '../models/analysis/emotion_data.dart';
import '../models/analysis/metrics.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class AnalysisRepository {
  final ApiService _apiService;
  final LocalStorageService _storageService;
  final Random _random = Random();

  AnalysisRepository(this._apiService, this._storageService);

  // 세션 ID로 분석 결과 조회 (리포트 기반)
  Future<AnalysisResult> getAnalysisResult(String sessionId) async {
    try {
      print('🔍 분석 결과 조회 시작: $sessionId');
      
      // 🔥 1단계: 세션 ID로 직접 기존 리포트 조회
      try {
        final sessionReportResponse = await _apiService.get('/reports/session/$sessionId');
        
        if (sessionReportResponse['success'] == true && sessionReportResponse['data'] != null) {
          print('✅ 기존 리포트 조회 성공: $sessionId');
          return AnalysisResult.fromApiResponse(sessionReportResponse['data']);
        }
      } catch (e) {
        print('⚠️ 기존 리포트 없음, 새로 생성: $e');
      }
      
      // 🔥 2단계: 기존 리포트가 없으면 새로 생성
      print('🔄 새 리포트 생성 시작: $sessionId');
      final generateResponse = await _apiService.post('/reports/generate/$sessionId', body: {
        'format': 'json',
        'includeCharts': true,
        'detailLevel': 'detailed'
      });
      
      if (generateResponse['success'] == true && generateResponse['data'] != null) {
        print('✅ 새 분석 결과 생성 성공');
        return AnalysisResult.fromApiResponse(generateResponse['data']);
      } else {
        print('⚠️ API 응답 오류, 데모 데이터 사용: ${generateResponse['success']}');
        return await _loadDemoAnalysisResult(sessionId);
      }
    } catch (e) {
      print('❌ 분석 결과 API 호출 실패: $e');
      return await _loadDemoAnalysisResult(sessionId);
    }
  }

  // 분석 결과 기록 조회
  Future<List<AnalysisResult>> getAnalysisHistory() async {
    try {
      print('📋 분석 기록 목록 조회 시작');
      
      // 🔥 실제 report-service API 호출로 변경 (올바른 경로)
      final response = await _apiService.get('/reports');
      
      if (response['success'] == true && response['data'] != null) {
        // ✅ 올바른 응답 구조: response['data']['reports']
        final reportsData = response['data']['reports'] as List<dynamic>;
        print('✅ 실제 분석 기록 조회 성공: ${reportsData.length}개');
        
        List<AnalysisResult> results = [];
        for (var reportData in reportsData) {
          try {
            // 🔥 리포트 ID가 있으면 그대로 사용, 없으면 _id 사용, 그것도 없으면 sessionId 사용
            final reportId = reportData['id'] ?? reportData['_id']?.toString() ?? reportData['sessionId'];
            if (reportId == null) {
              print('⚠️ 리포트 ID를 찾을 수 없음: $reportData');
              continue;
            }
            
            // 🔧 reportId가 MongoDB ObjectId 형식이면 리포트 ID로, 그렇지 않으면 세션 ID로 조회
            String endpoint;
            if (reportId.length == 24 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(reportId)) {
              // MongoDB ObjectId 형식 (24자리 16진수)
              endpoint = '/reports/$reportId';
            } else {
              // UUID 또는 다른 형식 - 세션 ID로 조회
              endpoint = '/reports/session/$reportId';
            }
            
            final detailResponse = await _apiService.get(endpoint);
            if (detailResponse['success'] == true && detailResponse['data'] != null) {
              results.add(AnalysisResult.fromApiResponse(detailResponse['data']));
            }
          } catch (e) {
            print('⚠️ 개별 리포트 조회 실패: ${reportData['id'] ?? reportData['_id'] ?? reportData['sessionId']} - $e');
            // 개별 실패는 무시하고 계속 진행
          }
        }
        
        // 최신 순으로 정렬
        results.sort((a, b) => b.sessionStartTime.compareTo(a.sessionStartTime));
        
        return results;
      } else {
        print('⚠️ 분석 기록 API 응답 오류, 로컬 스토리지 조회');
        // API 오류 시 로컬 스토리지에서 조회 (기존 로직)
        return await _getLocalAnalysisHistory();
      }
    } catch (e) {
      print('❌ 분석 기록 API 호출 실패: $e');
      // API 연결 실패 시 로컬 스토리지에서 조회 (기존 로직)
      return await _getLocalAnalysisHistory();
    }
  }

  // 로컬 스토리지에서 분석 기록 조회 (폴백용)
  Future<List<AnalysisResult>> _getLocalAnalysisHistory() async {
    try {
      // 로컬 스토리지에서 분석 결과 목록 조회
      final jsonResults = await _storageService.getItem('analysis_results');

      if (jsonResults == null) {
        print('ℹ️ 로컬 분석 기록 없음');
        return [];
      }

      final resultsData = json.decode(jsonResults) as List<dynamic>;
      print('✅ 로컬 분석 기록 조회: ${resultsData.length}개');
      return resultsData
          .map((resultData) => AnalysisResult.fromJson(resultData))
          .toList();
    } catch (e) {
      print('❌ 로컬 분석 기록 조회 실패: $e');
      return [];
    }
  }

  // 분석 결과 저장 (내부 메서드)
  Future<void> _saveAnalysisResult(AnalysisResult result) async {
    try {
      // 기존 분석 결과 목록 조회
      List<AnalysisResult> results = await getAnalysisHistory();

      // 기존 결과가 있으면 업데이트, 없으면 추가
      final index = results.indexWhere((r) => r.sessionId == result.sessionId);
      if (index >= 0) {
        results[index] = result;
      } else {
        results.add(result);
      }

      // 업데이트된 결과 목록 저장
      await _storageService.setItem(
        'analysis_results',
        json.encode(results.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      throw Exception('분석 결과 저장 실패: $e');
    }
  }

  // 랜덤 감정 상태 선택
  String _getRandomEmotionState() {
    final states = ['긍정적', '중립적', '열정적', '흥미로움', '활기참'];
    return states[_random.nextInt(states.length)];
  }

  // 데모 분석 결과 로드
  Future<AnalysisResult> _loadDemoAnalysisResult(String sessionId) async {
    try {
      // 데모 데이터 (JSON 파일에서 로드) - 실제 프로젝트에서는 assets에 넣고 사용
      await Future.delayed(Duration(milliseconds: 800)); // API 호출 시뮬레이션

      // 데모 데이터 생성
      final emotionData = List.generate(
        60, // 1분간의 데이터
        (index) => EmotionData(
          timestamp: index.toDouble(),
          emotionType: index % 20 < 10 ? '긍정적' : '부정적',
          value: 50 + (index % 10) * 5,
          description: '감정 데이터 $index',
        ),
      );

      final emotionChangePoints = [
        EmotionChangePoint(
          time: '00:05:21',
          timestamp: 321,
          description: '주제에 대한 관심 표현',
          emotionValue: 85,
          label: '관심 증가',
          topics: ['취미', '여행'],
        ),
        EmotionChangePoint(
          time: '00:12:48',
          timestamp: 768,
          description: '의견 불일치 발생',
          emotionValue: 35,
          label: '부정적 변화',
          topics: ['정치', '사회 이슈'],
        ),
        EmotionChangePoint(
          time: '00:18:15',
          timestamp: 1095,
          description: '공통 관심사 발견',
          emotionValue: 90,
          label: '긍정적 전환',
          topics: ['영화', '음악'],
        ),
      ];

      final habitPatterns = [
        HabitPattern(
          type: '습관어 반복',
          count: 15,
          description: '대화 중 "음...", "그니까" 등의 표현을 자주 사용합니다.',
          examples: ['음...', '그니까', '뭐지'],
        ),
        HabitPattern(
          type: '말 끊기',
          count: 5,
          description: '상대방의 말을 끊고 본인의 이야기를 시작하는 경우가 있습니다.',
          examples: ['잠깐만요', '그게 아니라'],
        ),
        HabitPattern(
          type: '속도 변화',
          count: 8,
          description: '흥미로운 주제에서 말의 속도가 빨라지는 패턴이 있습니다.',
          examples: ['취미 이야기', '영화 이야기'],
        ),
      ];

      final emotionFeedbacks = [
        EmotionFeedback(
          type: '긍정적인 포인트',
          content: '상대방의 이야기에 관심을 보이며 적극적으로 반응합니다.',
        ),
        EmotionFeedback(
          type: '개선 포인트',
          content: '민감한 주제에서 감정 표현이 다소 과격해집니다.',
        ),
        EmotionFeedback(
          type: '제안',
          content: '상대방의 관점을 더 이해하려는 질문을 해보세요.',
        ),
      ];

      final topics = [
        ConversationTopic(
          name: '취미',
          percentage: 35,
          isPrimary: true,
        ),
        ConversationTopic(
          name: '일상',
          percentage: 25,
          isPrimary: false,
        ),
        ConversationTopic(
          name: '영화',
          percentage: 20,
          isPrimary: false,
        ),
        ConversationTopic(
          name: '여행',
          percentage: 15,
          isPrimary: false,
        ),
        ConversationTopic(
          name: '음악',
          percentage: 5,
          isPrimary: false,
        ),
      ];

      final topicTimepoints = [
        TopicTimepoint(
          time: '00:02:10',
          timestamp: 130,
          description: '인사 및 안부 나눔',
          topics: ['일상'],
        ),
        TopicTimepoint(
          time: '00:08:45',
          timestamp: 525,
          description: '취미 활동에 대한 대화 시작',
          topics: ['취미', '여행'],
        ),
        TopicTimepoint(
          time: '00:15:30',
          timestamp: 930,
          description: '최근 본 영화에 대한 이야기',
          topics: ['영화', '음악'],
        ),
      ];

      final topicInsights = [
        TopicInsight(
          topic: '취미',
          insight: '취미 활동에 대한 대화에서 가장 활발한 상호작용이 이루어졌습니다.',
        ),
        TopicInsight(
          topic: '일상',
          insight: '일상 대화는 편안한 분위기를 조성했지만 깊이 있는 대화로 발전하지 못했습니다.',
        ),
        TopicInsight(
          topic: '영화',
          insight: '영화 취향이 비슷하여 공감대 형성에 도움이 되었습니다.',
        ),
      ];

      final recommendedTopics = [
        RecommendedTopic(
          topic: '여행',
          description: '여행에 대한 더 구체적인 경험과 계획에 대해 이야기해보세요.',
          questions: [
            '가장 기억에 남는 여행지는 어디인가요?',
            '다음에 가보고 싶은 여행지가 있나요?',
            '여행 중 특별한 경험이 있었나요?'
          ],
        ),
        RecommendedTopic(
          topic: '음식',
          description: '음식 취향은 개인의 성향을 잘 보여주는 주제입니다.',
          questions: [
            '좋아하는 음식이나 요리는 무엇인가요?',
            '직접 요리해본 음식이 있나요?',
            '특별한 음식 관련 추억이 있나요?'
          ],
        ),
      ];

      return AnalysisResult(
        sessionId: sessionId,
        title: '첫 번째 미팅 대화',
        date: DateTime.now().subtract(Duration(days: 2, hours: 5)),
        sessionStartTime: DateTime.now().subtract(Duration(days: 2, hours: 5)),
        category: '소개팅',
        emotionData: emotionData.cast<EmotionData>(),
        emotionChangePoints: emotionChangePoints,
        rawApiData: {}, // 🔥 빈 맵으로 초기화 (데모 데이터용)
        metrics: SessionMetrics(
          totalDuration: 1800, // 30분
          audioRecorded: true,
          speakingMetrics: SpeakingMetrics(
            speechRate: 125, // 분당 단어 수
            tonality: 75, // %
            clarity: 85, // %
            habitPatterns: habitPatterns,
          ),
          emotionMetrics: EmotionMetrics(
            averageInterest: 72, // %
            averageLikeability: 68, // %
            peakLikeability: 92, // %
            lowestLikeability: 35, // %
            feedbacks: emotionFeedbacks,
          ),
          conversationMetrics: ConversationMetrics(
            contributionRatio: 55, // %
            listeningScore: 78, // %
            interruptionCount: 5,
            flowDescription:
                '전반적으로 자연스러운 대화 흐름을 유지하였으나, 일부 주제에서 의견 불일치가 있었습니다.',
          ),
          topicMetrics: TopicMetrics(
            topics: topics,
            timepoints: topicTimepoints,
            insights: topicInsights,
            recommendations: recommendedTopics,
          ),
        ),
      );
    } catch (e) {
      throw Exception('데모 분석 결과 생성에 실패했습니다: $e');
    }
  }

  // 분석 결과 삭제
  Future<void> deleteAnalysisResult(String sessionId) async {
    try {
      print('🗑️ 세션 분석 결과 삭제: $sessionId');
      
      // 1단계: 먼저 리포트 목록에서 해당 세션의 리포트 ID 찾기
      try {
        final reportsResponse = await _apiService.get('/reports');
        
        if (reportsResponse['success'] == true && reportsResponse['data'] != null) {
          final reportsData = reportsResponse['data']['reports'] as List<dynamic>;
          
          // 해당 세션 ID의 리포트 찾기
          final sessionReport = reportsData.firstWhere(
            (report) => report['sessionId'] == sessionId,
            orElse: () => null,
          );
          
          if (sessionReport != null) {
            final reportId = sessionReport['id'] ?? sessionReport['_id'];
            
            if (reportId != null && reportId.toString().isNotEmpty) {
              // 2단계: 리포트 API로 삭제
              await _apiService.delete('/reports/$reportId');
              print('✅ 서버에서 리포트 삭제 성공: $reportId');
            }
          }
        }
      } catch (e) {
        print('⚠️ 서버 삭제 실패: $e, 로컬에서만 삭제');
      }
      
      // 3단계: 로컬 스토리지에서도 삭제
      await _deleteLocalAnalysisResult(sessionId);
      print('✅ 로컬 삭제 완료: $sessionId');
      
    } catch (e) {
      print('❌ 분석 결과 삭제 실패: $e');
      throw Exception('분석 결과 삭제 실패: $e');
    }
  }

  // 로컬 스토리지에서 분석 결과 삭제
  Future<void> _deleteLocalAnalysisResult(String sessionId) async {
    try {
      // 기존 분석 결과 목록 조회
      List<AnalysisResult> results = await _getLocalAnalysisHistory();

      // 해당 세션 제거
      results.removeWhere((result) => result.sessionId == sessionId);

      // 업데이트된 결과 목록 저장
      await _storageService.setItem(
        'analysis_results',
        json.encode(results.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      print('❌ 로컬 분석 결과 삭제 실패: $e');
    }
  }
}
