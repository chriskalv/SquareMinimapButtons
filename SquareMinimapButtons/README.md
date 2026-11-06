# Square Minimap Buttons

Port of the *Square Minimap Buttons* module of [ProjectAzilroka](https://github.com/Azilroka/ProjectAzilroka) by Azilroka to **WoW Forever** (Interface 16001), as a standalone addon. It collects the minimap buttons of other addons into a bar and skins them square, like the original module.

> **Status: work in progress, package 2 of 6.** This version contains the frame of the addon (libraries, client detection, saved variables with the default profile, the guard against ProjectAzilroka, the slash commands) and the scan, skinning and locking of minimap buttons. The bar, the Blizzard buttons and the options follow in the next packages; until the bar exists, `/zmb scan` skins the buttons where they are. This README is completed with the release.

## Scan, skinning and locking

- **Scan** (`/zmb scan`; from package 3 on also on login and every 6 seconds): every child of the minimap that is a button is taken, except names on the fixed ignore list of ProjectAzilroka (25 names such as `GameTimeFrame`, `MinimapBackdrop`, `QueueStatusButton`, `TimeManagerClockButton`), names on the own ignore list, buttons already skinned, map pins (HereBeDragons, HandyNotes, TomCat Tours, Zygor, GatherMate2, Questie, TomTom) and unnamed buttons without an icon. Nothing is scanned in combat or in a pet battle.
- **Own ignore list** (setting in package 5): button names or Lua patterns; an entry matches if it equals the name or is found in it as a pattern. An invalid pattern only matches literally.
- **Skinning**: border, background and highlight textures (for example those of LibDBIcon buttons) are emptied; the other textures of the button and its direct children are fitted 1 px inside their frame (the button, or the child they belong to), without mask, and cropped like ElvUI icons if they show the full texture (0.08 per side, or after ElvUI's *cropIcon*). The button gets the icon size, the strata of the minimap and its level + 10, the backdrop and, with *Shadows*, a shadow (unless the button sets `ignoreTemplate`).
- **Locking**: while a button sits in the bar, its position methods (`SetParent`, `ClearAllPoints`, `SetPoint`, `SetSize`, `SetScale`, `SetIgnoreParentScale`, `SetFrameStrata`, `SetFrameLevel`) do nothing and strata and level are fixed, so that the addon owning the button cannot move it out again.

## Origin and permission

The code is ported from ProjectAzilroka's module `Modules/SquareMinimapButtons.lua` and the helpers of its core. Zippy reports that Azilroka personally allowed the port of this part of ProjectAzilroka to WoW Forever (reported on 2026-11-05); the written record of the permission will be added to `LICENSE.txt`. The addon keeps Azilroka's name for the module and the ProjectAzilroka copyright notice.

If ProjectAzilroka is loaded at the same time and its Square Minimap Buttons module is enabled, this addon stays inactive and says so once in the chat. The same happens, with its own message, when ProjectAzilroka is loaded but its settings cannot be read.

## Install

1. Copy the folder `SquareMinimapButtons` into the `Interface\AddOns` folder of your WoW Forever installation, so that `Interface\AddOns\SquareMinimapButtons\SquareMinimapButtons.toc` exists. A release zip follows with version 1.0.0.
2. Restart the game and enable **Square Minimap Buttons** in the addon list.

## Slash commands

| Command | Effect |
|---|---|
| `/zmb` or `/zippyminimap` | open the options (until the options exist: a hint in the chat) |
| `/zmb scan` | scan the minimap for new buttons now |
| `/zmb reset` | reset the current profile to the defaults |

The addon compartment entry opens the options as well.

## Changes from the original

Planned for version 1.0.0 and implemented step by step in packages 2 to 5; in the current state the client detection, the default profile, the guard against ProjectAzilroka, the slash commands, the own ignore list (without its setting) and the guard for secret texture coordinates exist.

- Client detection for WoW Forever (`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`); ProjectAzilroka knows only Retail and Classic.
- Default profile after Zippy's classic UI: one column of 22 px buttons, anchored inside the top left corner of the minimap (`ButtonsPerRow` 1, `IconSize` 22; ProjectAzilroka: 12 and 20, bar at the right screen edge).
- *Move Queue Status Icon* is off by default in WoW Forever (on in Retail and Classic, as in ProjectAzilroka).
- The own backdrop without ElvUI has a black border (ProjectAzilroka: dark grey).
- New settings: anchor the bar to the minimap (point, relative point, offset), lock the bar, an own ignore list.
- Texture coordinates that the client returns as secret values are not compared; such an icon keeps its coordinates instead of being cropped.
- Profile changes, copies and resets rebuild the bar (ProjectAzilroka only rereads the settings).
- Own slash commands `/zmb` and `/zippyminimap` (ProjectAzilroka has none for the module).

## Credits

- **Azilroka**: ProjectAzilroka and the Square Minimap Buttons module, with **Sinaris**, **Omega** and **Durc** as authors of the module.
- **Zippy**: port to WoW Forever.
- **Ace3** (WoWUIDev/Ace3): addon framework, embedded unmodified (commit `ac3d122`).

## Licenses

- Parts taken from ProjectAzilroka: ProjectAzilroka License (copyright notice kept), used with Azilroka's permission; see `LICENSE.txt`.
- Ace3: BSD license of the Ace3 Development Team, see `Libs/Ace3/LICENSE.txt`.
