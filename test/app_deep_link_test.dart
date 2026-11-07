import 'package:flutter_test/flutter_test.dart';
import 'package:ygntv_customer/deep_links/app_deep_link.dart';

void main() {
  group('AppDeepLink.tryParse', () {
    test('accepts the movies catalogue route', () {
      final link = AppDeepLink.tryParse(
        Uri.parse('https://ygntv.org/app/movies'),
      );

      expect(link?.destination, AppDeepLinkDestination.movies);
      expect(link?.slug, isNull);
    });

    test('accepts the series catalogue route', () {
      final link = AppDeepLink.tryParse(
        Uri.parse('https://ygntv.org/app/series'),
      );

      expect(link?.destination, AppDeepLinkDestination.series);
      expect(link?.slug, isNull);
    });

    test('accepts a movie detail slug and query parameters', () {
      final link = AppDeepLink.tryParse(
        Uri.parse('https://ygntv.org/app/movie/example-film?from=banner'),
      );

      expect(link?.destination, AppDeepLinkDestination.movieDetail);
      expect(link?.slug, 'example-film');
    });

    test('accepts a series detail slug on the www host', () {
      final link = AppDeepLink.tryParse(
        Uri.parse('https://www.ygntv.org/app/series/example-show'),
      );

      expect(link?.destination, AppDeepLinkDestination.seriesDetail);
      expect(link?.slug, 'example-show');
    });

    test('rejects non-HTTPS and unrelated hosts', () {
      expect(
        AppDeepLink.tryParse(Uri.parse('http://ygntv.org/app/movies')),
        isNull,
      );
      expect(
        AppDeepLink.tryParse(Uri.parse('https://example.com/app/movies')),
        isNull,
      );
    });

    test('rejects unknown, incomplete, and overlong routes', () {
      for (final url in [
        'https://ygntv.org/app',
        'https://ygntv.org/app/movie',
        'https://ygntv.org/app/movies/extra',
        'https://ygntv.org/app/blog/story',
        'https://ygntv.org/app/movie/../other',
      ]) {
        expect(AppDeepLink.tryParse(Uri.parse(url)), isNull, reason: url);
      }
    });
  });
}
