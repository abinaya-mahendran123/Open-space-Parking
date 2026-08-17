import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';

class AppFadeSlide extends StatefulWidget {
  const AppFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 16),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<AppFadeSlide> createState() => _AppFadeSlideState();
}

class _AppFadeSlideState extends State<AppFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class AppStaggeredList extends StatelessWidget {
  const AppStaggeredList({
    super.key,
    required this.children,
    this.itemGap = AppSpacing.md,
    this.baseDelay = const Duration(milliseconds: 60),
  });

  final List<Widget> children;
  final double itemGap;
  final Duration baseDelay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          AppFadeSlide(
            delay: baseDelay * i,
            child: children[i],
          ),
          if (i < children.length - 1) SizedBox(height: itemGap),
        ],
      ],
    );
  }
}
