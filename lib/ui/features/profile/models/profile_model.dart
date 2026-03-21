class ProfileModel {
  final String uid;
  final String? displayName;
  final String? email;
  final String languageLevel;
  final List<String> providerIds;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;
  final int conversations;
  final int pronunciationSessions;

  ProfileModel({
    required this.uid,
    this.displayName,
    this.email,
    this.languageLevel = 'B1',
    this.providerIds = const [],
    this.createdAt,
    this.lastLoginAt,
    this.updatedAt,
    this.conversations = 0,
    this.pronunciationSessions = 0,
  });

  factory ProfileModel.fromMap(
    Map<String, dynamic>? map, {
    String? fallbackUid,
  }) {
    if (map == null) {
      return ProfileModel(uid: fallbackUid ?? 'Unknown');
    }

    DateTime? _asDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is double)
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      if (value is Map &&
          value['seconds'] != null &&
          value['nanoseconds'] != null) {
        // Firestore serialized timestamp map in some contexts.
        try {
          final seconds = value['seconds'] as int;
          final nanos = value['nanoseconds'] as int;
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + nanos ~/ 1000000,
          );
        } catch (_) {
          return null;
        }
      }
      try {
        final toDate = value.toDate;
        if (toDate is Function) {
          final result = toDate();
          if (result is DateTime) return result;
        }
      } catch (_) {
        // ignore
      }
      return null;
    }

    return ProfileModel(
      uid: (map['uid'] as String?) ?? fallbackUid ?? 'Unknown',
      displayName: (map['displayName'] as String?)?.trim(),
      email: (map['email'] as String?)?.trim(),
      providerIds:
          (map['providerIds'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: _asDateTime(map['createdAt']),
      lastLoginAt: _asDateTime(map['lastLoginAt']),
      updatedAt: _asDateTime(map['updatedAt']),
      languageLevel: (map['languageLevel'] as String?)?.trim() ?? 'B1',
      conversations: (map['conversations'] is int
          ? map['conversations'] as int
          : 0),
      pronunciationSessions: (map['pronunciationSessions'] is int
          ? map['pronunciationSessions'] as int
          : 0),
    );
  }

  String get displayInitials {
    final source = displayName?.isNotEmpty == true
        ? displayName!
        : (email?.isNotEmpty == true ? email! : 'U');
    return source.substring(0, 1).toUpperCase();
  }

  String get prettyName =>
      displayName?.isNotEmpty == true ? displayName! : 'Guest User';
  String get displayEmail =>
      email?.isNotEmpty == true ? email! : 'No email available';
}
