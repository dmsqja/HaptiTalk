import 'package:flutter/material.dart';
import 'package:haptitalk/screens/auth/login_screen.dart';
import 'package:haptitalk/screens/auth/signup_screen.dart';
import 'package:haptitalk/screens/main/main_tab_screen.dart';
// import 'package:haptitalk/screens/onboarding/onboarding_screen.dart';
import 'package:haptitalk/screens/session/new_session_screen.dart';
// import 'package:haptitalk/screens/session/session_details_screen.dart';
import 'package:haptitalk/screens/analysis/realtime_analysis_screen.dart';
// import 'package:haptitalk/screens/analysis/analysis_summary_screen.dart';
import 'package:haptitalk/screens/history/history_screen.dart';
// import 'package:haptitalk/screens/profile/profile_screen.dart';
import 'package:haptitalk/screens/profile/settings_screen.dart';
import 'package:haptitalk/screens/profile/subscription_screen.dart';
import 'package:haptitalk/screens/profile/statistics_detail_screen.dart';
import 'package:haptitalk/screens/profile/help_support_screen.dart';
import 'package:haptitalk/screens/debug/watch_debug_screen.dart';
import 'package:haptitalk/screens/practice/haptic_practice_screen.dart';

class AppRoutes {
  // 라우트 이름 정의
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String newSession = '/session/new';
  static const String sessionDetails = '/session/details';
  static const String realtimeAnalysis = '/analysis/realtime';
  static const String analysisSummary = '/analysis/summary';
  static const String sessionsHistory = '/history';
  static const String profile = '/profile';
  static const String settings = '/profile/settings';
  static const String subscription = '/profile/subscription';
  static const String statisticsDetail = '/profile/statistics';
  static const String helpSupport = '/profile/help';
  static const String watchDebug = '/watch-debug';
  static const String hapticPractice = '/practice/haptic';

  // 라우트 생성 함수
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      signup: (context) => const SignUpScreen(),
      main: (context) => const MainTabScreen(),
      // onboarding: (context) => const OnboardingScreen(),
      newSession: (context) => const NewSessionScreen(),
      // sessionDetails: (context) => const SessionDetailsScreen(),
      realtimeAnalysis: (context) {
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final sessionId = args?['sessionId'] ?? 'default_session_id';
        return RealtimeAnalysisScreen(sessionId: sessionId);
      },
      // analysisSummary: (context) => const AnalysisSummaryScreen(),
      sessionsHistory: (context) => const HistoryScreen(),
      // profile: (context) => const ProfileScreen(),
      settings: (context) => const SettingsScreen(),
      subscription: (context) => const SubscriptionScreen(),
      statisticsDetail: (context) => const StatisticsDetailScreen(),
      helpSupport: (context) => const HelpSupportScreen(),
      watchDebug: (context) => const WatchDebugScreen(),
      hapticPractice: (context) => const HapticPracticeScreen(),
    };
  }
}
