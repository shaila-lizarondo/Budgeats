import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum MealType { breakfast, lunch, dinner, snack }

class Meal {
  final String id;
  final String name;
  final MealType type;
  final List<String> ingredients;
  final double price;
  final String day;
  final DateTime date;
  final bool eaten;
  final bool saveForReuse;

  Meal({
    required this.id,
    required this.name,
    required this.type,
    required this.ingredients,
    required this.price,
    String? day,
    DateTime? date,
    this.eaten = false,
    this.saveForReuse = false,
  })  : date = date ?? DateTime.now(),
        day = day ??
            (date != null
                ? DateFormat('EEEE').format(date)
                : DateFormat('EEEE').format(DateTime.now()));

  Meal copyWith({
    String? id,
    String? name,
    MealType? type,
    List<String>? ingredients,
    double? price,
    String? day,
    DateTime? date,
    bool? eaten,
    bool? saveForReuse,
  }) {
    final newDate = date ?? this.date;
    final newDay = day ?? DateFormat('EEEE').format(newDate);
    return Meal(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ingredients: ingredients ?? this.ingredients,
      price: price ?? this.price,
      day: newDay,
      date: newDate,
      eaten: eaten ?? this.eaten,
      saveForReuse: saveForReuse ?? this.saveForReuse,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'ingredients': ingredients,
      'price': price,
      'day': day,
      'date': Timestamp.fromDate(date),
      'eaten': eaten,
      'saveForReuse': saveForReuse,
    };
  }

  factory Meal.fromFirestore(Map<String, dynamic> json, [String? docId]) {
    final dateVal = json['date'];
    DateTime parsedDate;
    if (dateVal is Timestamp) {
      parsedDate = dateVal.toDate();
    } else if (dateVal is String) {
      parsedDate = DateTime.tryParse(dateVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final typeStr = json['type'] as String? ?? 'breakfast';
    final mealType = MealType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => MealType.breakfast,
    );

    return Meal(
      id: json['id'] as String? ?? docId ?? '',
      name: json['name'] as String? ?? '',
      type: mealType,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      day: json['day'] as String?,
      date: parsedDate,
      eaten: json['eaten'] as bool? ?? false,
      saveForReuse: json['saveForReuse'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory Meal.fromJson(Map<String, dynamic> json) => Meal.fromFirestore(json);
}
