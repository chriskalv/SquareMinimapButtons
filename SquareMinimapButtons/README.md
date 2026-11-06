# Square Minimap Buttons

Port of the *Square Minimap Buttons* module of [ProjectAzilroka](https://github.com/Azilroka/ProjectAzilroka) by Azilroka to **WoW Forever** (Interface 16001), as a standalone addon. It collects the minimap buttons of other addons into a bar and skins them square, like the original module.

> **Status: work in progress, package 4 of 6.** This version contains the frame of the addon (libraries, client detection, saved variables with the default profile, the guard against ProjectAzilroka, the slash commands), the scan, skinning and locking of minimap buttons, the bar (layout, position, dragging, lock, fading, visibility, ElvUI and Tukui movers) and the Blizzard buttons (mail, tracking, calendar, queue). The options follow in the next package; until they exist, the settings below can only be changed in the saved variables. This README is completed with the release.

## Scan, skinning and locking

- **Scan** (`/zmb scan`, on entering the world and every 6 seconds): every child of the minimap that is a button is taken, except names on the fixed ignore list of ProjectAzilroka (25 names such as `GameTimeFrame`, `MinimapBackdrop`, `QueueStatusButton`, `TimeManagerClockButton`), names on the own ignore list, buttons already skinned, map pins (HereBeDragons, HandyNotes, TomCat Tours, Zygor, GatherMate2, Questie, TomTom) and unnamed buttons without an icon. Nothing is scanned in combat or in a pet battle.
- **Own ignore list** (setting in package 5): button names or Lua patterns; an entry matches if it equals the name or is found in it as a pattern. An invalid pattern only matches literally.
- **Skinning**: border, background and highlight textures (for example those of LibDBIcon buttons) are emptied; the other textures of the button and its direct children are fitted 1 px inside their frame (the button, or the child they belong to), without mask, and cropped like ElvUI icons if they show the full texture (0.08 per side, or after ElvUI's *cropIcon*). The button gets the icon size, the strata of the minimap and its level + 10, the backdrop and, with *Shadows*, a shadow (unless the button sets `ignoreTemplate`).
- **Locking**: while a button sits in the bar, its position methods (`SetParent`, `ClearAllPoints`, `SetPoint`, `SetSize`, `SetScale`, `SetIgnoreParentScale`, `SetFrameStrata`, `SetFrameLevel`) do nothing and strata and level are fixed, so that the addon owning the button cannot move it out again.

## The bar

- **Layout**: the buttons are laid out in the order they were found, `ButtonsPerRow` per row (default 1, so one column from the top), `IconSize` 22 and `ButtonSpacing` 2 apart and from the edge, from the top left corner (with *Reverse Direction* from the top right). The bar takes the size of its buttons, gets the backdrop (*Bar Backdrop*), the strata and level of the profile (buttons one level higher) and only counts buttons that are shown. Without buttons it is hidden (the original showed an empty narrow strip).
- **Position**: by default the bar is anchored to the minimap, its top left corner 1 px inside the top left corner of the minimap (point, relative point and offset in the profile). Without that anchor it stands where it was dragged last (saved in the profile) or, if it was never dragged, at the right screen edge like in ProjectAzilroka.
- **Dragging and lock**: without ElvUI and Tukui the bar is dragged with the left mouse button, on the bar or on one of its buttons; the position is saved in the profile. Nothing moves while the bar is anchored to the minimap or locked (*Lock*). With ElvUI the bar has ElvUI's mover *SquareMinimapButtonBar Anchor* (frame name `SquareMinimapButtonBarMover`, as in ProjectAzilroka, so a mover position from an ElvUI profile applies), which starts at the position from the profile; with Tukui it is registered with Tukui's movers.
- **Fading**: with *Bar MouseOver* the bar fades out and fades in while the mouse is over the bar or one of its buttons.
- **Visibility**: a macro condition (*Visibility*, default `[petbattle] hide; show`) shows or hides the bar.
- **Combat**: the bar is rebuilt only out of combat; a rebuild asked for in combat follows when combat ends.
- **Profiles**: changing, copying or resetting the profile sets the position again and rebuilds the bar.

## Blizzard buttons

Seven seconds after the start (and after a profile change) the addon adds Blizzard's own minimap buttons to the bar, after the addon buttons found so far. As in ProjectAzilroka it only adds them: a button taken out of the profile stays in the bar until the interface is reloaded.

| Button | Setting | WoW Forever | Retail | Classic |
|---|---|---|---|---|
| Mail: own button with a letter icon, green while there is unread mail, tooltip with the latest senders | *Move Mail Icon* | yes | yes | yes |
| Tracking: Blizzard's tracking button | *Move Tracker Icon* | yes | yes | no |
| Queue: own button with the eye, Blizzard's queue button on top of it while queued | *Move Queue Status Icon* | yes, off by default | yes | no |
| Calendar: Blizzard's calendar button | *Move Game Time Frame* | yes | no | yes |
| Garrison | *Hide Garrison*, *Move Garrison Icon* | no effect (as in ProjectAzilroka, whose code for it is disabled) | | |

WoW Forever needs its own handling for three of them:

- **Tracking**: in WoW Forever the tracking button's `Show` shows or hides its whole tracking frame, so ProjectAzilroka's call would hide it. The addon shows the tracking frame instead and moves only the button into the bar.
- **Calendar**: the WoW Forever calendar button has no `GameTimeTexture` (ProjectAzilroka would stop with an error there). The addon makes Blizzard's own textures of the button transparent and shows its own calendar icon (the atlas of Blizzard's button) inside the square frame; a click still opens the calendar.
- **Queue**: off by default in WoW Forever until it is checked in the client, because the queue button is an Edit Mode system and moving it may cause taint. A click on the eye opens the group finder through `ToggleGroupFinderFrame()` (WoW Forever has no `PVEFrame`). If ElvUI's queue module is loaded (frame `ElvUIQueueStatus`), the addon leaves the queue button alone, because ElvUI puts it back into its own mover at once; the option will be shown as locked then.

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

Planned for version 1.0.0 and implemented step by step in packages 2 to 5; in the current state the client detection, the default profile, the guard against ProjectAzilroka, the slash commands, the own ignore list (without its setting), the guard for secret texture coordinates, the minimap anchor, dragging with a saved position, the lock, the counting fix, the hidden empty bar, the rebuild after combat and on profile changes and the WoW Forever handling of the Blizzard buttons exist (settings for them follow with the options).

- Client detection for WoW Forever (`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`); ProjectAzilroka knows only Retail and Classic.
- Default profile after Zippy's classic UI: one column of 22 px buttons, anchored inside the top left corner of the minimap (`ButtonsPerRow` 1, `IconSize` 22; ProjectAzilroka: 12 and 20, bar at the right screen edge).
- *Move Queue Status Icon* is off by default in WoW Forever (on in Retail and Classic, as in ProjectAzilroka), and has no effect while ElvUI's queue module holds the queue button.
- Blizzard buttons in WoW Forever: tracking button moved without hiding its tracking frame, own calendar branch (ProjectAzilroka's `GameTimeTexture` does not exist there), queue click through `ToggleGroupFinderFrame()`.
- The own backdrop without ElvUI has a black border (ProjectAzilroka: dark grey).
- New settings: anchor the bar to the minimap (point, relative point, offset), lock the bar, an own ignore list.
- Without ElvUI and Tukui the bar itself can be dragged (ProjectAzilroka registers it for dragging but only its buttons move it), and its position is kept in the profile instead of the client's layout cache.
- Buttons that already sit in the bar are counted when they are shown, not when they are visible: in ProjectAzilroka a rebuild while the bar is hidden (pet battle) counted no buttons and removed the visibility condition of the bar.
- A rebuild asked for in combat waits until combat ends.
- Without buttons the bar stays hidden: ProjectAzilroka hid it and then faded it in again, which showed an empty strip.
- An ElvUI or Tukui that is enabled but not loaded does not cause an error; the bar can then be dragged.
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
