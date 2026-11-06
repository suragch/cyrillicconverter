import 'package:flutter/foundation.dart';

@immutable
class LocalWordEntry {
  final String cyrillic;
  final String menksoft;
  final String? explanation;
  final DateTime createdAt;

  const LocalWordEntry({
    required this.cyrillic,
    required this.menksoft,
    this.explanation,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'cyrillic': cyrillic,
      'menksoft': menksoft,
      if (explanation != null) 'explanation': explanation,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalWordEntry.fromJson(Map<String, dynamic> json) {
    return LocalWordEntry(
      cyrillic: json['cyrillic'] as String? ?? '',
      menksoft: json['menksoft'] as String? ?? '',
      explanation: json['explanation'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  LocalWordEntry copyWith({
    String? cyrillic,
    String? menksoft,
    String? explanation,
    DateTime? createdAt,
  }) {
    return LocalWordEntry(
      cyrillic: cyrillic ?? this.cyrillic,
      menksoft: menksoft ?? this.menksoft,
      explanation: explanation ?? this.explanation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LocalWordEntry &&
        other.runtimeType == runtimeType &&
        other.cyrillic == cyrillic &&
        other.menksoft == menksoft &&
        other.explanation == explanation &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(cyrillic, menksoft, explanation, createdAt);
  }
}
