import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';

/// Open Space Parking mark — blue square with "P".
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
  });

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: size * 0.28,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          'P',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

/// Welcome screen banner — design art only (no duplicate buttons).
///
/// Fills the parent with the full illustration (logo, text, car) using
/// [BoxFit.contain] so nothing is cropped and text stays sharp on phones.
class WelcomeBannerImage extends StatelessWidget {
  const WelcomeBannerImage({super.key, this.height});

  final double? height;

  static const _bannerAsset = 'assets/images/welcome_banner.png';

  @override
  Widget build(BuildContext context) {
    Widget imageFor(BoxConstraints constraints) {
      return Image.asset(
        _bannerAsset,
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => OpenSkyHeroIllustration(
          height: height ?? constraints.maxHeight.clamp(200.0, 600.0),
        ),
      );
    }

    if (height != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) => imageFor(constraints),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) => imageFor(constraints),
      ),
    );
  }
}

/// Cropped hero — illustration band only (no logo/buttons from reference JPG).
class WelcomeHeroImage extends StatelessWidget {
  const WelcomeHeroImage({super.key, required this.height});

  final double height;

  static const _asset = 'assets/images/welcome_hero.jpg';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              _asset,
              width: width,
              height: height * 3.1,
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.26),
              errorBuilder: (_, __, ___) =>
                  OpenSkyHeroIllustration(height: height),
            ),
          ),
        );
      },
    );
  }
}

/// City skyline + car — Option A welcome hero (matches design mockup).
class OpenSkyHeroIllustration extends StatelessWidget {
  const OpenSkyHeroIllustration({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: const _OpenSkyHeroPainter(),
      ),
    );
  }
}

class _OpenSkyHeroPainter extends CustomPainter {
  const _OpenSkyHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;
    final roadHeight = h - horizon;

    // Sky band
    final skyRect = Rect.fromLTWH(0, 0, w, horizon);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEFF6FF), Color(0xFFF7F9FC)],
        ).createShader(skyRect),
    );

    // Ground / road
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, roadHeight),
      Paint()..color = const Color(0xFFE2E8F0),
    );

    // Buildings — soft blue blocks
    final buildingPaint = Paint()..color = const Color(0xFFBFDBFE);
    final buildingDark = Paint()..color = const Color(0xFF93C5FD);

    void drawBuilding(double x, double top, double bw, double bh, {bool dark = false}) {
      final rect = Rect.fromLTWH(x, top, bw, horizon - top);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        dark ? buildingDark : buildingPaint,
      );
      // Windows
      final windowPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
      for (var row = top + 8; row < horizon - 10; row += 10) {
        for (var col = x + 5; col < x + bw - 5; col += 8) {
          canvas.drawRect(Rect.fromLTWH(col, row, 4, 5), windowPaint);
        }
      }
    }

    drawBuilding(w * 0.04, horizon - h * 0.28, w * 0.11, h * 0.28);
    drawBuilding(w * 0.17, horizon - h * 0.42, w * 0.13, h * 0.42, dark: true);
    drawBuilding(w * 0.33, horizon - h * 0.22, w * 0.09, h * 0.22);
    drawBuilding(w * 0.45, horizon - h * 0.36, w * 0.12, h * 0.36, dark: true);
    drawBuilding(w * 0.60, horizon - h * 0.26, w * 0.10, h * 0.26);
    drawBuilding(w * 0.73, horizon - h * 0.38, w * 0.11, h * 0.38, dark: true);
    drawBuilding(w * 0.87, horizon - h * 0.30, w * 0.09, h * 0.30);

    // Road + car layout
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, 3),
      Paint()..color = const Color(0xFFCBD5E1),
    );

    final carW = w * 0.34;
    final carH = h * 0.09;
    final carX = w * 0.48;
    final carBottom = horizon + roadHeight * 0.42;

    // Trees
    void drawTree(double cx, double cy, double r) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy + r * 0.6), width: 4, height: r * 0.5),
        Paint()..color = const Color(0xFF92400E),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()..color = AppColors.available.withValues(alpha: 0.75),
      );
    }

    drawTree(w * 0.18, carBottom - carH * 1.1, h * 0.055);
    drawTree(w * 0.80, carBottom - carH * 1.05, h * 0.05);

    // Parking sign
    final signX = w * 0.72;
    final signBaseY = carBottom - carH * 0.2;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(signX, signBaseY), width: 3, height: h * 0.14),
      Paint()..color = const Color(0xFF64748B),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(signX, signBaseY - h * 0.1),
          width: h * 0.09,
          height: h * 0.09,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.primary,
    );
    final signText = TextPainter(
      text: TextSpan(
        text: 'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.05,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    signText.paint(
      canvas,
      Offset(signX - signText.width / 2, signBaseY - h * 0.1 - signText.height / 2),
    );

    // Car — side-view sedan (matches welcome mockup)

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(carX, carBottom + 2),
        width: carW * 0.9,
        height: carH * 0.35,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );

    // Lower body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(carX - carW / 2, carBottom - carH, carW, carH),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, Paint()..color = AppColors.primary);

    // Cabin / roof (smaller, sits on rear half of body)
    final cabinW = carW * 0.48;
    final cabinH = carH * 0.72;
    final cabinRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        carX - carW * 0.08,
        carBottom - carH - cabinH + carH * 0.18,
        cabinW,
        cabinH,
      ),
      const Radius.circular(7),
    );
    canvas.drawRRect(cabinRect, Paint()..color = AppColors.primaryDark);

    // Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          carX - carW * 0.04,
          carBottom - carH - cabinH + carH * 0.24,
          cabinW * 0.42,
          cabinH * 0.55,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFBFDBFE),
    );

    // Rear window
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          carX + carW * 0.12,
          carBottom - carH - cabinH + carH * 0.28,
          cabinW * 0.28,
          cabinH * 0.45,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF93C5FD),
    );

    // Headlight
    canvas.drawCircle(
      Offset(carX - carW / 2 + carW * 0.06, carBottom - carH * 0.35),
      carH * 0.1,
      Paint()..color = const Color(0xFFFDE68A),
    );

    // Wheels
    final wheelR = carH * 0.22;
    final wheelY = carBottom - carH * 0.05;
    final wheelPaint = Paint()..color = const Color(0xFF334155);
    canvas.drawCircle(Offset(carX - carW * 0.28, wheelY), wheelR, wheelPaint);
    canvas.drawCircle(Offset(carX + carW * 0.28, wheelY), wheelR, wheelPaint);
    final hubPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawCircle(Offset(carX - carW * 0.28, wheelY), wheelR * 0.42, hubPaint);
    canvas.drawCircle(Offset(carX + carW * 0.28, wheelY), wheelR * 0.42, hubPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
