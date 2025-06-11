import 'package:flutter/material.dart';
import '../../models/analysis/analysis_result.dart';
import '../../models/analysis/metrics.dart';
import '../../constants/colors.dart';
import 'dart:math' as math;

class SessionDetailTabTopics extends StatelessWidget {
  final AnalysisResult analysisResult;

  const SessionDetailTabTopics({
    Key? key,
    required this.analysisResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final topicMetrics = analysisResult.metrics.topicMetrics;

    return ListView(
      padding: EdgeInsets.all(0),
      children: [
        // 🔥 주요 대화 주제 섹션 (이미지 스타일)
        Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '주요 대화 주제',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 주제 태그들 (이미지와 동일한 스타일)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topicMetrics.topics.isNotEmpty) ...[
                      // 주제 태그들 (상위 10개)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _buildTopicTags(),
                      ),
                    ] else ...[
                      // 기본 주제들 (시뮬레이션)
              Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _buildDefaultTopicTags(),
                      ),
                ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // 🔥 대화 주제 분포 섹션 (파이차트 스타일)
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '대화 주제 분포',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 파이차트 컨테이너
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.donut_large,
                          size: 20,
                          color: Color(0xFF212121),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '주제별 대화 비중',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // 파이차트 및 범례
                    Row(
                      children: [
                        // 파이차트 영역
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 150,
                            child: CustomPaint(
                              size: Size(150, 150),
                              painter: TopicPieChartPainter(_getTopicDistribution()),
                            ),
                      ),
                    ),
                    SizedBox(width: 20),
                        // 범례 영역
                    Expanded(
                          flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildTopicLegends(),
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

        // 🔥 대화 주제 흐름 섹션 (시간대별)
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '대화 주제 흐름',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 시간대별 주제 흐름
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 20,
                          color: Color(0xFF212121),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '주제 타임라인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),

                    // 시간대별 주제 분석 내용
                    ..._buildTopicTimelineItems(),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 핵심 대화 포인트 섹션
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
              Text(
                '핵심 대화 포인트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
                              ),
                              SizedBox(height: 15),

              // 핵심 포인트 카드들 (실제 데이터 기반)
              ..._buildKeyPointCards(),
            ],
          ),
        ),

