import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';
import '../widgets/resilient_network_image.dart';
import '../widgets/ygntv_brand.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({required this.service, super.key});

  final AuthService service;

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  late Future<List<TvBlogPost>> _posts;

  @override
  void initState() {
    super.initState();
    _posts = widget.service.getBlogPosts();
  }

  Future<void> _refresh() async {
    setState(() => _posts = widget.service.getBlogPosts());
    try {
      await _posts;
    } catch (_) {
      // The feed card displays the retry state.
    }
  }

  void _openPost(TvBlogPost post) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            BlogDetailScreen(service: widget.service, slug: post.slug),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: ygntvRed,
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 28),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Refresh blog',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Blog',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Stories, updates, and notes from YGNTV.',
          style: TextStyle(color: ygntvMuted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<TvBlogPost>>(
          future: _posts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: CircularProgressIndicator(color: ygntvRed),
                ),
              );
            }
            if (snapshot.hasError) {
              return _BlogMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Blog is temporarily unavailable',
                copy: 'Check your connection and try again.',
                action: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              );
            }
            final posts = snapshot.data ?? const <TvBlogPost>[];
            if (posts.isEmpty) {
              return const _BlogMessage(
                icon: Icons.auto_stories_outlined,
                title: 'No stories yet',
                copy: 'New YGNTV blog stories will appear here.',
              );
            }
            return Column(
              children: [
                for (final post in posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _BlogPostCard(
                      post: post,
                      onTap: () => _openPost(post),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class BlogDetailScreen extends StatefulWidget {
  const BlogDetailScreen({
    required this.service,
    required this.slug,
    super.key,
  });

  final AuthService service;
  final String slug;

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  late Future<TvBlogPost> _post;

  @override
  void initState() {
    super.initState();
    _post = widget.service.getBlogPost(widget.slug);
  }

  Future<void> _refresh() async {
    setState(() => _post = widget.service.getBlogPost(widget.slug));
    try {
      await _post;
    } catch (_) {
      // Keep the detail error state visible for retry.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Back to Blog',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const YgntvBrandLockup(compact: true),
      actions: [AppPageLinkButton(uri: AppDeepLink.linkFor('blog'))],
    ),
    body: SafeArea(
      top: false,
      child: RefreshIndicator(
        color: ygntvRed,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 34),
          children: [
            const SizedBox(height: 12),
            FutureBuilder<TvBlogPost>(
              future: _post,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 90),
                    child: Center(
                      child: CircularProgressIndicator(color: ygntvRed),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _BlogMessage(
                    icon: Icons.wifi_off_rounded,
                    title: 'This story could not be opened',
                    copy: 'Check your connection or try again.',
                    action: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  );
                }

                final post = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (post.category.isNotEmpty)
                          _MetaPill(text: post.category),
                        if (post.date.isNotEmpty)
                          Text(
                            post.date,
                            style: const TextStyle(
                              color: ygntvMuted,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 25,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    if (post.author.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'By ${post.author}',
                        style: const TextStyle(color: ygntvMuted, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 15),
                    if (post.image.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ResilientNetworkImage(
                            url: post.image,
                            fit: BoxFit.cover,
                            cacheWidth: 780,
                            fallback: const ColoredBox(
                              color: Color(0xFF25222B),
                            ),
                          ),
                        ),
                      ),
                    if (post.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        post.excerpt,
                        style: const TextStyle(
                          color: Color(0xFFD0CDD3),
                          fontSize: 13,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 17),
                    AppPageLinkButton(uri: AppDeepLink.blogLinkFor(post.slug)),
                    const SizedBox(height: 18),
                    Text(
                      post.content.trim().isEmpty ? post.excerpt : post.content,
                      style: const TextStyle(
                        color: Color(0xFFE2DEE5),
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _BlogPostCard extends StatelessWidget {
  const _BlogPostCard({required this.post, required this.onTap});

  final TvBlogPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ygntvPanel,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 94,
                height: 108,
                child: post.image.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF25222B),
                        child: Icon(
                          Icons.auto_stories_outlined,
                          color: Color(0x66FFFFFF),
                        ),
                      )
                    : ResilientNetworkImage(
                        url: post.image,
                        fit: BoxFit.cover,
                        cacheWidth: 250,
                        fallback: const ColoredBox(
                          color: Color(0xFF25222B),
                          child: Icon(
                            Icons.auto_stories_outlined,
                            color: Color(0x66FFFFFF),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 108,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        post.category,
                        post.date,
                      ].where((value) => value.trim().isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ygntvGold,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        post.excerpt,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ygntvMuted,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ygntvMuted,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: ygntvGold,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: ygntvRed.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFC3C7),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _BlogMessage extends StatelessWidget {
  const _BlogMessage({
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
    margin: const EdgeInsets.only(top: 45),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(icon, color: ygntvGold, size: 30),
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
