// lib/core/constants/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/onboarding/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/listing/listing_create_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/favorites_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',          builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/home',       builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/listing',    builder: (_, __) => const PostListingScreen()),
    GoRoute(path: '/profile',    builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/login',      builder: (_, __) => const _PlaceholderScreen(title: 'Đăng nhập')),
    GoRoute(path: '/register',   builder: (_, __) => const _PlaceholderScreen(title: 'Đăng ký')),
    GoRoute(path: '/favorites',  builder: (_, __) => const FavoritesScreen()),
    GoRoute(path: '/chat',       builder: (_, __) => const _PlaceholderScreen(title: 'Tin nhắn')),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0057D9),
      body: Center(
        child: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}