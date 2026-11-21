# NearPace — Backend Integration Handoff (Phase 2B)

- **Date:** 2026-11-21
- **Baseline:** `origin/main` commit `1a81cb9` (PR #16 — Complete MVP mobile UI)
- **App directory:** `NearPace App/nearpace/`
- **Audience:** Backend / Firebase / Platform Integration Developer
- **Scope boundary:** This document defines the verified integration boundaries, recommended contracts, data/privacy rules, and rollout sequence for Phase 3. **No backend integration has been implemented yet** — all screens currently operate against local in-memory mock data in `NearPaceController`.

---

## 1. Current Architecture Overview

### 1.1 Runtime Flow (Current Behavior vs. Proposed Behavior)

| Layer | Current Behavior (Verified in `1a81cb9`) | Proposed Behavior (Phase 3 Target) |
| --- | --- | --- |
| **App entry** (`lib/main.dart`) | Calls `bootstrapFirebase()` using compile-time `--dart-define` keys (`FirebaseConfig`), then mounts `NearPaceApp(firebaseStatus: ...)`. | Same bootstrap entry; optionally registers FCM background handler when `FirebaseReady`. |
| **Root wiring** (`lib/app.dart`) | Instantiates a single `NearPaceController` via `ChangeNotifierProvider`. Switches between `AuthScreen` and `AppShell` based on `controller.isSignedIn`. | Constructs repository/service instances (live when `FirebaseReady`, mock fallback otherwise) and injects them into `NearPaceController` (or split controllers only if needed). |
| **State controller** (`lib/state/nearpace_controller.dart`) | Holds all UI state, auth/profile/activity/leaderboard/recording/notification state in memory, seeded from `NearPaceMockData`. `isLocalPreview` is hardcoded to `true`. | Delegates auth, profile, activities, GPS stream, weather, leaderboard, and push notifications to injected interfaces; sets `isLocalPreview` dynamically from mode/configuration. |
| **Domain models** (`lib/domain/*`) | Pure Dart immutable models (`UserProfile`, `Activity`, `GeoPointLite`, `WeatherSnapshot`, `LeaderboardEntry`), sealed `RunState`, and pure-Dart GPS filter/aggregator `RunSession`. | Preserved as the shared contract; serialization aligned with Firestore `Timestamp` and Security Rules (see Section 5.1). |
| **UI screens** (`lib/ui/screens/*`) | 8 screens + 8 reusable widgets observing `NearPaceController` via `context.watch` / `context.read`. Zero direct Firebase/HTTP/Geolocator imports in `lib/ui/`. | Preserved with minimal touch-ups: add async busy/error handling on sign-in/sign-up, profile save, activity save/delete, and opt-in toggle. |

### 1.2 Directory Map of Existing Application Code

- `lib/main.dart` — Flutter binding initialization + `bootstrapFirebase()`.
- `lib/app.dart` — `NearPaceApp`, `ChangeNotifierProvider<NearPaceController>`, `MaterialApp`, dark/light `NearPaceTheme`, `AnimatedSwitcher` auth gate.
- `lib/config/firebase_config.dart` — `--dart-define` keys (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, optional `FIREBASE_STORAGE_BUCKET`, `FIREBASE_AUTH_DOMAIN`).
- `lib/config/firebase_bootstrap.dart` — Sealed `FirebaseBootstrapStatus` (`FirebaseUnconfigured`, `FirebaseReady`, `FirebaseInitFailed`).
- `lib/domain/` — `activity.dart`, `geo_point.dart`, `leaderboard_entry.dart`, `run_session.dart`, `run_state.dart`, `user_profile.dart`, `weather.dart`.
- `lib/state/` — `nearpace_controller.dart` (562 lines), `mock_data.dart` (256 lines).
- `lib/utils/formatters.dart` — `NearPaceFormatters` (km, clock/compact duration, pace, ISO Monday `weekKey`, dates).
- `lib/ui/screens/` — `auth_screen.dart`, `app_shell.dart`, `home_screen.dart`, `history_screen.dart`, `leaderboard_screen.dart`, `profile_screen.dart`, `record_run_screen.dart`, `run_result_screen.dart`.
- `lib/ui/widgets/` — `activity_card.dart`, `location_permission_sheet.dart`, `metric_tile.dart`, `nearpace_card.dart`, `route_sketch.dart`, `state_views.dart`, `weather_badge.dart`, `weekly_distance_chart.dart`.
- `firestore.rules` — Draft Security Rules (contains a verified defect on `activities` read/delete; see Section 5.1).

---

## 2. Deep-Dive Audit of `NearPaceController`

`NearPaceController` (`lib/state/nearpace_controller.dart`) is the single `ChangeNotifier` observed by every screen.

### 2.1 Operation Classification (Current Implementation)

| Concern | Methods / Fields | Sync / Async | Data Source Today | Notes for Backend Replacement |
| --- | --- | --- | --- | --- |
| **App chrome / UI prefs** | `themeMode`, `setThemeMode`, `selectedTabIndex`, `setTabIndex`, `selectedCity`, `setSelectedCity` | Sync | Local memory | **Keep in UI/controller layer.** Optional persistence via local preferences is out of MVP scope unless desired. |
| **Authentication** | `isSignedIn`, `isLocalPreview`, `signInLocalPreview`, `signUpLocalPreview`, `enterQuickPreview`, `signOut` | Sync (`void`) | Mock in-memory | Must become `Future` operations backed by `AuthRepository` + `authStateChanges` stream listener. Note: `auth_screen.dart` does not yet pass password to `NearPaceController`. |
| **Profile & privacy** | `profile`, `updateProfile`, `setShowOnLeaderboard` | Sync (`void`) | `NearPaceMockData.defaultProfile()` | Must persist to `users/{uid}`; toggling `showOnLeaderboard` or editing `displayName`/`city` while opted in must sync or delete `leaderboard/{weekKey}_{uid}`. |
| **Activities & weekly aggregates** | `activities`, `historyState`, `historyError`, `saveActivity`, `deleteActivity`, `retryHistory`, `weeklyActivities`, `weeklyDistanceMeters`, `weeklyDuration`, `weeklyAvgPaceSecPerKm`, `weeklyDailyDistancesMeters`, `totalDistanceMeters` | Sync (`void`) | `NearPaceMockData.initialActivities()` | Derived weekly getters already compute cleanly from `_activities`! Replace `_activities` storage with a Firestore stream subscription (`users/{uid}/activities`, ordered by `startedAt` desc) and make `saveActivity`/`deleteActivity` async. |
| **Run recording & GPS** | `runState`, `locationPermission`, `activeSession`, `setLocationPermission`, `startRecording`, `pauseRecording`, `resumeRecording`, `resetRecording`, `finishRecording`, `simulateGpsInPreview`, `simulateGpsSignalLost` | Mixed (`startRecording` and `finishRecording` are `Future`; others sync) | 1-second `Timer.periodic` stepping through `NearPaceMockData.simulationLoop()` | `RunSession` is already pure Dart and handles accuracy (`<= 35 m`), jitter (`>= 1.5 m`), speed jump (`<= 12 m/s`), and pause math! Replace the simulated waypoint stepper in `_startRunTimer()` with a `StreamSubscription<GeoPointLite>` from `LocationTrackingService` while keeping the 1-second UI tick timer for live elapsed clock updates. |
| **Weather** | Created inline inside `finishRecording()` (`temperatureC: 27.6, apparentC: 29.9, code: 1`) controlled by `weatherAvailableInPreview` | Inside `Future<Activity?> finishRecording()` | Hardcoded mock `WeatherSnapshot` | Replace inline mock with `WeatherRepository.fetchCurrentWeather(startPoint)` with timeout & graceful `null` fallback. Optionally fetch asynchronously on `RunResultScreen` using `WeatherSummaryCard(isLoading: ...)` so finishing a run never stalls offline. |
| **Leaderboard** | `allLeaderboardEntries`, `filteredLeaderboardEntries`, `availableCities`, `leaderboardState`, `leaderboardError`, `retryLeaderboard` | Sync | `NearPaceMockData.initialLeaderboard()` + appends current user locally if `showOnLeaderboard` | Replace `_leaderboardBase` with Firestore query/stream on `leaderboard` filtered by `weekKey == currentWeekKey` ordered by `distanceM` desc. Remove local synthetic append when backed by live Firestore (to avoid duplicate rows for the current user). |
| **Push notifications** | `activeNotice`, `triggerPreviewNotification`, `dismissNotification` | Sync | Local preview trigger in `ProfileScreen` | Subscribe `PushNotificationService.foregroundMessages` to populate `_activeNotice` (`ForegroundNotice`). Keep `triggerPreviewNotification` only in preview/debug mode or remove once live FCM is verified. |

### 2.2 Coupling & Architectural Assessment

- **What is well-separated today:**
  - `lib/ui/` has **zero** imports of `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `geolocator`, or `http`.
  - `RunSession` (`lib/domain/run_session.dart`) and `NearPaceFormatters` (`lib/utils/formatters.dart`) are pure Dart and completely decoupled from Flutter and backend SDKs.
  - `HistoryScreen`, `HomeScreen`, and `LeaderboardScreen` already support `ViewLoadState.loading`, `ViewLoadState.error`, and empty states via `LoadingSkeletonList`, `ErrorStateView`, and `EmptyStateView`.
  - `WeatherSummaryCard` (`lib/ui/widgets/weather_badge.dart`) already supports `isLoading`, loaded data with Open-Meteo attribution, and `weather == null` ("Conditions unavailable") fallback.
- **Current coupling points to address during integration:**
  1. `NearPaceController` directly calls `NearPaceMockData.*` in its constructor and `_startRunTimer()`, and hardcodes `bool get isLocalPreview => true;`.
  2. Mutation methods (`signInLocalPreview`, `signUpLocalPreview`, `signOut`, `updateProfile`, `setShowOnLeaderboard`, `saveActivity`, `deleteActivity`) are synchronous `void` and have no busy/error state channels.
  3. `AuthScreen._submit` (`lib/ui/screens/auth_screen.dart:50-69`) validates `_passwordController` locally, then discards the password when calling `signInLocalPreview` / `signUpLocalPreview`.
  4. `RecordRunScreen` (`lib/ui/screens/record_run_screen.dart:28-47`) treats `showLocationPermissionSheet` as the permission source of truth (returning mock `granted`/`denied`/`deniedForever` buttons) instead of invoking real Android OS permission APIs via `geolocator`.
  5. `RecordRunScreen` displays preview-only switches (`simulateGpsInPreview`, `weatherAvailableInPreview`, and `Simulate signal loss` button in `RunPreparing`) that should be hidden when `!controller.isLocalPreview`.
  6. `RunResultScreen` (`lib/ui/screens/run_result_screen.dart:57-104`) calls `controller.saveActivity(activity)` and `controller.deleteActivity(activity.id)` synchronously and pops immediately without waiting for Firestore confirmation or handling write failures.

### 2.3 Failure Representation Recommendation

Keep failure handling simple and consistent with existing `ViewLoadState`:
- **Stream/list screens (`History`, `Leaderboard`):** Continue using `ViewLoadState.loading` / `ViewLoadState.ready` / `ViewLoadState.error` with user-facing `_historyError` / `_leaderboardError` strings and retry callbacks (`retryHistory`, `retryLeaderboard`).
- **One-shot async mutations (Auth submit, Profile save, Opt-in toggle, Activity save/delete):** Return a lightweight typed result (or throw a typed `NearPaceException(String userMessage, {Object? cause})`) and expose a per-operation busy flag (e.g., `isAuthBusy`, `isSavingActivity`) so screens can disable submit buttons, show progress, and display inline/SnackBar errors without closing dialogs or discarding recorded runs.
- **Non-blocking auxiliary services (Weather, FCM):** Never fail a run save or sign-in because weather or FCM failed. Weather degrades to `null` ("Conditions unavailable"); FCM errors log and display an honest status in `ProfileScreen`.

---

## 3. Verified Integration Boundaries (7 Areas)

### 3.1 Firebase Authentication

- **Current status:** Local/mock preview (`signInLocalPreview`, `signUpLocalPreview`, `enterQuickPreview`, `signOut`). `firebase_auth: ^7.1.0` is declared in `pubspec.yaml` but unused.
- **Relevant files:** `lib/config/firebase_bootstrap.dart`, `lib/config/firebase_config.dart`, `lib/app.dart`, `lib/state/nearpace_controller.dart:219-272`, `lib/ui/screens/auth_screen.dart`, `lib/ui/screens/profile_screen.dart:41-72`.
- **Existing models:** `UserProfile` (`lib/domain/user_profile.dart`), `FirebaseBootstrapStatus`.
- **UI entry points:**
  - `AuthScreen` (`Sign in` / `Create account` segmented form, `Continue in local preview` button).
  - `ProfileScreen` (`Sign out` confirmation dialog).
  - `NearPaceApp` (`_NearPaceMaterialApp` switches `AuthScreen` <-> `AppShell` on `controller.isSignedIn`).
- **Required packages / services:** `firebase_core`, `firebase_auth` (Email/Password provider enabled in Firebase Console).
- **Expected inputs & outputs:**
  - `signIn(email, password)` -> authenticated `uid` + triggers profile/activity/leaderboard hydration.
  - `signUp(email, password, displayName, city)` -> creates Firebase Auth user, sets display name, creates initial `users/{uid}` Firestore document (`showOnLeaderboard: false`).
  - `signOut()` -> cancels active streams/timers, signs out of Firebase Auth, clears in-memory user data, sets `isSignedIn = false`.
  - `authStateChanges()` stream -> restores session on cold app restart.
- **States:**
  - *Loading:* Auth check on startup (avoid flashing `AuthScreen` if already signed in) + busy state while submitting sign-in/sign-up.
  - *Success:* Transitions to `AppShell` tab 0 (`HomeScreen`).
  - *Empty:* N/A (unauthenticated shows `AuthScreen`).
  - *Failure:* Map `FirebaseAuthException.code` (`invalid-credential`, `email-already-in-use`, `weak-password`, `network-request-failed`, `too-many-requests`) to clear user copy in `AuthScreen._formErrorSummary`.
- **Permissions & privacy:** Email/password only; never expose `email` outside `users/{uid}`.
- **Existing tests:** `test/controller_test.dart` (sign-up preview), `test/widget_test.dart` (form validation, quick preview, sign-out flow, Firebase status cards).
- **Dependencies:** Firebase project + `--dart-define` / Android config.
- **Open questions for backend dev:**
  1. Should `Continue in local preview` remain available only when `firebaseStatus is! FirebaseReady` (or hidden in production builds)?
  2. Should cold-start auth persistence use a lightweight splash/loading state until the first `authStateChanges` event arrives?

### 3.2 Firestore User Profiles & Activity Persistence

- **Current status:** Local/mock preview (`NearPaceMockData.defaultProfile()` and `initialActivities()`). `cloud_firestore: ^7.2.0` is declared but unused. Draft `firestore.rules` exists at `NearPace App/nearpace/firestore.rules`.
- **Relevant files:** `lib/domain/user_profile.dart`, `lib/domain/activity.dart`, `lib/state/nearpace_controller.dart:80-90, 276-288, 489-502`, `lib/ui/screens/home_screen.dart`, `lib/ui/screens/history_screen.dart`, `lib/ui/screens/profile_screen.dart`, `firestore.rules`.
- **Existing models:** `UserProfile`, `Activity`, `GeoPointLite`, `WeatherSnapshot`.
- **UI entry points:**
  - `HomeScreen`: Weekly totals, daily bar chart, 3 recent runs (`controller.activities`, `controller.historyState`).
  - `HistoryScreen`: Full run list with `All runs` / `This week` filter, cumulative stats, empty/loading/error states.
  - `ProfileScreen`: Runner identity card, Edit profile bottom sheet (`displayName`, `city`), leaderboard opt-in switch (`showOnLeaderboard`), lifetime run count & distance.
- **Required packages / services:** `cloud_firestore`, deployed Firestore Security Rules (`firestore.rules` after fixing the read/delete rule defect).
- **Expected inputs & outputs:**
  - Profile read/watch: `users/{uid}` -> `Stream<UserProfile?>` or `Future<UserProfile>`.
  - Profile write: `users/{uid}` -> creates on sign-up, updates `displayName`, `city`, `showOnLeaderboard`, `fcmToken`.
  - Activities stream: `users/{uid}/activities` ordered by `startedAt` descending -> `Stream<List<Activity>>`.
  - Activity delete: `users/{uid}/activities/{activityId}` -> deletes document and recalculates weekly leaderboard aggregate if opted in and activity was in `currentWeekKey`.
- **States:**
  - *Loading:* `ViewLoadState.loading` -> renders `LoadingSkeletonList` on `HomeScreen` and `HistoryScreen`.
  - *Success:* `ViewLoadState.ready` -> renders activities and recomputes weekly metrics.
  - *Empty:* `activities.isEmpty` -> renders `EmptyStateView` ("No runs recorded yet") with CTA to start a run.
  - *Failure:* `ViewLoadState.error` -> renders `ErrorStateView` with `retryHistory` callback re-subscribing the stream.
- **Permissions & privacy:** Strictly owner-only (`request.auth.uid == uid`). No second user may read or write `users/{uid}` or `users/{uid}/activities/{id}`.
- **Existing tests:** `test/controller_test.dart` (seeded weekly metrics, save activity), `test/widget_test.dart` (profile edit sheet, history tab).
- **Dependencies:** Firebase Auth (`uid`), fixed `firestore.rules`, agreed timestamp serialization format.
- **Open questions for backend dev:**
  1. Confirm Timestamp vs ISO-8601 String serialization for `Activity.startedAt`/`endedAt`, `WeatherSnapshot.fetchedAt`, and `UserProfile.createdAt` (recommended: native Firestore `Timestamp` in repository mappers; see Section 5.1).
  2. What maximum route point count should be enforced before writing `route` to Firestore (e.g., simplify/downsample to <= 200–300 points so documents stay well under Firestore's 1 MiB limit)?
  3. Should Firestore offline persistence remain enabled (default on Android)?

### 3.3 Real GPS Tracking & Location Permissions

- **Current status:** Local/mock preview (`LocationPermissionSheet` returns simulated enum values; `_startRunTimer` feeds interpolated points from `NearPaceMockData.simulationLoop()` into `RunSession`). `geolocator: ^14.1.2` is declared in `pubspec.yaml` and `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` are declared in `android/app/src/main/AndroidManifest.xml`, but `geolocator` is not imported anywhere.
- **Relevant files:** `lib/domain/run_state.dart`, `lib/domain/run_session.dart`, `lib/domain/geo_point.dart`, `lib/state/nearpace_controller.dart:102-120, 340-487, 504-555`, `lib/ui/screens/record_run_screen.dart`, `lib/ui/widgets/location_permission_sheet.dart`, `android/app/src/main/AndroidManifest.xml`.
- **Existing models:** Sealed `RunState` (`RunIdle`, `RunPreparing`, `RunActive(paused)`, `RunStopping`, `RunFailed(message)`), `RunSession`, `RunSample`, `GeoPointLite`, `LocationPermissionStatus`.
- **UI entry points:**
  - `AppShell` center "Run" button -> pushes `RecordRunScreen`.
  - `RecordRunScreen`: Start run -> permission rationale/request -> `RunPreparing` (acquiring fix) -> `RunActive` (live distance, elapsed clock, pace, live `RouteSketch`, Pause/Resume/Finish) -> `RunStopping` -> pushes `RunResultScreen(isUnsaved: true)`.
  - `LocationPermissionSheet`: Rationale bottom sheet currently showing mock `Allow` / `Deny` / `Deny forever` buttons.
- **Required packages / services:** `geolocator` (`isLocationServiceEnabled`, `checkPermission`, `requestPermission`, `openAppSettings`, `openLocationSettings`, `getPositionStream` with `AndroidSettings`).
- **Expected inputs & outputs:**
  - `checkPermission()` / `requestPermission()` -> maps `LocationPermission` + location-service-enabled check to `LocationPermissionStatus` (plus explicit "Location services disabled" message if GPS toggle is off).
  - `positionStream()` -> `Stream<GeoPointLite>` emitting `(latitude, longitude, accuracyM, recordedAt)` fed directly into `RunSession.addSample(point, at)`.
- **States:**
  - *Idle:* `RunIdle` — ready to start.
  - *Preparing:* `RunPreparing` — waiting for first valid GPS fix (with timeout -> `RunFailed` if no fix arrives within e.g. 20–30s).
  - *Active / Paused:* `RunActive(paused: false/true)` — live updates; paused ignores incoming GPS samples (`RunSession.addSample` already returns `false` when paused).
  - *Stopping:* `RunStopping` — cancels stream subscription, builds final `Activity`.
  - *Failure:* `RunFailed(message)` — handles permission denied, permanently denied (offer `openAppSettings()`), GPS hardware disabled (offer `openLocationSettings()`), and stream errors without crashing.
- **Permissions & privacy:** Foreground location only (`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`). Background recording after app kill is explicitly out of MVP scope (`docs/mvp-specification.md`). Route points stay private.
- **Existing tests:** `test/controller_test.dart` (permission guard + run lifecycle), `test/widget_test.dart` (full permission -> record -> pause -> resume -> finish -> save flow, denied recovery state). **Gap:** `RunSession` filtering math has no dedicated unit test file yet.
- **Dependencies:** Independent of Firebase; feeds `Activity` creation (3.4) and start-point weather (3.5).
- **Open questions for backend dev:**
  1. Should `LocationPermissionSheet` stay as a pre-prompt rationale that triggers the real OS `Geolocator.requestPermission()` when "Allow while using app" is tapped (recommended), and invoke `Geolocator.openAppSettings()` when `deniedForever`?
  2. What GPS acquisition timeout (e.g., 20s) and `distanceFilter` (e.g., 2–3 m) should be used for Android `LocationSettings`?

### 3.4 Saving Completed Runs

- **Current status:** Local/mock preview. `finishRecording()` creates an unsaved `Activity` with `'local-${endedAt.millisecondsSinceEpoch}'`; `RunResultScreen._saveRun()` calls synchronous `controller.saveActivity(activity)` and pops immediately.
- **Relevant files:** `lib/state/nearpace_controller.dart:440-502`, `lib/ui/screens/record_run_screen.dart:49-57`, `lib/ui/screens/run_result_screen.dart:27-105`, `lib/domain/activity.dart`.
- **Existing models:** `Activity`, `GeoPointLite`, `WeatherSnapshot`.
- **UI entry points:** `RunResultScreen` (`Save run` primary CTA when `isUnsaved: true`, `Discard` confirmation dialog, and `Delete` trash icon when `isUnsaved: false`).
- **Required packages / services:** `cloud_firestore` (writes `users/{uid}/activities/{id}`; if `profile.showOnLeaderboard == true`, also updates `leaderboard/{weekKey}_{uid}`).
- **Expected inputs & outputs:**
  - Input: unsaved `Activity` (with simplified/capped `route` and optional `weather`).
  - Output: saved `Activity` with Firestore document ID; stream updates `HomeScreen` and `HistoryScreen`; leaderboard aggregate updated if opted in.
- **States:**
  - *Saving:* Disable `Save run` button and show loading indicator on `RunResultScreen` until Firestore write succeeds (or queues offline).
  - *Success:* Show confirmation SnackBar and pop back to shell.
  - *Failure:* Keep `RunResultScreen` open with the unsaved `Activity` intact, display retryable error banner/SnackBar (never silently lose a finished run!).
- **Permissions & privacy:** Owner-only write under `users/{uid}/activities/{id}`; leaderboard write includes only aggregate `distanceM` + `runCount` (never `route` or `email`).
- **Existing tests:** `test/controller_test.dart`, `test/widget_test.dart`.
- **Dependencies:** Firebase Auth, ActivityRepository, Weather (non-blocking), Leaderboard sync (if opted in).
- **Open questions for backend dev:**
  1. Should weather be fetched *before* showing `RunResultScreen` (with short timeout), or loaded asynchronously on `RunResultScreen` and merged into the saved `Activity` (or patched to Firestore after save, as hinted in `mvp-specification.md`: *"fetched after save; optional"*)?
  2. Should a zero-distance / `< 2` sample run still be saveable (valid for indoor/short demo tests), or warned before saving? (`firestore.rules` allows `distanceM >= 0` and `durationS >= 0`.)

### 3.5 Weather API Integration (Open-Meteo)

- **Current status:** Local/mock preview. `NearPaceController.finishRecording()` attaches a hardcoded `WeatherSnapshot(temperatureC: 27.6, apparentC: 29.9, code: 1, fetchedAt: endedAt)` whenever `_weatherAvailableInPreview && route.isNotEmpty`. `http: ^1.6.0` is declared in `pubspec.yaml` but unused.
- **Relevant files:** `lib/domain/weather.dart`, `lib/state/nearpace_controller.dart:463-470`, `lib/ui/widgets/weather_badge.dart`, `lib/ui/screens/run_result_screen.dart`.
- **Existing models:** `WeatherSnapshot` (`temperatureC`, `apparentC`, `code`, `fetchedAt`, `label` via `weatherCodeLabel(code)`).
- **UI entry points:**
  - `RunResultScreen` -> `WeatherSummaryCard(weather: activity.weather, isLoading: ...)` (already displays temperature, feels-like, WMO label, `"Weather data by Open-Meteo"` attribution, loading indicator, and `"Conditions unavailable"` offline fallback!).
  - `ActivityCard` -> `WeatherPill(weather: activity.weather)` (hides itself cleanly when `weather == null`).
- **Required packages / services:** `http` package calling Open-Meteo Forecast API:
  `GET https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,apparent_temperature,weather_code`
- **Expected inputs & outputs:**
  - Input: `GeoPointLite` (first point of the run `route.first`), configurable HTTP timeout (e.g., 5–8 seconds).
  - Output: `WeatherSnapshot?` (or `ApiResult<WeatherSnapshot>`). Returns `null` / failure result on timeout, non-200 status, malformed JSON, or offline device.
- **States:**
  - *Loading:* `WeatherSummaryCard(weather: null, isLoading: true)`.
  - *Success:* `WeatherSummaryCard(weather: snapshot)`.
  - *Empty / Failure:* `WeatherSummaryCard(weather: null)` -> renders `"Conditions unavailable"` without blocking run summary or saving.
- **Permissions & privacy:** Uses `INTERNET` permission (already in `AndroidManifest.xml`). Only sends start coordinate to Open-Meteo (no user ID/email/name). No API key required.
- **Existing tests:** `test/widget_test.dart` (`displays weather unavailable fallback on saved run`). **Gap:** No Open-Meteo JSON parser / error-path unit tests yet.
- **Dependencies:** Start coordinate from GPS recording; optional persistence inside `Activity.weather`.
- **Open questions for backend dev:**
  1. Confirm Open-Meteo response field names (`current.temperature_2m`, `current.apparent_temperature`, `current.weather_code`) and timeout threshold (recommended: 6 seconds).
  2. If a run has an empty route (0 GPS samples), skip the Open-Meteo call and leave `weather = null`.

### 3.6 Leaderboard Queries & Privacy Controls

- **Current status:** Local/mock preview (`NearPaceMockData.initialLeaderboard()` + in-memory append of current user when `profile.showOnLeaderboard == true`). Note: Marked **optional** in `docs/requirements-matrix.md` and `docs/mvp-specification.md`, though the UI and `firestore.rules` already exist.
- **Relevant files:** `lib/domain/leaderboard_entry.dart`, `lib/state/nearpace_controller.dart:92-100, 159-201, 284-288, 308-336`, `lib/ui/screens/leaderboard_screen.dart`, `lib/ui/screens/profile_screen.dart:236-258`, `firestore.rules:29-50`.
- **Existing models:** `LeaderboardEntry` (`uid`, `displayName`, `city`, `weekKey`, `distanceM`, `runCount`, `updatedAt`, `documentId => '${weekKey}_$uid'`).
- **UI entry points:**
  - `LeaderboardScreen`: Opt-in banner (`Opt in` button when private), city filter chips (`All cities` + dynamic city chips), ranked list, loading/empty/error states.
  - `ProfileScreen`: `Show on weekly leaderboard` `SwitchListTile`.
- **Required packages / services:** `cloud_firestore` (`leaderboard/{weekKey}_{uid}` collection) + composite Firestore index if querying `where('weekKey', isEqualTo: weekKey).orderBy('distanceM', descending: true)` (and optionally `.where('city', isEqualTo: city)`).
- **Expected inputs & outputs:**
  - Query: `leaderboard` for `weekKey == currentWeekKey`, sorted by `distanceM` descending (city filtering can be done client-side on the week's query results for small cohorts, or server-side with a composite index).
  - Upsert (when `showOnLeaderboard == true`): Owner writes `leaderboard/{weekKey}_{uid}` after saving/deleting a current-week run, enabling opt-in, or updating `displayName`/`city`.
  - Delete (when `showOnLeaderboard == false`): Owner deletes `leaderboard/{weekKey}_{uid}` immediately upon opting out.
- **States:**
  - *Loading:* `ViewLoadState.loading` -> `LoadingSkeletonList`.
  - *Success:* Ranked rows with `"You"` highlight badge for `entry.uid == profile.uid`.
  - *Empty:* `EmptyStateView` (differs when `All cities` is empty vs. a specific city filter has no runners).
  - *Failure:* `ViewLoadState.error` -> `ErrorStateView` with `retryLeaderboard`.
- **Permissions & privacy:**
  - `showOnLeaderboard` MUST default to `false` on new accounts.
  - `leaderboard/{weekKey}_{uid}` MUST contain ONLY `uid`, `displayName`, `city`, `weekKey`, `distanceM`, `runCount`, `updatedAt` — **never** `email`, `fcmToken`, or `route`.
  - Enforced by `firestore.rules` (`keys().hasOnly(...)`, `entryId == weekKey + '_' + request.auth.uid`, `displayName <= 40`, `city <= 60`, `distanceM <= 1000000`).
- **Existing tests:** `test/controller_test.dart` (opt-in inclusion & city filtering), `test/formatters_test.dart` (`isoWeekKey` Monday alignment).
- **Dependencies:** Firebase Auth, UserProfile (`showOnLeaderboard`, `displayName`, `city`), weekly Activities sum, fixed Timestamp serialization in `LeaderboardEntry`.
- **Open questions for backend dev:**
  1. Do we filter by city client-side on the current week's `leaderboard` snapshot (simpler, only needs one `(weekKey, distanceM DESC)` index and automatically populates `availableCities`), or query per-city in Firestore? (Recommended for MVP: query `where('weekKey', isEqualTo: weekKey).orderBy('distanceM', descending: true)` and filter cities client-side, matching `NearPaceController.availableCities`.)
  2. When a user opts out, should we delete only the current week's `leaderboard/{currentWeekKey}_{uid}` doc, or query and delete all prior weeks' docs for `uid`?

### 3.7 Push Notifications (FCM)

- **Current status:** Local/mock preview (`ProfileScreen` "Preview foreground banner" button invokes `controller.triggerPreviewNotification()`, rendered by `ForegroundNoticeBanner` inside `AppShell`). `firebase_messaging: ^17.1.0` is declared in `pubspec.yaml` but unused.
- **Mandatory vs. Optional classification:** **Mandatory under provisional `docs/requirements-matrix.md` (#4) and `docs/mvp-specification.md`** (until/unless the lecturer rubric states otherwise).
- **Relevant files:** `lib/state/nearpace_controller.dart:23-36, 70-71, 292-304`, `lib/ui/screens/app_shell.dart:41, 56-73`, `lib/ui/screens/profile_screen.dart:311-363`, `lib/ui/widgets/state_views.dart:288-367`, `lib/domain/user_profile.dart` (`fcmToken`).
- **Existing models:** `ForegroundNotice` (`title`, `body`, `receivedAt`, `topic`), `UserProfile.fcmToken`.
- **UI entry points:**
  - `AppShell`: Top overlay `ForegroundNoticeBanner` with dismiss button.
  - `ProfileScreen`: Notifications section displaying `Topic: nearpace_updates`.
- **Required packages / services:** `firebase_messaging`, Firebase Cloud Messaging enabled in Firebase Console, Android device/emulator with Google Play Services.
- **Expected inputs & outputs:**
  - `initialize()` after sign-in: requests runtime notification permission (`POST_NOTIFICATIONS` on Android 13+; already merged into the debug manifest by `firebase_messaging`), fetches FCM token (`getToken()`), saves token to `users/{uid}.fcmToken`, listens to `onTokenRefresh`, subscribes to topic `nearpace_updates`.
  - Foreground stream (`FirebaseMessaging.onMessage`): maps `RemoteMessage` notification title/body into `ForegroundNotice` and surfaces via `NearPaceController`.
  - Background handler: top-level `@pragma('vm:entry-point')` function registered via `FirebaseMessaging.onBackgroundMessage(...)`.
- **States:**
  - *Permission granted:* Token stored, subscribed to `nearpace_updates`, foreground messages show `ForegroundNoticeBanner`.
  - *Permission denied:* App continues normally; Profile card indicates notifications are disabled.
  - *Failure / no Play Services:* Non-fatal; log and show status without blocking auth or run recording.
- **Permissions & privacy:** `POST_NOTIFICATIONS` runtime prompt on Android 13+ (API 33+); `fcmToken` stored privately inside `users/{uid}` (never in `leaderboard/`).
- **Existing tests:** `test/controller_test.dart` (`triggers and dismisses foreground notification banner`).
- **Dependencies:** Firebase project, Android FCM configuration (verify whether `google-services.json` is needed for Android FCM token/background delivery!).
- **Open questions for backend dev:**
  1. Confirm on a physical/emulator Android device with Play Services whether `firebase_messaging` works with `--dart-define` `FirebaseOptions` alone or requires `android/app/google-services.json` + `com.google.gms.google-services` Gradle plugin (Android FCM background messaging often requires `google-services.json` to auto-initialize the default Firebase app in the background isolate).
  2. Should `fcmToken` be cleared on `signOut()` and unsubscribed from `nearpace_updates`? (Recommended: yes, best effort.)

---

## 4. Proposed Minimal Integration Architecture

### 4.1 Design Principles

1. **Preserve `provider` + `ChangeNotifier`.** Do not introduce Riverpod, BLoC, GetX, or code-generation frameworks; `NearPaceController` already satisfies the UI contract and provisional Requirement #2.
2. **Keep SDK calls out of `lib/ui/`.** Widgets talk only to `NearPaceController` (and pure domain models).
3. **Preserve local preview & offline unit/widget tests.** Inject repositories/services via constructor parameters with clean in-memory/mock defaults so all 20 existing tests continue passing without a live Firebase project.
4. **Avoid over-abstraction.** Skip generic use-case classes, DTO layers with redundant mappers, or global service locators.

### 4.2 Evaluation of Candidate Interfaces

| Candidate Interface | Verdict | Why |
| --- | --- | --- |
| `AuthRepository` | **Necessary** | Decouples `FirebaseAuth` (`authStateChanges`, `signIn`, `signUp`, `signOut`) from `NearPaceController`; enables deterministic auth tests without Firebase. |
| `ProfileRepository` | **Necessary** | Owns `users/{uid}` reads/writes (`watchProfile`, `createProfile`, `updateProfile`, `setShowOnLeaderboard`, `updateFcmToken`), keeping private profile rules distinct from activities and public leaderboard. |
| `ActivityRepository` | **Necessary** | Owns `users/{uid}/activities` (`watchActivities`, `saveActivity`, `deleteActivity`) and Firestore `Timestamp` + route-simplification serialization. |
| `LeaderboardRepository` | **Necessary (if leaderboard stays in scope)** | Owns public `leaderboard/{weekKey}_{uid}` queries, owner upsert, and opt-out deletion. Keeping it separate from `ActivityRepository` makes privacy boundaries explicit and auditable. |
| `WeatherRepository` (or `WeatherService`) | **Necessary** | Wraps Open-Meteo `http.Client` call, timeout, JSON parsing, and non-blocking `ApiResult<WeatherSnapshot>` / `WeatherSnapshot?` fallback; trivially unit-testable with `http/testing.dart` `MockClient`. |
| `LocationTrackingService` | **Necessary** | Wraps `geolocator` permission checks, location service status, settings deep-links, and `Stream<GeoPointLite>`. Keeps `RunSession` pure Dart and allows simulated GPS streams in preview/tests. |
| `PushNotificationService` | **Necessary (for provisional Req #4)** | Wraps `firebase_messaging` permission request, token fetch/refresh, `nearpace_updates` topic subscription, and foreground `Stream<ForegroundNotice>`. |

### 4.3 Proposed Minimal Directory Layout (Additive Only)

Keep existing `lib/domain/`, `lib/state/`, `lib/theme/`, `lib/ui/`, and `lib/utils/` intact. Add only:

```text
lib/
  data/
    api_result.dart                   # Optional small sealed ApiResult<T> (Ok / Err)
    repositories/
      auth_repository.dart            # Abstract interface + FirebaseAuthRepository + MockAuthRepository
      profile_repository.dart         # Abstract interface + FirestoreProfileRepository + MockProfileRepository
      activity_repository.dart        # Abstract interface + FirestoreActivityRepository + MockActivityRepository
      leaderboard_repository.dart     # Abstract interface + FirestoreLeaderboardRepository + MockLeaderboardRepository
      weather_repository.dart         # Abstract interface + OpenMeteoWeatherRepository + MockWeatherRepository
  services/
    location_tracking_service.dart    # Abstract interface + GeolocatorTrackingService + SimulatedLocationService
    push_notification_service.dart    # Abstract interface + FcmPushNotificationService + NoopPushNotificationService
```

### 4.4 Minimal Contract Signatures (Reference Blueprint)

```dart
abstract interface class AuthRepository {
  Stream<String?> authStateChanges(); // emits uid or null
  String? get currentUid;
  Future<String> signIn({required String email, required String password});
  Future<String> signUp({required String email, required String password});
  Future<void> signOut();
}

abstract interface class ProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);
  Future<void> upsertProfile(UserProfile profile, {bool isNew = false});
  Future<void> updateIdentity(String uid, {required String displayName, required String city});
  Future<void> setShowOnLeaderboard(String uid, bool show);
  Future<void> updateFcmToken(String uid, String? token);
}

