import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/resilient_network_image.dart';
import '../widgets/ygntv_brand.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.service,
    required this.onOpenItem,
    super.key,
  });

  final AuthService service;
  final ValueChanged<CatalogItem> onOpenItem;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  Future<List<CatalogItem>>? _results;
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search([String? value]) {
    final query = (value ?? _queryController.text).trim();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _query = query;
      _results = query.isEmpty ? null : widget.service.searchCatalog(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 28),
      children: [
        Row(
          children: [
            const YgntvBrandLockup(compact: true),
            const Spacer(),
            AppPageLinkButton(uri: AppDeepLink.linkFor('search')),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Find your next story.',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Search the live YGNTV movies and series catalog.',
          style: TextStyle(color: ygntvMuted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _queryController,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Title, show, or movie',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: _search,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
            filled: true,
            fillColor: ygntvPanel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_results == null)
          const _SearchPrompt()
        else
          FutureBuilder<List<CatalogItem>>(
            future: _results,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 90),
                  child: Center(
                    child: CircularProgressIndicator(color: ygntvRed),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _MessageCard(
                  icon: Icons.wifi_off_rounded,
                  title: 'Search is unavailable',
                  copy: 'Check your connection and try again.',
                  action: TextButton.icon(
                    onPressed: () => _search(_query),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                );
              }
              final items = snapshot.data ?? const <CatalogItem>[];
              if (items.isEmpty) {
                return _MessageCard(
                  icon: Icons.search_off_rounded,
                  title: 'No matching titles',
                  copy: 'Try another title or a shorter search.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${items.length} results for “$_query”',
                    style: const TextStyle(color: ygntvMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 14,
                          childAspectRatio: .58,
                        ),
                    itemBuilder: (context, index) => _SearchPoster(
                      key: ValueKey('${items[index].kind}:${items[index].id}'),
                      item: items[index],
                      onTap: () => widget.onOpenItem(items[index]),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _SearchPoster extends StatelessWidget {
  const _SearchPoster({required this.item, required this.onTap, super.key});
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
            child: _PosterImage(url: item.posterUrl),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
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
          style: const TextStyle(color: ygntvMuted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => url.isEmpty
      ? const _PosterFallback()
      : ResilientNetworkImage(
          url: url,
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 185,
          tmdbMaxWidth: 500,
          fallback: const _PosterFallback(),
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

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 90),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.travel_explore_rounded, color: ygntvGold, size: 38),
          SizedBox(height: 12),
          Text(
            'Search movies and series',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text(
            'Results come from the YGNTV catalog.',
            style: TextStyle(color: ygntvMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
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
    margin: const EdgeInsets.only(top: 55),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(icon, color: ygntvGold, size: 29),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
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
