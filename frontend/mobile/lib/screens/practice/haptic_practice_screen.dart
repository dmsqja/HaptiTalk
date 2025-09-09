import 'dart:math';
import 'package:flutter/material.dart';
import 'package:haptitalk/constants/colors.dart';
import 'package:haptitalk/services/watch_service.dart';

class HapticPracticeScreen extends StatefulWidget {
  const HapticPracticeScreen({Key? key}) : super(key: key);

  @override
  _HapticPracticeScreenState createState() => _HapticPracticeScreenState();
}

class _HapticPracticeScreenState extends State<HapticPracticeScreen>
    with TickerProviderStateMixin {
  final WatchService _watchService = WatchService();
  bool _isWatchConnected = false;
  String _currentMessage = '';
  String _currentPatternId = '';
  String _selectedSessionMode = '발표'; // 기본 세션 모드
  
  // 🎨 시각적 피드백을 위한 애니메이션 컨트롤러들
  late AnimationController _visualFeedbackController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _waveAnimation;
  
  bool _showVisualFeedback = false;
  String _currentVisualPattern = '';

  // 🎯 새로운 4개 핵심 햅틱 패턴 (발표/면접 특화)
  final List<Map<String, dynamic>> _allHapticPatterns = [
    // 📢 D1: 속도 조절 (급한 리듬)
    {
      'patternId': 'D1',
      'category': 'delivery',
      'title': '속도 조절',
      'description': '말하기 속도가 너무 빠르거나 느릴 때',
      'metaphor': '급한 리듬 (빠른 3연타)',
      'pattern': 'speed_control',
      'icon': Icons.speed, // 워치: speedometer
      'color': Colors.orange,
      'sessions': ['발표', '면접'],
      'messages': {
        '발표': '천천히 말해보세요',
        '면접': '천천히 답변해보세요',
      },
      'titles': {
        '발표': '발표 속도 조절',
        '면접': '답변 속도 조절',
      },
      'vibration': '짧음-짧음-짧음 (빠른 3연타)',
      'duration': '0.9초',
      'isActive': true,
    },

    // 💪 C1: 자신감 상승 (상승 웨이브)
    {
      'patternId': 'C1',
      'category': 'confidence',
      'title': '자신감 상승',
      'description': '목소리에 자신감이 느껴질 때',
      'metaphor': '상승 웨이브 (약함→강함→여운)',
      'pattern': 'confidence_boost',
      'icon': Icons.trending_up, // 워치: chart.line.uptrend.xyaxis
      'color': Colors.green,
      'sessions': ['발표', '면접'],
      'messages': {
        '발표': '훌륭한 발표 자신감이에요!',
        '면접': '확신감 있는 답변이에요!',
      },
      'titles': {
        '발표': '발표 자신감 상승',
        '면접': '면접 자신감 상승',
      },
      'vibration': '약함→강함→여운 (점진적 상승)',
      'duration': '1.1초',
      'isActive': true,
    },

    // 🧘 C2: 자신감 하락 (부드러운 경고)
    {
      'patternId': 'C2',
      'category': 'confidence',
      'title': '자신감 하락',
      'description': '자신감이 떨어질 때 (격려)',
      'metaphor': '부드러운 경고 (강함-휴지-강함)',
      'pattern': 'confidence_alert',
      'icon': Icons.trending_down, // 워치: chart.line.downtrend.xyaxis
      'color': Colors.purple,
      'sessions': ['발표', '면접'],
      'messages': {
        '발표': '더 자신감 있게 발표하세요!',
        '면접': '더 자신감 있게 답변하세요!',
      },
      'titles': {
        '발표': '발표 자신감 하락',
        '면접': '면접 자신감 하락',
      },
      'vibration': '강함-휴지-강함 (2회 경고)',
      'duration': '0.9초',
      'isActive': true,
    },

    // 🗣️ F1: 필러워드 감지 (가벼운 지적)
    {
      'patternId': 'F1',
      'category': 'filler',
      'title': '필러워드 감지',
      'description': '"음", "어", "그런" 등 불필요한 감탄사',
      'metaphor': '가벼운 지적 (톡-톡)',
      'pattern': 'filler_word_alert',
      'icon': Icons.warning_amber, // 워치: exclamationmark.bubble
      'color': Colors.blue,
      'sessions': ['발표', '면접'],
      'messages': {
        '발표': '"음", "어" 등을 줄여보세요',
        '면접': '"음", "어" 등을 줄여보세요',
      },
      'titles': {
        '발표': '발표 표현 정제',
        '면접': '답변 표현 정제',
      },
      'vibration': '톡-톡 (짧은 2연타)',
      'duration': '0.2초',
      'isActive': true,
    },
  ];

  // 활성화된 패턴들만 필터링 (세션 모드별)
  List<Map<String, dynamic>> get _hapticPatterns {
    return _allHapticPatterns.where((pattern) {
      // 🔥 활성화된 패턴이면서 현재 세션에 속한 패턴만 표시
      final isActive = pattern['isActive'] ?? false;
      final sessions = pattern['sessions'] as List<String>;
      return isActive && sessions.contains(_selectedSessionMode);
    }).map((pattern) {
      // 세션별 메시지 적용
      final sessionMessages = pattern['messages'] as Map<String, String>;
      return {
        ...pattern,
        'message': sessionMessages[_selectedSessionMode] ?? '기본 메시지',
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _checkWatchConnection();
    _initializeAnimationControllers();
  }

  Future<void> _checkWatchConnection() async {
    try {
      final isConnected = await _watchService.isWatchConnected();
      setState(() {
        _isWatchConnected = isConnected;
      });
    } catch (e) {
      print('Watch 연결 상태 확인 실패: $e');
    }
  }

  Future<void> _triggerHapticPattern(Map<String, dynamic> pattern) async {
    if (!_isWatchConnected) {
      _showErrorSnackBar('Apple Watch가 연결되지 않았습니다');
      return;
    }

    setState(() {
      _currentMessage = pattern['message'];
      _currentPatternId = pattern['patternId'];
    });

    // 🎨 시각적 피드백 시작
    _triggerVisualFeedback(pattern['patternId']);

    try {
      await _watchService.sendHapticFeedbackWithPattern(
        message: pattern['message'],
        pattern: pattern['pattern'],
        category: pattern['category'],
        patternId: pattern['patternId'],
        sessionType: _selectedSessionMode, // 🔥 현재 선택된 세션 모드 전달
      );

      // 🔥 Flutter 앱 연습화면에서는 시각적 피드백을 4초로 통일
      int duration = 4; // 모든 패턴을 4초로 통일 (1초 연장)
      
      Future.delayed(Duration(seconds: duration), () {
        if (mounted) {
          setState(() {
            _currentMessage = '';
            _currentPatternId = '';
            _showVisualFeedback = false;
          });
        }
      });

      print('🎯 햅틱 패턴 [${pattern['patternId']}] 전송: ${pattern['message']}');
    } catch (e) {
      print('❌ 햅틱 패턴 전송 실패: $e');
      _showErrorSnackBar('햅틱 피드백 전송에 실패했습니다');
    }
  }

  // 🎨 패턴별 시각적 피드백 트리거
  void _triggerVisualFeedback(String patternId) {
    setState(() {
      _showVisualFeedback = true;
      _currentVisualPattern = patternId;
    });

    switch (patternId) {
      // 🎯 새로운 4개 핵심 패턴 애니메이션
      case 'D1': // 전달력: 속도 조절 - 리듬감 있는 펄스
        _triggerFastPulseAnimation();
        break;
      case 'C1': // 자신감: 확신도 상승 - 상승 파동
        _triggerRisingWaveAnimation();
        break;
              case 'C2': // 자신감: 하락 - 떨어지는 화살표 효과
        _triggerConfidenceDropAnimation();
        break;
      case 'F1': // 필러워드: 감지 - 짧은 펄스
        _triggerShortPulseAnimation();
        break;
        
      // 🔒 비활성화된 패턴들 (주석 처리)
      /*
      case 'L1': // 경청 강화 - 점진적 증가
        _triggerGradualIntensityAnimation();
        break;
      case 'F1': // 주제 전환 - 긴 페이드
        _triggerLongFadeAnimation();
        break;
      case 'F2': // 침묵 관리 - 부드러운 펄스 (비활성화됨)
        // _triggerSoftPulseAnimation(); // 비활성화된 패턴
        break;
      case 'L3': // 질문 제안 - 물음표 형태
        _triggerQuestionMarkAnimation();
        break;
      */
    }
  }

  // D1: 빠른 펄스 애니메이션 (빠른 심장 박동)
  void _triggerFastPulseAnimation() {
    _pulseController.reset();
    _pulseController.repeat(count: 3);
  }

  // L1: 점진적 강도 증가 애니메이션
  void _triggerGradualIntensityAnimation() {
    _visualFeedbackController.reset();
    _visualFeedbackController.forward();
  }

  // F1: 긴 페이드 애니메이션 (페이지 넘기기)
  void _triggerLongFadeAnimation() {
    _pulseController.reset();
    _pulseController.duration = Duration(milliseconds: 800);
    _pulseController.forward().then((_) {
      _pulseController.duration = Duration(milliseconds: 500); // 원복
    });
  }

  // R1: 상승 파동 애니메이션
  void _triggerRisingWaveAnimation() {
    _waveController.reset();
    _waveController.forward();
  }

  // C2: 자신감 하락 애니메이션 (워치와 동일하게 한번만 실행)
  void _triggerConfidenceDropAnimation() {
    _pulseController.reset();
    _pulseController.duration = Duration(milliseconds: 2500); // 2.5초 총 시간
    _pulseController.forward().then((_) {
      _pulseController.duration = Duration(milliseconds: 500); // 원복
    });
  }

  // S2: 크기 변화 애니메이션 (음파)
  void _triggerVaryingSizeAnimation() {
    _visualFeedbackController.reset();
    _visualFeedbackController.repeat(count: 2);
  }

  // R2: 경고 애니메이션 (강한 깜빡임)
  void _triggerAlertAnimation() {
    _pulseController.reset();
    _pulseController.duration = Duration(milliseconds: 300);
    _pulseController.repeat(count: 2).then((_) {
      _pulseController.duration = Duration(milliseconds: 500); // 원복
    });
  }

  // L3: 물음표 형태 애니메이션 - 🔧 안전한 단순 버전
  void _triggerQuestionMarkAnimation() {
    _pulseController.reset();
    _pulseController.repeat(count: 4); // 단순한 4회 반복으로 변경
  }

  // F1: 짧은 펄스 애니메이션 (가벼운 지적)
  void _triggerShortPulseAnimation() {
    _pulseController.reset();
    _pulseController.repeat(count: 2);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _initializeAnimationControllers() {
    _visualFeedbackController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '햅틱 패턴 연습',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textColor),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildConnectionStatus(),
              if (_currentMessage.isNotEmpty) _buildCurrentFeedback(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIntroSection(),
                      const SizedBox(height: 20),
                      _buildSessionModeSelector(),
                      const SizedBox(height: 25),
                      _buildPatternGrid(),
                      const SizedBox(height: 25),
                      _buildCategoryLegend(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 🎨 시각적 피드백 오버레이
          _buildVisualFeedbackOverlay(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: _isWatchConnected ? Colors.green.shade100 : Colors.red.shade100,
      child: Row(
        children: [
          Icon(
            _isWatchConnected ? Icons.watch : Icons.watch_off,
            color: _isWatchConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Text(
            _isWatchConnected 
                ? '✅ Apple Watch 연결됨' 
                : '❌ Apple Watch 연결 안됨',
            style: TextStyle(
              color: _isWatchConnected ? Colors.green.shade800 : Colors.red.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (!_isWatchConnected)
            TextButton(
              onPressed: _checkWatchConnection,
              child: const Text('다시 확인'),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentFeedback() {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        border: Border.all(color: AppColors.primaryColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.vibration,
            color: AppColors.primaryColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 재생 중: $_currentPatternId',
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _currentMessage,
                  style: TextStyle(
                    color: AppColors.textColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                color: AppColors.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'HaptiTalk 햅틱 패턴 학습',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            '각 버튼을 눌러 다양한 햅틱 패턴을 경험해보세요.\n실제 대화 중 어떤 상황에서 어떤 진동이 오는지 미리 학습할 수 있습니다.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.secondaryTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionModeSelector() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Row(
        children: [
          const Text(
            '세션 모드:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _selectedSessionMode,
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedSessionMode = newValue;
                });
              }
            },
            items: ['발표', '면접'].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4가지 핵심 햅틱 패턴',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.95,
          ),
          itemCount: _hapticPatterns.length,
          itemBuilder: (context, index) {
            final pattern = _hapticPatterns[index];
            final isCurrentlyPlaying = _currentPatternId == pattern['patternId'];
            
            return GestureDetector(
              onTap: () => _triggerHapticPattern(pattern),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrentlyPlaying 
                        ? AppColors.primaryColor 
                        : AppColors.dividerColor,
                    width: isCurrentlyPlaying ? 2 : 1,
                  ),
                  boxShadow: isCurrentlyPlaying
                      ? [
                          BoxShadow(
                            color: AppColors.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (pattern['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            pattern['icon'],
                            color: pattern['color'],
                            size: 18,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(pattern['category']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pattern['patternId'],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(pattern['category']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pattern['title'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        pattern['description'],
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryTextColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 🔥 진동 정보 표시 (메타포 대신)
                    Text(
                      '${pattern['vibration']}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500, // 🔥 약간 굵게 표시
                        color: _getCategoryColor(pattern['category']).withOpacity(0.8), // 🔥 카테고리 색상으로 표시
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isCurrentlyPlaying) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryLegend() {
          // 🎯 새로운 4개 핵심 카테고리
      final categories = [
        {'key': 'delivery', 'label': '전달력 (D)', 'color': Colors.orange},
        {'key': 'confidence', 'label': '자신감 (C)', 'color': Colors.green},
        {'key': 'filler', 'label': '필러워드 (F)', 'color': Colors.blue},
      ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카테고리 설명',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          const SizedBox(height: 15),
          ...categories.map((category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: category['color'] as Color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      category['label'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textColor,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'delivery':
        return Colors.orange;
      case 'confidence':
        return Colors.green;
      case 'filler':
        return Colors.blue;
      case 'listener':
        return Colors.blue;
      case 'flow':
        return Colors.green;
      case 'reaction':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  // 🎨 시각적 피드백 오버레이 - 🔥 확실한 표시를 위한 개선
  Widget _buildVisualFeedbackOverlay() {
    if (!_showVisualFeedback || _currentVisualPattern.isEmpty) {
      return Container(); // 아무것도 표시하지 않음
    }
    
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        color: Colors.transparent, // 🔧 배경을 완전히 투명하게
        child: Center(
          child: SingleChildScrollView( // 🔧 스크롤 가능하게 수정
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7, // 🔧 크기 축소 (0.85 → 0.7)
              constraints: BoxConstraints(
                maxWidth: 320, // 🔧 최대 너비 축소 (380 → 320)
                minWidth: 250, // 🔧 최소 너비 축소 (300 → 250)
                minHeight: 300, // 🔧 최소 높이 축소 (350 → 300)
                maxHeight: MediaQuery.of(context).size.height * 0.6, // 🔧 최대 높이 축소 (0.8 → 0.6)
              ),
              margin: EdgeInsets.symmetric(vertical: 40), // 🔧 상하 여백 추가
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column( // 🔧 Stack 대신 Column 사용으로 안전한 레이아웃
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🎨 패턴별 시각적 효과 - 아이콘과 배경을 하나로 통합
                  Container(
                    height: 150, // 🔧 크기 축소 (200 → 150)
                    width: 150,  // 🔧 크기 축소 (200 → 150)
                    margin: EdgeInsets.all(15), // 🔧 여백 축소 (20 → 15)
                    child: Center(
                      child: _buildPatternVisualEffect(),
                    ),
                  ),
                  
                  // 메시지 표시 (하단)
                  Container(
                    margin: EdgeInsets.all(15), // 🔧 여백 축소 (20 → 15)
                    padding: const EdgeInsets.all(15), // 🔧 패딩 축소 (18 → 15)
                    decoration: BoxDecoration(
                      color: _getPatternColor(_currentVisualPattern).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15), // 🔧 둥글기 축소 (18 → 15)
                      border: Border.all(
                        color: _getPatternColor(_currentVisualPattern).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getPatternTitle(_currentVisualPattern),
                          style: TextStyle(
                            fontSize: 20, // 🔧 폰트 크기 축소 (22 → 20)
                            fontWeight: FontWeight.bold,
                            color: _getPatternColor(_currentVisualPattern),
                          ),
                        ),
                        const SizedBox(height: 8), // 🔧 간격 축소 (10 → 8)
                        Text(
                          _currentMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14, // 🔧 폰트 크기 축소 (16 → 14)
                            color: AppColors.textColor,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 패턴별 시각적 효과 위젯 - 고정된 아이콘과 패턴별 애니메이션 배경
  Widget _buildPatternVisualEffect() {
    Color patternColor = _getPatternColor(_currentVisualPattern);
    IconData patternIcon = _getPatternIcon(_currentVisualPattern);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // 🎨 패턴별 애니메이션 배경
        _buildPatternSpecificAnimation(patternColor),
        
        // 🔥 고정된 아이콘 - 애니메이션 없이 중앙에 고정
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: patternColor.withOpacity(0.15),
            border: Border.all(
              color: patternColor,
              width: 3,
            ),
          ),
          child: Icon(
            patternIcon,
            size: 40,
            color: patternColor,
          ),
        ),
      ],
    );
  }

  // 🎨 패턴별 특화 애니메이션 배경
  Widget _buildPatternSpecificAnimation(Color patternColor) {
    switch (_currentVisualPattern) {
      case 'D1': // 빠른 펄스 (3회 반복)
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double pulseScale = 1.0 + (0.3 * sin(_pulseController.value * 2 * pi));
            return Transform.scale(
              scale: pulseScale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: patternColor.withOpacity(0.1),
                  border: Border.all(
                    color: patternColor.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        );
      
      case 'C1': // 상승 파동 애니메이션
        return AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            double waveScale = 1.0 + (0.5 * _waveController.value); // 상승하는 느낌
            double waveOpacity = 1.0 - (0.7 * _waveController.value); // 점점 투명해짐
            return Transform.scale(
              scale: waveScale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: patternColor.withOpacity(0.1 * waveOpacity),
                  border: Border.all(
                    color: patternColor.withOpacity(0.6 * waveOpacity),
                    width: 3,
                  ),
                ),
              ),
            );
          },
        );
      
      case 'C2': // 하락 애니메이션 (긴 시간)
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double pulseScale = 1.0 + (0.2 * sin(_pulseController.value * 2 * pi));
            return Transform.scale(
              scale: pulseScale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: patternColor.withOpacity(0.1),
                  border: Border.all(
                    color: patternColor.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        );
      
      case 'F1': // 짧은 펄스 (2회 반복)
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            double pulseScale = 1.0 + (0.25 * sin(_pulseController.value * 2 * pi));
            return Transform.scale(
              scale: pulseScale,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: patternColor.withOpacity(0.1),
                  border: Border.all(
                    color: patternColor.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        );
      
      default:
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: patternColor.withOpacity(0.1),
            border: Border.all(
              color: patternColor.withOpacity(0.3),
              width: 2,
            ),
          ),
        );
    }
  }

  Color _getPatternColor(String patternId) {
    switch (patternId) {
      // 🎯 새로운 4개 핵심 패턴 색상
      case 'D1':
        return Colors.orange; // 전달력: 속도 조절
      case 'C1':
        return Colors.green; // 자신감: 상승
      case 'C2':
        return Colors.purple; // 자신감: 하락 (구분을 위해 다른 색상)
      case 'F1':
        return Colors.blue; // 필러워드
      default:
        return Colors.grey;
    }
  }

  IconData _getPatternIcon(String patternId) {
    switch (patternId) {
      // 🎯 워치와 동일한 4개 핵심 패턴 아이콘
      case 'D1':
        return Icons.speed; // 워치: speedometer
      case 'C1':
        return Icons.trending_up; // 워치: chart.line.uptrend.xyaxis
      case 'C2':
        return Icons.trending_down; // 워치: chart.line.downtrend.xyaxis
      case 'F1':
        return Icons.warning_amber; // 워치: exclamationmark.bubble
      default:
        return Icons.help_outline;
    }
  }

  String _getPatternTitle(String patternId) {
    // 활성화된 4개 핵심 패턴 제목 반환
    switch (patternId) {
      // ✅ 활성화된 패턴들
      case 'D1':
        return _selectedSessionMode == '발표' ? '발표 속도 조절' : '답변 속도 조절';
      case 'C1':
        return _selectedSessionMode == '발표' ? '발표 자신감 상승' : '면접 자신감 상승';
      case 'C2':
        return _selectedSessionMode == '발표' ? '발표 자신감 하락' : '면접 자신감 하락';
      case 'F1':
        return _selectedSessionMode == '발표' ? '발표 표현 정제' : '답변 표현 정제';
        
      // 🔒 비활성화된 패턴들 (주석 처리)
      /*
      case 'L1':
        return _selectedSessionMode == '발표' ? '청중 소통 강화' :
               _selectedSessionMode == '면접' ? '면접관 경청' : '상대방 경청';
      case 'F1':
        return _selectedSessionMode == '발표' ? '발표 주제 전환' :
               _selectedSessionMode == '면접' ? '면접 주제 전환' : '대화 주제 전환';
      case 'F2':
        return _selectedSessionMode == '발표' ? '발표 휴지 관리' :
               _selectedSessionMode == '면접' ? '면접 침묵 관리' : '대화 침묵 관리';
      case 'L3':
        return _selectedSessionMode == '발표' ? '핵심 포인트 강조' :
               _selectedSessionMode == '면접' ? '질문 제안' : '대화 제안';
      */
      default:
        return 'Unknown Pattern';
    }
  }

  @override
  void dispose() {
    _visualFeedbackController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }
} 