abstract interface class ActivityRepository {
  Stream<List<Activity>> watchActivities(String uid);
  Future<String> saveActivity(String uid, Activity activity);
  Future<void> deleteActivity(String uid, String activityId);
}

abstract interface class LeaderboardRepository {
  Stream<List<LeaderboardEntry>> watchWeeklyLeaderboard(String weekKey);
  Future<void> upsertEntry(LeaderboardEntry entry);
  Future<void> deleteEntry({required String weekKey, required String uid});
}

abstract interface class WeatherRepository {
  Future<WeatherSnapshot?> fetchCurrentWeather(GeoPointLite startPoint);
}

abstract interface class LocationTrackingService {
  Future<LocationPermissionStatus> checkPermission();
  Future<LocationPermissionStatus> requestPermission();
  Future<bool> isLocationServiceEnabled();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
  Stream<GeoPointLite> positionStream();
}

abstract interface class PushNotificationService {
  Future<String?> initializeAndGetToken();
  Stream<String> get onTokenRefresh;
  Stream<ForegroundNotice> get foregroundMessages;
  Future<void> subscribeToTopic(String topic);
  Future<void> unsubscribeFromTopic(String topic);
}
```

### 4.5 Wiring Pattern in `lib/app.dart`

- When `firebaseStatus is FirebaseReady`: wire the `Firebase*` / `Firestore*` / `OpenMeteo*` / `Geolocator*` / `Fcm*` implementations into `NearPaceController(isLocalPreview: false, ...)`.
- When `firebaseStatus is! FirebaseReady` (or in widget tests): wire the mock/simulated implementations into `NearPaceController(isLocalPreview: true, ...)`.
- **Result:** All 8 existing screens keep working untouched in preview mode and tests, while live Firebase builds exercise real services through the exact same `NearPaceController` surface.

---

## 5. Data Ownership, Schema Alignment & Privacy Considerations

### 5.1 Critical Pre-Integration Defects & Mismatches Found in Audit

The backend developer **must resolve these before deploying Firestore writes**:

1. **Defect in `firestore.rules` (`users/{uid}/activities/{activityId}`, lines 21–26):**
   - Current rule uses `allow read, write: if isOwner(uid) && (!request.resource.data.keys()...)`.
   - In Firestore Security Rules, `request.resource` is `null` on `read` and `delete` operations, causing `request.resource.data` evaluation to fail and **deny every activity read and delete**.
   - **Proposed fix:** Split into `allow read, delete: if isOwner(uid);` and `allow create, update: if isOwner(uid) && request.resource.data.distanceM is number && request.resource.data.distanceM >= 0 && request.resource.data.durationS is number && request.resource.data.durationS >= 0;`.
2. **Timestamp vs. ISO-8601 String mismatch across models and rules:**
   - `LeaderboardEntry.toMap()` (`lib/domain/leaderboard_entry.dart:44`) writes `'updatedAt': updatedAt.toUtc().toIso8601String()` (a `String`), while `firestore.rules:46` enforces `request.resource.data.updatedAt is timestamp`. Writing `LeaderboardEntry.toMap()` directly to Firestore will be **rejected**.
   - `Activity.toMap()` / `Activity.fromMap()` (`lib/domain/activity.dart:43-67`) and `WeatherSnapshot` (`lib/domain/weather.dart:33-50`) also assume ISO-8601 strings, whereas `docs/mvp-specification.md` specifies Firestore `timestamp` fields (`startedAt`, `endedAt`, `createdAt`).
   - **Recommendation:** Keep `lib/domain/` free of `cloud_firestore` imports, and handle `Timestamp <-> DateTime` conversion inside the Firestore repository mappers (or accept both `Timestamp` and ISO `String` in mapper helpers).
3. **Missing `createdAt` on `UserProfile`:**
   - `docs/mvp-specification.md` lists `createdAt: timestamp` on `users/{uid}`, which is not yet on `UserProfile`. Write `FieldValue.serverTimestamp()` on initial profile creation in `FirestoreProfileRepository`.
4. **Uncapped GPS route arrays:**
   - `docs/mvp-specification.md` specifies `route: array<{lat, lng}> // capped, simplified`, while `RunSession.route` currently returns all accepted samples uncapped. Add a simple downsampler (e.g., cap to <= 250 points preserving start/end) in `ActivityRepository` or a pure helper before writing to Firestore.
