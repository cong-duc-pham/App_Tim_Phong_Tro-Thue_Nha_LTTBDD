// lib/main.dart

import 'package:flutter/material.dart';
import 'core/constants/app_router.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Swings House',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0057D9),
        ),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}