import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  child: user.profileImageUrl != null
                      ? ClipOval(child: Image.network(user.profileImageUrl!))
                      : Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 32)),
                ),
                const SizedBox(height: 16),
                Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
                Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await authProvider.signOut();
                    if (context.mounted) {
                      context.go(AppRouter.login);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}