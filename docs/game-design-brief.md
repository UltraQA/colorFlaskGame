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
- 1 locked bonus empty flask;
- the locked flask can be opened by:
  - rewarded ad for the current round;
  - permanent purchase, making it always available.

Total on screen: 8 flasks.

## Core Loop

1. The player opens a potion shop order.
2. The screen shows 5 filled flasks, 2 available empty flasks, and 1 locked bonus flask.
3. The player taps a source flask.
4. The player taps a target flask.
5. If the move is valid, liquid pours with a smooth animation.
6. If the move is invalid, the game gives soft feedback without punishment.
7. The player sorts liquids until every flask is either empty or full with one color.
8. On victory, the game shows cozy feedback: bubbles, glow, and order completion.
9. The player receives a small reward and moves to the next level.

The key fantasy: the player is not solving an abstract sorting puzzle, they are preparing clean potions for the shop.

## Level And Progression Plan

### Base Level Structure

- 5 filled flasks;
- 2 empty flasks available immediately;
- 1 locked bonus flask;
- each flask capacity: 4 sections;
- standard level color count: 5;
- each color appears exactly 4 times.

### First 10 Levels

The first levels should be handcrafted, not fully random. Their job is to teach the player without overload.

**Level 1**
- 3 colors;
- 3 filled flasks;
- 2 empty flasks;
- locked flask is visible but not needed;
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
- shuffle intensity;
- solution depth;
- temporary pour count;
- similar colors only after visual differentiation is strong;
- locked flask must not be required to solve normal levels.

Bonus flask should be convenience, not a paywall. Do not design levels that force the player to watch an ad.

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
- extra hints can use soft currency;
- rewarded ad is acceptable only as an optional way to get a hint.

### Priority 4: Bonus Locked Flask

Bonus flask:
- appears as an extra empty flask;
- is visually locked;
- does not participate in moves until unlocked;
- can be unlocked by:
  - rewarded ad for current round;
  - permanent purchase.

Behavior:
- ad unlock lasts only until the current round ends;
- permanent purchase makes bonus flask always available;
- temporary unlock resets when the level ends.

Standard levels must remain solvable without the bonus flask.

### Priority 5: Win State

After victory:
- block input;
- play feedback animation;
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

For MVP, permanent state can live in `UserDefaults`.

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
- daily gift;
- potion shelf collection;
- soft currency;
- optional rewarded ad;
- permanent bonus flask unlock.

Owner:
- Ohm + Gibbs.

## Open Questions

1. Should the locked bonus flask appear from Level 1, or be introduced later, for example on Level 5?
2. Should the player see level number and order progress on the main screen, or keep the screen textless for now?
3. Will the game be portrait-only?
4. Do we need a separate level map, or should victory immediately move to the next order?
5. What should soft currency be called: herbs, mana drops, stars, coins, or something else?
6. Is permanent bonus flask unlock a future IAP feature, or only a design stub for now?
7. Do we need a perfect-level system without undo/hint, or would that create unnecessary pressure?
8. What is the maximum number of colors in late game?
9. Should we support iPad layout with a larger board?
10. Do we want a shop meta: potion shelf, shop decorations, customers, and orders?
