import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:haptitalk/constants/colors.dart';
import 'package:haptitalk/models/analysis/analysis_result.dart';
import 'package:haptitalk/providers/analysis_provider.dart';
import 'package:haptitalk/providers/session_provider.dart';
import 'package:haptitalk/screens/analysis/analysis_summary_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAnalysisHistory();
  }

  Future<void> _loadAnalysisHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 분석 기록 조회
      await Provider.of<AnalysisProvider>(context, listen: false)
          .fetchAnalysisHistory();

      // 로딩이 끝난 후 최근 세션이 있는지 확인
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _navigateToLatestSessionIfExists();
      }
    } catch (e) {
      // 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('분석 기록을 불러오는 중 오류가 발생했습니다: $e')),
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 최근 세션이 있으면 해당 세션 분석 결과로 이동
  void _navigateToLatestSessionIfExists() {
    final analysisProvider =
        Provider.of<AnalysisProvider>(context, listen: false);
    final analysisHistory = analysisProvider.analysisHistory;

    // 분석 기록이 있으면 가장 최근 세션으로 이동
    if (analysisHistory.isNotEmpty) {
      final latestAnalysis = analysisHistory.first;

      // 이 부분에서는 화면 전환 애니메이션을 부드럽게 하기 위해
      // pushReplacement 대신 Future.delayed와 push 사용
      Future.delayed(Duration.zero, () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisSummaryScreen(
              sessionId: latestAnalysis.sessionId,
              sessionType: null,
            ),
          ),
        );
      });
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
          '분석',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.secondaryTextColor,
            onPressed: _loadAnalysisHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildEmptyAnalysisScreen(),
    );
  }

  Widget _buildEmptyAnalysisScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assessment_outlined,
              size: 80,
              color: AppColors.secondaryTextColor,
            ),
            const SizedBox(height: 24),
            Text(
              '최근 진행된 세션이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '새 세션을 만들고 완료하면 여기에 분석 결과가 표시됩니다.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // 홈 탭으로 이동 (메인 탭 인덱스 0으로 설정)
                if (onMainTabIndexChange != null) {
                  onMainTabIndexChange!(0);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('새 세션 시작하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 메인 탭 인덱스 변경을 위한 콜백 함수
Function(int)? onMainTabIndexChange;
