import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared shell layout with themed bottom navigation.
///
/// On Android system back:
/// - Non-home tab → switch to Home (does not exit)
/// - Home tab → require a second back within 2s to exit
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

  /// Tab index treated as the root (usually Dashboard/Home).
  final int homeIndex;

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  DateTime? _lastBackAtHome;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
        appBar: widget.appBar,
        body: widget.body,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.06),
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
