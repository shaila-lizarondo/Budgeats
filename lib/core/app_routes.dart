import 'package:flutter/material.dart';

import '../frontend/screens/budget_screen.dart';
import '../frontend/screens/calendar_screen.dart';
import '../frontend/screens/edit_profile_screen.dart';
import '../frontend/screens/expense_form_screen.dart';
import '../frontend/screens/forgot_password_screen.dart';
import '../frontend/screens/full_summary_screen.dart';
import '../frontend/screens/get_started_screen.dart';
import '../frontend/screens/grocery_screen.dart';
import '../frontend/screens/home_screen.dart';
import '../frontend/screens/login_screen.dart';
import '../frontend/screens/main_shell.dart';
import '../frontend/screens/meal_form_screen.dart';
import '../frontend/screens/meal_plan_screen.dart';
import '../frontend/screens/profile_screen.dart';
import '../frontend/screens/saved_meals_screen.dart';
import '../frontend/screens/signup_screen.dart';
import '../frontend/screens/welcome_screen.dart';

class AppRoutes {
  static const welcome = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const getStarted = '/get-started';
  static const editProfile = '/edit-profile';
  static const mainShell = '/main';
  static const home = '/home';
  static const calendar = '/calendar';
  static const mealPlan = '/meal-plan';
  static const grocery = '/grocery';
  static const budget = '/budget';
  static const profile = '/profile';
  static const savedMeals = '/saved-meals';
  static const fullSummary = '/full-summary';
  static const mealForm = '/meal-form';
  static const expenseForm = '/expense-form';

  static Map<String, WidgetBuilder> get routes => {
    welcome: (_) => const WelcomeScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignUpScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    getStarted: (_) => const GetStartedScreen(),
    editProfile: (_) => const EditProfileScreen(),
    mainShell: (_) => const MainShell(),
    home: (_) => const HomeScreen(),
    calendar: (_) => const CalendarScreen(),
    mealPlan: (_) => const MealPlanScreen(),
    grocery: (_) => const GroceryScreen(),
    budget: (_) => const BudgetScreen(),
    profile: (_) => const ProfileScreen(),
    savedMeals: (_) => const SavedMealsScreen(),
    fullSummary: (_) => const FullSummaryScreen(),
    mealForm: (_) => const MealFormScreen(),
    expenseForm: (_) => const ExpenseFormScreen(),
  };
}
