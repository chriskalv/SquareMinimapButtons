# Square Minimap Buttons

Port of the *Square Minimap Buttons* module of [ProjectAzilroka](https://github.com/Azilroka/ProjectAzilroka) by Azilroka to **WoW Forever** (Interface 16001), as a standalone addon. It collects the minimap buttons of other addons into a bar and skins them square, like the original module.

> **Status: work in progress, package 5 of 6.** This version contains the frame of the addon (libraries, client detection, saved variables with the default profile, the guard against ProjectAzilroka, the slash commands), the scan, skinning and locking of minimap buttons, the bar (layout, position, dragging, lock, fading, visibility, ElvUI and Tukui movers), the Blizzard buttons (mail, tracking, calendar, queue) and the options (own dialog, Blizzard settings, ElvUI's options, profiles). The release (documentation, zip) follows in the last package.

## Scan, skinning and locking

- **Scan** (`/zmb scan`, on entering the world and every 6 seconds): every child of the minimap that is a button is taken, except names on the fixed ignore list of ProjectAzilroka (25 names such as `GameTimeFrame`, `MinimapBackdrop`, `QueueStatusButton`, `TimeManagerClockButton`), names on the own ignore list, buttons already skinned, map pins (HereBeDragons, HandyNotes, TomCat Tours, Zygor, GatherMate2, Questie, TomTom) and unnamed buttons without an icon. Nothing is scanned in combat or in a pet battle.
- **Own ignore list** (*Ignore List* in the options, see below): button names or Lua patterns; an entry matches if it equals the name or is found in it as a pattern. An invalid pattern only matches literally.
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

Seven seconds after the start (and after a profile change or when one is turned on in the options) the addon adds Blizzard's own minimap buttons to the bar, after the addon buttons found so far. As in ProjectAzilroka it only adds them: a button turned off stays in the bar until the interface is reloaded; the options then ask for a reload.

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
- **Queue**: off by default in WoW Forever until it is checked in the client, because the queue button is an Edit Mode system and moving it may cause taint. A click on the eye opens the group finder through `ToggleGroupFinderFrame()` (WoW Forever has no `PVEFrame`). If ElvUI's queue module is loaded (frame `ElvUIQueueStatus`), the addon leaves the queue button alone, because ElvUI puts it back into its own mover at once; the option is disabled then, with a hint.

## Options

`/zmb`, `/zippyminimap` and the addon compartment entry open the options dialog. The same options are in the game settings under *Square Minimap Buttons* (with *Profiles* as a subcategory) and, with ElvUI, in ElvUI's options under *Square Minimap Buttons*. The tree follows ProjectAzilroka's (labels in English and German as there); the group *Extensions* is new.

| Option | Group | Default (WoW Forever) | Range | Effect |
|---|---|---|---|---|
| *Enable* | top | on | toggle | off: reload dialog (the bar goes away with the reload); on: builds the bar if it does not exist yet |
| *Enable Bar* | General > Minimap Buttons / Bar | on | toggle | without the bar the buttons are only skinned where they are |
| *Bar MouseOver* | same | off | toggle | the bar fades out and fades in under the mouse |
| *Bar Backdrop* | same | on | toggle | backdrop of the bar |
| *Icon Size* | same | 22 | 12 to 48 | edge length of the buttons |
| *Button Spacing* | same | 2 | -1 to 10 | space between the buttons and to the edge |
| *Buttons Per Row* | same | 1 | 1 to 100 | columns per row |
| *Shadows* | same | on | toggle | shadows, only with AddOnSkins, ElvUI or Tukui |
| *Reverse Direction* | same | off | toggle | lay out from the top right |
| *Visibility* | same | `[petbattle] hide; show` | macro condition | shows or hides the bar |
| *Frame Strata* | General | `MEDIUM` | eight strata | strata of the bar and its buttons |
| *Frame Level* | General | 12 | 0 to 255 | level of the bar (buttons one higher) |
| *Hide Garrison*, *Move Garrison Icon* | General > Blizzard | off, on | toggle | no effect (as in ProjectAzilroka); each disables the other; hidden in WoW Forever and Classic |
| *Move Mail Icon* | same | on | toggle | own mail button in the bar |
| *Move Game Time Frame* | same | on | toggle | calendar button in the bar; hidden in Retail |
| *Move Tracker Icon* | same | on | toggle | tracking button in the bar; hidden in Classic |
| *Move Queue Status Icon* | same | off (Retail, Classic: on) | toggle | queue button in the bar; hidden in Classic, disabled with a hint while ElvUI's queue module holds the button |
| *Anchor to Minimap* | Extensions | on | toggle | the bar is attached to the minimap; off: free position, draggable as in ProjectAzilroka |
| *Point*, *Relative Point* | Extensions | `TOPLEFT`, `TOPLEFT` | nine points | point of the bar at the point of the minimap (only with *Anchor to Minimap*) |
| *X Offset*, *Y Offset* | Extensions | 1, -1 | -200 to 200 | offset from the minimap (only with *Anchor to Minimap*) |
| *Lock Bar* | Extensions | off | toggle | the bar cannot be dragged |
| *Ignore List* | Extensions | empty | one entry per line | frame names or Lua patterns of buttons that stay on the minimap; blank lines and spaces around an entry are dropped; scans again at once, a button already in the bar stays until the next reload |

- Changes to *General* rebuild the bar, changes to *Blizzard* build the buttons turned on at once; turning off a Blizzard button that is already in the bar shows the reload dialog. In combat both wait until combat ends.
- With ElvUI's or Tukui's mover the mover holds the position of the bar: the group *Extensions* says so, and *Anchor to Minimap*, the points and the offsets are disabled.
- **Profiles**: the profile page of AceDBOptions (choose, create, copy, delete, reset); one profile per character by default. A profile change rebuilds the bar. The settings are saved in `SquareMinimapButtonsDB`.
- **ElvUI**: if ElvUI's plugin library is there, the addon registers as a plugin and adds its options (without the profiles, ElvUI has its own) to ElvUI's options when ElvUI loads them.

## Origin and permission

The code is ported from ProjectAzilroka's module `Modules/SquareMinimapButtons.lua` and the helpers of its core. Zippy reports that Azilroka personally allowed the port of this part of ProjectAzilroka to WoW Forever (reported on 2026-11-05); the written record of the permission will be added to `LICENSE.txt`. The addon keeps Azilroka's name for the module and the ProjectAzilroka copyright notice.

If ProjectAzilroka is loaded at the same time and its Square Minimap Buttons module is enabled, this addon stays inactive and says so once in the chat. The same happens, with its own message, when ProjectAzilroka is loaded but its settings cannot be read.

## Install

1. Copy the folder `SquareMinimapButtons` into the `Interface\AddOns` folder of your WoW Forever installation, so that `Interface\AddOns\SquareMinimapButtons\SquareMinimapButtons.toc` exists. A release zip follows with version 1.0.0.
2. Restart the game and enable **Square Minimap Buttons** in the addon list.

## Slash commands

| Command | Effect |
|---|---|
| `/zmb` or `/zippyminimap` | open the options dialog |
| `/zmb scan` | scan the minimap for new buttons now |
| `/zmb reset` | reset the current profile to the defaults |

The addon compartment entry opens the options as well.

## Changes from the original

Each change below is part of this version; most can be switched off or are set so that the original behavior results.

- Client detection for WoW Forever (`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`); ProjectAzilroka knows only Retail and Classic.
- Default profile after Zippy's classic UI: one column of 22 px buttons, anchored inside the top left corner of the minimap (`ButtonsPerRow` 1, `IconSize` 22; ProjectAzilroka: 12 and 20, bar at the right screen edge).
- *Move Queue Status Icon* is off by default in WoW Forever (on in Retail and Classic, as in ProjectAzilroka), and has no effect while ElvUI's queue module holds the queue button.
- Blizzard buttons in WoW Forever: tracking button moved without hiding its tracking frame, own calendar branch (ProjectAzilroka's `GameTimeTexture` does not exist there), queue click through `ToggleGroupFinderFrame()`.
- The own backdrop without ElvUI has a black border (ProjectAzilroka: dark grey).
- New settings in the group *Extensions*: anchor the bar to the minimap (point, relative point, offset), lock the bar, an own ignore list.
- Options per client after this port's detection: the garrison options are hidden in WoW Forever (they have no effect), mail, tracking, calendar and queue are shown.
- Turning off a Blizzard button that is already in the bar shows the reload dialog (ProjectAzilroka keeps the button until a reload without saying so). *Enable* turned on again before the reload only rebuilds the bar.
- Option changes in combat wait until combat ends (the bar and the Blizzard buttons).
- The options are in the game settings (with a profiles subcategory), in an own dialog and, with ElvUI, in ElvUI's options; ProjectAzilroka uses ElvUI's options or the game settings.
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
