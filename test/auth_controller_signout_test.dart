import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_controller.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

class _HangingLogoutService extends AuthService {
  _HangingLogoutService()
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  bool sessionCleared = false;

  @override
  Future<void> logout() => Completer<void>().future;

  @override
  Future<void> clearSession() async {
    sessionCleared = true;
  }
}

void main() {
  test('sign out completes locally when telemetry and logout hang', () async {
    final service = _HangingLogoutService();
    final controller = AuthController(service)
      ..session = const AuthSession(
        token: 'test-token',
        userId: '1',
        name: 'Test Viewer',
        email: 'viewer@example.com',
      )
      ..beforeSignOut = () => Completer<void>().future;
    addTearDown(controller.dispose);

    final timer = Stopwatch()..start();
    await controller.signOut();

    expect(timer.elapsed, lessThan(const Duration(seconds: 4)));
    expect(service.sessionCleared, isTrue);
    expect(controller.session, isNull);
  });
}
