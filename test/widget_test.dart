import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:student_budget_meal_plan/app.dart';
import 'package:student_budget_meal_plan/backend/local_database.dart';

void main() {
  testWidgets('App loads welcome screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocalDatabase()),
        ],
        child: const StudentBudgetMealPlanApp(),
      ),
    );

    expect(find.textContaining('Student Budget'), findsWidgets);
  });
}
