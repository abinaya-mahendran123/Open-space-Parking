import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';

/// Open Space Parking mark — custom P + pin logo when available.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 64,
    this.showShadow = true,
  });

  static const assetPath = 'assets/images/brand_logo_p.png';

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;
    final pad = size * 0.08;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.navigationBlue.withValues(alpha: 0.28),
                  blurRadius: size * 0.28,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => _FallbackP(size: size, radius: radius),
        ),
      ),
    );
  }
}

class _FallbackP extends StatelessWidget {
  const _FallbackP({required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.navigationBlue,
        borderRadius: BorderRadius.circular(radius),
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
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8F4FF), Color(0xFFF7FAFC)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final building = Paint()..color = const Color(0xFFBFDBFE).withValues(alpha: 0.55);
    final groundY = size.height * 0.62;
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = const Color(0xFFE2E8F0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, groundY - 48, 36, 48),
        const Radius.circular(4),
      ),
      building,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.22, groundY - 70, 44, 70),
        const Radius.circular(4),
      ),
      building,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.72, groundY - 56, 40, 56),
        const Radius.circular(4),
      ),
      building,
    );

    final car = Paint()..color = AppColors.navigationBlue;
    final cx = size.width * 0.5;
    final cy = groundY - 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 88, height: 28),
        const Radius.circular(8),
      ),
      car,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
