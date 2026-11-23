import 'package:flutter/material.dart';

import 'ygntv_brand.dart';

class YgntvHomeBannerFallback extends StatelessWidget {
  const YgntvHomeBannerFallback({
    required this.title,
    this.actionLabel,
    super.key,
  });

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final visibleTitle = title.trim().isEmpty ? 'Featured' : title.trim();
    final visibleAction = actionLabel?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF321014), Color(0xFF1B0D11), Color(0xFF171318)],
        ),
        border: Border.all(color: ygntvGold.withValues(alpha: .34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Row(
          children: [
            Container(
              width: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF56181E),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: ygntvRed.withValues(alpha: .65)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.live_tv_rounded,
                color: ygntvGold,
                size: 19,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'YANGON TV',
                      style: TextStyle(
                        color: ygntvGold,
                        fontSize: 8,
                        height: 1,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      visibleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (visibleAction != null && visibleAction.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 96),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A1919),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: ygntvGold.withValues(alpha: .44)),
                ),
                child: Text(
                  visibleAction.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ygntvGold,
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
