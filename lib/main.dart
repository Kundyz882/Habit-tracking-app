import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/today_screen.dart';
import 'services/auth_service.dart';
import 'services/habit_store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitApp());
}

class HabitApp extends StatefulWidget {
  const HabitApp({super.key});

  @override
  State<HabitApp> createState() => _HabitAppState();
}

class _HabitAppState extends State<HabitApp> {
  late Future<AuthService> _startup = _start();
  AuthService? _auth;

  Future<AuthService> _start() async {
    // Show the animation while Firebase and the saved session initialize.
    final results = await Future.wait<Object?>([
      _initialize(),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    return results.first as AuthService;
  }

  Future<AuthService> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    final auth = AuthService();
    try {
      await auth.load();
      if (!mounted) {
        auth.dispose();
      } else {
        _auth = auth;
      }
      return auth;
    } catch (_) {
      auth.dispose();
      rethrow;
    }
  }

  @override
  void dispose() {
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BM Habits',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: FutureBuilder<AuthService>(
            future: _startup,
            builder: (context, snapshot) {
              if (snapshot.hasError &&
                  snapshot.connectionState == ConnectionState.done) {
                return Scaffold(
                    body: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('BM Habits',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text(
                        'Unable to start. Check your connection and try again.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => setState(() {
                              _startup = _start();
                            }),
                        child: const Text('Retry')),
                  ]),
                )));
              }
              final auth = snapshot.data;
              return AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                child: auth == null
                    ? const SplashScreen(key: ValueKey('splash'))
                    : AuthGate(key: const ValueKey('account'), auth: auth),
              );
            }),
      );
}

/// Shows the login screen until a user is signed in, then opens that user's
/// own habit store.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _userId;
  Future<HabitStore>? _storeFuture;
  HabitStore? _store;

  void _closeStore() {
    _store?.dispose();
    _store = null;
  }

  @override
  void dispose() {
    _closeStore();
    super.dispose();
  }

  Future<HabitStore> _open(String userId) async {
    final store = HabitStore(userId: userId);
    try {
      await store.load();
      if (!mounted || _userId != userId) {
        store.dispose();
      } else {
        _store = store;
      }
      return store;
    } catch (_) {
      store.dispose();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final user = widget.auth.user;
        if (user == null) {
          _closeStore();
          _userId = null;
          _storeFuture = null;
          return AuthScreen(auth: widget.auth);
        }
        if (_userId != user.id) {
          _closeStore();
          _userId = user.id;
          _storeFuture = _open(user.id);
        }
        return FutureBuilder<HabitStore>(
          future: _storeFuture,
          builder: (context, snap) {
            if (snap.hasError) {
              return Scaffold(
                  body: Center(
                      child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load habits from the database.'),
                  FilledButton(
                      onPressed: () => setState(() {
                            _storeFuture = _open(user.id);
                          }),
                      child: const Text('Retry')),
                  TextButton(
                      onPressed: widget.auth.logout,
                      child: const Text('Log out')),
                ],
              )));
            }
            final store = snap.data;
            if (store == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return RootScreen(
              key: ValueKey(user.id),
              store: store,
              auth: widget.auth,
            );
          },
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.store, required this.auth});

  final HabitStore store;
  final AuthService auth;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              final error = widget.store.error;
              return error == null
                  ? const SizedBox.shrink()
                  : MaterialBanner(
                      content: Text(error),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() {
                            widget.store.error = null;
                          }),
                          child: const Text('Dismiss'),
                        )
                      ],
                    );
            }),
        Expanded(
            child: IndexedStack(
          index: _index,
          children: [
            TodayScreen(store: widget.store),
            HistoryScreen(store: widget.store),
            ProfileScreen(auth: widget.auth, store: widget.store),
          ],
        )),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
