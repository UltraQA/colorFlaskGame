# Water Sort: Cozy Potion Shop - Game Design Brief

## Product Direction

**Genre:** mobile puzzle game in the Water Sort format.
**Theme:** Cozy Potion Shop: a warm potion store where the player sorts magical liquids, creates clean elixirs, and completes shop orders.

The goal is to keep Water Sort simple and readable while giving it a stronger identity through a small potion shop fantasy: warm light, glass flasks, herbs, bubbles, soft magic, and clean UI with low visual noise.

The game should feel:
- calm;
- clear from the first tap;
- visually pleasant;
- non-aggressive in monetization;
- suitable for short 1-3 minute sessions.

Current round structure:
- 5 filled flasks at start;
- 2 empty flasks available immediately;
- 1 locked bonus empty flask appears once levels become harder, starting at Level 5;
- the locked flask can be opened by:
  - rewarded ad for the current round;
  - future permanent purchase placeholder, making it always available once IAP is implemented.

Total on screen: 7 flasks before Level 5, then 8 flasks from Level 5 onward.

## Core Loop

1. The player opens a potion shop order.
2. The screen shows filled flasks, 2 available empty flasks, and, from Level 5 onward, 1 locked bonus flask.
3. The player taps a source flask.
4. The player taps a target flask.
5. If the move is valid, liquid pours with a smooth animation.
6. If the move is invalid, the game gives soft feedback without punishment.
7. The player sorts liquids until every flask is either empty or full with one color.
8. On victory, the game shows cozy feedback: bubbles, glow, and order completion.
9. The player receives a small herbs reward and moves to the next level.

The key fantasy: the player is not solving an abstract sorting puzzle, they are preparing clean potions for the shop.

## Level And Progression Plan

### Base Level Structure

- 5 filled flasks;
- 2 empty flasks available immediately;
- 1 locked bonus flask from Level 5 onward;
- each flask capacity: 4 sections;
- standard level color count: 5;
- each color appears exactly 4 times.

### First 10 Levels

The first levels should be handcrafted, not fully random. Their job is to teach the player without overload.

**Level 1**
- 3 colors;
- 3 filled flasks;
- 2 empty flasks;
- locked bonus flask is not visible yet;
- teaches source tap -> target tap.

**Level 2**
- 3 colors;
- 4 filled flasks;
- 2 empty flasks;
- one color is almost completed;
- teaches empty flasks as buffers.

**Level 3**
- 4 colors;
- 4 filled flasks;
- 2 empty flasks;
- first small planning level.

**Level 4**
- 4 colors;
- 5 filled flasks;
- 2 empty flasks;
- full board without high difficulty.

**Bonus Flask Introduction**
- locked bonus flask is introduced as an optional extra buffer;
- standard levels must still remain solvable without using it.

**Level 5**
- 5 colors;
- 5 filled flasks;
- 2 empty flasks;
- low shuffle;
- first standard level.

**Level 6**
- 5 colors;
- 5 filled flasks;
- 2 empty flasks;
- includes a tempting but suboptimal obvious move;
- teaches not to fill buffers carelessly.

**Level 7**
- 5 colors;
- 5 filled flasks;
- 2 empty flasks;
- requires using both empty flasks;
- reinforces buffer strategy.

**Level 8**
- 5 colors;
- 5 filled flasks;
- 2 empty flasks;
- more color alternation;
- raises difficulty without requiring the locked flask.

**Level 9**
- 5 colors;
- 5 filled flasks;
- 2 empty flasks;
- bonus locked flask can help, but the level must remain solvable without it;
- softly demonstrates bonus flask value.

**Level 10**
- milestone level;
- 5 colors;
- 5 filled flasks;
- 2 empty flasks;
- slightly higher difficulty;
- after victory, show special feedback: first shop order completed.

### Difficulty Scaling

Increase difficulty through:
- color count;
- flask capacity / section count in later chapters;
- shuffle intensity;
- solution depth;
- temporary pour count;
- similar colors only after visual differentiation is strong;
- locked flask must not be required to solve normal levels.

Bonus flask should be convenience, not a paywall. Do not design levels that force the player to watch an ad.

Suggested long-term progression:

