import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/analysis/analysis_result.dart';
import '../../models/analysis/emotion_data.dart';
import '../../models/analysis/metrics.dart';
import '../../constants/colors.dart';

class SessionDetailTabEmotion extends StatelessWidget {
  final AnalysisResult analysisResult;

  const SessionDetailTabEmotion({
    Key? key,
    required this.analysisResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final emotionMetrics = analysisResult.metrics.emotionMetrics;
    final screenWidth = MediaQuery.of(context).size.width;

    return ListView(
      padding: EdgeInsets.all(0),
      children: [
        // 평균 지표 섹션
        Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '평균 ${_getPrimaryMetricName()}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 주요 지표 게이지 카드
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 지표 게이지
                    SizedBox(
                      height: 180,
                      child: Center(
                        child: _buildEmotionGauge(context, emotionMetrics),
                      ),
                    ),
                    SizedBox(height: 10),

                    // 설명 텍스트
                    Text(
                      _generatePerformanceDescription(emotionMetrics.averageLikeability),
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF616161),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 감정 지표 섹션
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getSessionTypeName()} 지표',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 감정 지표 카드들 (2x2 그리드)
              Row(
                children: [
                  // 왼쪽 열
                  Expanded(
                    child: Column(
                      children: [
                        // 최고 지표 카드
                        _buildMetricCard(
                          title: '최고 ${_getPrimaryMetricName()}',
                          value: '${emotionMetrics.peakLikeability.toInt()}%',
                          description: _getPeakDescription(),
                          icon: _getPositiveIcon(),
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 15),
                        // 관심도 카드
                        _buildMetricCard(
                          title: '평균 ${_getSecondaryMetricName()}',
                          value: '${emotionMetrics.averageInterest.toInt()}%',
                          description: _getSecondaryDescription(),
                          icon: _getSecondaryIcon(),
                          color: Color(0xFF7986CB),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 15),
                  // 오른쪽 열
                  Expanded(
                    child: Column(
                      children: [
                        // 최저 지표 카드
                        _buildMetricCard(
                          title: '최저 ${_getPrimaryMetricName()}',
                          value: '${emotionMetrics.lowestLikeability.toInt()}%',
                          description: _getLowestDescription(),
                          icon: _getNegativeIcon(),
                          color: Color(0xFFE57373),
                        ),
                        SizedBox(height: 15),
                        // 특수 지표 카드
                        _buildMetricCard(
                          title: _getSpecialMetricName(),
                          value: '${_getSpecialMetricValue().toInt()}%',
                          description: _getSpecialMetricDescription(),
                          icon: _getSpecialIcon(),
                          color: Color(0xFF4DB6AC),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 주요 감정 변화 포인트 섹션
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '주요 ${_getPrimaryMetricName()} 변화 포인트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 감정 변화 카드
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 카드 타이틀
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 20,
                          color: Color(0xFF212121),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${_getPrimaryMetricName()} 변화',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),

                    // 감정 변화 항목들 (실제 데이터 기반)
                    ..._buildEmotionChangeItems(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 성과 하이라이트 섹션
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '성과 하이라이트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 하이라이트 카드
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 20,
                          color: Colors.green[600],
              ),
                        SizedBox(width: 8),
                        Text(
                          '주요 성취',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
              ),
                    SizedBox(height: 10),
                    Text(
                      _generateHighlightText(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 세션 타입 키 정규화
  String _getSessionTypeKey() {
    final category = analysisResult.category.toLowerCase();
    if (category.contains('발표') || category == 'presentation') return 'presentation';
    if (category.contains('면접') || category == 'interview') return 'interview';
    if (category.contains('소개팅') || category == 'dating') return 'dating';
    return 'presentation'; // 기본값
  }

  // 세션 타입 표시명
  String _getSessionTypeName() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '발표';
      case 'interview':
        return '면접';
      case 'dating':
        return '소개팅';
      default:
        return '세션';
    }
  }

  // 세션 타입별 주요 지표명
  String _getPrimaryMetricName() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '청중 관심도';
      case 'interview':
        return '면접관 평가';
      case 'dating':
        return '호감도';
      default:
        return '성과 지표';
    }
  }

  // 세션 타입별 보조 지표명
  String _getSecondaryMetricName() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '집중도';
      case 'interview':
        return '자신감';
      case 'dating':
        return '관심도';
      default:
        return '보조 지표';
    }
  }

  // 특수 지표명
  String _getSpecialMetricName() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '설득력';
      case 'interview':
        return '안정감';
      case 'dating':
        return '경청 지수';
      default:
        return '특수 지표';
    }
  }

  // 특수 지표값
  double _getSpecialMetricValue() {
    // 🔥 백엔드에서 이미 계산된 값 우선 사용
    final rawApiData = analysisResult.rawApiData;
    final sessionTypeKey = _getSessionTypeKey();
    
    if (rawApiData.isNotEmpty && rawApiData['keyMetrics'] != null) {
      final keyMetrics = rawApiData['keyMetrics'] as Map<String, dynamic>;
      
      switch (sessionTypeKey) {
        case 'presentation':
          final presentationMetrics = keyMetrics['presentation'] as Map<String, dynamic>?;
          if (presentationMetrics != null && presentationMetrics['persuasion'] != null) {
            final persuasion = (presentationMetrics['persuasion'] as num).toDouble();
            print('📊 감정 탭 설득력: 백엔드 계산값 사용 ($persuasion%) - keyMetrics.presentation.persuasion');
            return persuasion;
          } else {
            print('📊 감정 탭 설득력: 폴백 계산값 사용');
            return analysisResult.metrics.speakingMetrics.clarity;
          }
        case 'interview':
          final interviewMetrics = keyMetrics['interview'] as Map<String, dynamic>?;
          if (interviewMetrics != null && interviewMetrics['stability'] != null) {
            final stability = (interviewMetrics['stability'] as num).toDouble();
            print('📊 감정 탭 안정감: 백엔드 계산값 사용 ($stability%) - keyMetrics.interview.stability');
            return stability;
          } else {
            print('📊 감정 탭 안정감: 폴백 계산값 사용');
            return analysisResult.metrics.speakingMetrics.tonality;
          }
        case 'dating':
          // 소개팅은 경청 지수로 유지 (백엔드에 별도 지표 없음)
          return analysisResult.metrics.conversationMetrics.listeningScore;
        default:
          return 70.0;
      }
    } else {
      // 폴백 로직
      switch (sessionTypeKey) {
        case 'presentation':
          return analysisResult.metrics.speakingMetrics.clarity;
        case 'interview':
          return analysisResult.metrics.speakingMetrics.tonality;
        case 'dating':
          return analysisResult.metrics.conversationMetrics.listeningScore;
        default:
          return 70.0;
      }
    }
  }

  // 아이콘들
  IconData _getPositiveIcon() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return Icons.thumb_up;
      case 'interview':
        return Icons.star;
      case 'dating':
        return Icons.favorite;
      default:
        return Icons.thumb_up;
    }
  }

  IconData _getSecondaryIcon() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return Icons.visibility;
      case 'interview':
        return Icons.psychology;
      case 'dating':
        return Icons.remove_red_eye;
      default:
        return Icons.visibility;
    }
  }

  IconData _getNegativeIcon() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return Icons.thumb_down;
      case 'interview':
        return Icons.warning;
      case 'dating':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.thumb_down;
    }
  }

