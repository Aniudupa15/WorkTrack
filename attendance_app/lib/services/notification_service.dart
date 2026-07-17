import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _tokenSubscription;
  bool _initialized = false;

  NotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  Future<void> initialize({required Future<void> Function(String token) onToken}) async {
    if (_initialized) return;
    _initialized = true;
    final permission = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await _messaging.getToken();
    if (token != null) await onToken(token);
    _tokenSubscription = _messaging.onTokenRefresh.listen(onToken);
  }

  Future<void> dispose() async => _tokenSubscription?.cancel();

  Future<void> reset() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _initialized = false;
  }
}
