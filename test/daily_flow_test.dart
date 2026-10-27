import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/screens/today_screen.dart';
import 'package:habit_tracker/services/habit_store.dart';
import 'package:habit_tracker/utils/dates.dart';

class MemoryStore extends HabitStore {
  MemoryStore() : super(userId: 'test-user');
  final List<Habit> data = [];
  @override
  List<Habit> get habits => data;

  @override
  Future<void> addRoutine(
      List<({String name, HabitType type, String category, int colorValue})>
          choices) async {
    for (final choice in choices) {
      data.add(Habit(
          id: '${data.length}',
          name: choice.name,
          type: choice.type,
          category: choice.category,
          colorValue: choice.colorValue,
          createdAt: DateTime.now()));
    }
    notifyListeners();
  }

  @override
  Future<void> setEntry(Habit habit, DateTime day, bool success,
      {String? trigger, List<String> reasons = const [], String? note}) async {
    habit.entries[dateKey(day)] = Entry(
        success: success,
        timestamp: DateTime.now(),
        reasons: reasons,
        note: note);
    notifyListeners();
  }
}

void main() {
  testWidgets('first visit selects build and quit habits once', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await tester.pumpWidget(MaterialApp(home: TodayScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Choose what you want to change'), findsOneWidget);
    await tester.tap(find.text('Drink water'));
    await tester.scrollUntilVisible(find.text('Stop smoking'), 180,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Stop smoking'));
    await tester.scrollUntilVisible(find.text('Start my daily routine'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Start my daily routine'));
    await tester.pumpAndSettle();
    expect(store.habits.map((h) => h.type), [HabitType.build, HabitType.quit]);
    expect(find.text('Choose what you want to change'), findsNothing);
    expect(find.text('Drink water'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missed habit saves multiple factors and comment',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    await store.addRoutine([
      (
        name: 'Read',
        type: HabitType.build,
        category: 'Study',
        colorValue: 0xFF5B6CFF
      )
    ]);
    await tester.pumpWidget(MaterialApp(home: TodayScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Choose what you want to change'), findsNothing);
    await tester.tap(find.byTooltip('Missed today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stress / anxiety'));
    await tester.tap(find.text('Not enough time'));
    await tester.enterText(find.byType(TextField), 'Work deadline');
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();
    final entry = store.habits.first.entryOn(DateTime.now())!;
    expect(entry.success, false);
    expect(entry.reasons, ['stress', 'time']);
    expect(entry.note, 'Work deadline');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('review allows successful retrospective check-in',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    final yesterday = addDays(dateOnly(DateTime.now()), -1);
    store.data.add(Habit(
        id: 'old',
        name: 'Walk',
        type: HabitType.build,
        category: 'Fitness',
        colorValue: 0xFF5B6CFF,
        createdAt: yesterday));
    await tester.pumpWidget(MaterialApp(home: TodayScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How did the past days go?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Walk').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();
    expect(store.data.first.entryOn(yesterday)?.success, true);
    expect(find.text('All caught up!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
