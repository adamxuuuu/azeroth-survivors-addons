# Queued Level Ups

Automatically turns on the browser client's built-in level storage at the start of each run. New level-ups accumulate instead of interrupting combat. Click the stock **Level Up!** button when ready to spend them. The original card selection, rerolls and banishes remain controlled by the game.

## Install

1. Open the browser game, then **Options → AddOns → Install**.
2. Select `dist/QueuedLevelUps.zip` from this project.
3. Start your next run (or reload the client if already in a run).

Requires `AZS_GetPhase`, `AZS_IsStoringLevels` and `AZS_SetStoringLevels`. Older clients get one chat warning and no changes. Keep the stock levels HUD enabled to see the queue button/count.

The addon enables storage once per run, so you can change the game's storage toggle yourself afterward. It restores the previous setting when it observes death, victory or leaving the run. If you remove it or close/reload the page mid-run, check the stock storage toggle yourself; there is no guaranteed cleanup callback.

Opening the queued choices still uses the game's paused picker. Combat during card selection is not exposed by the addon API. Jewelry/cache choices are not deferred by this addon. Unspent level behavior at death is controlled by the client.

## Validation

Run `lua tests/queued-level-ups.lua` from the project root with Lua 5.1. The mocked API checks initialization, phase gating, restoring the setting, manual override, repeated runs and an unsupported client. Actual browser gameplay still needs verification.
