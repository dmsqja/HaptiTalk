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
      'details': '매우 빠른 3회 연속 진동 (120ms 간격)\n강한 강도로 확실한 경고',
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
      'details': '점진적 강도 증가 4회 진동 (400ms 간격)\n약함→중간→강함→더블탭',
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
      'details': '긴 진동 2회 (600ms 간격)\n페이지 넘기기 완료까지 표현',
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
      'details': '점진적 상승 4회 진동 (300ms 간격)\n부드러운 시작→행복한 정점→지속',
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
      'details': '매우 부드러운 2회 탭 (800ms 간격)\n침묵의 느낌을 살린 긴 간격',
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
      'details': '극명한 강도 변화 (약함↔강함)\n더블탭으로 변화 강조',
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
      'details': '매우 강한 4회 경고 (100ms 간격)\n긴급한 상황임을 명확히 전달',
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
      'details': '물음표 패턴: 짧음-짧음-긴휴지-긴진동-여운\n질문의 형태를 진동으로 표현',
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

      // 3초 후 메시지 클리어
      Future.delayed(Duration(seconds: 3), () {
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

  // L3: 물음표 형태 애니메이션
  void _triggerQuestionMarkAnimation() {
    _pulseController.reset();
    _pulseController.forward().then((_) {
      Future.delayed(Duration(milliseconds: 200), () {
        _pulseController.reset();
        _pulseController.forward().then((_) {
          Future.delayed(Duration(milliseconds: 300), () {
            _pulseController.reset();
            _pulseController.duration = Duration(milliseconds: 800);
            _pulseController.forward().then((_) {
              _pulseController.duration = Duration(milliseconds: 500); // 원복
            });
          });
        });
      });
    });
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
          if (_showVisualFeedback) _buildVisualFeedbackOverlay(),
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
            childAspectRatio: 0.85,
          ),
          itemCount: _hapticPatterns.length,
          itemBuilder: (context, index) {
            final pattern = _hapticPatterns[index];
            final isCurrentlyPlaying = _currentPatternId == pattern['patternId'];
            
            return GestureDetector(
              onTap: () => _triggerHapticPattern(pattern),
              child: Container(
                padding: const EdgeInsets.all(16),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (pattern['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            pattern['icon'],
                            color: pattern['color'],
                            size: 20,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(pattern['category']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pattern['patternId'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(pattern['category']),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pattern['title'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pattern['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryTextColor,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '메타포: ${pattern['metaphor']}',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pattern['details'],
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isCurrentlyPlaying) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(2),
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

  Widget _buildVisualFeedbackOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 🎨 패턴별 시각적 효과
                _buildPatternVisualEffect(),
                // 메시지 표시
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentPatternId,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _getPatternColor(_currentVisualPattern),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 패턴별 시각적 효과 위젯
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
                width: 200,
                height: 200,
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
              width: 150 + (100 * _visualFeedbackController.value),
              height: 150 + (100 * _visualFeedbackController.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: patternColor.withOpacity(0.3),
                border: Border.all(
                  color: patternColor,
                  width: 3 + (5 * _visualFeedbackController.value),
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
              width: 250,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
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
              children: List.generate(5, (index) {
                double delay = index * 0.2;
                double animationValue = (_waveAnimation.value - delay).clamp(0.0, 1.0);
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  width: 200,
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
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
                width: 180,
                height: 180,
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
            double size = 100 + (150 * _visualFeedbackController.value);
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
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pulseController.value > 0.5 
                    ? Colors.red.withOpacity(0.8) 
                    : Colors.red.withOpacity(0.3),
              ),
            );
          },
        );
      
      case 'L3': // 질문 제안 - 물음표 형태
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: patternColor.withOpacity(0.6 * _scaleAnimation.value),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: patternColor.withOpacity(0.8 * _scaleAnimation.value),
                  ),
                ),
              ],
            );
          },
        );
      
      default:
        return Container();
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

  @override
  void dispose() {
    _visualFeedbackController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }
} 