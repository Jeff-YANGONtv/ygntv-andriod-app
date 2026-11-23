import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/resilient_network_image.dart';
import '../widgets/ygntv_brand.dart';
import 'media_actions.dart';
import 'video_player_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({required this.service, this.initialTab = 0, super.key});
  final AuthService service;
  final int initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: initialTab.clamp(0, 3).toInt(),
    child: Scaffold(
      backgroundColor: ygntvBackground,
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          Builder(
            builder: (context) => AppPageLinkButton(
              uri: AppDeepLink.linkFor('library'),
              uriBuilder: () {
                const tabs = ['continue', 'history', 'list', 'offline'];
                final index = DefaultTabController.of(context).index;
                return AppDeepLink.linkFor('library/${tabs[index]}');
              },
            ),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Continue'),
            Tab(text: 'History'),
            Tab(text: 'My List'),
            Tab(text: 'Offline'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _LibraryList(service: service, mode: _LibraryMode.continueWatching),
          _LibraryList(service: service, mode: _LibraryMode.history),
          _LibraryList(service: service, mode: _LibraryMode.saved),
          _DownloadsList(service: service),
        ],
      ),
    ),
  );
}

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({required this.service, super.key});

  final AuthService service;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      key: const ValueKey('activity-history-screen'),
      backgroundColor: ygntvBackground,
      appBar: AppBar(
        title: const Text('Activity History'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Watch List'),
            Tab(text: 'Watched'),
            Tab(text: 'Downloaded'),
            Tab(text: 'Subscription History'),
            Tab(text: 'Claimed Bonus'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _LibraryList(service: service, mode: _LibraryMode.saved),
          _LibraryList(service: service, mode: _LibraryMode.history),
          _DownloadsList(service: service),
          const _UnavailableSubscriptionHistory(),
          _ClaimedBonusList(service: service),
        ],
      ),
    ),
  );
}

class _UnavailableSubscriptionHistory extends StatelessWidget {
  const _UnavailableSubscriptionHistory();

  @override
  Widget build(BuildContext context) => const _ScrollableMessage(
    child: _InfoState(
      icon: Icons.receipt_long_outlined,
      title: 'Subscription history is unavailable',
      copy: 'This app version does not receive subscription history records.',
    ),
  );
}

class _ClaimedBonusList extends StatefulWidget {
  const _ClaimedBonusList({required this.service});

  final AuthService service;

  @override
  State<_ClaimedBonusList> createState() => _ClaimedBonusListState();
}

class _ClaimedBonusListState extends State<_ClaimedBonusList> {
  late Future<Map<String, dynamic>> _overview;

  @override
  void initState() {
    super.initState();
    _overview = widget.service.getDailySignInWheelOverview();
  }

