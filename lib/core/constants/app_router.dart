// lib/core/constants/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/onboarding/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/onboarding/preference_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/listing/listing_create_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/favorites_screen.dart';
import '../../screens/profile/about_app_screen.dart';
import '../../screens/profile/report_issue_screen.dart';
import '../../screens/profile/support_center_screen.dart';
import '../../screens/profile/search_history_screen.dart';
import '../../screens/profile/my_reviews_screen.dart';
import '../../screens/profile/verification_screen.dart';
import '../../screens/profile/change_password_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../models/conversation.dart';
import '../../screens/chat/conversations_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../widgets/main_bottom_nav.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',          builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(
      path: '/preferences',
      builder: (context, state) {
        final from = state.uri.queryParameters['from'];
        return PreferenceScreen(from: from);
      },
    ),
    ShellRoute(
      builder: (context, state, child) {
        return Scaffold(
          body: child,
          bottomNavigationBar: const MainBottomNav(),
        );
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) {
            final query = state.uri.queryParameters['q'];
            return HomeScreen(initialSearchQuery: query);
          },
        ),
        GoRoute(path: '/listing', builder: (_, __) => const PostListingScreen()),
        GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
        GoRoute(path: '/chat', builder: (_, __) => const ConversationsScreen()),
      ],
    ),
    GoRoute(path: '/profile',    builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/login',      builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register',   builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/about',      builder: (_, __) => const AboutAppScreen()),
    GoRoute(path: '/report-issue', builder: (_, __) => const ReportIssueScreen()),
    GoRoute(path: '/support-center', builder: (_, __) => const SupportCenterScreen()),
    GoRoute(path: '/search-history', builder: (_, __) => const SearchHistoryScreen()),
    GoRoute(path: '/my-reviews', builder: (_, __) => const MyReviewsScreen()),
    GoRoute(path: '/verify-account', builder: (_, __) => const AccountVerificationScreen()),
    GoRoute(path: '/change-password', builder: (_, __) => const ChangePasswordScreen()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(
      path: '/chat/detail',
      builder: (context, state) {
        final conv = state.extra as Conversation;
        return ChatScreen(conversation: conv);
      },
    ),
  ],
);
