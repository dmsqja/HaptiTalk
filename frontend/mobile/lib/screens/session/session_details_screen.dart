import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/session/session_model.dart';
import '../../models/analysis/analysis_result.dart';
import '../../providers/session_provider.dart';
import '../../providers/analysis_provider.dart';
import '../../constants/colors.dart';
import '../../widgets/common/buttons/primary_button.dart';
import '../../widgets/session/session_header.dart';
import '../../widgets/session/session_detail_tab_timeline.dart';
import '../../widgets/session/session_detail_tab_emotion.dart';
import '../../widgets/session/session_detail_tab_speaking.dart';
import '../../widgets/session/session_detail_tab_topics.dart';

class SessionDetailsScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailsScreen({Key? key, required this.sessionId})
      : super(key: key);

  @override
  _SessionDetailsScreenState createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late Future<AnalysisResult> _analysisFuture;
  bool _isAudioPlaying = false;
  AnalysisResult? _analysisResult; // 분석 결과 저장용

  @override
  void initState() {
    super.initState();
    _analysisFuture = _loadAnalysisData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initializeTabController(AnalysisResult analysisResult) {
    _analysisResult = analysisResult;
    final isPresentation = _getSessionTypeKey(analysisResult) == 'presentation';
    final tabCount = isPresentation ? 3 : 4; // 발표는 3개, 나머지는 4개 탭
    _tabController = TabController(length: tabCount, vsync: this);
  }

  String _getSessionTypeKey(AnalysisResult analysisResult) {
    final category = analysisResult.category.toLowerCase();
    if (category.contains('발표') || category == 'presentation') return 'presentation';
    if (category.contains('면접') || category == 'interview') return 'interview';
    if (category.contains('소개팅') || category == 'dating') return 'dating';
    return 'presentation';
  }

  List<Widget> _buildTabs() {
    if (_analysisResult == null) return [];
    
    final isPresentation = _getSessionTypeKey(_analysisResult!) == 'presentation';
    
    if (isPresentation) {
      return const [
        Tab(text: '타임라인'),
        Tab(text: '말하기 패턴'),
        Tab(text: '대화 주제'),
      ];
    } else {
      return const [
        Tab(text: '타임라인'),
        Tab(text: '감정/호감도'),
        Tab(text: '말하기 패턴'),
        Tab(text: '대화 주제'),
      ];
    }
  }

  List<Widget> _buildTabViews() {
    if (_analysisResult == null) return [];
    
    final isPresentation = _getSessionTypeKey(_analysisResult!) == 'presentation';
    
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

  Future<AnalysisResult> _loadAnalysisData() async {
    final analysisProvider =
        Provider.of<AnalysisProvider>(context, listen: false);
    return analysisProvider.getAnalysisResult(widget.sessionId);
  }

  void _toggleAudioPlayback() {
    setState(() {
      _isAudioPlaying = !_isAudioPlaying;
    });
    // 실제 구현에서는 오디오 재생/정지 로직 추가
  }

  void _shareSession() {
    // 세션 공유 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('세션 공유 기능이 추가될 예정입니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '세션 상세',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 18,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: Container(
          padding: EdgeInsets.all(5),
          child: Container(width: 24, height: 24, child: Stack()),
        ),
        actions: [
          Container(
            padding: EdgeInsets.all(5),
            child: Container(width: 22, height: 22, child: Stack()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Color(0xFFF0F0F0),
          ),
        ),
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<AnalysisResult>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('분석 데이터를 불러오는데 실패했습니다.'),
                  SizedBox(height: 16),
                  PrimaryButton(
                    text: '다시 시도',
                    onPressed: () {
                      setState(() {
                        _analysisFuture = _loadAnalysisData();
                      });
                    },
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(child: Text('데이터가 없습니다.'));
          }

          final analysisResult = snapshot.data!;
          
          // 탭 컨트롤러 초기화 (한 번만)
          if (_tabController == null) {
            _initializeTabController(analysisResult);
          }

          return Column(
            children: [
              // 세션 기본 정보 헤더
              SessionHeader(
                title: analysisResult.title,
                date: analysisResult.getFormattedDate(),
                duration: analysisResult.getFormattedDuration(),
                category: analysisResult.category,
                isAudioPlaying: _isAudioPlaying,
                onPlayAudio: _toggleAudioPlayback,
              ),

              // 탭 바 (Figma 디자인)
              Container(
                padding: EdgeInsets.only(bottom: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(width: 1, color: Color(0xFFF0F0F0)),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Color(0xFF3F51B5),
                  unselectedLabelColor: Color(0xFF757575),
                  indicatorColor: Color(0xFF3F51B5),
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: TextStyle(
                    color: Color(0xFF3F51B5),
                    fontSize: 14,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 14,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: _buildTabs(),
                ),
              ),

              // 탭 내용 (동적으로 구성)
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: TabBarView(
                    controller: _tabController,
                    physics: BouncingScrollPhysics(),
                    children: _buildTabViews(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
