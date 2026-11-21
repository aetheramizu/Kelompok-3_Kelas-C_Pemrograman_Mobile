# NearPace — Phase 2A Post-MVP Audit & Android Build Verification Report

- **Audit date:** 2026-11-21
- **Repository:** `https://github.com/aetheramizu/Kelompok-3_Kelas-C_Pemrograman_Mobile`
- **Flutter application path:** `NearPace App/nearpace/`
- **Verified baseline commit:** `1a81cb9` (`origin/main`, Merge PR #16 from `Tugas_D121241001` — *"Implement NearPace complete MVP mobile UI"*)
- **Local initial state:** Checked out on `Tugas_D121241001` (`42ded29`, 0 diff against `origin/main`), working tree clean, no stashes, no uncommitted changes.
- **Audit branch:** `feature/nearpace-phase2-audit` (branched cleanly from `origin/main` at `1a81cb9`; zero application source changes made).

---

## 1. Environment & Toolchain Audit

All measurements below were captured directly on the audit host without altering global system packages, SDK licenses, or Gradle configuration.

| Component | Verified Value / Status | Notes |
| --- | --- | --- |
| **Operating System** | Ubuntu 24.04.5 LTS (`7.0.0-1016-oracle`) | Linux VM |
| **CPU Architecture** | `aarch64` (ARM64) | Important for Android NDK host binaries (see Section 6) |
| **Flutter SDK** | `3.50.1` (stable, rev `ae9b586f34`, 2026-11-18) | Installed via snap at `/home/alief/snap/flutter/common/flutter` |
| **Dart SDK** | `3.14.0` (stable, `linux_arm64`) | DevTools `2.61.0` |
| **Java / JDK** | OpenJDK `21.0.13.1` (`/usr/bin/java`, `/usr/bin/javac`) | Compatible with AGP 9.3.1 / Gradle 9.5.0; app compiles targeting Java 17 |
| **Android SDK** | Present at `/home/alief/Android/Sdk` | Configured in gitignored `android/local.properties` |
| **Installed Android Platforms** | `android-34`, `android-36` | Matches Flutter 3.50 default `compileSdk = 36`, `targetSdk = 36`, `minSdk = 24` |
| **Android Build-Tools** | `35.0.0`, `36.0.0` (with custom ARM64 symlinks in `build-tools/arm64/`) | `aapt`, `aapt2`, `aidl`, `dexdump`, `split-select`, `zipalign` resolve to native `ELF 64-bit ARM aarch64` binaries |
| **Android NDK** | `28.2.13676358` | Matches Flutter default `ndkVersion = "28.2.13676358"`, **but** ships `linux-x86_64` host tools (`llvm-strip` fails on `aarch64`) |
| **Android SDK Licenses** | Files present in `/home/alief/Android/Sdk/licenses/` | Accepted by Gradle during build; `flutter doctor -v` still reports `Android license status unknown` |
| **Gradle Wrapper** | `9.5.0-all` (`android/gradle/wrapper/gradle-wrapper.properties`) | Cached under `~/.gradle/wrapper/dists/gradle-9.5.0-all` |
| **Android Gradle Plugin (AGP)** | `9.3.1` (`android/settings.gradle.kts`) | Kotlin Android plugin `2.4.20`; `android.newDsl=false`, `android.builtInKotlin=false` |
| **Connected Devices (`flutter doctor`)** | `Pixel 9` (`127.0.0.1:6601`, Android 14 / API 34, `android-arm64`), `Linux` (`linux-arm64`) | Android target available |
| **Environment Variables** | `HOME=/home/alief`, standard `PATH` including `/snap/bin` | `ANDROID_HOME`, `ANDROID_SDK_ROOT`, and `JAVA_HOME` are not explicitly exported; resolved via `PATH` and `android/local.properties` |
| **Non-Android Toolchains** | Chrome missing; Linux desktop toolchain (`clang++`, `cmake`, `ninja`, `pkg-config`) missing | Expected and non-blocking for Android target |

---

## 2. Dependency Health Audit

Evaluated `pubspec.yaml` (`environment: sdk: ^3.14.0`), `pubspec.lock`, `flutter pub outdated`, `.flutter-plugins-dependencies`, and actual `import` usage across all 33 `lib/` files and 3 `test/` files (7,872 total Dart lines).

| Package | Constraint (`pubspec.yaml`) | Resolved (`pubspec.lock`) | Latest (`pub outdated`) | Actual `lib/` Usage | Native Android Plugin? | Assessment |
| --- | --- | --- | --- | --- | --- | --- |
| `material_ui` | `^1.1.0` | `1.11.1` | `1.11.1` | Imported in 22 files | No | Healthy; Flutter 3.50 decoupled Material library |
| `provider` | `^6.1.5+1` | `6.1.5+1` | `6.1.5+1` | Imported in 9 files | No | Healthy; powers `NearPaceController` |
| `firebase_core` | `^5.2.0` | `5.2.0` | `5.2.0` | Imported in 1 file (`firebase_bootstrap.dart`) | Yes | Healthy; compiles cleanly |
| `firebase_auth` | `^7.1.0` | `7.1.0` | `7.1.0` | **Unused** (0 imports) | Yes | Intentionally staged for Phase 3 backend |
| `cloud_firestore` | `^7.2.0` | `7.2.0` | `7.2.0` | **Unused** (0 imports) | Yes | Intentionally staged for Phase 3 backend |
| `firebase_messaging` | `^17.1.0` | `17.1.0` | `17.1.0` | **Unused** (0 imports) | Yes (merges `POST_NOTIFICATIONS`, `WAKE_LOCK`, C2DM) | Intentionally staged for Phase 3 backend |
| `geolocator` | `^14.1.2` | `14.1.2` | `14.1.2` | **Unused** (0 imports) | Yes (`geolocator_android`) | Intentionally staged for Phase 3 GPS |
| `http` | `^1.6.0` | `1.6.0` | `1.6.0` | **Unused** (0 imports) | No | Intentionally staged for Phase 3 Open-Meteo |
| `cupertino_icons` | `^1.0.8` | `1.0.9` | `2.0.0` | **Unused** (0 imports) | No | Template leftover; only outdated direct dependency. Optional low-priority removal; **no urgent upgrade needed** |
| `flutter_lints` *(dev)* | `^6.0.0` | `6.0.0` | `6.0.0` | `analysis_options.yaml` | No | Up-to-date |

### Dependency & Platform Configuration Findings

1. **Zero dependency conflicts:** `flutter pub get --offline` resolves cleanly against the committed `pubspec.lock`. All active dependencies are at their latest resolvable versions.
2. **Android native plugins compile cleanly:** All 6 native Android plugins in `.flutter-plugins-dependencies` (`firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_messaging`, `geolocator_android`, transitive `package_info_plus`) compiled and merged into the debug APK without Gradle or Kotlin errors.
3. **Missing Firebase platform files (expected in Phase 2):** No `android/app/google-services.json` and no `com.google.gms.google-services` Gradle plugin are configured. `FirebaseConfig` reads keys from `--dart-define`. Before Phase 3 FCM work, the backend developer should verify whether Android FCM background delivery requires a gitignored `google-services.json` + Google Services Gradle plugin.
4. **AndroidManifest permissions:** `android/app/src/main/AndroidManifest.xml` declares `INTERNET`, `ACCESS_COARSE_LOCATION`, and `ACCESS_FINE_LOCATION`. `firebase_messaging` automatically merges `POST_NOTIFICATIONS` and `WAKE_LOCK` into the merged debug manifest; runtime permission prompts are still required in Dart for Android 13+ (API 33+).
5. **Upgrade recommendation:** Do **not** upgrade dependencies at this stage. Every backend and UI dependency is current; only `cupertino_icons` (`1.0.9 -> 2.0.0`) is behind and unused.

---

## 3. Existing Application Architecture Audit

### 3.1 Entry & Firebase Bootstrap
- `lib/main.dart`: Calls `WidgetsFlutterBinding.ensureInitialized()`, awaits `bootstrapFirebase()`, and passes `FirebaseBootstrapStatus` to `NearPaceApp`.
- `lib/config/firebase_config.dart`: Reads compile-time `--dart-define` strings (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, optional `FIREBASE_STORAGE_BUCKET`, `FIREBASE_AUTH_DOMAIN`).
- `lib/config/firebase_bootstrap.dart`: Returns a sealed `FirebaseBootstrapStatus`: `FirebaseUnconfigured(missingKeys)`, `FirebaseReady()`, or `FirebaseInitFailed(message)`. Never fakes a connected backend when unconfigured.

### 3.2 Navigation & Screen Ownership
- `lib/app.dart`: Wraps the app in `ChangeNotifierProvider<NearPaceController>` and uses an `AnimatedSwitcher` auth gate:
  - Signed out -> `AuthScreen` (`lib/ui/screens/auth_screen.dart`).
  - Signed in -> `AppShell` (`lib/ui/screens/app_shell.dart`), hosting an `IndexedStack` with 4 tabs (`HomeScreen`, `HistoryScreen`, `LeaderboardScreen`, `ProfileScreen`), a custom bottom bar with a centered `Run` action button, and a top-anchored `ForegroundNoticeBanner`.
- Modal full-screen flows pushed via `Navigator.push`:
  - `AppShell` / `HomeScreen` / `HistoryScreen` -> `RecordRunScreen` (`lib/ui/screens/record_run_screen.dart`, 866 lines) -> `pushReplacement` to `RunResultScreen(isUnsaved: true)` (`lib/ui/screens/run_result_screen.dart`).
  - `HomeScreen` / `HistoryScreen` activity tap -> `RunResultScreen(isUnsaved: false)`.

### 3.3 State Controller (`NearPaceController`) & Mock-Data Flow
- `lib/state/nearpace_controller.dart` (562 lines) owns **all** runtime state: theme mode, active tab, foreground notice, auth status, `UserProfile`, `List<Activity>`, `List<LeaderboardEntry>`, city filter, `ViewLoadState` for history & leaderboard, `LocationPermissionStatus`, sealed `RunState`, `RunSession?`, and a 1-second `Timer.periodic` that simulates GPS movement along `NearPaceMockData.simulationLoop()`.
- `lib/state/mock_data.dart` (256 lines) seeds deterministic local fixtures (`defaultProfile`, `initialActivities`, `initialLeaderboard`, `simulationLoop`).
- `isLocalPreview` is hardcoded to `true`. All mutation methods (`signInLocalPreview`, `signUpLocalPreview`, `signOut`, `updateProfile`, `setShowOnLeaderboard`, `saveActivity`, `deleteActivity`) are synchronous in-memory operations.

### 3.4 Domain Models & Theme
- `lib/domain/`: Clean pure-Dart models (`GeoPointLite`, `WeatherSnapshot`, `Activity`, `UserProfile`, `LeaderboardEntry`, sealed `RunState`, `RunSession`). Zero Flutter or Firebase SDK imports.
- `lib/theme/`: Material 3 dark/light themes (`NearPaceTheme`, `NearPaceColors` `ThemeExtension`, `NearPaceSpacing`, `NearPaceMotion`).
- `lib/utils/formatters.dart`: `NearPaceFormatters` for distance, clock/compact duration, pace, and ISO Monday `weekKey`.

### 3.5 Error, Loading & Empty States
- `lib/ui/widgets/state_views.dart` provides reusable `LoadingSkeletonList`, `EmptyStateView`, `ErrorStateView`, `StatusPill`, `SectionHeader`, and `ForegroundNoticeBanner`.
- `HomeScreen`, `HistoryScreen`, and `LeaderboardScreen` already switch exhaustively on `ViewLoadState` (`ready`, `loading`, `error`).
- `WeatherSummaryCard` (`lib/ui/widgets/weather_badge.dart`) already supports `isLoading`, loaded conditions with `"Weather data by Open-Meteo"`, and `weather == null` (`"Conditions unavailable"`).
- **Gap:** Async submission busy/error states are not yet wired on `AuthScreen` submit, `ProfileScreen` edit save/opt-in toggle, or `RunResultScreen` save/delete because those mutations are currently synchronous.

### 3.6 Testing Structure
- `test/controller_test.dart`: 5 unit tests covering initial state, sign-up preview, leaderboard opt-in + city filter, run recording lifecycle + permission guard, and foreground notice banner.
- `test/formatters_test.dart`: 4 unit tests covering distance, durations, pace edge cases, and ISO Monday `weekKey`.
- `test/widget_test.dart`: 11 widget tests covering all 3 `FirebaseBootstrapStatus` views, auth validation & quick preview, tab switching, full recording->save flow, permission denied recovery, weather unavailable fallback, 360px narrow screen @ 1.6x text scale, landscape + light theme switch, and profile edit + sign-out.
- **Coverage gaps:** No unit tests exist yet for `RunSession` GPS filtering (accuracy > 35 m, jitter < 1.5 m, speed > 12 m/s, pause/resume math), `GeoPointLite.distanceTo`, or domain model `toMap()`/`fromMap()` round-trips.

### 3.7 Coupling Assessment
- **Clean boundary:** Presentation widgets (`lib/ui/`) contain **zero** direct Firebase, Firestore, HTTP, or Geolocator calls.
- **Primary coupling hotspot:** `NearPaceController` directly instantiates `NearPaceMockData`, hardcodes `isLocalPreview => true`, and mixes UI navigation/theme state with mock data storage and simulated GPS ticking. Introducing constructor-injected repository/service interfaces with mock defaults (detailed in `docs/backend-integration-handoff.md`) cleanly decouples data access without changing the state-management framework or rewriting UI screens.

---

## 4. MVP Feature Verification Matrix

Classification scale:
1. **Implemented and verified** — Real feature works end-to-end and is verified by tests/checks.
2. **Implemented as a local/mock preview** — Complete UI and local state flow, backed by in-memory mock data rather than live backend/device services.
3. **Partially implemented** — Some real foundation exists, but key runtime pieces are incomplete or missing.
4. **Not implemented** — Feature does not exist in application code yet.
5. **Unable to verify** — Cannot be verified due to environment/external constraints.

| MVP Feature | Spec Reference | Classification | Verified Evidence & Limitations |
| --- | --- | --- | --- |
| **Firebase bootstrap & status visibility** | `requirements-matrix.md` #1 | **Partially implemented** | `Firebase.initializeApp` via `--dart-define` works (`firebase_bootstrap.dart`) and all 3 states are widget-tested; no Firebase project credentials are connected yet. |
| **Authentication & preview mode** | `mvp-specification.md`, Req #6 | **Implemented as a local/mock preview** | `AuthScreen` validates email/password/name/city and switches to `AppShell`, but calls `signInLocalPreview` / `signUpLocalPreview` / `enterQuickPreview`. `firebase_auth` is unused; password is not forwarded to controller. |
| **Home dashboard** | `mvp-specification.md` | **Implemented as a local/mock preview** | Weekly distance, duration, pace, 7-day `WeeklyDistanceChart`, recent 3 runs, and status pill work and are widget-tested against seeded local activities. |
| **Run recording state transitions** | `mvp-specification.md`, Req #3 | **Implemented as a local/mock preview** | Sealed `RunState` (`RunIdle`, `RunPreparing`, `RunActive`, `RunStopping`, `RunFailed`), `RunSession` math, live `RouteSketch`, pause/resume, and discard/finish guards work against a simulated waypoint loop and mock permission sheet. Real `geolocator` stream & OS permission requests are not wired. |
| **Activity result & history** | `mvp-specification.md`, Req #1, #2 | **Implemented as a local/mock preview** | `RunResultScreen` (metrics, `CustomPainter` `RouteSketch`, save/discard/delete) and `HistoryScreen` (`All runs` / `This week` filters) work in memory only; data does not survive cold app restart. |
| **Leaderboard & opt-in behavior** | `mvp-specification.md` (optional) | **Implemented as a local/mock preview** | Default `showOnLeaderboard: false`, opt-in prompt, city filters, `"You"` badge, and private-field exclusion work locally against mock entries; not backed by Firestore `leaderboard/` collection yet. |
| **Profile & settings** | `mvp-specification.md` | **Implemented as a local/mock preview** | Display name/city editing (40/60 char limits), opt-in toggle, connection status card, and sign-out confirmation work in memory only. |
| **Theme switching (Dark / Light / System)** | MVP UI | **Implemented and verified** | `NearPaceTheme.light()` / `.dark()` and `SegmentedButton<ThemeMode>` in `ProfileScreen` switch themes cleanly and are verified by widget test (`renders cleanly in landscape and switches to Light theme`). |
| **Weather presentation** | `mvp-specification.md`, Req #5 | **Implemented as a local/mock preview** | `WeatherSummaryCard` (Open-Meteo attribution, loading state, `"Conditions unavailable"` fallback) and `WeatherPill` are built and widget-tested, but `finishRecording()` injects a hardcoded `WeatherSnapshot` instead of calling Open-Meteo via `http`. |
| **Loading, empty, and error states** | MVP UI / `state_views.dart` | **Implemented and verified** | `LoadingSkeletonList`, `EmptyStateView`, `ErrorStateView`, `RunFailed` recovery card, and weather fallback are implemented and verified in widget tests (async mutation busy/error states remain to be added in Phase 3). |
| **Push notifications (FCM)** | `mvp-specification.md`, Req #4 | **Implemented as a local/mock preview** | `ForegroundNoticeBanner` in `AppShell` and preview trigger in `ProfileScreen` work and are unit-tested; `firebase_messaging` token registration, topic `nearpace_updates` subscription, and background handler are not implemented yet. |
| **Firestore Security Rules** | `mvp-specification.md`, Req #6 | **Partially implemented** | Draft `firestore.rules` exists in repo, not yet deployed/tested against emulator, and contains a confirmed `read`/`delete` evaluation defect on `activities` (see Section 7). |

---

## 5. Automated Checks & Test Verification

All commands were executed from `NearPace App/nearpace/` against commit `1a81cb9`.

| Check | Result | Evidence | Required action |
| --- | --- | --- | --- |
| **Dependency resolution** | **PASS** | `flutter pub get --offline` -> exit `0` (`Got dependencies!`) | None (optional low-priority removal of unused `cupertino_icons` later) |
| **Formatting** | **PASS** | `dart format --output=none --set-exit-if-changed lib test` -> exit `0` (`Formatted 36 files (0 changed) in 0.51 seconds.`) | None |
| **Static analysis** | **PASS** | `flutter analyze` -> exit `0` (`No issues found! (ran in 5.2s)`) | None |
| **Unit tests** | **PASS** | `flutter test --reporter expanded test/controller_test.dart test/formatters_test.dart` -> exit `0` (`9/9 passed`: 5 controller, 4 formatters) | Add unit tests for `RunSession`, `GeoPointLite`, and model mappers in Phase 3 Stage 2 |
| **Widget tests** | **PASS** | `flutter test --reporter expanded test/widget_test.dart` -> exit `0` (`11/11 passed`) | Keep passing via mock repository defaults during Phase 3 |
| **Android build** | **PASS** *(with ARM64 host caveats)* | `flutter build apk --debug` -> exit `0` in `122.6s`, produced `build/app/outputs/flutter-apk/app-debug.apk` (`1.4G` unstripped; see Section 6) | Re-verify stripped debug/release APK on a standard x86-64 Windows/Linux/macOS workstation with official Android SDK |

---

## 6. Android Debug APK Compilation Verification

- **Classification:** **PASS** *(with documented ARM64 host environment caveats)*
- **Command executed:** `flutter build apk --debug` (from `NearPace App/nearpace/`)
- **Exit code:** `0` (`Running Gradle task 'assembleDebug'... 122.6s`, `✓ Built build/app/outputs/flutter-apk/app-debug.apk`)
- **Why this differs from the historical VM report:** The previous report noted missing Android SDK platforms on this ARM64 Ubuntu VM. Re-inspection confirmed that `/home/alief/Android/Sdk` now contains `platforms/android-34`, `platforms/android-36`, `build-tools/35.0.0`, `build-tools/36.0.0` (with native `aarch64` symlinks in `build-tools/arm64/`), `ndk/28.2.13676358`, and accepted license files.

### Verified Host Caveats (Environment Limitations — Not Project Defects)
1. **NDK `llvm-strip` is x86-64 on an ARM64 host:** Gradle printed twice:
   `/home/alief/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip: 1: Syntax error: "(" unexpected`
   Because native debug symbols could not be stripped, the resulting `app-debug.apk` is **1.4 GB** instead of a normal ~60–100 MB debug APK. Release builds or native stripping cannot be reliably executed on this ARM64 host.
2. **`platform-tools` inconsistent path warning:** `/home/alief/Android/Sdk/platform-tools` contains only a manual `adb -> /usr/bin/adb` symlink without `package.xml`, causing Gradle to auto-install `platform-tools` v37.0.3 into `/home/alief/Android/Sdk/platform-tools-2`.
3. **`flutter doctor -v` license warning:** Reports `Android license status unknown` even though Gradle accepted the licenses in `/home/alief/Android/Sdk/licenses/`.

**Conclusion:** The Flutter application and its Android Gradle configuration (`AGP 9.3.1`, `Gradle 9.5.0`, `Kotlin 2.4.20`, all 6 Android plugins) have **zero compilation defects**. See `docs/android-build-setup.md` for clean verification steps on a standard x86-64 Windows workstation.

---

## 7. Confirmed Defects & Blockers (Documented — Not Modified in Audit)

| ID | Severity | Location | Finding & Evidence | Proposed Fix |
| --- | --- | --- | --- | --- |
| **DEF-1** | **High** | `firestore.rules:21-26` | `match /activities/{activityId}` uses `allow read, write: if isOwner(uid) && (!request.resource.data.keys()...)`. On `read` and `delete`, `request.resource` is `null`, causing Firestore Rules evaluation to fail and deny all activity reads and deletes. | Split into `allow read, delete: if isOwner(uid);` and `allow create, update: if isOwner(uid) && ...` before deploying rules. |
| **DEF-2** | **High** | `lib/domain/leaderboard_entry.dart:44`, `lib/domain/activity.dart:44-45`, `firestore.rules:46` | `LeaderboardEntry.toMap()` serializes `updatedAt` as an ISO-8601 `String`, but `firestore.rules:46` requires `request.resource.data.updatedAt is timestamp`. Writing `toMap()` directly to Firestore will be rejected. Similarly `Activity` and `WeatherSnapshot` parse strings rather than Firestore `Timestamp`. | Handle `Timestamp <-> DateTime` conversion inside Firestore repository mappers (keeping `lib/domain/` free of `cloud_firestore`). |
| **BLK-1** | **Medium** *(External)* | Firebase Console / `--dart-define` | No Firebase project credentials (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`) or Android `google-services.json` exist yet. | Create/configure Firebase project in Phase 3 Stage 1; supply local gitignored `dart_defines.json` (and verify FCM `google-services.json` need). |
| **BLK-2** | **Medium** *(Environment)* | Audit VM (`aarch64`) | NDK `llvm-strip` is an x86-64 binary and fails on ARM64, yielding an unstripped 1.4 GB debug APK. | Verify normal-sized debug/release APKs on an x86-64 Windows/Linux/macOS machine with Android Studio (see `docs/android-build-setup.md`). |
| **BLK-3** | **Medium** *(External)* | `docs/requirements-matrix.md` | Verbatim lecturer rubric is still absent; the 6 course requirement areas remain provisional. | Reconcile `docs/requirements-matrix.md` immediately once the rubric is provided. |
| **GAP-1** | **Low** | `test/` | No unit tests yet for `RunSession`, `GeoPointLite`, or model `toMap`/`fromMap` serialization. | Add pure-Dart unit tests during Phase 3 Stage 2 before wiring live `geolocator` and Firestore. |
| **GAP-2** | **Low** | `pubspec.yaml:36`, `lib/domain/user_profile.dart` | `cupertino_icons` is unused; `UserProfile` omits `createdAt` (listed in `mvp-specification.md`). | Set `createdAt: FieldValue.serverTimestamp()` in `FirestoreProfileRepository` on sign-up; optionally drop `cupertino_icons` in a later cleanup. |

---

## 8. Recommended Next Actions

1. **Repository owner (UI dev):** Review and merge the Phase 2 audit/handoff PR; keep `main` clean; run the 5-minute Windows workstation build sanity check in `docs/android-build-setup.md` to confirm normal APK sizing (~60–100 MB).
2. **Backend developer:** Read `docs/backend-integration-handoff.md` and resolve the 7 coordination questions in Section 8 with the UI dev, then begin Phase 3 Stage 1 (Firebase project setup) and Stage 2 (fix `DEF-1` in `firestore.rules`, align `DEF-2` timestamps, add repository interfaces with mock defaults).