  IconData _getSpecialIcon() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return Icons.campaign;
      case 'interview':
        return Icons.self_improvement;
      case 'dating':
        return Icons.hearing;
      default:
        return Icons.analytics;
    }
  }

  // 설명 텍스트들
  String _generatePerformanceDescription(double score) {
    final sessionType = _getSessionTypeKey();
    String level = score >= 70 ? '아주 좋은' : score >= 50 ? '긍정적인' : '보통의';
    
    switch (sessionType) {
      case 'presentation':
        return '$level 청중 반응을 이끌어냈습니다';
      case 'interview':
        return '$level 면접 성과를 보였습니다';
      case 'dating':
        return '$level 호감도를 형성했습니다';
      default:
        return '$level 성과를 달성했습니다';
    }
  }

  String _getPeakDescription() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '가장 몰입도 높은 순간';
      case 'interview':
        return '가장 인상적인 답변';
      case 'dating':
        return '가장 호감 높은 순간';
      default:
        return '최고 성과 순간';
    }
  }

  String _getSecondaryDescription() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '전체 집중도 수준';
      case 'interview':
        return '답변 자신감 수준';
      case 'dating':
        return '전체 상호작용 수준';
      default:
        return '보조 지표 수준';
    }
  }

  String _getLowestDescription() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '개선 필요 구간';
      case 'interview':
        return '재검토 필요 답변';
      case 'dating':
        return '주의 필요 순간';
      default:
        return '개선 필요 부분';
    }
  }

  String _getSpecialMetricDescription() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '메시지 설득력';
      case 'interview':
        return '답변 안정성';
      case 'dating':
        return '상대방 이야기 경청';
      default:
        return '특수 분석 결과';
    }
  }

  // 감정 변화 항목들 생성
  List<Widget> _buildEmotionChangeItems() {
    final items = <Widget>[];
    final emotionData = analysisResult.emotionData;
    
    if (emotionData.isEmpty) {
      items.add(_buildEmotionChangeItem(
        '세션 전체',
        '안정적인 수준 유지',
        '전반적으로 일정한 수준을 유지하며 진행되었습니다.',
        true,
      ));
      return items;
    }

    // 최고점과 최저점 찾기
    double maxValue = emotionData.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    double minValue = emotionData.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    
    int maxIndex = emotionData.indexWhere((e) => e.value == maxValue);
    int minIndex = emotionData.indexWhere((e) => e.value == minValue);

    // 상승 구간
    if (maxIndex > 0) {
      items.add(_buildEmotionChangeItem(
        _formatTimeFromIndex(maxIndex, emotionData.length),
        '${_getPrimaryMetricName()} 상승',
        _getPositiveChangeText(),
        true,
      ));
      items.add(SizedBox(height: 15));
    }

    // 최고점
    items.add(_buildEmotionChangeItem(
      _formatTimeFromIndex(maxIndex, emotionData.length),
      '${_getPrimaryMetricName()} 최고점',
      _getPeakChangeText(maxValue),
      true,
    ));

    // 최저점 (너무 낮지 않은 경우만)
    if (minValue < 60 && minIndex != maxIndex) {
      items.add(SizedBox(height: 15));
      items.add(_buildEmotionChangeItem(
        _formatTimeFromIndex(minIndex, emotionData.length),
        '주의 필요 구간',
        _getNegativeChangeText(),
        false,
      ));
    }

    return items;
  }

  String _formatTimeFromIndex(int index, int totalPoints) {
    final totalSeconds = analysisResult.metrics.totalDuration;
    final segmentSeconds = totalSeconds / totalPoints;
    final currentSeconds = (index * segmentSeconds).round();
    
    final minutes = currentSeconds ~/ 60;
    final seconds = currentSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getPositiveChangeText() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '효과적인 메시지 전달로 청중의 관심이 크게 증가했습니다.';
      case 'interview':
        return '체계적인 답변과 자신감 있는 태도로 좋은 평가를 받았습니다.';
      case 'dating':
        return '자연스러운 대화와 공감으로 호감도가 상승했습니다.';
      default:
        return '좋은 성과로 지표가 상승했습니다.';
    }
  }

  String _getPeakChangeText(double value) {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '청중의 관심과 집중도가 최고조에 달했습니다. 핵심 메시지가 효과적으로 전달되었습니다.';
      case 'interview':
        return '면접관의 평가가 가장 높았던 순간입니다. 전문성과 역량을 잘 어필했습니다.';
      case 'dating':
        return '상대방의 호감도가 최고점에 도달했습니다. 진정성 있는 소통이 효과적이었습니다.';
      default:
        return '가장 좋은 성과를 달성한 순간입니다.';
    }
  }

  String _getNegativeChangeText() {
    switch (_getSessionTypeKey()) {
      case 'presentation':
        return '청중의 집중도가 다소 떨어진 구간입니다. 내용 전달 방식을 조정하면 좋겠습니다.';
      case 'interview':
        return '답변에 확신이 부족해 보인 구간입니다. 구체적 사례 제시가 도움이 될 것 같습니다.';
      case 'dating':
        return '대화 흐름이 다소 어색했던 순간입니다. 상대방의 관심사에 더 집중해보세요.';
      default:
        return '개선이 필요한 구간입니다.';
    }
  }

  // 하이라이트 텍스트 생성
  String _generateHighlightText() {
    final emotionMetrics = analysisResult.metrics.emotionMetrics;
    final sessionType = _getSessionTypeKey();
    final avgScore = (emotionMetrics.averageLikeability + emotionMetrics.averageInterest) / 2;
    
    switch (sessionType) {
      case 'presentation':
        return '전체 발표에서 청중의 평균 관심도가 ${avgScore.toInt()}%로 우수한 수준이었습니다. '
               '특히 핵심 메시지 전달 시점에서 집중도가 크게 향상되었으며, '
               '말하기 속도와 톤이 적절해 효과적인 소통이 이루어졌습니다.';
               
      case 'interview':
        return '면접 전체에서 평균 ${avgScore.toInt()}%의 좋은 평가를 받았습니다. '
               '답변의 체계성과 자신감 있는 태도가 돋보였으며, '
               '전문 지식과 경험을 효과적으로 어필할 수 있었습니다.';
               
      case 'dating':
        return '대화 전체에서 평균 호감도가 ${avgScore.toInt()}%로 긍정적이었습니다. '
               '자연스러운 소통과 적절한 경청 자세로 상대방과의 좋은 관계를 형성했으며, '
               '진정성 있는 대화가 특히 효과적이었습니다.';
               
      default:
        return '전체 세션에서 평균 ${avgScore.toInt()}%의 좋은 성과를 달성했습니다.';
    }
  }

  // 감정 게이지 위젯
  Widget _buildEmotionGauge(BuildContext context, EmotionMetrics emotionMetrics) {
    return Stack(
        alignment: Alignment.center,
        children: [
        // 배경 원
        SizedBox(
          width: 140,
          height: 140,
          child: CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 12,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[300]!),
          ),
        ),
        // 실제 값 원
        SizedBox(
          width: 140,
          height: 140,
          child: CircularProgressIndicator(
            value: emotionMetrics.averageLikeability / 100,
            strokeWidth: 12,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              emotionMetrics.averageLikeability >= 70 
                ? Colors.green 
                : emotionMetrics.averageLikeability >= 50 
                  ? AppColors.primary 
                  : Colors.orange
            ),
            ),
          ),
        // 중앙 텍스트
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
              '${emotionMetrics.averageLikeability.toInt()}%',
                style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
                ),
              ),
              Text(
              _getPrimaryMetricName(),
                style: TextStyle(
                fontSize: 12,
                color: Color(0xFF616161),
                ),
              ),
            ],
          ),
        ],
    );
  }

  // 메트릭 카드 위젯
  Widget _buildMetricCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: color,
              ),
              Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212121),
            ),
          ),
          SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }

  // 감정 변화 아이템 위젯
  Widget _buildEmotionChangeItem(
    String time,
    String title,
    String description,
    bool isPositive,
  ) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 20,
                color: isPositive ? Colors.green[600] : Colors.orange[600],
              ),
              SizedBox(width: 8),
              Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? Colors.green[600] : Colors.orange[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }
}
