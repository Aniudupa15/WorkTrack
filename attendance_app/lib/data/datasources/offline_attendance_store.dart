import 'package:hive_flutter/hive_flutter.dart';

/// Local, durable queue of attendance events captured while offline.
///
/// Events are stored as plain maps (no generated Hive adapters needed) keyed by
/// a client-generated id so a sync result can remove exactly what succeeded.
class OfflineAttendanceStore {
  OfflineAttendanceStore(this._box);

  static const String boxName = 'offline_attendance';

  final Box _box;

  /// Adds an event to the queue.
  Future<void> add(Map<String, dynamic> event) async {
    final clientId = event['clientId'] as String;
    await _box.put(clientId, Map<String, dynamic>.from(event));
  }

  /// All queued events, oldest first (Hive preserves insertion order).
  List<Map<String, dynamic>> all() => _box.values
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList(growable: false);

  int get length => _box.length;

  bool get isEmpty => _box.isEmpty;

  Future<void> remove(String clientId) => _box.delete(clientId);

  Future<void> clear() => _box.clear();
}
