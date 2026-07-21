# Color Flask Game

`Color Flask Game` is a SwiftUI iOS puzzle game in the Water Sort genre with a Cozy Potion Shop theme. The player sorts magical liquids between flasks, completes potion orders, earns herbs, and progresses through handcrafted and generated levels.

The project is currently an alpha-ready MVP foundation, not a release-candidate build. Core gameplay, onboarding levels, order objectives, hints, undo, reset, progress persistence, monetization/analytics/crash-reporting boundaries, and test coverage are in place. Final art, real ads, StoreKit, real analytics/crash SDKs, and App Store assets are still future work.

## Project Goals

- Keep the classic Water Sort loop clear and easy to understand.
- Add a distinct Cozy Potion Shop identity through orders, herbs, flasks, and soft feedback.
- Keep monetization optional and non-aggressive.
- Make levels fair: standard levels must be solvable without the locked bonus flask.
- Keep the codebase testable and ready for production hardening.

## Gameplay Summary

Core interaction:

1. Tap a source flask.
2. Tap a target flask.
3. Liquid pours only if the target is empty or has the same top color.
4. A valid pour moves only the contiguous top color group and respects flask capacity.
5. Invalid moves give feedback without changing state.
6. A round is complete when the current objective is solved.

Current level structure:

- Tutorial levels 1-4 teach the basic mechanics with simplified layouts.
- Level 5 introduces herbs, paid hints, and the locked bonus flask.
- Standard levels use 5 filled flasks, 2 available empty flasks, and 1 locked bonus flask.
- Generated levels scale color count, flask capacity, and board size over time.
- Mystery levels start after Level 60 and reveal only the top color.

## Technical Stack

- Swift
- SwiftUI
- Combine
- Swift Concurrency with `Task` and `async/await`
- MVVM-style screen state through `HomeViewModel`
- XCTest
- Xcode project, no Swift Package Manager dependency setup currently required

Minimum target is configured for iOS 17.0.

## Requirements

- macOS with Xcode installed
- iOS Simulator runtime installed through Xcode Settings > Platforms
- Xcode command line tools available:

```bash
xcode-select -p
```

The helper scripts expect an iPhone 15 simulator. `scripts/run.sh` can create one if needed. `scripts/alpha_check.sh` currently targets iPhone 15 / iOS 17.4.

## Getting Started

Clone or open the repository, then run:

```bash
./scripts/run.sh
```

For a clean first-run install:

```bash
./scripts/run.sh --fresh
```

This script:

- finds or creates an iPhone 15 simulator;
- boots the simulator;
- builds the `ColorFlaskGame` scheme;
- installs the app;
- launches it on the simulator.

## Running Tests

Use the alpha readiness script:

```bash
./scripts/alpha_check.sh
```

This runs the test suite through `xcodebuild` on iPhone 15 / iOS 17.4.

Manual equivalent:

```bash
xcodebuild \
  -project ColorFlaskGame.xcodeproj \
  -scheme ColorFlaskGame \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 15,OS=17.4" \
  -derivedDataPath build/DerivedData \
  test
```

## Project Structure

```text
ColorFlaskGame/
  App/
    ColorFlaskGameApp.swift
    AppRootView.swift
  Core/
    Game/
      GameManager.swift
  DesignSystem/
    DesignSystem.swift
    DSButtonStyle.swift
    DSCard.swift
  Features/
    Home/
      HomeView.swift
      HomeViewModel.swift
      HomeLayout.swift
      FlaskTubeView.swift
      PourStreamView.swift
      FlaskProgressView.swift
      GameFeedback.swift
      ProgressStore.swift
  Resources/
    Assets.xcassets/
    Media/
docs/
scripts/
ColorFlaskGameTests/
```

## Architecture Notes

The current architecture keeps gameplay rules and UI state separated enough for alpha iteration:

- `GameManager` and related models own core Water Sort rules, level data, validation, objectives, and hint planning.
- `HomeViewModel` owns UI-facing game flow: selected flask, animation state, hints, undo, reset, completion, herbs, feature flags, and persistence coordination.
- `HomeView` is the main SwiftUI gameplay surface.
- `AppRootView` owns high-level app flow: intro, main menu, and game screen.
- `ProgressStore` abstracts persistence, with `UserDefaultsProgressStore` used for app state.
- `RewardedAdProviding` abstracts rewarded-ad behavior; current implementation is a stub.
- `GameFeatureFlags` gates monetization-related flows so alpha and release behavior can diverge safely.

