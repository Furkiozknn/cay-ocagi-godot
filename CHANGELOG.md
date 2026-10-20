# Changelog

## 2026-10-21 overnight pass

Ports the browser version's remaster and fixes, fixes the Godot bugs from the arena review, and closes the
design-language gaps.

### Fixed

- The HUD coin counter showed the wallet plus today's coins against today's target, so the target looked met when it
  was not. It now shows today's coins only (the wallet is on the summary, shop and game-over cards).
- Menus could not be used with the keyboard or a gamepad: buttons and sliders take the focus now, the first button of
  every card is focused when it opens, and focused controls show an amber ring.
- *Start game* silently overwrote a saved run. With a save the title shows *Continue* and *New game*, and *New game*
  asks first ("A new game overwrites your saved progress").
- Parties that were still eating at closing time were never paid. They now pay the full bill and the tip (from the
  patience left when their order was completed) before the stars and pass / fail are worked out.
- Failed-day rule, now the same as the browser version: the coins of a failed day are kept. Game over offers
  *Shop & retry*; the shop's button then says *Retry the day* and does not advance the day. Saved as
  `resume: "shop", retrying: true`, so Continue after a failed day 7 retries it instead of showing the victory.
- Dirty glasses can no longer be thrown off the tray ("Dirty glasses go to the sink (5)").
- When the waiter clears a table the apprentice had claimed, the apprentice is sent back home instead of clearing an
  empty table.
- The angry bubble over a table that a customer left in anger now shows (the code for it was unreachable).
- Victory now saves `endless = true`. A language change on the victory card no longer replays the confetti.
- Changing the quality resizes the steam and smoke emitters too. The ferry, gulls and cat stand still while paused.
- The station buttons no longer allocate a new stylebox every frame while something is ready.

### Added

- Generated assets shared with the browser version: nine GLB models (semaver x2, oven, coffee sand stove, ayran
  fridge, sink, table, window, ferry, cat), the cobblestone ground texture, 20 icon PNGs, the crest (title, 128 px /
  112 px in a short window / 96 px on a phone) and the favicon (project icon). Same transforms as the browser;
  tables and windows are MultiMeshes; the oven glow, simit rings, coffee foam, steam and smoke follow the models.
  `--noassets` brings back the procedural look.
- Per-item served models (tea glass, simit plate, coffee cup, ayran cup, used glass, crumb plate) on the tray, the
  tables and the apprentice, instead of recoloured cylinders.
- Pause menu: *Restart the day* (back to the coins and upgrades the day began with). Dimmed, blurred backdrop behind
  every card except the title.
- Keys: `M` music, `X` effects, `L` language, `P` / `Esc` pause (Esc closes settings / confirm first), `Backspace`
  clears the queue (F speed, Q / E / Enter tables and the gamepad map are unchanged).
- *Last orders* 20 s before closing: one toast, the bell, and the clock bar and time turn red.
- Coins fly from the paying table to the HUD coin counter (1-4 coins, 0.7 s), which then bumps.
- *New record!* badge on the summary, game over and victory cards; *Main menu* on the intro, summary and shop;
  more stats on game over (happy, angry, wallet).
- Music ducked to 45 % while paused or while the window is in the background.
- Welcome toast and a pulsing tea station on day 1; queue chips show the station icon or the table number.
- Footer on the title: "Claude Game Arena · built by Claude Sonnet 5.5 · assets remastered".
- Buttons, HUD buttons and tray slots are at least 44 px on touch screens.
- `--no-save` (no save file is read or written) and `--noassets` user arguments.
- Tests: 458 unit assertions (was 386) covering the closing-time payment, the failed-day rule and its save, Restart,
  the new-record badge, victory → endless, the dirty-glass rule, the apprentice race, last orders, the volume toggles
  and defaults, the item models and the GLB bake; the UI smoke test has 43 checks (focus, new-game confirm, Esc / P,
  M / X, Backspace, paused number keys, HUD coins).

### Changed

- Settings defaults: master 80 %, music 60 %, effects 80 % (new players only).
- The top-bar mark is the tea icon PNG (the crest is unreadable at 26 px).
- A boiled-over coffee shows a flat dark froth at the pot mouth.
- The autoplay bot retries a failed day through the shop, like a player. `--seed=5` result: 7 days, 1,752 coins,
  18 stars (was 1,611 coins, 17 stars, mostly from the closing-time payments).
- Removed dead code: `Sfx.set_music`, `Sfx.is_ready`, unused text keys.
