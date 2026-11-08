import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ygntv_customer/auth/auth_service.dart';
import 'package:ygntv_customer/deep_links/app_deep_link.dart';
import 'package:ygntv_customer/screens/customer_home_screen.dart';

class _DeepLinkTestService extends AuthService {
  _DeepLinkTestService({
    this.banners = const [],
    this.blogPosts = const [],
    this.article,
  }) : super(client: MockClient((_) async => http.Response('{}', 200)));

  final List<TvHomeBanner> banners;
  final List<TvBlogPost> blogPosts;
  final TvBlogPost? article;
  String? lastLoadedKind;
  String? lastLoadedSlug;
  String? lastBlogSlug;

  @override
  Future<List<CatalogItem>> loadCatalog(
    String kind, {
    int page = 1,
    int perPage = 48,
  }) async => const [];

  @override
  Future<List<TvLibraryEntry>> getContinueWatching() async => const [];

  @override
  Future<List<TvHomeBanner>> getTopAdBanners() async => banners;

  @override
  Future<List<TvBlogPost>> getBlogPosts({int page = 1}) async => blogPosts;

  @override
  Future<TvBlogPost> getBlogPost(String slug) async {
    lastBlogSlug = slug;
    return article ??
        TvBlogPost(
          id: '4',
          slug: slug,
          title: 'Linked Blog Story',
          excerpt: 'A short linked story.',
          date: '2026-11-08',
          category: 'Updates',
          author: 'Yangon TV',
          image: '',
          content: 'The article opens inside the app.',
        );
  }

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

Future<_HomeHarness> _mountHome(
  WidgetTester tester, {
  List<TvHomeBanner> banners = const [],
  List<TvBlogPost> blogPosts = const [],
  TvBlogPost? article,
}) async {
  final service = _DeepLinkTestService(
    banners: banners,
    blogPosts: blogPosts,
    article: article,
  );
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

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('catalog-page-title')))
          .data,
      'Movie',
    );
  });

  testWidgets('series catalogue link selects the Series tab', (tester) async {
    final home = await _mountHome(tester);
    home.event.value = const AppDeepLink(
      destination: AppDeepLinkDestination.series,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('catalog-page-title')))
          .data,
      'Series',
    );
  });

  testWidgets('Blog deep link selects the Blog tab', (tester) async {
    final home = await _mountHome(tester);
    home.event.value = const AppDeepLink(
      destination: AppDeepLinkDestination.blog,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Stories, updates, and notes from YGNTV.'),
      findsOneWidget,
    );
  });

  testWidgets('exact Blog deep link opens the story inside the app', (
    tester,
  ) async {
    final home = await _mountHome(tester);
    home.event.value = const AppDeepLink(
      destination: AppDeepLinkDestination.blog,
      slug: 'deep-link-story',
    );
    await tester.pumpAndSettle();

    expect(home.service.lastBlogSlug, 'deep-link-story');
    expect(find.text('Linked Blog Story'), findsOneWidget);
    expect(find.text('The article opens inside the app.'), findsOneWidget);
  });

  testWidgets('tapping a Blog feed card opens its native article screen', (
    tester,
  ) async {
    const post = TvBlogPost(
      id: '4',
      slug: 'sample-story',
      title: 'Featured story',
      excerpt: 'A short linked story.',
      date: '2026-11-08',
      category: 'Updates',
      author: 'Yangon TV',
      image: '',
      content: 'The article opens inside the app.',
    );
    final home = await _mountHome(
      tester,
      blogPosts: const [post],
      article: post,
    );
    await tester.tap(find.text('Blog').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Featured story'));
    await tester.pumpAndSettle();

    expect(home.service.lastBlogSlug, 'sample-story');
    expect(find.text('The article opens inside the app.'), findsOneWidget);
  });

  testWidgets('tapping a home blog hero opens its native article', (
    tester,
  ) async {
    const post = TvBlogPost(
      id: '5',
      slug: 'home-story',
      title: 'Published home story',
      excerpt: 'Blog summary',
      date: '2026-11-08',
      category: 'Updates',
      author: 'YGNTV',
      image: '',
      content: 'The home story opens inside the app.',
    );
    final home = await _mountHome(
      tester,
      blogPosts: const [post],
      article: post,
    );

    await tester.tap(find.text('Published home story'));
    await tester.pumpAndSettle();

    expect(home.service.lastBlogSlug, 'home-story');
    expect(find.text('The home story opens inside the app.'), findsOneWidget);
  });

  testWidgets('hero poster tap opens its link without rendering a button', (
    tester,
  ) async {
    final home = await _mountHome(
      tester,
      banners: const [
        TvHomeBanner(
          id: 8,
          name: 'Featured TEST banner',
          imageUrl: '',
          displayOrder: 0,
          linkUrl: 'https://ygntv.org/app/movies',
          buttonName: 'Watch now',
        ),
      ],
    );

    expect(find.text('Featured TEST banner'), findsOneWidget);
    expect(find.text('Watch now'), findsNothing);
    await tester.tap(find.text('Featured TEST banner'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('catalog-page-title')))
          .data,
      'Movie',
    );
    expect(home.service.lastLoadedKind, isNull);
  });

  testWidgets('top ad slider precedes the blog hero and keeps 728:90 ratio', (
    tester,
  ) async {
    await _mountHome(
      tester,
      banners: const [
        TvHomeBanner(
          id: 8,
          name: 'Sponsored placement',
          imageUrl: 'https://example.com/banner.png',
          displayOrder: 0,
        ),
      ],
      blogPosts: const [
        TvBlogPost(
          id: '5',
          slug: 'home-story',
          title: 'Published home story',
          excerpt: 'Blog summary',
          date: '2026-11-08',
          category: 'Updates',
          author: 'YGNTV',
          image: '',
        ),
      ],
    );

    final ad = find.byKey(const ValueKey('home-top-banner-aspect-ratio'));
    final blog = find.byKey(const ValueKey('home-blog-hero-slider'));
    expect(ad, findsOneWidget);
    expect(blog, findsOneWidget);
    expect(tester.widget<AspectRatio>(ad).aspectRatio, closeTo(728 / 90, .001));
    expect(find.text('Published home story'), findsOneWidget);
    final adRect = tester.getRect(ad);
    final blogRect = tester.getRect(blog);
    expect(adRect.top, lessThan(blogRect.top));
  });

  testWidgets('home hero is hidden rather than falling back to movies', (
    tester,
  ) async {
    final home = await _mountHome(tester);
    expect(find.text('YANGON TV PICKS'), findsNothing);
    expect(find.text('Your next story awaits.'), findsNothing);
    expect(find.byKey(const ValueKey('home-blog-hero-slider')), findsNothing);
    expect(find.text('Stories worth staying up for.'), findsOneWidget);
    expect(find.text('Movie'), findsOneWidget);
    expect(home.service.lastLoadedKind, isNull);
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
