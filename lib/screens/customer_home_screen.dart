import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../services/customer_app_update_service.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/resilient_network_image.dart';
import '../widgets/ygntv_brand.dart';
import 'account_screen.dart';
import 'library_screen.dart';
import 'media_actions.dart';
import 'media_detail_screen.dart';
import 'manual_transfer_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'subscription_screen.dart';
import 'support_chat_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    required this.session,
    required this.authService,
    required this.onSignOut,
    this.deepLinkEvent,
    super.key,
  });

  final AuthSession session;
  final AuthService authService;
  final Future<void> Function() onSignOut;
  final ValueNotifier<AppDeepLink?>? deepLinkEvent;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  int _selectedTab = 0;
  late Future<List<CatalogItem>> _movies;
  late Future<List<CatalogItem>> _series;
  late Future<List<TvLibraryEntry>> _continueWatching;
  late Future<List<TvHomeBanner>> _heroBanners;
  final PageController _bannerController = PageController();
  int _bannerIndex = 0;
  TvNotificationFeed? _notificationFeed;
  bool _refreshingNotifications = false;
  Timer? _notificationTimer;
  Timer? _bannerTimer;
  Timer? _appUpdateTimer;
  final CustomerAppUpdateService _appUpdateService = CustomerAppUpdateService();
  DateTime? _lastUpdateCheckAt;
  bool _checkingAppUpdate = false;
  bool _installingDownloadedUpdate = false;
  int? _pendingInstallerDownloadId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.deepLinkEvent?.addListener(_consumeDeepLinkEvent);
    _refreshCatalog();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumeDeepLinkEvent(),
    );
    unawaited(_refreshNotifications());
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshNotifications(),
    );
    _bannerTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _advanceBanner(),
    );
    _appUpdateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) unawaited(_checkForAppUpdate());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.deepLinkEvent?.removeListener(_consumeDeepLinkEvent);
    _notificationTimer?.cancel();
    _bannerTimer?.cancel();
    _appUpdateTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deepLinkEvent != widget.deepLinkEvent) {
      oldWidget.deepLinkEvent?.removeListener(_consumeDeepLinkEvent);
      widget.deepLinkEvent?.addListener(_consumeDeepLinkEvent);
      _consumeDeepLinkEvent();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotifications());
      unawaited(_onAppResumed());
    }
  }

  Future<void> _onAppResumed() async {
    if (_pendingInstallerDownloadId != null) {
      await _installPendingUpdateIfAllowed();
      return;
    }
    final lastCheck = _lastUpdateCheckAt;
    if (lastCheck == null ||
        DateTime.now().difference(lastCheck) >= const Duration(hours: 6)) {
      await _checkForAppUpdate();
    }
  }

  Future<void> _checkForAppUpdate({bool manual = false}) async {
    if (_checkingAppUpdate) return;
    _checkingAppUpdate = true;
    _lastUpdateCheckAt = DateTime.now();
    try {
      final release = await _appUpdateService.findAvailableUpdate();
      if (!mounted) return;
      if (release == null) {
        if (manual) {
          _showAppUpdateMessage('You are using the latest YGNTV TEST build.');
        }
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: ygntvPanel,
          title: const Text('YGNTV update available'),
          content: Text(
            'Version ${release.versionName} · build ${release.versionCode}'
            '${release.releaseNotes.isEmpty ? '' : '\n\n${release.releaseNotes}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download & install'),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) await _downloadAndInstallUpdate(release);
    } catch (error) {
      if (manual && mounted) _showAppUpdateMessage(error.toString());
    } finally {
      _checkingAppUpdate = false;
    }
  }

  Future<void> _downloadAndInstallUpdate(AppUpdateRelease release) async {
    final id = await _appUpdateService.startApkDownload(release);
    if (!mounted) return;
    final progress = ValueNotifier<AppUpdateDownloadStatus>(
      const AppUpdateDownloadStatus(status: 'pending'),
    );
    final progressDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<AppUpdateDownloadStatus>(
        valueListenable: progress,
        builder: (context, status, _) => AlertDialog(
          backgroundColor: ygntvPanel,
          title: const Text('Downloading YGNTV update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: status.progress, color: ygntvRed),
              const SizedBox(height: 12),
              Text(
                status.progress == null
                    ? 'Download is running in the background.'
                    : '${(status.progress! * 100).round()}% downloaded',
                style: const TextStyle(color: ygntvMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    var dialogClosed = false;
    try {
      while (mounted) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final status = await _appUpdateService.downloadStatus(id);
        progress.value = status;
        if (status.status == 'complete' && status.checksumValid == true) {
          if (mounted && !dialogClosed) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogClosed = true;
          }
          await progressDialog;
          if (await _appUpdateService.canInstallPackages()) {
            _pendingInstallerDownloadId = null;
            await _appUpdateService.installDownloadedApk(id);
          } else {
            await _requestInstallPermission(id);
          }
          return;
        }
        if (status.isFinished) {
          throw FormatException(
            status.message ??
                'The YGNTV update download could not be verified.',
          );
        }
      }
    } catch (error) {
      if (mounted && !dialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogClosed = true;
        await progressDialog;
      }
      if (mounted) _showAppUpdateMessage(error.toString());
    } finally {
      progress.dispose();
    }
  }

  Future<void> _requestInstallPermission(int id) async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ygntvPanel,
        title: const Text('Allow YGNTV updates'),
        content: const Text(
          'Android needs your permission to install this private TEST update. '
          'Allow “Install unknown apps” for YGNTV, then return here. Android '
          'will still ask you to confirm the update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      _pendingInstallerDownloadId = id;
      await _appUpdateService.openInstallPermissionSettings();
    }
  }

  Future<void> _installPendingUpdateIfAllowed() async {
    final id = _pendingInstallerDownloadId;
    if (id == null || _installingDownloadedUpdate) return;
    _installingDownloadedUpdate = true;
    try {
      if (await _appUpdateService.canInstallPackages()) {
        _pendingInstallerDownloadId = null;
        await _appUpdateService.installDownloadedApk(id);
      }
    } catch (error) {
      if (mounted) _showAppUpdateMessage(error.toString());
    } finally {
      _installingDownloadedUpdate = false;
    }
  }

  void _showAppUpdateMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshNotifications() async {
    if (_refreshingNotifications) return;
    _refreshingNotifications = true;
    try {
      final feed = await widget.authService.getNotifications();
      if (mounted) setState(() => _notificationFeed = feed);
    } catch (_) {
      // Keep the last server-confirmed count when the connection is unavailable.
    } finally {
      _refreshingNotifications = false;
    }
  }

  void _advanceBanner() {
    if (!mounted ||
        _selectedTab != 0 ||
        !_bannerController.hasClients ||
        _bannerController.position.viewportDimension <= 0 ||
        _bannerController.position.maxScrollExtent <= 0) {
      return;
    }
    final position = _bannerController.position;
    final pageCount =
        (position.maxScrollExtent / position.viewportDimension).round() + 1;
    if (pageCount < 2) return;
    final currentPage = _bannerController.page?.round() ?? 0;
    unawaited(
      _bannerController.animateToPage(
        (currentPage + 1) % pageCount,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _refreshCatalog() {
    _movies = widget.authService.loadCatalog('movie');
    _series = widget.authService.loadCatalog('series');
    _continueWatching = widget.authService.getContinueWatching();
    _heroBanners = widget.authService.getHeroBanners();
    _bannerIndex = 0;
    if (_bannerController.hasClients) _bannerController.jumpToPage(0);
  }

  Future<void> _refresh() async {
    setState(_refreshCatalog);
    unawaited(_refreshNotifications());
    try {
      await Future.wait([_movies, _series, _continueWatching, _heroBanners]);
    } catch (_) {
      // Each shelf displays its own live API error state.
    }
  }

  void _openItem(CatalogItem item) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            MediaDetailScreen(item: item, service: widget.authService),
      ),
    );
  }

  void _consumeDeepLinkEvent() {
    final event = widget.deepLinkEvent;
    final link = event?.value;
    if (event == null || link == null) return;
    event.value = null;
    unawaited(_openDeepLink(link));
  }

  Future<void> _openDeepLink(AppDeepLink link) async {
    switch (link.destination) {
      case AppDeepLinkDestination.movies:
        setState(() => _selectedTab = 1);
        return;
      case AppDeepLinkDestination.series:
        setState(() => _selectedTab = 2);
        return;
      case AppDeepLinkDestination.home:
        setState(() => _selectedTab = 0);
        return;
      case AppDeepLinkDestination.search:
        setState(() => _selectedTab = 3);
        return;
      case AppDeepLinkDestination.account:
        setState(() => _selectedTab = 4);
        return;
      case AppDeepLinkDestination.library:
        const libraryTabs = {
          'continue': 0,
          'history': 1,
          'list': 2,
          'offline': 3,
        };
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => LibraryScreen(
              service: widget.authService,
              initialTab: libraryTabs[link.tab] ?? 0,
            ),
          ),
        );
        return;
      case AppDeepLinkDestination.notifications:
        await _openNotifications();
        return;
      case AppDeepLinkDestination.subscription:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SubscriptionScreen(
              service: widget.authService,
              initialTab: link.tab == 'redeem' ? 1 : 0,
            ),
          ),
        );
        return;
      case AppDeepLinkDestination.support:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(service: widget.authService),
          ),
        );
        return;
      case AppDeepLinkDestination.manualTransfer:
        try {
          final planKey = link.planKey;
          if (planKey == null) return;
          final plans = await widget.authService.getPremiumPlans();
          final plan = plans
              .where((candidate) => candidate.key == planKey)
              .firstOrNull;
          if (plan == null) {
            if (mounted) {
              _showAppUpdateMessage(
                'This membership plan is no longer available.',
              );
            }
            return;
          }
          if (!mounted) return;
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  ManualTransferScreen(service: widget.authService, plan: plan),
            ),
          );
        } catch (error) {
          if (mounted) _showAppUpdateMessage(error.toString());
        }
        return;
      case AppDeepLinkDestination.videoPlayback:
        final contentType = link.contentType;
        final contentId = link.contentId;
        if (contentType == null || contentId == null) return;
        await runMediaAction(
          context,
          widget.authService,
          contentType: contentType,
          contentId: contentId,
          title: contentType == 'episode' ? 'YGNTV episode' : 'YGNTV movie',
          posterUrl: '',
          action: 'watch',
        );
        return;
      case AppDeepLinkDestination.movieDetail:
      case AppDeepLinkDestination.seriesDetail:
        final isMovie = link.destination == AppDeepLinkDestination.movieDetail;
        final kind = isMovie ? 'movie' : 'series';
        final slug = link.slug;
        if (slug == null) return;
        setState(() => _selectedTab = isMovie ? 1 : 2);
        try {
          final item = await widget.authService.loadDetail(
            CatalogItem(title: '', posterUrl: '', kind: kind, slug: slug),
          );
          if (!mounted) return;
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  MediaDetailScreen(item: item, service: widget.authService),
            ),
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This title could not be opened from the link.'),
              ),
            );
          }
        }
        return;
    }
  }

  void _openLibrary() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LibraryScreen(service: widget.authService),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(service: widget.authService),
      ),
    );
    if (!mounted) return;
    unawaited(_refreshNotifications());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    body: SafeArea(child: _selectedView()),
    bottomNavigationBar: NavigationBar(
      height: 67,
      backgroundColor: const Color(0xFF111116),
      indicatorColor: ygntvRed.withValues(alpha: .18),
      selectedIndex: _selectedTab,
      onDestinationSelected: (value) => setState(() => _selectedTab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie_rounded),
          label: 'Movies',
        ),
        NavigationDestination(
          icon: Icon(Icons.live_tv_outlined),
          selectedIcon: Icon(Icons.live_tv_rounded),
          label: 'Series',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_rounded),
          selectedIcon: Icon(Icons.manage_search_rounded),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Account',
        ),
      ],
    ),
  );

  Widget _selectedView() => switch (_selectedTab) {
    0 => _homeView(),
    1 => _catalogPage('Movies to discover', _movies, 'movie'),
    2 => _catalogPage('Series to binge', _series, 'series'),
    3 => SearchScreen(service: widget.authService, onOpenItem: _openItem),
    _ => AccountScreen(
      service: widget.authService,
      session: widget.session,
      onSignOut: widget.onSignOut,
      onCheckForUpdates: () => _checkForAppUpdate(manual: true),
    ),
  };

  Widget _homeView() {
    final displayName = widget.session.name.trim().isEmpty
        ? 'there'
        : widget.session.name.trim().split(RegExp(r'\s+')).first;
    return RefreshIndicator(
      color: ygntvRed,
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(19, 12, 19, 0),
              child: Row(
                children: [
                  const YgntvBrandLockup(compact: true),
                  const Spacer(),
                  AppPageLinkButton(uri: AppDeepLink.linkFor('home')),
                  IconButton(
                    tooltip: 'My Library',
                    onPressed: _openLibrary,
                    icon: const Icon(
                      Icons.video_library_outlined,
                      color: ygntvGold,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Updates',
                    onPressed: _openNotifications,
                    icon: Badge(
                      isLabelVisible:
                          (_notificationFeed?.hasServerUnreadCount ?? false) &&
                          (_notificationFeed?.unreadCount ?? 0) > 0,
                      label: Text(
                        (_notificationFeed?.unreadCount ?? 0) > 99
                            ? '99+'
                            : '${_notificationFeed?.unreadCount ?? 0}',
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: ygntvGold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedTab = 4),
                    borderRadius: BorderRadius.circular(50),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: ygntvRed.withValues(alpha: .18),
                      child: Text(
                        _initial(widget.session.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR YGNTV HOME',
                    style: TextStyle(
                      color: ygntvGold,
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Welcome back, $displayName.',
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.12,
                      letterSpacing: -.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Stories worth staying up for.',
                    style: TextStyle(color: ygntvMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _heroBannerSlider()),
          SliverToBoxAdapter(child: _continueRail()),
          SliverToBoxAdapter(
            child: _catalogRail(
              title: 'Movies to discover',
              future: _movies,
              kind: 'movie',
            ),
          ),
          SliverToBoxAdapter(
            child: _catalogRail(
              title: 'Series to binge',
              future: _series,
              kind: 'series',
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 26)),
        ],
      ),
    );
  }

  Widget _heroBannerSlider() => FutureBuilder<List<TvHomeBanner>>(
    future: _heroBanners,
    builder: (context, snapshot) {
      final banners = snapshot.data ?? const <TvHomeBanner>[];
      if (banners.isEmpty) return _featuredCard();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _bannerController,
                  itemCount: banners.length,
                  onPageChanged: (index) =>
                      setState(() => _bannerIndex = index),
                  itemBuilder: (context, index) => _bannerCard(banners[index]),
                ),
                if (banners.length > 1)
                  Positioned(
                    right: 15,
                    bottom: 15,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List<Widget>.generate(
                        banners.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == _bannerIndex ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            color: index == _bannerIndex
                                ? ygntvGold
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _bannerCard(TvHomeBanner banner) => GestureDetector(
    onTap: banner.buttonName == null && banner.linkUrl != null
        ? () => _openBannerLink(banner.linkUrl)
        : null,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ResilientNetworkImage(
          url: banner.imageUrl,
          fit: BoxFit.cover,
          cacheWidth: 780,
          fallback: const _FeatureBackdrop(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x11000000), Color(0xEE09090D)],
            ),
          ),
        ),
        Positioned(
          left: 17,
          right: banner.buttonName == null ? 17 : 76,
          bottom: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 7),
              Text(
                banner.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              if (banner.linkUrl != null && banner.buttonName != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openBannerLink(banner.linkUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: Text(banner.buttonName!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _openBannerLink(String? value) async {
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return;
    final appLink = AppDeepLink.tryParse(uri);
    if (appLink != null) {
      await _openDeepLink(appLink);
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This banner link could not be opened.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This banner link could not be opened.'),
          ),
        );
      }
    }
  }

  Widget _featuredCard() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: FutureBuilder<List<CatalogItem>>(
      future: _movies,
      builder: (context, snapshot) {
        final item = snapshot.data?.firstOrNull;
        return ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item != null && item.backdropUrl.isNotEmpty)
                  ResilientNetworkImage(
                    url: item.backdropUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 780,
                    fallback: const _FeatureBackdrop(),
                  )
                else if (item != null && item.posterUrl.isNotEmpty)
                  ResilientNetworkImage(
                    url: item.posterUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 342,
                    fallback: const _FeatureBackdrop(),
                  )
                else
                  const _FeatureBackdrop(),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x11000000), Color(0xEE09090D)],
                    ),
                  ),
                ),
                Positioned(
                  left: 17,
                  right: 17,
                  bottom: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: ygntvGold,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'YANGON TV PICKS',
                            style: TextStyle(
                              color: ygntvGold,
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item?.title ??
                            (snapshot.hasError
                                ? 'Your next story awaits.'
                                : 'Stories worth staying up for.'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item?.synopsis.isNotEmpty == true
                            ? item!.synopsis
                            : 'Discover movies and series picked for you.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD0CDD3),
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _continueRail() => Padding(
    padding: const EdgeInsets.only(bottom: 21),
    child: FutureBuilder<List<TvLibraryEntry>>(
      future: _continueWatching,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <TvLibraryEntry>[];
        if (entries.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Continue watching', onSeeAll: _openLibrary),
            const SizedBox(height: 11),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                scrollDirection: Axis.horizontal,
                itemCount: entries.length.clamp(0, 8),
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (context, index) => _ContinueCard(
                  key: ValueKey(
                    '${entries[index].contentType}:${entries[index].contentId}',
                  ),
                  entry: entries[index],
                  onTap: () => runMediaAction(
                    context,
                    widget.authService,
                    contentType: entries[index].contentType,
                    contentId: entries[index].contentId,
                    title: entries[index].title,
                    posterUrl: entries[index].posterUrl,
                    action: 'watch',
                    initialPosition: entries[index].positionSeconds,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _catalogRail({
    required String title,
    required Future<List<CatalogItem>> future,
    required String kind,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 23),
    child: FutureBuilder<List<CatalogItem>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <CatalogItem>[];
        void onSeeAll() {
          setState(() => _selectedTab = kind == 'movie' ? 1 : 2);
        }

        if (items.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: title, onSeeAll: onSeeAll),
              const SizedBox(height: 10),
              const SizedBox(
                height: 105,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ygntvRed,
                  ),
                ),
              ),
            ],
          );
        }
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: title, onSeeAll: onSeeAll),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  snapshot.hasError
                      ? 'The live catalog is temporarily unavailable.'
                      : 'New titles are on the way.',
                  style: const TextStyle(color: ygntvMuted, fontSize: 11),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: title, onSeeAll: onSeeAll),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 19),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (context, index) => _PosterCard(
                  key: ValueKey('${items[index].kind}:${items[index].id}'),
                  item: items[index],
                  onTap: () => _openItem(items[index]),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _catalogPage(
    String title,
    Future<List<CatalogItem>> future,
    String kind,
  ) => RefreshIndicator(
    color: ygntvRed,
    onRefresh: _refresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(19, 15, 19, 18),
            child: Row(
              children: [
                const YgntvBrandLockup(compact: true),
                const Spacer(),
                AppPageLinkButton(
                  uri: AppDeepLink.linkFor(
                    kind == 'movie' ? 'movies' : 'series',
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh catalog',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(19, 0, 19, 15),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              ),
            ),
          ),
        ),
        FutureBuilder<List<CatalogItem>>(
          future: future,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <CatalogItem>[];
            if (items.isEmpty &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: ygntvRed),
                ),
              );
            }
            if (items.isEmpty && snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          color: ygntvMuted,
                          size: 31,
                        ),
                        const SizedBox(height: 11),
                        const Text(
                          'Could not load titles.',
                          style: TextStyle(color: ygntvMuted),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (items.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No titles available yet.',
                    style: TextStyle(color: ygntvMuted),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 24),
              sliver: SliverGrid.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 13,
                  crossAxisSpacing: 10,
                  childAspectRatio: .55,
                ),
                itemBuilder: (context, index) => _PosterCard(
                  key: ValueKey('${items[index].kind}:${items[index].id}'),
                  item: items[index],
                  onTap: () => _openItem(items[index]),
                  grid: true,
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 19),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('See all', style: TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.item,
    required this.onTap,
    this.grid = false,
    super.key,
  });
  final CatalogItem item;
  final VoidCallback onTap;
  final bool grid;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: grid ? null : 113,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                child: item.posterUrl.isEmpty
                    ? const _PosterFallback()
                    : ResilientNetworkImage(
                        url: item.posterUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 185,
                        tmdbMaxWidth: 500,
                        fallback: const _PosterFallback(),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              item.year,
              item.kind == 'movie' ? 'Movie' : 'Series',
            ].where((part) => part.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ygntvMuted, fontSize: 8),
          ),
        ],
      ),
    ),
  );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap, super.key});
  final TvLibraryEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final duration = entry.durationSeconds ?? 0;
    final progress = duration > 0
        ? (entry.positionSeconds / duration).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return SizedBox(
      width: 245,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: ygntvPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .05)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 76,
                  height: 112,
                  child: entry.posterUrl.isEmpty
                      ? const _PosterFallback()
                      : ResilientNetworkImage(
                          url: entry.posterUrl,
                          fit: BoxFit.cover,
                          cacheWidth: 185,
                          tmdbMaxWidth: 500,
                          fallback: const _PosterFallback(),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.contentType == 'episode'
                          ? 'SERIES EPISODE'
                          : 'MOVIE',
                      style: const TextStyle(
                        color: ygntvGold,
                        fontSize: 8,
                        letterSpacing: .7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(ygntvRed),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          color: ygntvRed,
                          size: 14,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Resume',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF25222B),
    child: Center(
      child: Icon(Icons.movie_outlined, color: Color(0x66FFFFFF), size: 28),
    ),
  );
}

class _FeatureBackdrop extends StatelessWidget {
  const _FeatureBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF643136), Color(0xFF24202A), Color(0xFF0D0C12)],
      ),
    ),
  );
}

String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Y' : trimmed.characters.first.toUpperCase();
}
