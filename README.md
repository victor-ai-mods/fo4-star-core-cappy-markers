# Star Core and Cappy Markers

A Fallout 4 mod. **Requires Nuka-World.**

> **Status:** working in-game, not released on Nexus Mods yet.

Quest markers for the Nuka-World **Star Cores** and **hidden Cappys** you have not
picked up yet — correct on a save where the collecting is already half done, and
never showing a marker for something you already have.

## Why another one of these

[Nuka-World Collectable Quest Markers (Nexus 20354)](https://www.nexusmods.com/fallout4/mods/20354)
does the same job but keeps **its own** record of which Star Cores were collected,
in alias collections it adds to the vanilla quests. That is the root of every
long-standing complaint on its bug tab:

| Reported bug | Cause |
|---|---|
| Markers for collected cores come back after finishing *Star Control* | its v1.2.0 Misc quest fills a fresh collection with **all** cores |
| Marker does not disappear after picking a core up | its collections have no equivalent of the vanilla `RemoveRef` |
| Nothing shows at all when installed mid-playthrough | new aliases cannot be added to a quest that is already running in the save — alias data is baked into the save, objectives are not |

This mod adds **no tracking of its own**. Everything is read back out of vanilla
state that already lives in the save file.

## How it works

Two new `QUST` records — `SCCM_StarCoreQuest` and `SCCM_CappyQuest`, both Start Game
Enabled, type *Miscellaneous*. Each has one empty ref-collection alias and one objective
whose `QSTA` target is that alias. Targeting a ref collection makes the engine draw one
marker per ref — the same pattern vanilla uses for `Min02`/EggClutches and
`MinRecruit*`/RaiderBosses.

**One quest per collectible type, not one quest with two objectives**, because Fallout 4
tracks a whole quest rather than a single objective: two objectives sharing a quest can
only ever be tracked together.

Each quest's script (`SCCM:StarCoreMarkers` / `SCCM:CappyMarkers`, sharing
`SCCM:MarkerQuestBase` for the timer and objective plumbing) refills its collection:

**Star Cores** — `DLC04GZTrackingQuest` (`0101E34C`) holds six ref-collection aliases,
one per zone (ids 42–47), and `dlc04gztrackingqueststarcorecollection.pex` calls
`RemoveRef()` the moment a core is taken. So those collections *are* the list of
remaining cores, already accurate in any save. The script copies them with
`AddRefCollection()` and then drops anything that is disabled (a taken loose core) or
sits in `LockedStarCorePanels` (an emptied wall panel) — that last filter only
matters for cores taken before the tracking quest reached stage 10, where vanilla
removes the ref from the wrong collection.

**Hidden Cappys** — the 10 placed `DLC04MS01CappyActivator` refs each set their own
stage on `DLC04MS01` when found (110, 115, 120 … 155), so `GetStageDone()` answers per
Cappy. The objective is hidden unless *Cappy in a Haystack* is running and unfinished.

Both objectives hide themselves when nothing is left to find.

### No masters

The script resolves every vanilla form with `Game.GetFormFromFile(..., "DLCNukaWorld.esm")`,
so the plugin's only master is `Fallout4.esm`. It overrides no vanilla record, conflicts
with nothing, and can be removed at any time.

## Using it

Both quests sit in Pip-Boy → **Misc**, and can be tracked independently. Track the
"Find the remaining …" line you want to get its markers on the compass; untrack it when
you don't. Map markers show either way.

## Diagnostics

With Papyrus user logging enabled in the ini, the script writes to
`Logs\Script\User\SCCM.0.log` — which vanilla quests it resolved, the per-zone counts it
read out of `DLC04GZTrackingQuest`, and the remaining totals. It only writes when one of
those changes, never once per poll, and the calls are no-ops with logging off.

## Build

```
python tools/gen_esp.py
"D:\Games\Fallout 4\Papyrus Compiler\PapyrusCompiler.exe" papyrus ^
    -i="papyrus;D:\Games\Fallout 4\Data\Scripts\Source\Base" ^
    -o="build\scripts" -f="Institute_Papyrus_Flags.flg" -all
```

Outputs `build/StarCoreAndCappyMarkers.esp` and three `build/scripts/SCCM/*.pex`.
Install to `Data/` and `Data/Scripts/SCCM/` respectively, and enable the plugin.

`tools/gen_esp.py` documents the QUST byte layout, including the non-obvious one: a
**Ref Collection Alias is its own array entry** — `ALCS` (alias id) + `ALMI` (max initial
fill) placed immediately *before* the ordinary `ALST` entry it upgrades. There is no flag
for it.

## License

[The Unlicense](LICENSE) — public domain. Do whatever you want with this code; no attribution
required.