5. **Android `google-services` Gradle setup absent:**
   - `android/settings.gradle.kts` and `android/app/build.gradle.kts` do not apply `com.google.gms.google-services`, and no `google-services.json` exists. While `Firebase.initializeApp(options: ...)` via `--dart-define` works for Auth and Firestore, verify early whether Android FCM background delivery requires `google-services.json` (gitignored!) + the Google Services plugin.

### 5.2 Data Ownership & Privacy Matrix

| Firestore Path | Owner | Read Access | Write Access | Forbidden Fields |
| --- | --- | --- | --- | --- |
| `users/{uid}` | Authenticated user `uid` | Owner only (`isOwner(uid)`) | Owner only (`isOwner(uid)`) | Raw password |
| `users/{uid}/activities/{activityId}` | Authenticated user `uid` | Owner only (`isOwner(uid)`) | Owner only (`isOwner(uid)`) | — |
| `leaderboard/{weekKey}_{uid}` | Authenticated user `uid` | Any signed-in user (`signedIn()`) | Owner only (`entryId == weekKey + '_' + uid`), strict `hasOnly` whitelist | `email`, `fcmToken`, `route`, raw GPS coordinates |

**Opt-in / Opt-out lifecycle:**
- Default for every new account: `showOnLeaderboard = false` (no document created in `leaderboard/`).
- Opting **in** (`false -> true`): compute current week's total `distanceM` and `runCount` from `users/{uid}/activities`, write `leaderboard/{currentWeekKey}_{uid}`.
- Saving/deleting a current-week run while opted **in**: recompute and overwrite `leaderboard/{currentWeekKey}_{uid}`.
- Editing `displayName` or `city` while opted **in**: update `leaderboard/{currentWeekKey}_{uid}` so public display stays accurate.
- Opting **out** (`true -> false`): delete `leaderboard/{currentWeekKey}_{uid}` immediately.

