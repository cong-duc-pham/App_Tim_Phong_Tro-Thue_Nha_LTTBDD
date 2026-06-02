import 'package:flutter/material.dart';

class ListingDetailScreen extends StatelessWidget {
  final String id;
  const ListingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết tin đăng')),
      body: Center(child: Text('Chi tiết tin đăng ID: $id')),
    );
  }
}
