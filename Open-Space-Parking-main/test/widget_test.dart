import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

import 'helpers/pump_app.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
  });

  testWidgets('app auth scaffold smoke test', (tester) async {
    await pumpAppWidget(
      tester,
      const AuthScaffold(
        title: 'Open Space Parking',
        child: SizedBox.shrink(),
      ),
    );

    expect(find.text('Open Space Parking'), findsOneWidget);
  });
}
