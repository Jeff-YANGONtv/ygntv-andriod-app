import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/resilient_network_image.dart';
import '../widgets/ygntv_brand.dart';
import 'media_actions.dart';

class MediaDetailScreen extends StatefulWidget {
  const MediaDetailScreen({
    required this.item,
    required this.service,
    super.key,
  });

  final CatalogItem item;
  final AuthService service;

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  late Future<CatalogItem> _detail;
  String _tab = 'Review';
  int? _selectedSeasonId;
  bool _saved = false;
  bool _saveBusy = false;
  String? _savingEpisode;

  @override
  void initState() {
    super.initState();
    _detail = widget.service.loadDetail(widget.item);
    if (widget.item.kind == 'movie' && widget.item.id != null) {
      _loadSaved();
    }
  }

  Future<void> _loadSaved() async {
    try {
      final entries = await widget.service.getSavedContent();
      if (!mounted) return;
      setState(() {
        _saved = entries.any(
          (entry) =>
              entry.contentType == 'movie' && entry.contentId == widget.item.id,
        );
      });
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    final id = widget.item.id;
    if (id == null || _saveBusy) return;
    setState(() => _saveBusy = true);
    try {
      if (_saved) {
        await widget.service.removeSavedContent(
          'movie',
          id,
          title: widget.item.title,
        );
      } else {
        await widget.service.saveContent('movie', id, title: widget.item.title);
      }
      if (mounted) {
        setState(() => _saved = !_saved);
        _message(_saved ? 'Added to My List.' : 'Removed from My List.');
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  Future<void> _saveEpisode(CatalogEpisode episode) async {
    final id = episode.id;
    if (id == null || _savingEpisode != null) return;
    final key = '$id';
    setState(() => _savingEpisode = key);
    try {
      await widget.service.saveContent('episode', id, title: episode.title);
      if (mounted) _message('Episode added to My List.');
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _savingEpisode = null);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    body: FutureBuilder<CatalogItem>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }
        if (snapshot.hasError) {
          return _error(snapshot.error.toString());
        }
        return _content(snapshot.data ?? widget.item);
      },
    ),
  );

  Widget _loading() => CustomScrollView(
    slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: ygntvBackground,
        title: const YgntvBrandLockup(compact: true),
      ),
      const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: ygntvRed)),
      ),
    ],
  );

  Widget _error(String message) => CustomScrollView(
    slivers: [
      SliverAppBar(
        pinned: true,
        backgroundColor: ygntvBackground,
        title: const YgntvBrandLockup(compact: true),
      ),
      SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, color: ygntvGold, size: 35),
                const SizedBox(height: 12),
                const Text(
                  'Title details could not be loaded.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ygntvMuted, fontSize: 11),
                ),
                const SizedBox(height: 11),
                FilledButton.tonalIcon(
                  onPressed: () => setState(
                    () => _detail = widget.service.loadDetail(widget.item),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _content(CatalogItem item) {
    final seasons = [...item.seasons]
      ..sort((a, b) => a.number.compareTo(b.number));
    final selectedSeason = seasons.length == 1
        ? seasons.first
        : seasons.where((season) => season.id == _selectedSeasonId).firstOrNull;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: ygntvBackground,
          foregroundColor: Colors.white,
          actions: [
            if (item.slug.isNotEmpty)
              AppPageLinkButton(
                uri: AppDeepLink.linkFor(
                  '${item.kind == 'movie' ? 'movie' : 'series'}/${item.slug}',
                ),
              ),
            if (item.kind == 'movie' && item.id != null)
              IconButton(
                tooltip: _saved ? 'Remove from My List' : 'Save to My List',
                onPressed: _saveBusy ? null : _toggleSaved,
                icon: Icon(
                  _saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  color: _saved ? ygntvGold : Colors.white,
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _Backdrop(
              url: item.backdropUrl.isNotEmpty
                  ? item.backdropUrl
                  : item.posterUrl,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(19, 7, 19, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const YgntvBrandLockup(compact: true),
                const SizedBox(height: 18),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.08,
                    letterSpacing: -.7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                _MetaLine(item: item),
                if (item.genres.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: item.genres
                        .take(5)
                        .map((genre) => _GenreChip(label: genre))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                _ActionTabs(
                  selected: _tab,
                  onSelect: (value) => setState(() => _tab = value),
                ),
                const SizedBox(height: 16),
                if (_tab == 'Review')
                  _review(item)
                else if (item.kind == 'movie')
                  _movieAction(item, _tab)
                else
                  _episodeGuide(item, seasons, selectedSeason, _tab),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _review(CatalogItem item) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Review',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        item.synopsis.isNotEmpty
            ? item.synopsis
            : 'No review or synopsis has been added for this title yet.',
        style: const TextStyle(
          color: Color(0xFFCAC6D0),
          fontSize: 12,
          height: 1.55,
        ),
      ),
      if (item.kind == 'series') ...[
        const SizedBox(height: 20),
        const Text(
          'Series details',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${item.seasons.length} ${item.seasons.length == 1 ? 'season' : 'seasons'} in the Episode Guide',
          style: const TextStyle(color: ygntvMuted, fontSize: 11),
        ),
      ],
    ],
  );

  Widget _movieAction(CatalogItem item, String action) {
    final isWatch = action == 'Watch';
    return _ActionPanel(
      title: isWatch ? 'Watch this movie' : 'Download this movie',
      copy: isWatch
          ? 'Playback is authorized by YGNTV and uses the protected streaming source.'
          : 'The app will use an available YGNTV download link or the protected video rendition.',
      icon: isWatch
          ? Icons.play_circle_outline_rounded
          : Icons.download_rounded,
      buttonLabel: isWatch ? 'Watch now' : 'Download',
      onTap: item.id == null
          ? null
          : () => runMediaAction(
              context,
              widget.service,
              contentType: 'movie',
              contentId: item.id!,
              title: item.title,
              posterUrl: item.posterUrl,
              action: isWatch ? 'watch' : 'download',
            ),
      unavailable: item.id == null,
    );
  }

  Widget _episodeGuide(
    CatalogItem item,
    List<CatalogSeason> seasons,
    CatalogSeason? selectedSeason,
    String action,
  ) {
    if (seasons.isEmpty) {
      return _ActionPanel(
        title: 'Episode Guide unavailable',
        copy: 'The YGNTV show API did not return season and episode records for this series.',
        icon: Icons.list_alt_rounded,
        buttonLabel: 'Not available',
        unavailable: true,
      );
    }
    final isWatch = action == 'Watch';
    if (selectedSeason == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isWatch ? 'Episode Guide · Watch' : 'Episode Guide · Download',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a season to view its episodes.',
            style: TextStyle(color: ygntvMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...seasons.map(
            (season) => _SeasonCard(
              season: season,
              onTap: () => setState(() => _selectedSeasonId = season.id),
            ),
          ),
        ],
      );
    }
    final episodes = [...selectedSeason.episodes]
      ..sort((a, b) => a.number.compareTo(b.number));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Season ${selectedSeason.number}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (seasons.length > 1)
              TextButton.icon(
                onPressed: () => setState(() => _selectedSeasonId = null),
                icon: const Icon(Icons.list_rounded, size: 16),
                label: const Text('All seasons'),
              ),
          ],
        ),
        if (selectedSeason.year.isNotEmpty)
          Text(
            selectedSeason.year,
            style: const TextStyle(color: ygntvMuted, fontSize: 10),
          ),
        if (selectedSeason.review.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            selectedSeason.review,
            style: const TextStyle(
              color: ygntvMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (episodes.isEmpty)
          const _EmptyEpisodes()
        else
          ...episodes.map(
            (episode) => _EpisodeCard(
              episode: episode,
              showPoster: item.posterUrl,
              action: action,
              busy: _savingEpisode == '${episode.id}',
              onAction: episode.id == null || !episode.available
                  ? null
                  : () => runMediaAction(
                      context,
                      widget.service,
                      contentType: 'episode',
                      contentId: episode.id!,
                      title: '${item.title} · ${episode.title}',
                      posterUrl: episode.thumbnailUrl.isNotEmpty
                          ? episode.thumbnailUrl
                          : item.posterUrl,
                      action: isWatch ? 'watch' : 'download',
                    ),
              onSave: episode.id == null ? null : () => _saveEpisode(episode),
            ),
          ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (url.isNotEmpty)
        ResilientNetworkImage(
          url: url,
          fit: BoxFit.cover,
          cacheWidth: 780,
          fallback: const _BackdropFallback(),
        )
      else
        const _BackdropFallback(),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x22000000), Color(0xFF09090D)],
          ),
        ),
      ),
    ],
  );
}

