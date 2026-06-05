# ColorFlaskGame Product Readiness Brief

Date: 2026-05-31
Owner perspective: Product Management for Cozy Potion Shop Water Sort
Scope: functional product readiness, team ownership, MVP/alpha/beta/release path, App Store preparation.

This brief intentionally does not review pixel-perfect UI, text alignment, font tuning, or visual polish minutiae. The goal is to define what must be true for the game to become a complete, testable, shippable iOS product.

## Product Snapshot

ColorFlaskGame is a SwiftUI iOS Water Sort puzzle game with a Cozy Potion Shop wrapper. The current product direction is strong for a small-scope casual puzzle game: short sessions, calm tone, low-pressure monetization, and a clear sorting mechanic.

Current implemented or documented strengths:

- Core Water Sort interaction exists: tap source flask, tap target flask, validate move, pour, complete board.
- Level model exists with handcrafted early levels and deterministic generated levels after the handcrafted pool.
- Solvability validation exists for levels without relying on the locked bonus flask.
- Undo, hint, reset, locked bonus flask, herbs reward, order banner, tutorial prompt, win interlude, and progress persistence are present at product-concept level.
- Rewarded ad and permanent bonus flask flows are currently stubs, which is correct for alpha but not release.
- Unit tests exist around game logic, home view model behavior, and layout.
- Alpha test notes already define the main loop to test and expected tester questions.

Current product maturity: alpha-capable foundation, not yet beta-ready, not App Store-ready.

The biggest product gap is not the basic mechanic. The biggest gap is release completeness: real monetization decisions, content volume, analytics/crash visibility, App Store compliance assets, device QA, and final retention/economy validation.

## Readiness Definitions

### MVP

MVP means the game can prove that the core loop is understandable and fun without needing full economy, store, or final art.

MVP is ready when:

- Player can start Level 1 and complete at least the first 10 levels.
- Core rules are clear without a long tutorial.
- Invalid moves give soft feedback and do not break state.
- Undo works reliably after valid moves.
- Hint shows a useful source and target without auto-playing.
- Locked bonus flask appears only when intended and remains optional.
- Progress is saved and the next level loads correctly.
- Reset/new game flows are safe and intentional.
- Basic tests pass through `scripts/alpha_check.sh`.

Current status: close to MVP, assuming the existing implementation passes the alpha check on target simulators.

### Alpha

Alpha means the game is playable by a small internal/external test group to validate clarity, difficulty, and first-session interest.

Alpha is ready when:

- MVP criteria are met.
- First 10 levels are handcrafted and reviewed for teaching progression.
- Levels after the handcrafted pool are generated or selected through solvability validation.
- Testers can play Levels 1-5 without developer guidance.
- Rewarded ads and IAP can remain stubs, but all stubbed flows must be visibly labeled internally and must not be submitted as real monetization.
- Known limitations are documented.
- Alpha feedback form/questions are available.
- Build can be distributed through TestFlight or local simulator/device install.

Current status: alpha-ready candidate after build/test verification.

### Beta

Beta means the game should behave like a near-final product, with real service decisions made and enough content to measure retention signals.

Beta is ready when:

- Real rewarded ads are either integrated and consent-compliant, or removed/disabled for beta.
- IAP is either implemented through StoreKit with sandbox testing, or all permanent purchase UI is removed/hidden.
- Content plan covers at least 50-100 playable levels with stable difficulty pacing.
- Analytics events and crash reporting are integrated and privacy-reviewed.
- Device QA covers multiple iPhone sizes and relevant iOS versions.
- App icon, launch screen, screenshots, and store metadata have near-final versions.
- No debug/test reset actions are exposed to normal players unless intentionally designed.
- QA has a regression checklist and a known-issues list.

Current status: not beta-ready.

### Release Candidate

Release candidate means the build is intended for App Store submission unless a blocker is found.

RC is ready when:

- All beta criteria are met.
- No placeholder art, placeholder monetization, or debug-only product flows remain visible to users.
- Privacy manifest, tracking/consent behavior, App Store privacy labels, and third-party SDK declarations are complete.
- Age rating inputs are reviewed.
- TestFlight smoke test passes on clean install and upgrade install.
- App Review notes explain any optional rewarded ad/IAP behavior.
- Product metadata, screenshots, preview video if used, keywords, subtitle, and support URL are ready.
- Crash-free internal TestFlight run is acceptable for the planned launch risk.

