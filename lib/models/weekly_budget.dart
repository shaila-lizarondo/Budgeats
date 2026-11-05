import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyBudget {
  final String id; // Format: yyyy-MM-dd (startOfWeek)
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? savedAt;

  const WeeklyBudget({
    required this.id,
    required this.amount,
    required this.startDate,
    required this.endDate,
    this.savedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'weekStart': Timestamp.fromDate(startDate),
      'weekEnd': Timestamp.fromDate(endDate),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'savedAt': savedAt != null ? Timestamp.fromDate(savedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory WeeklyBudget.fromFirestore(Map<String, dynamic> json, String docId) {
    final startVal = json['weekStart'] ?? json['startDate'];
    final endVal = json['weekEnd'] ?? json['endDate'];
    final savedVal = json['savedAt'];

    final start = startVal is Timestamp
        ? startVal.toDate()
        : (startVal is String ? (DateTime.tryParse(startVal) ?? DateTime.now()) : DateTime.now());
    final end = endVal is Timestamp
        ? endVal.toDate()
        : (endVal is String ? (DateTime.tryParse(endVal) ?? DateTime.now()) : DateTime.now());
    final saved = savedVal is Timestamp ? savedVal.toDate() : null;

    return WeeklyBudget(
      id: docId,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      startDate: start,
      endDate: end,
      savedAt: saved,
    );
  }
}