Important production rule: SDK-specific code should stay behind protocols and must not leak into game rules or SwiftUI views.

## Feature Flags

`GameFeatureFlags.appDefault` selects configuration by build:

- DEBUG builds use `GameFeatureFlags.alpha`;
- release builds use `GameFeatureFlags.production`.

`GameFeatureFlags.alpha` is the local alpha configuration:

- rewarded-ad stubs enabled;
- permanent bonus flask purchase hidden and disabled;
- debug jump-to-level and reset-progress tools enabled.

`GameFeatureFlags.production` hides debug tools and disables monetization stubs until real SDKs are selected.

`GameFeatureFlags.allEnabled` exists for tests and future StoreKit work.

Current monetization state:

- Rewarded ads are stubs.
- Permanent bonus flask unlock is a future IAP path.
- Standard levels must remain solvable without the bonus flask.

## Resources And Assets

Runtime assets live in:

```text
ColorFlaskGame/Resources/Assets.xcassets
```

Editable/source media lives in:

```text
ColorFlaskGame/Resources/Media
```

The media folder is intended for source files such as `.pxo`, images, music, and sound drafts. Runtime-ready assets should be exported into `Assets.xcassets`.

See:

```text
ColorFlaskGame/Resources/Media/README.md
```

## Documentation

Main docs:

- `docs/game-design-brief.md` - game design direction, levels, mechanics, roadmap.
- `docs/product-readiness-brief.md` - MVP/alpha/beta/release readiness and App Store preparation.
- `docs/alpha-test-notes.md` - tester instructions, known limitations, and feedback questions.

## Alpha Test Flow

Recommended fresh-install test:

```bash
./scripts/run.sh --fresh
```

Then verify:

- Intro opens and can be skipped by tap.
- Main Menu shows current order, herbs, reward, sound/haptics toggles, and test level controls.
- Level 1 teaches source and target tapping.
- Level 2 teaches same-color pouring.
- Level 5 grants herbs through the in-game tutorial popup and requires using Hint once.
- Undo, reset, hint, menu return, continue order, win interlude, and level advance work.

Before sharing an alpha build:

```bash
./scripts/alpha_check.sh
./scripts/release_check.sh
```

## Known Limitations

- Real rewarded ads are not integrated.
- StoreKit purchase/restore is not implemented; a purchase-provider boundary exists for the future permanent bonus flask unlock.
- Permanent bonus flask purchase is hidden by default and remains a future feature.
- Real analytics and crash-reporting SDKs are not integrated; no-op protocol boundaries are in place.
- App Store metadata, screenshots, privacy details, and final icon work are not complete.
- Final art direction and production asset export are still in progress.
- Device QA is focused on portrait iPhone layouts, with scaled iPad portrait support started.

## Useful Development Commands

Run the app:

```bash
./scripts/run.sh
```

Run a fresh install:

```bash
./scripts/run.sh --fresh
```

Run alpha tests:

```bash
./scripts/alpha_check.sh
```

Run a Release configuration sanity build:

```bash
./scripts/release_check.sh
```

Inspect changed files:

```bash
git status --short
```

## Troubleshooting

If `xcodebuild` cannot find the simulator:

- Open Xcode.
- Go to Settings > Platforms.
- Install an iOS runtime compatible with the scripts.
- Run `./scripts/run.sh` again.

If simulator services are unavailable from a sandboxed terminal, rerun the command from a normal terminal or grant the required simulator access in the tool asking for permission.

If the app launches with old progress:

```bash
./scripts/run.sh --fresh
```

## Current Status

The project is suitable for structured alpha testing of the core loop. The next product priorities are:

1. Verify Levels 1-10 manually on device and simulator.
2. Decide v1 monetization path: real ads/IAP or no monetization.
3. Expand content and difficulty pacing.
4. Choose and integrate real analytics/crash-reporting SDKs if moving toward beta.
5. Prepare final art, icon, screenshots, and App Store compliance material.