Current status: not release-candidate ready.

## Functional Gaps

### Product And Game Loop

- Need a clear decision on whether the first public version includes only level progression or also shop meta.
- Need enough level content to avoid the game feeling like a prototype after the first session.
- Need difficulty pacing review beyond the first 10 levels.
- Need explicit fail-safe rules for generated levels: solvable, reasonable minimum move count, no forced bonus flask, no color readability traps.
- Need final behavior for returning to menu, continuing current order, starting new game, and resetting progress.
- Need define whether orders are pure flavor or mechanically distinct objectives.

### Monetization

- Rewarded ads are currently stubs. Release requires either real SDK integration or removal/disablement.
- Permanent bonus flask unlock is a future IAP stub. Release requires StoreKit implementation, sandbox QA, restore purchases, and App Store metadata, or the flow should be hidden.
- Bonus flask must remain convenience-only, never required to solve normal levels.
- Hint economy needs balance validation: free first hint, herb cost, ad fallback, and reward rate.

### Retention And Progression

- Herbs exist, but their long-term role is limited. Decide whether herbs are only hint currency for v1 or become shop upgrade currency later.
- Need a lightweight milestone structure: first order complete, chapter markers, or new potion sets.
- Daily rewards, achievements, customers, and shop upgrades should stay post-v1 unless they directly improve retention in testing.
- Future customization can add unlockable backgrounds, UI color palettes, and flask styles every 20 or 50 levels.
- Herbs can later become cosmetic currency for flask skins, backgrounds, color schemes, or shop decorations.
- Completion/outro should eventually show progress toward the next reward, for example `5/20 orders until new background`.

### Onboarding And Clarity

- Play-first onboarding is the right direction.
- Need verify first-time users understand source tap, target tap, matching colors, empty flasks, undo, and hint.
- Need clear in-game messaging for optional locked bonus flask, especially to avoid paywall perception.

### Technical/Product Operations

- Need production build configuration review.
- Need analytics and crash reporting decision.
- Need privacy review before adding ads, analytics, or attribution SDKs.
- Need App Store assets and metadata workflow.
- Need QA test matrix for device sizes, iOS versions, clean install, upgrade install, offline behavior, reduced motion, and interrupted sessions.

## Team Workstreams

### iOS Developer

Primary outcome: turn the alpha foundation into a stable, service-ready iOS build.

Tasks:

- Verify `scripts/alpha_check.sh` passes on the target simulator and at least one physical device.
- Harden level loading, progress persistence, reset/new game, and resume behavior.
- Add or expand tests for generated level solvability, bonus flask unlock lifetime, ad reward success/failure, IAP purchase/restore states, and completion transitions. **Started:** feature-flag tests now cover disabled rewarded ads and disabled permanent bonus unlock paths.
- Decide and implement real SDK path: ads, StoreKit, analytics, crash reporting.
- If ads/IAP are not shipping in v1, hide or feature-flag those flows. **Done:** `GameFeatureFlags` now gates rewarded-ad and permanent bonus-flask purchase UI/actions; alpha keeps rewarded-ad stubs enabled and hides the future permanent purchase by default.
- Add dependency injection boundaries for ad provider, purchase provider, analytics, crash reporting, and remote config if used. **Started:** `GameAnalyticsProviding` now captures level start/complete, move count on completion, hint use, undo, reset, bonus flask unlock, and rewarded-ad attempt/result events behind a no-op provider.
- Prepare production configuration: bundle id, version/build numbers, signing, capabilities, privacy manifest, release scheme.
- Ensure accessibility basics: VoiceOver labels for core actions, Dynamic Type sanity where applicable, Reduce Motion respected.

Architectural note: keep game rules in value-type core models and service dependencies behind protocols. Avoid leaking SDK-specific code into SwiftUI views or the game engine.

### Game Designer

Primary outcome: make the Water Sort progression fun, fair, and measurable.

Tasks:

