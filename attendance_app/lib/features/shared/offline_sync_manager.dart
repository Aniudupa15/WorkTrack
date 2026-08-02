import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:attendance_app/data/datasources/connectivity_service.dart';
import 'package:attendance_app/domain/repositories/attendance_repository.dart';

/// Drives replay of queued offline attendance events.
///
/// Once an employee session is known it listens for connectivity changes and
/// flushes the queue whenever the device comes back online; it also flushes
/// immediately on [configure] (e.g. right after login or app start).
class OfflineSyncManager extends ChangeNotifier {
  OfflineSyncManager(this._repo, this._connectivity);

  final AttendanceRepository _repo;
  final ConnectivityService _connectivity;

  String? _companyId;
  StreamSubscription<bool>? _subscription;
  bool _syncing = false;

  int get pendingCount => _repo.pendingSyncCount;

  /// Binds the manager to the signed-in employee's company and starts syncing.
  void configure(String companyId) {
    _companyId = companyId;
    _subscription ??= _connectivity.onOnlineChanged.listen((online) {
      if (online) sync();
    });
    sync();
  }

  /// Flushes the queue if there is anything pending and a company is bound.
  Future<void> sync() async {
    final companyId = _companyId;
    if (companyId == null || _syncing || _repo.pendingSyncCount == 0) return;
    _syncing = true;
    try {
      final synced = await _repo.syncPending(companyId);
      if (synced > 0) notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  /// Stops listening (e.g. on sign-out). Queued events remain on disk.
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _companyId = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
