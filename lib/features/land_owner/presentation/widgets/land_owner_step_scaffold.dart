import 'package:flutter/material.dart';

import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/step_indicator.dart';

class LandOwnerStepScaffold extends StatelessWidget {
  const LandOwnerStepScaffold({
    super.key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
    this.onBack,
    this.bottomBar,
    required this.child,
  });

  final String title;
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;
  final VoidCallback? onBack;
  final Widget? bottomBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = context.isDesktop ? 720.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: StepIndicator(
                  currentStep: currentStep,
                  totalSteps: totalSteps,
                  labels: stepLabels,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: child,
                ),
              ),
              if (bottomBar != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: bottomBar!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
