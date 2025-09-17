import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_router.dart';
import '../../utils/responsive_breakpoints.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/main_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signUp(
        _emailController.text.trim(),
        _nameController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        context.go(AppRouter.home);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please check that email authentication is enabled in your Supabase project.'),
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
      child: ResponsiveLayout(
        mobile: _MobileRegisterLayout(
          formKey: _formKey,
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          obscurePassword: _obscurePassword,
          obscureConfirmPassword: _obscureConfirmPassword,
          onObscureToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onConfirmObscureToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          onSignUp: _signUp,
        ),
        tablet: _TabletRegisterLayout(
          formKey: _formKey,
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          obscurePassword: _obscurePassword,
          obscureConfirmPassword: _obscureConfirmPassword,
          onObscureToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onConfirmObscureToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          onSignUp: _signUp,
        ),
        desktop: _DesktopRegisterLayout(
          formKey: _formKey,
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          obscurePassword: _obscurePassword,
          obscureConfirmPassword: _obscureConfirmPassword,
          onObscureToggle: () => setState(() => _obscurePassword = !_obscurePassword),
          onConfirmObscureToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          onSignUp: _signUp,
        ),
      ),
    );
  }
}

class _MobileRegisterLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onObscureToggle;
  final VoidCallback onConfirmObscureToggle;
  final VoidCallback onSignUp;

  const _MobileRegisterLayout({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onObscureToggle,
    required this.onConfirmObscureToggle,
    required this.onSignUp,
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
              _RegisterHeader(),
              const ResponsiveSpacing(mobile: 48),
              _RegisterForm(
                nameController: nameController,
                emailController: emailController,
                passwordController: passwordController,
                confirmPasswordController: confirmPasswordController,
                obscurePassword: obscurePassword,
                obscureConfirmPassword: obscureConfirmPassword,
                onObscureToggle: onObscureToggle,
                onConfirmObscureToggle: onConfirmObscureToggle,
              ),
              const ResponsiveSpacing(mobile: 24),
              _RegisterActions(onSignUp: onSignUp),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletRegisterLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onObscureToggle;
  final VoidCallback onConfirmObscureToggle;
  final VoidCallback onSignUp;

  const _TabletRegisterLayout({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onObscureToggle,
    required this.onConfirmObscureToggle,
    required this.onSignUp,
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
                _RegisterHeader(),
                const ResponsiveSpacing(mobile: 32),
                _RegisterForm(
                  nameController: nameController,
                  emailController: emailController,
                  passwordController: passwordController,
                  confirmPasswordController: confirmPasswordController,
                  obscurePassword: obscurePassword,
                  obscureConfirmPassword: obscureConfirmPassword,
                  onObscureToggle: onObscureToggle,
                  onConfirmObscureToggle: onConfirmObscureToggle,
                ),
                const ResponsiveSpacing(mobile: 24),
                _RegisterActions(onSignUp: onSignUp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopRegisterLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onObscureToggle;
  final VoidCallback onConfirmObscureToggle;
  final VoidCallback onSignUp;

  const _DesktopRegisterLayout({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onObscureToggle,
    required this.onConfirmObscureToggle,
    required this.onSignUp,
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
                    'Create your account to start managing\\nyour organizations and workflows',
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
        // Right side - Register form
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
                        'Create Account',
                        baseFontSize: 28,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join us and start managing your business',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      _RegisterForm(
                        nameController: nameController,
                        emailController: emailController,
                        passwordController: passwordController,
                        confirmPasswordController: confirmPasswordController,
                        obscurePassword: obscurePassword,
                        obscureConfirmPassword: obscureConfirmPassword,
                        onObscureToggle: onObscureToggle,
                        onConfirmObscureToggle: onConfirmObscureToggle,
                      ),
                      const SizedBox(height: 32),
                      _RegisterActions(onSignUp: onSignUp),
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

class _RegisterHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.person_add,
          size: ResponsiveBreakpoints.getFontSize(context, mobile: 80, tablet: 96, desktop: 112),
          color: Theme.of(context).primaryColor,
        ),
        const ResponsiveSpacing(mobile: 24),
        ResponsiveText(
          'Join Organization Manager',
          baseFontSize: 28,
          tabletFontSize: 32,
          desktopFontSize: 36,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const ResponsiveSpacing(mobile: 8),
        ResponsiveText(
          'Create an account to manage your organizations and workflows',
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

class _RegisterForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onObscureToggle;
  final VoidCallback onConfirmObscureToggle;

  const _RegisterForm({
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onObscureToggle,
    required this.onConfirmObscureToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameController,
          keyboardType: TextInputType.name,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        const ResponsiveSpacing(mobile: 16),
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
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const ResponsiveSpacing(mobile: 16),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: onConfirmObscureToggle,
            ),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password';
            }
            if (value != passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _RegisterActions extends StatelessWidget {
  final VoidCallback onSignUp;

  const _RegisterActions({required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return ElevatedButton(
              onPressed: authProvider.isLoading ? null : onSignUp,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 18, desktop: 20),
                ),
              ),
              child: authProvider.isLoading
                  ? const CircularProgressIndicator()
                  : ResponsiveText(
                      'Create Account',
                      baseFontSize: 16,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            );
          },
        ),
        const ResponsiveSpacing(mobile: 16),
        TextButton(
          onPressed: () => context.go(AppRouter.login),
          child: const ResponsiveText(
            'Already have an account? Sign In',
            baseFontSize: 14,
          ),
        ),
      ],
    );
  }
}