| Stage | Levels | Colors | Flask capacity | Filled flasks | Available empty flasks | Goal |
| --- | --- | --- | --- | --- | --- | --- |
| Tutorial | 1-4 | 3-4 | 4 | 3-5 | 2 | Teach tapping, matching, and buffers |
| Standard | 5-30 | 5 | 4 | 5 | 2 | Introduce locked bonus flask and normal puzzle rhythm |
| Expanded | 31-80 | 6 | 4 | 6 | 2 | More planning without changing section size |
| Advanced | 81-150 | 7 | 4 | 7 | 2-3 | Longer solve paths and higher buffer pressure |
| Expert | 151+ | 8 | 5 | 8 | 3 | Bigger potion batches with five sections per color |

Rule of thumb:
- do not increase color count and flask capacity at the same time;
- first introduce a new color count with familiar 4-section flasks;
- only move to 5-section flasks once the player already understands 7-8 color puzzles;
- each color must still appear exactly once per flask section count, for example 4 times in 4-section levels and 5 times in 5-section levels.

## Mechanics Priorities

### Priority 1: Stable Level System

Move away from fully random starts and introduce level data.

Recommended shape:

```swift
struct Level {
    let id: Int
    let filledFlasks: [Flask]
    let availableEmptyFlaskCount: Int
    let hasLockedBonusFlask: Bool
    let difficulty: Difficulty
}
```

For the first version:
- define the first 10 levels by hand;
- add a generator later, with solvability validation.

### Priority 2: Undo

Undo is a critical puzzle UX feature.

Requirements:
- Undo button stays top-right;
- undo restores the previous state;
- save history before every valid move;
- invalid moves do not enter history;
- reset clears history;
- after win, undo is locked.

MVP:
- unlimited undo.

Later:
- soft limits or economy can be considered, but not early.

### Priority 3: Hint

Hint should help without playing for the user.

MVP hint:
- find one valid useful move;
- highlight source flask;
- then highlight target flask;
- do not execute the move automatically.

Later:
- improve hint solver;
- consider level state;
- avoid hints that lead to dead ends.

Economy:
- first hint on each level is free;
- extra hints can use herbs;
- rewarded ad is acceptable only as an optional way to get a hint.

### Priority 4: Bonus Locked Flask

Bonus flask:
- appears as an extra empty flask;
- is visually locked;
- does not participate in moves until unlocked;
- can be unlocked by:
  - rewarded ad for current round;
  - future permanent purchase placeholder.

Behavior:
- ad unlock lasts only until the current round ends;
- permanent purchase is a future IAP stub for now and will make the bonus flask always available once implemented;
- temporary unlock resets when the level ends.

Standard levels must remain solvable without the bonus flask.

### Priority 5: Win State

After victory:
- block input;
- play a short win interlude: micro celebration, soft board blur/dim, central encouragement message, then transition;
- support tap-to-skip while the encouragement message is visible;
- show completion state;
- save progress;
- open the next level.

## UI And Design Requirements For Hume

### Theme Direction

Theme: **Cozy Potion Shop**.

Visual tone:
- warm;
- magical;
- clean;
- not overloaded;
- readable on a small screen.

Avoid:
- sci-fi darkness;
- overloaded decorative frames;
- tiny details that compete with flasks;
- aggressive monetization patterns.

### Screen Layout

On the game screen:
- top-center: current level number;
- center: board with 8 flasks;
- bottom-left: Reset;
- top-right: Undo;
- bottom-right: Hint;
- locked bonus flask is part of the flask grid;
- UI must respect safe areas.

Recommended grid:
- 4 flasks in the top row;
- 4 flasks in the bottom row.

Alternative:
- 3 + 3 + 2 if 4 + 4 feels too tight on small screens.

### Flask States

Design states:
- normal;
- selected;
- valid target;
- invalid target;
- empty;
- completed;
- locked bonus flask;
- unlocked bonus flask;
- hint source;
- hint target.

### Locked Bonus Flask UI

Locked flask should be understandable without text:
- dimmed empty flask;
- small lock icon;
- soft glow or plus mark nearby;
- on tap, future bottom sheet can offer:
  - watch ad;
  - unlock forever.

MVP:
- lock icon;
- disabled interaction.

### Controls

Reset:
- bottom-left;
- easy to reach, but not the main CTA;
- visually calm.

Undo:
- top-right;
- icon-only;
- disabled state when history is empty.

Hint:
- bottom-right;
- more visible than reset;
- may include a small badge with hint count.

### Feedback

Needed micro-animations:
- selected flask lift / glow;
- invalid move shake;
- successful pour stream;
- completed flask glow;
- win bubbles / sparkle;
- hint pulse.

## Engineering Requirements For Gibbs

### Architecture

