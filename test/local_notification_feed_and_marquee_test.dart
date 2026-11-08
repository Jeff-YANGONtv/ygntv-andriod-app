import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/auth/local_notification_store.dart';

void main() {
  test(
    'Admin marquee text comes from the existing active public ads route',
    () async {
      final requests = <http.Request>[];
      final service = AuthService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'position': 'header_marquee',
                  'content': 'Myanmar marquee copy',
                },
                {'position': 'top', 'content': 'Not ticker text'},
                {'position': 'header_marquee', 'content': '   '},
              ],
            }),
            200,
          );
        }),
        tokenReader: () async => null,
      );
      addTearDown(service.dispose);

      expect(await service.getHomeMarquee(), 'Myanmar marquee copy');
      expect(requests.single.url.path, '/api/public/ads');
      expect(requests.single.url.queryParameters, {
        'position': 'header_marquee',
      });
    },
  );

  test(
    'blank Admin marquee content returns an empty string for a hidden bar',
    () async {
      final service = AuthService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {'position': 'header_marquee', 'content': '  '},
              ],
            }),
            200,
          ),
        ),
        tokenReader: () async => null,
      );
      addTearDown(service.dispose);

      expect(await service.getHomeMarquee(), isEmpty);
    },
  );

  test(
    'marquee entries preserve Admin-selected colors with a gold fallback',
    () async {
      final service = AuthService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'position': 'header_marquee',
                  'content': 'Blue text',
                  'text_color': '#73C9FF',
                },
                {'position': 'header_marquee', 'content': 'Old text'},
              ],
            }),
            200,
          ),
        ),
        tokenReader: () async => null,
      );
      addTearDown(service.dispose);

      final entries = await service.getHomeMarqueeEntries();
      expect(
        entries.map((entry) => [entry.content, entry.textColor]).toList(),
        [
          ['Blue text', '#73C9FF'],
          ['Old text', '#E8C27E'],
        ],
      );
    },
  );

  test(
    'local unread count combines with API count and drops only after read',
    () async {
      String? localValue;
      final localStore = LocalNotificationStore(
        readValue: () async => localValue,
        writeValue: (next) async => localValue = next,
      );
      await localStore.addNotification(
        title: 'Saved to My List',
        message: 'A title was saved.',
        type: 'library_saved',
      );
      final localId = '${(await localStore.getNotifications()).single['id']}';
      final requests = <http.Request>[];
      final service = AuthService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'notifications': [
                  {
                    'id': 9,
                    'title': 'Support replied',
                    'message': 'Open support chat.',
                    'type': 'support',
                    'created_at': '2026-11-08T00:00:00Z',
                    'read_at': null,
                  },
                ],
                'unread_count': 2,
              },
            }),
            200,
          );
        }),
        tokenReader: () async => 'test-token',
        localNotificationStore: localStore,
      );
      addTearDown(service.dispose);

      final before = await service.getNotifications();
      expect(before.unreadCount, 3);
      expect(before.localUnreadCount, 1);
      expect(before.notifications.where((item) => !item.isRead), hasLength(2));

      final after = await service.markNotificationRead(localId);
      expect(after.unreadCount, 2);
      expect(after.localUnreadCount, 0);
      expect(
        after.notifications.singleWhere((item) => item.id == localId).isRead,
        isTrue,
      );
      expect(requests.every((request) => request.method == 'GET'), isTrue);
    },
  );
}
