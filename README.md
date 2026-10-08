# TDFC — more tactical enemies

**English** · [简体中文](README.zh-CN.md)

Enemies use sight, sound and squad reports to aim, take cover, suppress and advance. Adds variety to firefights while keeping vanilla health and damage.

**[Download v0.6.4 — TDFC_v0.6.4.zip](https://github.com/Eclipse-NotFound/TDFC/releases/download/v0.6.4/TDFC_v0.6.4.zip)** · [Release notes / other versions](https://github.com/Eclipse-NotFound/TDFC/releases)

Use the download link above, or open the release page, expand **Assets**, and select that filename. **Source code** and the green **Code → Download ZIP** button are development files, not the installable package.

## What changes?

- First identification takes observation; an enemy that remembers you can recognize you again quickly on sight.
- Level, training and elite status influence reaction and decision-making.
- Faction styles differ: raiders tend to close in, while rangers favor firing positions and covering allies.
- Works automatically during normal play, with an optional panel to inspect enemy decisions.

## Install

For **Windows / Remains 1.02**.

1. Save and close the game. In your Steam Library, right-click Remains → **Manage → Browse local files**. The game folder contains `pfe.swf` and `application.xml`.
2. If this is your first mod from this collection, complete the [ModLoader first-time setup](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md#first-install), including the game patch and scanner. Skip this if already installed.
3. Extract the ZIP and **merge its `mods` folder into the game folder**. Avoid a nested `mods/mods` folder.
4. Double-click **`mods/ModLoader/RemainsModScanner.exe`** inside the game folder. Wait for it to finish, close its message, then launch the game normally.

Check that this file exists: `mods/TDFC/release/TDFCMod.swf`. It takes effect automatically against supported enemies. The TDFC button at the upper right opens its observation panel.

[Folder diagram, updating and recovery](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md)

## Your first session

Load your character and play normally; no activation key is required.

To inspect it, click **TDFC** at the upper right and select an enemy label. The orange line shows its muzzle direction and the orange circle its aim point. Close the panel when finished; diagnostic information is hidden during ordinary play by default.

## Updates, removal and compatibility

Before updating, save and close the game, back up `mods/TDFC`, merge the new files, run the scanner and restart. Preserve your configuration. To disable the mod temporarily, move its folder outside `mods` as a backup, scan again and restart.

This guide covers v0.6.4 on Remains 1.02. It mainly affects raiders, rangers, mercenaries, slavers, zebras and enclave units. Special bosses and unrecognized types keep vanilla behavior. Morale, fleeing and active flanking are not included; co-op has not been comprehensively verified.

## Need help?

Check the folder location, run the scanner, and fully restart the game. See the [installation troubleshooting guide](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md#troubleshooting) for common problems.

If it still fails, [report an issue](https://github.com/Eclipse-NotFound/TDFC/issues) with your game version, mod version, other installed mods, steps to reproduce, and what you expected versus what happened. Include a screenshot or exact error if available; a personal save is not needed for an initial report.

<details>
<summary>Development resources (not needed to install)</summary>

This page describes the downloadable release; repository source may be ahead. See [src](src/) for implementation, with design, validation and version records in the project tree.

</details>

[Browse the mod collection](https://github.com/Eclipse-NotFound/ModLoader#choose-mods) · [First-time installation guide](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.md)

An unofficial fan project. You need your own copy of the game.
