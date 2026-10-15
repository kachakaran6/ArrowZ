# ArrowZ

**A calm, thoughtful arrow-escape puzzle game.** Untangle the board, find the right order, and clear every arrow with one tap at a time.

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.arrowz.app"><img src="https://img.shields.io/badge/Google_Play-Download-414141?style=for-the-badge&logo=googleplay&logoColor=white" alt="Get ArrowZ on Google Play"></a>
  <a href="https://github.com/kachakaran6/ArrowZ"><img src="https://img.shields.io/badge/Platform-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Built with Flutter"></a>
  <img src="https://img.shields.io/badge/Package-com.arrowz.app-555555?style=for-the-badge" alt="Android package">
</p>

---

## Overview

ArrowZ is a relaxing yet challenging logic puzzle for players who enjoy planning, spatial reasoning, and satisfying visual feedback. The board is filled with arrows pointing in different directions. An arrow can leave the board only when its route is clear, so the order in which you remove arrows matters.

Tap an arrow, read the board, and work out what must move first. Each successful move opens new paths and brings you closer to an empty board.

- **Easy to understand:** tap an arrow to try to release it.
- **A puzzle of order:** blocked paths encourage you to think several moves ahead.
- **Designed for short sessions:** play a level whenever you have a quiet moment.
- **Offline-first experience:** core puzzle play and bundled level data are designed to work locally, without a game account or a game backend.
- **Built with Flutter:** a custom-rendered board, deliberate motion, and responsive touch interactions.

