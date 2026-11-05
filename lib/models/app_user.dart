import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String? uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? photoBase64;
  final String provider;
  final double weeklyBudget;
  final List<String> dietaryPreferences;
  final bool darkMode;
  final int paletteIndex;
  final bool hasSeenGetStarted;
  final DateTime? createdAt;

  const AppUser({
    this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.photoBase64,
    this.provider = 'email',
    required this.weeklyBudget,
    this.dietaryPreferences = const [],
    this.darkMode = false,
    this.paletteIndex = 0,
    this.hasSeenGetStarted = true,
    this.createdAt,
  });

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? photoBase64,
    String? provider,
    double? weeklyBudget,
    List<String>? dietaryPreferences,
    bool? darkMode,
    int? paletteIndex,
    bool? hasSeenGetStarted,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBase64: photoBase64 ?? this.photoBase64,
      provider: provider ?? this.provider,
      weeklyBudget: weeklyBudget ?? this.weeklyBudget,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      darkMode: darkMode ?? this.darkMode,
      paletteIndex: paletteIndex ?? this.paletteIndex,
      hasSeenGetStarted: hasSeenGetStarted ?? this.hasSeenGetStarted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (uid != null) 'uid': uid,
      'name': name,
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      'provider': provider,
      'weeklyBudget': weeklyBudget,
      'dietaryPreferences': dietaryPreferences,
      'darkMode': darkMode,
      'paletteIndex': paletteIndex,
      'hasSeenGetStarted': hasSeenGetStarted,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromFirestore(Map<String, dynamic> json, [String? docId]) {
    final createdVal = json['createdAt'];
    DateTime? createdDate;
    if (createdVal is Timestamp) {
      createdDate = createdVal.toDate();
    } else if (createdVal is String) {
      createdDate = DateTime.tryParse(createdVal);
    }

    return AppUser(
      uid: json['uid'] as String? ?? docId,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      photoBase64: json['photoBase64'] as String?,
      provider: json['provider'] as String? ?? 'email',
      weeklyBudget: (json['weeklyBudget'] as num?)?.toDouble() ?? 0.0,
      dietaryPreferences: List<String>.from(json['dietaryPreferences'] ?? []),
      darkMode: json['darkMode'] as bool? ?? false,
      paletteIndex: (json['paletteIndex'] as num?)?.toInt() ?? 0,
      hasSeenGetStarted: json['hasSeenGetStarted'] as bool? ?? true,
      createdAt: createdDate,
    );
  }
}
