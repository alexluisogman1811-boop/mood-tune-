# MoodScape

MoodScape makes **playlists for every moment**: music that fits **what you
are doing**, **how you feel** and **what's around you**. You choose an activity
(gym, running, party, tidying up, driving, commuting, cooking, chilling,
working, studying, reading, falling asleep), can take a photo of
your surroundings (optional), say how you feel, and set your listening
preferences. MoodScape then ranks songs with a transparent
match score and explains each match. Songs open in Spotify or Apple Music and
can be saved to a playlist.

> The photo describes the *environment* (light, colour, weather, atmosphere).
> MoodScape never tries to read emotions from images. Your feelings are
> whatever you tell it. Match scores estimate how well a song fits; they are
> not a scientific measure of emotion.

The app is available in **English and Thai (ไทย)**: it follows the phone's
language, and the ไทย/English button on the Welcome screen or **Settings ›
Language** switches it.

## Use it now: one link for iPhone and Android

**https://alexluisogman1811-boop.github.io/moodscape/**

Open the link in **Safari** (iPhone) or **Chrome** (Android), then:
- **iPhone:** tap Share › **Add to Home Screen**.
- **Android:** tap ⋮ › **Add to Home screen** (or **Install app**).

MoodScape then opens full-screen from its own icon, like a normal app. No
store, APK or IPA is needed, so it isn't affected by Android's 2026
developer-verification rules or iOS signing.

**Web version differences:** the browser asks before using the camera;
photos are analysed in the browser and never uploaded. Apple Music
sign-in isn't available on the web, but "Open in Spotify/Apple Music"
works everywhere.

**Publishing an update:** the site is the built app in the public repo
`alexluisogman1811-boop/moodscape` (built files only; this source repo
stays private). To update it, build the app:

```bash
flutter build web --release --base-href /moodscape/
```

Then copy `build/web/` into that repo (keep its `.nojekyll` file), commit
and push. GitHub Pages republishes within a minute or two.

- Flutter 3.47 (stable), Dart 3.13, built and tested on Windows with VS Code
- Riverpod 3, GoRouter 18, Dio, flutter_secure_storage, SharedPreferences,
  camera, image_picker, url_launcher, flutter_web_auth_2, just_audio
- Material components come from the `material_ui` package. Flutter 3.47
  moved Material out of the core SDK.

---

## 1. Set up a Windows development machine