---

## 6. Feature-by-Feature Handoff Contract

*Scope note: Items 1–5 and 7 correspond to the six provisional course requirements in `docs/requirements-matrix.md`. Item 6 (Leaderboard) is explicitly marked **optional** in `docs/mvp-specification.md` and `docs/requirements-matrix.md`, though its UI and draft rules are already built.*

| Feature | Current state | Existing UI entry point | Existing model/controller | Proposed integration boundary | Required behavior | Acceptance criteria |
| --- | --- | --- | --- | --- | --- | --- |
| **1. Authentication** *(Mandatory — provisional Req #1, #6)* | Local/mock preview (`signInLocalPreview`, `signUpLocalPreview`, `enterQuickPreview`, `signOut`) | `AuthScreen`, `ProfileScreen` (Sign out), `NearPaceApp` auth gate | `NearPaceController` (`isSignedIn`, `firebaseStatus`), `UserProfile`, `FirebaseBootstrapStatus` | `AuthRepository` (`FirebaseAuthRepository` + `MockAuthRepository`) | Email/password sign-up, sign-in, session persistence across restarts, sign-out with state/stream cleanup, human-readable auth error messages. | 1. Signing up with a new email/password creates a Firebase Auth user and `users/{uid}` doc, and navigates to `HomeScreen`.<br>2. Restarting the app restores the signed-in session automatically.<br>3. Wrong password or duplicate email displays an inline error on `AuthScreen` without crashing.<br>4. Signing out returns to `AuthScreen` and clears cached user data. |
| **2. User profile** *(Mandatory — provisional Req #1, #6)* | Local/mock preview (`NearPaceMockData.defaultProfile()`, sync `updateProfile`) | `ProfileScreen`, `_EditProfileSheet`, `HomeScreen` greeting | `UserProfile`, `NearPaceController` (`profile`, `updateProfile`, `setShowOnLeaderboard`) | `ProfileRepository` (`FirestoreProfileRepository` + `MockProfileRepository`) | Persist `displayName` (2–40 chars), optional `city` (0–60 chars), `showOnLeaderboard` (default `false`), `fcmToken`, `createdAt` under `users/{uid}`. | 1. Editing display name or city persists to `users/{uid}` and survives app restart.<br>2. A second authenticated account receives `permission-denied` when attempting to read or write another user's `users/{uid}` doc.<br>3. Profile write failure surfaces a visible error and does not silently lie that changes were saved. |
| **3. Activity persistence** *(Mandatory — provisional Req #1, #2, #6)* | Local/mock preview (`NearPaceMockData.initialActivities()`, sync `saveActivity`/`deleteActivity`) | `RunResultScreen` (`Save run`, `Delete`), `HomeScreen`, `HistoryScreen` | `Activity`, `GeoPointLite`, `WeatherSnapshot`, `NearPaceController` (`activities`, `historyState`, `weekly*`) | `ActivityRepository` (`FirestoreActivityRepository` + `MockActivityRepository`) | Stream `users/{uid}/activities` newest first; save completed run with capped route; delete saved run; surface loading/empty/error states. | 1. A completed run saved from `RunResultScreen` appears in `HistoryScreen` and `HomeScreen` and remains after cold restart.<br>2. Deleting a saved run removes it from Firestore and updates weekly totals.<br>3. A second authenticated account cannot read, modify, or delete the first user's `activities` (verified via Rules test or emulator).<br>4. Save failure keeps `RunResultScreen` open with the unsaved run and offers retry. |
| **4. GPS tracking** *(Mandatory — provisional Req #3, MVP core)* | Local/mock preview (mock permission sheet + 1s timer stepping `simulationLoop()`) | `AppShell` "Run" CTA, `RecordRunScreen`, `LocationPermissionSheet` | `RunState` (sealed), `RunSession`, `GeoPointLite`, `LocationPermissionStatus`, `NearPaceController` | `LocationTrackingService` (`GeolocatorTrackingService` + `SimulatedLocationService`) | Real foreground Android permission flow, location-service check, live `Stream<Position>` mapped to `GeoPointLite` and filtered by `RunSession`, pause/resume, clean stream disposal. | 1. Tapping Start without permission requests real Android foreground location permission.<br>2. Denying or permanently denying location permission transitions to `RunFailed` with recovery action (`openAppSettings`) and never crashes.<br>3. Moving along a real or mock GPS route increments distance/pace and draws a live `RouteSketch`; pausing freezes distance and elapsed time.<br>4. Rejects fixes with `accuracyM > 35` or implied speed `> 12 m/s` (unit-tested in `RunSession`). |
| **5. Weather** *(Mandatory — provisional Req #5)* | Local/mock preview (hardcoded `WeatherSnapshot` in `finishRecording()`) | `RunResultScreen` (`WeatherSummaryCard`), `ActivityCard` (`WeatherPill`) | `WeatherSnapshot`, `weatherCodeLabel()`, `NearPaceController` | `WeatherRepository` (`OpenMeteoWeatherRepository` + `MockWeatherRepository`) | Fetch Open-Meteo `current` (`temperature_2m`, `apparent_temperature`, `weather_code`) for `route.first` with timeout; persist optional snapshot on `Activity`; show Open-Meteo attribution. | 1. Online run with valid start coordinate displays real temperature, feels-like temp, WMO condition label, and `"Weather data by Open-Meteo"` attribution.<br>2. In airplane mode or on HTTP error/timeout, `WeatherSummaryCard` shows `"Conditions unavailable"` and does **not** block viewing or saving the run.<br>3. Open-Meteo JSON parser and failure fallback are covered by unit tests using a mock HTTP client. |
| **6. Leaderboard** *(Optional in `requirements-matrix.md` & `mvp-specification.md`; UI already built)* | Local/mock preview (`NearPaceMockData.initialLeaderboard()` + local self-append) | `LeaderboardScreen`, `ProfileScreen` opt-in toggle | `LeaderboardEntry`, `NearPaceFormatters.isoWeekKey`, `NearPaceController` (`filteredLeaderboardEntries`, `leaderboardState`) | `LeaderboardRepository` (`FirestoreLeaderboardRepository` + `MockLeaderboardRepository`) | Query `leaderboard` for `currentWeekKey` ordered by `distanceM` desc; upsert `leaderboard/{weekKey}_{uid}` only when opted in; delete doc immediately on opt-out; filter by city. | 1. New accounts default to `showOnLeaderboard == false` and do not appear in `leaderboard/`.<br>2. Opting in publishes only `uid`, `displayName`, `city`, `weekKey`, `distanceM`, `runCount`, `updatedAt` (no `email` or `route`).<br>3. Opting out deletes `leaderboard/{weekKey}_{uid}` so the user disappears from public rankings.<br>4. A user cannot write or delete another user's leaderboard document (verified by Rules test). |
| **7. Notifications** *(Mandatory — provisional Req #4; background delivery best-effort)* | Local/mock preview (`ProfileScreen` preview button -> `ForegroundNoticeBanner` in `AppShell`) | `AppShell` (`ForegroundNoticeBanner`), `ProfileScreen` (Notifications card) | `ForegroundNotice`, `UserProfile.fcmToken`, `NearPaceController` (`activeNotice`) | `PushNotificationService` (`FcmPushNotificationService` + `NoopPushNotificationService`) | Request Android 13+ notification permission, save FCM token to `users/{uid}.fcmToken`, subscribe to topic `nearpace_updates`, show foreground console messages in `ForegroundNoticeBanner`, register background handler. | 1. Signed-in Android device with Play Services stores a non-empty `fcmToken` in `users/{uid}` and subscribes to `nearpace_updates`.<br>2. Sending a Firebase Console test message to `nearpace_updates` while app is foregrounded renders `ForegroundNoticeBanner` and can be dismissed.<br>3. Denying notification permission does not block sign-in, recording, or saving runs.<br>4. Background notification behavior and console demo steps are documented. |

---

## 7. Recommended Integration Order & Dependencies

Each stage ends in a verifiable test/demo checkpoint before moving to the next.

| Stage | Focus | Prerequisites | Deliverables | Required Tests | Acceptance Criteria | Potential Blockers | Coordination (UI ↔ Backend) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **1** | **Firebase project & Android platform setup** | Firebase Console access; Android build verified (`docs/android-build-setup.md`) | Firebase project with Email/Password Auth, Cloud Firestore, and FCM enabled; local gitignored `dart_defines.json` (and `google-services.json` if required for FCM); verified `FirebaseReady` banner on device. | Manual launch on Android with `--dart-define-from-file`; confirm `AuthScreen` shows `"Firebase ready"`. | App launches cleanly on Android and transitions `firebaseStatus` to `FirebaseReady`. | Missing Firebase Console ownership; Android `com.nearpace` package ID mismatch; FCM requiring `google-services.json`. | **Both:** Agree on `applicationId` (`com.nearpace`), secret-sharing channel for `dart_defines.json`, and whether `google-services.json` is gitignored + Gradle plugin added. |
| **2** | **Schema, Rules fix & repository contracts** | Stage 1; review of Section 4 & 5.1 | Fix `firestore.rules` (`activities` read/delete bug); agree on `Timestamp` mapping & route cap; add abstract interfaces in `lib/data/repositories/` & `lib/services/` with mock implementations; wire constructor injection into `NearPaceController`. | `flutter analyze`; all 20 existing tests pass unchanged; add unit tests for `RunSession`, `GeoPointLite`, and model mappers; Firestore Rules unit test / Emulator check. | Zero regressions on existing UI tests; Firestore Rules allow owner read/write/delete and deny cross-user access. | Disagreement on `Timestamp` vs ISO string or `LeaderboardEntry` fields. | **Both:** Co-review interface signatures and `firestore.rules` before writing Firebase implementations. |
| **3** | **Firebase Authentication** | Stage 2 | `FirebaseAuthRepository`; async `signIn` / `signUp` / `signOut` + `authStateChanges` subscription in `NearPaceController`; minimal `AuthScreen` update to pass password, show busy state, and show backend auth error. | Unit tests for controller auth flows with fake `AuthRepository`; manual sign-up, restart, sign-out on Android. | User signs up, restarts app staying signed in, sees inline errors for bad credentials, and signs out cleanly. | Unhandled `FirebaseAuthException` codes; auth gate flashing `AuthScreen` during startup hydration. | **UI dev** reviews small `AuthScreen` busy/error UI adjustment; **Backend dev** implements `FirebaseAuthRepository` and error mapping. |
| **4** | **Firestore User Profile** | Stage 3 | `FirestoreProfileRepository`; create `users/{uid}` on sign-up (`showOnLeaderboard: false`, `createdAt`); watch profile; async `updateProfile` & `setShowOnLeaderboard`. | Controller + repository tests; two-account Firestore Rules test proving user B cannot read/write user A's profile. | Profile edits persist across restart; privacy defaults to `false`; cross-user access denied. | Missing initial profile doc for users created manually in Firebase Console (handle gracefully by auto-creating default doc). | **UI dev** reviews async SnackBar/error handling in `ProfileScreen._EditProfileSheet`. |
| **5** | **Firestore Activity Persistence** | Stage 4 | `FirestoreActivityRepository` with `Timestamp` mapping and route simplification; live stream into `NearPaceController`; async `saveActivity` and `deleteActivity` with busy/error feedback in `RunResultScreen`. | Repository mapper tests; controller tests; two-account isolation test on `users/{uid}/activities`. | Saved runs appear in `HistoryScreen` & `HomeScreen` immediately and after restart; delete removes doc; failed save does not discard unsaved run. | Large GPS arrays approaching 1 MiB limit if uncapped; `firestore.rules` read/delete bug if Stage 2 was skipped. | **UI dev** reviews `RunResultScreen` save/delete loading and retry error UI. |
| **6** | **Real GPS Tracking (`geolocator`)** | Stage 2 (can run in parallel with Stages 4–5) | `GeolocatorTrackingService`; real Android permission flow + location-services check; live `Stream<GeoPointLite>` feeding `RunSession`; hide preview-only switches on `RecordRunScreen` when `!isLocalPreview`. | Unit tests for `RunSession` (accuracy, jitter, speed jump, pause/resume); manual test on Android device/emulator with mock GPS route. | Outdoor or mock-GPS run records real distance, pace, and `RouteSketch`; permission denial enters `RunFailed` safely; pause freezes elapsed time & distance. | Indoor GPS signal drift; emulator missing mock GPS route; Android battery/screen-off behavior (foreground-only for MVP). | **UI dev** aligns `LocationPermissionSheet` copy/buttons with real OS prompt & `openAppSettings()`. |
| **7** | **Weather API (Open-Meteo)** | Stage 5 & 6 | `OpenMeteoWeatherRepository` using `http` with timeout; non-blocking fetch on run completion (or result screen) with `WeatherSummaryCard(isLoading: ...)` and `"Conditions unavailable"` fallback. | Unit tests with `MockClient` covering 200 OK, timeout, 500 error, malformed JSON; airplane-mode manual check. | Online run shows live Open-Meteo temperature/condition + attribution; offline run degrades gracefully and saves normally. | Rate-limiting or network flakiness during demo (mitigated by graceful fallback). | **UI dev** confirms `RunResultScreen` passes `isLoading` to `WeatherSummaryCard` if weather loads asynchronously. |
| **8** | **Weekly Leaderboard & Privacy** *(Optional per provisional matrix)* | Stage 4 & 5 | `FirestoreLeaderboardRepository`; Firestore composite index (`weekKey` ASC, `distanceM` DESC); owner upsert on run save/delete/opt-in/profile edit; doc delete on opt-out. | Controller + repository tests; Firestore Rules test verifying strict field whitelist and owner-only write/delete. | Opted-in users rank accurately for `currentWeekKey` and filter by city; opted-out users never appear; zero private fields published. | Missing Firestore composite index (Firestore SDK prints direct index-creation URL on first query). | **Backend dev** creates & documents composite index (`firestore.indexes.json` optional). |
| **9** | **Push Notifications (FCM)** *(Mandatory per provisional Req #4)* | Stage 1 & 4 | `FcmPushNotificationService`; Android 13+ permission prompt; save `fcmToken` to `users/{uid}`; subscribe to `nearpace_updates`; foreground `onMessage` -> `ForegroundNoticeBanner`; top-level background handler. | Manual console push test to `nearpace_updates` on Android device/emulator with Play Services. | Foreground console message renders `ForegroundNoticeBanner` and dismisses cleanly; denied permission does not break app. | Emulator image without Google Play Services; missing `google-services.json` for background delivery. | **UI dev** hides or gates `"Preview foreground banner"` button in `ProfileScreen` when live FCM is active. |
| **10** | **Integration Verification & Demo Readiness** | Stages 1–9 | Update `docs/requirements-matrix.md` and `docs/implementation-plan.md` statuses with real evidence; run full test suite and Android debug APK verification on target device. | `dart format`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, two-account security verification, offline weather check, FCM console check. | All demo success criteria in `docs/mvp-specification.md` pass with recorded evidence. | Lecturer rubric still unverified (confirm once published). | **Both:** Final end-to-end rehearsal before submission. |

---

## 8. Open Questions Requiring Agreement Before Phase 3

Please confirm these items between the UI developer and backend developer before starting Stage 1:

1. **Firebase configuration strategy on Android:** Will we use `--dart-define-from-file=dart_defines.json` only, or also add a gitignored `android/app/google-services.json` + `com.google.gms.google-services` Gradle plugin to ensure reliable Android FCM background handling?
2. **Firestore Timestamp convention:** Confirm using native Firestore `Timestamp` for `startedAt`, `endedAt`, `updatedAt`, `fetchedAt`, and `createdAt` inside repository mappers (required to satisfy `firestore.rules` `updatedAt is timestamp` without weakening rules).
3. **Preview mode behavior when Firebase is configured:** Should the `"Continue in local preview"` button on `AuthScreen` and the simulated GPS/weather switches on `RecordRunScreen` be hidden whenever `FirebaseReady` is active? (Recommended: yes.)
4. **Weather fetch timing:** Should weather be fetched inside `finishRecording()` (bounded by a short 4–5s timeout so it is immediately attached to the unsaved `Activity`), or fetched asynchronously while `RunResultScreen` is open using `WeatherSummaryCard(isLoading: true)`?
5. **Route downsampling cap:** Confirm a maximum stored point count per activity (e.g., 250 points) and simplification rule.
6. **Leaderboard scope & city filtering:** Confirm whether leaderboard remains included for the demo and whether client-side city filtering over the current week's leaderboard query is acceptable for class-scale data.
7. **Lecturer rubric:** If the official course rubric becomes available, reconcile `docs/requirements-matrix.md` immediately before spending time on optional features.
