import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../models/weekly_budget.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameController = TextEditingController();
  final budgetController = TextEditingController();
  final FocusNode budgetFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  bool _isEditingName = false;
  bool _isEditingBudget = false;
  bool _isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    budgetController.dispose();
    budgetFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _syncControllersWithData(LocalDatabase db) {
    if (!_isEditingName) {
      nameController.text = db.currentUser?.name ?? '';
    }
    if (!_isEditingBudget) {
      final currentBudget = db.weeklyBudget;
      if (currentBudget > 0) {
        budgetController.text = currentBudget % 1 == 0
            ? currentBudget.toInt().toString()
            : currentBudget.toStringAsFixed(2);
      } else {
        budgetController.text = '';
      }
    }
  }

  Future<void> saveProfile() async {
    final db = context.read<LocalDatabase>();
    final nameStr = nameController.text.trim();
    final budgetStr = budgetController.text.trim();

    if (nameStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your name.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    double? budgetToSave;
    if (budgetStr.isNotEmpty) {
      final parsed = double.tryParse(budgetStr);
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Please enter a valid weekly budget greater than 0.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      budgetToSave = parsed;
    }

    setState(() => _isSaving = true);

    await db.updateProfile(
      name: nameStr,
      budget: budgetToSave,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditingName = false;
      _isEditingBudget = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved successfully')),
    );
  }

  void _scrollToBudgetInput() {
    budgetFocusNode.requestFocus();
  }

  void _showEditBudgetDialog(
      BuildContext context, LocalDatabase db, WeeklyBudget weekBudget) {
    final editController = TextEditingController(
      text: weekBudget.amount % 1 == 0
          ? weekBudget.amount.toInt().toString()
          : weekBudget.amount.toStringAsFixed(2),
    );

    final startStr = DateFormat('MMM d').format(weekBudget.startDate);
    final endStr = DateFormat('MMM d, yyyy').format(weekBudget.endDate);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Weekly Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$startStr - $endStr',
              style: TextStyle(
                color: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: editController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weekly Budget Amount',
                prefixText: '₱ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final parsed = double.tryParse(editController.text.trim());
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Please enter a valid amount greater than 0.'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
                return;
              }
              await db.saveWeeklyBudget(parsed, date: weekBudget.startDate);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Weekly budget updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteBudgetConfirmation(
      BuildContext context, LocalDatabase db, WeeklyBudget weekBudget) {
    final startStr = DateFormat('MMM d').format(weekBudget.startDate);
    final endStr = DateFormat('MMM d, yyyy').format(weekBudget.endDate);
    final dateRange = '$startStr - $endStr';
    final isCurrent =
        LocalDatabase.isSameWeek(weekBudget.startDate, DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Week Budget?'),
        content: Text(
          'Are you sure you want to delete the budget for $dateRange?'
          '${isCurrent ? "\n\nNote: Deleting this week's budget will clear the active budget on Home and Budget screens." : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              await db.deleteWeeklyBudget(weekBudget.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Budget deleted for $dateRange')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showWeekDetailsSheet(
      BuildContext context, LocalDatabase db, WeeklyBudget weekBudget) {
    final theme = Theme.of(context);
    final startStr = DateFormat('MMM d').format(weekBudget.startDate);
    final endStr = DateFormat('MMM d, yyyy').format(weekBudget.endDate);
    final dateRange = '$startStr - $endStr';

    final budget = db.budgetForWeek(weekBudget.startDate);
    final meals = db.mealsForWeek(weekBudget.startDate);
    final expenses = db.expensesForWeek(weekBudget.startDate);
    final isCurrent =
        LocalDatabase.isSameWeek(weekBudget.startDate, DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        dateRange,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'This week',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metrics Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Weekly Budget',
                          value: '₱${weekBudget.amount.toStringAsFixed(2)}',
                        ),
                        const Divider(height: 16),
                        _DetailRow(
                          label: 'Total Spent',
                          value: '₱${budget.spent.toStringAsFixed(2)}',
                        ),
                        const Divider(height: 16),
                        _DetailRow(
                          label: budget.remaining >= 0
                              ? 'Amount Left'
                              : 'Over Budget',
                          value:
                              '₱${budget.remaining.abs().toStringAsFixed(2)}',
                          valueColor: budget.remaining >= 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        const Divider(height: 16),
                        _DetailRow(
                          label: 'Average Daily Cost',
                          value:
                              '₱${budget.averageMealCost.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Budget'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditBudgetDialog(context, db, weekBudget);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                        ),
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDeleteBudgetConfirmation(
                              context, db, weekBudget);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Meals Breakdown
                Text(
                  'Meals (${meals.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (meals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No meals recorded for this week.',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...meals.map(
                    (m) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${DateFormat('EEE, MMM d').format(m.date)} • ${m.type.name}',
                      ),
                      trailing: Text(
                        '₱${m.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Expenses Breakdown
                Text(
                  'Other Expenses (${expenses.length})',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No other expenses recorded for this week.',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...expenses.map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        e.note.isNotEmpty ? e.note : e.category,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${DateFormat('EEE, MMM d').format(e.date)} • ${e.category}',
                      ),
                      trailing: Text(
                        '₱${e.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<LocalDatabase>();
    final user = db.currentUser;
    final theme = Theme.of(context);
    final historyList = db.weeklyBudgets;

    if (user != null) {
      _syncControllersWithData(db);
    }

    ImageProvider? userAvatar;
    if (user?.photoBase64 != null && user!.photoBase64!.isNotEmpty) {
      try {
        userAvatar = MemoryImage(base64Decode(user.photoBase64!));
      } catch (_) {}
    } else if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty) {
      userAvatar = NetworkImage(user.photoUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          backgroundImage: userAvatar,
                          child: userAvatar == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.name.isNotEmpty ? user.name : 'Student',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                        if (user.provider == 'google') ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Google Account',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => EditProfileScreen.show(context),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Profile'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Saved Meals Card
                Text(
                  'Saved Meals',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.bookmark_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      'Saved Meals',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${db.savedMeals.length} reusable meal${db.savedMeals.length == 1 ? '' : 's'} saved',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.savedMeals);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Dark Mode & Theme Color Picker
                Text(
                  'App Theme & Appearance',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(
                          db.isDarkMode
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Dark Mode'),
                        value: db.isDarkMode,
                        onChanged: (value) => db.setDarkMode(value),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Color Palette Presets',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: AppTheme.palettes.length,
                                itemBuilder: (context, index) {
                                  final palette = AppTheme.palettes[index];
                                  final isSelected = db.paletteIndex == index;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => db.setPaletteIndex(index),
                                    child: Container(
                                      width: 90,
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: palette.background,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? palette.primary
                                              : Colors.black12,
                                          width: isSelected ? 2.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              CircleAvatar(
                                                radius: 10,
                                                backgroundColor:
                                                    palette.surface,
                                              ),
                                              const SizedBox(width: 4),
                                              CircleAvatar(
                                                radius: 10,
                                                backgroundColor:
                                                    palette.primary,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            palette.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: palette.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // User Settings
                Text(
                  'Profile Settings',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  onChanged: (_) => _isEditingName = true,
                  decoration: const InputDecoration(
                    labelText: 'Edit name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: budgetController,
                  focusNode: budgetFocusNode,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _isEditingBudget = true,
                  decoration: const InputDecoration(
                    labelText: 'Weekly budget',
                    hintText: 'e.g. 1000',
                    prefixText: '₱ ',
                    prefixIcon: Icon(Icons.savings_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isSaving)
                  const Center(child: CircularProgressIndicator())
                else
                  FilledButton(
                    onPressed: saveProfile,
                    child: const Text('Save Profile'),
                  ),
                const SizedBox(height: 28),

                // Budget History Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Budget history',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (historyList.isNotEmpty)
                      Text(
                        '${historyList.length} week${historyList.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (historyList.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            size: 40,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No budgets saved yet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start tracking your weekly food budget by setting an amount above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Set budget'),
                            onPressed: _scrollToBudgetInput,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...historyList.map((wb) {
                    final weekBudgetObj = db.budgetForWeek(wb.startDate);
                    final spent = weekBudgetObj.spent;
                    final total = wb.amount;
                    final remaining = wb.amount - spent;
                    final isCurrent =
                        LocalDatabase.isSameWeek(wb.startDate, DateTime.now());
                    final progress =
                        total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
                    final isOver = remaining < 0;

                    final startStr = DateFormat('MMM d').format(wb.startDate);
                    final endStr = DateFormat('MMM d, yyyy').format(wb.endDate);
                    final rangeStr = '$startStr - $endStr';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () => _showWeekDetailsSheet(context, db, wb),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rangeStr,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'This week',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded,
                                          size: 20),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showEditBudgetDialog(
                                              context, db, wb);
                                        } else if (val == 'delete') {
                                          _showDeleteBudgetConfirmation(
                                              context, db, wb);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit Amount'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline_rounded,
                                                  size: 18, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Budget: ₱${wb.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    Text(
                                      'Spent: ₱${spent.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isOver
                                      ? '₱${(-remaining).toStringAsFixed(2)} over budget'
                                      : '₱${remaining.toStringAsFixed(2)} left',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isOver
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor:
                                        theme.scaffoldBackgroundColor,
                                    color: isOver
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.logout_rounded,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Log Out',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      await context.read<LocalDatabase>().logout();
                      if (!context.mounted) return;
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.welcome,
                        (route) => false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: valueColor ?? theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}
