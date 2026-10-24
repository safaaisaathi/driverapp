/// Hive [TypeAdapter] for Firestore `Timestamp` values inside buffered doc
/// maps (F-D7 durability enabler).
///
/// WHY: the durable Trail buffer stores `GpsPoint.toMap()` records, whose
/// contract `t` field is a Firestore `Timestamp` (`firestore_time.dart`
/// round-trip semantics). Hive cannot serialize Firestore types by default
/// ("Cannot write, unknown type: Timestamp"), so EVERY trail-box write
/// fails unless this adapter is registered ONCE before the first
/// `Hive.openBox` — see the bootstrap step in the ticket 12 report.
///
/// Encoded as epoch-milliseconds; `GpsPoint.fromMap` re-parses `Timestamp`
/// values natively on read, so the model round-trip is untouched.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:hive/hive.dart';

/// TypeId for the adapter (user space: below Hive's 224 cutoff, far from
/// the built-in ids); never change or reuse once data is on disk.
class FirestoreTimestampAdapter extends TypeAdapter<Timestamp> {
  FirestoreTimestampAdapter();

  @override
  int get typeId => 207;

  @override
  Timestamp read(BinaryReader reader) =>
      Timestamp.fromMillisecondsSinceEpoch(reader.readInt());

  @override
  void write(BinaryWriter writer, Timestamp obj) =>
      writer.writeInt(obj.millisecondsSinceEpoch);
}