### Flutter SDK
1. Install **Git for Windows** (https://git-scm.com/download/win). The
   `flutter` and `dart` scripts call `git`; without it, `dart.bat` fails with
   *"Unable to determine engine version"*.
2. Download the Flutter SDK zip for Windows from https://docs.flutter.dev and
   extract it to a short path without spaces, e.g. `C:\src\flutter`.
3. Add `C:\src\flutter\bin` to your user `PATH`, then open a new terminal.

### VS Code
Install the **Dart** and **Flutter** extensions (`Dart-Code.dart-code`,
`Dart-Code.flutter`).

### Check the toolchain

```bash
flutter doctor -v
```

### Android
1. Install **Android Studio**. In *SDK Manager*, install an Android SDK
   platform, **Android SDK Command-line Tools (latest)** and
   **Android SDK Build-Tools**.
2. Accept the SDK licences:

```bash
flutter doctor --android-licenses
```

3. **Emulator:** in Android Studio, open *Device Manager*, create a device
   (for example a Pixel with a recent system image) and start it. MoodScape's
   camera works with the emulator's virtual scene camera; choosing from the
   gallery works too.
4. **Physical device:** enable *Developer options* and *USB debugging* on the
   phone, connect it by USB and accept the prompt. Check that it's visible:

```bash
flutter devices
```

### iOS
iOS apps can only be built on **macOS with Xcode**. The standard
Flutter/Xcode toolchain can't build or sign them on Windows. Your options:
- a Mac with Xcode (plus CocoaPods or Swift Package Manager), or
- a hosted macOS build service (e.g. a macOS CI runner).

MusicKit doesn't work in the iOS Simulator, so test Apple Music on a real
device.

### iPhone without paying (sideloading from Windows)
This project's GitHub Actions build produces an **unsigned
`MoodScape-unsigned.ipa`** on every push to `main`. You can sign and
install it with a **free Apple ID** using a sideloading tool:

1. **Download the .ipa.** On GitHub, open the repository › **Actions** ›
   the latest green **CI** run › **Artifacts** ›
   `MoodScape-unsigned-ipa`. You get a zip; extract it to find
   `MoodScape-unsigned.ipa`. Artifacts are kept for 7 days; push again or
   re-run the workflow for a fresh one.
2. **Install Sideloadly** from its official site (sideloadly.io). It needs
   Apple's iTunes and iCloud for Windows; follow Sideloadly's setup
   page for the right versions.
3. **Connect the iPhone** by USB, unlock it and tap **Trust** on the
   phone.
4. In Sideloadly, drop in the `.ipa`, enter your Apple ID and click
   **Start**. Your Apple ID password goes only to Apple, through
   Sideloadly; consider using a secondary Apple ID.
5. **On the iPhone:**
   - **Settings › General › VPN & Device Management** → trust your Apple
     ID's developer profile.
   - On iOS 16 and later, enable **Settings › Privacy & Security ›
     Developer Mode** and restart when asked.

**Limits of the free route:**
- The app stops opening after **7 days**. Sideload it again, or use
  AltStore (altstore.io), which can refresh it automatically over Wi-Fi.
- A free Apple ID can have at most 3 sideloaded apps.
- **Apple Music sign-in and playlist saving don't work.** MusicKit
  requires Apple's paid Developer Program. The app falls back to the demo
  catalogue and explains why. "Open in Apple Music/Spotify" links work.

### Keep the project path short
Native-asset build hooks can fail on Windows with
`Failed to canonicalize path … OS error 122` when the project lives in a very
deep folder. Keep the project in a short path, or enable Windows long-path
support.

---

## 2. Run, analyse and test

From the project folder:

```bash
flutter pub get
```

```bash
dart format .
```

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter run
```

Run with your configuration file (see section 3):

```bash
flutter run --dart-define-from-file=config/dev.json
```

Build an Android APK:

```bash
flutter build apk --debug --dart-define-from-file=config/dev.json
```

Build a release APK to install on your own phone:

```bash
flutter build apk --release
```

The release build is currently signed with the debug key, which is fine
for sideloading but not for the Google Play Store. Before publishing,
create an upload keystore and configure `signingConfigs` in
`android/app/build.gradle.kts`, keeping the keystore and its passwords out
of Git.

The app icon is generated from `tool/generate_icon.dart`:

```bash
dart run tool/generate_icon.dart
```

```bash
dart run flutter_launcher_icons
```

After regenerating, revert any change the icon tool makes to
`ios/Runner.xcodeproj/project.pbxproj`: it rewrites an unrelated build
setting to an invalid value.

Run the end-to-end test on a connected device or emulator. It drives the
real app from Welcome to Settings using in-memory storage, so it never
touches data from manual use of the app:

```bash
flutter test integration_test -d <device-id>
```

In VS Code, pick a configuration in *Run and Debug*. They're defined in
`.vscode/launch.json`:
- **demo mode** runs with no configuration.
- **with config/dev.json** uses your real settings.

---

## 3. Configuration and credentials

MoodScape reads **public** identifiers at build time. Copy the template and
fill in only what you use:

```bash
copy config\dev.example.json config\dev.json
```

| Key | Purpose | Without it |
| --- | --- | --- |
| `SPOTIFY_CLIENT_ID` | Spotify app client ID (public, used with PKCE) | Spotify shows setup help |
| `SPOTIFY_REDIRECT_URI` | Must be `moodscape://spotify-callback` | – |
| `ANALYSIS_BACKEND_URL` | HTTPS image-analysis service | On-device analysis only |
| `APPLE_MUSIC_DEVELOPER_TOKEN_URL` | HTTPS token service (Android/other) | iOS uses MusicKit; elsewhere Apple Music is unavailable |

`config/*.json` is git-ignored, except the example file. **Never put secret
keys in this file**: anything compiled into an app can be extracted. Secrets
belong on a server. The server contracts are in [docs/backend.md](docs/backend.md).

### Spotify
1. Create an app at https://developer.spotify.com/dashboard and select
   **Web API**.
2. Add the redirect URI **`moodscape://spotify-callback`**. Custom schemes
   are still allowed for mobile apps, but `http://localhost` is not.
3. Copy the **Client ID** into `config/dev.json`. No client secret is used:
   sign-in is Authorization Code with **PKCE**.
4. **Development Mode limits (2026):** the app owner needs Spotify Premium,
   and only users added under *User Management* can sign in (5 for new
   apps). Wider use requires Spotify's extended quota review.
5. What MoodScape uses:
   - `GET /search` (max 10 results per page)
   - `POST /me/playlists`
   - `POST /playlists/{id}/items`
   - scopes `playlist-modify-private` and `playlist-modify-public`
6. **Not available to new apps:** Recommendations, Audio Features, Related
   Artists and preview URLs. MoodScape therefore estimates mood fit from the
   search words that found each song and says so in the app.

### Apple Music
1. In the Apple Developer portal (*Certificates, Identifiers & Profiles*),
   open the app's identifier (`com.moodscape.moodscape` by default; change it
   to your own) and enable the **MusicKit** App Service. iOS can then
   generate developer tokens with no key in the app.
