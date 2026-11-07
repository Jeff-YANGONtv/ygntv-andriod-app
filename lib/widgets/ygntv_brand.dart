import 'package:flutter/material.dart';

const ygntvRed = Color(0xFFE5454F);
const ygntvGold = Color(0xFFE8C27E);
const ygntvBackground = Color(0xFF09090D);
const ygntvPanel = Color(0xFF191920);
const ygntvMuted = Color(0xFFA4A1AA);

class YgntvLogoMark extends StatelessWidget {
  const YgntvLogoMark({
    this.size = 52,
    this.radius = 15,
    this.showBorder = true,
    super.key,
  });

  final double size;
  final double radius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF020202),
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(color: Colors.white.withValues(alpha: .12))
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/brand/yangon-tv-logo.png',
          fit: BoxFit.cover,
          semanticLabel: 'Official Yangon TV logo',
          errorBuilder: (_, _, _) =>
              const Center(child: Icon(Icons.live_tv_rounded, color: ygntvRed)),
        ),
      ),
    );
  }
}

class YgntvBrandLockup extends StatelessWidget {
  const YgntvBrandLockup({
    this.compact = false,
    this.showTagline = false,
    super.key,
  });

  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 38.0 : 48.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        YgntvLogoMark(size: markSize, radius: compact ? 11 : 14),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text.rich(
              TextSpan(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .75,
                ),
                children: [
                  TextSpan(text: 'YANGON '),
                  TextSpan(
                    text: 'TV',
                    style: TextStyle(color: ygntvRed),
                  ),
                ],
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 4),
              const Text(
                'YOUR NEXT STORY STARTS HERE',
                style: TextStyle(
                  color: ygntvGold,
                  fontSize: 8,
                  letterSpacing: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
