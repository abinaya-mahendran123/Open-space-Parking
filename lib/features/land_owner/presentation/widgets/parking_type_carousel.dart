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

  static const _types = ParkingType.values;

  @override
  void initState() {
    super.initState();
    _currentIndex = _types.indexOf(widget.selectedType);
    _pageController = PageController(initialPage: _currentIndex);
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
    _pageController.dispose();
    super.dispose();
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
            },
            itemBuilder: (context, index) {
              final type = _types[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _ParkingTypeCard(type: type),
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
  const _ParkingTypeCard({required this.type});

  final ParkingType type;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = type.color;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            type.imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colorScheme.surfaceContainerHighest,
              child: Icon(type.icon, size: 64, color: color.withValues(alpha: 0.4)),
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
          // Swipe hint top-right
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
                  const Icon(Icons.swipe_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Swipe',
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
    );
  }
}
