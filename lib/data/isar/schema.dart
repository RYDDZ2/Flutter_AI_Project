import 'package:isar/isar.dart';

part 'schema.g.dart';

/// Places that user can create (tempat).
@collection
class Place {
  Id id = Isar.autoIncrement;

  /// Display name: "Kandang A", "Kebun", dst.
  late String name;

  /// Optional note.
  String? note;

  /// Created at (unix ms).
  late int createdAtMs;

  /// Last updated at (unix ms).
  late int updatedAtMs;
}

/// Manual objects inside a place (user input).
@collection
class ManualObject {
  Id id = Isar.autoIncrement;

  /// Place FK
  late int placeId;

  /// Object label: bebas (misal: "kucing", "orang", "burung", dst)
  late String label;

  /// Count for this label at manual entry.
  late int count;

  /// Created at (unix ms).
  late int createdAtMs;

  /// Updated at (unix ms).
  late int updatedAtMs;
}

/// Result snapshot when running detection (from images upload / realtime mode).
@collection
class DetectionSnapshot {
  Id id = Isar.autoIncrement;

  /// Place FK
  late int placeId;

  /// Source type: "upload", "realtime", "manual_yolo"
  late String sourceType;

  /// Timestamp of the snapshot (unix ms).
  late int timestampMs;

  /// Total count for this snapshot (sum over labels).
  late int totalCount;

  /// JSON-encoded map {label: count}. (Isar doesn't store Map<String,int> directly without extra modeling.)
  late String countsJson;
}

/// Individual per-label counts derived from a snapshot (optional but useful for UI querying).
@collection
class DetectionLabelCount {
  Id id = Isar.autoIncrement;

  /// Snapshot FK
  late int snapshotId;

  late String label;
  late int count;
}
