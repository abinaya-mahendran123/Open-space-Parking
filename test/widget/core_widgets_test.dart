import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/cards/app_stat_card.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';

import '../helpers/pump_app.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('shows label and triggers onPressed', (tester) async {
      var tapped = false;

      await pumpAppWidget(
        tester,
        PrimaryButton(
          label: 'Continue',
          onPressed: () => tapped = true,
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows loading indicator when isLoading', (tester) async {
      await pumpAppWidget(
        tester,
        const PrimaryButton(
          label: 'Submit',
          isLoading: true,
          onPressed: null,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });
  });

  group('AppErrorWidget', () {
    testWidgets('displays message and retry button', (tester) async {
      var retried = false;

      await pumpAppWidget(
        tester,
        AppErrorWidget(
          message: 'Network unavailable',
          onRetry: () => retried = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network unavailable'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(retried, isTrue);
    });
  });

  group('AppStatCard', () {
    testWidgets('renders value, label, and icon', (tester) async {
      await pumpAppWidget(
        tester,
        const SizedBox(
          width: 200,
          height: 140,
          child: AppStatCard(
            label: 'Assigned',
            value: '12',
            icon: Icons.assignment_outlined,
          ),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('Assigned'), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    });
  });
}
