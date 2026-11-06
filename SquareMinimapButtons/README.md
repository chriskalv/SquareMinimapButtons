# Square Minimap Buttons

Port of the *Square Minimap Buttons* module of [ProjectAzilroka](https://github.com/Azilroka/ProjectAzilroka) by Azilroka to **WoW Forever** (Interface 16001), as a standalone addon, with Azilroka's permission. It collects the minimap buttons of other addons into a bar and skins them square, like the original module.

> **Version 1.0.0.** Functionally complete; the first release waits for the checks in the WoW Forever client listed below (see [Known limits and client checks](#known-limits-and-client-checks)). Changes per version are in [`CHANGELOG.md`](CHANGELOG.md).

## What it does

### Scan, skinning and locking

- **Scan** (`/zmb scan`, on entering the world and every 6 seconds): every child of the minimap that is a button is taken, except names on the fixed ignore list of ProjectAzilroka (25 names such as `GameTimeFrame`, `MinimapBackdrop`, `QueueStatusButton`, `TimeManagerClockButton`), names on the own ignore list, buttons already skinned, map pins (HereBeDragons, HandyNotes, TomCat Tours, Zygor, GatherMate2, Questie, TomTom) and unnamed buttons without an icon. Nothing is scanned in combat or in a pet battle.
- **Own ignore list** (*Ignore List* in the options): button names or Lua patterns; an entry matches if it equals the name or is found in it as a pattern. An invalid pattern only matches literally.
- **Skinning**: border, background and highlight textures (for example those of LibDBIcon buttons) are emptied; the other textures of the button and its direct children are fitted 1 px inside their frame (the button, or the child they belong to), without mask, and cropped like ElvUI icons if they show the full texture (0.08 per side, or after ElvUI's *cropIcon*). The button gets the icon size, the strata of the minimap and its level + 10, the backdrop and, with *Shadows*, a shadow (unless the button sets `ignoreTemplate`).
- **Locking**: while a button sits in the bar, its position methods (`SetParent`, `ClearAllPoints`, `SetPoint`, `SetSize`, `SetScale`, `SetIgnoreParentScale`, `SetFrameStrata`, `SetFrameLevel`) do nothing and strata and level are fixed, so that the addon owning the button cannot move it out again.

### The bar

- **Layout**: the buttons are laid out in the order they were found, `ButtonsPerRow` per row (default 1, so one column from the top), `IconSize` 18 and `ButtonSpacing` 0 apart and from the edge, from the top left corner (with *Reverse Direction* from the top right). The bar takes the size of its buttons, gets the backdrop (*Bar Backdrop*), the strata and level of the profile (buttons one level higher) and only counts buttons that are shown. Without buttons it is hidden.
- **Position**: by default the bar is anchored to the minimap, its top left corner 1 px inside the top left corner of the minimap (point, relative point and offset in the profile). Without that anchor it stands where it was dragged last (saved in the profile) or, if it was never dragged, at the right screen edge like in ProjectAzilroka.
- **Dragging and lock**: without ElvUI and Tukui the bar is dragged with the left mouse button, on the bar or on one of its buttons; the position is saved in the profile. Nothing moves while the bar is anchored to the minimap or locked (*Lock Bar*). With ElvUI the bar has ElvUI's mover *SquareMinimapButtonBar Anchor* (frame name `SquareMinimapButtonBarMover`, as in ProjectAzilroka, so a mover position from an ElvUI profile applies), which starts at the position from the profile; with Tukui it is registered with Tukui's movers.
- **Fading**: with *Bar MouseOver* the bar fades out and fades in while the mouse is over the bar or one of its buttons.
- **Visibility**: a macro condition (*Visibility*, default `[petbattle] hide; show`) shows or hides the bar.
- **Combat**: the bar is rebuilt only out of combat; a rebuild asked for in combat follows when combat ends.
- **Profiles**: changing, copying or resetting the profile sets the position again and rebuilds the bar and the Blizzard buttons.

### Next to ProjectAzilroka

If ProjectAzilroka is loaded at the same time and its Square Minimap Buttons module is enabled, this addon stays inactive and says so once in the chat. The same happens, with its own message, when ProjectAzilroka is loaded but its settings cannot be read. While the addon is inactive it adds no options, and `/zmb` and `/zmb scan` only repeat that message.

## Requirements

- **WoW Forever** (Interface 16001). The TOC lists only this client. The code keeps ProjectAzilroka's branches for Retail and Classic, but they are not tested in those clients.
- No required dependencies: the libraries (Ace3) are embedded.
- Optional: **ElvUI** (backdrop and shadows through ElvUI's frame API, icon crop after ElvUI's *cropIcon*, ElvUI's mover, the options in ElvUI's options), **Tukui** (backdrop and shadows through its frame API, Tukui's movers) and **AddOnSkins** (backdrop and shadows through AddOnSkins). Without them the addon draws its own backdrop and has no shadows.

## Installation

1. Download `SquareMinimapButtons-<version>.zip` from the [Releases](https://github.com/chriskalv/ZippyAddOns/releases) page of this repository; it appears there with the first release.
2. Extract it into the `Interface\AddOns` folder of your WoW Forever installation, so that `Interface\AddOns\SquareMinimapButtons\SquareMinimapButtons.toc` exists. The folder name must stay `SquareMinimapButtons`.
3. Restart the game and enable **Square Minimap Buttons** in the addon list.

Alternatively copy the folder `SquareMinimapButtons` from the repository into `Interface\AddOns` (same result as the zip).

## Slash commands

| Command | Effect |
|---|---|
| `/zmb` or `/zippyminimap` | open the options dialog |
| `/zmb scan` | scan the minimap for new buttons now |
| `/zmb reset` | reset the current profile to the defaults |
| `/zmb` with anything else | print the usage |

The addon compartment entry opens the options as well.

## Options

`/zmb`, `/zippyminimap` and the addon compartment entry open the options dialog. The same options are in the game settings under *Square Minimap Buttons* (with *Profiles* as a subcategory) and, with ElvUI, in ElvUI's options under *Square Minimap Buttons*. The tree follows ProjectAzilroka's (labels in English and German as there); the group *Extensions* is new.

| Option | Group | Default (WoW Forever) | Range | Effect |
|---|---|---|---|---|
| *Enable* | top | on | toggle | off: reload dialog (the bar goes away with the reload); on: builds the bar if it does not exist yet |
| *Enable Bar* | General > Minimap Buttons / Bar | on | toggle | without the bar the buttons are only skinned where they are, and no Blizzard buttons are added; turning it off takes effect after a reload (the bar stays until then, without a reload dialog) |
| *Bar MouseOver* | same | off | toggle | the bar fades out and fades in under the mouse |
| *Bar Backdrop* | same | on | toggle | backdrop of the bar |
| *Icon Size* | same | 18 | 12 to 48 | edge length of the buttons |
| *Button Spacing* | same | 0 | -1 to 10 | space between the buttons and to the edge |
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
| *Ignore List* | Extensions | empty | one entry per line | frame names or Lua patterns of buttons that stay on the minimap; blank lines, duplicates and spaces around an entry are dropped; scans again at once, a button already in the bar stays until the next reload |

- Changes to *General* rebuild the bar, changes to *Blizzard* build the buttons turned on at once; turning off a Blizzard button that is already in the bar shows the reload dialog. In combat both wait until combat ends.
- With ElvUI's or Tukui's mover the mover holds the position of the bar: the group *Extensions* says so, and *Anchor to Minimap*, the points and the offsets are disabled; *Lock Bar* stays available.
- **Profiles**: the profile page of AceDBOptions (choose, create, copy, delete, reset); one profile per character by default. A profile change rebuilds the bar. The settings are saved in `SquareMinimapButtonsDB`.
- **ElvUI**: if ElvUI's plugin library is there, the addon registers as a plugin and adds its options (without the profiles, ElvUI has its own) to ElvUI's options when ElvUI loads them.

## Blizzard buttons

Seven seconds after the start (and after a profile change or when one is turned on in the options) the addon adds Blizzard's own minimap buttons to the bar, after the addon buttons found so far; only with *Enable Bar*. As in ProjectAzilroka it only adds them: a button turned off stays in the bar until the interface is reloaded; the options then ask for a reload.

| Button | Setting | WoW Forever | Retail | Classic |
|---|---|---|---|---|
| Mail: own button with a letter icon, green while there is unread mail, tooltip with the latest senders | *Move Mail Icon* | yes | yes | yes |
| Tracking: Blizzard's tracking button | *Move Tracker Icon* | yes | yes | no |
| Queue: own button with the eye, Blizzard's queue button on top of it while queued | *Move Queue Status Icon* | yes, off by default | yes | no |
| Calendar: Blizzard's calendar button | *Move Game Time Frame* | yes | no | yes |
| Garrison | *Hide Garrison*, *Move Garrison Icon* | no effect (as in ProjectAzilroka, whose code for it is disabled) | | |

## Notes for WoW Forever

- **Secret values when cropping**: WoW Forever can return values as secret values. Texture coordinates that are secret (checked with `issecretvalue` where the client has it) or not numbers are not compared; such an icon keeps its coordinates instead of being cropped.
- **Tracking**: in WoW Forever the tracking button's `Show` shows or hides its whole tracking frame, so ProjectAzilroka's call would hide it. The addon shows the tracking frame instead and moves only the button into the bar.
- **Calendar**: the WoW Forever calendar button has no `GameTimeTexture` (ProjectAzilroka would stop with an error there). The addon makes Blizzard's own textures of the button transparent and shows its own calendar icon (the atlas of Blizzard's button) inside the square frame; a click still opens the calendar.
- **Queue click and ElvUI lock**: the queue button is off by default in WoW Forever until it is checked in the client, because it is an Edit Mode system and moving it may cause taint. A click on the eye opens the group finder through `ToggleGroupFinderFrame()` (WoW Forever has no `PVEFrame`). If ElvUI's queue module is loaded (frame `ElvUIQueueStatus`), the addon leaves the queue button alone, because ElvUI puts it back into its own mover at once; the option is disabled then, with a hint.
- **Garrison hidden**: ProjectAzilroka's code for the garrison button is disabled, so the two garrison options have no effect; in WoW Forever (and Classic) they are hidden.

## Differences from ProjectAzilroka

Each difference below is part of this version; where possible it can be switched off or is set so that the original behavior results.

- Client detection for WoW Forever (`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`) with its own branches for the Blizzard buttons; ProjectAzilroka knows only Retail and Classic.
- Blizzard buttons in WoW Forever: tracking button moved without hiding its tracking frame, own calendar branch (ProjectAzilroka's `GameTimeTexture` does not exist there), queue click through `ToggleGroupFinderFrame()`.
- *Move Queue Status Icon* is off by default in WoW Forever (on in Retail and Classic, as in ProjectAzilroka) and disabled while ElvUI's queue module holds the queue button.
- Texture coordinates that the client returns as secret values are not compared.
- Default profile after Zippy's classic UI: one column of 18 px buttons without spacing, anchored inside the top left corner of the minimap (`ButtonsPerRow` 1, `IconSize` 18, `ButtonSpacing` 0; ProjectAzilroka: 12 and 20, bar at the right screen edge).
- The own backdrop without ElvUI has a black border (ProjectAzilroka: dark grey).
- New settings in the group *Extensions*: anchor the bar to the minimap (point, relative point, offset), lock the bar, an own ignore list next to the fixed one.
- Without ElvUI and Tukui the bar itself can be dragged (ProjectAzilroka registers it for dragging but only its buttons move it), and its position is kept in the profile instead of the client's layout cache.
- Buttons that already sit in the bar are counted when they are shown, not when they are visible: in ProjectAzilroka a rebuild while the bar is hidden (pet battle) counted no buttons and removed the visibility condition of the bar.
- Without buttons the bar stays hidden: ProjectAzilroka hid it and then faded it in again, which showed an empty strip.
- After adding the Blizzard buttons the bar is rebuilt in combat too (the rebuild waits until combat ends); ProjectAzilroka skipped it in combat, so new buttons stayed without a position until the next rebuild.
- A rebuild asked for in combat waits until combat ends; so do the Blizzard buttons after an option or profile change in combat.
- Turning off a Blizzard button that is already in the bar shows the reload dialog (ProjectAzilroka keeps the button until a reload without saying so). *Enable* turned on again before the reload only rebuilds the bar instead of asking for a reload.
- Profile changes, copies and resets rebuild the bar and the Blizzard buttons (ProjectAzilroka only rereads the settings).
- An ElvUI or Tukui that is enabled but not loaded does not cause an error; the bar can then be dragged.
- The backdrop of the bar is removed and the class color border on mouse-over is set only on frames that have the backdrop methods (frames skinned by AddOnSkins may lack them).
- The queue frame starts with the mouse state that matches the queue button (ProjectAzilroka set it only when the queue button was shown or hidden).
- Options per client after this port's detection: the garrison options are hidden in WoW Forever (they have no effect), mail, tracking, calendar and queue are shown.
- The options are in the game settings (with a profiles subcategory), in an own dialog and, with ElvUI, in ElvUI's options; ProjectAzilroka uses ElvUI's options or the game settings. They are registered only when the guard lets the addon run.
- Own slash commands `/zmb` and `/zippyminimap` (ProjectAzilroka has none for the module).
- Unused code of the original (`CheckTexture`, `SMB.Hider`) is left out.

## Known limits and client checks

- The automatic tests run the Lua code outside the game with stubs of the WoW API; drawing, taint and Edit Mode can only be checked in the client.
- A button that is already in the bar stays there until the interface is reloaded, also when it is added to the own ignore list or (for Blizzard buttons) turned off.
- *Enable Bar* turned off leaves the bar and its buttons in place until the interface is reloaded, as in ProjectAzilroka.
- The garrison options have no effect, as in ProjectAzilroka.
- Whether Tukui runs in WoW Forever is not checked; its branch stays as in the original.
- If the client does not keep the saved variables, the defaults apply at every start and changes are lost (check C9).

Checks in the WoW Forever client, once with ElvUI and once without:

- [ ] **C1**: the addon loads without errors; `/zmb` opens the dialog; without ProjectAzilroka there is no guard message.
- [ ] **C2**: LibDBIcon buttons become square, without the round border, with the icon cropped; map pins (HandyNotes, TomTom, Questie, if used) stay on the map.
- [ ] **C3**: the bar matches the screenshot in column, border, backdrop and position; size 18 and spacing 0 are the defaults the owner chose on 2026-11-06, the screenshot showed 22 and 2.
- [ ] **C4**: tracking and calendar button in the bar: a click opens the menu or the calendar; the tracking button stays visible, the mail indicator does not jump; `taintLog` has no entries from this addon.
- [ ] **C5**: queue option on (without ElvUI): the eye is in the bar, a click opens the group finder, opening and closing Edit Mode and scaling the minimap cause no taint errors and no jump back; only then consider turning the option on by default.
- [ ] **C6**: together with ElvUI's minimap (tracking position, calendar, mail indicator, `ElvUI_MinimapHolder`) and ElvUI's queue module (option *Move Queue Status Icon* disabled, the eye at ElvUI's queue status mover, no empty frame in the bar).
- [ ] **C7**: mail button green with new mail, tooltip with the senders; the icons `INV_Letter_15` and `LFG-Eye` exist.
- [ ] **C8**: visibility `[petbattle] hide; show` (is `[petbattle]` evaluated?), fading with *Bar MouseOver*, dragging and *Lock Bar*.
- [ ] **C9**: saved variables: change a setting, restart the client, the value is still there.
- [ ] **C10**: options in the game settings and, with ElvUI, in ElvUI's options; a profile change rebuilds the bar.

## Credits and license

- **Azilroka**: ProjectAzilroka and the Square Minimap Buttons module, with **Sinaris**, **Omega** and **Durc** as authors of the module.
- **Zippy**: port to WoW Forever.
- **Ace3** (WoWUIDev/Ace3): addon framework, embedded unmodified (commit `ac3d122`).

The code is ported from ProjectAzilroka's module `Modules/SquareMinimapButtons.lua`, the helpers of its core and the option labels of its locales. Zippy reports that Azilroka personally allowed the port of this part of ProjectAzilroka to WoW Forever (reported on 2026-11-05); the written record of the permission will be added to `LICENSE.txt`. The addon keeps Azilroka's name for the module and the ProjectAzilroka copyright notice.

- Parts taken from ProjectAzilroka: ProjectAzilroka License (copyright notice kept), used with Azilroka's permission; the license text and the notes on the port are in `LICENSE.txt`.
- Ace3: BSD license of the Ace3 Development Team, see `Libs/Ace3/LICENSE.txt`.
