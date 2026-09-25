# TDFC

Tactical decision & fire control for **Fallout Equestria: REMAINS** — enemies that perceive, think and fight back convincingly: they spot you, hear you, report to squadmates, pick cover, suppress, push and retreat based on weapon, situation, thinking tier and faction style. Damage and HP stay fully vanilla.

English (this page) · [简体中文](README.zh-CN.md)

## What it changes

- **Perception**: first identification needs sustained sight plus vanilla detection buildup. Enemies who have personally identified you re-acquire instantly on seeing you again (within their memory window); being occluded doesn't track your exact position, and hearing or squad reports never substitute for the first visual ID.
- **Four thinking tiers** (rough / trained / tactical / elite): base `1 + floor(level / 12)`, +1 for trained types, +1 for elite units, capped at 4. Higher tiers shorten confirm/report delays, retain intel longer, compare more cover options and prefer cover that lets them peek safely.
- **Faction styles**: raiders close in and press; iron rangers hold firing positions and cover allies with longer suppression windows; mercenaries pick cover and firing angles conservatively; slavers push opportunistically; the zebra legion combines pushes with squad reports and dispersed fire; the enclave keeps range with mobile shooting constrained by flight ability.
- Special bosses keep vanilla mechanics; unrecognized unit types are explicitly handed back to vanilla AI. No morale, fleeing or active flanking in this version.
- **Telekinesis interop**: enemies grabbed by telekinesis show "TK-held" and pause movement/firing orders until released; works with [RealisticVision](https://github.com/Eclipse-NotFound/RealisticVision) (vision mode is shown when TK input gets blocked).

## Observation overlay

Click the **TDFC** button (top-right in game) to open the debug overlay — off by default during normal play:

- Labels for every on-screen enemy with occlusion state; click a label to inspect its intel sources, intel age, action reasoning, target point, actual move/fire signals and blockers.
- Orange line = actual muzzle direction, orange circle = current aim point; vision lines show direction only.
- "Save diagnostics" exports characters, units, coordinates, actions and cooldowns to the game window's data directory (path also logged to `tdfc.log`).
- Telekinesis rows report the last grab/release/blocked/insufficient-magic/not-allowed result with pre-input targets kept for troubleshooting.

## Requirements

- Fallout Equestria: REMAINS (1.02).
- The one-time **ModLoader** game patch — see
  [ModLoader Releases](https://github.com/Eclipse-NotFound/ModLoader/releases) → `Remains-GamePatch`.

## Install

1. Download `TDFC_v0.6.4.zip` from [Releases](../../releases).
2. Copy the zip's `mods` folder into your game root (next to `pfe.swf`).
3. Restart the game — no keys needed; open the overlay only if you want to watch the AI think.

## Development

Sources in `src/`, rebuild via `build/build.ps1` (produces a candidate file; the game loads `release/TDFCMod.swf`). `Start-Test.bat` launches a sandboxed test window on a copy of your latest autosave — the vanilla save is never touched. Architecture and validation records (Chinese) live under `design/` and `knowledge/experiments/`.

## Related mods

[ModLoader](https://github.com/Eclipse-NotFound/ModLoader) ·
[RealisticVision](https://github.com/Eclipse-NotFound/RealisticVision) ·
[Sandevistan](https://github.com/Eclipse-NotFound/Sandevistan) ·
[MoreSkillsAndWeapons](https://github.com/Eclipse-NotFound/MoreSkillsAndWeapons) ·
[RandomRooms](https://github.com/Eclipse-NotFound/RandomRooms) ·
[RConnect](https://github.com/Eclipse-NotFound/RConnect)

> Fan mod project; not affiliated with the game's authors.
