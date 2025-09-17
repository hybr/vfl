import 'package:flutter/material.dart';

class RentalDetailScreen extends StatelessWidget {
  final String rentalId;

  const RentalDetailScreen({super.key, required this.rentalId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Details'),
      ),
      body: const Center(
        child: Text('Rental Detail Screen'),
      ),
    );
  }
}