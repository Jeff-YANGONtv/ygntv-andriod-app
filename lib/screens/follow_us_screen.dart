import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../widgets/ygntv_brand.dart';

class FollowUsScreen extends StatefulWidget {
  const FollowUsScreen({required this.service, super.key});

  final AuthService service;

  @override
  State<FollowUsScreen> createState() => _FollowUsScreenState();
}

class _FollowUsScreenState extends State<FollowUsScreen> {
  late Future<List<TvSocialLink>> _links;

  @override
  void initState() {
    super.initState();
    _links = widget.service.getSocialLinks();
  }

  Future<void> _reload() async {
    final next = widget.service.getSocialLinks();
    setState(() => _links = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder displays the current request error.
    }
  }

  Future<void> _open(TvSocialLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null ||
        !link.isUsable ||
        !['https', 'http', 'mailto'].contains(uri.scheme)) {
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showOpenError(link.name);
    } catch (_) {
      if (mounted) _showOpenError(link.name);
    }
  }

  void _showOpenError(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Could not open $name.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ygntvBackground,
    appBar: AppBar(title: const Text('Follow Us')),
    body: FutureBuilder<List<TvSocialLink>>(
      future: _links,
      builder: (context, snapshot) {
        final links = snapshot.data ?? const <TvSocialLink>[];
        return RefreshIndicator(
          color: ygntvRed,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              const Text(
                'Official YGNTV channels',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a channel to open its latest updates.',
                style: TextStyle(color: ygntvMuted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  links.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 46),
                  child: Center(
                    child: CircularProgressIndicator(color: ygntvRed),
                  ),
                )
              else if (snapshot.hasError)
                _StatusPanel(
                  icon: Icons.wifi_off_rounded,
                  message: 'Social links are unavailable right now.',
                  actionLabel: 'Try again',
                  onAction: _reload,
                )
              else if (links.isEmpty)
                const _StatusPanel(
                  icon: Icons.public_rounded,
                  message: 'No social links are available right now.',
                )
              else
                ...links.map(_socialCard),
            ],
          ),
        );
      },
    ),
  );

  Widget _socialCard(TvSocialLink link) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _open(link),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: ygntvRed.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_iconFor(link), color: ygntvGold, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ygntvMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new_rounded,
                color: ygntvMuted,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  IconData _iconFor(TvSocialLink link) {
    final value = '${link.name} ${link.icon}'.toLowerCase();
    if (value.contains('telegram')) return Icons.send_rounded;
    if (value.contains('facebook')) return Icons.people_alt_rounded;
    if (value.contains('tiktok')) return Icons.music_note_rounded;
    if (value.contains('youtube')) return Icons.ondemand_video_rounded;
    if (value.contains('instagram')) return Icons.camera_alt_rounded;
    return Icons.public_rounded;
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: ygntvPanel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .05)),
    ),
    child: Column(
      children: [
        Icon(icon, color: ygntvGold, size: 27),
        const SizedBox(height: 9),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 7),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
