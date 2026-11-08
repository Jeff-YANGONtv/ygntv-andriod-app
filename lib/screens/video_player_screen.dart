import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../auth/auth_service.dart';
import '../deep_links/app_deep_link.dart';
import '../widgets/app_page_link_button.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    required this.service,
    required this.url,
    required this.headers,
    required this.title,
    required this.posterUrl,
    required this.contentType,
    required this.contentId,
    this.initialPosition = 0,
    this.localFilePath,
    this.saveProgress = true,
    super.key,
  });

  final AuthService service;
  final String url;
  final Map<String, String> headers;
  final String title;
  final String posterUrl;
  final String contentType;
  final int contentId;
  final int initialPosition;
  final String? localFilePath;
  final bool saveProgress;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  Timer? _progressTimer;
  Timer? _controlsTimer;
  String? _error;
  bool _showControls = true;
  bool _landscapeMode = false;
  double _playbackSpeed = 1;
  bool _completedSaved = false;
  int _lastSavedPosition = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_toggleLandscape());
    _initializePlayer();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _saveProgress(),
    );
  }

  Future<void> _initializePlayer() async {
    final path = widget.localFilePath;
    final uri = path == null ? Uri.tryParse(widget.url) : null;
    if (path == null && (uri == null || uri.scheme != 'https')) {
      setState(() => _error = 'The video link is not valid.');
      return;
    }
    final options = VideoPlayerOptions(allowBackgroundPlayback: false);
    final controller = path != null
        ? VideoPlayerController.file(File(path), videoPlayerOptions: options)
        : VideoPlayerController.networkUrl(
            uri!,
            httpHeaders: widget.headers,
            videoPlayerOptions: options,
          );
    _controller = controller;
    controller.addListener(_onPlayerChanged);
    try {
      await controller.initialize();
      if (!mounted) return;
      final resumeAt = widget.initialPosition;
      if (resumeAt > 0 && resumeAt < controller.value.duration.inSeconds - 5) {
        await controller.seekTo(Duration(seconds: resumeAt));
      }
      if (_playbackSpeed != 1) {
        await controller.setPlaybackSpeed(_playbackSpeed);
      }
      await controller.play();
      _revealControlsTemporarily();
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = widget.localFilePath != null
              ? 'This downloaded video could not be opened. It may be incomplete or no longer available on this device.'
              : 'YGNTV could not open this protected stream. The video may not have an uploaded rendition yet.';
        });
      }
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }
    final value = controller.value;
    if (value.isCompleted && !_completedSaved) {
      _completedSaved = true;
      unawaited(_saveProgress(completed: true, force: true));
    }
    setState(() {});
  }

  Future<void> _saveProgress({
    bool completed = false,
    bool force = false,
  }) async {
    if (!widget.saveProgress) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    final position = value.position.inSeconds.clamp(0, 1 << 30);
    final duration = value.duration.inSeconds;
    if (duration <= 0 || (!force && position - _lastSavedPosition < 15)) return;
    _lastSavedPosition = position;
    try {
      await widget.service.updateViewingProgress(
        contentType: widget.contentType,
        contentId: widget.contentId,
        positionSeconds: position,
        durationSeconds: duration,
        completed: completed,
      );
    } catch (_) {
      // Playback continues if progress storage is temporarily unavailable.
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      await _saveProgress(force: true);
    } else {
      await controller.play();
    }
    _revealControlsTemporarily();
  }

  Future<void> _seek(double seconds) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.seekTo(Duration(seconds: seconds.round()));
    _revealControlsTemporarily();
  }

  Future<void> _seekRelative(int seconds) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration.inSeconds;
    final target = (controller.value.position.inSeconds + seconds)
        .clamp(0, duration)
        .toInt();
    await controller.seekTo(Duration(seconds: target));
    _revealControlsTemporarily();
  }

  void _revealControlsTemporarily() {
    _controlsTimer?.cancel();
    if (!mounted) return;
    if (!_showControls) setState(() => _showControls = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (_showControls) {
      _controlsTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      _revealControlsTemporarily();
    }
  }

  Widget _skipButton({required bool forward}) => IconButton.filledTonal(
    tooltip: forward ? 'Forward 15 seconds' : 'Back 15 seconds',
    onPressed: () => unawaited(_seekRelative(forward ? 15 : -15)),
    icon: SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            forward ? Icons.forward_rounded : Icons.replay_rounded,
            size: 36,
          ),
          Positioned(
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF35333A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '15',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _toggleLandscape() async {
    final next = !_landscapeMode;
    if (next) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
    }
    if (mounted) {
      setState(() => _landscapeMode = next);
      _revealControlsTemporarily();
    }
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    final controller = _controller;
    if (controller?.value.isInitialized == true) {
      await controller!.setPlaybackSpeed(speed);
    }
    if (mounted) setState(() {});
  }

  Widget _speedMenu() => PopupMenuButton<double>(
    tooltip: 'Playback speed',
    initialValue: _playbackSpeed,
    onSelected: (speed) => unawaited(_setPlaybackSpeed(speed)),
    itemBuilder: (context) => [1, 2, 3, 5, 10]
        .map(
          (speed) => PopupMenuItem<double>(
            value: speed.toDouble(),
            child: Text('$speed×${speed == _playbackSpeed ? '  ✓' : ''}'),
          ),
        )
        .toList(growable: false),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        '${_playbackSpeed.toStringAsFixed(_playbackSpeed % 1 == 0 ? 0 : 1)}×',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );

  Widget _standbyState(Widget content) => Stack(
    fit: StackFit.expand,
    children: [
      content,
      if (_landscapeMode)
        Positioned(
          top: 2,
          left: 4,
          child: IconButton.filledTonal(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controlsTimer?.cancel();
    unawaited(_saveProgress(force: true));
    _controller?.removeListener(_onPlayerChanged);
    unawaited(_controller?.dispose());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    final value = ready ? controller!.value : null;
    final duration = value?.duration.inSeconds ?? 0;
    final position = value?.position.inSeconds ?? 0;
    final sliderMax = duration > 0 ? duration.toDouble() : 1.0;
    final sliderValue = position.toDouble().clamp(0, sliderMax);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _landscapeMode
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF09090D),
              title: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                if (widget.contentId > 0 &&
                    {'movie', 'episode'}.contains(widget.contentType))
                  AppPageLinkButton(
                    uri: AppDeepLink.linkFor(
                      'watch/${widget.contentType}/${widget.contentId}',
                    ),
                  ),
                _speedMenu(),
                IconButton(
                  tooltip: 'Landscape fullscreen',
                  onPressed: () => unawaited(_toggleLandscape()),
                  icon: const Icon(Icons.screen_rotation_alt_rounded),
                ),
              ],
            ),
      body: SafeArea(
        top: false,
        bottom: !_landscapeMode,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: ready ? controller!.value.aspectRatio : 16 / 9,
                  child: _error != null
                      ? _standbyState(_errorState())
                      : !ready
                      ? _standbyState(
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE5454F),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _toggleControls,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              VideoPlayer(controller!),
                              if (_showControls)
                                Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0x66000000),
                                            Color(0x00000000),
                                            Color(0x99000000),
                                          ],
                                          stops: [0, .45, 1],
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _skipButton(forward: false),
                                            const SizedBox(width: 16),
                                            IconButton.filledTonal(
                                              onPressed: _togglePlayback,
                                              iconSize: 42,
                                              icon: Icon(
                                                value!.isPlaying
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            _skipButton(forward: true),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            4,
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                _timeLabel(position),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontFeatures: [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: Slider(
                                                  min: 0,
                                                  max: sliderMax,
                                                  value: sliderValue.toDouble(),
                                                  onChanged: duration > 0
                                                      ? _seek
                                                      : null,
                                                ),
                                              ),
                                              Text(
                                                _timeLabel(duration),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontFeatures: [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_landscapeMode)
                                      Positioned(
                                        top: 2,
                                        left: 4,
                                        right: 4,
                                        child: Row(
                                          children: [
                                            IconButton(
                                              tooltip: 'Back',
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .maybePop(),
                                              icon: const Icon(
                                                Icons.arrow_back_rounded,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                widget.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            _speedMenu(),
                                            IconButton(
                                              tooltip: 'Exit landscape',
                                              onPressed: () =>
                                                  unawaited(_toggleLandscape()),
                                              icon: const Icon(
                                                Icons.fullscreen_exit_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            if (!_landscapeMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFFE8C27E),
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.localFilePath != null
                            ? 'Downloaded video · available offline on this device'
                            : ready
                            ? 'Protected YGNTV playback · progress saves automatically'
                            : 'Opening the protected YGNTV stream…',
                        style: const TextStyle(
                          color: Color(0xFFA4A1AA),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() => Padding(
    padding: const EdgeInsets.all(26),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFE8C27E),
          size: 34,
        ),
        const SizedBox(height: 12),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE4E1E6), height: 1.45),
        ),
        const SizedBox(height: 10),
        const Text(
          'Playback needs an active Premium entitlement and a published video rendition.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFA4A1AA), fontSize: 11, height: 1.4),
        ),
      ],
    ),
  );
}

String _timeLabel(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hours = safe ~/ 3600;
  final minutes = (safe % 3600) ~/ 60;
  final remainder = safe % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = remainder.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
}
