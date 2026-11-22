# Implementation plan

**Approach:** small vertical slices, each ending in a runnable check. No stage starts before its dependency exists. Firebase console setup is the only external dependency and is documented rather than faked.

| Stage | Work | Depends on | Exit check | Status |
| --- | --- | --- | --- | --- |
| A | Inspect repository, confirm no rubric, write scope and matrix | - | Documents reviewed against actual repository | Done |
| B1 | Install Flutter SDK outside the repo, create the Flutter project, preserve existing files | A | `flutter --version`, project files present, research untouched | Done |
| B2 | Add dependencies, theme, routing shell, Firebase bootstrap that fails visibly when unconfigured | B1 | `flutter analyze` clean | Done |
| B3 | Auth controller and screens; auth gate | B2 | Sign-up/sign-in validation unit tests | Done |
| B4 | Firestore models, repositories, Security Rules, indexes | B2 | Model round-trip tests; rules reviewed (DEF-1 fixed) | Done |
| C1 | Run state machine, distance/pace calculation, route filtering | B2 | Unit tests for distance, pace, pause and empty routes | Done |
| C2 | Location service + recording screen (permission, fix, pause, finish) | C1 | Widget test for state labels; real geolocator service wired | Done |
| C3 | Result screen, save activity, history and detail | B4, C2 | Save/load path reviewed; async loading/error handling | Done |
| D1 | Weather service (Open-Meteo) with typed result and fallback | C3 | Parser tests; offline fallback widget test | Done |
| D2 | Weekly leaderboard with opt-in and city filter | B4 | Rules and query reviewed; composite index documented | Done |
| D3 | FCM service, token persistence, foreground banner, console instructions | B2 | Code compiles; `FcmPushNotificationService` wired | Done |
| E | Format, analyze, tests, manual checklist, matrix update | all | `dart format` (0 changed), `flutter analyze` (0 issues), `flutter test` (42/42 passed) | Done |

## Key decisions

- **No Strava integration.** Research established the API policy blocks the intended cross-user use; the app uses NearPace-owned data only.
- **Provider over a heavier state library.** Single `NearPaceController` with constructor-injected repositories and services; no code generation or unnecessary abstractions.
- **No map tiles.** A `CustomPainter` route sketch avoids tile licensing, offline-prefetch limits and map SDK setup while still showing the recorded shape.
- **Open-Meteo over keyed weather APIs.** No signup, no secret, simple JSON; timeout and error paths degrade gracefully to null without blocking run saving.
- **Firestore rules are part of the deliverable.** DEF-1 fixed by splitting activities read/delete from create/update. Public leaderboard strictly enforces field whitelist (zero private fields exposed).
- **Route downsampling.** Enforced maximum 250 route points before Firestore writes, preserving exact start and end points to prevent hitting Firestore 1 MiB limits.
- **FCM console demo.** Sending from a trusted server would require a service account and a backend; the console composer to a topic (`nearpace_updates`) is the simplest reliable classroom path.

## Known external blockers

1. A Firebase project and Android app registration are required to generate `google-services.json` and the `--dart-define` values. A committed `dart_defines.example.json` is provided as a blueprint.
2. FCM delivery needs a device or emulator with Google Play services and a console-sent message.
3. Real GPS recording on a live phone needs outdoor movement or an emulator with a mock location route.
4. The lecturer's verbatim rubric is still missing.
