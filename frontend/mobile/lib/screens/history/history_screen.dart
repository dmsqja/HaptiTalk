import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../constants/assets.dart';
import '../../constants/colors.dart';
import '../../widgets/session_card.dart';
import '../../models/session.dart';
import '../../providers/analysis_provider.dart';
import '../../models/analysis/analysis_result.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedCategory = '전체';
  String _selectedSort = '최신순';
  final List<String> _categories = [
    '전체',
    '발표',
    '소개팅',
    '면접',
    '최근 일주일',
    '최근 한달'
  ];
  final List<String> _sortOptions = ['최신순', '평가순'];

  bool _isLoading = false;
  List<Session> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessionHistory();
  }

  // 🔥 실제 API에서 세션 기록 로드
  Future<void> _loadSessionHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('📋 세션 기록 로드 시작');
      
      // AnalysisProvider를 통해 실제 분석 기록 조회
      final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
      await analysisProvider.fetchAnalysisHistory(); // void 메서드 호출
      
      // getter로 업데이트된 분석 결과 가져오기
      final analysisResults = analysisProvider.analysisHistory;
      
      // AnalysisResult를 Session 모델로 변환
      _sessions = _convertAnalysisResultsToSessions(analysisResults);
      
      print('✅ 세션 기록 로드 완료: ${_sessions.length}개');
    } catch (e) {
      print('❌ 세션 기록 로드 실패: $e');
      // 오류 발생 시 빈 목록으로 초기화
      _sessions = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // AnalysisResult를 Session으로 변환
  List<Session> _convertAnalysisResultsToSessions(List<AnalysisResult> analysisResults) {
    return analysisResults.map((analysis) {
      // 주요 지표 추출
      Map<String, int> metrics = {};
      
      switch (analysis.category) {
        case '소개팅':
          metrics = {
            '호감도': analysis.metrics.emotionMetrics.averageLikeability.round(),
            '경청 지수': analysis.metrics.conversationMetrics.listeningScore.round(),
          };
          break;
        case '면접':
          metrics = {
            '자신감': analysis.metrics.emotionMetrics.averageLikeability.round(),
            '명확성': analysis.metrics.speakingMetrics.clarity.round(),
          };
          break;
        case '발표':
          metrics = {
            '설득력': analysis.metrics.conversationMetrics.contributionRatio.round(),
            '명확성': analysis.metrics.speakingMetrics.clarity.round(),
          };
          break;
        case '비즈니스':
          metrics = {
            '설득력': analysis.metrics.conversationMetrics.contributionRatio.round(),
            '명확성': analysis.metrics.speakingMetrics.clarity.round(),
          };
          break;
        case '코칭':
          metrics = {
            '발음': analysis.metrics.speakingMetrics.tonality.round(),
            '유창성': analysis.metrics.speakingMetrics.speechRate > 100 ? 80 : 60,
          };
          break;
        default:
          metrics = {
            '전체 점수': analysis.metrics.emotionMetrics.averageLikeability.round(),
          };
      }

      return Session(
        id: analysis.sessionId,
        title: analysis.title,
        date: _formatDate(analysis.date),
        duration: analysis.getFormattedDuration(),
        type: analysis.category,
        metrics: metrics,
        progress: _calculateProgress(analysis),
      );
    }).toList();
  }

  // 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // 진행률 계산 (여러 지표의 평균)
  double _calculateProgress(AnalysisResult analysis) {
    final likeability = analysis.metrics.emotionMetrics.averageLikeability;
    final listening = analysis.metrics.conversationMetrics.listeningScore;
    final clarity = analysis.metrics.speakingMetrics.clarity;
    
    return (likeability + listening + clarity) / 300; // 0~1 사이 값으로 정규화
  }

  List<Session> get filteredSessions {
    List<Session> filtered = List.from(_sessions);

    // 카테고리 필터링
    if (_selectedCategory != '전체' &&
        _selectedCategory != '최근 일주일' &&
        _selectedCategory != '최근 한달') {
      filtered = filtered
          .where((session) => session.type == _selectedCategory)
          .toList();
    } else if (_selectedCategory == '최근 일주일') {
      // 최근 일주일 필터링 로직 (실제로는 날짜 비교 필요)
      filtered = filtered.take(3).toList();
    } else if (_selectedCategory == '최근 한달') {
      // 최근 한달 필터링 로직 (실제로는 날짜 비교 필요)
      filtered = filtered;
    }

    // 정렬
    if (_selectedSort == '최신순') {
      // 이미 최신순으로 정렬되어 있다고 가정
    } else if (_selectedSort == '평가순') {
      // 평가 기준으로 정렬 (진행률 기준으로 임시 구현)
      filtered.sort((a, b) => b.progress.compareTo(a.progress));
    }

    return filtered;
  }

  // 🗑️ 세션 삭제 기능 추가
  Future<void> _deleteSession(String sessionId) async {
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '세션 삭제',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),
        content: Text(
          '이 세션을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondaryTextColor,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: AppColors.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '삭제',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        // 실제 API 호출로 서버에서 삭제
        final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
        await analysisProvider.deleteAnalysisResult(sessionId);

        // 로컬 상태에서도 제거
        setState(() {
          _sessions.removeWhere((session) => session.id == sessionId);
        });

        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('세션이 삭제되었습니다.'),
            backgroundColor: AppColors.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        print('❌ 세션 삭제 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '기록',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            color: AppColors.secondaryTextColor,
            onPressed: () {
              // 검색 기능 구현
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.secondaryTextColor,
            onPressed: _loadSessionHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // 카테고리 필터 (가로 스크롤 가능한 토글 버튼)
          Container(
            height: 57,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor
                            : AppColors.lightGrayColor,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : AppColors.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.secondaryTextColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 세션 개수 및 정렬 옵션
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 ${filteredSessions.length}개 세션',
                  style: TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                Row(
                  children: _sortOptions.map((option) {
                    final isSelected = option == _selectedSort;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSort = option;
                        });
                      },
                      child: Row(
                        children: [
                          Text(
                            option,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryColor
                                  : AppColors.secondaryTextColor,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          if (option != _sortOptions.last)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 1,
                              height: 14,
                              color: AppColors.dividerColor,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // 세션 목록
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 120,
                              color: AppColors.secondaryTextColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '세션 기록이 없습니다',
                              style: TextStyle(
                                color: AppColors.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '새로운 세션을 시작해보세요',
                              style: TextStyle(
                                color: AppColors.secondaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        itemCount: filteredSessions.length,
                        itemBuilder: (context, index) {
                          final session = filteredSessions[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: SessionCard(
                              session: session,
                              onDelete: _deleteSession,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
