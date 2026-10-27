import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/habit.dart';
import '../utils/dates.dart';

/// Minimum number of days of history the model needs.
const int aiMinHistory = 7;

/// TEST ONLY. flutter run --dart-define=AI_DEMO_DAYS=10 pretends every habit is
/// 10 days older (earlier days count as missed) so tips can be seen immediately.
const int aiDemoDays = int.fromEnvironment('AI_DEMO_DAYS', defaultValue: 0);

class AiTip {
  const AiTip(
      {required this.status,
      this.risk,
      this.level,
      this.message,
      this.daysNeeded});

  /// 'ok' or 'collecting' (not enough days yet).
  final String status;
  final double? risk;

  /// 'low', 'medium' or 'high'.
  final String? level;
  final String? message;
  final int? daysNeeded;

  bool get ready => status == 'ok' && message != null;
}

/// One message of the coach conversation. role is 'user' or 'assistant'.
class ChatTurn {
  const ChatTurn(this.role, this.text);
  final String role;
  final String text;
}

class AiQuotaException implements Exception {
  const AiQuotaException(this.retryAfter);

  final Duration retryAfter;
}

class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Builds the request for one habit.
  ///
  /// The history covers the days from the day the habit was created up to the
  /// last "decided" day: today if it is already recorded (then we predict
  /// tomorrow), otherwise yesterday (then we predict today). A day counts as 1
  /// only if it was recorded as a success. A missing record or a recorded
  /// lapse counts as 0. This matches how the model was trained on StickK data.
  static Map<String, dynamic> buildRequest(Habit habit, DateTime now) {
    final today = dateOnly(now);
    final lastDay = habit.entryOn(today) != null ? today : addDays(today, -1);
    final first = addDays(dateOnly(habit.createdAt), -aiDemoDays);
    final n = daysBetween(first, lastDay) + 1;
    final take = n <= 0 ? 0 : (n > 60 ? 60 : n);

    final history = <int>[];
    for (var i = take - 1; i >= 0; i--) {
      history.add(habit.entryOn(addDays(lastDay, -i))?.success == true ? 1 : 0);
    }

    // Reasons the person gave for missed days in the last two weeks.
    final reasons = <String>[];
    for (var i = 0; i < 14; i++) {
      final e = habit.entryOn(addDays(lastDay, -i));
      if (e != null && !e.success) reasons.addAll(e.reasons);
    }

    final target = addDays(lastDay, 1);
    return {
      'habit_type': habit.isQuit ? 'quit' : 'build',
      'category': habit.category,
      'history': history,
      'target_weekday': target.weekday - 1, // Monday = 0
      'reasons': reasons,
    };
  }

  /// Returns null if the service cannot be reached (the card is then hidden).
  Future<AiTip?> recommend(Habit habit, {DateTime? now}) async {
    final body = buildRequest(habit, now ?? DateTime.now());
    final days = (body['history'] as List).length;
    if (days < aiMinHistory) {
      return AiTip(status: 'collecting', daysNeeded: aiMinHistory - days);
    }
    try {
      final res = await _client
          .post(Uri.parse('$aiServiceUrl/recommend'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return AiTip(
        status: j['status'] as String,
        risk: (j['risk'] as num?)?.toDouble(),
        level: j['level'] as String?,
        message: j['message'] as String?,
        daysNeeded: j['days_needed'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sends the conversation plus a summary of the person's habits to the AI
  /// service and returns the coach reply, or null if it is unavailable.
  Future<String?> chat(List<ChatTurn> turns, List<Habit> habits,
      {DateTime? now}) async {
    final habitContext = habits.take(12).map((h) {
      final r = buildRequest(h, now ?? DateTime.now());
      return {
        ...r,
        'name': h.name.length > 100 ? h.name.substring(0, 100) : h.name,
        'reasons': (r['reasons'] as List).take(40).toList(),
      };
    }).toList();
    final recent = turns.length > 12 ? turns.sublist(turns.length - 12) : turns;

    String? token;
    try {
      token = await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      token = null;
    }
    try {
      final res = await _client
          .post(Uri.parse('$aiServiceUrl/chat'),
              headers: {
                'Content-Type': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'messages': [
                  for (final t in recent) {'role': t.role, 'content': t.text}
                ],
                'habits': habitContext,
              }))
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 429) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final detail = body is Map<String, dynamic> ? body['detail'] : null;
        if (detail is Map<String, dynamic> && detail['code'] == 'llm_quota') {
          final seconds = (detail['retry_after_seconds'] as num?)?.toInt() ??
              int.tryParse(res.headers['retry-after'] ?? '') ??
              3600;
          throw AiQuotaException(
              Duration(seconds: seconds.clamp(1, 86400).toInt()));
        }
        return null;
      }
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return j['reply'] as String?;
    } on AiQuotaException {
      rethrow;
    } catch (_) {
      return null;
    }
  }
}
