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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Image.asset(
                          type.imageAsset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.local_parking,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          type.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _types.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentIndex
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
