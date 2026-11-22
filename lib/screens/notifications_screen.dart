import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/ygntv_brand.dart';
import 'support_chat_screen.dart';
import 'video_player_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.service, super.key});
  final AuthService service;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  late Future<TvNotificationFeed> _feed;
  TvNotificationFeed? _lastKnownFeed;
  List<TvDownloadProgress> _downloads = const [];
  final Set<int> _knownCompletedDownloadIds = {};
  Timer? _downloadTimer;
  Timer? _notificationTimer;
  bool _busy = false;
  bool _syncingNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feed = widget.service.getNotifications();
    unawaited(_rememberFeed(_feed));
    unawaited(_refreshDownloads());
    _downloadTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshDownloads(),
    );
    _startNotificationPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadTimer?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startNotificationPolling();
      unawaited(_syncNotifications());
      unawaited(_refreshDownloads());
    } else {
      _notificationTimer?.cancel();
      _notificationTimer = null;
    }
  }

  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_syncNotifications()),
    );
  }

  Future<void> _rememberFeed(Future<TvNotificationFeed> future) async {
    try {
      final feed = await future;
      _lastKnownFeed ??= feed;
    } catch (_) {
      // The first load error is shown by the FutureBuilder.
    }
  }

  Future<void> _syncNotifications() async {
    if (_syncingNotifications || _busy) return;
    _syncingNotifications = true;
    try {
      final feed = await widget.service.getNotifications();
      if (!mounted) return;
      setState(() {
        _lastKnownFeed = feed;
        _feed = Future.value(feed);
      });
    } catch (_) {
      final previous = _lastKnownFeed;
      if (mounted && previous != null) {
        setState(() => _feed = Future.value(previous));
      }
    } finally {
      _syncingNotifications = false;
    }
  }

  Future<void> _refresh() async {
    if (_syncingNotifications) return;
    _syncingNotifications = true;
    final future = widget.service.getNotifications();
    setState(() => _feed = future);
    try {
      await _refreshDownloads();
      _lastKnownFeed = await future;
    } catch (_) {
      // A failed refresh keeps the last server-confirmed feed when available.
    } finally {
      _syncingNotifications = false;
    }
  }

  Future<void> _refreshDownloads() async {
    final downloads = await widget.service.getAndroidDownloads();
    final completedIds = downloads
        .where((download) => download.status == 'complete')
        .map((download) => download.id)
        .toSet();
    final hasNewCompletion = completedIds.difference(
      _knownCompletedDownloadIds,
    ).isNotEmpty;
    _knownCompletedDownloadIds.addAll(completedIds);
    if (mounted) setState(() => _downloads = downloads);
    if (hasNewCompletion && mounted) await _syncNotifications();
  }

  Future<void> _playDownloadedVideo(TvDownloadProgress download) async {
    final path = download.localFilePath;
    if (download.status != 'complete' || path == null) {
      _message('The offline video file is not available on this device.');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          service: widget.service,
          url: '',
          headers: const {},
          title: download.title,
          posterUrl: '',
          contentType: 'movie',
          contentId: 0,
          localFilePath: path,
          saveProgress: false,
        ),
      ),
    );
  }

  Future<void> _markRead(TvNotificationEntry item) async {
    if (item.isRead || _busy) return;
    setState(() => _busy = true);
    try {
      final feed = await widget.service.markNotificationRead(item.id);
      if (mounted) {
        setState(() {
          _lastKnownFeed = feed;
          _feed = Future.value(feed);
        });
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAll(TvNotificationFeed feed) async {
    if (feed.visibleUnreadCount == 0 || _busy) return;
    setState(() => _busy = true);
    try {
      final next = await widget.service.markAllNotificationsRead();
      if (mounted) {
        setState(() {
          _lastKnownFeed = next;
          _feed = Future.value(next);
        });
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearRead(TvNotificationFeed feed) async {
    if (_busy || !feed.visibleNotifications.any((item) => item.isRead)) return;
    setState(() => _busy = true);
    try {
      final next = await widget.service.dismissReadNotifications(feed);
      if (mounted) {
        setState(() {
          _lastKnownFeed = next;
          _feed = Future.value(next);
        });
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLink(String? value) async {
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _message('This link could not be opened.');
    }
  }

  Future<void> _openNotification(TvNotificationEntry item) async {
    await _markRead(item);
    if (!mounted) return;
    if (_isSupportReply(item)) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(service: widget.service),
        ),
      );
      return;
    }
    if (_isLocalDownloadComplete(item)) {
      for (final download in _downloads) {
        if (download.status == 'complete' &&
            item.message.contains(download.title)) {
          await _playDownloadedVideo(download);
          return;
        }
      }
    }
    await _openLink(item.linkUrl);
  }

  bool _isSupportReply(TvNotificationEntry item) {
    final type = (item.type ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    return type == 'support' ||
        type.contains('supportreply') ||
        type.contains('customersupport') ||
        item.title.toLowerCase().contains('customer support reply');
  }

  bool _isLocalDownloadComplete(TvNotificationEntry item) {
    final normalizedType = (item.type ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return item.isLocal &&
        (normalizedType == 'downloadcomplete' ||
            normalizedType == 'downloadcompleted');
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    appBar: AppBar(
      title: const Text('YGNTV Updates'),
      actions: [
        AppPageLinkButton(uri: AppDeepLink.linkFor('notifications')),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      color: ygntvRed,
      onRefresh: _refresh,
      child: FutureBuilder<TvNotificationFeed>(
        future: _feed,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ScrollableState(
              child: CircularProgressIndicator(color: ygntvRed),
            );
          }
          if (snapshot.hasError) {
            return _ScrollableState(
              child: _InfoState(
                icon: Icons.wifi_off_rounded,
                title: 'Updates could not be loaded',
                copy: snapshot.error.toString(),
                action: TextButton(
                  onPressed: _refresh,
                  child: const Text('Try again'),
                ),
              ),
            );
          }
          final feed = snapshot.data!;
          final notifications = feed.visibleNotifications;
          final hasUnreadItems = notifications.any((item) => !item.isRead);
          final hasReadItems = notifications.any((item) => item.isRead);
          final summary = [
            if (notifications.any((item) => !item.isRead))
              '${notifications.where((item) => !item.isRead).length} unread',
          ].join(' · ');
          if (notifications.isEmpty) {
            return const _ScrollableState(
              child: _InfoState(
                icon: Icons.notifications_none_rounded,
                title: 'No updates yet',
                copy:
                    'YGNTV announcements and account updates will appear here.',
              ),
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 28),
            itemCount: notifications.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 8)
                : const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary.isEmpty ? 'YGNTV Updates' : summary,
                        style: const TextStyle(color: ygntvMuted, fontSize: 11),
                      ),
                    ),
                    if (hasUnreadItems)
                      TextButton(
                        onPressed: _busy ? null : () => _markAll(feed),
                        child: const Text('Mark all read'),
                      ),
                    if (hasReadItems)
                      TextButton(
                        key: const ValueKey('notifications-clear-read'),
                        onPressed: _busy ? null : () => _clearRead(feed),
                        child: const Text('Clear read'),
                      ),
                  ],
                );
              }
              final item = notifications[index - 1];
              return _NotificationCard(
                item: item,
                onTap: () => _openNotification(item),
              );
            },
          );
        },
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});
  final TvNotificationEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: item.isRead ? ygntvPanel : const Color(0xFF241B20),
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.isRead
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              color: item.isRead ? ygntvMuted : ygntvRed,
              size: 20,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: ygntvRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: Color(0xFFC7C3CD),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                  if (item.linkUrl != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.type?.toLowerCase() == 'support' ||
                              item.title.toLowerCase().contains(
                                'customer support reply',
                              )
                          ? 'Tap to open support chat'
                          : 'Tap to open link',
                      style: TextStyle(
                        color: ygntvGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScrollableState extends StatelessWidget {
  const _ScrollableState({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .28),
      child,
    ],
  );
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.title,
    required this.copy,
    this.action,
  });
  final IconData icon;
  final String title;
  final String copy;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30),
    child: Column(
      children: [
        Icon(icon, color: ygntvGold, size: 36),
        const SizedBox(height: 11),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          copy,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ygntvMuted, fontSize: 11, height: 1.4),
        ),
        ?action,
      ],
    ),
  );
}
