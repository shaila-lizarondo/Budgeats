import 'package:cloud_firestore/cloud_firestore.dart';

class GroceryItem {
  final String id;
  final String name;
  final String quantity;
  final double price;
  final bool purchased;
  final DateTime? createdAt;

  const GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.purchased = false,
    this.createdAt,
  });

  double get estimatedPrice => price;
  bool get isChecked => purchased;

  GroceryItem copyWith({
    String? id,
    String? name,
    String? quantity,
    double? price,
    bool? purchased,
    DateTime? createdAt,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      purchased: purchased ?? this.purchased,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'estimatedPrice': price,
      'price': price,
      'isChecked': purchased,
      'purchased': purchased,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory GroceryItem.fromFirestore(Map<String, dynamic> json, [String? docId]) {
    final dateVal = json['createdAt'];
    DateTime? parsedDate;
    if (dateVal is Timestamp) {
      parsedDate = dateVal.toDate();
    } else if (dateVal is String) {
      parsedDate = DateTime.tryParse(dateVal);
    }

    final rawPrice = json['estimatedPrice'] ?? json['price'];
    final rawChecked = json['isChecked'] ?? json['purchased'];

    return GroceryItem(
      id: docId ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: json['quantity']?.toString() ?? '1',
      price: (rawPrice as num?)?.toDouble() ?? 0.0,
      purchased: rawChecked as bool? ?? false,
      createdAt: parsedDate,
    );
  }
}
