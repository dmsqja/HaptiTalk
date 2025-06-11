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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '분석 결과',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<AnalysisResult?>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                '오류가 발생했습니다: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // 분석 탭 선택
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: '분석',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '기록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
        onTap: (index) {
          // 메인 탭 화면으로 돌아가고 해당 탭 선택
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/main',
            (route) => false,
            arguments: {'initialTabIndex': index},
          );
        },
      ),
    );
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
        SessionMode inferredMode = SessionMode.dating; // 기본값
        if (widget.sessionType != null) {
          switch (widget.sessionType!.toLowerCase()) {
            case 'presentation':
            case '발표':
              inferredMode = SessionMode.dating; // presentation이 없으면 기본값 사용
              break;
            case 'interview':
            case '면접':
              inferredMode = SessionMode.interview;
              break;
            case 'dating':
            case '소개팅':
            default:
              inferredMode = SessionMode.dating;
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
            : SessionMode.dating;

        // 실제 분석 결과에서 duration 가져오기
        final totalSeconds = analysis.metrics.totalDuration.toInt();
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        final sessionDuration = '${minutes}분 ${seconds}초';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getSessionIcon(sessionMode),
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sessionName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSessionModeText(sessionMode),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
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
                    Icon(
                      Icons.access_time,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '세션 시간: $sessionDuration',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, size: 18, color: AppColors.text),
                const SizedBox(width: 8),
                Text(
                  _getChartTitle(analysis.category),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 160,
              padding: const EdgeInsets.only(right: 16),
              child: _buildTimelineChart(analysis),
            ),
          ],
        ),
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
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (touchedSpot) => AppColors.primary.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final timePoint = barSpot.x.toInt();
                final value = barSpot.y;
                final timeInSeconds = timePoint * 30; // 30초 간격
                final minutes = timeInSeconds ~/ 60;
                final seconds = timeInSeconds % 60;
                final timeLabel = '${minutes}:${seconds.toString().padLeft(2, '0')}';
                
                return LineTooltipItem(
                  '$timeLabel\n${value.toStringAsFixed(1)}%',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 25,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final totalMinutes = (analysis.metrics.totalDuration / 60).ceil();
                final timeLabels = _generateTimeLabels(totalMinutes, values.length);
                
                if (value.toInt() < 0 || value.toInt() >= timeLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    timeLabels[value.toInt()],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        minX: 0,
        maxX: (values.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateTimeLabels(int totalMinutes, int dataPoints) {
    List<String> labels = [];
    
    // 🔥 실제 30초 간격으로 라벨 생성
    for (int i = 0; i < dataPoints; i++) {
      final timeInSeconds = i * 30; // 정확히 30초 간격
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
    // 소개팅 시나리오: 호감도 기반
    final likeability = analysis.metrics.emotionMetrics.averageLikeability;
    
    // 소개팅은 점진적으로 상승하는 패턴
    return [
      likeability * 0.8,   // 시작
      likeability * 0.9,   // 25%
      likeability * 1.0,   // 50%
      likeability * 1.1,   // 75%
      likeability * 1.05,  // 완료
    ];
  }

  Widget _buildMetricsSection(AnalysisResult analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주요 지표',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          children: _buildMetricCards(analysis),
        ),
      ],
    );
  }

  List<Widget> _buildMetricCards(AnalysisResult analysis) {
    // 시나리오별 지표 설정
    if (analysis.category == '발표') {
      return [
        _buildMetricCard(
          '자신감',
          '${_calculateSpeakingConfidence(analysis).round()}%',
          Icons.psychology,
          _getConfidenceDescription(_calculateSpeakingConfidence(analysis)),
        ),
        _buildMetricCard(
          '말하기 속도',
          '${analysis.metrics.speakingMetrics.speechRate.toInt()}WPM',
          Icons.speed,
          _getSpeedDescription(analysis.metrics.speakingMetrics.speechRate),
        ),
        _buildMetricCard(
          '설득력',
          '${_calculatePersuasionLevel(analysis).round()}%',
          Icons.trending_up,
          _getPersuasionDescription(_calculatePersuasionLevel(analysis)),
        ),
        _buildMetricCard(
          '명확성',
          '${analysis.metrics.speakingMetrics.clarity.toInt()}%',
          Icons.radio_button_checked,
          _getClarityDescription(analysis.metrics.speakingMetrics.clarity),
        ),
      ];
    } else if (analysis.category == '면접') {
      return [
        _buildMetricCard(
          '자신감',
          '${_calculateSpeakingConfidence(analysis).round()}%',
          Icons.psychology,
          _getConfidenceDescription(_calculateSpeakingConfidence(analysis)),
        ),
        _buildMetricCard(
          '말하기 속도',
          '${analysis.metrics.speakingMetrics.speechRate.toInt()}WPM',
          Icons.speed,
          _getSpeedDescription(analysis.metrics.speakingMetrics.speechRate),
        ),
        _buildMetricCard(
          '명확성',
          '${analysis.metrics.speakingMetrics.clarity.toInt()}%',
          Icons.radio_button_checked,
          _getClarityDescription(analysis.metrics.speakingMetrics.clarity),
        ),
        _buildMetricCard(
          '안정감',
          '${analysis.metrics.speakingMetrics.tonality.toInt()}%',
          Icons.sentiment_satisfied_alt,
          _getStabilityDescription(analysis.metrics.speakingMetrics.tonality),
        ),
      ];
    } else {
      // 소개팅 시나리오는 감정적 호감도 사용 (적절함)
      return [
        _buildMetricCard(
          '호감도',
          '${analysis.metrics.emotionMetrics.averageLikeability.toInt()}%',
          Icons.psychology,
          _getConfidenceDescription(analysis.metrics.emotionMetrics.averageLikeability),
        ),
        _buildMetricCard(
          '말하기 속도',
          '${analysis.metrics.speakingMetrics.speechRate.toInt()}WPM',
          Icons.speed,
          _getSpeedDescription(analysis.metrics.speakingMetrics.speechRate),
        ),
        _buildMetricCard(
          '명확성',
          '${analysis.metrics.speakingMetrics.clarity.toInt()}%',
          Icons.radio_button_checked,
          _getClarityDescription(analysis.metrics.speakingMetrics.clarity),
        ),
        _buildMetricCard(
          '안정감',
          '${analysis.metrics.speakingMetrics.tonality.toInt()}%',
          Icons.sentiment_satisfied_alt,
          _getStabilityDescription(analysis.metrics.speakingMetrics.tonality),
        ),
      ];
    }
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, String description) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Icon(icon, size: 16, color: Colors.grey[700]),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const Spacer(),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakingRatioSection(AnalysisResult analysis) {
    final contributionRatio = analysis.metrics.conversationMetrics.contributionRatio;
    final myRatio = contributionRatio.toInt();
    final otherRatio = (100 - contributionRatio).toInt();
    
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '$myRatio%',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '나',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$myRatio%',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '상대방',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$otherRatio%',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection(AnalysisResult analysis) {
    final insights = _generateInsights(analysis);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '핵심 인사이트',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...insights.asMap().entries.map((entry) => 
          _buildInsightItem(entry.key + 1, entry.value)
        ).toList(),
      ],
    );
  }

  List<String> _generateInsights(AnalysisResult analysis) {
    List<String> insights = [];
    
    if (analysis.category == '발표') {
      // 발표 시나리오 인사이트 - 말하기 자신감 사용
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
      
    } else if (analysis.category == '면접') {
      // 면접 시나리오 인사이트 - 말하기 자신감 사용
      final confidence = _calculateSpeakingConfidence(analysis);
      final clarity = analysis.metrics.speakingMetrics.clarity;
      final stability = analysis.metrics.speakingMetrics.tonality;
      
      if (confidence >= 70) {
        insights.add('면접관에게 자신감 있는 모습을 잘 보여주었습니다.');
      } else {
        insights.add('답변 시 더 확신을 가지고 말하면 좋은 인상을 줄 수 있습니다.');
      }
      
      if (clarity >= 70) {
        insights.add('질문에 대한 답변이 명확하고 체계적이었습니다.');
      } else {
        insights.add('답변을 더 구체적이고 명확하게 하면 더 좋을 것 같습니다.');
      }
      
      if (stability >= 70) {
        insights.add('안정적인 태도로 면접에 임했습니다.');
      } else {
        insights.add('긴장을 줄이고 더 자연스럽게 대화하는 연습이 필요합니다.');
      }
      
    } else {
      // 소개팅 시나리오 인사이트 - 감정적 호감도 사용 (적절함)
      final likeability = analysis.metrics.emotionMetrics.averageLikeability;
      final interest = analysis.metrics.emotionMetrics.averageInterest;
      final listening = analysis.metrics.conversationMetrics.listeningScore;
      
      if (likeability >= 70) {
        insights.add('상대방에게 긍정적인 인상을 주는 대화를 나눴습니다.');
      } else {
        insights.add('더 친근하고 편안한 분위기로 대화하면 좋을 것 같습니다.');
      }
      
      if (interest >= 70) {
        insights.add('흥미로운 주제들로 활발한 대화를 이어갔습니다.');
      } else {
        insights.add('공통 관심사를 찾아 더 깊이 있는 대화를 나누어보세요.');
      }
      
      if (listening >= 70) {
        insights.add('상대방의 말을 잘 들어주는 좋은 경청자였습니다.');
      } else {
        insights.add('상대방의 이야기에 더 관심을 보이고 반응해주세요.');
      }
    }
    
    return insights;
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
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(AnalysisResult analysis) {
    final suggestions = _generateSuggestions(analysis);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '개선 제안',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions.asMap().entries.map((entry) {
              final suggestion = entry.value;
              return Row(
                children: [
                  _buildSuggestionCard(suggestion['title']!, suggestion['content']!),
                  if (entry.key < suggestions.length - 1) const SizedBox(width: 12),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _generateSuggestions(AnalysisResult analysis) {
    List<Map<String, String>> suggestions = [];
    
    if (analysis.category == '발표') {
      // 발표 시나리오 제안 - 말하기 자신감 사용
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
      
    } else if (analysis.category == '면접') {
      // 면접 시나리오 제안 - 말하기 자신감 사용
      final confidence = _calculateSpeakingConfidence(analysis);
      final clarity = analysis.metrics.speakingMetrics.clarity;
      
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
      // 소개팅 시나리오 제안 - 감정적 호감도 사용 (적절함)
      final likeability = analysis.metrics.emotionMetrics.averageLikeability;
      final listening = analysis.metrics.conversationMetrics.listeningScore;
      
      if (likeability < 60) {
        suggestions.add({
          'title': '공감 표현 늘리기',
          'content': '"정말요?", "그렇군요", "재밌네요" 같은 공감 표현을 더 자주 사용하면 상대방이 더 편안하게 대화할 수 있습니다.'
        });
      }
      
      if (listening < 60) {
        suggestions.add({
          'title': '적극적 경청',
          'content': '상대방의 말이 끝날 때까지 기다린 후 관련된 질문을 이어가면 더 깊이 있는 대화를 나눌 수 있습니다.'
        });
      }
    }
    
    // 기본 제안 (모든 시나리오 공통)
    if (suggestions.isEmpty) {
      suggestions.add({
        'title': '자연스러운 대화',
        'content': '현재 수준을 잘 유지하면서 더 자연스럽고 편안한 대화를 이어가세요.'
      });
    }
    
    return suggestions;
  }

  Widget _buildSuggestionCard(String title, String content) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '상세 분석',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '보기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // 홈으로 이동
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/main',
                (route) => false,
                arguments: {'initialTabIndex': 0},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home,
                  size: 20,
                  color: Colors.grey[800],
                ),
                const SizedBox(width: 8),
                Text(
                  '홈으로',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getSessionModeText(SessionMode mode) {
    switch (mode) {
      case SessionMode.dating:
        return '소개팅';
      case SessionMode.interview:
        return '면접';
      case SessionMode.business:
        return '비즈니스';
      case SessionMode.coaching:
        return '코칭';
      default:
        return '기타';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour > 12 ? "오후" : "오전"} ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getSessionIcon(SessionMode mode) {
    switch (mode) {
      case SessionMode.dating:
        return Icons.favorite;
      case SessionMode.interview:
        return Icons.headset;
      case SessionMode.business:
        return Icons.business;
      case SessionMode.coaching:
        return Icons.school;
      default:
        return Icons.help;
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

  double _calculateSpeakingConfidence(AnalysisResult analysis) {
    // 🔥 발표/면접에서 자신감 = 실제 timeline의 confidence 평균 (말하기 기반)
    
    // 실제 API 데이터에서 confidence 추출 시도
    final rawApiData = analysis.rawApiData;
    if (rawApiData != null && rawApiData['detailedTimeline'] != null) {
      final detailedTimeline = rawApiData['detailedTimeline'] as List;
      if (detailedTimeline.isNotEmpty) {
        final confidenceValues = detailedTimeline
            .map((point) => (point['confidence'] ?? 0.6) as double)
            .where((conf) => conf > 0)
            .toList();
        
        if (confidenceValues.isNotEmpty) {
          final averageConfidence = confidenceValues.reduce((a, b) => a + b) / confidenceValues.length;
          final result = (averageConfidence * 100).clamp(20.0, 95.0);
          print('📊 분석결과 탭 말하기 자신감: timeline confidence 평균 (${result.toStringAsFixed(1)}%) - ${confidenceValues.length}개 포인트');
          return result;
        }
      }
    }
    
    // 백업: emotionData의 평균값 사용
    if (analysis.emotionData.isNotEmpty) {
      final average = analysis.emotionData.map((e) => e.value).reduce((a, b) => a + b) / analysis.emotionData.length;
      print('📊 분석결과 탭 말하기 자신감: emotionData 평균 (${average.toStringAsFixed(1)}%) - ${analysis.emotionData.length}개 포인트');
      return average;
    }
    
    // 최종 백업: 기본값
    print('📊 분석결과 탭 말하기 자신감: 기본값 사용 (60.0%)');
    return 60.0;
  }
}

