import 'package:flutter/foundation.dart';

import '../backend/local_database.dart';
import '../models/budget.dart';
import '../models/meal.dart';

class DashboardController extends ChangeNotifier {
  final LocalDatabase db;

  DashboardController(this.db);

  Budget get budget => db.budget;
  List<Meal> get todayMeals => db.mealsForToday();

  bool get shouldShowBudgetAlert =>
      budget.alertTriggered && budget.weeklyBudget > 0;
}