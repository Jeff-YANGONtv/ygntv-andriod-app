enum AppDeepLinkDestination {
  home,
  movies,
  series,
  search,
  account,
  library,
  notifications,
  subscription,
  support,
  movieDetail,
  seriesDetail,
  manualTransfer,
  videoPlayback,
}

class AppDeepLink {
  const AppDeepLink({
    required this.destination,
    this.slug,
    this.tab,
    this.planKey,
    this.contentType,
    this.contentId,
  });

  final AppDeepLinkDestination destination;
  final String? slug;
  final String? tab;
  final String? planKey;
  final String? contentType;
  final int? contentId;

  static Uri linkFor(String route, {Map<String, String> query = const {}}) =>
      Uri.https('ygntv.org', '/app/$route', query.isEmpty ? null : query);

  static AppDeepLink? tryParse(Uri uri) {
    if (uri.scheme != 'https' ||
        !{'ygntv.org', 'www.ygntv.org'}.contains(uri.host.toLowerCase())) {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.length == 2 && segments[0] == 'app') {
      return switch (segments[1]) {
        'home' => const AppDeepLink(destination: AppDeepLinkDestination.home),
        'movies' => const AppDeepLink(
          destination: AppDeepLinkDestination.movies,
        ),
        'series' => const AppDeepLink(
          destination: AppDeepLinkDestination.series,
        ),
        'search' => const AppDeepLink(
          destination: AppDeepLinkDestination.search,
        ),
        'account' => const AppDeepLink(
          destination: AppDeepLinkDestination.account,
        ),
        'library' => const AppDeepLink(
          destination: AppDeepLinkDestination.library,
          tab: 'continue',
        ),
        'notifications' => const AppDeepLink(
          destination: AppDeepLinkDestination.notifications,
        ),
        'subscription' => const AppDeepLink(
          destination: AppDeepLinkDestination.subscription,
          tab: 'plans',
        ),
        'support' => const AppDeepLink(
          destination: AppDeepLinkDestination.support,
        ),
        _ => null,
      };
    }

    if (segments.length == 3 && segments[0] == 'app') {
      if (segments[1] == 'library') {
        const tabs = {'continue', 'history', 'list', 'offline'};
        if (!tabs.contains(segments[2])) return null;
        return AppDeepLink(
          destination: AppDeepLinkDestination.library,
          tab: segments[2],
        );
      }
      if (segments[1] == 'subscription') {
        final tab = switch (segments[2]) {
          'plans' => 'plans',
          'redeem' => 'redeem',
          _ => null,
        };
        if (tab == null) return null;
        return AppDeepLink(
          destination: AppDeepLinkDestination.subscription,
          tab: tab,
        );
      }
    }

    if (segments.length == 4 &&
        segments[0] == 'app' &&
        segments[1] == 'subscription' &&
        segments[2] == 'transfer') {
      final planKey = segments[3].trim();
      if (!_validSegment(planKey)) return null;
      return AppDeepLink(
        destination: AppDeepLinkDestination.manualTransfer,
        planKey: planKey,
      );
    }

    if (segments.length == 4 &&
        segments[0] == 'app' &&
        segments[1] == 'watch') {
      final contentType = segments[2];
      final contentId = int.tryParse(segments[3]);
      if (!{'movie', 'episode'}.contains(contentType) ||
          contentId == null ||
          contentId <= 0) {
        return null;
      }
      return AppDeepLink(
        destination: AppDeepLinkDestination.videoPlayback,
        contentType: contentType,
        contentId: contentId,
      );
    }

    if (segments.length != 3 || segments[0] != 'app') return null;
    final slug = segments[2].trim();
    if (!_validSegment(slug)) return null;

    return switch (segments[1]) {
      'movie' => AppDeepLink(
        destination: AppDeepLinkDestination.movieDetail,
        slug: slug,
      ),
      'series' => AppDeepLink(
        destination: AppDeepLinkDestination.seriesDetail,
        slug: slug,
      ),
      _ => null,
    };
  }

  static bool _validSegment(String value) =>
      value.isNotEmpty && value != '.' && value != '..';
}
