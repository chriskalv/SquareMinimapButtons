# Square Minimap Buttons

Port of the *Square Minimap Buttons* module of [ProjectAzilroka](https://github.com/Azilroka/ProjectAzilroka) by Azilroka to **WoW Forever** (Interface 16001), as a standalone addon. It collects the minimap buttons of other addons into a bar and skins them square, like the original module.

> **Status: work in progress, package 1 of 6.** This version contains the frame of the addon only: libraries, client detection, saved variables with the default profile, the guard against ProjectAzilroka and the slash commands. Scanning, skinning, the bar, the Blizzard buttons and the options follow in the next packages. This README is completed with the release.

## Origin and permission

The code is ported from ProjectAzilroka's module `Modules/SquareMinimapButtons.lua` and the helpers of its core. Zippy reports that Azilroka personally allowed him to port this part of ProjectAzilroka to WoW Forever (reported on 2026-11-05); the written record of the permission will be added to `LICENSE.txt`. The addon keeps Azilroka's name for the module and his copyright notice.

If ProjectAzilroka is loaded at the same time and its Square Minimap Buttons module is enabled, this addon stays inactive and says so once in the chat.

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

- Client detection for WoW Forever (`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`); ProjectAzilroka knows only Retail and Classic.
- Default profile after Zippy's classic UI: one column of 22 px buttons, anchored inside the top left corner of the minimap (`ButtonsPerRow` 1, `IconSize` 22; ProjectAzilroka: 12 and 20, bar at the right screen edge).
- *Move Queue Status Icon* is off by default in WoW Forever (on in Retail and Classic, as in ProjectAzilroka).
- The own backdrop without ElvUI has a black border (ProjectAzilroka: dark grey).
- New settings: anchor the bar to the minimap (point, relative point, offset), lock the bar, an own ignore list.
- Profile changes, copies and resets rebuild the bar (ProjectAzilroka only rereads the settings).
- Own slash commands `/zmb` and `/zippyminimap` (ProjectAzilroka has none for the module).

## Credits

- **Azilroka**: ProjectAzilroka and the Square Minimap Buttons module, with **Sinaris**, **Omega** and **Durc** as authors of the module.
- **Zippy**: port to WoW Forever.
- **Ace3** (WoWUIDev/Ace3): addon framework, embedded unmodified (commit `ac3d122`).

## Licenses

- Parts taken from ProjectAzilroka: ProjectAzilroka License (copyright notice kept), used with Azilroka's permission; see `LICENSE.txt`.
- Ace3: BSD license of the Ace3 Development Team, see `Libs/Ace3/LICENSE.txt`.
