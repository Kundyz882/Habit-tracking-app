import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/screens/splash_screen.dart';

void main() {
  testWidgets('splash animates brand into view and disposes safely',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pump(const Duration(milliseconds: 700));
    final halfway = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(halfway, greaterThan(0));
    expect(halfway, lessThan(1));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(find.text('BM Habits'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion shows brand immediately on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          disableAnimations: true, textScaler: TextScaler.linear(1.5)),
      child: SplashScreen(),
    )));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