class _BackdropFallback extends StatelessWidget {
  const _BackdropFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5E2B31), Color(0xFF17141A), Color(0xFF09090D)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.movie_filter_outlined,
        color: Color(0x44FFFFFF),
        size: 72,
      ),
    ),
  );
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.item});
  final CatalogItem item;
  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      item.kind == 'movie' ? 'Movie' : 'Series',
      if (item.year.isNotEmpty) item.year,
      if (item.rating > 0) '★ ${item.rating.toStringAsFixed(1)}',
    ];
    return Text(
      parts.join('  ·  '),
      style: const TextStyle(color: ygntvMuted, fontSize: 11),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF211F27),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFD7D3DC),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ActionTabs extends StatelessWidget {
  const _ActionTabs({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: ['Review', 'Watch', 'Download'].map((label) {
      final active = selected == label;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: active ? ygntvRed : const Color(0xFF1A1920),
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: () => onSelect(label),
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : ygntvMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.title,
    required this.copy,
    required this.icon,
    required this.buttonLabel,
    this.onTap,
    this.unavailable = false,
  });
  final String title;
  final String copy;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback? onTap;
  final bool unavailable;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: Colors.white.withValues(alpha: .06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ygntvGold, size: 23),
        const SizedBox(height: 9),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          copy,
          style: const TextStyle(color: ygntvMuted, fontSize: 10, height: 1.45),
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: unavailable ? null : onTap,
            icon: Icon(icon, size: 17),
            label: Text(unavailable ? 'Unavailable' : buttonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: ygntvRed,
              disabledBackgroundColor: Colors.white12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season, required this.onTap});
  final CatalogSeason season;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 41,
          height: 41,
          decoration: BoxDecoration(
            color: ygntvRed.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Text(
              '${season.number}',
              style: const TextStyle(
                color: ygntvRed,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        title: Text(
          season.title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${season.episodes.length} ${season.episodes.length == 1 ? 'episode' : 'episodes'}${season.year.isNotEmpty ? ' · ${season.year}' : ''}',
          style: const TextStyle(color: ygntvMuted, fontSize: 10),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: ygntvMuted),
      ),
    ),
  );
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.showPoster,
    required this.action,
    required this.busy,
    required this.onAction,
    required this.onSave,
  });
  final CatalogEpisode episode;
  final String showPoster;
  final String action;
  final bool busy;
  final VoidCallback? onAction;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final image = episode.thumbnailUrl.isNotEmpty
        ? episode.thumbnailUrl
        : showPoster;
    final available = episode.available && episode.id != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ygntvPanel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: .05)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 78,
              height: 67,
              child: image.isEmpty
                  ? const _BackdropFallback()
                  : ResilientNetworkImage(
                      url: image,
                      fit: BoxFit.cover,
                      cacheWidth: 185,
                      tmdbMaxWidth: 500,
                      fallback: const _BackdropFallback(),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EPISODE ${episode.number}',
                  style: const TextStyle(
                    color: ygntvGold,
                    fontSize: 8,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  episode.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (episode.duration.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    episode.duration,
                    style: const TextStyle(color: ygntvMuted, fontSize: 9),
                  ),
                ],
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  onPressed: available ? onAction : null,
                  icon: busy
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          action == 'Watch'
                              ? Icons.play_arrow_rounded
                              : Icons.download_rounded,
                          size: 15,
                        ),
                  label: Text(available ? action : 'Unavailable'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 31),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ),
          if (onSave != null)
            IconButton(
              tooltip: 'Save episode to My List',
              onPressed: onSave,
              icon: const Icon(
                Icons.bookmark_add_outlined,
                size: 19,
                color: ygntvMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyEpisodes extends StatelessWidget {
  const _EmptyEpisodes();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Text(
        'No episode records were returned for this season.',
        style: TextStyle(color: ygntvMuted, fontSize: 11),
      ),
    ),
  );
}
