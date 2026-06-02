import 'package:flutter/material.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tin đăng của tôi')),
      body: const Center(child: Text('Danh sách tin đăng của tôi')),
    );
  }
}
