import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String category;
  final DateTime date;
  final double amount;
  final String note;

  const Expense({
    required this.id,
    required this.category,
    required this.date,
    required this.amount,
    required this.note,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'category': category,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'note': note,
    };
  }

  factory Expense.fromFirestore(Map<String, dynamic> json, [String? docId]) {
    final dateVal = json['date'];
    DateTime parsedDate;
    if (dateVal is Timestamp) {
      parsedDate = dateVal.toDate();
    } else if (dateVal is String) {
      parsedDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return Expense(
      id: json['id'] as String? ?? docId ?? '',
      category: json['category'] as String? ?? 'Other',
      date: parsedDate,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory Expense.fromJson(Map<String, dynamic> json) => Expense.fromFirestore(json);
}
