import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import 'subscription_screen.dart';
import 'video_player_screen.dart';

Future<void> runMediaAction(
  BuildContext context,
  AuthService service, {
  required String contentType,
  required int contentId,
  required String title,
  required String posterUrl,
  required String action,
  int initialPosition = 0,
}) async {
  try {
    final playback = await service.getPlayback(contentType, contentId);
    if (!context.mounted) return;

    if (action == 'download') {
      final target = await service.createDownloadTarget(playback, title: title);
      if (target == null) {
        throw const AuthException(
          'No download source is available for this title yet.',
        );
      }
      if (target.openExternally) {
        final uri = Uri.tryParse(target.url);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw const AuthException('The download source could not be opened.');
        }
        await service.recordLocalNotification(
          title: 'Download opened',
          message: 'The download source for “$title” was opened.',
          type: 'download_opened',
        );
        if (context.mounted) {
          _showMessage(context, 'Opened the official download source.');
        }
        return;
      }
      await service.enqueueDownload(target);
      if (context.mounted) {
        _showMessage(
          context,
          'Download started. Track progress in Updates and find it in My Library offline.',
        );
      }
      return;
    }

    if (playback.playbackMode == 'custom_embed' && playback.embedUrl != null) {
      final embed = Uri.tryParse(playback.embedUrl!);
      if (embed == null ||
          embed.scheme != 'https' ||
          !{
            'nstream.cc',
            'www.nstream.cc',
            'nstream.org',
            'www.nstream.org',
          }.contains(embed.host.toLowerCase()) ||
          !await launchUrl(embed, mode: LaunchMode.externalApplication)) {
        throw const AuthException('The external stream could not be opened.');
      }
      await service.recordLocalNotification(
        title: 'Started watching',
        message: 'You opened “$title” to watch.',
        type: 'watch_started',
      );
      return;
    }

    final source =
        playback.protectedYgntvUrl ??
        playback.signedApiStreamUrl ??
        playback.hlsUrl;
    if (source == null) {
      throw const AuthException(
        'A protected YGNTV stream is not available for this title yet.',
      );
    }
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'https') {
      throw const AuthException('The returned stream source is invalid.');
    }
    final headers = <String, String>{};
    if (uri.host.toLowerCase() == 'stream.ygntv.org') {
      if (playback.playbackCookie.isEmpty) {
        throw const AuthException(
          'The playback session was not returned. Please sign in again and retry.',
        );
      }
      headers['Origin'] = 'https://ygntv.org';
      headers['Cookie'] = 'ygntv_playback_session=${playback.playbackCookie}';
    }
    await service.recordLocalNotification(
      title: 'Started watching',
      message:
          'You started watching “${playback.title.isNotEmpty ? playback.title : title}”.',
      type: 'watch_started',
    );
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          service: service,
          url: source,
          headers: headers,
          title: playback.title.isNotEmpty ? playback.title : title,
          posterUrl: posterUrl,
          contentType: contentType,
          contentId: contentId,
          initialPosition: initialPosition,
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    if (error is AuthException && error.statusCode == 402) {
      final openPlans = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1B1A21),
          title: const Text('Premium membership required'),
          content: const Text(
            'YGNTV checks your active Premium access before playback or download.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('View plans'),
            ),
          ],
        ),
      );
      if (openPlans == true && context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SubscriptionScreen(service: service),
          ),
        );
      }
      return;
    }
    _showMessage(context, error.toString());
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
