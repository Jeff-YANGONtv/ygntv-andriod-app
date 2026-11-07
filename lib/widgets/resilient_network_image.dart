import 'dart:async';

import 'package:flutter/material.dart';

String directTmdbImageUrlForWidth(String url, int maxWidth) {
  if (maxWidth <= 0) return url;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.toLowerCase() != 'image.tmdb.org') {
    return url;
  }
  final segments = uri.pathSegments;
  if (segments.length < 4 || segments[0] != 't' || segments[1] != 'p') {
    return url;
  }
  final requestedSize = switch (maxWidth) {
    <= 185 => 'w185',
    <= 342 => 'w342',
    <= 500 => 'w500',
    <= 780 => 'w780',
    _ => 'original',
  };
  final resized = [...segments]..[2] = requestedSize;
  return uri.replace(pathSegments: resized).toString();
}

/// Loads public artwork directly from its source and retries transient failures.
/// TMDB thumbnails can request a smaller direct rendition; no proxy or disk
/// cache is used.
class ResilientNetworkImage extends StatefulWidget {
  const ResilientNetworkImage({
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.tmdbMaxWidth,
    this.retryDelays = const [
      Duration(milliseconds: 700),
      Duration(seconds: 2),
    ],
    this.onRetry,
    super.key,
  });

  final String url;
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final int? tmdbMaxWidth;
  final List<Duration> retryDelays;
  final ValueChanged<int>? onRetry;

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  Timer? _retryTimer;
  int _retryCount = 0;
  int _requestGeneration = 0;

  String get _requestUrl {
    final width = widget.tmdbMaxWidth;
    if (width == null || width <= 0) return widget.url;
    return directTmdbImageUrlForWidth(widget.url, width);
  }

  @override
  void didUpdateWidget(covariant ResilientNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.tmdbMaxWidth != widget.tmdbMaxWidth) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryCount = 0;
      _requestGeneration++;
    }
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _retryCount >= widget.retryDelays.length) return;

    final url = _requestUrl;
    final nextAttempt = _retryCount + 1;
    _retryTimer = Timer(widget.retryDelays[_retryCount], () async {
      _retryTimer = null;
      if (!mounted || _requestUrl != url) return;

      try {
        await NetworkImage(url).evict();
      } catch (_) {
        // A failed/uncacheable image is still safe to request again.
      }

      if (!mounted || _requestUrl != url) return;
      widget.onRetry?.call(nextAttempt);
      setState(() {
        _retryCount = nextAttempt;
        _requestGeneration++;
      });
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) return widget.fallback;
    final requestUrl = _requestUrl;

    return Image.network(
      requestUrl,
      key: ValueKey('$requestUrl:$_requestGeneration'),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : widget.fallback,
      errorBuilder: (context, error, stackTrace) {
        _scheduleRetry();
        return widget.fallback;
      },
    );
  }
}
