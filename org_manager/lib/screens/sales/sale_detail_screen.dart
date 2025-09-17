import 'package:flutter/material.dart';

class SaleDetailScreen extends StatelessWidget {
  final String saleId;

  const SaleDetailScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Details'),
      ),
      body: const Center(
        child: Text('Sale Detail Screen'),
      ),
    );
  }
}