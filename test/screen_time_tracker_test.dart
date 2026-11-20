import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/auth/screen_time_tracker.dart';

class _RecordingAuthService extends AuthService {
  _RecordingAuthService()
    : super(
        client: MockClient((_) async => http.Response('{}', 200)),
        tokenReader: () async => 'test-token',
      );

  final List<String> events = [];

  @override
  Future<void> recordScreenTime({
    required String sessionId,
    required String event,
  }) async {
    events.add('$event:$sessionId');
  }
}

void main() {
  test(
    'tracker records foreground time only for an authenticated session',
    () async {
      final service = _RecordingAuthService();
      final tracker = ScreenTimeTracker(
        service: service,
        heartbeatInterval: const Duration(milliseconds: 15),
        createSessionId: () => 'test-session',
      );
      addTearDown(service.dispose);

      await tracker.setUserId('42');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(service.events, isEmpty);

      tracker.setAppVisible(true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      tracker.setAppVisible(false);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.events.first, 'start:test-session');
      expect(service.events, contains('heartbeat:test-session'));
      expect(service.events.last, 'end:test-session');
      await tracker.dispose();
    },
  );

  test('sign-out ends the session before the auth token is cleared', () async {
    final service = _RecordingAuthService();
    final tracker = ScreenTimeTracker(
      service: service,
      createSessionId: () => 'signout-session',
    );
    addTearDown(service.dispose);

    tracker.setAppVisible(true);
    await tracker.setUserId('7');
    await tracker.stopForSignOut();

    expect(service.events, ['start:signout-session', 'end:signout-session']);
    await tracker.dispose();
  });
}