2. `NSAppleMusicUsageDescription` is already in `ios/Runner/Info.plist`.
3. **Catalogue search** works with just a developer token.
   **Saving playlists** needs the user's permission (MusicKit) and usually
   an active Apple Music subscription. The app shows the subscription
   status.
4. **Android:** there is no native MusicKit bridge. With
   `APPLE_MUSIC_DEVELOPER_TOKEN_URL` set, catalogue search and "Open in Apple
   Music" work; saving to the library is iOS-only.

### Native configuration already in place
- **Android** (`android/app/src/main/AndroidManifest.xml`):
  - `INTERNET`, and an optional camera feature (`required="false"`)
  - the camera plugin's `RECORD_AUDIO` permission removed (no audio is
    recorded)
  - `CallbackActivity` for the `moodscape://` redirect
  - an https `<queries>` entry
- **iOS** (`ios/Runner/Info.plist`):
  - camera, photo library and microphone usage descriptions (the camera
    plugin requires the microphone one; no audio is recorded)
  - `NSAppleMusicUsageDescription`
  - the MusicKit bridge lives in `ios/Runner/AppDelegate.swift`
    (channel `moodscape/musickit`)

---

## 4. How it works

### Flow
Welcome → Activity → Capture (optional) → Mood → Preferences (skippable) → Platform
(skippable) → Atmosphere analysis → Results → Track details. Settings and
Privacy are reachable from Welcome and Results.

### Match score
The scorer lives in `lib/features/recommendations/domain/match_scorer.dart`:

```
matchScore = moodMatch·0.40 + atmosphereMatch·0.25 + preferenceMatch·0.20 + energyMatch·0.15
```

- Every component is on a 0–100 scale, and so is the final score.
- **Missing information is never counted as zero.** Components that can't be
  computed are dropped, and the remaining weights are rescaled to sum to 1.
  For example, with no photo and no preferences, mood carries 100% of the
  weight. If nothing can be computed, the score is a neutral 50. The weights
  are configurable (`MatchWeights`).
- **Mood:** each mood is a point on a valence/energy plane, and intensity
  moves it further from neutral. A track's score blends its best-matching
  mood (70%) with its average over all selected moods (30%), so conflicting
  moods are handled gracefully.
- **Atmosphere:** compares the scene's energy with the track's energy and
  counts shared atmosphere and weather tags. The result is pulled toward 50
  in proportion to how unsure the analysis was.
- **Preferences:** genre, language, vocals, and familiar-or-new; only the
  checks the track's metadata supports are used.
- **Energy:** distance from the requested relaxing (25), balanced (50) or
  energetic (80) target. With no requested energy, the energy that suits
  the activity is used (falling asleep 10, studying and reading 25, chilling
  30, working 40, something else 45, commuting and cooking 55, driving 65,
  tidying up 75, running 85, gym and party 90).
