import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../widgets/resilient_network_image.dart';

class CatalogBrowserScreen extends StatefulWidget {
  const CatalogBrowserScreen({
    required this.service,
    required this.kind,
    required this.title,
    required this.catalogFuture,
    required this.onOpenItem,
    required this.onRefresh,
    super.key,
  });

  final AuthService service;
  final String kind;
  final String title;
  final Future<List<CatalogItem>> catalogFuture;
  final ValueChanged<CatalogItem> onOpenItem;
  final Future<void> Function() onRefresh;

  @override
  State<CatalogBrowserScreen> createState() => _CatalogBrowserScreenState();
}

class _CatalogBrowserScreenState extends State<CatalogBrowserScreen> {
  static const _catalogPageSize = 48;

  final _queryController = TextEditingController();
  Timer? _searchDebounce;
  late Future<List<CatalogItem>> _catalog;
  late Future<List<CatalogItem>> _results;
  String _query = '';
  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    _catalog = _loadCatalogPages(widget.catalogFuture);
    _results = _catalog;
  }

  @override
  void didUpdateWidget(covariant CatalogBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalogFuture != widget.catalogFuture) {
      _catalog = _loadCatalogPages(widget.catalogFuture);
      if (_query.runes.length < 2) _results = _catalog;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<List<CatalogItem>> _loadCatalogPages(
    Future<List<CatalogItem>> firstPage,
  ) async {
    final items = <CatalogItem>[];
    final seen = <String>{};
    var batch = await firstPage;
    for (var page = 1; ; page++) {
      var added = 0;
      for (final item in batch) {
        if (item.kind != widget.kind) continue;
        final key = item.id != null
            ? '${widget.kind}:${item.id}'
            : '${widget.kind}:${item.slug.isNotEmpty ? item.slug : item.title}';
        if (seen.add(key)) {
          items.add(item);
          added++;
        }
      }
      if (batch.length < _catalogPageSize || added == 0) break;
      batch = await widget.service.loadCatalog(
        widget.kind,
        page: page + 1,
        perPage: _catalogPageSize,
      );
    }
    return items;
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    setState(() {
      _query = query;
      if (query.runes.length < 2) _results = _catalog;
    });
    if (query.runes.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _queryController.text.trim() == query) {
        _search(query);
      }
    });
  }

  void _search(String query) {
    _searchDebounce?.cancel();
    setState(() {
      _query = query.trim();
      _results = widget.service
          .searchCatalog(_query)
          .then(
            (items) => items.where((item) => item.kind == widget.kind).toList(),
          );
    });
  }

  void _selectGenre(String? genre) {
    setState(() {
      _selectedGenre = genre;
      _results = _query.runes.length >= 2
          ? widget.service
                .searchCatalog(_query)
                .then(
                  (items) =>
                      items.where((item) => item.kind == widget.kind).toList(),
                )
          : _catalog;
    });
  }

  List<CatalogItem> _filterItems(List<CatalogItem> items) {
    final selected = _selectedGenre?.toLowerCase();
    return items
        .where((item) => item.kind == widget.kind)
        .where(
          (item) =>
              selected == null ||
              item.genres.any(
                (genre) => genre.trim().toLowerCase() == selected,
              ),
        )
        .toList(growable: false);
  }

  List<String> _genresFor(List<CatalogItem> items) =>
      items
          .expand((item) => item.genres)
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: const Color(0xFFE5454F),
    onRefresh: widget.onRefresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _CatalogPinnedHeaderDelegate(
            extent: 112,
            child: Material(
              color: const Color(0xFF09090D),
              child: Column(
                children: [
                  SizedBox(
                    height: 50,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Refresh catalog',
                            onPressed: widget.onRefresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 62,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
                      child: TextField(
                        controller: _queryController,
                        textInputAction: TextInputAction.search,
                        onChanged: _onQueryChanged,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          hintText: widget.kind == 'movie'
                              ? 'Search Movie'
                              : 'Search Series',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? const Icon(Icons.manage_search_rounded)
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _queryController.clear();
                                    _onQueryChanged('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: const Color(0xFF19191F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key: const ValueKey('catalog-page-title'),
                  widget.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 13),
                _genreFilters(),
                const SizedBox(height: 13),
                _catalogResults(),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _genreFilters() => SizedBox(
    height: 37,
    child: FutureBuilder<List<CatalogItem>>(
      future: _catalog,
      builder: (context, snapshot) {
        final genres = _genresFor(snapshot.data ?? const <CatalogItem>[]);
        return ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: const Text('All'),
                selected: _selectedGenre == null,
                onSelected: (_) => _selectGenre(null),
              ),
            ),
            for (final genre in genres)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(genre),
                  selected:
                      _selectedGenre?.toLowerCase() == genre.toLowerCase(),
                  onSelected: (_) => _selectGenre(genre),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _catalogResults() => FutureBuilder<List<CatalogItem>>(
    future: _results,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.only(top: 75),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFE5454F),
            ),
          ),
        );
      }
      if (snapshot.hasError) {
        return _BrowseMessage(
          icon: Icons.wifi_off_rounded,
          title: _query.length >= 2
              ? 'Search is unavailable'
              : 'Could not load titles',
          copy: 'Check your connection and try again.',
          action: TextButton.icon(
            onPressed: () =>
                _query.length >= 2 ? _search(_query) : widget.onRefresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        );
      }

      final items = _filterItems(snapshot.data ?? const <CatalogItem>[]);
      if (items.isEmpty) {
        return _BrowseMessage(
          icon: _query.isEmpty
              ? Icons.movie_filter_outlined
              : Icons.search_off_rounded,
          title: _query.isEmpty
              ? 'No titles in this genre'
              : 'No matching titles',
          copy: _query.isEmpty
              ? 'Choose another genre or check back soon.'
              : 'Try another title or choose a different genre.',
        );
      }

      final countLabel = _query.runes.length >= 2
          ? '${items.length} ${widget.kind == 'movie' ? 'movies' : 'series'} found'
          : _selectedGenre == null
          ? '${items.length} ${widget.kind == 'movie' ? 'movies' : 'series'}'
          : '${items.length} titles in “$_selectedGenre”';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            countLabel,
            style: const TextStyle(color: Color(0xFFAAA7B0), fontSize: 11),
          ),
          const SizedBox(height: 11),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              childAspectRatio: .58,
            ),
            itemBuilder: (context, index) => _CatalogPoster(
              key: ValueKey('${items[index].kind}:${items[index].id}'),
              item: items[index],
              onTap: () => widget.onOpenItem(items[index]),
            ),
          ),
        ],
      );
    },
  );
}

class _CatalogPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CatalogPinnedHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _CatalogPinnedHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}

class _CatalogPoster extends StatelessWidget {
  const _CatalogPoster({required this.item, required this.onTap, super.key});
  final CatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: item.posterUrl.isEmpty
                ? const _PosterFallback()
                : ResilientNetworkImage(
                    url: item.posterUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    cacheWidth: 185,
                    tmdbMaxWidth: 500,
                    fallback: const _PosterFallback(),
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
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          [
            item.kind == 'movie' ? 'Movie' : 'Series',
            item.year,
          ].where((part) => part.isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFAAA7B0), fontSize: 8),
        ),
      ],
    ),
  );
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

class _BrowseMessage extends StatelessWidget {
  const _BrowseMessage({
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 35),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF19191F),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFFFFD27A), size: 29),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(
          copy,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFAAA7B0),
            fontSize: 11,
            height: 1.4,
          ),
        ),
        ?action,
      ],
    ),
  );
}
