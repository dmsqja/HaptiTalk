import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../config/routes.dart';
import '../../services/navigation_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/stats_service.dart';
import '../../models/user/user_model.dart';
import '../../models/stats/user_stats_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? currentUser;
  UserStatsModel? userStats;
  bool isLoading = true;
  late StatsService _statsService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadUserData();
  }

  void _initializeServices() {
    try {
      // AuthService에서 사용하는 API 서비스 인스턴스를 재사용
      final authService = AuthService();
      _statsService = StatsService(authService.apiService);
    } catch (e) {
      print('❌ 서비스 초기화 실패: $e');
      // 실패 시 기본 API 서비스로 폴백
      final apiService = ApiService.create();
      _statsService = StatsService(apiService);
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => isLoading = true);
      
      // AuthService에서 현재 사용자 정보 가져오기
      final authService = AuthService();
      currentUser = authService.currentUser;
      
      // 만약 사용자 정보가 없다면 프로필을 다시 가져오기 시도
      if (currentUser == null) {
        print('🔄 사용자 정보 없음, 프로필 재조회 시도');
        await authService.checkAutoLogin();
        currentUser = authService.currentUser;
      }
      
      print('✅ 프로필 화면 - 사용자 정보: ${currentUser?.name} (${currentUser?.email})');
      
      // 통계 데이터 로드
      await _loadStatsData();
      
    } catch (e) {
      print('❌ 사용자 정보 로드 실패: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadStatsData() async {
    try {
      print('📊 통계 데이터 로드 시작...');
      userStats = await _statsService.getUserStats();
      
      if (userStats != null) {
        print('✅ 통계 데이터 로드 성공: $userStats');
      } else {
        print('⚠️ 통계 데이터 로드 실패, 기본값 사용');
        userStats = UserStatsModel.empty();
      }
    } catch (e) {
      print('❌ 통계 데이터 로드 중 오류: $e');
      userStats = UserStatsModel.empty();
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
          '프로필',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                // 프로필 정보 섹션
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 프로필 이미지
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.lightGrayColor,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: currentUser?.profileImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.network(
                                  currentUser!.profileImage!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(width: 20),

                      // 사용자 정보 및 편집 버튼
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?.name ?? '사용자',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              currentUser?.email ?? '이메일 없음',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () {
                                // 프로필 편집 기능
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGrayColor,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.primaryColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '프로필 편집',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 구독 정보 섹션
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '구독 정보',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '프리미엄',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.lightGrayColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.black,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'HaptiTalk 프리미엄',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '모든 기능과 분석을 제한 없이 이용할 수 있습니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              '2025년 12월 31일까지',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () {
                            NavigationService.navigateTo(AppRoutes.subscription);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '구독 관리',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 나의 통계 섹션
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '나의 통계',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 총 세션 수
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  userStats?.totalSessions.toString() ?? '0',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '총 세션 수',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 총 대화 시간
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  userStats?.totalConversationTime ?? '0:00',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '총 대화 시간',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 평균 호감도
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${userStats?.averageLikeability.toStringAsFixed(0) ?? '0'}%',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '평균 호감도',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '커뮤니케이션 실력 향상도',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textColor,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.dividerColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: userStats?.communicationImprovement ?? 0.0,
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CAF50),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              // 통계 상세 보기
                              NavigationService.navigateTo(AppRoutes.statisticsDetail);
                            },
                            child: Text(
                              '보기',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 설정 메뉴 섹션
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _buildSettingItem(
                        icon: Icons.help_outline,
                        title: '도움말 및 지원',
                        onTap: () {
                          // 도움말 및 지원으로 이동
                          NavigationService.navigateTo(AppRoutes.helpSupport);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.logout_outlined,
                          color: Color(0xFFF44336),
                        ),
                        title: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFF44336),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        onTap: () {
                          // 로그아웃 기능
                          _showLogoutDialog(context);
                        },
                      ),
                      const SizedBox(height: 50), // 하단 여백
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 18,
        color: Colors.black45,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                '로그아웃',
                style: TextStyle(color: AppColors.errorColor),
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                
                try {
                  // 실제 로그아웃 로직 구현
                  await AuthService().logout();
                  print('✅ 로그아웃 완료');
                  
                  // 로그인 화면으로 이동
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login, 
                      (route) => false
                    );
                  }
                } catch (e) {
                  print('❌ 로그아웃 실패: $e');
                  
                  // 오류 발생 시에도 로그인 화면으로 이동 (안전장치)
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login, 
                      (route) => false
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