- **Activity:** for working, studying, reading and falling asleep, songs
  without lyrics are favoured (words in the music compete for attention). This counts as a preference check
  unless the user picked a vocals preference or song languages themselves.
- **Languages:** choosing song languages is a filter: only songs sung in
  those languages are shown (songs whose language a service does not
  report are kept). The built-in catalogue is built by `tool/build_catalog.py`:
  it collects free Apple Music charts and Deezer playlists per language,
  analyses each 30-second preview with librosa (loudness, brightness,
  tempo, onsets, major/minor key) into energy and valence estimates, deletes
  the audio, and stores only the numbers. Re-run it with
  `py tool/build_catalog.py` after `py -m pip install --user librosa
  soundfile requests`.

Each result shows a plain-language explanation. The track details screen
shows each component's score and the weight it was given.

### Languages
UI text is written in English in the code and wrapped in `context.tr(...)`;
Thai versions live in `lib/core/l10n/thai.dart`, keyed by the English text,
with `{name}` placeholders. Match explanations are stored as data
(`MatchReason`) and worded in the current language when shown.
`test/unit/translations_test.dart` fails if any translated text lacks a Thai
entry or a placeholder differs, and the accessibility tests run every screen
in Thai too.

### Feedback
After a day of use the results screen invites people to rate the app
(Settings › Feedback always works). Answers are anonymous and go to a Google
Sheet through a free Apps Script web app that also serves a password-protected
admin dashboard; see `tool/feedback_backend/README.md`. Release builds pass
the web app URL with `--dart-define-from-file=config/prod.json`
(`{"FEEDBACK_URL": "https://script.google.com/macros/s/…/exec"}`, not committed).

