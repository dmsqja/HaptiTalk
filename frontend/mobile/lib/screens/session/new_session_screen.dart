import 'package:flutter/material.dart';
import 'package:haptitalk/constants/colors.dart';
import 'package:haptitalk/config/routes.dart';
import 'package:haptitalk/services/navigation_service.dart';
import 'package:haptitalk/services/watch_service.dart';
import 'package:haptitalk/widgets/common/buttons/primary_button.dart';
import 'package:uuid/uuid.dart';

class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  // 선택된 세션 모드 (기본값: 발표)
  String _selectedSessionMode = '발표';

  // 세션 모드 목록과 설명
  final Map<String, String> _sessionModes = {
    '발표': '설득력과 전달력 분석',
    '소개팅': '호감도와 대화 주제 분석',
    '면접(인터뷰)': '자신감과 명확성 분석',
  };

  // 분석 수준 선택
  String _selectedAnalysisLevel = '표준';
  final List<String> _analysisLevels = ['기본', '표준', '고급'];

  // 녹음 저장 선택
  String _selectedRecordingOption = '7일';
  final List<Map<String, dynamic>> _recordingOptions = [
    {'label': '저장 안함', 'subLabel': ''},
    {'label': '7일', 'subLabel': '자동 삭제'},
    {'label': '30일', 'subLabel': '자동 삭제'},
  ];

  // 세션 이름 컨트롤러
  final TextEditingController _sessionNameController = TextEditingController();

  // 스마트워치 연결 상태
  bool _isWatchConnected = true;
  String _connectedWatchName = 'Apple Watch';

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textColor),
          onPressed: () => NavigationService.goBack(),
        ),
        title: const Text(
          '새 세션 시작',
          style: TextStyle(
            color: AppColors.textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 제목
                const Text(
                  '새로운 세션 시작하기',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '세션 모드와 설정을 선택하세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 30),

                // 세션 모드 선택
                const Text(
                  '세션 모드',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 15),

                // 세션 모드 카드 그리드
                _buildSessionModeGrid(),
                const SizedBox(height: 30),

                // 세션 이름 입력
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '세션 이름 (선택사항)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF424242),
                      ),
                    ),
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sessionNameController,
                  decoration: InputDecoration(
                    hintText: '나중에 쉽게 찾을 수 있는 이름',
                    hintStyle: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 분석 수준 선택
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '분석 수준',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF424242),
                      ),
                    ),
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAnalysisLevelSelector(),
                const SizedBox(height: 20),

                // 녹음 저장 선택
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '녹음 저장',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF424242),
                      ),
                    ),
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRecordingOptionSelector(),
                const SizedBox(height: 20),

                // 스마트워치 연결 정보
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.watch,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '스마트워치',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF424242),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isWatchConnected
                                        ? const Color(0xFF4CAF50)
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isWatchConnected
                                      ? '연결됨 ($_connectedWatchName)'
                                      : '연결되지 않음',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _isWatchConnected
                                        ? const Color(0xFF4CAF50)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          // 스마트워치 관리 화면으로 이동
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryColor,
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          minimumSize: const Size(58, 36),
                        ),
                        child: const Text('관리'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 시작 버튼
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      // UUID 생성
                      final uuid = Uuid();
                      final sessionId = uuid.v4();

                      // Watch에 세션 시작 알림
                      await WatchService().startSession(_selectedSessionMode);

                      // 실시간 분석 화면으로 이동
                      NavigationService.navigateTo(
                        AppRoutes.realtimeAnalysis,
                        arguments: {
                          'sessionId': sessionId,
                          'sessionName': _sessionNameController.text.isEmpty
                              ? '세션 - $_selectedSessionMode'
                              : _sessionNameController.text,
                          'sessionType': _selectedSessionMode,
                          'analysisLevel': _selectedAnalysisLevel,
                          'recordingOption': _selectedRecordingOption,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '세션 시작하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 세션 모드 그리드 위젯
  Widget _buildSessionModeGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.0,
      children: _sessionModes.entries.map((entry) {
        final isSelected = entry.key == _selectedSessionMode;
        // 🔥 소개팅과 면접 모드는 준비 중 상태
        final isDisabled = entry.key == '소개팅' || entry.key == '면접(인터뷰)';
        
        return GestureDetector(
          onTap: () {
            if (isDisabled) {
              // 준비 중 다이얼로그 표시
              _showComingSoonDialog(entry.key);
            } else {
              setState(() {
                _selectedSessionMode = entry.key;
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDisabled 
                  ? Colors.grey[100] 
                  : (isSelected
                      ? AppColors.primaryColor.withOpacity(0.1)
                      : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(16),
              border: isSelected 
                  ? Border.all(color: AppColors.primaryColor) 
                  : (isDisabled 
                      ? Border.all(color: Colors.grey[300]!) 
                      : null),
            ),
            child: Stack(
              children: [
                // 메인 콘텐츠를 전체 영역에 맞춤
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconForSessionMode(entry.key),
                          color: isDisabled 
                              ? Colors.grey[400] 
                              : AppColors.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDisabled 
                              ? Colors.grey[500] 
                              : const Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          isDisabled ? '준비 중' : entry.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDisabled 
                                ? Colors.grey[500] 
                                : const Color(0xFF757575),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 준비 중 배지
                if (isDisabled)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SOON',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 분석 수준 선택 위젯
  Widget _buildAnalysisLevelSelector() {
    return Row(
      children: _analysisLevels.map((level) {
        final isSelected = level == _selectedAnalysisLevel;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedAnalysisLevel = level;
              });
            },
            child: Container(
              height: 50,
              margin: EdgeInsets.only(
                right: level != _analysisLevels.last ? 10 : 0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor.withOpacity(0.1)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Center(
                child: Text(
                  level,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isSelected
                        ? AppColors.primaryColor
                        : const Color(0xFF757575),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 녹음 저장 옵션 선택 위젯
  Widget _buildRecordingOptionSelector() {
    return Row(
      children: _recordingOptions.map((option) {
        final isSelected = option['label'] == _selectedRecordingOption;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedRecordingOption = option['label'];
              });
            },
            child: Container(
              height: 50,
              margin: EdgeInsets.only(
                right: option != _recordingOptions.last ? 10 : 0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor.withOpacity(0.1)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryColor
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    option['label'],
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isSelected
                          ? AppColors.primaryColor
                          : const Color(0xFF757575),
                    ),
                  ),
                  if (option['subLabel'].isNotEmpty)
                    Text(
                      option['subLabel'],
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? AppColors.primaryColor
                            : const Color(0xFF9E9E9E),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 세션 모드에 따른 아이콘 반환
  IconData _getIconForSessionMode(String mode) {
    switch (mode) {
      case '발표':
        return Icons.present_to_all;
      case '소개팅':
        return Icons.favorite_border;
      case '면접(인터뷰)':
        return Icons.business_center;
      case '비즈니스':
        return Icons.handshake;
      case '코칭':
        return Icons.psychology;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  void _showComingSoonDialog(String mode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.construction,
                color: Colors.orange[600],
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                '준비 중인 기능',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          content: Text(
            '$mode 모드는 현재 개발 중입니다.\n곧 만나볼 수 있도록 준비하고 있어요!',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF757575),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
