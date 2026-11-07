import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

void main() {
  test('support chat uses the authenticated YGNTV API contract', () async {
    const token = 'supportToken123456789012345678901';
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/support/conversations') {
        return http.Response(
          jsonEncode({
            'conversations': [
              {'public_token': token, 'status': 'open', 'messages_count': 1},
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/support/start') {
        return http.Response(
          jsonEncode({
            'conversation': {'public_token': token, 'status': 'open'},
            'messages': [
              {'id': 1, 'sender_type': 'admin', 'body': 'How can we help?'},
            ],
            'next_after_id': 1,
          }),
          201,
        );
      }
      if (request.url.path == '/api/support/$token/messages' &&
          request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'conversation': {'public_token': token, 'status': 'open'},
            'messages': [
              {
                'id': 2,
                'sender_type': 'admin',
                'body': 'We are checking that for you.',
              },
            ],
            'next_after_id': 2,
          }),
          200,
        );
      }
      if (request.url.path == '/api/support/$token/messages' &&
          request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'message': {'id': 3, 'sender_type': 'visitor', 'body': 'Thanks'},
          }),
          201,
        );
      }
      return http.Response('Not found', 404);
    });
    final service = AuthService(
      client: client,
      tokenReader: () async => 'test-session-token',
    );
    addTearDown(service.dispose);

    final conversations = await service.getSupportConversations();
    expect(conversations.single.publicToken, token);
    expect(conversations.single.messagesCount, 1);

    final started = await service.startSupportConversation();
    expect(started.publicToken, token);
    expect(started.messages.single.body, 'How can we help?');

    final page = await service.getSupportMessages(token, afterId: 1);
    expect(page.messages.single.body, 'We are checking that for you.');
    expect(page.nextAfterId, 2);

    final sent = await service.sendSupportMessage(token, '  Thanks  ');
    expect(sent.body, 'Thanks');

    expect(requests, hasLength(4));
    expect(
      requests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer test-session-token',
      ),
      isTrue,
    );
    expect(requests[2].url.queryParameters['after_id'], '1');
    expect(jsonDecode(requests.last.body)['body'], 'Thanks');
  });
}
