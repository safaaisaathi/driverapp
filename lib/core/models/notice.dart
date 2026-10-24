import 'firestore_time.dart';

/// `notice.targetType` (0.3). Contract strings only: van | ward | all.
enum NoticeTargetType {
  van('van'),
  ward('ward'),
  all('all');

  const NoticeTargetType(this.value);

  /// The exact contract string (0.3).
  final String value;

  /// Parses the contract string; throws on anything else.
  static NoticeTargetType parse(Object? raw, {String field = 'notices.targetType'}) {
    if (raw is String) {
      for (final value in values) {
        if (value.value == raw) return value;
      }
    }
    throw FormatException('Unknown $field value: $raw');
  }
}

/// The `notices` collection (0.2): id, targetType, targetId, message,
/// createdAt, createdBy.
///
/// A Notice is a one-way message an admin sends to a van (targetType `van`), to
/// a ward (targetType `ward`), or to everyone (targetType `all`, where
/// `targetId` carries no addressee).


class Notice {
  final String id;

  final NoticeTargetType targetType;

  /// The addressed van or ward id; null for targetType `all`.
  final String? targetId;

  final String message;

  final DateTime createdAt;

  final String createdBy;

  const Notice({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.message,
    required this.createdAt,
    required this.createdBy,
  });

  factory Notice.fromMap(Map<String, Object?> map) => Notice(
        id: map['id'] as String,
        targetType: NoticeTargetType.parse(map['targetType']),
        targetId: map['targetId'] as String?,
        message: map['message'] as String,
        createdAt:
            docTimeToDateTimeRequired(map['createdAt'], 'notices.createdAt'),
        createdBy: map['createdBy'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'targetType': targetType.value,
        'targetId': targetId,
        'message': message,
        'createdAt': dateTimeToDocTime(createdAt),
        'createdBy': createdBy,
      };

  @override
  bool operator ==(Object other) =>
      other is Notice &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.targetType == targetType &&
      other.targetId == targetId &&
      other.message == message &&
      other.createdAt == createdAt &&
      other.createdBy == createdBy;

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, targetType, targetId, message, createdAt, createdBy);

  @override
  String toString() => 'Notice(${toMap()})';
}
