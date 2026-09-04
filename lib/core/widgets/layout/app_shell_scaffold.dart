import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared shell layout with Open Sky bottom navigation.
class AppShellScaffold extends StatefulWidget {
  const AppShellScaffold({
    super.key,
    this.appBar,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.homeIndex = 0,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final int homeIndex;

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  DateTime? _lastBackAtHome;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final atHome = widget.selectedIndex == widget.homeIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (!atHome) {
          widget.onDestinationSelected(widget.homeIndex);
          return;
        }

        final now = DateTime.now();
        final previous = _lastBackAtHome;
        if (previous != null &&
            now.difference(previous) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }

        _lastBackAtHome = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: widget.appBar,
        body: widget.body,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border(
              top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.35),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .shadow
                    .withValues(alpha: isLight ? 0.05 : 0.2),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: NavigationBar(
              height: 64,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              destinations: widget.destinations,
            ),
          ),
        ),
      ),
    );
  }
}
