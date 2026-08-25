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
  const GoogleLogoIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
        // Keep strokes fully visible inside the button.
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.16;
    // Inset so the stroke width never gets clipped by the box edge.
    final radius = (size.shortestSide - stroke) / 2 - 0.5;
    final center = Offset(size.width / 2, size.height / 2);
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    final yellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    // Classic Google "G" ring segments (angles in radians).
    canvas.drawArc(arcRect, -0.45, 1.25, false, blue);
    canvas.drawArc(arcRect, 0.85, 1.05, false, green);
    canvas.drawArc(arcRect, 1.95, 1.0, false, yellow);
    canvas.drawArc(arcRect, 3.0, 0.95, false, red);

    final barHeight = stroke * 0.95;
    final barLeft = center.dx - stroke * 0.15;
    final barRight = center.dx + radius;
    canvas.drawRRect(
      RRect.fromLTRBR(
        barLeft,
        center.dy - barHeight / 2,
        barRight,
        center.dy + barHeight / 2,
        Radius.circular(barHeight / 4),
      ),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
