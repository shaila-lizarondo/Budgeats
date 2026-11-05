import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'backend/local_database.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';

class StudentBudgetMealPlanApp extends StatelessWidget {
  const StudentBudgetMealPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<LocalDatabase>();
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final user = db.currentUser;
    final showGetStarted =
        isLoggedIn && user != null && user.hasSeenGetStarted == false;

    String initialRoute;
    if (!isLoggedIn) {
      initialRoute = AppRoutes.welcome;
    } else if (showGetStarted) {
      initialRoute = AppRoutes.getStarted;
    } else {
      initialRoute = AppRoutes.mainShell;
    }

    return MaterialApp(
      title: 'Budgeats',
      debugShowCheckedModeBanner: false,
      themeMode: db.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.buildTheme(
        brightness: Brightness.light,
        paletteIndex: db.paletteIndex,
      ),
      darkTheme: AppTheme.buildTheme(
        brightness: Brightness.dark,
        paletteIndex: db.paletteIndex,
      ),
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        final pageBuilder = AppRoutes.routes[settings.name];
        if (pageBuilder == null) return null;

        return PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              pageBuilder(context),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.025, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}
