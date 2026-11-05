import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../../models/meal.dart';
import '../widgets/meal_card.dart';
import 'meal_form_screen.dart';

class SavedMealsScreen extends StatelessWidget {
  const SavedMealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<LocalDatabase>();
    final savedMeals = db.savedMeals;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Meals'),
      ),
      body: savedMeals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.bookmark_outline_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved meals yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When creating or editing a meal, check "Save for reuse" to keep your favorite meals here for quick access.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Your Reusable Meals (${savedMeals.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap "+ Add to plan" to reuse a meal on any date, or edit/remove saved entries.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                ...savedMeals.map(
                  (meal) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MealCard(
                      meal: meal,
                      trailing: '₱${meal.price.toStringAsFixed(0)}',
                      actions: [
                        IconButton(
                          tooltip: 'Add to plan',
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onPressed: () {
                            MealFormScreen.show(
                              context,
                              meal: meal.copyWith(
                                id: DateTime.now().microsecondsSinceEpoch.toString(),
                                date: DateTime.now(),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Edit saved meal',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            MealFormScreen.show(
                              context,
                              meal: meal,
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Remove from saved',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () {
                            _confirmDeleteSavedMeal(context, db, meal);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _confirmDeleteSavedMeal(BuildContext context, LocalDatabase db, Meal meal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved meal?'),
        content: Text('Remove "${meal.name}" from your saved meals list?'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () {
                  db.deleteSavedMeal(meal.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${meal.name} removed from saved meals')),
                  );
                },
                child: const Text('Delete'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
