import 'package:flutter/material.dart';

class WorkflowDetailScreen extends StatelessWidget {
  final String workflowId;

  const WorkflowDetailScreen({super.key, required this.workflowId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflow Details'),
      ),
      body: const Center(
        child: Text('Workflow Detail Screen'),
      ),
    );
  }
}