Keep the separation:
- `GameManager`: rules and game state;
- `HomeViewModel`: UI orchestration;
- SwiftUI Views: rendering and user interaction only.

Do not move business logic into Views.

### Data Model

Update the level model for 8 flasks:
- 5 filled flasks;
- 2 available empty flasks;
- 1 locked bonus flask.

Recommended type:

```swift
enum FlaskAvailability {
    case available
    case lockedBonus
    case temporaryUnlocked
    case permanentlyUnlocked
}

struct GameFlask {
    var flask: Flask
    var availability: FlaskAvailability
}
```

Or extend the current `Flask` model if it keeps the domain clean.

Important:
- locked flask must not participate in `pour(from:to:)`;
- validation must check availability;
- UI should receive explicit state.

### Level System

Add:
- `Level`;
- `LevelRepository`;
- handcrafted first 10 levels;
- `currentLevelIndex`.

MVP:
- in-memory levels.

Later:
- JSON levels in bundle;
- level generator;
- solvability validator.

### Undo

Add history:

```swift
private var history: [[GameFlask]] = []
```

Rules:
- save state before valid pour;
- `undo()` restores the last state;
- `canUndo` is published to the ViewModel;
- reset clears history.

### Hint

MVP:
- `findHint() -> Move?`;
- `Move` contains `from` and `to`;
- ViewModel stores `hintedSourceIndex` / `hintedTargetIndex`;
- View highlights those flasks.

Do not execute hint automatically.

### Bonus Flask

Add:
- `unlockBonusFlaskForRound()`;
- `unlockBonusFlaskPermanently()`;
- `isBonusUnlockedPermanently`.

For MVP, permanent unlock is only a design/code stub and can live in `UserDefaults`.

Rewarded ad:
- use a stub for now;
- keep API behind a protocol so an SDK can be added later.

```swift
protocol RewardedAdProviding {
    func showRewardedAd() async -> Bool
}
```

### Testing

Minimum unit tests:
- cannot pour into locked flask;
- cannot pour from locked flask;
- can pour into temporary unlocked flask;
- undo restores previous state;
- reset clears undo history;
- win condition ignores locked empty flask;
- first 10 levels have valid color and section counts.

## Asset Brief For Confucius

### Overall Art Direction

Theme: Cozy Potion Shop.

Atmosphere:
- cozy potion store;
- warm magical light;
- wood, glass, soft glow;
- no horror;
- no grim dungeon;
- no heavy detail clutter.

### Required Assets

#### Background

Game background:
- vertical mobile;
- iPhone 15 ratio;
- must work under UI and flasks;
- center should stay low-noise;
- edges can contain shop elements: shelves, herbs, candles, books;
- safe areas must not conflict with buttons.

Needed sizes:
- `1x`, `2x`, `3x`;
- target `3x`: about `1179x2556`.

#### Flask

Base flask:
- transparent interior;
- readable glass outline;
- soft highlight;
- suitable for filling with SwiftUI-drawn liquids;
- can be used as an overlay above programmatic liquid.

States:
- normal;
- selected glow;
- completed glow;
- locked overlay.

#### Liquids

Potion colors should be distinct:
- ruby red;
- emerald green;
- honey yellow;
- moon blue;
- violet purple;
- optional orange.

Avoid overly similar colors.

#### Buttons

Needed icons/buttons:
- Reset: bottom-left;
- Undo: top-right;
- Hint: bottom-right;
- Lock;
- Plus / unlock;
- optional ad marker.

Style:
- soft round / oval forms;
- potion shop material language;
- not overly cartoonish;
- icon-first, no required visible text.

#### Effects

Small effects:
- bubbles;
- sparkle;
- soft glow;
- pour stream texture;
- completed potion shine.

Can be PNG sprites or references for SwiftUI effects.

### Asset Naming Proposal

```text
Images/
  Backgrounds/
    game_background_cozy_shop.png
  Flasks/
    flask_glass_base.png
    flask_glass_selected.png
    flask_glass_completed.png
    flask_locked_overlay.png
  Buttons/
    button_reset.png
    button_undo.png
    button_hint.png
  Icons/
    icon_lock.png
    icon_ad.png
    icon_plus.png
  Effects/
    effect_bubble.png
    effect_sparkle.png
    effect_glow.png
```

## Milestone Plan

## Review Snapshot - 2026-05-13

The current build is a solid MVP foundation: the core Water Sort loop works, the game introduces the locked bonus flask from Level 5, undo/hint/reset are implemented, the first 10 handcrafted levels exist, and the main logic is covered by unit tests.

