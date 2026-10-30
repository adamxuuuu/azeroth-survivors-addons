# Azeroth Survivors Addons

Two addons for the Azeroth Survivors browser client.

| Addon | Features | Download |
| --- | --- | --- |
| [CombatCluster](addons/CombatCluster/README.md) | Groups outgoing damage by source on the right, with colors and skill icons | [CombatCluster.zip](dist/CombatCluster.zip) |
| [QueuedLevelUps](addons/QueuedLevelUps/README.md) | Banks level-ups until you open the stock Level Up picker | [QueuedLevelUps.zip](dist/QueuedLevelUps.zip) |

## Install

Download an individual ZIP, then use **Options → AddOns → Install** in the game. Addons load on the next world entry.

## Tests

Run from the repository root with Lua 5.1:

```sh
lua tests/combat-cluster.lua
lua tests/queued-level-ups.lua
```

Mocked API tests and package integrity checks passed. Browser gameplay remains unverified. Unmatched damage sources use a question-mark icon. Opening banked level-ups still pauses for card selection.
