import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../../core/app_routes.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  Future<void> submit() async {
    if (isLoading) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final db = context.read<LocalDatabase>();
    final error = await db.login(
      emailController.text,
      passwordController.text,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      final isNoAccountOrInvalid =
          error.contains('No account found') || error.contains('incorrect');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
          action: isNoAccountOrInvalid
              ? SnackBarAction(
                  label: 'Sign Up',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.signup);
                  },
                )
              : null,
        ),
      );
      return;
    }

    final isNewAccount = db.currentUser?.hasSeenGetStarted == false;
    final targetRoute =
        isNewAccount ? AppRoutes.getStarted : AppRoutes.mainShell;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged in successfully'),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      targetRoute,
      (route) => false,
    );
  }

  Future<void> handleGoogleSignIn() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final db = context.read<LocalDatabase>();
    final error = await db.signInWithGoogle();

    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (db.currentUser != null) {
      final isNewAccount = db.currentUser!.hasSeenGetStarted == false;
      final targetRoute =
          isNewAccount ? AppRoutes.getStarted : AppRoutes.mainShell;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed in successfully with Google'),
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        targetRoute,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'user@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: LocalDatabase.validateEmail,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: passwordController,
              enabled: !isLoading,
              obscureText: hidePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Enter your password' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Log In',
              onPressed: isLoading ? null : submit,
            ),
            GoogleSignInButton(
              onPressed: handleGoogleSignIn,
              isLoading: isLoading,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? "),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pushNamed(context, AppRoutes.signup),
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
