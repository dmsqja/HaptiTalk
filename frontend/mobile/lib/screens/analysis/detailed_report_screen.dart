import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../models/analysis/analysis_result.dart';
import '../../providers/analysis_provider.dart';
import '../../widgets/session/session_detail_tab_timeline.dart';
import '../../widgets/session/session_detail_tab_emotion.dart';
import '../../widgets/session/session_detail_tab_speaking.dart';
import '../../widgets/session/session_detail_tab_topics.dart';

class DetailedReportScreen extends StatefulWidget {
  final String sessionId;

  const DetailedReportScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  State<DetailedReportScreen> createState() => _DetailedReportScreenState();
}

class _DetailedReportScreenState extends State<DetailedReportScreen> with SingleTickerProviderStateMixin {
  AnalysisResult? _analysisResult;
  bool _isLoading = true;
  String? _errorMessage;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initializeTabController() {
    if (_analysisResult != null) {
      final isPresentation = _getSessionTypeKey() == 'presentation';
      final tabCount = isPresentation ? 3 : 4; // 발표는 3개, 나머지는 4개 탭
      _tabController = TabController(length: tabCount, vsync: this);
    }
  }

  String _getSessionTypeKey() {
    final category = _analysisResult?.category.toLowerCase() ?? '';
    if (category.contains('발표') || category == 'presentation') return 'presentation';
    if (category.contains('면접') || category == 'interview') return 'interview';
    if (category.contains('소개팅') || category == 'dating') return 'dating';
    return 'presentation';
  }

  Future<void> _loadAnalysisData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // AnalysisProvider를 사용하여 분석 결과 화면과 동일한 데이터 소스 활용
      final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
      final analysisResult = await analysisProvider.getSessionAnalysis(widget.sessionId);
      
      if (analysisResult != null) {
        _analysisResult = analysisResult;
        _initializeTabController(); // 탭 컨트롤러 초기화
        print('✅ 분석 결과 로드 성공: ${analysisResult.category}');
      } else {
        throw Exception('분석 결과를 찾을 수 없습니다');
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '상세 분석 리포트',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAnalysisData,
          ),
        ],
        bottom: _analysisResult != null ? TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: _buildTabs(),
        ) : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('상세 리포트를 생성하고 있습니다...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              '리포트를 불러올 수 없습니다',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalysisData,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_analysisResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '상세 분석 데이터가 없습니다',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '실시간 분석을 진행한 세션만 상세 리포트를 확인할 수 있습니다.\n세션을 더 길게 진행하면 더 정확한 분석 결과를 얻을 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('돌아가기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 4개 탭 뷰 반환
    return TabBarView(
      controller: _tabController,
      children: _buildTabViews(),
    );
  }

  List<Widget> _buildTabs() {
    final isPresentation = _getSessionTypeKey() == 'presentation';
    
    if (isPresentation) {
      return const [
        Tab(text: '타임라인'),
        Tab(text: '말하기패턴'),
        Tab(text: '주제분석'),
      ];
    } else {
      return const [
        Tab(text: '타임라인'),
        Tab(text: '감정분석'),
        Tab(text: '말하기패턴'),
        Tab(text: '주제분석'),
      ];
    }
  }

  List<Widget> _buildTabViews() {
    final isPresentation = _getSessionTypeKey() == 'presentation';
    
    if (isPresentation) {
      return [
        SessionDetailTabTimeline(analysisResult: _analysisResult!),
        SessionDetailTabSpeaking(analysisResult: _analysisResult!),
        SessionDetailTabTopics(analysisResult: _analysisResult!),
      ];
    } else {
      return [
        SessionDetailTabTimeline(analysisResult: _analysisResult!),
        SessionDetailTabEmotion(analysisResult: _analysisResult!),
        SessionDetailTabSpeaking(analysisResult: _analysisResult!),
        SessionDetailTabTopics(analysisResult: _analysisResult!),
      ];
    }
  }
} 