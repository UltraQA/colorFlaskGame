# Color Flask Game - Alpha Test Notes

## Goal

This alpha build tests the core Cozy Potion Shop loop:

1. Open the app.
2. Skip or watch the intro.
3. Start the current order from the main menu.
4. Sort potion colors by pouring between flasks.
5. Complete the order, earn herbs, and move to the next level.

The main question is whether the game feels clear, calm, and worth continuing after the first few orders.

## How To Play

- Tap a flask to select the source.
- Tap another flask to pour.
- You can pour only into an empty flask or onto the same top color.
- A flask is complete when it is full of one color.
- The order is complete when the current objective is solved.

## Controls

- Home: return to the main menu without resetting the current order.
- Undo: restore the previous valid move.
- Hint: show a suggested source and target.
- Reset: available from the main menu as a test/debug action.
- Bonus flask: starting from harder levels, a locked extra flask can be opened as optional help.

## What To Test

- For a clean first-run check, launch with `scripts/run.sh --fresh`.
- Start a fresh game and play from Level 1.
- Complete at least Levels 1-5.
- Try one valid pour and one invalid pour.
- Try Undo after a valid move.
- Try Hint once when it is free.
- Spend herbs on a later hint if you have enough.
- Try the ad fallback hint when herbs are empty.
- Tap the locked bonus flask once it appears.
- Return to the menu during a round, then continue the same order.
- Complete an order and confirm the next order starts correctly.

## Known Limitations

- Rewarded ads are stubs; no real ad network is connected yet.
- Permanent bonus flask unlock is a future IAP stub.
- Final shop meta, customers, achievements, and daily rewards are not implemented yet.
- Some art is placeholder and the Cozy Potion Shop visual pass is still in progress.
- Device QA is currently focused on portrait iPhone layouts.

## Feedback Questions

- Did you understand what to do without extra explanation?
- Did any UI element cover the flasks or make the board hard to read?
- Did the order objective feel clear?
- Did the Hint behavior feel helpful?
- Did the locked bonus flask feel optional, or did it feel required?
- Did the reward and next-level transition feel satisfying?
- At what point, if any, did you feel confused or bored?
- What would make you want to play one more order?
