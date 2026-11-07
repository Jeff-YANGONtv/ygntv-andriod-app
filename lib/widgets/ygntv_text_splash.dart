import 'package:flutter/material.dart';

class YgntvTextSplash extends StatefulWidget {
  const YgntvTextSplash({super.key});

  @override
  State<YgntvTextSplash> createState() => _YgntvTextSplashState();
}

class _YgntvTextSplashState extends State<YgntvTextSplash>
    with SingleTickerProviderStateMixin {
  static const _background = Color(0xFF08090B);
  static const _brandRed = Color(0xFFE5454F);

  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    body: Semantics(
      label: 'Loading Yangon TV',
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .82, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
              ),
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'YGN',
                      style: TextStyle(color: _brandRed),
                    ),
                    TextSpan(
                      text: ' TV',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 58,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.8,
                ),
              ),
            ),
            const SizedBox(height: 23),
            AnimatedBuilder(
              animation: _dots,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LOADING YGNTV',
                    style: TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (var index = 0; index < 3; index++) ...[
                    if (index > 0) const SizedBox(width: 4),
                    Opacity(
                      opacity: _dotOpacity(index),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _brandRed,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 4, height: 4),
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

  double _dotOpacity(int index) {
    final phase = (_dots.value * 3 - index + 3) % 3;
    return phase < 1 ? .25 + (phase * .75) : .25;
  }
}