- Lock v1 level strategy: number of handcrafted levels, generation rules, and difficulty bands.
- Review first 10 levels against teaching goals.
- Define target difficulty metrics per stage: color count, buffer pressure, minimum move count, dead-end risk, and expected solve time.
- Create acceptance rules for generated levels: solvable without bonus flask, no excessive search complexity, no repeated boring patterns.
- Balance herbs: reward per order, hint cost, ad fallback frequency, and whether herbs carry any v1 purpose beyond hints.
- Define order objective usage: all-sort only vs occasional complete-color orders.
- Create a tester feedback rubric: clarity, boredom point, perceived fairness, bonus flask pressure, desire to play one more order.

Product constraint: do not use the locked bonus flask as a difficulty requirement. It is an optional relief valve and monetization affordance, not a paywall.

### UI/UX Designer

Primary outcome: make the product understandable and shippable without over-scoping the interface.

Tasks:

- Map the current game screen into a v1 UX flow: splash/launch, menu or direct continue, gameplay, win interlude, next order, settings/support.
- Define states for buttons and controls: normal, disabled, selected, hinted, invalid, loading ad, purchase pending.
- Specify copy for tutorial prompts, bonus flask prompt, hint/ad fallback, reset confirmation, victory messages, and offline/service failure.
- Design App Store screenshot compositions around real gameplay value, not marketing-only art.
- Define accessibility expectations: labels, contrast, reduced motion, touch target sizes, and readable color differentiation.
- Keep full shop meta, large map, NPC conversations, daily reward calendar, and cosmetic store out of v1 unless PM re-prioritizes.
- For post-v1 customization, design a main menu entry for sound toggle, haptics toggle, and collections for backgrounds, palettes, and flask styles.
- Define how locked cosmetics show requirements without feeling like a hard monetization wall.

Design constraint: do not spend the next iteration on font micro-tuning or pixel-perfect alignment before the release flow and monetization/service decisions are settled.

### Artist / Animator

Primary outcome: give the game a distinctive Cozy Potion Shop identity while preserving puzzle readability.

Tasks:

- Finalize v1 art direction for background, flask/liquid readability, lock state, hint highlight, invalid move feedback, and win celebration.
- Produce final app icon and required App Store visual assets.
- Create lightweight animation pass: pour clarity, bubbles/sparkles, order completion, locked flask unlock, reduced-motion alternatives.
- Ensure liquid colors remain distinguishable, including for color-vision accessibility.
- Replace placeholder art before beta unless intentionally accepted as final.
- Provide export specs for iOS assets: sizes, naming, scale factors, compression guidance.
- Plan future cosmetic sets in families: background scene, matching UI palette, flask variant, small decorative details, and matching celebration accents.
- Flask variants can change silhouette or add non-gameplay elements such as corks, caps, labels, wraps, charms, or ribbons.

Art constraint: readability beats decoration. Cozy atmosphere should support the puzzle board, not compete with it.

### QA / App Store Prep

Primary outcome: reduce submission and first-user risk.

Tasks:

- Own regression checklist for core game loop, level progression, undo, hint, reset, bonus flask, ads/IAP if enabled, persistence, and win transition.
- Test clean install, relaunch during level, background/foreground, offline mode, interrupted ad/purchase, low motion, and multiple screen sizes.
- Run App Store readiness checklist before RC.
- Prepare TestFlight build notes and tester instructions.
- Track blocker/major/minor issues separately from visual polish.
- Confirm no debug-only actions or placeholder labels are visible in release configuration.

QA priority: validate state correctness first. Cosmetic alignment bugs should not block alpha unless they hide controls or break readability.

## App Store Readiness Checklist

### Privacy And Compliance

- App Privacy labels drafted and reviewed.
- Privacy Policy URL available.
- Support URL available.
- Privacy manifest included if required by SDKs or project setup.
- Third-party SDK list reviewed.
- ATT prompt decision made if tracking is introduced.
- No data collection claims are made without implementation review.

### Ads And IAP

- Decide one of two release paths:
  - ship with real rewarded ads and/or StoreKit IAP;
  - ship without monetization and hide all ad/IAP UI.
- Rewarded ad SDK integrated, tested, and consent-compliant if enabled.
- StoreKit products configured in App Store Connect if IAP is enabled.
- Restore purchases implemented if any non-consumable unlock ships.
- Purchase failure, cancellation, pending, and offline states tested.
- App Review notes explain monetization behavior.

### Analytics And Crash Reporting

