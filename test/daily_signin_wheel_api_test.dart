import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

void main() {
  test('wheel overview uses the signed-in customer token', () async {
    late http.Request captured;
    final service = AuthService(
      tokenReader: () async => 'customer-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'can_spin': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.getDailySignInWheelOverview();

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/tv/daily-signin-wheel');
    expect(captured.headers['authorization'], 'Bearer customer-token');
    expect(result['can_spin'], isTrue);
    service.dispose();
  });

  test(
    'spin sends only an idempotency key; prize remains server-generated',
    () async {
      late http.Request captured;
      final service = AuthService(
        tokenReader: () async => 'customer-token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'spin': {'reward_code': 'one_movie'},
                'overview': {'can_spin': false},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.spinDailySignInWheel(
        spinKey: 'fa8eb71a-4da0-4c09-9b8f-123456789012',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/tv/daily-signin-wheel/spin');
      expect(captured.headers['authorization'], 'Bearer customer-token');
      expect(jsonDecode(captured.body), {
        'spin_key': 'fa8eb71a-4da0-4c09-9b8f-123456789012',
      });
      expect(result['spin']['reward_code'], 'one_movie');
      service.dispose();
    },
  );

  test('spin surfaces Laravel 429 and does not retry the POST', () async {
    var requestCount = 0;
    final service = AuthService(
      tokenReader: () async => 'customer-token',
      client: MockClient((request) async {
        requestCount++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/tv/daily-signin-wheel/spin');
        return http.Response(
          jsonEncode({'message': 'Too Many Attempts.'}),
          429,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      service.spinDailySignInWheel(
        spinKey: 'fa8eb71a-4da0-4c09-9b8f-123456789012',
      ),
      throwsA(
        isA<AuthException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having((error) => error.message, 'message', 'Too Many Attempts.'),
      ),
    );
    expect(requestCount, 1);
    service.dispose();
  });

  test('options are fetched with type, page, and search parameters', () async {
    late http.Request captured;
    final service = AuthService(
      tokenReader: () async => 'customer-token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'items': [
                {'id': 2, 'title': 'Movie'},
              ],
              'page': 2,
              'has_more': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.getDailyWheelOptions(
      spinId: 'spin-1',
      type: 'movie',
      page: 2,
      search: 'space opera',
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/tv/daily-signin-wheel/spin-1/options');
    expect(captured.url.queryParameters, {
      'type': 'movie',
      'page': '2',
      'search': 'space opera',
    });
    expect(result['items'], hasLength(1));
    expect(result['has_more'], isTrue);
    service.dispose();
  });

  test(
    'episode options use the singular API type and parse the item payload',
    () async {
      late http.Request captured;
      final service = AuthService(
        tokenReader: () async => 'customer-token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 7,
                    'title': 'Episode 1',
                    'subtitle': 'Episode · Season 1',
                  },
                ],
                'page': 1,
                'per_page': 20,
                'has_more': false,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.getDailyWheelOptions(
        spinId: '12',
        type: 'episode',
        page: 1,
      );

      expect(captured.url.path, '/api/tv/daily-signin-wheel/12/options');
      expect(captured.url.queryParameters, {'type': 'episode', 'page': '1'});
      expect(captured.headers['authorization'], 'Bearer customer-token');
      expect(result['items'], hasLength(1));
      expect(result['items'].single['title'], 'Episode 1');
      service.dispose();
    },
  );

  test(
    'malformed options success response throws instead of appearing empty',
    () async {
      final service = AuthService(
        tokenReader: () async => 'customer-token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {'page': 1, 'has_more': false},
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        service.getDailyWheelOptions(spinId: '12', type: 'episode', page: 1),
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            'invalid_reward_options',
          ),
        ),
      );
      service.dispose();
    },
  );

  test(
    'options HTTP errors preserve their status instead of returning items',
    () async {
      final service = AuthService(
        tokenReader: () async => 'customer-token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'success': false, 'message': 'Service unavailable'}),
            503,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        service.getDailyWheelOptions(spinId: '12', type: 'episode', page: 1),
        throwsA(
          isA<AuthException>().having(
            (error) => error.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
      service.dispose();
    },
  );

  test(
    'movie and episode selections send immutable plural ID payloads',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final service = AuthService(
        tokenReader: () async => 'customer-token',
        client: MockClient((request) async {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'selection_status': 'selected'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await service.commitDailyWheelSelection(
        spinId: 'spin-2',
        type: 'movie',
        contentIds: [11, 12, 13],
      );
      await service.commitDailyWheelSelection(
        spinId: 'spin-3',
        type: 'episode',
        contentIds: [21, 22],
      );
      expect(bodies, [
        {
          'type': 'movie',
          'content_ids': [11, 12, 13],
        },
        {
          'type': 'episode',
          'content_ids': [21, 22],
        },
      ]);
      service.dispose();
    },
  );

  test('whole-season selection sends a season ID only', () async {
    late Map<String, dynamic> body;
    final service = AuthService(
      tokenReader: () async => 'customer-token',
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'data': {}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await service.commitDailyWheelSelection(
      spinId: 'spin-4',
      type: 'season',
      seasonId: 31,
    );
    expect(body, {'type': 'season', 'season_id': 31});
    service.dispose();
  });

}
