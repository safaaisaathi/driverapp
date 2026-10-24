import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Normalization between doc-map values and model [DateTime] fields.
///
/// The contract (0.2) stores timestamps with Firestore Timestamp semantics.
/// Live Firestore maps therefore contain [Timestamp] values, while emulated
/// stubs used in tests may carry epoch-millis (`int`), millis-as-`String`,
/// ISO-8601 strings or plain [DateTime]. Every parser in the model layer goes
/// through this file so `fromMap` accepts all of those encodings and
/// `fromMap ∘ toMap` round-trips hold for both emulated and live doc maps.
///
/// Parsed values are always returned as local DateTime at microsecond
/// resolution so `==` holds after a `fromMap → toMap → fromMap` cycle.


/// Parses a doc-map timestamp value; `null` passes through as `null`.
DateTime? docTimeToDateTime(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return _normalize(value.toDate());
  if (value is DateTime) return _normalize(value);
  if (value is num) {
    return _normalize(DateTime.fromMillisecondsSinceEpoch(value.round()));
  }
  if (value is String) {
    final asMillis = int.tryParse(value);
    if (asMillis != null) {
      return _normalize(DateTime.fromMillisecondsSinceEpoch(asMillis));
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return _normalize(parsed);
  }
  throw FormatException('Not a timestamp value in a doc map: $value');
}

/// Like [docTimeToDateTime] but for fields the contract requires (0.2).
DateTime docTimeToDateTimeRequired(Object? value, String field) {
  final parsed = docTimeToDateTime(value);
  if (parsed == null) {
    throw FormatException('Missing required timestamp field "$field" in doc map');
  }
  return parsed;
}

/// Converts a model [DateTime] back to the contract's Timestamp semantics so
/// `toMap()` output is directly writable to live Firestore.
Timestamp? dateTimeToDocTime(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);

DateTime _normalize(DateTime source) => DateTime.fromMicrosecondsSinceEpoch(
      source.microsecondsSinceEpoch,
    );
