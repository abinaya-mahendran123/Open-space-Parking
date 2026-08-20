import 'dart:async';

import 'package:flutter/material.dart';

import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';

class ParkingTypeCarousel extends StatefulWidget {
  const ParkingTypeCarousel({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final ParkingType selectedType;
  final ValueChanged<ParkingType> onTypeSelected;

  @override
  State<ParkingTypeCarousel> createState() => _ParkingTypeCarouselState();
}

class _ParkingTypeCarouselState extends State<ParkingTypeCarousel> {
  late final PageController _pageController;
  late int _currentIndex;
  Timer? _autoSlideTimer;

  static const _types = ParkingType.values;

  @override
  void initState() {
    super.initState();
    _currentIndex = _types.indexOf(widget.selectedType);
    _pageController = PageController(initialPage: _currentIndex);
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant ParkingTypeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      final index = _types.indexOf(widget.selectedType);
      if (index != _currentIndex) {
        _currentIndex = index;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    if (_types.length <= 1) return;
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextIndex = (_currentIndex + 1) % _types.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _openImagePreview(BuildContext context, ParkingType type) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (context) => _ParkingTypeImagePreview(type: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _types.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              widget.onTypeSelected(_types[index]);
              _startAutoSlide();
            },
            itemBuilder: (context, index) {
              final type = _types[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _ParkingTypeCard(
                  type: type,
                  onTap: () => _openImagePreview(context, type),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_types.length, (index) {
            final selected = index == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: selected ? 20 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ParkingTypeCard extends StatelessWidget {
  const _ParkingTypeCard({
    required this.type,
    required this.onTap,
  });

  final ParkingType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = type.color;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                type.imageAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                errorBuilder: (_, __, ___) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    type.icon,
                    size: 64,
                    color: color.withValues(alpha: 0.4),
                  ),
                ),
              ),
          // Gradient overlay at bottom for readability
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(type.icon, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          type.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to view',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingTypeImagePreview extends StatelessWidget {
  const _ParkingTypeImagePreview({required this.type});

  final ParkingType type;

  @override
  Widget build(BuildContext context) {
    final color = type.color;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Pinch to zoom',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(type.icon, size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                clipBehavior: Clip.none,
                child: Center(
                  child: Image.asset(
                    type.imageAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    errorBuilder: (_, __, ___) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type.icon,
                          size: 72,
                          color: color.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          type.label,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                type.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
