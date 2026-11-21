# NearPace — Android Build Setup & Verification Guide

- **Last verified:** 2026-11-21
- **Baseline commit:** `1a81cb9` (`origin/main`)
- **Flutter app directory:** `NearPace App/nearpace/`

---

## 1. Verified Project Toolchain Requirements

These versions are read directly from `pubspec.yaml`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`, and Flutter 3.50's Gradle extension (`FlutterExtension.kt`).

| Requirement | Verified Project Value | Source |
| --- | --- | --- |
| **Flutter SDK** | `3.50.1` (stable) | Verified on audit host |
| **Dart SDK** | `^3.14.0` (verified `3.14.0`) | `pubspec.yaml` |
| **Java / JDK** | JDK 17–21 (verified OpenJDK `21.0.13.1`; compiles targeting Java 17 / JVM 17) | `android/app/build.gradle.kts` |
| **Gradle Wrapper** | `9.5.0-all` (downloaded automatically by wrapper) | `android/gradle/wrapper/gradle-wrapper.properties` |
| **Android Gradle Plugin (AGP)** | `9.3.1` | `android/settings.gradle.kts` |
| **Kotlin Android Plugin** | `2.4.20` | `android/settings.gradle.kts` |
| **Android `compileSdk` / `targetSdk`** | `36` (`flutter.compileSdkVersion`, `flutter.targetSdkVersion`) | `android/app/build.gradle.kts` |
| **Android `minSdk`** | `24` (Android 7.0) | `android/app/build.gradle.kts` |
| **Android Build-Tools** | `36.0.0` (or `35.0.0`+) | Required by `compileSdk 36` |
| **Android NDK** | `28.2.13676358` (`flutter.ndkVersion`) | Flutter 3.50 default |
| **Application ID / Namespace** | `com.nearpace` | `android/app/build.gradle.kts` |
| **Android Native Plugins** | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `geolocator_android`, `package_info_plus` | `.flutter-plugins-dependencies` |

---

## 2. Audit Host Findings (ARM64 Ubuntu 24.04 VM)

On the audit host (`Ubuntu 24.04.5 LTS`, `aarch64` / ARM64, Flutter `3.50.1`, OpenJDK `21.0.13.1`, `/home/alief/Android/Sdk`), `flutter build apk --debug` **PASSED** (`exit 0`, `122.6s`, produced `build/app/outputs/flutter-apk/app-debug.apk`), proving that the Flutter project and Gradle configuration compile cleanly.

However, three **host-only ARM64 environment caveats** were observed:

1. **x86-64 NDK `llvm-strip` cannot run on `aarch64`:**
   - Error logged during `assembleDebug`:
     `/home/alief/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip: 1: Syntax error: "(" unexpected`
   - Impact: Native debug `.so` libraries were left unstripped, inflating `app-debug.apk` to **1.4 GB**. Debug APK compilation still succeeded because `build-tools/36.0.0` on this VM had custom `aarch64` symlinks (`aapt2`, `zipalign`, etc.), **but release builds or native NDK stripping should not be done on ARM64 Linux**.
2. **`platform-tools` inconsistent location warning:**
   - `/home/alief/Android/Sdk/platform-tools` lacked `package.xml`, so Gradle installed `platform-tools` v37.0.3 into `platform-tools-2`.
3. **`flutter doctor -v` license check:**
   - Reports `Android license status unknown` even though `/home/alief/Android/Sdk/licenses/` contains accepted license files used by Gradle.

**Recommendation:** Use a standard **x86-64 Windows (or x86-64 Linux / macOS) workstation** with official Android Studio + Android SDK for stripped debug/release APKs, emulator testing, and final demo verification.

---

## 3. Safe Setup & Verification Steps on a Windows Workstation

Follow these steps on an x86-64 Windows PC with Flutter and Android Studio installed.

### Step 1: Confirm Android Studio SDK components

Open **Android Studio -> Settings -> Languages & Frameworks -> Android SDK**:
- **SDK Platforms tab:** Install **Android 16 (API 36)** (and optionally API 34 if testing on an Android 14 emulator).
- **SDK Tools tab:** Install:
  - `Android SDK Build-Tools 36.0.0`
  - `Android SDK Command-line Tools (latest)`
  - `Android SDK Platform-Tools`
  - `NDK (Side by side) 28.2.13676358`

### Step 2: Accept Android SDK licenses (interactive)

In PowerShell (only when you explicitly approve accepting Google's SDK licenses):

```powershell
flutter doctor --android-licenses
```

### Step 3: Validate the local toolchain

```powershell
flutter --version
java -version
flutter doctor -v
```

Confirm:
- Flutter `3.50.x` (Dart `3.14.x`) is active.
- `[✓] Android toolchain` shows Android SDK, Platform `android-36`, JDK 17 or 21, and accepted licenses.
- Do **not** modify `android/settings.gradle.kts` or `android/gradle/wrapper/gradle-wrapper.properties` unless a verified project compatibility issue requires it.

### Step 4: Validate project health before building

From the repository root:

```powershell
cd "NearPace App\nearpace"
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Expected baseline results (as verified at `1a81cb9`):
- `dart format`: 36 files, 0 changed, exit `0`.
- `flutter analyze`: `No issues found!`, exit `0`.
- `flutter test`: `20/20` tests passed (`9` unit + `11` widget), exit `0`.

