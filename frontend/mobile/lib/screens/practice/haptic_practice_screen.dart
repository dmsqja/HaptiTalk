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
  
  // 🎨 시각적 피드백을 위한 애니메이션 컨트롤러들
  late AnimationController _visualFeedbackController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _waveAnimation;
  
  bool _showVisualFeedback = false;
  String _currentVisualPattern = '';

  // 🎯 HaptiTalk 설계 문서 기반 8개 기본 MVP 패턴 (🔥 강화된 버전)
  final List<Map<String, dynamic>> _hapticPatterns = [
    {
      'patternId': 'S1',
      'category': 'speaker',
      'title': '속도 조절',
      'description': '말하기 속도가 너무 빠를 때',
      'metaphor': '빠른 심장 박동',
      'pattern': 'speed_control',
      'icon': Icons.speed,
      'color': Colors.orange,
      'message': '🚀 말하기 속도를 조금 낮춰보세요',
      'vibration': '3회 강한 진동',
    },
    {
      'patternId': 'L1',
      'category': 'listener',
      'title': '경청 강화',
      'description': '더 적극적으로 경청하라는 신호',
      'metaphor': '점진적 주의 집중',
      'pattern': 'listening_enhancement',
      'icon': Icons.hearing,
      'color': Colors.blue,
      'message': '👂 더 적극적으로 경청해보세요',
      'vibration': '약함→중간→강함',
    },
    {
      'patternId': 'F1',
      'category': 'flow',
      'title': '주제 전환',
      'description': '대화 주제를 바꿀 적절한 타이밍',
      'metaphor': '페이지 넘기기',
      'pattern': 'topic_change',
      'icon': Icons.change_circle,
      'color': Colors.green,
      'message': '🔄 주제를 자연스럽게 바꿔보세요',
      'vibration': '2회 긴 진동',
    },
    {
      'patternId': 'R1',
      'category': 'reaction',
      'title': '호감도 상승',
      'description': '상대방의 호감도가 높아졌을 때',
      'metaphor': '상승하는 파동',
      'pattern': 'likability_up',
      'icon': Icons.favorite,
      'color': Colors.pink,
      'message': '💕 상대방이 호감을 느끼고 있어요!',
      'vibration': '4회 상승 파동',
    },
    {
      'patternId': 'F2',
      'category': 'flow',
      'title': '침묵 관리',
      'description': '적절한 침묵 후 대화를 재개하라는 신호',
      'metaphor': '부드러운 알림',
      'pattern': 'silence_management',
      'icon': Icons.volume_off,
      'color': Colors.grey,
      'message': '🤫 자연스럽게 대화를 이어가세요',
      'vibration': '2회 부드러운 탭',
    },
    {
      'patternId': 'S2',
      'category': 'speaker',
      'title': '음량 조절',
      'description': '목소리 크기 조절이 필요할 때',
      'metaphor': '음파 증폭/감소',
      'pattern': 'volume_control',
      'icon': Icons.volume_up,
      'color': Colors.purple,
      'message': '🔊 목소리 크기를 조절해보세요',
      'vibration': '극명한 강도 변화 (약함↔강함)',
    },
    {
      'patternId': 'R2',
      'category': 'reaction',
      'title': '관심도 하락',
      'description': '상대방의 관심이 떨어지고 있을 때',
      'metaphor': '경고 알림',
      'pattern': 'interest_down',
      'icon': Icons.warning,
      'color': Colors.red,
      'message': '⚠️ 상대방의 관심을 끌어보세요',
      'vibration': '4회 강한 경고',
    },
    {
      'patternId': 'L3',
      'category': 'listener',
      'title': '질문 제안',
      'description': '적절한 질문을 던질 타이밍',
      'metaphor': '물음표 형태',
      'pattern': 'question_suggestion',
      'icon': Icons.help_outline,
      'color': Colors.teal,
      'message': '❓ 상대방에게 질문해보세요',
      'vibration': '짧음-짧음-긴휴지-긴진동-여운',
    },
  ];

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
      );

      // 🔥 Flutter 앱 연습화면에서는 시각적 피드백을 2-3초로 통일
      int duration = 3; // 모든 패턴을 3초로 통일
      
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
      case 'S1': // 속도 조절 - 빠른 펄스
        _triggerFastPulseAnimation();
        break;
      case 'L1': // 경청 강화 - 점진적 증가
        _triggerGradualIntensityAnimation();
        break;
      case 'F1': // 주제 전환 - 긴 페이드
        _triggerLongFadeAnimation();
        break;
      case 'R1': // 호감도 상승 - 상승 파동
        _triggerRisingWaveAnimation();
        break;
      case 'F2': // 침묵 관리 - 부드러운 펄스
        _triggerSoftPulseAnimation();
        break;
      case 'S2': // 음량 조절 - 변화하는 크기
        _triggerVaryingSizeAnimation();
        break;
      case 'R2': // 관심도 하락 - 강한 경고
        _triggerAlertAnimation();
        break;
      case 'L3': // 질문 제안 - 물음표 형태
        _triggerQuestionMarkAnimation();
        break;
    }
  }

  // S1: 빠른 펄스 애니메이션 (빠른 심장 박동)
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

  // F2: 부드러운 펄스 애니메이션
  void _triggerSoftPulseAnimation() {
    _pulseController.reset();
    _pulseController.repeat(count: 2);
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

  Widget _buildPatternGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '8가지 기본 햅틱 패턴',
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
    final categories = [
      {'key': 'speaker', 'label': '화자 행동 (S)', 'color': Colors.orange},
      {'key': 'listener', 'label': '청자 행동 (L)', 'color': Colors.blue},
      {'key': 'flow', 'label': '대화 흐름 (F)', 'color': Colors.green},
      {'key': 'reaction', 'label': '상대방 반응 (R)', 'color': Colors.pink},
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
      case 'speaker':
        return Colors.orange;
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
                  // 🎨 패턴별 시각적 효과와 아이콘을 같은 위치에 겹쳐서 표시
                  Container(
                    height: 150, // 🔧 크기 축소 (200 → 150)
                    width: 150,  // 🔧 크기 축소 (200 → 150)
                    margin: EdgeInsets.all(15), // 🔧 여백 축소 (20 → 15)
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 🎨 패턴별 시각적 효과 (배경)
                        _buildPatternVisualEffect(),
                        
                        // 🔥 패턴 아이콘 - 중앙에 겹쳐서 표시
                        Container(
                          width: 60, // 🔧 크기 축소 (80 → 60)
                          height: 60, // 🔧 크기 축소 (80 → 60)
                          decoration: BoxDecoration(
                            color: _getPatternColor(_currentVisualPattern).withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _getPatternColor(_currentVisualPattern),
                              width: 2, // 🔧 선 두께 축소 (3 → 2)
                            ),
                          ),
                          child: Icon(
                            _getPatternIcon(_currentVisualPattern),
                            size: 30, // 🔧 아이콘 크기 축소 (40 → 30)
                            color: _getPatternColor(_currentVisualPattern),
                          ),
                        ),
                      ],
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

  // 🎨 패턴별 시각적 효과 위젯 - 🔧 안전한 크기로 조정
  Widget _buildPatternVisualEffect() {
    Color patternColor = _getPatternColor(_currentVisualPattern);
    
    switch (_currentVisualPattern) {
      case 'S1': // 속도 조절 - 빠른 펄스
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: patternColor.withOpacity(0.6 * _opacityAnimation.value),
                ),
              ),
            );
          },
        );
      
      case 'L1': // 경청 강화 - 점진적 증가
        return AnimatedBuilder(
          animation: _visualFeedbackController,
          builder: (context, child) {
            return Container(
              width: 100 + (60 * _visualFeedbackController.value),
              height: 100 + (60 * _visualFeedbackController.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: patternColor.withOpacity(0.3),
                border: Border.all(
                  color: patternColor,
                  width: 2 + (3 * _visualFeedbackController.value),
                ),
              ),
            );
          },
        );
      
      case 'F1': // 주제 전환 - 긴 페이드
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 180,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: patternColor.withOpacity(0.7 * _opacityAnimation.value),
              ),
            );
          },
        );
      
      case 'R1': // 호감도 상승 - 상승 파동
        return AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                double delay = index * 0.25;
                double animationValue = (_waveAnimation.value - delay).clamp(0.0, 1.0);
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 3),
                  width: 140,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: patternColor.withOpacity(0.8 * animationValue),
                  ),
                );
              }),
            );
          },
        );
      
      case 'F2': // 침묵 관리 - 부드러운 펄스
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (0.3 * _scaleAnimation.value),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: patternColor.withOpacity(0.4),
                ),
              ),
            );
          },
        );
      
      case 'S2': // 음량 조절 - 변화하는 크기
        return AnimatedBuilder(
          animation: _visualFeedbackController,
          builder: (context, child) {
            double size = 80 + (80 * _visualFeedbackController.value);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: patternColor.withOpacity(0.5),
                border: Border.all(color: patternColor, width: 2),
              ),
            );
          },
        );
      
      case 'R2': // 관심도 하락 - 강한 경고
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pulseController.value > 0.5 
                    ? Colors.red.withOpacity(0.8) 
                    : Colors.red.withOpacity(0.3),
              ),
            );
          },
        );
      
      case 'L3': // 질문 제안 - 물음표 형태 - 🔧 안전한 버전
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            // 안전한 범위로 애니메이션 값 제한
            double safeScale = (_scaleAnimation.value).clamp(0.5, 2.0);
            double safeOpacity = (_opacityAnimation.value).clamp(0.0, 1.0);
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 물음표의 위쪽 곡선 부분
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: patternColor.withOpacity(0.6 * safeOpacity),
                    border: Border.all(
                      color: patternColor.withOpacity(safeOpacity),
                      width: 3,
                    ),
                  ),
                ),
                SizedBox(height: 15),
                // 물음표의 점 부분
                Transform.scale(
                  scale: safeScale.clamp(0.8, 1.5),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: patternColor.withOpacity(0.8 * safeOpacity),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      
      default:
        return Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.withOpacity(0.3),
          ),
        );
    }
  }

  Color _getPatternColor(String patternId) {
    switch (patternId) {
      case 'S1':
      case 'S2':
        return Colors.orange;
      case 'L1':
      case 'L3':
        return Colors.blue;
      case 'F1':
      case 'F2':
        return Colors.green;
      case 'R1':
      case 'R2':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getPatternIcon(String patternId) {
    switch (patternId) {
      case 'S1':
        return Icons.speed;
      case 'L1':
        return Icons.hearing;
      case 'F1':
        return Icons.change_circle;
      case 'R1':
        return Icons.favorite;
      case 'F2':
        return Icons.volume_off;
      case 'S2':
        return Icons.volume_up;
      case 'R2':
        return Icons.warning;
      case 'L3':
        return Icons.help_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getPatternTitle(String patternId) {
    switch (patternId) {
      case 'S1':
        return '속도 조절';
      case 'L1':
        return '경청 강화';
      case 'F1':
        return '주제 전환';
      case 'R1':
        return '호감도 상승';
      case 'F2':
        return '침묵 관리';
      case 'S2':
        return '음량 조절';
      case 'R2':
        return '관심도 하락';
      case 'L3':
        return '질문 제안';
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