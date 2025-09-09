import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

import '../../constants/colors.dart';
import '../../models/analysis/analysis_result.dart';
import '../../models/session/session_model.dart';
import '../../providers/analysis_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/analysis/metrics_card.dart';
import '../../screens/analysis/detailed_report_screen.dart';

class AnalysisSummaryScreen extends StatefulWidget {
  final String sessionId;
  final String? sessionType;

  const AnalysisSummaryScreen({Key? key, required this.sessionId, this.sessionType})
      : super(key: key);

  @override
  State<AnalysisSummaryScreen> createState() => _AnalysisSummaryScreenState();
}

class _AnalysisSummaryScreenState extends State<AnalysisSummaryScreen> {
  late Future<AnalysisResult?> _analysisFuture;

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  void _loadAnalysisData() {
    _analysisFuture = Provider.of<AnalysisProvider>(context, listen: false)
        .getSessionAnalysis(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 분석 결과 헤더
            _buildAnalysisHeader(),
            
            // 스크롤 가능한 콘텐츠
            Expanded(
              child: FutureBuilder<AnalysisResult?>(
                future: _analysisFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '오류가 발생했습니다: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data == null) {
                    return const Center(
                      child: Text('분석 결과를 찾을 수 없습니다.'),
                    );
                  }

                  final analysis = snapshot.data!;
                  return _buildAnalysisContent(analysis);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }



  Widget _buildAnalysisHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Text(
        '분석 결과',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF212121),
          fontSize: 18,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(Icons.home, '홈', false),
          _buildBottomNavItem(Icons.assessment, '분석', true),
          _buildBottomNavItem(Icons.history, '기록', false),
          _buildBottomNavItem(Icons.person, '프로필', false),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          // 메인 탭 화면으로 돌아가고 해당 탭 선택
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/main',
            (route) => false,
            arguments: {'initialTabIndex': _getTabIndex(label)},
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: isSelected ? const Color(0xFF3F51B5) : const Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF3F51B5) : const Color(0xFFBDBDBD),
              fontSize: 12,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  int _getTabIndex(String label) {
    switch (label) {
      case '홈': return 0;
      case '분석': return 1;
      case '기록': return 2;
      case '프로필': return 3;
      default: return 0;
    }
  }

  Widget _buildAnalysisContent(AnalysisResult analysis) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSessionInfoSection(analysis),
          const SizedBox(height: 24),
          _buildTimelineChartSection(analysis),
          const SizedBox(height: 24),
          _buildMetricsSection(analysis),
          const SizedBox(height: 24),
          // 시나리오별로 비율 섹션 표시 여부 결정
          if (analysis.category != '발표') ...[
            _buildSpeakingRatioSection(analysis),
            const SizedBox(height: 24),
          ],
          _buildInsightsSection(analysis),
          const SizedBox(height: 24),
          _buildSuggestionsSection(analysis),
          const SizedBox(height: 24),
          _buildActionButtonsSection(),
        ],
      ),
    );
  }

  Widget _buildSessionInfoSection(AnalysisResult analysis) {
    return FutureBuilder<SessionModel>(
      future: Provider.of<SessionProvider>(context, listen: false)
          .fetchSessionDetails(widget.sessionId)
          .catchError((error) {
        // 세션 조회 실패 시 기본 세션 정보 반환
        print('⚠️ 세션 정보 조회 실패, 기본값 사용: $error');
        
        // 세션 타입 추론 (분석 결과에서 유추)
        SessionMode inferredMode = SessionMode.business; // 기본값을 비즈니스(발표)로 변경
        if (widget.sessionType != null) {
          switch (widget.sessionType!.toLowerCase()) {
            case 'presentation':
            case '발표':
              inferredMode = SessionMode.business; // 발표는 비즈니스 모드로 매핑
              break;
            case 'interview':
            case '면접':
              inferredMode = SessionMode.interview;
              break;

            default:
              inferredMode = SessionMode.business; // 기본값을 비즈니스(발표)로 변경
              break;
          }
        }
        
        return SessionModel(
          id: widget.sessionId,
          name: widget.sessionType != null 
              ? '${widget.sessionType!} 세션'
              : '분석 완료된 세션',
          mode: inferredMode,
          analysisLevel: AnalysisLevel.standard,
          recordingRetention: RecordingRetention.sevenDays,
          createdAt: DateTime.now(),
          duration: Duration(minutes: (analysis.metrics.totalDuration ~/ 60).toInt(), seconds: (analysis.metrics.totalDuration % 60).toInt()),
          isSmartWatchConnected: false,
        );
      }),
      builder: (context, snapshot) {
        final sessionName = snapshot.hasData
            ? (snapshot.data!.name?.isNotEmpty == true ? snapshot.data!.name! : '세션')
            : (widget.sessionType != null ? '${widget.sessionType!} 세션' : '세션');
        final sessionMode = snapshot.hasData 
            ? snapshot.data!.mode 
            : SessionMode.business;

        // 실제 분석 결과에서 duration 가져오기
        final totalSeconds = analysis.metrics.totalDuration.toInt();
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;
        final sessionDuration = hours > 0 
            ? '${hours}시간 ${minutes}분 ${seconds}초' 
            : '${minutes}분 ${seconds}초';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sessionName,
                          style: const TextStyle(
                            color: Color(0xFF212121),
                            fontSize: 22,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatSessionDate(snapshot.hasData ? snapshot.data!.createdAt : DateTime.now()),
                          style: const TextStyle(
                            color: Color(0xFF757575),
                            fontSize: 14,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: ShapeDecoration(
                      color: const Color(0xFF3F51B5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSessionIcon(sessionMode),
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getSessionModeText(sessionMode),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 18,
                    color: Color(0xFF757575),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '총 ${_getSessionModeText(sessionMode)} 시간: $sessionDuration',
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 14,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatSessionDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 오후 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondaryText),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineChartSection(AnalysisResult analysis) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                size: 18,
                color: Color(0xFF3F51B5),
              ),
              const SizedBox(width: 8),
              Text(
                _getChartTitle(analysis.category),
                style: const TextStyle(
                  color: Color(0xFF212121),
                  fontSize: 16,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 160,
            child: _buildTimelineChart(analysis),
          ),
          const SizedBox(height: 10),
          // 시간 라벨들
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _generateTimeLabels(analysis).map((time) => Text(
              time,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  String _getChartTitle(String category) {
    switch (category) {
      case '발표':
        return '발표 성과 변화';
      case '면접':
        return '면접 퍼포먼스 변화';
      default:
        return '감정 변화 그래프';
    }
  }

  Widget _buildTimelineChart(AnalysisResult analysis) {
    // 시나리오별로 다른 데이터 표시
    List<double> values;
    
    if (analysis.category == '발표') {
      // 발표: 자신감 + 설득력 평균
      values = _generatePresentationData(analysis);
    } else if (analysis.category == '면접') {
      // 면접: 안정감 + 명확성 평균
      values = _generateInterviewData(analysis);
    } else {
      // 소개팅: 감정 데이터
      values = _generateEmotionData(analysis);
    }

    // LineChart 데이터 포인트 생성
    final spots = values.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.black.withOpacity(0.1),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => const FlLine(
            color: Colors.transparent,
          ),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (values.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF3F51B5),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF3F51B5),
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  List<String> _generateTimeLabels(AnalysisResult analysis) {
    List<String> labels = [];
    
    final totalSeconds = analysis.metrics.totalDuration.toInt();
    
    // 실제 데이터 포인트 수 확인
    int dataPoints;
    if (analysis.emotionData.isNotEmpty) {
      // 실제 데이터가 있으면 그 수만큼
      dataPoints = analysis.emotionData.length;
    } else {
      // 시뮬레이션 데이터인 경우 5개 포인트
      dataPoints = 5;
    }
    
    // 30초 간격으로 라벨 생성
    for (int i = 0; i < dataPoints; i++) {
      int timeInSeconds;
      
      if (i == dataPoints - 1) {
        // 마지막 포인트는 실제 세션 종료 시간
        timeInSeconds = totalSeconds;
      } else {
        // 나머지는 30초 간격
        timeInSeconds = i * 30;
      }
      
      final minutes = timeInSeconds ~/ 60;
      final seconds = timeInSeconds % 60;
      labels.add('${minutes}:${seconds.toString().padLeft(2, '0')}');
    }
    
    return labels;
  }

  List<double> _generatePresentationData(AnalysisResult analysis) {
    // 🔥 실제 detailedTimeline 데이터가 있으면 30초 간격 그대로 사용
    if (analysis.emotionData.isNotEmpty) {
      print('✅ 발표 그래프: 실제 30초 간격 데이터 사용 (${analysis.emotionData.length}개 포인트)');
      
      // 30초 간격 데이터를 그대로 사용 (압축하지 않음)
      List<double> presentationValues = analysis.emotionData.map((e) => e.value).toList();
      
      print('📊 발표 그래프 30초 간격: ${presentationValues.take(5).map((v) => v.toStringAsFixed(1)).join(', ')}... (총 ${presentationValues.length}개)');
      return presentationValues;
    }
    
    // 🔥 폴백: 시뮬레이션 데이터 (실제 데이터 없을 때만)
    print('⚠️ 발표 그래프: 시뮬레이션 데이터 사용 (실제 데이터 없음)');
    final confidence = analysis.metrics.emotionMetrics.averageLikeability;
    final persuasion = _calculatePersuasionLevel(analysis);
    final average = (confidence + persuasion) / 2;
    
    // 발표는 보통 시작할 때 낮고 중간에 높아지는 패턴
    return [
      average * 0.7,   // 시작: 조금 낮음
      average * 0.85,  // 25%: 점점 상승
      average * 1.1,   // 50%: 최고점
      average * 1.05,  // 75%: 약간 하락
      average * 0.95,  // 완료: 마무리
    ];
  }

  List<double> _generateInterviewData(AnalysisResult analysis) {
    // 🔥 실제 detailedTimeline 데이터가 있으면 30초 간격 그대로 사용
    if (analysis.emotionData.isNotEmpty) {
      print('✅ 면접 그래프: 실제 30초 간격 데이터 사용 (${analysis.emotionData.length}개 포인트)');
      
      // 30초 간격 데이터를 그대로 사용 (압축하지 않음)
      List<double> interviewValues = analysis.emotionData.map((e) => e.value).toList();
      
      print('📊 면접 그래프 30초 간격: ${interviewValues.take(5).map((v) => v.toStringAsFixed(1)).join(', ')}... (총 ${interviewValues.length}개)');
      return interviewValues;
    }
    
    // 🔥 폴백: 시뮬레이션 데이터 (실제 데이터 없을 때만)
    print('⚠️ 면접 그래프: 시뮬레이션 데이터 사용 (실제 데이터 없음)');
    // 면접 시나리오: 안정감과 명확성 평균
    final stability = analysis.metrics.speakingMetrics.tonality;
    final clarity = analysis.metrics.speakingMetrics.clarity;
    final average = (stability + clarity) / 2;
    
    // 면접은 보통 초반에 긴장하다가 안정됨
    return [
      average * 0.6,   // 시작: 긴장
      average * 0.8,   // 25%: 적응
      average * 1.0,   // 50%: 안정
      average * 1.1,   // 75%: 최고점
      average * 1.05,  // 완료: 마무리
    ];
  }

  List<double> _generateEmotionData(AnalysisResult analysis) {
    // 🔥 실제 detailedTimeline 데이터가 있으면 30초 간격 그대로 사용
    if (analysis.emotionData.isNotEmpty) {
      print('✅ 감정 그래프: 실제 30초 간격 데이터 사용 (${analysis.emotionData.length}개 포인트)');
      
      // 30초 간격 데이터를 그대로 사용 (압축하지 않음)
      List<double> emotionValues = analysis.emotionData.map((e) => e.value).toList();
      
      print('📊 감정 그래프 30초 간격: ${emotionValues.take(5).map((v) => v.toStringAsFixed(1)).join(', ')}... (총 ${emotionValues.length}개)');
      return emotionValues;
    }
    
    // 🔥 폴백: 시뮬레이션 데이터 (실제 데이터 없을 때만)
    print('⚠️ 감정 그래프: 시뮬레이션 데이터 사용 (실제 데이터 없음)');
    // 기본값으로 발표 데이터 사용
    final confidence = _calculateSpeakingConfidence(analysis);
    final persuasion = _calculatePersuasionLevel(analysis);
    final average = (confidence + persuasion) / 2;
    
    // 발표는 보통 시작할 때 낮고 중간에 높아지는 패턴
    return [
      average * 0.7,   // 시작: 조금 낮음
      average * 0.85,  // 25%: 점점 상승
      average * 1.1,   // 50%: 최고점
      average * 1.05,  // 75%: 약간 하락
      average * 0.95,  // 완료: 마무리
    ];
  }

  Widget _buildMetricsSection(AnalysisResult analysis) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주요 지표',
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 18,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.23,
            children: _buildMetricCards(analysis),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMetricCards(AnalysisResult analysis) {
    // 시나리오별 지표 설정
    if (analysis.category == '발표') {
      print('📊 발표 지표 계산 시작...');
      
      // 🔥 백엔드에서 이미 계산된 값 우선 사용
      final rawApiData = analysis.rawApiData;
      if (rawApiData.isNotEmpty && rawApiData['keyMetrics'] != null) {
        final keyMetrics = rawApiData['keyMetrics'] as Map<String, dynamic>;
        final presentationMetrics = keyMetrics['presentation'] as Map<String, dynamic>?;
        final speakingMetrics = keyMetrics['speaking'] as Map<String, dynamic>?;
        
        if (presentationMetrics != null && speakingMetrics != null) {
          // ✅ 백엔드에서 계산된 정확한 값 사용
          final confidence = (presentationMetrics['confidence'] ?? 50).toDouble(); // 하드코딩 기본값 낮춤
          final persuasion = (presentationMetrics['persuasion'] ?? 55).toDouble(); // 하드코딩 기본값 낮춤
          final clarity = (presentationMetrics['clarity'] ?? 55).toDouble(); // 하드코딩 기본값 낮춤
          final speechRate = (speakingMetrics['speed'] ?? 120).toDouble();
          
          // 🔥 실제 계산값 vs 기본값 구분 로깅
          final isConfidenceCalculated = presentationMetrics['confidence'] != null;
          final isPersuasionCalculated = presentationMetrics['persuasion'] != null;
          final isClarityCalculated = presentationMetrics['clarity'] != null;
          
          print('📊 발표 지표 (백엔드 계산값): 자신감=${confidence.round()}%${isConfidenceCalculated ? "(계산됨)" : "(기본값)"}, 설득력=${persuasion.round()}%${isPersuasionCalculated ? "(계산됨)" : "(기본값)"}, 명확성=${clarity.round()}%${isClarityCalculated ? "(계산됨)" : "(기본값)"}, 속도=${speechRate.toInt()}WPM');
          
          return [
            _buildMetricCard(
              '자신감',
              '${confidence.round()}%',
              Icons.psychology,
              _getConfidenceDescription(confidence),
            ),
            _buildMetricCard(
              '말하기 속도',
              '${speechRate.toInt()}WPM',
              Icons.speed,
              _getSpeedDescription(speechRate),
            ),
            _buildMetricCard(
              '설득력',
              '${persuasion.round()}%',
              Icons.trending_up,
              _getPersuasionDescription(persuasion),
            ),
            _buildMetricCard(
              '명확성',
              '${clarity.round()}%',
              Icons.radio_button_checked,
              _getClarityDescription(clarity),
            ),
          ];
        }
      }
      
      // 🔥 폴백: 기존 로직 (백엔드 데이터 없을 때만)
      print('⚠️ 백엔드 keyMetrics 없음, 폴백 계산 사용');
      final speechRate = _getSafeMetricValue(analysis.metrics.speakingMetrics.speechRate, 120.0);
      final clarity = _getSafeMetricValue(analysis.metrics.speakingMetrics.clarity, 60.0); // 75→60 조정
      final confidence = _calculateSpeakingConfidence(analysis);
      final persuasion = _calculatePersuasionLevel(analysis);
      
      print('📊 발표 지표 최종값(폴백): 자신감=${confidence.round()}%(계산), 속도=${speechRate.toInt()}WPM, 설득력=${persuasion.round()}%(계산), 명확성=${clarity.toInt()}%(폴백)');
      
      return [
        _buildMetricCard(
          '자신감',
          '${confidence.round()}%',
          Icons.psychology,
          _getConfidenceDescription(confidence),
        ),
        _buildMetricCard(
          '말하기 속도',
          '${speechRate.toInt()}WPM',
          Icons.speed,
          _getSpeedDescription(speechRate),
        ),
        _buildMetricCard(
          '설득력',
          '${persuasion.round()}%',
          Icons.trending_up,
          _getPersuasionDescription(persuasion),
        ),
        _buildMetricCard(
          '명확성',
          '${clarity.toInt()}%',
          Icons.radio_button_checked,
          _getClarityDescription(clarity),
        ),
      ];
    } else if (analysis.category == '면접') {
      print('📊 면접 지표 계산 시작...');
      
      // 🔥 백엔드에서 이미 계산된 값 우선 사용 (면접용)
      final rawApiData = analysis.rawApiData;
      if (rawApiData.isNotEmpty && rawApiData['keyMetrics'] != null) {
        final keyMetrics = rawApiData['keyMetrics'] as Map<String, dynamic>;
        final interviewMetrics = keyMetrics['interview'] as Map<String, dynamic>?;
        final speakingMetrics = keyMetrics['speaking'] as Map<String, dynamic>?;
        
        if (interviewMetrics != null && speakingMetrics != null) {
          final confidence = (interviewMetrics['confidence'] ?? 50).toDouble(); // 60→50 조정
          final stability = (interviewMetrics['stability'] ?? 55).toDouble(); // 하드코딩 기본값 낮춤
          final clarity = (interviewMetrics['clarity'] ?? 55).toDouble(); // 60→55 조정
          final speechRate = (speakingMetrics['speed'] ?? 120).toDouble();
          
          // 🔥 실제 계산값 vs 기본값 구분 로깅
          final isConfidenceCalculated = interviewMetrics['confidence'] != null;
          final isStabilityCalculated = interviewMetrics['stability'] != null;
          final isClarityCalculated = interviewMetrics['clarity'] != null;
          
          print('📊 면접 지표 (백엔드 계산값): 자신감=${confidence.round()}%${isConfidenceCalculated ? "(계산됨)" : "(기본값)"}, 안정감=${stability.round()}%${isStabilityCalculated ? "(계산됨)" : "(기본값)"}, 명확성=${clarity.round()}%${isClarityCalculated ? "(계산됨)" : "(기본값)"}, 속도=${speechRate.toInt()}WPM');
          
          return [
            _buildMetricCard(
              '자신감',
              '${confidence.round()}%',
              Icons.psychology,
              _getConfidenceDescription(confidence),
            ),
            _buildMetricCard(
              '말하기 속도',
              '${speechRate.toInt()}WPM',
              Icons.speed,
              _getSpeedDescription(speechRate),
            ),
            _buildMetricCard(
              '명확성',
              '${clarity.round()}%',
              Icons.radio_button_checked,
              _getClarityDescription(clarity),
            ),
            _buildMetricCard(
              '안정감',
              '${stability.round()}%',
              Icons.sentiment_satisfied_alt,
              _getStabilityDescription(stability),
            ),
          ];
        }
      }
      
      // 폴백: 기존 로직
      final speechRate = _getSafeMetricValue(analysis.metrics.speakingMetrics.speechRate, 120.0);
      final clarity = _getSafeMetricValue(analysis.metrics.speakingMetrics.clarity, 60.0); // 75→60 조정
      final tonality = _getSafeMetricValue(analysis.metrics.speakingMetrics.tonality, 65.0); // 70→65 조정
      final confidence = _calculateSpeakingConfidence(analysis);
      
      print('📊 면접 지표 최종값(폴백): 자신감=${confidence.round()}%(계산), 속도=${speechRate.toInt()}WPM, 명확성=${clarity.toInt()}%(폴백), 안정감=${tonality.toInt()}%(폴백)');
      
      return [
        _buildMetricCard(
          '자신감',
          '${confidence.round()}%',
          Icons.psychology,
          _getConfidenceDescription(confidence),
        ),
        _buildMetricCard(
          '말하기 속도',
          '${speechRate.toInt()}WPM',
          Icons.speed,
          _getSpeedDescription(speechRate),
        ),
        _buildMetricCard(
          '명확성',
          '${clarity.toInt()}%',
          Icons.radio_button_checked,
          _getClarityDescription(clarity),
        ),
        _buildMetricCard(
          '안정감',
          '${tonality.toInt()}%',
          Icons.sentiment_satisfied_alt,
          _getStabilityDescription(tonality),
        ),
      ];
    } else {
      // 기본값으로 발표 지표 사용
      final speechRate = _getSafeMetricValue(analysis.metrics.speakingMetrics.speechRate, 120.0);
      final clarity = _getSafeMetricValue(analysis.metrics.speakingMetrics.clarity, 75.0);
      final confidence = _calculateSpeakingConfidence(analysis);
      final persuasion = _calculatePersuasionLevel(analysis);
      
      return [
        _buildMetricCard(
          '자신감',
          '${confidence.round()}%',
          Icons.psychology,
          _getConfidenceDescription(confidence),
        ),
        _buildMetricCard(
          '말하기 속도',
          '${speechRate.toInt()}WPM',
          Icons.speed,
          _getSpeedDescription(speechRate),
        ),
        _buildMetricCard(
          '설득력',
          '${persuasion.round()}%',
          Icons.trending_up,
          _getPersuasionDescription(persuasion),
        ),
        _buildMetricCard(
          '명확성',
          '${clarity.toInt()}%',
          Icons.radio_button_checked,
          _getClarityDescription(clarity),
        ),
      ];
    }
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, String description) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: ShapeDecoration(
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF424242),
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                icon,
                size: 16,
                color: const Color(0xFF3F51B5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF3F51B5),
              fontSize: 24,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF757575),
              fontSize: 12,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakingRatioSection(AnalysisResult analysis) {
    final contributionRatio = analysis.metrics.conversationMetrics.contributionRatio;
    final myRatio = contributionRatio.toInt();
    final otherRatio = (100 - contributionRatio).toInt();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(20),
            decoration: const ShapeDecoration(
              color: Colors.white,
              shape: CircleBorder(),
            ),
            child: Center(
              child: Text(
                '$myRatio%',
                style: const TextStyle(
                  color: Color(0xFF3F51B5),
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF3F51B5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const Text(
                      '나',
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 13,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$myRatio%',
                      style: const TextStyle(
                        color: Color(0xFF424242),
                        fontSize: 14,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: ShapeDecoration(
                        color: const Color(0xFFE0E0E0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const Text(
                      '상대방',
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 13,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$otherRatio%',
                      style: const TextStyle(
                        color: Color(0xFF424242),
                        fontSize: 14,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(AnalysisResult analysis) {
    final insights = _generateInsights(analysis);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '핵심 인사이트',
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 18,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ...insights.asMap().entries.map((entry) => 
            _buildInsightItem(entry.key + 1, entry.value)
          ).toList(),
        ],
      ),
    );
  }

  List<String> _generateInsights(AnalysisResult analysis) {
    List<String> insights = [];
    
    if (analysis.category == '발표') {
      // 발표 시나리오 인사이트 - 백엔드 계산값 우선 사용
      double confidence, persuasion, speechRate;
      
      // 🔥 백엔드 계산값 우선 사용
      final rawApiData = analysis.rawApiData;
      if (rawApiData.isNotEmpty && rawApiData['keyMetrics'] != null) {
        final keyMetrics = rawApiData['keyMetrics'] as Map<String, dynamic>;
        final presentationMetrics = keyMetrics['presentation'] as Map<String, dynamic>?;
        final speakingMetrics = keyMetrics['speaking'] as Map<String, dynamic>?;
        
        if (presentationMetrics != null && speakingMetrics != null) {
          confidence = (presentationMetrics['confidence'] ?? 50).toDouble(); // 60→50 조정
          persuasion = (presentationMetrics['persuasion'] ?? 55).toDouble(); // 70→55 조정
          speechRate = (speakingMetrics['speed'] ?? 120).toDouble();
          print('📊 인사이트: 백엔드 계산값 사용 - confidence=${confidence}, persuasion=${persuasion}, speed=${speechRate}');
        } else {
          // 폴백
          confidence = _calculateSpeakingConfidence(analysis);
          persuasion = _calculatePersuasionLevel(analysis);
          speechRate = analysis.metrics.speakingMetrics.speechRate;
          print('📊 인사이트: 폴백 계산값 사용');
        }
      } else {
        // 폴백
        confidence = _calculateSpeakingConfidence(analysis);
        persuasion = _calculatePersuasionLevel(analysis);
        speechRate = analysis.metrics.speakingMetrics.speechRate;
        print('📊 인사이트: 폴백 계산값 사용');
      }
      
      if (confidence >= 70) {
        insights.add('발표 중 자신감이 높아 청중들의 주의를 잘 끌었습니다.');
      } else {
        insights.add('발표 중 자신감을 더 보여주면 더 설득력 있는 발표가 될 것입니다.');
      }
      
      if (persuasion >= 70) {
        insights.add('논리적이고 설득력 있는 내용 구성으로 메시지가 잘 전달되었습니다.');
      } else {
        insights.add('핵심 메시지를 더 명확하게 강조하면 설득력을 높일 수 있습니다.');
      }
      
      if (speechRate >= 120 && speechRate <= 150) {
        insights.add('적절한 말하기 속도로 청중이 이해하기 쉬웠을 것입니다.');
      } else if (speechRate > 150) {
        insights.add('말하기 속도가 빨라 중요한 내용을 놓칠 가능성이 있습니다.');
      } else {
        insights.add('말하기 속도를 조금 빠르게 하면 더 역동적인 발표가 될 것입니다.');
      }
      
    } else if (analysis.category == '면접') {
      // 면접 시나리오 인사이트 - 백엔드 계산값 우선 사용
      double confidence, clarity, speechRate;
      
      final rawApiData = analysis.rawApiData;
      if (rawApiData.isNotEmpty && rawApiData['keyMetrics'] != null) {
        final keyMetrics = rawApiData['keyMetrics'] as Map<String, dynamic>;
        final interviewMetrics = keyMetrics['interview'] as Map<String, dynamic>?;
        final speakingMetrics = keyMetrics['speaking'] as Map<String, dynamic>?;
        
        if (interviewMetrics != null && speakingMetrics != null) {
          confidence = (interviewMetrics['confidence'] ?? 50).toDouble(); // 60→50 조정
          clarity = (interviewMetrics['clarity'] ?? 55).toDouble(); // 60→55 조정
          speechRate = (speakingMetrics['speed'] ?? 120).toDouble();
          print('📊 인사이트: 백엔드 계산값 사용 - confidence=${confidence}, clarity=${clarity}');
        } else {
          confidence = _calculateSpeakingConfidence(analysis);
          clarity = analysis.metrics.speakingMetrics.clarity;
          speechRate = analysis.metrics.speakingMetrics.speechRate;
        }
      } else {
        confidence = _calculateSpeakingConfidence(analysis);
        clarity = analysis.metrics.speakingMetrics.clarity;
        speechRate = analysis.metrics.speakingMetrics.speechRate;
      }
      
      if (confidence >= 70) {
        insights.add('면접에서 자신감 있는 답변으로 좋은 인상을 남겼습니다.');
      } else {
        insights.add('면접 답변에서 좀 더 확신을 가지고 말하면 더 좋은 평가를 받을 수 있습니다.');
      }
      
      if (clarity >= 70) {
        insights.add('명확하고 체계적인 답변으로 의사소통 능력을 잘 보여주었습니다.');
      } else {
        insights.add('답변을 더 구조적으로 정리해서 전달하면 명확성을 높일 수 있습니다.');
      }
      
    } else {
      // 기본값으로 발표 인사이트 사용
      final confidence = _calculateSpeakingConfidence(analysis);
      final persuasion = _calculatePersuasionLevel(analysis);
      final speed = analysis.metrics.speakingMetrics.speechRate;
      
      if (confidence >= 70) {
        insights.add('발표 중 자신감이 높아 청중들의 주의를 잘 끌었습니다.');
      } else {
        insights.add('발표 중 자신감을 더 보여주면 더 설득력 있는 발표가 될 것입니다.');
      }
      
      if (persuasion >= 70) {
        insights.add('논리적이고 설득력 있는 내용 구성으로 메시지가 잘 전달되었습니다.');
      } else {
        insights.add('핵심 메시지를 더 명확하게 강조하면 설득력을 높일 수 있습니다.');
      }
      
      if (speed >= 120 && speed <= 150) {
        insights.add('적절한 말하기 속도로 청중이 이해하기 쉬웠을 것입니다.');
      } else if (speed > 150) {
        insights.add('말하기 속도가 빨라 중요한 내용을 놓칠 가능성이 있습니다.');
      } else {
        insights.add('말하기 속도를 조금 빠르게 하면 더 역동적인 발표가 될 것입니다.');
      }
    }
    
    return insights;
  }

  List<Map<String, String>> _generateSuggestions(AnalysisResult analysis) {
    List<Map<String, String>> suggestions = [];
    
    if (analysis.category == '발표') {
      // 발표 시나리오 제안 - 백엔드 계산값 우선 사용
      double confidence, persuasion;
      
      final rawApiData = analysis.rawApiData;
      if (rawApiData.isNotEmpty && rawApiData['keyMetrics'] != null) {
        final keyMetrics = rawApiData['keyMetrics'] as Map<String, dynamic>;
        final presentationMetrics = keyMetrics['presentation'] as Map<String, dynamic>?;
        
        if (presentationMetrics != null) {
          confidence = (presentationMetrics['confidence'] ?? 50).toDouble(); // 60→50 조정
          persuasion = (presentationMetrics['persuasion'] ?? 55).toDouble(); // 70→55 조정
          print('📊 제안: 백엔드 계산값 사용 - confidence=${confidence}, persuasion=${persuasion}');
        } else {
          confidence = _calculateSpeakingConfidence(analysis);
          persuasion = _calculatePersuasionLevel(analysis);
          print('📊 제안: 폴백 계산값 사용');
        }
      } else {
        confidence = _calculateSpeakingConfidence(analysis);
        persuasion = _calculatePersuasionLevel(analysis);
        print('📊 제안: 폴백 계산값 사용');
      }
      
      if (confidence < 60) {
        suggestions.add({
          'title': '자신감 있는 발표',
          'content': '더 확신 있는 어조로 말하고, 중요한 포인트에서는 목소리 톤을 강조해보세요. 충분한 준비와 연습이 자신감의 기초입니다.'
        });
      }
      
      if (persuasion < 60) {
        suggestions.add({
          'title': '설득력 향상',
          'content': '데이터와 구체적인 사례를 활용하여 논리적으로 설명하고, 핵심 메시지를 명확하게 전달해보세요.'
        });
      }
      
    } else if (analysis.category == '면접') {
      // 면접 시나리오 제안 - 백엔드 계산값 우선 사용
      double confidence, clarity;
      
      final rawApiData = analysis.rawApiData;
      if (rawApiData.isNotEmpty && rawApiData['keyMetrics'] != null) {
        final keyMetrics = rawApiData['keyMetrics'] as Map<String, dynamic>;
        final interviewMetrics = keyMetrics['interview'] as Map<String, dynamic>?;
        
        if (interviewMetrics != null) {
          confidence = (interviewMetrics['confidence'] ?? 50).toDouble(); // 60→50 조정
          clarity = (interviewMetrics['clarity'] ?? 55).toDouble(); // 60→55 조정
        } else {
          confidence = _calculateSpeakingConfidence(analysis);
          clarity = analysis.metrics.speakingMetrics.clarity;
        }
      } else {
        confidence = _calculateSpeakingConfidence(analysis);
        clarity = analysis.metrics.speakingMetrics.clarity;
      }
      
      if (confidence < 60) {
        suggestions.add({
          'title': '자신감 있는 답변',
          'content': '답변 시 "아마도", "일 것 같다" 보다는 확신있는 표현을 사용해보세요. 구체적인 경험을 들어 답변하면 더 좋습니다.'
        });
      }
      
      if (clarity < 60) {
        suggestions.add({
          'title': '구조적 답변',
          'content': '답변을 할 때는 "첫째, 둘째" 같은 구조를 활용하거나 STAR 기법(상황-과제-행동-결과)을 사용해보세요.'
        });
      }
      
    } else {
      // 기본값으로 발표 제안 사용
      final confidence = _calculateSpeakingConfidence(analysis);
      final persuasion = _calculatePersuasionLevel(analysis);
      
      if (confidence < 60) {
        suggestions.add({
          'title': '자신감 있는 발표',
          'content': '더 확신 있는 어조로 말하고, 중요한 포인트에서는 목소리 톤을 강조해보세요. 충분한 준비와 연습이 자신감의 기초입니다.'
        });
      }
      
      if (persuasion < 60) {
        suggestions.add({
          'title': '설득력 향상',
          'content': '데이터와 구체적인 사례를 활용하여 논리적으로 설명하고, 핵심 메시지를 명확하게 전달해보세요.'
        });
      }
    }
    
    // 일반적인 제안들도 추가
    if (suggestions.length < 3) {
      suggestions.add({
        'title': '효과적인 소통',
        'content': '상대방의 반응을 살피며 말하고, 중요한 내용은 반복해서 강조하는 것이 좋습니다.'
      });
    }
    
    if (suggestions.length < 3) {
      suggestions.add({
        'title': '지속적인 연습',
        'content': '꾸준한 발표 연습과 피드백을 통해 더 나은 커뮤니케이션 스킬을 기를 수 있습니다.'
      });
    }
    
    return suggestions;
  }

  Widget _buildInsightItem(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 15),
            decoration: ShapeDecoration(
              color: const Color(0xFF3F51B5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF424242),
                fontSize: 15,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                height: 1.50,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(AnalysisResult analysis) {
    final suggestions = _generateSuggestions(analysis);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '개선 제안',
            style: TextStyle(
              color: Color(0xFF212121),
              fontSize: 18,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 124,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: suggestions.asMap().entries.map((entry) {
                final suggestion = entry.value;
                return Row(
                  children: [
                    _buildSuggestionCard(suggestion['title']!, suggestion['content']!),
                    if (entry.key < suggestions.length - 1) const SizedBox(width: 15),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(String title, String content) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(19),
      decoration: ShapeDecoration(
        color: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 4, color: Color(0xFF3F51B5)),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 16,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                color: Color(0xFF616161),
                fontSize: 14,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                height: 1.50,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 72,
              decoration: ShapeDecoration(
                color: const Color(0xFF3F51B5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // 🔥 전체 보고서 보기 기능 구현 - DetailedReportScreen으로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailedReportScreen(
                          sessionId: widget.sessionId,
                        ),
                      ),
                    );
                  },
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '전체 보고서',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '보기',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Container(
              height: 72,
              decoration: ShapeDecoration(
                color: const Color(0xFFF5F5F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // 홈으로 이동
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/main',
                      (route) => false,
                      arguments: {'initialTabIndex': 0}, // 홈 탭으로 이동
                    );
                  },
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home, size: 20, color: Color(0xFF424242)),
                        SizedBox(width: 8),
                        Text(
                          '홈으로 이동',
                          style: TextStyle(
                            color: Color(0xFF424242),
                            fontSize: 16,
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSessionModeText(SessionMode mode) {
    switch (mode) {
      case SessionMode.interview:
        return '면접';
      case SessionMode.business:
        return '발표';
      case SessionMode.coaching:
        return '코칭';
      default:
        return '발표';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour > 12 ? "오후" : "오전"} ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getSessionIcon(SessionMode mode) {
    switch (mode) {
      case SessionMode.interview:
        return Icons.headset;
      case SessionMode.business:
        return Icons.business;
      case SessionMode.coaching:
        return Icons.school;
      default:
        return Icons.business;
    }
  }

  // 지표별 설명 생성 메서드들
  String _getConfidenceDescription(double confidence) {
    if (confidence >= 80) return '매우 자신감 있는 발표';
    if (confidence >= 60) return '안정적인 자신감';
    if (confidence >= 40) return '보통의 자신감';
    return '자신감 향상 필요';
  }

  String _getSpeedDescription(double speed) {
    if (speed >= 150) return '빠른 속도';
    if (speed >= 120) return '적절한 속도';
    if (speed >= 90) return '천천히 말함';
    return '매우 느린 속도';
  }

  String _getPersuasionDescription(double persuasion) {
    if (persuasion >= 80) return '매우 설득력 있음';
    if (persuasion >= 60) return '적절한 설득력';
    if (persuasion >= 40) return '보통의 설득력';
    return '설득력 향상 필요';
  }

  String _getClarityDescription(double clarity) {
    if (clarity >= 80) return '매우 명확한 발음';
    if (clarity >= 60) return '명확한 전달';
    if (clarity >= 40) return '보통의 명확성';
    return '명확성 향상 필요';
  }

  String _getStabilityDescription(double stability) {
    if (stability >= 80) return '매우 안정적';
    if (stability >= 60) return '안정적인 태도';
    if (stability >= 40) return '보통의 안정감';
    return '안정감 향상 필요';
  }

  String _getTonalityDescription(double tonality) {
    if (tonality >= 80) return '자연스러운 억양';
    if (tonality >= 60) return '적절한 톤';
    if (tonality >= 40) return '보통의 억양';
    return '톤 개선 필요';
  }

  String _getLikeabilityDescription(double likeability) {
    if (likeability >= 80) return '매우 우호적인 반응';
    if (likeability >= 60) return '긍정적인 인상';
    if (likeability >= 40) return '보통의 호감';
    return '호감도 향상 필요';
  }

  String _getListeningDescription(double listening) {
    if (listening >= 80) return '우수한 경청 능력';
    if (listening >= 60) return '적절한 경청';
    if (listening >= 40) return '보통의 경청';
    return '경청 능력 향상 필요';
  }

  double _calculatePersuasionLevel(AnalysisResult analysis) {
    // 🔥 발표에서 설득력 = 톤(억양) + 명확성 조합 (말하기 패턴 탭과 동일)
    final tonality = analysis.metrics.speakingMetrics.tonality;
    final clarity = analysis.metrics.speakingMetrics.clarity;
    
    // 🔧 값이 0-1 범위인지 0-100 범위인지 확인하여 정규화
    final normalizedTonality = tonality > 1 ? tonality : tonality * 100;
    final normalizedClarity = clarity > 1 ? clarity : clarity * 100;
    
    // 발표 설득력 = 톤(50%) + 명확성(50%)
    final persuasionScore = (normalizedTonality * 0.5 + normalizedClarity * 0.5);
    
    print('📊 분석결과 탭 설득력: 말하기 기반 계산 (${persuasionScore.toStringAsFixed(1)}%) - tonality=$normalizedTonality, clarity=$normalizedClarity');
    return persuasionScore;
  }

  // 안전한 메트릭 값 추출 헬퍼 함수
  double _getSafeMetricValue(double value, double defaultValue) {
    if (value.isNaN || value.isInfinite || value <= 0) {
      print('📊 메트릭 값 보정: ${value} → ${defaultValue} (기본값 적용)');
      return defaultValue;
    }
    return value;
  }

  double _calculateSpeakingConfidence(AnalysisResult analysis) {
    print('🔍 자신감 계산 시작...');
    print('🔍 rawApiData 존재: ${analysis.rawApiData.isNotEmpty}');
    print('🔍 emotionData 개수: ${analysis.emotionData.length}');
    print('🔍 metrics 데이터: tonality=${analysis.metrics.speakingMetrics.tonality}, clarity=${analysis.metrics.speakingMetrics.clarity}');
    
    // 1. 실제 API 데이터에서 confidence 추출 시도
    final rawApiData = analysis.rawApiData;
    if (rawApiData.isNotEmpty && rawApiData['detailedTimeline'] != null) {
      final detailedTimeline = rawApiData['detailedTimeline'] as List;
      if (detailedTimeline.isNotEmpty) {
        final confidenceValues = detailedTimeline
            .map((point) => ((point['confidence'] ?? 0.6) as num).toDouble())
            .where((conf) => conf > 0)
            .toList();
        
        if (confidenceValues.isNotEmpty) {
          final averageConfidence = confidenceValues.reduce((a, b) => a + b) / confidenceValues.length;
          final result = (averageConfidence * 100).clamp(20.0, 95.0);
          print('📊 자신감: timeline confidence 평균 (${result.toStringAsFixed(1)}%) - ${confidenceValues.length}개 포인트');
          return result;
        }
      }
    }
    
    // 2. emotionData의 평균값 사용
    if (analysis.emotionData.isNotEmpty) {
      final average = analysis.emotionData.map((e) => e.value).reduce((a, b) => a + b) / analysis.emotionData.length;
      print('📊 자신감: emotionData 평균 (${average.toStringAsFixed(1)}%) - ${analysis.emotionData.length}개 포인트');
      return average;
    }
    
    // 3. 말하기 메트릭을 기반으로 자신감 계산
    final tonality = analysis.metrics.speakingMetrics.tonality;
    final clarity = analysis.metrics.speakingMetrics.clarity;
    
    // 값이 0-1 범위인지 0-100 범위인지 확인하여 정규화
    final normalizedTonality = tonality > 1 ? tonality : tonality * 100;
    final normalizedClarity = clarity > 1 ? clarity : clarity * 100;
    
    if (normalizedTonality > 0 || normalizedClarity > 0) {
      // 톤과 명확성을 기반으로 자신감 계산
      final confidenceScore = (normalizedTonality * 0.6 + normalizedClarity * 0.4).clamp(20.0, 95.0);
      print('📊 자신감: 말하기 메트릭 기반 (${confidenceScore.toStringAsFixed(1)}%) - tonality=$normalizedTonality, clarity=$normalizedClarity');
      return confidenceScore;
    }
    
    // 4. 최종 백업: 기본값
    print('📊 자신감: 기본값 사용 (55.0%) - 모든 데이터 소스 실패');
    return 55.0; // 65.0→55.0 조정
  }
}

