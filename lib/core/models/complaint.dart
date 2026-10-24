import 'firestore_time.dart';
import 'location.dart';

/// `complaint.category` (0.3). Contract strings only.
enum ComplaintCategory {
  garbageDump('garbage_dump'),
  openGutter('open_gutter'),
  missedCollection('missed_collection'),
  other('other');

  const ComplaintCategory(this.value);

  /// The exact contract string (0.3).
  final String value;

  /// Parses the contract string; throws on anything else.
  static ComplaintCategory parse(Object? raw, {String field = 'complaints.category'}) {
    if (raw is String) {
      for (final value in values) {
        if (value.value == raw) return value;
      }
    }
    throw FormatException('Unknown $field value: $raw');
  }
}

/// `complaint.status` (0.3). Contract strings only.
enum ComplaintStatus {
  received('received'),
  assigned('assigned'),
  resolved('resolved'),
  escalated('escalated');

  const ComplaintStatus(this.value);

  /// The exact contract string (0.3).
  final String value;

  /// Parses the contract string; throws on anything else.
  static ComplaintStatus parse(Object? raw, {String field = 'complaints.status'}) {
    if (raw is String) {
      for (final value in values) {
        if (value.value == raw) return value;
      }
    }
    throw FormatException('Unknown $field value: $raw');
  }
}

/// `complaint.escalationLevel` (0.3): 0 (inspector), 1 (chief officer or TDO
/// via `wards.escalationTo`), 2 (DDO). Numeric per contract, so kept as `int`
/// — not an enum.
///
/// The `complaints` collection (0.2): id, ticketId, deviceId, category,
/// photoUrl, location, wardId, createdAt, status, assignedTo, escalationLevel,
/// resolvedPhotoUrl, resolvedAt, mergedInto, note.
///
/// Ticket ID format: `PMH-YYYYMMDD-NNNN` (0.1/0.11).


class Complaint {
  final String id;

  final String ticketId;

  final String deviceId;

  final ComplaintCategory category;

  final String? photoUrl;

  final LocationPoint? location;

  final String? wardId;

  final DateTime createdAt;

  final ComplaintStatus status;

  final String? assignedTo;

  final int escalationLevel;

  final String? resolvedPhotoUrl;

  final DateTime? resolvedAt;

  final String? mergedInto;

  final String? note;

  const Complaint({
    required this.id,
    required this.ticketId,
    required this.deviceId,
    required this.category,
    required this.photoUrl,
    required this.location,
    required this.wardId,
    required this.createdAt,
    required this.status,
    required this.assignedTo,
    required this.escalationLevel,
    required this.resolvedPhotoUrl,
    required this.resolvedAt,
    required this.mergedInto,
    required this.note,
  });

  factory Complaint.fromMap(Map<String, Object?> map) {
    final locationRaw = map['location'];
    return Complaint(
      id: map['id'] as String,
      ticketId: map['ticketId'] as String,
      deviceId: map['deviceId'] as String,
      category: ComplaintCategory.parse(map['category']),
      photoUrl: map['photoUrl'] as String?,
      location: locationRaw == null
          ? null
          : LocationPoint.fromMap(
              Map<String, Object?>.from(locationRaw as Map<Object?, Object?>),
            ),
      wardId: map['wardId'] as String?,
      createdAt:
          docTimeToDateTimeRequired(map['createdAt'], 'complaints.createdAt'),
      status: ComplaintStatus.parse(map['status']),
      assignedTo: map['assignedTo'] as String?,
      escalationLevel: (map['escalationLevel'] as num?)?.toInt() ?? 0,
      resolvedPhotoUrl: map['resolvedPhotoUrl'] as String?,
      resolvedAt: docTimeToDateTime(map['resolvedAt']),
      mergedInto: map['mergedInto'] as String?,
      note: map['note'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'ticketId': ticketId,
        'deviceId': deviceId,
        'category': category.value,
        'photoUrl': photoUrl,
        'location': location?.toMap(),
        'wardId': wardId,
        'createdAt': dateTimeToDocTime(createdAt),
        'status': status.value,
        'assignedTo': assignedTo,
        'escalationLevel': escalationLevel,
        'resolvedPhotoUrl': resolvedPhotoUrl,
        'resolvedAt': dateTimeToDocTime(resolvedAt),
        'mergedInto': mergedInto,
        'note': note,
      };

  @override
  bool operator ==(Object other) =>
      other is Complaint &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.ticketId == ticketId &&
      other.deviceId == deviceId &&
      other.category == category &&
      other.photoUrl == photoUrl &&
      other.location == location &&
      other.wardId == wardId &&
      other.createdAt == createdAt &&
      other.status == status &&
      other.assignedTo == assignedTo &&
      other.escalationLevel == escalationLevel &&
      other.resolvedPhotoUrl == resolvedPhotoUrl &&
      other.resolvedAt == resolvedAt &&
      other.mergedInto == mergedInto &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        ticketId,
        deviceId,
        category,
        photoUrl,
        location,
        wardId,
        createdAt,
        status,
        assignedTo,
        escalationLevel,
        resolvedPhotoUrl,
        resolvedAt,
        mergedInto,
        note,
      );

  @override
  String toString() => 'Complaint(${toMap()})';
}
