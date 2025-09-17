import 'package:flutter/material.dart';

class OrganizationDetailScreen extends StatelessWidget {
  final String organizationId;

  const OrganizationDetailScreen({super.key, required this.organizationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Details'),
      ),
      body: const Center(
        child: Text('Organization Detail Screen'),
      ),
    );
  }
}