- Decide analytics provider and event taxonomy.
- Minimum events: app launch, level start, level complete, move count, hint used, undo used, reset, bonus flask prompt, bonus flask unlock, ad attempt/result, IAP attempt/result if enabled.
- Crash reporting integrated for beta or deliberate decision made to ship without it.
- Analytics and crash SDKs reflected in privacy disclosures.

### Store Assets And Metadata

- Final app name and subtitle.
- Keywords and description.
- Promotional text.
- App icon.
- Screenshots for required iPhone sizes.
- Optional preview video decision.
- Age rating questionnaire completed.
- Category selected.
- Copyright/support/contact details completed.

### TestFlight And Release Operations

- Internal TestFlight group created.
- External TestFlight review plan if needed.
- Build number/versioning rules defined.
- Smoke test checklist passed before each upload.
- Release notes drafted.
- Rollout strategy defined: manual release recommended for v1.

## Risks And Decisions

| Risk | Impact | Recommended Decision |
| --- | --- | --- |
| Real ads/IAP added too late | App Store delays, broken monetization, privacy mistakes | Decide monetization path before beta; hide stubs if not shipping |
| Generated levels become unfair or repetitive | Poor retention and bad reviews | Gate generated levels by solvability and difficulty metrics |
| Bonus flask feels required | Paywall perception | Keep all normal levels solvable without it and message it as optional help |
| Too much shop meta before core loop is proven | Delays and unclear MVP | Keep v1 focused on level progression, orders, hints, undo, rewards |
| No analytics/crash reporting in beta | Low visibility into failures and retention | Add lightweight analytics/crash reporting before broader TestFlight |
| Placeholder art remains into RC | Weak store conversion and review confidence | Schedule art replacement before beta exit |
| Debug/test actions leak into release | App Review/user trust risk | Feature-flag or remove debug controls from release configuration |

## Priority Order For Next Iterations

### Iteration 1: Alpha Stabilization

Goal: make the existing loop reliable enough for structured testing.

1. Run alpha check and fix blockers.
2. Verify Levels 1-10, undo, hint, reset, bonus flask, progress save, and win transition.
3. Add missing tests around state transitions and service stubs.
4. Prepare TestFlight/local tester instructions from `docs/alpha-test-notes.md`.
5. Collect feedback from at least 5-10 testers.

Exit criteria: testers can complete Levels 1-5 without guidance and no state-loss/blocker bugs remain.

### Iteration 2: Beta Scope Lock

Goal: decide what v1 ships with.

1. Choose monetization path: real ads/IAP or no monetization in v1.
2. Lock content target: recommended 50+ levels for beta, 100+ if generated levels feel varied.
3. Define analytics/crash reporting stack.
4. Finalize v1 UX flow and remove/hide non-v1 flows.
5. Start final art/icon/screenshot production.

Exit criteria: no major product decisions remain unresolved.

### Iteration 3: Beta Build

Goal: produce a near-final TestFlight build.

1. Integrate selected SDKs or remove stubs.
2. Complete level/content pass.
3. Add analytics events and crash reporting.
4. Run device QA matrix.
5. Replace placeholder art that affects player trust or App Store presentation.

Exit criteria: beta testers receive a build that represents the intended launch product.

### Iteration 4: Release Candidate

Goal: prepare App Store submission.

1. Complete App Store Connect metadata and screenshots.
2. Final privacy, age rating, and SDK review.
3. Run clean install, upgrade, offline, reduced motion, and service failure tests.
4. Freeze features.
5. Submit RC to TestFlight, then App Review.

Exit criteria: no known blockers, no visible stubs, no unresolved compliance items.

## Recommended V1 Product Scope

Ship v1 with:

- Water Sort core loop.
- First-session tutorial prompts.
- Level progression.
- Undo.
- Hint with herbs economy.
- Optional bonus flask, only if monetization path is real and compliant; otherwise make it free/unlockable by gameplay or hide monetized framing.
- Lightweight order framing.
- Cozy win feedback.
- Settings/support/privacy basics.
- Analytics and crash reporting.

Defer:

- Full shop customization.
- NPC relationship system.
- Daily rewards.
- Achievements.
- Large chapter map.
- Cosmetic store.
- Complex live ops.

This keeps the first release focused and gives the team a clean foundation for retention updates after real player data arrives.
