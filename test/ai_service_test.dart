import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/services/ai_service.dart';
import 'package:habit_tracker/utils/dates.dart';

Habit _habit(DateTime createdAt, {HabitType type = HabitType.build}) => Habit(
    id: '1',
    name: 'Walk',
    type: type,
    category: 'Fitness',
    colorValue: 0xFF5B6CFF,
    createdAt: createdAt);

void _success(Habit h, DateTime day) => h.entries[dateKey(day)] =
    Entry(success: true, timestamp: DateTime(2026, 10, 18));

void main() {
  test('predicts tomorrow when today is recorded', () {
    final now = DateTime(2026, 10, 18, 12); // Sunday
    final habit = _habit(DateTime(2026, 10, 9));
    for (var d = 14; d <= 18; d++) {
      _success(habit, DateTime(2026, 10, d));
    }
    final req = AiService.buildRequest(habit, now);
    expect(req['history'], [0, 0, 0, 0, 0, 1, 1, 1, 1, 1]);
    expect(req['target_weekday'], 0); // Monday
    expect(req['habit_type'], 'build');
  });

  test('predicts today when today is not recorded yet', () {
    final now = DateTime(2026, 10, 18, 12);
    final habit = _habit(DateTime(2026, 10, 9));
    for (var d = 14; d <= 17; d++) {
      _success(habit, DateTime(2026, 10, d));
    }
    final req = AiService.buildRequest(habit, now);
    expect((req['history'] as List).length, 9);
    expect(req['target_weekday'], 6); // Sunday
  });

  test('new habit has too little history', () async {
    final now = DateTime(2026, 10, 18, 12);
    final tip = await AiService().recommend(_habit(DateTime(2026, 10, 16)), now: now);
    expect(tip?.status, 'collecting');
  });

  test('chat sends messages and habits and decodes UTF-8', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(
          utf8.encode(jsonEncode({'reply': 'Привет! Маленький шаг.'})), 200,
          headers: {'content-type': 'application/json'});
    });
    final reply = await AiService(client: client).chat(
        [const ChatTurn('user', 'Help')], [_habit(DateTime(2026, 10, 9))],
        now: DateTime(2026, 10, 18, 12));
    expect(reply, 'Привет! Маленький шаг.');
    expect(sent['messages'], [
      {'role': 'user', 'content': 'Help'}
    ]);
    expect((sent['habits'] as List).single['name'], 'Walk');
  });
}
