import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../../core/app_routes.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/primary_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final budget = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  Future<void> submit() async {
    if (isLoading) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final startingBudget = double.tryParse(budget.text.trim()) ?? 0.0;
    final error = await context.read<LocalDatabase>().signUp(
          email.text.trim(),
          password.text,
          name.text.trim(),
          startingBudget,
        );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (error != null) {
      final isAlreadyRegistered = error.contains('already has an account');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
          action: isAlreadyRegistered
              ? SnackBarAction(
                  label: 'Log in',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.login);
                  },
                )
              : null,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created successfully! Welcome to Budgeats.'),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.getStarted,
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
      appBar: AppBar(title: const Text('Sign Up')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: name,
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: email,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'user@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: LocalDatabase.validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: password,
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
              validator: LocalDatabase.validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmPassword,
              enabled: !isLoading,
              obscureText: hidePassword,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_clock_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your password';
                }
                if (value != password.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: budget,
              enabled: !isLoading,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Starting weekly budget (optional)',
                prefixText: '₱ ',
                prefixIcon: Icon(Icons.savings_outlined),
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Create Account',
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
                const Text('Already have an account? '),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pushNamed(context, AppRoutes.login),
                  child: const Text('Log In'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
