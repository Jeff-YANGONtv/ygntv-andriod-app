import 'dart:async';

import 'package:uuid/uuid.dart';

import 'auth_service.dart';

class ScreenTimeTracker {
  ScreenTimeTracker({
    required AuthService service,
    Duration heartbeatInterval = const Duration(seconds: 60),
    String Function()? createSessionId,
  }) : this._(service, heartbeatInterval, createSessionId);

  ScreenTimeTracker._(
    this._service,
    this._heartbeatInterval,
    String Function()? createSessionId,
  ) : _createSessionId = createSessionId ?? (() => const Uuid().v4());

  final AuthService _service;
  final Duration _heartbeatInterval;
  final String Function() _createSessionId;
  String? _userId;
  String? _activeSessionId;
  bool _appVisible = false;
  bool _disposed = false;
  Timer? _timer;
  Future<void> _requests = Future<void>.value();

  Future<void> setUserId(String? userId) async {
    if (_userId == userId) return;
    _userId = userId;
    await _stopCurrentSession();
    if (!_disposed && _userId == userId && userId != null && _appVisible) {
      _startSession();
    }
  }

  void setAppVisible(bool visible) {
    if (_disposed || _appVisible == visible) return;
    _appVisible = visible;
    if (!visible) {
      unawaited(_stopCurrentSession());
    } else if (_userId != null && _activeSessionId == null) {
      _startSession();
    }
  }

  Future<void> stopForSignOut() async {
    _userId = null;
    await _stopCurrentSession().timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  void _startSession() {
    if (_disposed ||
        !_appVisible ||
        _userId == null ||
        _activeSessionId != null) {
      return;
    }
    final sessionId = _createSessionId();
    _activeSessionId = sessionId;
    _queueEvent(sessionId, 'start');
    _timer?.cancel();
    _timer = Timer.periodic(_heartbeatInterval, (_) {
      if (_activeSessionId == sessionId && _appVisible) {
        _queueEvent(sessionId, 'heartbeat');
      }
    });
  }

  Future<void> _stopCurrentSession() async {
    _timer?.cancel();
    _timer = null;
    final sessionId = _activeSessionId;
    _activeSessionId = null;
    if (sessionId != null) await _queueEvent(sessionId, 'end');
  }

  Future<void> _queueEvent(String sessionId, String event) {
    _requests = _requests.then((_) async {
      try {
        await _service.recordScreenTime(sessionId: sessionId, event: event);
      } catch (_) {
        // Screen-time recording is best-effort and must never block app use.
      }
    });
    return _requests;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _appVisible = false;
    _userId = null;
    await _stopCurrentSession();
  }
}
