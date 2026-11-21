# NearPace MVP specification

**Status:** agreed implementation scope for the university Mobile Programming assignment. The six course areas are **provisional** until the lecturer's rubric is supplied; no other mandatory requirement is assumed. Background research notes are kept outside this shared repository; this document does not repeat them.

## Product in one sentence

NearPace records a run on the phone, saves it to the signed-in runner's private history, and optionally shows the runner's weekly distance on a city leaderboard built only from NearPace-owned data.

## Primary flow

1. **Sign up / sign in** with email and password; choose a display name and optional city.
2. **Dashboard** shows this week's runs and distance plus recent activities.
3. **Start run** → grant location permission → acquire GPS fix → record.
4. **Pause / resume**, then **finish**.
5. **Result** shows distance, duration, average pace, a route sketch, and weather at the start point.
6. **Save** writes the activity to the runner's private Firestore collection.
7. **History** lists saved runs; tapping one reopens its result.
8. **Leaderboard** (optional) ranks opted-in runners by this week's distance, filterable by city.
9. **Profile** edits display name/city, controls leaderboard visibility, signs out.

## In scope

| Area | Lean implementation |
| --- | --- |
| Authentication | Firebase Auth email/password; sign up, sign in, sign out, auth-state gate. |
| Private data | `users/{uid}` profile and `users/{uid}/activities/{id}` records, owner-only in Security Rules. |
| Run recording | `geolocator` position stream, foreground recording, pause/resume, distance/pace from filtered points, explicit states. |
| Results | Metrics, route sketch drawn with `CustomPainter` (no map tiles), weather summary. |
| History | Firestore stream of the signed-in runner's activities, newest first, empty/error states. |
| Public API | Open-Meteo current conditions at the run's start point; failure never blocks saving. |
| Push | FCM permission, token storage, topic subscription, foreground in-app banner, console-sent demo notification. |
| Social (optional) | Weekly city leaderboard from a public aggregate document each runner writes for themselves. |
| Profile | Display name, city, leaderboard opt-in, sign out. |

## Explicitly excluded

Strava or any third-party activity import, clubs, events, feeds, messaging, route planning, map tiles, offline map packs, subscriptions/billing, anti-cheat, background recording after the app is killed, Cloud Functions, custom backend, analytics pipelines, CI/CD, and iOS-specific push configuration beyond documented setup.

## Data model

```
users/{uid}
  displayName: string
  email: string
  city: string            // optional, user-entered, used only for leaderboard filtering
  showOnLeaderboard: bool // default false
  fcmToken: string?       // latest device token
  createdAt: timestamp

users/{uid}/activities/{activityId}
  startedAt: timestamp
  endedAt: timestamp
  distanceM: number
  durationS: number
  avgPaceSecPerKm: number?
  route: array<{lat: number, lng: number}>   // capped, simplified
  weather: map?           // temperatureC, code, fetched after save; optional

leaderboard/{weekKey_uid}   // public aggregate, contains no route or email
  uid, displayName, city, weekKey, distanceM, updatedAt
```

`weekKey` is the ISO week start date (`yyyy-MM-dd`, Monday) in the runner's local time. The leaderboard document is rewritten by its owner after a save or opt-in; it is never written by another user.

## Access rules (summary)

- Profile and activities: read/write only by the matching authenticated uid.
- Leaderboard: readable by any signed-in user; writable only by the owner, and only for a document whose id matches `weekKey_uid`.
- Everything else denied.

## Public API choice

**Open-Meteo** forecast API, current conditions (`temperature_2m`, `apparent_temperature`, `weather_code`) for the run's first coordinate. No API key. Attribution shown in the UI. Timeout and failure degrade to "Conditions unavailable" without affecting the run. Terms are checked at integration time; if they change, remove the card rather than adding another provider.

## Success criteria for the demo

- A new account can sign up, record a short outdoor run, save it, see correct metrics, and find it in history after restart.
- A second account cannot read the first account's activities (rules test or emulator evidence).
- Weather loads for the start point, and the screen still works with the network disabled.
- A console-sent FCM message appears while the app is foregrounded; background delivery is documented as requiring device/console setup.
- Leaderboard shows only opted-in runners and no private fields.
- `flutter analyze` and `flutter test` pass; manual checks and blockers are recorded in the requirements matrix.
