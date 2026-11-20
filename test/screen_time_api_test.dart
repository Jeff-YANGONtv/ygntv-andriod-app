import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

void main() {
  test('screen-time events use the signed-in TV device endpoint', () async {
    final requests = <http.Request>[];
    final service = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'success': true, 'data': {'duration_seconds': 60}}),
          200,
        );
      }),
      tokenReader: () async => 'signed-in-device-token',
    );
    addTearDown(service.dispose);

    await service.recordScreenTime(
      sessionId: 'a1bd17e8-3d77-4d23-a1ec-5de937ed6801',
      event: 'heartbeat',
    );

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/tv/screen-time');
    expect(requests.single.headers['authorization'], 'Bearer signed-in-device-token');
    expect(jsonDecode(requests.single.body), {
      'session_id': 'a1bd17e8-3d77-4d23-a1ec-5de937ed6801',
      'event': 'heartbeat',
    });
  });

  test('profile data exposes the 30-day screen-time total and device allowance', () {
    final profile = TvProfileData.fromJson({
      'user': {'name': 'Viewer', 'email': 'viewer@example.com'},
      'profile': {'display_name': 'Viewer'},
      'entitlement': {},
      'devices': [],
      'device_limit': 2,
      'screen_time': {'last_30_days_seconds': 3720},
    });

    expect(profile.screenTimeLast30DaysSeconds, 3720);
    expect(profile.deviceLimit, 2);
  });
}
