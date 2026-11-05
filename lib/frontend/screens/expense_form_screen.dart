import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../widgets/primary_button.dart';

class ExpenseFormScreen extends StatefulWidget {
  final DateTime? initialDate;

  const ExpenseFormScreen({super.key, this.initialDate});

  static Future<void> show(BuildContext context, {DateTime? initialDate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ExpenseFormScreen(initialDate: initialDate),
      ),
    );
  }

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String selectedCategory = 'Food';
  late DateTime selectedDate;
  final categories = const ['Food', 'Transport', 'Supplies', 'Bills', 'Other'];

  @override
  void initState() {
    super.initState();
    final init = widget.initialDate ?? DateTime.now();
    selectedDate = DateTime(init.year, init.month, init.day);
  }

  Future<void> _pickOtherDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void save() {
    if (!formKey.currentState!.validate()) return;

    final amount = double.tryParse(amountController.text) ?? 0;
    final note = noteController.text.trim();

    context.read<LocalDatabase>().addExpense(
      amount,
      note,
      category: selectedCategory,
      date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense added successfully')),
    );

    Navigator.pop(context);
  }

  Widget _buildFormContent(BuildContext context) {
    final theme = Theme.of(context);
    final mondayOfSelectedWeek = LocalDatabase.startOfWeek(selectedDate);
    final weekDates = List.generate(
      7,
      (index) => DateTime(
        mondayOfSelectedWeek.year,
        mondayOfSelectedWeek.month,
        mondayOfSelectedWeek.day + index,
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add expense',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Category',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final selected = selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => selectedCategory = cat),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Date Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...weekDates.map((date) {
                    final selected = LocalDatabase.isSameDate(selectedDate, date);
                    final chipLabel = DateFormat('EEE d').format(date);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(chipLabel),
                        selected: selected,
                        onSelected: (_) => setState(
                          () => selectedDate = DateTime(date.year, date.month, date.day),
                        ),
                      ),
                    );
                  }),
                  IconButton.filledTonal(
                    tooltip: 'Pick another date',
                    icon: const Icon(Icons.calendar_month_rounded, size: 20),
                    onPressed: _pickOtherDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: '₱ ',
              ),
              validator: (value) =>
                  double.tryParse(value ?? '') != null &&
                          double.parse(value!) > 0
                      ? null
                      : 'Enter a valid amount',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note / Description',
                hintText: 'e.g. Coffee, Groceries top-up',
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save Expense',
              onPressed: save,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentRouteName = ModalRoute.of(context)?.settings.name;

    if (parentRouteName == '/expense-form') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add expense'),
        ),
        body: SafeArea(
          child: _buildFormContent(context),
        ),
      );
    }

    return _buildFormContent(context);
  }
}