Reviewer verdicts:
- Hume (UI Designer): flask grid and potion readability are strong, but the current background and mixed button styles weaken the Cozy Potion Shop identity.
- Gibbs (iOS SwiftUI Developer / Architect): the architecture is workable for MVP, but domain logic still depends on `SwiftUI.Color`, `GameManager` mixes pure rules with observation, and timing callbacks need cancellation.
- Ohm (Game Designer): the game is fair-minded and playable, but solvability without the bonus flask and trustworthy hint behavior need stronger validation.
- Confucius (Artist / UI Art Director): the theme direction is clear, but the current background reads as generic outdoor fantasy rather than a cozy potion shop.
- Anscombe (Apple Guidelines / HIG Reviewer): touch targets and safe-area basics are good, but adaptive layout, richer accessibility, Reduce Motion, and Dynamic Type need attention.

Overall state:
- MVP gameplay: strong enough to continue iteration.
- Visual identity: promising, but not yet aligned with Cozy Potion Shop.
- Architecture: acceptable for prototype, with clear refactor path before scale.
- Accessibility/adaptivity: basic support exists, but production readiness is not there yet.
- Monetization fairness: direction is good, but bonus flask introduction and solvability gates must be explicit.

## Consolidated Roadmap From Review

### Priority A: Fair Play And Puzzle Trust

Tasks:
- Add solvability validation for handcrafted levels without using the locked bonus flask. **Done:** `LevelSolvabilityValidator` now produces a solvability report with minimum move count and visited state count.
- Define whether levels 1-4 are tutorial exceptions or whether every visible level must always follow the full 5 + 2 + 1 structure. **Done:** levels 1-4 stay cleaner without the locked bonus flask; Level 5 introduces it when puzzles become more complex.
- Upgrade hint logic from local move ranking to a solution-aware or dead-end-aware hint path.
- Add difficulty metrics per level: color count, minimum moves, buffer pressure, solution depth, and dead-end risk.
- Tune bonus flask introduction so it feels optional and not pay-to-win.

Why this matters:
The player must trust that every standard level is fair and that Hint helps rather than quietly making the puzzle worse.

### Priority B: Cozy Potion Shop Visual Pass

Tasks:
- Replace the current background with an interior cozy potion shop board scene.
- Keep the board center low-noise so empty flasks and glass outlines remain readable.
- Unify Reset, Undo, and Hint into one visual language.
- Decide whether flasks stay SwiftUI-procedural or move to sprite overlays based on `Flask.pxo`.
- Create locked bonus flask art that feels like an optional cozy object, not an aggressive monetization gate.
- Export production-ready assets at `1x`, `2x`, and `3x`.

Why this matters:
The gameplay already says “potion sorting,” but the current art direction does not yet fully say “cozy potion shop.”

### Priority C: UI/UX Clarity

Tasks:
- Rework bottom controls into a coherent control group or clearly balanced corner layout.
- Improve the bonus unlock sheet with title, benefit copy, clear CTA labels, and a visual locked-to-unlocked preview.
- Add a stronger win moment: order complete, moves, small reward, and Next CTA or delayed fallback.
- Add a subtle board vignette or contrast layer behind flasks.
- Differentiate hint source and target with more than one shared highlight style.
- Protect reset in later levels with confirmation or press-and-hold.

Why this matters:
The first screen is playable, but the game needs clearer emotional beats and less accidental-feeling UI placement.

### Priority D: Architecture And Testability

Tasks:
- Replace `SwiftUI.Color` in the domain model with a domain-safe `LiquidColor` or `LiquidColorToken`. **Done:** core gameplay now uses `LiquidColor`; SwiftUI mapping lives in the design layer.
- Split `GameManager` into a pure game engine/state model and a SwiftUI-facing observable adapter. **Done:** `GameState` owns pure gameplay rules while `GameManager` publishes state for SwiftUI.
- Replace `DispatchQueue.main.asyncAfter` callbacks with cancellable task/scheduler or `Clock`-based orchestration. **Done:** `HomeViewModel` now uses cancellable tasks for pour feedback, invalid feedback, and completion transitions.
- Move progress persistence behind a `ProgressStore` protocol. **Done:** `HomeViewModel` now depends on a persistence abstraction while `UserDefaults` stays behind `UserDefaultsProgressStore`.
- Add deterministic level generation/shuffling for testable future generated levels. **Done:** generated levels now accept a stable seed and use deterministic shuffling.
- Expand tests around completion flow, level advance, delayed callback cancellation, and permanent bonus unlock across levels. **Done:** tests now cover completion phases, cancellation after reset, progress persistence, and permanent bonus unlock across levels.
- Clean Xcode project warnings and clarify resource policy for `Resources/Media` source assets. **Done:** media README now distinguishes editable source files from runtime `Assets.xcassets` exports.

