import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../../models/meal.dart';
import '../widgets/empty_state.dart';
import '../widgets/meal_card.dart';
import 'meal_form_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  void _previousWeek() {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day - 7,
      );
    });
  }

  void _nextWeek() {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + 7,
      );
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<LocalDatabase>();
    final meals = db.mealsForDate(_selectedDate);
    final theme = Theme.of(context);

    final monday = LocalDatabase.startOfWeek(_selectedDate);
    final sunday =
        DateTime(monday.year, monday.month, monday.day + 6, 23, 59, 59, 999);
    final weekDates = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );

    final weekMeals = db.mealsForWeek(_selectedDate);
    final weekTotalCost = weekMeals.fold<double>(0, (sum, m) => sum + m.price);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Meal Plan'),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today_rounded),
            onPressed: _goToToday,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => MealFormScreen.show(
          context,
          initialDate: _selectedDate,
        ),
        label: const Text('Add Meal'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Week Header Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: _previousWeek,
                ),
                Column(
                  children: [
                    Text(
                      '${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d, yyyy').format(sunday)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Week Spending: ₱${weekTotalCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _nextWeek,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Horizontal Date Chips Row (showing real dates e.g. "Mon 13", "Tue 14"...)
          SizedBox(
            height: 76,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: weekDates.length,
              itemBuilder: (context, index) {
                final date = weekDates[index];
                final isSelected =
                    LocalDatabase.isSameDate(_selectedDate, date);
                final foreground = isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: DateFormat('EEEE, MMMM d').format(date),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(17),
                        onTap: () => setState(
                          () => _selectedDate =
                              DateTime(date.year, date.month, date.day),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: 54,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface
                                    .withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: isSelected ? 0 : 0.12,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('EEE').format(date).toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.45,
                                  color: foreground.withValues(alpha: 0.78),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${date.day}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Day Meals Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(_selectedDate),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Day Cost: ₱${meals.fold<double>(0, (sum, m) => sum + m.price).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Meals List for Selected Date
          Expanded(
            child: meals.isEmpty
                ? EmptyState(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'A fresh day starts here',
                    message:
                        'No meals planned for ${DateFormat('EEE, MMM d').format(_selectedDate)}. Use Add Meal when you are ready to plan.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: meals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final meal = meals[index];
                      return MealCard(
                        meal: meal,
                        trailing: '₱${meal.price.toStringAsFixed(0)}',
                        actions: [
                          IconButton(
                            tooltip: 'Mark as eaten',
                            icon: Icon(
                              meal.eaten
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: meal.eaten
                                  ? theme.colorScheme.primary
                                  : theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.5),
                            ),
                            onPressed: () => db.toggleEaten(meal.id),
                          ),
                          IconButton(
                            tooltip: 'Copy to another date',
                            icon: const Icon(Icons.copy_rounded),
                            onPressed: () => _copyMeal(meal),
                          ),
                          IconButton(
                            tooltip: 'Edit meal',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => MealFormScreen.show(
                              context,
                              meal: meal,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete meal',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _deleteMeal(meal),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _copyMeal(Meal meal) {
    final db = context.read<LocalDatabase>();
    final monday = LocalDatabase.startOfWeek(_selectedDate);
    final weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Copy "${meal.name}" to:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: weekDates
                      .map(
                        (date) => ListTile(
                          title: Text(DateFormat('EEEE, MMM d').format(date)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            final dayName = DateFormat('EEEE').format(date);
                            db.copyMealToDay(meal, dayName, date: date);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${meal.name} copied to ${DateFormat('EEE, MMM d').format(date)}',
                                ),
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteMeal(Meal meal) {
    final db = context.read<LocalDatabase>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${meal.name}" from your meal plan?'),
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
                  db.deleteMeal(meal.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${meal.name} deleted')),
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
