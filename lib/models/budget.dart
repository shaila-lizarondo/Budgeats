class Budget {
  final double weeklyBudget;
  final double spent;

  const Budget({
    required this.weeklyBudget,
    required this.spent,
  });

  double get remaining => weeklyBudget - spent;
  double get usedPercent =>
      weeklyBudget <= 0 ? 0 : (spent / weeklyBudget).clamp(0, 1);
  bool get alertTriggered => usedPercent >= .80;
  double get averageMealCost => spent <= 0 ? 0 : spent / 7;
  double get saved => weeklyBudget - spent;
}