Why this matters:
The current architecture supports MVP, but these changes reduce coupling before level count, monetization, and UI states grow.

### Priority E: Apple HIG, Accessibility, And Device Coverage

Tasks:
- Build adaptive board layouts for compact portrait, standard portrait phones, and portrait iPad.
- For MVP iPad support, scale the existing portrait board and controls instead of designing a separate iPad-specific screen. **Done:** the game screen now uses a shared layout scale for larger portrait screens.
- Add rich VoiceOver labels for flasks, including index, contents summary, selected state, locked state, and available action. **Done:** flask controls now expose index, potion contents, top color, empty section count, state, and action hints.
- Done: Reduce Motion now replaces invalid-move shake, pour motion, sparkle animation, and celebration transitions with calmer state changes.
- Done: flask states now include non-color-only indicators for selected, hint source, hint target, invalid, and completed states.
- Done: bonus unlock sheet now measures content height and adapts layout for larger text.
- Done: contrast audit pass increased glass, locked, disabled, selected, invalid, hint, and completed-state readability.
- Started: layout regression tests now cover compact portrait phone, standard portrait phone, portrait iPad scaling, and safe-area bottom controls. Full visual snapshot coverage is still a future UI-test target task.

Why this matters:
The current screen is reachable and tappable, but production iOS quality needs stronger device and accessibility coverage.

### Milestone 1: Playable Cozy Core

Goal:
- game fully plays with the new 5 + 2 + 1 locked structure.

Scope:
- 8 flasks on screen;
- locked bonus flask;
- valid pouring;
- reset;
- win condition;
- basic cozy layout.

Owner:
- Gibbs.

Support:
- Hume for layout;
- Confucius for placeholder art direction.

### Milestone 2: Player-Friendly Puzzle UX

Goal:
- the player can make mistakes without frustration.

Scope:
- undo;
- invalid move feedback;
- selected / valid / invalid states;
- first hint version;
- win animation.

Owner:
- Gibbs + Hume.

### Milestone 3: First 10 Levels

Goal:
- replace random start with teaching progression.

Scope:
- `Level` model;
- handcrafted levels 1-10;
- level progression;
- simple persistence.

Owner:
- Ohm + Gibbs.

### Milestone 4: Cozy Potion Visual Pass

Goal:
- the game starts looking like Cozy Potion Shop.

Scope:
- final background;
- flask overlay;
- themed buttons;
- lock visual;
- hint/undo/reset icons;
- bubbles/sparkles.

Owner:
- Confucius + Hume.

### Milestone 5: Gentle Retention

Goal:
- add reasons to return without pressure.

Scope:
- daily herbs gift;
- potion shelf collection;
- future shop meta with customers who request special nectars, tinctures, potions, and other cozy potion orders;
- optional shop decorations as long-term progression;
- future achievement list, where perfect-level completion can exist as an optional mastery achievement;
- herbs as soft currency;
- optional rewarded ad;
- permanent bonus flask unlock as a future IAP placeholder.

Owner:
- Ohm + Gibbs.

## Open Questions

1. **Answered:** the locked bonus flask is introduced later, starting at Level 5, when levels become more complex.
2. **Answered:** show the current level number at the top of the main screen; it gives the player clear orientation without adding much visual noise.
3. **Answered:** yes, the game is portrait-only.
4. **Answered:** victory immediately moves to the next order/level for now; a separate level map is not needed for the current MVP.
5. **Answered:** soft currency is called herbs, matching the potion shop and future order-crafting fantasy.
6. **Answered:** permanent bonus flask unlock is a future IAP feature; for now it remains a design/code stub only.
7. **Answered:** no perfect-level pressure in MVP; perfect-level can return later as an optional achievement instead.
8. **Answered:** late game can grow up to 8 colors; flask capacity should stay at 4 first, then optionally increase to 5 sections only in expert levels.
9. **Answered:** yes, support iPad by scaling the current portrait layout/board for now; no separate iPad layout is needed in MVP.
10. **Answered:** yes, as a future layer: customers can visit the shop and request special nectars, tinctures, potions, and other orders; potion shelf and decorations can support long-term progression.