### Accounts and plans
When `FIREBASE_*` values are set, people sign in with email and password
(Firebase Authentication) and each account has a record in Firestore
(`users/{uid}`: email, plan, premiumUntil, today's playlist count). Without
them (development builds) everything is unlocked and no sign-in is shown.

| Plan | Price | What you get |
|---|---|---|
| Free | $0 | 3 playlists a day, 10 songs, no photo analysis |
| Monthly | $2.99 (≈109 ฿) | Premium for 30 days |
| Yearly | $24.99 (≈899 ฿) | Premium for 365 days |
| Lifetime | $39.99 (≈1,449 ฿) | Premium forever |

Premium = unlimited playlists, photo analysis, 20/30-song playlists.
Payment is manual: the buyer pays (details over Facebook Messenger, `MESSENGER_URL`, or the text in
`PAYMENT_INFO`), sends the slip with their account email, and an admin
(a verified email in `ADMIN_EMAILS`) opens Account › Admin dashboard and gives
the plan. `firestore.rules` enforces the same: users can create only a Free
record and can only count playlists; only admins can change plans or list users.

Rules tests run against the local Firebase emulator (needs Node and Java 21):
`cd tool/firestore_rules_test && npm install && npm test`.
A web build that talks to the emulator: `flutter build web
--dart-define-from-file=config/emulator.json` (with `USE_FIREBASE_EMULATORS: true`).

The sales page is a static file, `web_sales/index.html` (Thai/English), published
next to the web app at `/moodscape/buy/`.
### "Not for me"
Every song has a 👎 **Not for me** button, on its card and on the details
screen. Tapping it:
1. removes the song and fills its place with the best-scoring song not
   already shown;
2. remembers the dislike on the device, so the song is never suggested
   again, including after **New picks** (refresh) and app restarts;
3. if a playlist was saved this session, updates it: on **Spotify**, the
   song is removed and the replacement added. Apple Music's API can't
   remove songs from playlists, so the app says to remove it in the Music
   app;
4. offers **Undo**.

Settings › *Forget disliked songs* clears the list.

### Where songs come from
| Source | When | Feature quality |
| --- | --- | --- |
| Built-in catalogue (`assets/demo/demo_catalog.json`) | No service connected, or a service failed | Real songs; features measured from 30-second previews by `tool/build_catalog.py` (or estimated by hand for the original 188), labelled as estimates |
| Spotify search | Spotify chosen and connected | Real metadata; mood features estimated from search words |
| Apple Music catalogue | Apple Music chosen and a developer token available | Real metadata incl. genres and previews; mood features estimated |

If a connected service fails, results fall back to the demo catalogue and the
app says why.

### Architecture

```
lib/
  app/            app widget, router, theme
  core/           configuration, errors (+ redacting error reporter), network,
                  privacy (upload consent), storage providers
  features/       onboarding, camera, mood, preferences, atmosphere,
                  music_platform, recommendations, settings
                  (each split into domain / application / data / presentation)
  services/       image_analysis, spotify, apple_music (external integrations)
  shared/widgets/ reusable UI
test/
  unit/           scoring, validation, auth, API clients, storage, redaction
  widget/         every screen's key behaviour
```

---

## 5. Privacy and security
- Camera and photo permissions are requested only on the Capture screen, and
  every step works without a photo.
- Photos are resized to at most 1024 px, re-encoded (which strips EXIF
  location data) and kept **in memory only**.
- Uploading a photo for AI analysis needs explicit consent. Users can choose
  *Ask each time*, *Allow* or *Never* in Settings.
- The free-text mood description never leaves the device.
- Spotify tokens and the Apple Music user token are stored in the
  Keychain/Keystore via flutter_secure_storage.
  - Spotify token refresh is single-flight, so concurrent requests can't race
    and invalidate a rotated refresh token.
  - Revoked tokens are deleted and the user is asked to reconnect.
- Every network call uses HTTPS. External responses are validated before
  use.
- There is no logging of request bodies. Uncaught errors go through
  `ErrorReporter`, which redacts bearer tokens, user tokens and OAuth fields,
  and prints only in debug builds.
- **Settings › Clear all data** removes preferences, consent choices, tokens,
  the photo and the mood.

---

## 6. Current status and known limitations
- Verified on Windows: `flutter analyze` (no issues), `flutter test` (all
  unit and widget tests) and `flutter build apk --debug` (succeeds).
- The debug APK was installed on an Android 17 (API 37) emulator. It
  launched without errors, and the Capture screen showed a live CameraX
  preview.
- The end-to-end test (`integration_test/app_flow_test.dart`) **passes on
  a physical Galaxy S22 Ultra (SM-S908E)**. It covers Welcome → skip photo
  → moods → preferences → platform → atmosphere → results (ranking,
  filter) → track details (open-in link) → Settings › Clear all data.
- On the development PC the Android emulator (37.2.12, API 37 image,
  software rendering) repeatedly crashed (`qemu-system-x86_64.exe` access
  violation), so use a physical device or another emulator image for
  device tests.
- Samsung phones: if `adb devices` shows nothing even though USB debugging
  is on, turn off **Auto Blocker**, then reconnect and accept the
  debugging prompt.
- `flutter_web_auth_2` 5.1.0 applies the Kotlin Gradle Plugin. Today this
  is only a build warning, but future Flutter versions will reject it, so
  upgrade the plugin when a Built-in Kotlin version is released.
- The camera plugin requests `WRITE_EXTERNAL_STORAGE` (Android ≤ 9 only),
  which makes the build tools add an implied `READ_EXTERNAL_STORAGE`. This
  was left in place because old devices that would need it weren't tested.
- GitHub Actions (`.github/workflows/ci.yml`) runs on every push to `main`:
  formatting, analyze and all tests on Linux; the **end-to-end test on an
  Android API 34 emulator**; and an **unsigned iOS build on macOS** that
  compiles the whole iOS app, including the Swift MusicKit bridge. All
  three pass. The iOS app hasn't run on an iPhone yet:
  that needs an Apple Developer account for signing, and Apple Music
  features need a real device.
- Neither Spotify nor Apple Music has been exercised with real credentials
  in this environment.
- Android builds need the SDK command-line tools and accepted licences (see
  `flutter doctor`).
- Spotify Development Mode limits only allow-listed accounts to sign in.
- Song previews play inside the app (just_audio, HTTPS only) when the
  service provides one: Apple Music does; Spotify no longer gives previews
  to new apps and the demo catalogue has none. In-app playback is covered
  by widget tests but has not yet been heard on a device, because that
  needs Apple Music configured.