        // 대화 전개 패턴 섹션
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '대화 전개 패턴',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
                              ),
                              SizedBox(height: 15),

              // 대화 흐름 분석 카드
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timeline,
                          size: 20,
                          color: Color(0xFF212121),
                              ),
                        SizedBox(width: 8),
                        Text(
                          '${_getSessionTypeName()} 흐름 분석',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),

                    // 대화 흐름 분석 내용 (세션별 맞춤)
                    Text(
                      _getConversationFlowAnalysis(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF616161),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 주제별 인사이트 섹션
        if (topicMetrics.insights.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '주제별 인사이트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

                // 인사이트 카드들 (실제 데이터 기반)
                ...topicMetrics.insights.take(3).map((insight) => Column(
                  children: [
                    _buildInsightCard(insight),
              SizedBox(height: 15),
                  ],
                )).toList(),
            ],
          ),
        ),

        // 추천 주제 섹션
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getSessionTypeName()} 추천 주제',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 15),

              // 추천 주제 카드
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 20,
                          color: Colors.blue[600],
                        ),
                        SizedBox(width: 8),
                        Text(
                          '다음에 시도해볼 주제',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
              ),
              SizedBox(height: 15),

                    // 추천 주제 목록 (세션별 맞춤)
                    ..._buildRecommendedTopics(),
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

  // 🔥 주제 태그들 생성 (실제 데이터 기반)
  List<Widget> _buildTopicTags() {
    final topics = analysisResult.metrics.topicMetrics.topics;
    return topics.take(10).map((topic) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: topic.isPrimary ? AppColors.primary.withOpacity(0.2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: topic.isPrimary ? AppColors.primary : Colors.grey[400]!,
            width: 1,
          ),
      ),
      child: Text(
          topic.name,
        style: TextStyle(
            fontSize: 14,
            fontWeight: topic.isPrimary ? FontWeight.w600 : FontWeight.w500,
            color: topic.isPrimary ? AppColors.primary : Colors.grey[700],
          ),
        ),
      );
    }).toList();
  }

  // 🔥 기본 주제 태그들 (데이터 없을 때)
  List<Widget> _buildDefaultTopicTags() {
    final sessionType = _getSessionTypeKey();
    List<String> defaultTopics;
    
    switch (sessionType) {
      case 'presentation':
        defaultTopics = ['비즈니스', '전략', '기술', '혁신', '성과', '미래', '계획', '분석'];
        break;
      case 'interview':
        defaultTopics = ['경험', '프로젝트', '기술', '팀워크', '성과', '목표', '역량', '비전'];
        break;
      case 'dating':
        defaultTopics = ['여행', '사진', '음식', '영화', '음악', '취미', '카페', '운동', '책', '일상'];
        break;
      default:
        defaultTopics = ['일상', '취미', '관심사', '경험', '계획', '목표'];
    }
    
    return defaultTopics.map((topic) {
      final isPrimary = defaultTopics.indexOf(topic) < 3;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary.withOpacity(0.2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? AppColors.primary : Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: Text(
          topic,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
            color: isPrimary ? AppColors.primary : Colors.grey[700],
        ),
      ),
    );
    }).toList();
  }

  // 🔥 주제 분포 데이터 생성
  List<TopicDistribution> _getTopicDistribution() {
    final topics = analysisResult.metrics.topicMetrics.topics;
    
    if (topics.isEmpty) {
      // 기본 분포 (이미지와 유사)
      return [
        TopicDistribution('여행 & 사진', 35, Color(0xFF6200EA)),
        TopicDistribution('음식 & 카페', 20, Color(0xFF03DAC6)),
        TopicDistribution('영화 & 음악', 20, Color(0xFFFF6200)),
        TopicDistribution('기타 주제', 25, Color(0xFF757575)),
      ];
    }
    
    // 실제 데이터 기반 분포
    final colors = [
      Color(0xFF6200EA), Color(0xFF03DAC6), Color(0xFFFF6200), 
      Color(0xFF757575), Color(0xFF4CAF50), Color(0xFFFF5722),
    ];
    
    final distributions = <TopicDistribution>[];
    double totalPercentage = 0;
    
    for (int i = 0; i < topics.length && i < 6; i++) {
      final topic = topics[i];
      final percentage = topic.percentage.clamp(5.0, 40.0);
      totalPercentage += percentage;
      
      distributions.add(TopicDistribution(
        topic.name,
        percentage,
        colors[i % colors.length],
      ));
    }
    
    // 100%에 맞춤
    if (totalPercentage < 100 && distributions.isNotEmpty) {
      final remaining = 100 - totalPercentage;
      if (remaining > 5) {
        distributions.add(TopicDistribution(
          '기타 주제',
          remaining,
          Color(0xFF9E9E9E),
        ));
      }
    }
    
    return distributions;
  }

  // 🔥 파이차트 범례 생성
  List<Widget> _buildTopicLegends() {
    final distributions = _getTopicDistribution();
    
    return distributions.map((dist) {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
                color: dist.color,
                shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
            Expanded(
              child: Text(
                '${dist.name} (${dist.percentage.toInt()}%)',
          style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF616161),
                ),
          ),
        ),
      ],
        ),
    );
    }).toList();
  }

  // 🔥 주제 타임라인 아이템들 생성
  List<Widget> _buildTopicTimelineItems() {
    final duration = analysisResult.metrics.totalDuration;
    final sessionType = _getSessionTypeKey();
    
    // 🔥 실제 API conversation_topics 데이터 사용
    final conversationTopics = analysisResult.rawApiData['conversation_topics'] as List<dynamic>? ?? [];
    final timelineItems = <Widget>[];
    
    if (conversationTopics.isNotEmpty) {
      print('✅ 실제 주제 타임라인 데이터 사용: ${conversationTopics.length}개 주제');
      
      // 실제 주제 데이터를 시간순으로 정렬 (duration 기준)
      final sortedTopics = List<Map<String, dynamic>>.from(conversationTopics);
      sortedTopics.sort((a, b) {
        final durationA = (a['duration'] ?? 0) as num;
        final durationB = (b['duration'] ?? 0) as num;
        return durationB.compareTo(durationA); // 긴 시간부터
      });
      
      double cumulativeTime = 0;
      for (int i = 0; i < sortedTopics.length; i++) {
        final topic = sortedTopics[i];
        final topicName = topic['topic'] ?? '알 수 없는 주제';
        final topicDuration = (topic['duration'] ?? 30).toDouble();
        final topicPercentage = (topic['percentage'] ?? 0).toDouble();
        final keywords = List<String>.from(topic['keywords'] ?? []);
        
        final startMinute = (cumulativeTime / 60).round();
        final endMinute = ((cumulativeTime + topicDuration) / 60).round();
        
        String timeLabel;
        if (i == 0) {
          timeLabel = '시작 (${startMinute}분)';
        } else if (i == sortedTopics.length - 1) {
          timeLabel = '마무리 (${endMinute}분)';
        } else {
          timeLabel = '${startMinute}-${endMinute}분';
        }
        
        String description = '';
        if (keywords.isNotEmpty) {
          description = '${keywords.take(3).join(', ')} 등에 대해 이야기했습니다. (${topicPercentage.toInt()}% 비중)';
        } else {
          description = '${topicName}에 대한 대화가 이루어졌습니다. (${topicPercentage.toInt()}% 비중)';
        }
        
        timelineItems.add(_buildTimelineItem(
          timeLabel,
          topicName,
          description,
          true, // 실제 데이터는 모두 긍정적으로 표시
        ));
        
        if (i < sortedTopics.length - 1) {
          timelineItems.add(SizedBox(height: 12));
        }
        
        cumulativeTime += topicDuration;
      }
      
      print('📊 실제 주제 타임라인 생성 완료: ${timelineItems.length ~/ 2}개 항목');
      return timelineItems;
    }
    
    // 🔥 실제 데이터가 없을 때만 폴백 (기존 로직 유지하되 더 동적으로)
    print('⚠️ 실제 주제 데이터 없음 - 시뮬레이션 타임라인 생성');
    
    if (duration >= 120) { // 2분 이상
      final midTime = (duration/2/60).round();
      final endTime = (duration/60).round();
      
      timelineItems.add(_buildTimelineItem(
        '시작 (0분)',
        '${_getSessionTypeName()} 도입',
        '${_getSessionTypeName()} 시작과 함께 주요 안건이 소개되었습니다.',
        true,
      ));
      timelineItems.add(SizedBox(height: 12));
      
      if (duration >= 300) { // 5분 이상
        timelineItems.add(_buildTimelineItem(
          '중반 (${midTime}분)',
          '핵심 내용 전개',
          '주요 내용과 핵심 메시지에 대한 집중적인 논의가 이루어졌습니다.',
          true,
        ));
        timelineItems.add(SizedBox(height: 12));
      }
      
      timelineItems.add(_buildTimelineItem(
        '마무리 (${endTime}분)',
        '정리 및 결론',
        '핵심 내용을 정리하며 ${_getSessionTypeName()}이 마무리되었습니다.',
        true,
      ));
    } else {
      // 짧은 세션
      timelineItems.add(_buildTimelineItem(
        '전체 진행',
        '간결한 ${_getSessionTypeName()}',
        '짧은 시간 동안 핵심적인 내용이 효과적으로 전달되었습니다.',
        true,
      ));
    }
    
    return timelineItems;
  }

  // 타임라인 아이템 위젯
  Widget _buildTimelineItem(String time, String title, String description, bool isPositive) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
            color: isPositive ? AppColors.primary : Colors.orange,
            shape: BoxShape.circle,
                ),
              ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
              SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF616161),
                  height: 1.3,
                              ),
                            ),
            ],
          ),
        ),
      ],
    );
  }

  // 핵심 포인트 카드들 생성
  List<Widget> _buildKeyPointCards() {
    final cards = <Widget>[];
    final sessionType = _getSessionTypeKey();
    final topicMetrics = analysisResult.metrics.topicMetrics;
    
    if (topicMetrics.topics.isNotEmpty) {
      final primaryTopic = topicMetrics.topics.firstWhere(
        (topic) => topic.isPrimary,
        orElse: () => topicMetrics.topics.first,
      );
      
      cards.add(_buildKeyPointCard(
        '주요 대화 주제',
        Icons.star,
        _getMainTopicAnalysis(primaryTopic),
        AppColors.primary,
      ));
      cards.add(SizedBox(height: 15));
    }

    // 세션별 특화 분석
    switch (sessionType) {
      case 'presentation':
        cards.add(_buildKeyPointCard(
          '발표 자신감 지표',
          Icons.psychology,
          _getPresentationConfidenceAnalysis(),
          Colors.blue,
        ));
        cards.add(SizedBox(height: 15));
        cards.add(_buildKeyPointCard(
          '전달 효과성',
          Icons.campaign,
          _getPresentationEffectivenessAnalysis(),
          Colors.green,
        ));
        break;
        
      case 'interview':
        cards.add(_buildKeyPointCard(
          '답변 강점',
          Icons.thumb_up,
          _getInterviewStrengthAnalysis(),
          Colors.green,
        ));
        cards.add(SizedBox(height: 15));
        cards.add(_buildKeyPointCard(
          '전문성 어필',
          Icons.work,
          _getInterviewExpertiseAnalysis(),
          Colors.purple,
        ));
        break;
        
      case 'dating':
        cards.add(_buildKeyPointCard(
          '공감대 형성',
          Icons.favorite,
          _getDatingRapportAnalysis(),
          Colors.pink,
        ));
        cards.add(SizedBox(height: 15));
        cards.add(_buildKeyPointCard(
          '관심사 교집합',
          Icons.favorite_border,
          _getDatingInterestAnalysis(),
          Colors.orange,
        ));
        break;
    }
    
    return cards;
  }

  // 대화 흐름 분석 생성
  String _getConversationFlowAnalysis() {
    final sessionType = _getSessionTypeKey();
    final duration = (analysisResult.metrics.totalDuration / 60).round();
    final contribution = analysisResult.metrics.conversationMetrics.contributionRatio;
    
    switch (sessionType) {
      case 'presentation':
        return '${duration}분간의 발표에서 체계적인 구조로 정보를 전달했습니다. '
               '청중과의 상호작용을 ${contribution > 80 ? '적절히' : '더 많이'} 유도하며, '
               '핵심 메시지에 집중한 전개가 효과적이었습니다. '
               '질의응답 시간에도 명확한 답변으로 전문성을 보여주었습니다.';
               
      case 'interview':
        return '${duration}분간의 면접에서 논리적이고 체계적인 답변을 제공했습니다. '
               '질문에 대한 이해도가 높았으며, STAR 기법을 활용한 구체적인 경험 공유가 인상적이었습니다. '
               '${contribution > 60 ? '적극적인' : '안정적인'} 답변 태도로 전문성과 열정을 어필했습니다.';
               
      case 'dating':
        return '${duration}분간의 대화에서 자연스러운 주제 전환과 상호 관심사 발견이 이루어졌습니다. '
               '${contribution > 60 ? '다소 주도적이지만' : '균형잡힌'} 대화 참여로 편안한 분위기를 조성했으며, '
               '상대방의 이야기에 적절히 반응하여 좋은 라포를 형성했습니다.';
               
      default:
        return '${duration}분간의 세션에서 체계적이고 자연스러운 대화 흐름을 유지했습니다.';
    }
  }

  // 주요 주제 분석
  String _getMainTopicAnalysis(ConversationTopic topic) {
    final sessionType = _getSessionTypeKey();
    switch (sessionType) {
      case 'presentation':
        return '"${topic.name}" 주제가 전체 발표의 ${topic.percentage.toInt()}%를 차지했습니다. '
               '이 주제에서 청중의 관심이 가장 높았으며, 명확한 정보 전달이 이루어졌습니다.';
      case 'interview':
        return '"${topic.name}" 관련 질문이 면접의 ${topic.percentage.toInt()}%를 차지했습니다. '
               '이 영역에서 전문성과 경험을 효과적으로 어필할 수 있었습니다.';
      case 'dating':
        return '"${topic.name}" 대화가 전체의 ${topic.percentage.toInt()}%를 차지했습니다. '
               '이 주제에서 상호 관심사를 발견하며 자연스러운 공감대를 형성했습니다.';
      default:
        return '"${topic.name}" 주제가 대화의 ${topic.percentage.toInt()}%를 차지했습니다.';
    }
  }

  // 세션별 분석 텍스트들
  String _getPresentationConfidenceAnalysis() {
    final likeability = analysisResult.metrics.emotionMetrics.averageLikeability;
    final speechRate = analysisResult.metrics.speakingMetrics.speechRate;
    final clarity = analysisResult.metrics.speakingMetrics.clarity;
    
    if (likeability >= 70) {
      return '발표 중 높은 자신감을 보였습니다. 안정적인 말하기 속도(${speechRate.toInt()}WPM)와 명확한 전달력(${clarity.toInt()}%)으로 메시지 전달이 효과적이었습니다. 확신 있는 표현과 명확한 구조화가 인상적이었습니다.';
    } else if (likeability >= 50) {
      return '기본적인 발표 자신감은 갖추었으나, 더 확신 있는 어조와 제스처를 사용하면 설득력을 높일 수 있습니다. 핵심 포인트에서 목소리 톤 강조를 활용해보세요.';
    }
    return '발표 자신감 향상이 필요합니다. 충분한 준비와 연습을 통해 확신을 가지고 발표해보세요. 말하기 속도를 조절하고 중요한 내용에서 강조 톤을 사용하면 도움이 됩니다.';
  }

  String _getPresentationEffectivenessAnalysis() {
    final clarity = analysisResult.metrics.speakingMetrics.clarity;
    if (clarity >= 80) {
      return '핵심 메시지가 명확하게 전달되었습니다. 체계적인 구성과 적절한 예시로 이해도를 높였습니다.';
    } else if (clarity >= 60) {
      return '전반적으로 좋은 전달력을 보였습니다. 일부 복잡한 내용은 더 간단히 설명하면 효과적일 것 같습니다.';
    }
    return '메시지 전달 방식에 개선이 필요합니다. 핵심 포인트를 더 명확히 정리해서 전달해보세요.';
  }

  String _getInterviewStrengthAnalysis() {
    final confidence = analysisResult.metrics.emotionMetrics.averageLikeability;
    if (confidence >= 70) {
      return '자신감 있는 답변과 구체적인 경험 공유로 좋은 인상을 남겼습니다. 논리적 구조와 명확한 표현이 강점입니다.';
    } else if (confidence >= 50) {
      return '기본적인 답변 역량은 갖추었습니다. 더 구체적인 성과와 수치를 포함하면 설득력이 높아질 것 같습니다.';
    }
    return '답변에 더 확신을 가져보세요. 구체적인 사례와 성과를 통해 역량을 어필해보는 것이 좋겠습니다.';
  }

  String _getInterviewExpertiseAnalysis() {
    final contribution = analysisResult.metrics.conversationMetrics.contributionRatio;
    if (contribution >= 60) {
      return '전문 분야에 대한 깊이 있는 지식과 열정을 잘 어필했습니다. 적극적인 답변 태도가 인상적이었습니다.';
    } else if (contribution >= 40) {
      return '전문성은 충분히 전달되었습니다. 더 적극적으로 경험과 역량을 어필해보는 것이 좋겠습니다.';
    }
    return '전문성을 더 자신있게 어필해보세요. 구체적인 프로젝트 경험과 성과를 강조해보는 것이 좋겠습니다.';
  }

  String _getDatingRapportAnalysis() {
    final likeability = analysisResult.metrics.emotionMetrics.averageLikeability;
    if (likeability >= 70) {
      return '상대방과 자연스러운 공감대를 형성했습니다. 진정성 있는 소통과 적절한 유머로 좋은 분위기를 만들었습니다.';
    } else if (likeability >= 50) {
      return '기본적인 호감대는 형성되었습니다. 더 개인적인 경험이나 감정을 공유하면 친밀감을 높일 수 있을 것 같습니다.';
    }
    return '상대방과의 공감대 형성을 위해 더 적극적으로 소통해보세요. 공통 관심사를 찾아 대화를 이어가보는 것이 좋겠습니다.';
  }

  String _getDatingInterestAnalysis() {
    final topics = analysisResult.metrics.topicMetrics.topics;
    final commonTopics = topics.where((topic) => topic.percentage > 10).length;
    
    if (commonTopics >= 3) {
      return '다양한 공통 관심사를 발견했습니다. 여러 주제에서 자연스러운 대화가 이어져 좋은 케미를 보여주었습니다.';
    } else if (commonTopics >= 2) {
      return '몇 가지 공통 관심사를 찾았습니다. 이를 바탕으로 더 깊이 있는 대화를 나누면 관계 발전에 도움이 될 것 같습니다.';
    }
    return '공통 관심사를 더 적극적으로 찾아보세요. 상대방의 취미나 관심사에 대해 질문해보는 것이 좋겠습니다.';
  }

  // 추천 주제 목록 생성
  List<Widget> _buildRecommendedTopics() {
    final sessionType = _getSessionTypeKey();
    final recommendations = <Widget>[];
    
    List<String> topicSuggestions;
    switch (sessionType) {
      case 'presentation':
        topicSuggestions = [
          '청중과의 Q&A 세션',
          '실제 사례 및 케이스 스터디',
          '인터랙티브 워크샵 요소',
          '시각적 자료 활용',
          '핵심 메시지 강화 방법',
        ];
        break;
      case 'interview':
        topicSuggestions = [
          '구체적인 프로젝트 성과',
          '문제 해결 경험 사례',
          '팀워크 및 리더십 경험',
          '업계 트렌드에 대한 견해',
          '장기적인 커리어 목표',
        ];
        break;
      case 'dating':
        topicSuggestions = [
          '여행 경험 및 계획',
          '취미와 관심사',
          '음식과 맛집 이야기',
          '영화, 음악 등 문화 활동',
          '라이프스타일과 가치관',
        ];
        break;
      default:
        topicSuggestions = [
          '개인적인 경험 공유',
          '관심사와 취미',
          '미래 계획과 목표',
          '일상 이야기',
        ];
    }

    for (int i = 0; i < topicSuggestions.length; i++) {
      recommendations.add(
        Container(
          margin: EdgeInsets.only(bottom: i == topicSuggestions.length - 1 ? 0 : 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.blue[400],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  topicSuggestions[i],
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF424242),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return recommendations;
  }

  // 핵심 포인트 카드 위젯
  Widget _buildKeyPointCard(String title, IconData icon, String content, Color color) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212121),
            ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF616161),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // 인사이트 카드 위젯
  Widget _buildInsightCard(TopicInsight insight) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                size: 20,
                color: Colors.amber[600],
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.topic,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            insight.insight,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF616161),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// 🔥 주제 분포 데이터 모델
class TopicDistribution {
  final String name;
  final double percentage;
  final Color color;

  TopicDistribution(this.name, this.percentage, this.color);
}

// 🔥 파이차트 커스텀 페인터
class TopicPieChartPainter extends CustomPainter {
  final List<TopicDistribution> distributions;

  TopicPieChartPainter(this.distributions);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.5;
    
    if (distributions.isEmpty) {
      // 기본 원 그리기
      final paint = Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2; // 12시 방향부터 시작
    
    for (final dist in distributions) {
      final sweepAngle = (dist.percentage / 100) * 2 * math.pi;
      
      final paint = Paint()
        ..color = dist.color
        ..style = PaintingStyle.fill;
      
      // 파이 조각 그리기
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      // 경계선 그리기
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );
      
      startAngle += sweepAngle;
    }
    
    // 중앙 빈 원 그리기 (도넛 차트 효과)
    final innerPaint = Paint()
      ..color = Color(0xFFF5F5F5)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius * 0.5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
