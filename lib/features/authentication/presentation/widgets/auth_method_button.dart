import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthMethodButton extends StatelessWidget {
  const AuthMethodButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.55)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Center(child: leading),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final stroke = side * 0.13;
    // Leave room for half the stroke width on every edge.
    final inset = stroke * 0.55 + 1;
    final diameter = side - inset * 2;
    final rect = Rect.fromLTWH(
      (size.width - diameter) / 2,
      (size.height - diameter) / 2,
      diameter,
      diameter,
    );
    final center = rect.center;
    final radius = rect.width / 2 - stroke / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    Paint strokePaint(Color color) => Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Full "G" ring with a ~60° opening on the right (filled by the blue bar).
    const gapStart = math.pi / 6; // 30°
    const quarterTurn = math.pi / 2;
    const gap = math.pi / 3; // 60°

    canvas.drawArc(arcRect, gapStart, quarterTurn, false, strokePaint(_red));
    canvas.drawArc(
      arcRect,
      gapStart + quarterTurn,
      quarterTurn,
      false,
      strokePaint(_yellow),
    );
    canvas.drawArc(
      arcRect,
      gapStart + quarterTurn * 2,
      gap,
      false,
      strokePaint(_green),
    );
    canvas.drawArc(
      arcRect,
      gapStart + quarterTurn * 2 + gap,
      gap,
      false,
      strokePaint(_blue),
    );

    final barHeight = stroke * 0.92;
    canvas.drawRRect(
      RRect.fromLTRBR(
        center.dx - stroke * 0.08,
        center.dy - barHeight / 2,
        center.dx + radius + stroke * 0.08,
        center.dy + barHeight / 2,
        Radius.circular(barHeight / 2),
      ),
      Paint()
        ..color = _blue
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
