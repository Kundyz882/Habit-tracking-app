# BM Habits — Version A (no AI)

Flutter / Dart mobile app for the study "Development and Usability Evaluation
of a Mobile Habit-Tracking Application with AI".

Animated branded splash appears while Firebase restores the session.

## Features
- Create habits of two types: **build** (do it) and **quit** (avoid it)
- Daily check-in: tap to complete; for quit habits, "I held on" or "I slipped"
  (with an optional trigger)
- Current streak, best streak, 30-day completion rate
- History: 7-day strip per habit, 5-week heatmap, recent activity
- Sign up / log in (name, email, password), session is remembered, log out in Profile
- Habits are stored separately per user
- Firebase Authentication for email/password accounts
- Cloud Firestore in project `habit-tracker-797b8`, database `(default)`, region `eur3`
- Habits and daily entries: `users/{uid}/habits/{habitId}`; rules restrict access to the owner
- Live updates across devices. Persistent Firestore caching is disabled.
- Existing local prototype accounts and habits are not migrated; register a Firebase account.

## Daily routine and reflections
- First-time users select daily build/quit habits or add their own. Choices persist in Firestore.
- Today offers done/held-on and missed/slipped check-ins, with optional multiple factors and a note.
- Unrecorded past days remain unknown. A review card offers the last 7 days; the habit calendar allows editing older visible dates.
- Review happens inside the app on return; no scheduled or push notifications are configured.
- Entry fields include `success`, `timestamp` (recorded time), `reasons` (stable factor codes), and `note`. The entries map key identifies the habit day, including retrospective records.
- These are self-reported factors; no AI analysis is performed.

## Run
```bash
cd habit_tracker
flutter create . --platforms=android,ios --org kz.aitu   # generates android/ and ios/
flutter pub get
flutter test
flutter run
```
`flutter create .` does not overwrite the existing `lib/` and `test/` files.

## Structure
```
lib/
  main.dart                    app shell + bottom navigation
  theme.dart                   colours, card style, Material 3 theme
  models/habit.dart            Habit, Entry, streak logic
  services/habit_store.dart    Firestore persistence
  utils/dates.dart             date helpers
  screens/                     today, history, add habit, habit detail
```

## Data model (ready for the AI module)
Each check-in is stored as an `Entry`: success flag, timestamp (time of
check-in) and an optional trigger for lapses. Together with the habit type,
category and the date key, this covers the fields needed later for the
features (day of week, time, streak, missed days in the last 7).

## Next steps
1. Extend Firestore data model as needed
2. Usage logging for engagement metrics (active days, completion rate)
3. Version B: AI recommendation service (Python) and a recommendations card
