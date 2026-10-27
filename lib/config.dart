/// Address of the AI service (habit_ai_service).
///
/// Override when running or building:
///   flutter run --dart-define=AI_SERVICE_URL=https://your-service.onrender.com
/// Android emulator reaches your computer at http://10.0.2.2:8000
const String aiServiceUrl = String.fromEnvironment(
  'AI_SERVICE_URL',
  defaultValue: 'http://localhost:8000',
);
