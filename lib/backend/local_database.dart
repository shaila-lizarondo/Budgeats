import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/budget.dart';
import '../models/expense.dart';
import '../models/grocery_item.dart';
import '../models/meal.dart';
import '../models/weekly_budget.dart';

const String _googleServerClientId =
    '795483562128-ev9bbqjt1gjo3g9gtsml8s7109alio3c.apps.googleusercontent.com';
Future<void>? _googleSignInInitialization;

class LocalDatabase extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppUser? currentUser;

  final List<Meal> meals = [];
  final List<Meal> savedMeals = [];
  final List<Expense> otherExpenses = [];
  final List<GroceryItem> groceryItems = [];
  final Map<String, WeeklyBudget> _weeklyBudgetsMap = {};
  final Map<String, double> lastPrices = {};

  double _weeklyBudget = 0.0;
  int paletteIndex = 0;
  bool isDarkMode = false;
  bool isGroceryLoading = false;

  StreamSubscription? _authSub;
  StreamSubscription? _userSub;
  StreamSubscription? _mealsSub;
  StreamSubscription? _savedMealsSub;
  StreamSubscription? _expensesSub;
  StreamSubscription? _budgetsSub;
  StreamSubscription? _grocerySub;

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static DateTime startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static DateTime endOfWeek(DateTime date) {
    final start = startOfWeek(date);
    return DateTime(start.year, start.month, start.day, 23, 59, 59, 999)
        .add(const Duration(days: 6));
  }

  static bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameWeek(DateTime a, DateTime b) {
    return isSameDate(startOfWeek(a), startOfWeek(b));
  }

  // Static validation rules
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email address';
    }
    final email = value.trim();
    final parts = email.split('@');
    if (parts.length != 2 ||
        parts[0].isEmpty ||
        parts[1].isEmpty ||
        !parts[1].contains('.')) {
      return 'Email must contain "@" with valid text before and after it';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least 1 uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least 1 number';
    }
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(value)) {
      return 'Password can only contain letters and numbers (no special symbols)';
    }
    return null;
  }

  double get weeklyBudget {
    final currentWeekId =
        DateFormat('yyyy-MM-dd').format(startOfWeek(DateTime.now()));
    if (_weeklyBudgetsMap.containsKey(currentWeekId)) {
      final weekAmt = _weeklyBudgetsMap[currentWeekId]!.amount;
      if (weekAmt > 0) return weekAmt;
    }
    return currentUser?.weeklyBudget ?? _weeklyBudget;
  }

  set weeklyBudget(double val) {
    _weeklyBudget = val;
  }

  List<WeeklyBudget> get weeklyBudgets {
    final list = _weeklyBudgetsMap.values.toList();
    list.sort((a, b) => b.startDate.compareTo(a.startDate)); // Newest first
    return list;
  }

  Future<void> initPreferences() async {
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {}

    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _setupFirestoreListeners(user.uid);
      } else {
        _clearUserData();
      }
    });
  }

  Future<void> _migrateLegacyPreferences(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyPalette = prefs.getInt('paletteIndex');
      final legacyDark = prefs.getBool('darkMode');
      await prefs.remove('welcomeBgPath');

      if (legacyPalette != null || legacyDark != null) {
        final updates = <String, dynamic>{};
        if (legacyPalette != null) updates['paletteIndex'] = legacyPalette;
        if (legacyDark != null) updates['darkMode'] = legacyDark;

        if (updates.isNotEmpty) {
          await _firestore
              .collection('users')
              .doc(uid)
              .set(updates, SetOptions(merge: true));
        }
        await prefs.clear();
      }
    } catch (e) {
      if (kDebugMode) print('Legacy migration error: $e');
    }
  }

  Future<void> _migrateLegacyGroceryItems(String uid) async {
    try {
      final legacySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('groceryItems')
          .get();

      if (legacySnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in legacySnapshot.docs) {
          final targetDoc = _firestore
              .collection('users')
              .doc(uid)
              .collection('groceries')
              .doc(doc.id);
          final data = doc.data();
          final item = GroceryItem.fromFirestore(data, doc.id);
          batch.set(targetDoc, item.toFirestore());
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) print('Legacy grocery migration error: $e');
    }
  }

  void _setupFirestoreListeners(String uid) {
    _cancelDataSubscriptions();
    _migrateLegacyPreferences(uid);
    _migrateLegacyGroceryItems(uid);

    // 1. Profile Listener
    _userSub =
        _firestore.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        currentUser = AppUser.fromFirestore(data, doc.id);
        _weeklyBudget = currentUser!.weeklyBudget;
        paletteIndex = currentUser!.paletteIndex;
        isDarkMode = currentUser!.darkMode;
        _checkAndMigrateLegacyBudget();
        notifyListeners();
      }
    }, onError: (e) {
      if (kDebugMode) print('User listener error: $e');
    });

    // 2. Meals Listener
    _mealsSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .snapshots()
        .listen((snapshot) {
      meals.clear();
      for (final doc in snapshot.docs) {
        try {
          final meal = Meal.fromFirestore(doc.data(), doc.id);
          meals.add(meal);
          for (final ingredient in meal.ingredients) {
            if (meal.price > 0) {
              lastPrices[ingredient.toLowerCase()] = meal.price;
            }
          }
        } catch (e) {
          if (kDebugMode) print('Error parsing meal ${doc.id}: $e');
        }
      }
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('Meals listener error: $e');
    });

    // 3. Saved Meals Listener
    _savedMealsSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('savedMeals')
        .snapshots()
        .listen((snapshot) {
      savedMeals.clear();
      for (final doc in snapshot.docs) {
        try {
          savedMeals.add(Meal.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          if (kDebugMode) print('Error parsing saved meal ${doc.id}: $e');
        }
      }
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('Saved meals listener error: $e');
    });

    // 4. Expenses Listener
    _expensesSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .snapshots()
        .listen((snapshot) {
      otherExpenses.clear();
      for (final doc in snapshot.docs) {
        try {
          otherExpenses.add(Expense.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          if (kDebugMode) print('Error parsing expense ${doc.id}: $e');
        }
      }
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('Expenses listener error: $e');
    });

    // 5. Budgets Listener
    _budgetsSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .snapshots()
        .listen((snapshot) {
      _weeklyBudgetsMap.clear();
      for (final doc in snapshot.docs) {
        try {
          _weeklyBudgetsMap[doc.id] =
              WeeklyBudget.fromFirestore(doc.data(), doc.id);
        } catch (e) {
          if (kDebugMode) print('Error parsing budget ${doc.id}: $e');
        }
      }
      _checkAndMigrateLegacyBudget();
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('Budgets listener error: $e');
    });

    // 6. Groceries Listener (users/{uid}/groceries)
    isGroceryLoading = true;
    _grocerySub = _firestore
        .collection('users')
        .doc(uid)
        .collection('groceries')
        .snapshots()
        .listen((snapshot) {
      groceryItems.clear();
      for (final doc in snapshot.docs) {
        try {
          final item = GroceryItem.fromFirestore(doc.data(), doc.id);
          groceryItems.add(item);
          if (item.price > 0) {
            lastPrices[item.name.toLowerCase()] = item.price;
          }
        } catch (e) {
          if (kDebugMode) print('Error parsing grocery item ${doc.id}: $e');
        }
      }
      isGroceryLoading = false;
      notifyListeners();
    }, onError: (e) {
      isGroceryLoading = false;
      if (kDebugMode) print('Groceries listener error: $e');
      notifyListeners();
    });
  }

  void _checkAndMigrateLegacyBudget() {
    final currentWeekId =
        DateFormat('yyyy-MM-dd').format(startOfWeek(DateTime.now()));
    if (!_weeklyBudgetsMap.containsKey(currentWeekId) &&
        (currentUser?.weeklyBudget ?? 0) > 0) {
      saveWeeklyBudget(currentUser!.weeklyBudget);
    }
  }

  void _cancelDataSubscriptions() {
    _userSub?.cancel();
    _mealsSub?.cancel();
    _savedMealsSub?.cancel();
    _expensesSub?.cancel();
    _budgetsSub?.cancel();
    _grocerySub?.cancel();

    _userSub = null;
    _mealsSub = null;
    _savedMealsSub = null;
    _expensesSub = null;
    _budgetsSub = null;
    _grocerySub = null;
  }

  void _clearUserData() {
    _cancelDataSubscriptions();
    currentUser = null;
    meals.clear();
    savedMeals.clear();
    otherExpenses.clear();
    groceryItems.clear();
    _weeklyBudgetsMap.clear();
    lastPrices.clear();
    _weeklyBudget = 0.0;
    paletteIndex = 0;
    isDarkMode = false;
    isGroceryLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDataSubscriptions();
    super.dispose();
  }

  // --- Auth Methods ---
  Future<String?> signUp(
    String email,
    String password,
    String name,
    double startingBudget,
  ) async {
    if (name.trim().isEmpty) {
      return 'Enter your full name';
    }

    final emailError = validateEmail(email);
    if (emailError != null) return emailError;

    final passwordError = validatePassword(password);
    if (passwordError != null) return passwordError;

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        return 'Account creation failed. Please try again.';
      }

      try {
        await user.updateDisplayName(name.trim());
      } catch (_) {}

      final appUser = AppUser(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
        provider: 'email',
        weeklyBudget: startingBudget,
        darkMode: isDarkMode,
        paletteIndex: paletteIndex,
        hasSeenGetStarted: false,
        createdAt: DateTime.now(),
      );

      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(appUser.toFirestore());

        if (startingBudget > 0) {
          await saveWeeklyBudget(startingBudget);
        }
      } catch (firestoreError) {
        try {
          await user.delete();
        } catch (_) {}
        return 'Failed to save user account. Please check your network or database connection.';
      }

      // Do not sign out! Keep user signed in for Get Started page
      currentUser = appUser;
      _setupFirestoreListeners(user.uid);
      notifyListeners();

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapSignUpAuthException(e);
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<String?> login(String email, String password) async {
    final emailError = validateEmail(email);
    if (emailError != null) return emailError;

    if (password.isEmpty) {
      return 'Enter your password';
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = cred.user;
      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        try {
          final doc = await docRef.get();
          if (!doc.exists) {
            final appUser = AppUser(
              uid: user.uid,
              name: user.displayName ?? email.split('@').first,
              email: user.email ?? email,
              provider: 'email',
              weeklyBudget: 0.0,
              darkMode: isDarkMode,
              paletteIndex: paletteIndex,
              hasSeenGetStarted: true,
              createdAt: DateTime.now(),
            );
            await docRef.set(appUser.toFirestore());
          }
        } catch (e) {
          if (kDebugMode) print('Profile check/creation error: $e');
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapLoginAuthException(e);
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<String?> signInWithGoogle() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return 'Google sign-in is available on Android and web. Please use email and password on Windows.';
    }

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
          serverClientId: defaultTargetPlatform == TargetPlatform.android
              ? _googleServerClientId
              : null,
        );
        await _googleSignInInitialization;
        final GoogleSignInAccount googleAccount =
            await GoogleSignIn.instance.authenticate();

        final GoogleSignInAuthentication googleAuth =
            googleAccount.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null) {
        final docRef = _firestore.collection('users').doc(user.uid);
        final doc = await docRef.get();

        if (!doc.exists) {
          final appUser = AppUser(
            uid: user.uid,
            name: user.displayName ??
                (user.email != null ? user.email!.split('@').first : 'User'),
            email: user.email ?? '',
            photoUrl: user.photoURL,
            provider: 'google',
            weeklyBudget: 0.0,
            darkMode: isDarkMode,
            paletteIndex: paletteIndex,
            hasSeenGetStarted: false,
            createdAt: DateTime.now(),
          );
          await docRef.set(appUser.toFirestore());
        }
      }

      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'Google Sign-In FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'account-exists-with-different-credential') {
        return 'This email already has an account. Log in with your password first.';
      }
      return _cleanErrorMessage(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('serverclientid must be provided')) {
        return 'Google Sign-In is not configured for Android. Add the Web OAuth client to Firebase, then download and replace android/app/google-services.json.';
      }
      if (errStr.contains('canceled') ||
          errStr.contains('cancelled') ||
          errStr.contains('popup_closed') ||
          errStr.contains('popup_blocked')) {
        return null;
      }
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<void> completeGetStarted() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (currentUser != null) {
      currentUser = currentUser!.copyWith(hasSeenGetStarted: true);
    }
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'hasSeenGetStarted': true}, SetOptions(merge: true));
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String? base64Photo) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (currentUser != null) {
      currentUser = currentUser!.copyWith(photoBase64: base64Photo);
    }
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'photoBase64': base64Photo}, SetOptions(merge: true));
    notifyListeners();
  }

  Future<String?> updateName(String newName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'Not logged in';
    final clean = newName.trim();
    if (clean.isEmpty) return 'Enter your name.';

    try {
      await _auth.currentUser?.updateDisplayName(clean);
      if (currentUser != null) {
        currentUser = currentUser!.copyWith(name: clean);
      }
      await _firestore
          .collection('users')
          .doc(uid)
          .set({'name': clean}, SetOptions(merge: true));
      notifyListeners();
      return null;
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<String?> updateEmailAndAuth({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'Not logged in';

    final emailErr = validateEmail(newEmail);
    if (emailErr != null) return emailErr;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapReauthAuthException(e);
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<String?> updatePasswordAuth({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'Not logged in';

    if (currentPassword == newPassword) {
      return 'New password cannot be the same as current password.';
    }

    final pwdErr = validatePassword(newPassword);
    if (pwdErr != null) return pwdErr;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapReauthAuthException(e);
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  String _mapReauthAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Current password is incorrect.';
      case 'requires-recent-login':
        return 'Please log out and log in again before changing these settings.';
      case 'email-already-in-use':
        return 'This email is already in use by another account.';
      case 'weak-password':
        return 'The new password provided is too weak.';
      case 'invalid-email':
        return 'Invalid email format.';
      default:
        return _cleanErrorMessage(e.message ?? 'Update failed.');
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    final emailError = validateEmail(email);
    if (emailError != null) return emailError;

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapResetPasswordAuthException(e);
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    try {
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    _clearUserData();
  }

  String _mapLoginAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'No account found, or the password is incorrect. Please check your details or sign up.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase Console. Please enable it under Authentication > Sign-in method.';
      default:
        return _cleanErrorMessage(
            e.message ?? 'Login failed. Please try again.');
    }
  }

  String _mapSignUpAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email already has an account. Please log in.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in Firebase Console. Please enable it under Authentication > Sign-in method.';
      default:
        return _cleanErrorMessage(
            e.message ?? 'Sign up failed. Please try again.');
    }
  }

  String _mapResetPasswordAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'No account found with this email.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return _cleanErrorMessage(e.message ?? 'Failed to send reset email.');
    }
  }

  String _cleanErrorMessage(String raw) {
    if (raw.contains('permission-denied')) {
      return 'Database permission denied. Ensure Security Rules are published in Firebase Console.';
    }
    if (raw.contains('network-request-failed') || raw.contains('unavailable')) {
      return 'No internet connection.';
    }
    final regex = RegExp(r'\[.*?\]\s*');
    return raw.replaceAll(regex, '').trim();
  }

  // --- Theme & Appearance Settings ---
  Future<void> setPaletteIndex(int index) async {
    paletteIndex = index;
    if (currentUser != null) {
      currentUser = currentUser!.copyWith(paletteIndex: index);
    }
    notifyListeners();

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set(
        {'paletteIndex': index},
        SetOptions(merge: true),
      );
    }
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode = value;
    if (currentUser != null) {
      currentUser = currentUser!.copyWith(darkMode: value);
    }
    notifyListeners();

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set(
        {'darkMode': value},
        SetOptions(merge: true),
      );
    }
  }

  // --- Calculations ---
  double get purchasedGroceryTotal => groceryItems
      .where((item) => item.purchased)
      .fold<double>(0, (acc, item) => acc + item.price);

  List<Expense> expensesForWeek(DateTime date) {
    final start = startOfWeek(date);
    final end = endOfWeek(date);
    return otherExpenses.where((exp) {
      final expDate = DateTime(exp.date.year, exp.date.month, exp.date.day);
      return !expDate.isBefore(start) && !expDate.isAfter(end);
    }).toList();
  }

  double otherExpensesTotalForWeek(DateTime date) {
    return expensesForWeek(date)
        .fold<double>(0, (acc, exp) => acc + exp.amount);
  }

  Budget budgetForWeek(DateTime date) {
    final start = startOfWeek(date);
    final weekId = DateFormat('yyyy-MM-dd').format(start);
    final weekBudgetAmount = _weeklyBudgetsMap[weekId]?.amount ??
        (isSameWeek(date, DateTime.now()) ? weeklyBudget : 0.0);

    final weekMeals = mealsForWeek(date);
    final mealsSpent =
        weekMeals.fold<double>(0, (acc, meal) => acc + meal.price);
    final expensesSpent = otherExpensesTotalForWeek(date);
    final groceriesSpent =
        isSameWeek(date, DateTime.now()) ? purchasedGroceryTotal : 0.0;
    final totalSpent = mealsSpent + expensesSpent + groceriesSpent;

    return Budget(weeklyBudget: weekBudgetAmount, spent: totalSpent);
  }

  Budget get budget => budgetForWeek(DateTime.now());

  double get groceryTotal =>
      groceryItems.fold<double>(0, (acc, item) => acc + item.price);

  List<Meal> mealsForDay(String day) =>
      meals.where((meal) => meal.day == day).toList();

  List<Meal> mealsForToday() {
    return mealsForDate(DateTime.now());
  }

  List<Meal> mealsForDate(DateTime date) {
    return meals.where((meal) => isSameDate(meal.date, date)).toList();
  }

  List<Meal> mealsForWeek(DateTime date) {
    final start = startOfWeek(date);
    final end = endOfWeek(date);
    return meals.where((meal) {
      final mealDate = DateTime(meal.date.year, meal.date.month, meal.date.day);
      return !mealDate.isBefore(start) && !mealDate.isAfter(end);
    }).toList();
  }

  // --- Firestore Database Operations ---
  Future<void> updateProfile({
    String? name,
    double? budget,
    List<String>? preferences,
    bool? darkMode,
    int? paletteIndex,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || currentUser == null) return;

    final newName = (name ?? currentUser!.name).trim();
    final newBudget = budget ?? currentUser!.weeklyBudget;
    final newPrefs = preferences ?? currentUser!.dietaryPreferences;
    final newDarkMode = darkMode ?? currentUser!.darkMode;
    final newPalette = paletteIndex ?? this.paletteIndex;

    if (newName.isEmpty) return;
    if (newBudget < 0) return;

    currentUser = currentUser!.copyWith(
      name: newName,
      weeklyBudget: newBudget,
      dietaryPreferences: newPrefs,
      darkMode: newDarkMode,
      paletteIndex: newPalette,
    );
    _weeklyBudget = newBudget;
    isDarkMode = newDarkMode;
    this.paletteIndex = newPalette;

    final batch = _firestore.batch();
    final userDocRef = _firestore.collection('users').doc(uid);

    batch.set(
      userDocRef,
      {
        'name': newName,
        'email': currentUser!.email,
        'weeklyBudget': newBudget,
        'dietaryPreferences': newPrefs,
        'darkMode': newDarkMode,
        'paletteIndex': newPalette,
      },
      SetOptions(merge: true),
    );

    if (budget != null && budget > 0) {
      final start = startOfWeek(DateTime.now());
      final end = endOfWeek(DateTime.now());
      final weekId = DateFormat('yyyy-MM-dd').format(start);
      final wb = WeeklyBudget(
        id: weekId,
        amount: budget,
        startDate: start,
        endDate: end,
        savedAt: DateTime.now(),
      );
      final budgetDocRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .doc(weekId);
      batch.set(budgetDocRef, wb.toFirestore(), SetOptions(merge: true));
    }

    await batch.commit();
    notifyListeners();
  }

  Future<void> saveWeeklyBudget(double amount, {DateTime? date}) async {
    if (amount <= 0) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final targetDate = date ?? DateTime.now();
    final start = startOfWeek(targetDate);
    final end = endOfWeek(targetDate);
    final weekId = DateFormat('yyyy-MM-dd').format(start);

    final wb = WeeklyBudget(
      id: weekId,
      amount: amount,
      startDate: start,
      endDate: end,
      savedAt: DateTime.now(),
    );

    _weeklyBudgetsMap[weekId] = wb;

    final batch = _firestore.batch();

    final currentWeekId =
        DateFormat('yyyy-MM-dd').format(startOfWeek(DateTime.now()));
    if (weekId == currentWeekId) {
      _weeklyBudget = amount;
      if (currentUser != null) {
        currentUser = currentUser!.copyWith(weeklyBudget: amount);
      }
      final userDocRef = _firestore.collection('users').doc(uid);
      batch.set(userDocRef, {'weeklyBudget': amount}, SetOptions(merge: true));
    }

    final budgetDocRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(weekId);
    batch.set(budgetDocRef, wb.toFirestore(), SetOptions(merge: true));

    await batch.commit();
    notifyListeners();
  }

  Future<void> deleteWeeklyBudget(String weekId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _weeklyBudgetsMap.remove(weekId);

    final batch = _firestore.batch();

    final currentWeekId =
        DateFormat('yyyy-MM-dd').format(startOfWeek(DateTime.now()));
    if (weekId == currentWeekId) {
      _weeklyBudget = 0.0;
      if (currentUser != null) {
        currentUser = currentUser!.copyWith(weeklyBudget: 0.0);
      }
      final userDocRef = _firestore.collection('users').doc(uid);
      batch.set(userDocRef, {'weeklyBudget': 0.0}, SetOptions(merge: true));
    }

    final budgetDocRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(weekId);
    batch.delete(budgetDocRef);

    await batch.commit();
    notifyListeners();
  }

  Future<void> addMeal(Meal meal) async {
    if (meal.price < 0) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();

    final docRef = meal.id.isNotEmpty
        ? _firestore
            .collection('users')
            .doc(uid)
            .collection('meals')
            .doc(meal.id)
        : _firestore.collection('users').doc(uid).collection('meals').doc();

    final finalMeal = meal.copyWith(id: docRef.id);
    batch.set(docRef, finalMeal.toFirestore());

    if (finalMeal.saveForReuse) {
      final savedDocRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('savedMeals')
          .doc(docRef.id);
      batch.set(
          savedDocRef, finalMeal.copyWith(saveForReuse: true).toFirestore());
    }

    await batch.commit();
    _syncGroceryList(finalMeal);
  }

  Future<void> updateMeal(Meal meal) async {
    if (meal.price < 0) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();

    final mealDocRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .doc(meal.id);
    batch.set(mealDocRef, meal.toFirestore(), SetOptions(merge: true));

    final savedDocRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('savedMeals')
        .doc(meal.id);

    if (meal.saveForReuse) {
      batch.set(savedDocRef, meal.toFirestore(), SetOptions(merge: true));
    } else {
      batch.delete(savedDocRef);
    }

    await batch.commit();
  }

  Future<void> deleteMeal(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef =
        _firestore.collection('users').doc(uid).collection('meals').doc(id);
    await docRef.delete();
  }

  Future<void> deleteSavedMeal(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();

    final savedDocRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('savedMeals')
        .doc(id);
    batch.delete(savedDocRef);

    final mealIndex = meals.indexWhere((m) => m.id == id);
    if (mealIndex != -1) {
      final updated = meals[mealIndex].copyWith(saveForReuse: false);
      final mealDocRef =
          _firestore.collection('users').doc(uid).collection('meals').doc(id);
      batch.set(mealDocRef, updated.toFirestore(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> copyMealToDay(Meal meal, String newDay, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final cleanTarget =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    final targetDayName = DateFormat('EEEE').format(cleanTarget);
    final newMeal = meal.copyWith(
      id: '',
      day: targetDayName,
      date: cleanTarget,
      eaten: false,
    );
    await addMeal(newMeal);
  }

  Future<void> toggleEaten(String id) async {
    final index = meals.indexWhere((m) => m.id == id);
    if (index != -1) {
      final updated = meals[index].copyWith(eaten: !meals[index].eaten);
      await updateMeal(updated);
    }
  }

  // --- Grocery List Firestore Operations ---
  Future<String?> addGroceryItem(GroceryItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'You must be logged in to add grocery items.';

    final cleanName = item.name.trim();
    if (cleanName.isEmpty) return 'Enter item name.';

    final qtyNum = int.tryParse(item.quantity.trim());
    if (qtyNum == null || qtyNum <= 0) {
      return 'Quantity must be a whole number greater than 0.';
    }

    if (item.price < 0) {
      return 'Estimated price must be 0 or greater.';
    }

    try {
      final collectionRef =
          _firestore.collection('users').doc(uid).collection('groceries');

      final isAutoGeneratedLocalId =
          item.id.isNotEmpty && item.id.contains(RegExp(r'^\d{10,}$'));

      final docRef = (item.id.isNotEmpty && !isAutoGeneratedLocalId)
          ? collectionRef.doc(item.id)
          : collectionRef.doc();

      final finalItem = item.copyWith(
        id: docRef.id,
        name: cleanName,
        quantity: qtyNum.toString(),
        createdAt: item.createdAt ?? DateTime.now(),
      );

      await docRef.set(finalItem.toFirestore());
      return null;
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<String?> updateGroceryItem(GroceryItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'You must be logged in.';

    final cleanName = item.name.trim();
    if (cleanName.isEmpty) return 'Enter item name.';

    final qtyNum = int.tryParse(item.quantity.trim());
    if (qtyNum == null || qtyNum <= 0) {
      return 'Quantity must be a whole number greater than 0.';
    }

    if (item.price < 0) {
      return 'Estimated price must be 0 or greater.';
    }

    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('groceries')
          .doc(item.id);

      final finalItem = item.copyWith(
        name: cleanName,
        quantity: qtyNum.toString(),
      );

      await docRef.set(finalItem.toFirestore(), SetOptions(merge: true));
      return null;
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<String?> toggleGroceryItem(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'You must be logged in.';

    final index = groceryItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      final updatedPurchased = !groceryItems[index].purchased;
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('groceries')
            .doc(id)
            .set({
          'isChecked': updatedPurchased,
          'purchased': updatedPurchased,
        }, SetOptions(merge: true));
        return null;
      } catch (e) {
        return _cleanErrorMessage(e.toString());
      }
    }
    return null;
  }

  Future<String?> deleteGroceryItem(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'You must be logged in.';

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('groceries')
          .doc(id)
          .delete();
      return null;
    } catch (e) {
      return _cleanErrorMessage(e.toString());
    }
  }

  Future<void> addExpense(
    double amount,
    String note, {
    String category = 'Other',
    DateTime? date,
  }) async {
    if (amount <= 0) return;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final expenseDate = date ?? DateTime.now();
    final cleanDate =
        DateTime(expenseDate.year, expenseDate.month, expenseDate.day);

    final docRef =
        _firestore.collection('users').doc(uid).collection('expenses').doc();
    final expense = Expense(
      id: docRef.id,
      category: category,
      date: cleanDate,
      amount: amount,
      note: note,
    );
    await docRef.set(expense.toFirestore());
  }

  Future<void> deleteExpense(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(id)
        .delete();
  }

  void _syncGroceryList(Meal meal) {
    for (final ingredient in meal.ingredients) {
      final exists = groceryItems.any(
        (item) => item.name.toLowerCase() == ingredient.toLowerCase(),
      );
      if (!exists) {
        addGroceryItem(
          GroceryItem(
            id: '',
            name: ingredient,
            quantity: '1',
            price: lastPrices[ingredient.toLowerCase()] ?? 0,
          ),
        );
      }
    }
  }
}
