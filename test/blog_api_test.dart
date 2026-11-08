import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';

void main() {
  test('loads and maps public blog posts from the existing API', () async {
    late Uri requestedUri;
    final service = AuthService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'data': {
              'data': [
                {
                  'id': 24,
                  'slug': 'sample-story',
                  'title': 'A YGNTV story',
                  'excerpt': 'A short preview.',
                  'date': '2026-11-08',
                  'topic': 'Updates',
                  'author': 'Yangon TV',
                  'cover': '/storage/blog/cover.webp',
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final posts = await service.getBlogPosts();

    expect(requestedUri.path, '/api/public/blogs');
    expect(requestedUri.queryParameters['page'], '1');
    expect(posts, hasLength(1));
    expect(posts.single.id, '24');
    expect(posts.single.slug, 'sample-story');
    expect(posts.single.category, 'Updates');
    expect(posts.single.image, 'https://api.ygntv.org/storage/blog/cover.webp');
    service.dispose();
  });

  test(
    'loads a blog article by its slug for native detail navigation',
    () async {
      late Uri requestedUri;
      final service = AuthService(
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'data': {
                'id': 25,
                'slug': 'deep-link-story',
                'title': 'A linked story',
                'content': 'Article text stays inside the app.',
              },
            }),
            200,
          );
        }),
      );

      final post = await service.getBlogPost('deep-link-story');

      expect(requestedUri.path, '/api/public/blogs/deep-link-story');
      expect(post.slug, 'deep-link-story');
      expect(post.content, 'Article text stays inside the app.');
      service.dispose();
    },
  );
}
