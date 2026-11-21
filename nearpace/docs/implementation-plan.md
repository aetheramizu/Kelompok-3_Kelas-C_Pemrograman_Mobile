# Implementation plan

**Approach:** small vertical slices, each ending in a runnable check. No stage starts before its dependency exists. Firebase console setup is the only external dependency and is documented rather than faked.

| Stage | Work | Depends on | Exit check | Status |
| --- | --- | --- | --- | --- |
| A | Inspect repository, confirm no rubric, write scope and matrix | - | Documents reviewed against actual repository | Done |
| B1 | Install Flutter SDK outside the repo, create the Flutter project, preserve existing files | A | `flutter --version`, project files present, research untouched | In progress |
| B2 | Add dependencies, theme, routing shell, Firebase bootstrap that fails visibly when unconfigured | B1 | `flutter analyze` clean | Planned |
| B3 | Auth controller and screens; auth gate | B2 | Sign-up/sign-in validation unit tests | Planned |
| B4 | Firestore models, repositories, Security Rules, indexes | B2 | Model round-trip tests; rules reviewed | Planned |
| C1 | Run state machine, distance/pace calculation, route filtering | B2 | Unit tests for distance, pace, pause and empty routes | Planned |
| C2 | Location service + recording screen (permission, fix, pause, finish) | C1 | Widget test for state labels; manual device check | Planned |
| C3 | Result screen, save activity, history and detail | B4, C2 | Save/load path reviewed; widget test for summary | Planned |
| D1 | Weather service (Open-Meteo) with typed result and fallback | C3 | Parser tests; offline fallback widget test | Planned |
| D2 | Weekly leaderboard with opt-in and city filter | B4 | Rules and query reviewed; widget test for empty state | Planned |
| D3 | FCM service, token persistence, foreground banner, console instructions | B2 | Code compiles; console delivery documented | Planned |
| E | Format, analyze, tests, manual checklist, matrix update | all | `dart format`, `flutter analyze`, `flutter test` output recorded | Planned |

## Key decisions

- **No Strava integration.** Research established the API policy blocks the intended cross-user use; the app uses NearPace-owned data only.
- **Provider over a heavier state library.** One controller per concern, no code generation, no global service locator.
- **No map tiles.** A `CustomPainter` route sketch avoids tile licensing, offline-prefetch limits and map SDK setup while still showing the recorded shape.
- **Open-Meteo over keyed weather APIs.** No signup, no secret, simple JSON; failure is non-blocking.
- **Firestore rules are part of the deliverable**, not an afterthought; the public leaderboard is a separate aggregate so private activities stay private.
- **FCM console demo.** Sending from a trusted server would require a service account and a backend; the console composer to a topic is the simplest reliable classroom path.

## Known external blockers

1. A Firebase project and Android app registration are required to generate `google-services.json` and the `--dart-define` values. Until then the app shows a setup screen instead of pretending to be connected.
2. FCM delivery needs a device or emulator with Google Play services and a console-sent message.
3. Real GPS recording needs a device or an emulator with a mock location route; desktop/web is not a target.
4. The lecturer's verbatim rubric is still missing.
