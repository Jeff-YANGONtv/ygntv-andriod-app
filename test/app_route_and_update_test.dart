import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/deep_links/app_deep_link.dart';
import 'package:ygntv_customer/services/customer_app_update_service.dart';

void main() {
  group('AppDeepLink.tryParse', () {
    const expectedRoutes = <String, AppDeepLinkDestination>{
      'home': AppDeepLinkDestination.home,
      'movies': AppDeepLinkDestination.movies,
      'series': AppDeepLinkDestination.series,
      'search': AppDeepLinkDestination.search,
      'blog': AppDeepLinkDestination.blog,
      'account': AppDeepLinkDestination.account,
      'library': AppDeepLinkDestination.library,
      'notifications': AppDeepLinkDestination.notifications,
      'subscription': AppDeepLinkDestination.subscription,
      'support': AppDeepLinkDestination.support,
    };

    for (final entry in expectedRoutes.entries) {
      test('accepts the ${entry.key} page link', () {
        final link = AppDeepLink.tryParse(
          Uri.parse('https://ygntv.org/app/${entry.key}'),
        );
        expect(link?.destination, entry.value);
      });
    }

    test('accepts redeem and each library tab', () {
      final redeem = AppDeepLink.tryParse(
        Uri.parse('https://ygntv.org/app/subscription/redeem'),
      );
      expect(redeem?.destination, AppDeepLinkDestination.subscription);
      expect(redeem?.tab, 'redeem');
      for (final tab in ['continue', 'history', 'list', 'offline']) {
        final link = AppDeepLink.tryParse(
          Uri.parse('https://ygntv.org/app/library/$tab'),
        );
        expect(link?.destination, AppDeepLinkDestination.library);
        expect(link?.tab, tab);
      }
    });

    test('accepts transfer, movie, series, and player links', () {
      final transfer = AppDeepLink.tryParse(
        Uri.parse('https://ygntv.org/app/subscription/transfer/monthly'),
      );
      expect(transfer?.destination, AppDeepLinkDestination.manualTransfer);
      expect(transfer?.planKey, 'monthly');
      expect(
        AppDeepLink.tryParse(
          Uri.parse('https://ygntv.org/app/movie/example-film'),
        )?.destination,
        AppDeepLinkDestination.movieDetail,
      );
      expect(
        AppDeepLink.tryParse(
          Uri.parse('https://ygntv.org/app/series/example-show'),
        )?.destination,
        AppDeepLinkDestination.seriesDetail,
      );
      final player = AppDeepLink.tryParse(
        Uri.parse('https://ygntv.org/app/watch/episode/42'),
      );
      expect(player?.destination, AppDeepLinkDestination.videoPlayback);
      expect(player?.contentType, 'episode');
      expect(player?.contentId, 42);
    });

    test(
      'rejects unknown app routes, invalid tabs and invalid playback IDs',
      () {
        for (final url in [
          'https://ygntv.org/app/unknown',
          'https://ygntv.org/app/library/other',
          'https://ygntv.org/app/subscription/invalid',
          'https://ygntv.org/app/watch/movie/0',
          'https://ygntv.org/app/watch/series/5',
          'http://ygntv.org/app/home',
          'https://example.com/app/home',
        ]) {
          expect(AppDeepLink.tryParse(Uri.parse(url)), isNull, reason: url);
        }
      },
    );
  });

  group('AppUpdateRelease.fromJson', () {
    const checksum =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final valid = <String, dynamic>{
      'channel': 'customer-test',
      'package_name': 'org.ygntv.ygntv_customer',
      'version_name': '1.1.4-test',
      'version_code': 2014,
      'apk_url': 'https://ygntv.org/app-updates/customer-test/app.apk',
      'sha256': checksum,
      'release_notes': 'Redeem links and app updates.',
      'size_bytes': 32000000,
    };

    test('accepts a signed HTTPS customer TEST release manifest', () {
      final release = AppUpdateRelease.fromJson(valid);
      expect(release.versionCode, 2014);
      expect(release.channel, 'customer-test');
      expect(release.apkUrl.scheme, 'https');
      expect(release.sha256, checksum);
    });

    test(
      'rejects non-test, wrong-package, unsafe APK and invalid checksum data',
      () {
        for (final changed in [
          {...valid, 'channel': 'production'},
          {...valid, 'package_name': 'other.app'},
          {
            ...valid,
            'apk_url': 'http://ygntv.org/app-updates/customer-test/app.apk',
          },
          {...valid, 'apk_url': 'https://evil.example/app.apk'},
          {...valid, 'sha256': 'not-a-checksum'},
        ]) {
          expect(
            () => AppUpdateRelease.fromJson(changed),
            throwsFormatException,
          );
        }
      },
    );
  });

  group('CustomerAppUpdateService.findAvailableUpdate', () {
    test(
      'does not request the TEST manifest for the production package',
      () async {
        var requestCount = 0;
        final service = CustomerAppUpdateService(
          client: MockClient((request) async {
            requestCount++;
            return http.Response('', 200);
          }),
          packageNameReader: () async => 'org.ygntv.ygntv_customer',
        );

        expect(
          await service.findAvailableUpdate(installedVersionCode: 2018),
          isNull,
        );
        await expectLater(service.fetchLatestRelease(), throwsFormatException);
        expect(requestCount, 0);
      },
    );

    test('checks the TEST manifest for the .test package', () async {
      final requests = <http.Request>[];
      final service = CustomerAppUpdateService(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'channel': 'customer-test',
              'package_name': 'org.ygntv.ygntv_customer',
              'version_name': '1.0-test',
              'version_code': 2019,
              'apk_url':
                  'https://ygntv.org/app-updates/customer-test/app-2019.apk',
              'sha256': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            }),
            200,
          );
        }),
        packageNameReader: () async => 'org.ygntv.ygntv_customer.test',
      );

      final release = await service.findAvailableUpdate(
        installedVersionCode: 2018,
      );

      expect(release?.versionCode, 2019);
      expect(requests.single.url.toString(), customerTestReleaseManifestUrl);
    });
  });
}
