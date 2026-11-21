# Requirements matrix (provisional)

**Source of truth:** no lecturer rubric exists in this repository (checked `docs/`, the research folders and the repository root). The six rows below are the areas supplied in the assignment brief and are therefore **provisional**. They will be replaced verbatim when the rubric is available. Status values are honest: `planned`, `implemented`, `verified`, `blocked`.

| # | Requirement | Planned implementation | Where it appears | How it is demonstrated | Status | Dependency / open question |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Firebase integration | `firebase_core` bootstrap; Auth, Cloud Firestore and FCM used for real app data | `lib/main.dart`, `lib/services/firebase_bootstrap.dart`, `lib/data/*` | Sign in, save a run, reopen history; console message received | Planned | Firebase project, Android `google-services.json`, options via `--dart-define` |
| 2 | State management | `provider` + `ChangeNotifier` controllers, one per concern, injected at the root | `lib/state/*`, `lib/app.dart` | Pause/resume updates timer and button state; history list reacts to Firestore stream | Planned | None |
| 3 | Advanced Dart | Sealed `RunPhase` state machine with exhaustive `switch`; `Stream<Position>`; `async/await`; records for coordinates; generic `ApiResult<T>`; typed models; custom exceptions; extensions for pace/date formatting | `lib/domain/*`, `lib/services/*`, `lib/ui/*` | Walk through the recording state transitions and the weather error path | Planned | None |
| 4 | Push notifications | FCM permission, token save, topic subscription, foreground banner, background handler | `lib/services/push_service.dart`, `lib/app.dart` | Send a console message to the `nearpace_updates` topic | Planned | Firebase project; physical/emulator device with Play services |
| 5 | Public/open API | Open-Meteo current weather for the run start point, with timeout and fallback | `lib/services/weather_service.dart`, `lib/ui/result_screen.dart` | Result screen shows temperature/conditions; airplane mode shows fallback | Planned | Network access at demo time |
| 6 | Authentication and authorization | Firebase Auth email/password; owner-only profile/activities; public aggregate leaderboard rules | `lib/state/auth_controller.dart`, `firestore.rules` | Two-account read attempt denied; leaderboard hides private fields | Planned | Firebase project; rules deployed or emulator test |

## Not required by the provisional checklist

Leaderboard is optional and included only because it is small. Clubs, events, feeds, messaging, route planning, Strava integration, billing and anti-cheat are excluded unless the rubric names them.

## Evidence log

| Date | Check | Result |
| --- | --- | --- |
| 2026-11-21 | Repository inspection | No Flutter project existed; only research, `docs/` archive and an icon. Flutter SDK absent from the machine, so the SDK was installed outside the repository. |
| 2026-11-21 | Rubric search | No rubric or syllabus found. Six areas remain provisional. |

_Updated as implementation and verification proceed._
