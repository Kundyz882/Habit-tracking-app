# BM Habits — AI habit tracker

Flutter / Dart mobile app for the study "Development and Usability Evaluation
of a Mobile Habit-Tracking Application with AI".

Animated branded splash appears while Firebase restores the session.

The app includes personalised AI recommendations and a conversational habit
coach. AI features require the separately deployed recommendation API; configure
its URL with the `AI_SERVICE_URL` Dart define when building or running the app.

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
- AI risk estimates and short personalised tips based on habit check-ins.
- AI habit coach chat, which receives a limited summary of the user's habits
  and recent check-ins to suggest practical next steps.

## Daily routine and reflections
- First-time users select daily build/quit habits or add their own. Choices persist in Firestore.
- Today offers done/held-on and missed/slipped check-ins, with optional multiple factors and a note.
- Unrecorded past days remain unknown. A review card offers the last 7 days; the habit calendar allows editing older visible dates.
- Review happens inside the app on return; no scheduled or push notifications are configured.
- Entry fields include `success`, `timestamp` (recorded time), `reasons` (stable factor codes), and `note`. The entries map key identifies the habit day, including retrospective records.
- Reasons are self-reported. The AI service uses up to 60 days of success/missed
  history and reasons from the last 14 days to generate recommendations. Tips
  appear after at least 7 days of history. The coach receives summaries for up
  to 12 habits and the most recent 12 chat messages. Chat history is kept in
  memory while the app is open.
- AI responses depend on the separately hosted backend. If it is unavailable,
  AI cards may be hidden and the coach will show a connection message. The chat
  API may also enforce a temporary quota.

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

## AI service configuration
Set `AI_SERVICE_URL` in `lib/config.dart` or pass it as a Dart define, for
example:

```bash
flutter run --dart-define=AI_SERVICE_URL=https://habit-tracking-application-with-ai.onrender.com
```

The backend must provide `POST /recommend` and `POST /chat` endpoints. The
app's API client is in `lib/services/ai_service.dart`; the recommendations
card and coach screen are in `lib/widgets/ai_tips_section.dart` and
`lib/screens/ai_coach_screen.dart`.
