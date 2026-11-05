import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../widgets/budget_progress_card.dart';
import 'expense_form_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final budgetController = TextEditingController();
  bool _isEditingBudget = false;

  @override
  void dispose() {
    budgetController.dispose();
    super.dispose();
  }

  void _syncBudgetController(LocalDatabase db) {
    if (!_isEditingBudget) {
      final current = db.weeklyBudget;
      if (current > 0) {
        budgetController.text = current % 1 == 0
            ? current.toInt().toString()
            : current.toStringAsFixed(2);
      } else {
        budgetController.text = '';
      }
    }
  }

  Future<void> saveBudget() async {
    final rawStr = budgetController.text.trim();
    final value = double.tryParse(rawStr);

    if (rawStr.isEmpty || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid weekly budget greater than 0.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final db = context.read<LocalDatabase>();
    await db.saveWeeklyBudget(value);

    if (!mounted) return;
    setState(() {
      _isEditingBudget = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Weekly budget updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<LocalDatabase>();
    final budget = db.budget;
    final theme = Theme.of(context);

    _syncBudgetController(db);

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          BudgetProgressCard(budget: budget),
          if (budget.alertTriggered) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Budget alert: You have reached 80% of your weekly budget.',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly summary',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SummaryRow(
                    label: 'Total spent',
                    value: '₱${budget.spent.toStringAsFixed(2)}',
                  ),
                  _SummaryRow(
                    label: 'Average cost per day',
                    value: '₱${budget.averageMealCost.toStringAsFixed(2)}',
                  ),
                  _SummaryRow(
                    label: 'Amount saved',
                    value: '₱${budget.saved.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: budgetController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _isEditingBudget = true,
            decoration: const InputDecoration(
              labelText: 'Set weekly budget',
              hintText: 'e.g. 1000',
              prefixText: '₱ ',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saveBudget,
            child: const Text('Save Budget'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ExpenseFormScreen.show(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Expense'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
