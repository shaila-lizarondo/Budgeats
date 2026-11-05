import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../backend/local_database.dart';
import '../../models/grocery_item.dart';
import '../widgets/empty_state.dart';

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final nameFocusNode = FocusNode();
  final quantityController = TextEditingController();
  final priceController = TextEditingController();

  bool isAdding = false;

  @override
  void dispose() {
    nameController.dispose();
    nameFocusNode.dispose();
    quantityController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> addItem() async {
    if (isAdding) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => isAdding = true);

    final qtyVal = quantityController.text.trim().isEmpty
        ? '1'
        : quantityController.text.trim();
    final priceVal = double.tryParse(priceController.text.trim()) ?? 0.0;

    final db = context.read<LocalDatabase>();
    final error = await db.addGroceryItem(
      GroceryItem(
        id: '',
        name: nameController.text.trim(),
        quantity: qtyVal,
        price: priceVal,
        createdAt: DateTime.now(),
      ),
    );

    if (!mounted) return;
    setState(() => isAdding = false);

    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    _showSnackBar('"${nameController.text.trim()}" added to grocery list');

    nameController.clear();
    quantityController.clear();
    priceController.clear();
    formKey.currentState?.reset();
  }

  void _showEditDialog(BuildContext context, GroceryItem item) {
    final editFormKey = GlobalKey<FormState>();
    final editName = TextEditingController(text: item.name);
    final editQty = TextEditingController(text: item.quantity);
    final editPrice = TextEditingController(
      text: item.price > 0
          ? (item.price % 1 == 0
              ? item.price.toInt().toString()
              : item.price.toStringAsFixed(2))
          : '',
    );

    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Grocery Item'),
            content: Form(
              key: editFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: editName,
                    enabled: !isUpdating,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter item name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: editQty,
                          enabled: !isUpdating,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: '1',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Qty required';
                            final parsed = int.tryParse(v.trim());
                            if (parsed == null || parsed <= 0)
                              return 'Must be > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: editPrice,
                          enabled: !isUpdating,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Est. Price',
                            prefixText: '₱ ',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null || parsed < 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUpdating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isUpdating
                    ? null
                    : () async {
                        if (!editFormKey.currentState!.validate()) return;
                        setDialogState(() => isUpdating = true);

                        final db = context.read<LocalDatabase>();
                        final updated = item.copyWith(
                          name: editName.text.trim(),
                          quantity: editQty.text.trim(),
                          price: double.tryParse(editPrice.text.trim()) ?? 0.0,
                        );

                        final err = await db.updateGroceryItem(updated);
                        if (!ctx.mounted) return;
                        setDialogState(() => isUpdating = false);

                        if (err != null) {
                          _showSnackBar(err, isError: true);
                          return;
                        }

                        Navigator.pop(ctx);
                        _showSnackBar('Item updated');
                      },
                child: isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, GroceryItem item) {
    final db = context.read<LocalDatabase>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Grocery Item?'),
        content: Text(
            'Are you sure you want to remove "${item.name}" from your grocery list?'),
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
              Navigator.pop(ctx);
              final err = await db.deleteGroceryItem(item.id);
              if (err != null && context.mounted) {
                _showSnackBar(err, isError: true);
              } else if (context.mounted) {
                _showSnackBar('"${item.name}" deleted');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroceryItemCard(
    GroceryItem item,
    LocalDatabase db,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: CheckboxListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        value: item.purchased,
        onChanged: (_) async {
          final err = await db.toggleGroceryItem(item.id);
          if (err != null) _showSnackBar(err, isError: true);
        },
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.purchased ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Qty: ${item.quantity} • ₱${item.price.toStringAsFixed(2)}',
        ),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit item',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditDialog(context, item),
            ),
            IconButton(
              tooltip: 'Delete item',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => _confirmDelete(context, item),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<LocalDatabase>();
    final theme = Theme.of(context);
    final toBuyItems =
        db.groceryItems.where((item) => !item.purchased).toList();
    final inBasketItems =
        db.groceryItems.where((item) => item.purchased).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Grocery List')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Add Grocery Form Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Grocery Item',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          focusNode: nameFocusNode,
                          enabled: !isAdding,
                          decoration: const InputDecoration(
                            labelText: 'Item name',
                            hintText: 'e.g. Milk, Pringles, Rice',
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter item name'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: quantityController,
                                enabled: !isAdding,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  hintText: '1',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty)
                                    return null;
                                  final parsed = int.tryParse(value.trim());
                                  if (parsed == null || parsed <= 0) {
                                    return 'Must be > 0';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                enabled: !isAdding,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Est. Price',
                                  prefixText: '₱ ',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty)
                                    return null;
                                  final parsed = double.tryParse(value.trim());
                                  if (parsed == null || parsed < 0) {
                                    return 'Invalid price';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isAdding ? null : addItem,
                            icon: isAdding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_rounded),
                            label: Text(
                                isAdding ? 'Saving...' : 'Add to Grocery List'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Item Counter & Total Price Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items (${db.groceryItems.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total: ₱${db.groceryTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Grocery List View / Empty State / Loading State
              Expanded(
                child: db.isGroceryLoading
                    ? const Center(child: CircularProgressIndicator())
                    : db.groceryItems.isEmpty
                        ? EmptyState(
                            icon: Icons.shopping_basket_outlined,
                            title: 'Your list is ready to fill',
                            message:
                                'Add the ingredients and essentials you need for the week.',
                            compact: true,
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (toBuyItems.isNotEmpty) ...[
                                _GrocerySectionHeader(
                                  title: 'To pick up',
                                  count: toBuyItems.length,
                                  icon: Icons.shopping_basket_outlined,
                                ),
                                ...toBuyItems.map(
                                  (item) => _buildGroceryItemCard(item, db),
                                ),
                              ],
                              if (inBasketItems.isNotEmpty) ...[
                                _GrocerySectionHeader(
                                  title: 'Picked up',
                                  count: inBasketItems.length,
                                  icon: Icons.check_circle_outline_rounded,
                                  topPadding: toBuyItems.isNotEmpty ? 12 : 0,
                                ),
                                ...inBasketItems.map(
                                  (item) => _buildGroceryItemCard(item, db),
                                ),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrocerySectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final double topPadding;

  const _GrocerySectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    this.topPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, topPadding, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