### Step 5: Build the Android Debug APK

#### Standard local-preview debug APK (no Firebase credentials required)

```powershell
flutter build apk --debug
```

Expected output:
- `✓ Built build\app\outputs\flutter-apk\app-debug.apk`
- Exit code `0`
- On x86-64 Windows with working NDK `llvm-strip`, the debug APK size should be normal (~60–120 MB, **not** 1.4 GB).

#### Phase 3 debug APK with Firebase `--dart-define` (when backend is ready)

Create a **gitignored** `dart_defines.json` in `NearPace App/nearpace/` (never commit secrets!):

```json
{
  "FIREBASE_API_KEY": "<your-api-key>",
  "FIREBASE_APP_ID": "<your-android-app-id>",
  "FIREBASE_MESSAGING_SENDER_ID": "<your-sender-id>",
  "FIREBASE_PROJECT_ID": "<your-project-id>",
  "FIREBASE_STORAGE_BUCKET": "<optional-storage-bucket>"
}
```

Then build or run with:

```powershell
flutter build apk --debug --dart-define-from-file=dart_defines.json
```

*(Note: Verify in Phase 3 Stage 1 whether Android FCM also requires placing a gitignored `google-services.json` under `android/app/` and adding the `com.google.gms.google-services` Gradle plugin.)*

### Step 6: Optional install & smoke test on device/emulator

```powershell
flutter devices
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## 4. Distinguishing Environment Failures from Application Build Failures

Use this diagnostic matrix whenever an Android build fails:

| Observed Error / Symptom | Failure Category | Root Cause | Safe Resolution |
| --- | --- | --- | --- |
| `Syntax error: "(" unexpected` or `Exec format error` from `aapt2`, `zipalign`, or `llvm-strip` | **BLOCKED — ENVIRONMENT** | Running x86-64 Android SDK/NDK binaries on an ARM64 (`aarch64`) host | Build on an x86-64 workstation (Windows/Linux/macOS); do not change Gradle or app code |
| `SDK location not found` / `ANDROID_HOME` not set / `No Android SDK found` | **BLOCKED — ENVIRONMENT** | Missing `android/local.properties` or Android SDK path | Set `ANDROID_HOME` or run `flutter pub get` after installing Android Studio SDK |
| `Android license status unknown` / `You have not accepted the license agreements` | **BLOCKED — ENVIRONMENT** | Unaccepted SDK licenses or missing `cmdline-tools` | Install `Android SDK Command-line Tools (latest)` and run `flutter doctor --android-licenses` |
| `Unsupported class file major version` or `Gradle requires JVM 17+` | **BLOCKED — ENVIRONMENT** | Wrong system JDK version (e.g., JDK 8/11) | Point `JAVA_HOME` or `flutter config --jdk-dir` to Android Studio's JBR / JDK 17–21 |
| `Could not resolve all files` / `UnknownHostException` / `Connection timed out` | **BLOCKED — ENVIRONMENT** | Offline machine or firewall blocking Maven Central / Google Maven / pub.dev | Restore network access or use `--offline` only if Gradle & pub caches are already warm |
| `Dart compiler failed` / `Error: The getter '...' isn't defined` | **FAIL — PROJECT** | Application Dart syntax/type defect | Fix Dart code and re-run `flutter analyze` and `flutter test` |
| `Manifest merger failed` / `Duplicate class` / `minSdkVersion ... cannot be smaller than version ... declared in library` | **FAIL — PROJECT** | Plugin or `android/app/build.gradle.kts` / `AndroidManifest.xml` incompatibility | Inspect `build/app/outputs/logs/manifest-merger-debug-report.txt` and adjust Android config deliberately |
| `Execution failed for task ':app:compileDebugKotlin'` | **FAIL — PROJECT** | Kotlin/AGP version mismatch or plugin code error | Check plugin changelog and `android/settings.gradle.kts` plugin versions |
