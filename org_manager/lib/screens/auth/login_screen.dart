import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_router.dart';
import '../../utils/responsive_breakpoints.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        context.go(AppRouter.home);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Check your credentials or ensure your Supabase project is properly configured.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      showNavigation: false,
      showAppBar: false,
      child: ResponsiveLayout(
        mobile: _MobileLoginLayout(
          formKey: _formKey,
          emailController: _emailController,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          onObscureToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onSignIn: _signIn,
        ),
        tablet: _TabletLoginLayout(
          formKey: _formKey,
          emailController: _emailController,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          onObscureToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onSignIn: _signIn,
        ),
        desktop: _DesktopLoginLayout(
          formKey: _formKey,
          emailController: _emailController,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          onObscureToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onSignIn: _signIn,
        ),
      ),
    );
  }
}

class _MobileLoginLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onObscureToggle;
  final VoidCallback onSignIn;

  const _MobileLoginLayout({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onObscureToggle,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: ResponsiveHelper.getContentPadding(context),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LoginHeader(),
              const ResponsiveSpacing(mobile: 48),
              _LoginForm(
                emailController: emailController,
                passwordController: passwordController,
                obscurePassword: obscurePassword,
                onObscureToggle: onObscureToggle,
              ),
              const ResponsiveSpacing(mobile: 24),
              _LoginActions(onSignIn: onSignIn),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletLoginLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onObscureToggle;
  final VoidCallback onSignIn;

  const _TabletLoginLayout({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onObscureToggle,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ResponsiveCard(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LoginHeader(),
                const ResponsiveSpacing(mobile: 32),
                _LoginForm(
                  emailController: emailController,
                  passwordController: passwordController,
                  obscurePassword: obscurePassword,
                  onObscureToggle: onObscureToggle,
                ),
                const ResponsiveSpacing(mobile: 24),
                _LoginActions(onSignIn: onSignIn),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopLoginLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onObscureToggle;
  final VoidCallback onSignIn;

  const _DesktopLoginLayout({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onObscureToggle,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left side - Branding
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_center,
                    size: 120,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 24),
                  ResponsiveText(
                    'Organization Manager',
                    baseFontSize: 32,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ResponsiveText(
                    'Streamline your business operations\nwith powerful workflow management',
                    baseFontSize: 16,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side - Login form
        Expanded(
          flex: 2,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ResponsiveText(
                        'Welcome Back',
                        baseFontSize: 28,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your account',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      _LoginForm(
                        emailController: emailController,
                        passwordController: passwordController,
                        obscurePassword: obscurePassword,
                        onObscureToggle: onObscureToggle,
                      ),
                      const SizedBox(height: 32),
                      _LoginActions(onSignIn: onSignIn),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.business,
          size: ResponsiveBreakpoints.getFontSize(context, mobile: 80, tablet: 96, desktop: 112),
          color: Theme.of(context).primaryColor,
        ),
        const ResponsiveSpacing(mobile: 24),
        ResponsiveText(
          'Organization Manager',
          baseFontSize: 28,
          tabletFontSize: 32,
          desktopFontSize: 36,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const ResponsiveSpacing(mobile: 8),
        ResponsiveText(
          'Manage your organizations, workflows, and business',
          baseFontSize: 16,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onObscureToggle;

  const _LoginForm({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onObscureToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const ResponsiveSpacing(mobile: 16),
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: onObscureToggle,
            ),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _LoginActions extends StatelessWidget {
  final VoidCallback onSignIn;

  const _LoginActions({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return ElevatedButton(
              onPressed: authProvider.isLoading ? null : onSignIn,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 18, desktop: 20),
                ),
              ),
              child: authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : ResponsiveText(
                      'Sign In',
                      baseFontSize: 16,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            );
          },
        ),
        const ResponsiveSpacing(mobile: 16),
        TextButton(
          onPressed: () => context.go(AppRouter.register),
          child: const ResponsiveText(
            'Don\'t have an account? Sign Up',
            baseFontSize: 14,
          ),
        ),
      ],
    );
  }
}