import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../utils/dates.dart';

/// TEST ONLY. flutter run --dart-define=FORCE_GROUP=B shows AI tips without
/// editing Firestore. Never pass it in builds given to participants.
const String _forceGroup = String.fromEnvironment('FORCE_GROUP');

class HabitStore extends ChangeNotifier {
  HabitStore({required this.userId});

  final String userId;
  final List<Habit> _habits = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  bool _disposed = false;
  String? error;

  /// Study group: 'A' = tracking only, 'B' = tracking + AI tips.
  /// Set per participant in the Firestore document users/{uid}, field "group".
  /// Defaults to 'A' if missing or if the read fails.
  String group = 'A';

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('habits');

  List<Habit> get habits => List.unmodifiable(_habits);

  Habit? byId(String id) {
    for (final habit in _habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  Future<void> _loadGroup() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      group = doc.data()?['group'] == 'B' ? 'B' : 'A';
      if (_forceGroup == 'B') group = 'B'; // test only
    } catch (_) {
      group = _forceGroup == 'B' ? 'B' : 'A';
    }
  }

  Future<void> load() async {
    await _loadGroup();
    final initial =
        await _collection.get(const GetOptions(source: Source.server));
    _receive(initial);
    _subscription =
        _collection.snapshots().listen(_receive, onError: (Object e) {
      error = 'Unable to sync habits. Check your connection and try again.';
      _notify();
    });
  }

  void _receive(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_disposed) return;
    try {
      final habits = snapshot.docs
          .map((doc) => Habit.fromJson({...doc.data(), 'id': doc.id}))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _habits
        ..clear()
        ..addAll(habits);
      error = null;
    } catch (_) {
      error = 'Unable to read habit data.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
      error = null;
    } catch (_) {
      error = 'Unable to save changes to the database. Please try again.';
    }
    _notify();
  }

  Future<void> add(
          {required String name,
          required HabitType type,
          required String category,
          required int colorValue}) =>
      _write(() {
        final doc = _collection.doc();
        final habit = Habit(
            id: doc.id,
            name: name,
            type: type,
            category: category,
            colorValue: colorValue,
            createdAt: DateTime.now());
        return doc.set(habit.toJson());
      });

  Future<void> addRoutine(
          List<({String name, HabitType type, String category, int colorValue})>
              choices) =>
      _write(() {
        final batch = FirebaseFirestore.instance.batch();
        final now = DateTime.now();
        for (final choice in choices) {
          final doc = _collection.doc();
          batch.set(
              doc,
              Habit(
                      id: doc.id,
                      name: choice.name,
                      type: choice.type,
                      category: choice.category,
                      colorValue: choice.colorValue,
                      createdAt: now)
                  .toJson());
        }
        return batch.commit();
      });

  Future<void> remove(String id) => _write(() => _collection.doc(id).delete());

  Future<void> setEntry(Habit habit, DateTime day, bool success,
          {String? trigger, List<String> reasons = const [], String? note}) =>
      _write(() => _collection.doc(habit.id).update({
            'entries.${dateKey(day)}': Entry(
                    success: success,
                    timestamp: DateTime.now(),
                    trigger: trigger,
                    reasons: reasons,
                    note: note)
                .toJson(),
          }));

  Future<void> clearEntry(Habit habit, DateTime day) =>
      _write(() => _collection.doc(habit.id).update({
            'entries.${dateKey(day)}': FieldValue.delete(),
          }));

  Future<void> toggleToday(Habit habit) {
    final today = DateTime.now();
    return habit.entryOn(today)?.success == true
        ? clearEntry(habit, today)
        : setEntry(habit, today, true);
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
