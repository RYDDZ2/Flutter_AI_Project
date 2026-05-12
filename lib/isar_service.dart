import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'data/isar/schema.dart';

class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  Isar? _isar;

  Future<Isar> open() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        PlaceSchema,
        ManualObjectSchema,
        DetectionSnapshotSchema,
        DetectionLabelCountSchema,
      ],
      directory: dir.path,
    );
    return _isar!;
  }

  Future<int> createPlace({
    required String name,
    String? note,
  }) async {
    final isar = await open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final place = Place()
      ..name = name
      ..note = note
      ..createdAtMs = now
      ..updatedAtMs = now;

    return isar.writeTxn(() async {
      return await isar.places.put(place);
    });
  }

  Future<List<Place>> getPlaces() async {
    final isar = await open();
    return isar.places.where().sortByUpdatedAtMsDesc().findAll();
  }

  Future<Place?> getPlace(int id) async {
    final isar = await open();
    return isar.places.get(id);
  }

  Future<void> updatePlace({
    required int id,
    required String name,
    String? note,
  }) async {
    final isar = await open();
    final now = DateTime.now().millisecondsSinceEpoch;

    await isar.writeTxn(() async {
      final place = await isar.places.get(id);
      if (place == null) return;

      place
        ..name = name
        ..note = note
        ..updatedAtMs = now;

      await isar.places.put(place);
    });
  }

  Future<void> deletePlace(int id) async {
    final isar = await open();

    await isar.writeTxn(() async {
      await isar.manualObjects.filter().placeIdEqualTo(id).deleteAll();
      await isar.detectionSnapshots.filter().placeIdEqualTo(id).deleteAll();
      await isar.detectionLabelCounts.filter().snapshotIdEqualTo(-1).deleteAll(); // no-op safeguard
      await isar.places.delete(id);
    });
  }

  Future<void> addManualObject({
    required int placeId,
    required String label,
    int count = 1,
  }) async {
    final isar = await open();
    final now = DateTime.now().millisecondsSinceEpoch;

    await isar.writeTxn(() async {
      final manualObject = ManualObject()
        ..placeId = placeId
        ..label = label
        ..count = count
        ..createdAtMs = now
        ..updatedAtMs = now;

      await isar.manualObjects.put(manualObject);
    });
  }

  Future<List<ManualObject>> getManualObjectsByPlace(int placeId) async {
    final isar = await open();

    final all = await isar.manualObjects.where().findAll();
    return all.where((m) => m.placeId == placeId).toList(growable: false);
  }

  Future<void> deleteManualObjectById(int manualObjectId) async {
    final isar = await open();

    await isar.writeTxn(() async {
      await isar.manualObjects.delete(manualObjectId);
    });
  }

  /// Simple delete-by-place (used when replacing manual labels)
  Future<void> deleteManualObjectsByPlace(int placeId) async {
    final isar = await open();

    await isar.writeTxn(() async {
      final all = await isar.manualObjects.where().findAll();
      final toDelete = all.where((m) => m.placeId == placeId);
      for (final m in toDelete) {
        await isar.manualObjects.delete(m.id);
      }
    });
  }

  /// Mengambil semua label unik (manual + deteksi) untuk satu tempat.
  Future<List<String>> getUniqueLabelsByPlace(int placeId) async {
    final isar = await open();

    // Ambil dari manual objects
    final manuals = await isar.manualObjects.filter().placeIdEqualTo(placeId).findAll();
    final manualLabels = manuals.map((e) => e.label.trim()).where((e) => e.isNotEmpty).toSet();

    // Ambil dari detection snapshots
    final snapshots = await isar.detectionSnapshots.filter().placeIdEqualTo(placeId).findAll();
    final snapshotIds = snapshots.map((s) => s.id).toList();

    final detectedLabels = <String>{};
    if (snapshotIds.isNotEmpty) {
      final labelCounts = await isar.detectionLabelCounts
          .filter()
          .anyOf(snapshotIds, (q, int id) => q.snapshotIdEqualTo(id))
          .findAll();
      detectedLabels.addAll(labelCounts.map((l) => l.label.trim()).where((e) => e.isNotEmpty));
    }

    final allLabels = manualLabels.union(detectedLabels).toList();
    allLabels.sort();
    return allLabels;
  }

  /// Menghapus label tertentu dari semua sumber (manual & deteksi) di satu tempat.
  Future<void> deleteLabelFromPlace(int placeId, String label) async {
    final isar = await open();
    await isar.writeTxn(() async {
      // 1. Hapus dari ManualObject
      await isar.manualObjects
          .filter()
          .placeIdEqualTo(placeId)
          .labelEqualTo(label)
          .deleteAll();

      // 2. Hapus dari DetectionLabelCount (cari snapshot milik tempat ini dulu)
      final snapshots = await isar.detectionSnapshots.filter().placeIdEqualTo(placeId).findAll();
      final ids = snapshots.map((s) => s.id).toList();
      if (ids.isNotEmpty) {
        await isar.detectionLabelCounts
            .filter()
            .anyOf(ids, (q, int id) => q.snapshotIdEqualTo(id))
            .labelEqualTo(label)
            .deleteAll();
      }
    });
  }
}
