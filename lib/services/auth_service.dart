import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AppUser {
  const AppUser({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String email;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get lastName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.length > 1 ? parts.skip(1).join(' ') : '';
  }
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _subscription;
  String? profileSyncError;
  bool _disposed = false;

  AppUser? get user {
    final current = _auth.currentUser;
    if (current == null) return null;
    return AppUser(
      id: current.uid,
      name: current.displayName ?? current.email?.split('@').first ?? '',
      email: current.email ?? '',
    );
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    String? currentPassword,
  }) async {
    final current = _auth.currentUser;
    if (current == null) throw StateError('Not signed in');
    final fullName = [firstName.trim(), lastName.trim()]
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (fullName.isEmpty) throw ArgumentError('Enter your first name');
    if (email.trim().toLowerCase() != current.email?.toLowerCase()) {
      if (currentPassword == null || current.email == null) {
        throw StateError('Enter your current password to change email');
      }
      final credential = EmailAuthProvider.credential(
          email: current.email!, password: currentPassword);
      await current.reauthenticateWithCredential(credential);
      await current.verifyBeforeUpdateEmail(email.trim());
    }
    await current.updateDisplayName(fullName);
    await FirebaseFirestore.instance.collection('users').doc(current.uid).set(
      {
        'name': fullName,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
      },
      SetOptions(merge: true),
    );
    notifyListeners();
  }

  Future<void> load() async {
    await _auth.authStateChanges().first;
    _subscription = _auth.userChanges().listen((_) {
      notifyListeners();
      unawaited(syncProfile());
    });
  }

  /// Merge the name into the profile without touching its habits collection.
  /// Runs for restored sessions, sign-in, and display-name changes.
  Future<void> syncProfile() async {
    final current = _auth.currentUser;
    final name = current?.displayName?.trim();
    if (current == null || name == null || name.isEmpty) return;
    String? error;
    try {
      await FirebaseFirestore.instance.collection('users').doc(current.uid).set(
        {'name': name},
        SetOptions(merge: true),
      );
    } catch (_) {
      error = 'Unable to save your profile name. Please try again.';
    }
    if (!_disposed &&
        _auth.currentUser?.uid == current.uid &&
        profileSyncError != error) {
      profileSyncError = error;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<String?> login(
      {required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<void> logout() => _auth.signOut();

  String _message(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'An account with this email already exists',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Incorrect email or password',
        'invalid-email' => 'Enter a valid email',
        'weak-password' => 'Choose a stronger password',
        'network-request-failed' =>
          'Check your internet connection and try again',
        'too-many-requests' => 'Too many attempts. Please try again later',
        _ => e.message ?? 'Unable to sign in. Please try again',
      };

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
