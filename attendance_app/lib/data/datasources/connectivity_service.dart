import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over `connectivity_plus` exposing a simple online/offline view.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> isOnline() async =>
      _isOnline(await _connectivity.checkConnectivity());

  Future<bool> isOffline() async => !await isOnline();

  /// Emits `true` when connectivity becomes available, `false` when lost.
  Stream<bool> get onOnlineChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);
}