**Play on Android:** [ArrowZ on Google Play](https://play.google.com/store/apps/details?id=com.arrowz.app)

## How to Play

1. **Inspect the arrows.** Each arrow points toward its exit direction.
2. **Find a clear path.** An arrow can be removed when its route out of the board is unobstructed.
3. **Tap to release.** Select an arrow and watch its path play out.
4. **Use the space you create.** Removing one arrow can unblock another.
5. **Clear the board.** Keep choosing carefully until the level is complete.

If an arrow is blocked, look for the arrow or sequence that needs to move first. The challenge is not just identifying a possible move; it is choosing a useful order.

## Features

The repository includes the following game systems and supporting screens:

- **Arrow puzzle engine** — board state, arrow directions, path checks, occupancy, and move validity.
- **Animated arrow extraction** — dedicated extraction and thread-animation systems for movement and feedback.
- **Level progression** — bundled JSON level data organised into chapter files.
- **Hints and lives** — gameplay assistance and life-state UI.
- **Level selection** — browse available levels and progression.
- **Progress persistence** — locally stored player progress and snapshots.
- **Statistics and streaks** — supporting repositories and screens for play history and streak tracking.
- **Settings and themes** — theme selection, design tokens, and typography built around Manrope and Newsreader.
- **Audio feedback** — bundled sound assets and an audio service.
- **Haptic feedback** — platform haptics service for tactile responses.
- **Rewarded-ad integration** — Google Mobile Ads service for supported rewarded flows.
- **Local notifications** — notification service for supported reminders.
- **Google Play integrations** — in-app update and review support on compatible Android devices.
- **Diagnostics and developer tools** — diagnostic overlays and an animation lab for development.
- **Automated tests** — unit, widget, engine, persistence, interaction, and visual-system tests.

> The availability of platform-specific features can depend on the device, operating system, Google Play availability, and the current app configuration. The project is offline-first for core puzzle play; ads, store updates, reviews, and notifications are platform integrations and may require platform services or permissions.

## Screens and Game Systems

The codebase is organised around focused features rather than putting the entire game into a single screen.

| Area | Responsibility |
| --- | --- |
| Home | Main lobby and entry points into the game |
| Game | Board rendering, input, move handling, lives, hints, and completion/failure flows |
| Levels | Level browsing and progression |
| Settings | Player preferences and app settings |
| Themes | Theme selection and shared design tokens |
| Statistics | Progress-related statistics |
| Streaks | Streak tracking and related UI |
| How to play | Instructions and gameplay guidance |
| Diagnostics | Developer-facing diagnostics and animation tools |

## Technology Stack

| Technology | Purpose |
| --- | --- |
| [Flutter](https://flutter.dev/) | Cross-platform application UI and rendering |
| [Dart](https://dart.dev/) | Application and puzzle-engine language |
| [Riverpod](https://riverpod.dev/) | State management and dependency injection |
| [go_router](https://pub.dev/packages/go_router) | App navigation |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | Local preference and lightweight state persistence |
| [audioplayers](https://pub.dev/packages/audioplayers) | Sound playback |
| [google_mobile_ads](https://pub.dev/packages/google_mobile_ads) | Google Mobile Ads integration |
| [in_app_update](https://pub.dev/packages/in_app_update) | In-app update support |
| [in_app_review](https://pub.dev/packages/in_app_review) | Native in-app review prompts |
| [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) | Local notifications |
| [timezone](https://pub.dev/packages/timezone) | Time-zone support for notification scheduling |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | Installed app metadata |
| [flutter_test](https://docs.flutter.dev/testing) | Unit and widget testing |
| [integration_test](https://docs.flutter.dev/testing/integration-tests) | Integration testing support |

The declared Dart SDK constraint is `^3.5.0`. Dependency versions are maintained in [pubspec.yaml](pubspec.yaml).

## Project Structure

A high-level map of the important files and directories:

```text
ArrowZ/
├── android/                   # Android host project and native Play helpers
├── assets/
│   ├── audio/                 # Bundled sound effects and audio licences
│   ├── fonts/                 # Manrope and Newsreader font assets
│   ├── levels/                # Bundled chapter and level JSON data
│   └── icon.png               # App icon source
├── lib/
│   ├── data/                  # Level, progress, settings, snapshot and streak data
│   ├── design/                # Design tokens, themes, typography and primitives
│   ├── diagnostics/           # Diagnostics and developer overlays
│   ├── engine/                # Board model, directions, path logic, solver and validity
│   ├── features/
│   │   ├── dev/               # Animation lab
│   │   ├── game/              # Board, controller, game state, hints and game sheets
│   │   ├── home/              # Main lobby
│   │   ├── howto/             # Gameplay instructions
│   │   ├── levels/             # Level selection
│   │   ├── settings/          # Settings and theme picker
│   │   ├── splash/            # Startup screen
│   │   ├── stats/             # Statistics
│   │   └── streak/             # Streak features
│   ├── platform/              # Audio, ads, haptics, notifications and Play services
│   ├── router/                # Routes, transitions and navigation
│   ├── app.dart               # App composition
│   └── main.dart              # Application entry point and service setup
├── test/                      # Unit, widget and interaction tests
├── Implementation.md          # Product and implementation specification
├── analysis_options.yaml      # Dart lint configuration
└── pubspec.yaml               # Package metadata, dependencies and assets
```

This is a guide to the main areas, not an exhaustive listing of every source file.

## Getting Started

### Prerequisites

Install the following before running the project:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart support.
- [Git](https://git-scm.com/downloads).
- Android Studio with Android SDK tools, or another supported Flutter development environment.
- An Android emulator or a physical Android device for Android testing.

Check your environment:

```bash
flutter doctor
```

### Clone and Run

```bash
git clone https://github.com/kachakaran6/ArrowZ.git
cd ArrowZ
flutter pub get
flutter run
```

If more than one device is available, list the available targets and select one:

```bash
flutter devices
flutter run -d <device-id>
```

Replace `<device-id>` with an ID printed by `flutter devices`.

### Run Static Analysis and Tests

Run these commands from the repository root:

```bash
flutter analyze
flutter test
```

The project also declares Flutter integration-test support. Integration tests may require a running emulator or a connected device and should be run using the Flutter integration-test workflow appropriate to your environment.

### Build Android Releases

Build a release APK for direct installation/testing:

```bash
flutter build apk --release
```

Build an Android App Bundle for Google Play distribution:

```bash
flutter build appbundle --release
```

Typical output locations:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

Release builds may require Android signing configuration. Keep signing keys, passwords, API keys, and other secrets out of source control.

## Architecture Notes

ArrowZ separates puzzle rules from UI and platform-specific integrations:

- **Engine layer (`lib/engine/`)** models the board, cells, directions, threads, move validity, path extraction, and solving logic.
- **Game feature (`lib/features/game/`)** coordinates player input, game state, board rendering, animations, hints, lives, and game outcome sheets.
- **Data layer (`lib/data/`)** loads level data and stores progress, settings, snapshots, and streak information.
- **Design layer (`lib/design/`)** centralises theme definitions, component tokens, typography, and reusable UI primitives.
- **Platform layer (`lib/platform/`)** isolates audio, haptics, ads, notifications, in-app updates, and in-app review integrations.
- **Navigation layer (`lib/router/`)** defines routes and transitions.
- **Riverpod** is used to wire state and services into the Flutter widget tree.

Level content is bundled under `assets/levels/`; the repository includes chapter JSON files and a level report. This allows the app to package puzzle data with the application rather than depend on a remote level server.

## Testing Guide

Before submitting a change, use the following checklist:

- [ ] `flutter pub get` completes successfully.
- [ ] `flutter analyze` completes without new analysis errors.
- [ ] `flutter test` passes.
- [ ] The app launches on an Android emulator or physical device.
- [ ] A level can be started, arrows can be tapped, and blocked moves provide feedback.
- [ ] Successful moves update the board correctly and a completed board reaches the completion flow.
- [ ] Level progression and saved progress behave as expected after restarting the app.
- [ ] Settings and theme changes are reflected correctly.
- [ ] Audio and haptic settings/behaviour are checked on a real device where possible.
- [ ] Platform integrations are tested only in the appropriate supported environment.

## Contributing

Contributions, bug reports, and focused improvements are welcome.

1. Fork the repository.
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-change
   ```
3. Make the change and add or update tests where appropriate.
4. Run analysis and tests:
   ```bash
   flutter analyze
   flutter test
   ```
5. Commit with a clear message:
   ```bash
   git add .
   git commit -m "Describe your change"
   ```
6. Push your branch and open a pull request.

For gameplay or engine changes, include the expected behaviour, edge cases considered, and test coverage. For UI changes, include screenshots or a short recording when useful.

## Reporting Bugs

Please use [GitHub Issues](https://github.com/kachakaran6/ArrowZ/issues) to report reproducible bugs or request improvements.

When reporting a bug, include:

- Device and operating-system version.
- Flutter version (`flutter --version`).
- Steps to reproduce the problem.
- Expected behaviour and actual behaviour.
- Screenshots, screen recordings, or relevant logs where possible.

Do not include private user data, signing keys, credentials, or other secrets in an issue.

## Privacy and Network Behaviour

ArrowZ is designed around local puzzle play and locally stored progress. The repository also contains optional or platform-dependent integrations, including rewarded ads, Google Play update/review flows, and local notifications. These integrations may communicate with their respective platform services.

For the app's current privacy practices and disclosures, refer to the privacy information provided with the published app. Do not infer that every integration is disabled simply because core gameplay works offline.

## Project Specification

The repository includes [Implementation.md](Implementation.md), which records product intent, design principles, architecture decisions, and implementation details. It is useful background for contributors, but the running code and current tests are the source of truth for implemented behaviour.

## Links

- **Google Play:** https://play.google.com/store/apps/details?id=com.arrowz.app
- **Source code:** https://github.com/kachakaran6/ArrowZ
- **Issues and bug reports:** https://github.com/kachakaran6/ArrowZ/issues
- **Flutter documentation:** https://docs.flutter.dev/
- **Dart documentation:** https://dart.dev/guides

## License

No repository-wide open-source license was confirmed while preparing this README. Unless a license is added to the repository, all rights remain with the applicable copyright holder and reuse should not be assumed to be permitted. Check the repository for licensing information before redistributing or reusing code or assets.

---

<p align="center">
  <strong>ArrowZ</strong><br>
  Think clearly. Find the path. Let every arrow go.
</p>
