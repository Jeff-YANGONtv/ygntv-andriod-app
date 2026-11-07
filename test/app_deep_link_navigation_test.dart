import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/deep_links/app_deep_link.dart';
import 'package:ygntv_customer/screens/customer_home_screen.dart';

class _DeepLinkTestService extends AuthService {
  _DeepLinkTestService()
    : super(client: MockClient((_) async => http.Response('{}', 200)));

  String? lastLoadedKind;
  String? lastLoadedSlug;

  @override
  Future<List<CatalogItem>> loadCatalog(
    String kind, {
    int page = 1,
    int perPage = 48,
  }) async => const [];

  @override
  Future<List<TvLibraryEntry>> getContinueWatching() async => const [];

  @override
  Future<List<TvHomeBanner>> getHeroBanners({String position = 'top'}) async =>
      const [];

  @override
  Future<TvNotificationFeed> getNotifications() async =>
      const TvNotificationFeed(notifications: [], unreadCount: 0);

  @override
  Future<CatalogItem> loadDetail(CatalogItem item) async {
    lastLoadedKind = item.kind;
    lastLoadedSlug = item.slug;
    return CatalogItem(
      id: 1,
      title: item.kind == 'movie' ? 'Linked Movie' : 'Linked Series',
      posterUrl: '',
      kind: item.kind,
      slug: item.slug,
    );
  }
}

class _HomeHarness {
  const _HomeHarness({required this.service, required this.event});

  final _DeepLinkTestService service;
  final ValueNotifier<AppDeepLink?> event;
}

Future<_HomeHarness> _mountHome(WidgetTester tester) async {
  final service = _DeepLinkTestService();
  final event = ValueNotifier<AppDeepLink?>(null);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: CustomerHomeScreen(
        session: const AuthSession(
          token: 'test',
          userId: '1',
          name: 'Test Viewer',
          email: 'viewer@example.com',
        ),
        authService: service,
        onSignOut: () async {},
        deepLinkEvent: event,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _HomeHarness(service: service, event: event);
}

void main() {
  testWidgets('movies catalogue link selects the Movies tab', (tester) async {
    final home = await _mountHome(tester);
    home.event.value = const AppDeepLink(
      destination: AppDeepLinkDestination.movies,
    );
    await tester.pumpAndSettle();

    expect(find.text('Movies to discover'), findsOneWidget);
  });

  testWidgets('series catalogue link selects the Series tab', (tester) async {
    final home = await _mountHome(tester);
    home.event.value = const AppDeepLink(
      destination: AppDeepLinkDestination.series,
    );
    await tester.pumpAndSettle();

    expect(find.text('Series to binge'), findsOneWidget);
  });

  testWidgets('movie slug link opens the matching movie detail', (
    tester,
  ) async {
    final home = await _mountHome(tester);
    home.event.value = const AppDeepLink(
      destination: AppDeepLinkDestination.movieDetail,
      slug: 'sample-film',
    );
    await tester.pumpAndSettle();

    expect(home.service.lastLoadedKind, 'movie');
    expect(home.service.lastLoadedSlug, 'sample-film');
    expect(find.text('Linked Movie'), findsOneWidget);
  });

  testWidgets('series slug link opens the matching series detail', (
    tester,
  ) async {
    final home = await _mountHome(tester);
    home.event.value = const AppDeepLink(
      destination: AppDeepLinkDestination.seriesDetail,
      slug: 'sample-show',
    );
    await tester.pumpAndSettle();

    expect(home.service.lastLoadedKind, 'series');
    expect(home.service.lastLoadedSlug, 'sample-show');
    expect(find.text('Linked Series'), findsOneWidget);
  });
}
