import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../../models/meal.dart';
import '../widgets/primary_button.dart';

class MealFormScreen extends StatefulWidget {
  final Meal? editingMeal;
  final String? initialDay;
  final DateTime? initialDate;

  const MealFormScreen({
    super.key,
    this.editingMeal,
    this.initialDay,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    Meal? meal,
    String? initialDay,
    DateTime? initialDate,
  }) {
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
        child: MealFormScreen(
          editingMeal: meal,
          initialDay: initialDay,
          initialDate: initialDate,
        ),
      ),
    );
  }

  @override
  State<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends State<MealFormScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final ingredientsController = TextEditingController();

  MealType selectedType = MealType.breakfast;
  late DateTime selectedDate;
  bool saveForReuse = false;
  Meal? editingMeal;

  @override
  void initState() {
    super.initState();
    if (widget.editingMeal != null) {
      editingMeal = widget.editingMeal;
      nameController.text = editingMeal!.name;
      priceController.text = editingMeal!.price > 0 ? editingMeal!.price.toString() : '';
      ingredientsController.text = editingMeal!.ingredients.join(', ');
      selectedType = editingMeal!.type;
      selectedDate = DateTime(editingMeal!.date.year, editingMeal!.date.month, editingMeal!.date.day);
      saveForReuse = editingMeal!.saveForReuse;
    } else {
      final init = widget.initialDate ?? DateTime.now();
      selectedDate = DateTime(init.year, init.month, init.day);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (editingMeal == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Meal) {
        editingMeal = args;
        nameController.text = args.name;
        priceController.text = args.price > 0 ? args.price.toString() : '';
        ingredientsController.text = args.ingredients.join(', ');
        selectedType = args.type;
        selectedDate = DateTime(args.date.year, args.date.month, args.date.day);
        saveForReuse = args.saveForReuse;
      } else if (args is Map<String, dynamic>) {
        if (args['date'] != null && args['date'] is DateTime) {
          final d = args['date'] as DateTime;
          selectedDate = DateTime(d.year, d.month, d.day);
        }
      }
    }
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

    final db = context.read<LocalDatabase>();
    final cleanDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dayName = DateFormat('EEEE').format(cleanDate);

    final meal = Meal(
      id: editingMeal?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      type: selectedType,
      ingredients: ingredientsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      price: double.tryParse(priceController.text) ?? 0,
      day: dayName,
      date: cleanDate,
      eaten: editingMeal?.eaten ?? false,
      saveForReuse: saveForReuse,
    );

    if (editingMeal == null) {
      db.addMeal(meal);
    } else {
      db.updateMeal(meal);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          editingMeal == null
              ? '${meal.name} added to your meal plan'
              : '${meal.name} updated',
        ),
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildFormContent(BuildContext context) {
    final theme = Theme.of(context);
    final db = context.watch<LocalDatabase>();
    final isEditing = editingMeal != null;

    // Calculate Monday of the selected date's week
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit meal' : 'Add a meal',
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

            // Quick Fill from Saved Meals if adding new meal
            if (!isEditing && db.savedMeals.isNotEmpty) ...[
              Text(
                'Quick fill from Saved Meals',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: db.savedMeals.length,
                  itemBuilder: (context, index) {
                    final savedMeal = db.savedMeals[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.bookmark_rounded, size: 16),
                        label: Text(savedMeal.name),
                        onPressed: () {
                          setState(() {
                            nameController.text = savedMeal.name;
                            selectedType = savedMeal.type;
                            ingredientsController.text = savedMeal.ingredients.join(', ');
                            priceController.text =
                                savedMeal.price > 0 ? savedMeal.price.toString() : '';
                            saveForReuse = true;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 1. Meal name
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Meal name',
                hintText: 'e.g. Overnight oats',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter meal name' : null,
            ),
            const SizedBox(height: 20),

            // 2. Meal type (2x2 grid)
            Text(
              'Meal type',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: MealType.values.map((type) {
                final selected = selectedType == type;
                final labelName =
                    type.name[0].toUpperCase() + type.name.substring(1);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      labelName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. Ingredients or place (Optional)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingredients or place',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: ingredientsController,
              decoration: const InputDecoration(
                hintText: 'e.g. Oats, milk, banana',
              ),
            ),
            const SizedBox(height: 20),

            // 4. Date selection and Price
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
            Row(
              children: [
                // Horizontal week date chips + Calendar picker button
                Expanded(
                  child: SingleChildScrollView(
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
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price field
            Text(
              'Price',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: '₱ ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return double.tryParse(value) != null ? null : 'Invalid price';
              },
            ),
            const SizedBox(height: 16),

            // 5. Checkbox Save for reuse
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: saveForReuse,
              onChanged: (val) => setState(() => saveForReuse = val ?? false),
              title: const Text('Save for reuse'),
              subtitle: const Text('Add it to your Saved Meals list'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),

            // 6. Full-width primary button
            PrimaryButton(
              label: isEditing ? 'Save changes' : 'Add meal',
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
    final isRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final parentRouteName = ModalRoute.of(context)?.settings.name;

    if (parentRouteName == '/meal-form' || (isRoute && Navigator.canPop(context))) {
      return Scaffold(
        appBar: AppBar(
          title: Text(editingMeal != null ? 'Edit meal' : 'Add a meal'),
          automaticallyImplyLeading: true,
        ),
        body: SafeArea(
          child: _buildFormContent(context),
        ),
      );
    }

    return _buildFormContent(context);
  }
}