  Future<void> _refresh() async {
    final next = widget.service.getDailySignInWheelOverview();
    setState(() => _overview = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: ygntvRed,
    onRefresh: _refresh,
    child: FutureBuilder<Map<String, dynamic>>(
      future: _overview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ScrollableMessage(
            child: CircularProgressIndicator(color: ygntvRed),
          );
        }
        if (snapshot.hasError) {
          return _ScrollableMessage(
            child: _InfoState(
              icon: Icons.wifi_off_rounded,
              title: 'Bonus history could not be loaded',
              copy: snapshot.error.toString(),
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
          );
        }
        final rows = _claimedBonusRows(snapshot.data?['rewards']);
        if (rows.isEmpty) {
          return const _ScrollableMessage(
            child: _InfoState(
              icon: Icons.card_giftcard_outlined,
              title: 'No claimed bonuses yet',
              copy: 'Daily Sign In Bonus rewards you open will appear here.',
            ),
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _ClaimedBonusCard(
            key: ValueKey('claimed-bonus-${rows[index]['id'] ?? index}'),
            row: rows[index],
          ),
        );
      },
    ),
  );
}

List<Map<String, dynamic>> _claimedBonusRows(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

class _ClaimedBonusCard extends StatelessWidget {
  const _ClaimedBonusCard({required this.row, super.key});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final selection = row['selection'] is Map
        ? Map<String, dynamic>.from(row['selection'] as Map)
        : const <String, dynamic>{};
    final selectedTitle = '${selection['title'] ?? selection['name'] ?? ''}'
        .trim();
    final rawStatus = '${row['selection_status'] ?? ''}'.toLowerCase();
    final status = switch (rawStatus) {
      'selected' => 'Selected',
      'pending' => 'Pending selection',
      'expired' => 'Expired',
      _ => 'Claimed',
    };
    final timestamp =
        row['claimed_at'] ??
        row['opened_at'] ??
        row['created_at'] ??
        row['spun_at'];
    final date = _bonusHistoryDate(timestamp);
    final expiry = rawStatus == 'pending'
        ? _bonusHistoryDate(row['expires_at'])
        : '';
    final details = <String>[
      status,
      if (date.isNotEmpty) 'Opened $date',
      if (expiry.isNotEmpty) 'Expires $expiry',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ygntvPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ygntvRed.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: ygntvGold,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _claimedBonusTitle(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  details,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ygntvMuted, fontSize: 9.5),
                ),
                if (selectedTitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Selected: $selectedTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ygntvGold, fontSize: 9.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _claimedBonusTitle(Map<String, dynamic> row) {
  final label = '${row['reward_label'] ?? ''}'.trim();
  if (label.isNotEmpty) return label;
  final code = '${row['reward_code'] ?? row['code'] ?? ''}';
  return switch (code) {
    'one_episode' => '1 Episode',
    'one_movie' => '1 Movie',
    'good_luck_next_round' => 'Good Luck in Next Round',
    'two_movies' => '2 Movies',
    'two_episodes' => '2 Episodes',
    'roll_again' => 'Roll Again',
    'three_movies' => '3 Movies',
    'thanks_for_choosing_us' => 'Thank You',
    _ => code.isEmpty ? 'Bonus reward' : code,
  };
}

String _bonusHistoryDate(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

enum _LibraryMode { continueWatching, history, saved }

class _DownloadsList extends StatefulWidget {
  const _DownloadsList({required this.service});
  final AuthService service;

  @override
  State<_DownloadsList> createState() => _DownloadsListState();
}

class _DownloadsListState extends State<_DownloadsList> {
  late Future<List<TvDownloadProgress>> _downloads;

  @override
  void initState() {
    super.initState();
    _downloads = widget.service.getAndroidDownloads();
  }

  Future<void> _refresh() async {
    final next = widget.service.getAndroidDownloads();
    setState(() => _downloads = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _play(TvDownloadProgress download) async {
    final path = download.localFilePath;
    if (download.status != 'complete' || path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This video is not ready for offline play.'),
        ),
      );
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

  Future<void> _remove(TvDownloadProgress download) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ygntvPanel,
        title: const Text('Remove offline video?'),
        content: Text('“${download.title}” will be deleted from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove video'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await widget.service.deleteAndroidDownload(download.id);
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: ygntvRed,
    onRefresh: _refresh,
    child: FutureBuilder<List<TvDownloadProgress>>(
      future: _downloads,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ScrollableMessage(
            child: CircularProgressIndicator(color: ygntvRed),
          );
        }
        if (snapshot.hasError) {
          return _ScrollableMessage(
            child: _InfoState(
              icon: Icons.wifi_off_rounded,
              title: 'Offline library could not load',
              copy: snapshot.error.toString(),
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
          );
        }
        final downloads = snapshot.data ?? const <TvDownloadProgress>[];
        if (downloads.isEmpty) {
          return const _ScrollableMessage(
            child: _InfoState(
              icon: Icons.download_for_offline_outlined,
              title: 'No offline videos yet',
              copy: 'Download a movie or episode to watch it here without internet.',
            ),
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          itemCount: downloads.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) => _OfflineDownloadCard(
            download: downloads[index],
            onPlay: downloads[index].status == 'complete'
                ? () => _play(downloads[index])
                : null,
            onRemove: () => _remove(downloads[index]),
          ),
        );
      },
    ),
  );
}

class _OfflineDownloadCard extends StatelessWidget {
  const _OfflineDownloadCard({
    required this.download,
    required this.onPlay,
    required this.onRemove,
  });

  final TvDownloadProgress download;
  final VoidCallback? onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final progress = download.progress;
    final active = download.isActive;
    final percentage = progress == null ? null : (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ygntvPanel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          Icon(
            download.status == 'complete'
                ? Icons.download_done_rounded
                : Icons.downloading_rounded,
            color: download.status == 'complete'
                ? const Color(0xFF81D398)
                : ygntvGold,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  download.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active && percentage != null
                      ? '${download.statusLabel} · $percentage%'
                      : download.statusLabel,
                  style: const TextStyle(color: ygntvMuted, fontSize: 10),
                ),
                if (active) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: Colors.white12,
                    color: ygntvRed,
                  ),
                ],
                if (onPlay != null) ...[
                  const SizedBox(height: 9),
                  FilledButton.tonalIcon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Play offline'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove offline video',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _LibraryList extends StatefulWidget {
  const _LibraryList({required this.service, required this.mode});
  final AuthService service;
  final _LibraryMode mode;

  @override
  State<_LibraryList> createState() => _LibraryListState();
}

class _LibraryListState extends State<_LibraryList> {
  late Future<List<TvLibraryEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  Future<List<TvLibraryEntry>> _load() async {
    if (widget.mode == _LibraryMode.continueWatching) {
      return widget.service.getContinueWatching();
    }

    final allEntries = <TvLibraryEntry>[];
    final seen = <String>{};
    for (var page = 1; page <= 100; page++) {
      final pageEntries = widget.mode == _LibraryMode.saved
          ? await widget.service.getSavedContent(page: page)
          : await widget.service.getWatchHistory(page: page);
      if (pageEntries.isEmpty) break;

      final newEntries = pageEntries
          .where((entry) => seen.add('${entry.contentType}:${entry.contentId}'))
          .toList(growable: false);
      if (newEntries.isEmpty) break;
      allEntries.addAll(newEntries);
    }
    return allEntries;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _entries = next);
    try {
      await next;
    } catch (_) {
      // The page displays the same API error state after the refresh.
    }
  }

  Future<void> _remove(TvLibraryEntry entry) async {
    try {
      await widget.service.removeSavedContent(
        entry.contentType,
        entry.contentId,
        title: entry.title,
      );
      if (mounted) {
        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from My List.')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: ygntvRed,
    onRefresh: _refresh,
    child: FutureBuilder<List<TvLibraryEntry>>(
      future: _entries,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <TvLibraryEntry>[];
        if (entries.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const _ScrollableMessage(
            child: CircularProgressIndicator(color: ygntvRed),
          );
        }
        if (entries.isEmpty && snapshot.hasError) {
          return _ScrollableMessage(
            child: _InfoState(
              icon: Icons.wifi_off_rounded,
              title: 'Library could not be loaded',
              copy: snapshot.error.toString(),
              action: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ),
          );
        }
        if (entries.isEmpty) {
          final empty = switch (widget.mode) {
            _LibraryMode.continueWatching => (
              'Nothing in progress',
              'Start a movie or episode and it will appear here.',
            ),
            _LibraryMode.history => (
              'No watch history yet',
              'Titles you watch will be listed here.',
            ),
            _LibraryMode.saved => (
              'Your list is empty',
              'Save a movie or episode from its detail page.',
            ),
          };
          return _ScrollableMessage(
            child: _InfoState(
              icon: Icons.video_library_outlined,
              title: empty.$1,
              copy: empty.$2,
            ),
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 11),
          itemBuilder: (context, index) => _LibraryCard(
            key: ValueKey(
              '${entries[index].contentType}:${entries[index].contentId}',
            ),
            entry: entries[index],
            mode: widget.mode,
            onPlay: () => runMediaAction(
              context,
              widget.service,
              contentType: entries[index].contentType,
              contentId: entries[index].contentId,
              title: entries[index].title,
              posterUrl: entries[index].posterUrl,
              action: 'watch',
              initialPosition: entries[index].positionSeconds,
            ),
            onRemove: widget.mode == _LibraryMode.saved
                ? () => _remove(entries[index])
                : null,
          ),
        );
      },
    ),
  );
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.entry,
    required this.mode,
    required this.onPlay,
    this.onRemove,
    super.key,
  });

  final TvLibraryEntry entry;
  final _LibraryMode mode;
  final VoidCallback onPlay;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final duration = entry.durationSeconds ?? 0;
    final progress = duration > 0
        ? (entry.positionSeconds / duration).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ygntvPanel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 77,
              height: 104,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.contentType == 'episode' ? 'SERIES EPISODE' : 'MOVIE',
                  style: const TextStyle(
                    color: ygntvGold,
                    fontSize: 8,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (mode != _LibraryMode.saved && duration > 0) ...[
                  const SizedBox(height: 9),
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
                  Text(
                    '${(progress * 100).round()}% watched',
                    style: const TextStyle(color: ygntvMuted, fontSize: 9),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(
                        mode == _LibraryMode.continueWatching
                            ? 'Resume'
                            : 'Watch',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                      ),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Remove from My List',
                        onPressed: onRemove,
                        icon: const Icon(
                          Icons.bookmark_remove_outlined,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .26),
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
        Icon(icon, color: ygntvGold, size: 34),
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

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFF27242D),
    child: Center(child: Icon(Icons.movie_outlined, color: Color(0x77FFFFFF))),
  );
}
