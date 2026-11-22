# Requirements matrix (provisional)

**Source of truth:** no lecturer rubric exists in this repository (checked `docs/`, the research folders and the repository root). The six rows below are the areas supplied in the assignment brief and are therefore **provisional**. They will be replaced verbatim when the rubric is available. Status values are honest: `planned`, `implemented`, `verified`, `blocked`.

| # | Requirement | Planned implementation | Where it appears | How it is demonstrated | Status | Dependency / open question |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Firebase integration | `firebase_core` bootstrap; Auth, Cloud Firestore, and FCM wired via repository interfaces | `lib/main.dart`, `lib/config/firebase_bootstrap.dart`, `lib/data/repositories/*`, `lib/app.dart` | Sign in, save run to Firestore, watch activities stream; tests pass with mock repositories and live contracts | Implemented | Firebase project; supply values via `--dart-define-from-file=dart_defines.json` |
| 2 | State management | `provider` + `ChangeNotifier` (`NearPaceController`), constructor-injected repositories and services | `lib/state/nearpace_controller.dart`, `lib/app.dart` | Responsive UI; 42/42 unit and widget tests pass; pause/resume/finish state machine | Verified | None |
| 3 | Advanced Dart | Sealed `RunState` state machine; pure-Dart `RunSession` GPS filtering (accuracy <= 35m, jitter >= 1.5m, speed <= 12 m/s); `GeoPointLite` distance; route downsampling cap | `lib/domain/*`, `lib/data/repositories/*`, `lib/services/*` | Verified via dedicated unit tests in `test/run_session_test.dart` and `test/repository_mappers_test.dart` | Verified | None |
| 4 | Push notifications | `firebase_messaging` with `POST_NOTIFICATIONS` runtime prompt, token persistence to `users/{uid}`, topic `nearpace_updates`, foreground banner, top-level background handler | `lib/services/push_notification_service.dart`, `lib/state/nearpace_controller.dart`, `lib/ui/screens/profile_screen.dart` | In-app `ForegroundNoticeBanner` for foreground pushes; live FCM activated when configured | Implemented | Android device/emulator with Google Play Services for live push delivery |
| 5 | Public/open API | Open-Meteo current weather for run start point, short timeout (6s) and graceful `null` fallback | `lib/data/repositories/weather_repository.dart`, `lib/ui/widgets/weather_badge.dart` | Verified with `MockClient` in `test/weather_repository_test.dart` covering 200 OK, timeout, 500 error, and malformed JSON | Verified | None (Open-Meteo is open and keyless) |
| 6 | Authentication and authorization | Firebase Auth email/password, `firestore.rules` owner-only profile/activities, public aggregate leaderboard with strict field whitelist and DEF-1 fix | `lib/data/repositories/auth_repository.dart`, `firestore.rules`, `firestore.indexes.json` | Verified via `test/auth_repository_test.dart` and `firestore.rules` security audit | Verified | Firebase project for live cloud sign-in |

## Not required by the provisional checklist

Leaderboard is optional and included only because it is small. Clubs, events, feeds, messaging, route planning, Strava integration, billing and anti-cheat are excluded unless the rubric names them.

## Evidence log

| Date | Check | Result |
| --- | --- | --- |
| 2026-11-21 | Repository inspection | No Flutter project existed; only research, `docs/` archive and an icon. Flutter SDK installed outside repository. |
| 2026-11-21 | Rubric search | No rubric or syllabus found. Six areas remain provisional. |
| 2026-11-21 | Phase 2 Architecture Audit | Verified MVP UI, identified DEF-1 (`firestore.rules` activities read/delete bug) and DEF-2 (`Timestamp` vs ISO string mismatch). |
| 2026-11-22 | Phase 3 Backend & Platform Integration | Fixed DEF-1 in `firestore.rules`. Implemented `AuthRepository`, `ProfileRepository`, `ActivityRepository` (with route downsampling <= 250 pts), `LeaderboardRepository`, `OpenMeteoWeatherRepository`, `GeolocatorTrackingService`, and `FcmPushNotificationService`. Added 22 new unit tests (42/42 passed). `flutter analyze` 0 issues. `dart format` clean across 47 files. |

_Updated as implementation and verification proceed._
