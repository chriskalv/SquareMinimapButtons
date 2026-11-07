# Square Minimap Buttons

Port of the *Square Minimap Buttons* module of [ProjectAzilroka](https://github.com/Azilroka/ProjectAzilroka) by Azilroka to **WoW Forever** (Interface 16001), as a standalone addon, with Azilroka's permission. It collects the minimap buttons of other addons into a bar and skins them square, like the original module.

> **Version 1.0.0.** Functionally complete; the first release waits for the checks in the WoW Forever client listed below (see [Known limits and client checks](#known-limits-and-client-checks)). Changes per version are in [`CHANGELOG.md`](CHANGELOG.md).

## What it does

### Scan, skinning and locking

- **Scan** (`/smb scan`, on entering the world and every 6 seconds): every child of the minimap that is a button is taken, except names on the fixed ignore list of ProjectAzilroka (25 names such as `GameTimeFrame`, `MinimapBackdrop`, `QueueStatusButton`, `TimeManagerClockButton`), buttons already skinned, map pins (HereBeDragons, HandyNotes, TomCat Tours, Zygor, GatherMate2, Questie, TomTom) and unnamed buttons without an icon. Nothing is scanned in combat or in a pet battle.
- **Skinning**: border, background and highlight textures (for example those of LibDBIcon buttons) are emptied; the other textures of the button and its direct children are fitted 1 px inside their frame (the button, or the child they belong to), without mask, and cropped like ElvUI icons if they show the full texture (0.08 per side, or after ElvUI's *cropIcon*). Mask textures are never emptied, moved or cropped; masks on a skinned texture are taken off it (see [Masks on button icons](#masks-on-button-icons)). The button gets the icon size, the strata of the minimap and its level + 10, the backdrop and, with *Shadows*, a shadow (unless the button sets `ignoreTemplate`).
- **Locking**: while a button sits in the bar, its position methods (`SetParent`, `ClearAllPoints`, `SetPoint`, `SetSize`, `SetScale`, `SetIgnoreParentScale`, `SetFrameStrata`, `SetFrameLevel`) do nothing and strata and level are fixed, so that the addon owning the button cannot move it out again.

### The bar

- **Layout**: the buttons are laid out in the order they were found, `ButtonsPerRow` per row (default 1, so one column from the top), `IconSize` 18 and `ButtonSpacing` 0 apart and from the edge, from the top left corner (with *Reverse Direction* from the top right). The bar takes the size of its buttons, gets the backdrop (*Bar Backdrop*), the strata and level of the profile (buttons one level higher) and only counts buttons that are shown. Without buttons it is hidden.
- **Position**: the bar is anchored to the minimap, its top left corner 1 px inside the top left corner of the minimap. Since the changes after the first client test there are no options for the position; the keys `AnchorToMinimap`, `Point`, `RelativePoint`, `X`, `Y` and `BarPosition` stay in the profile (defaults `true`, `TOPLEFT`, `TOPLEFT`, 1, -1, none), so that a profile set to a free position by an earlier test version keeps it: without the anchor the bar stands where it was dragged last or, if it was never dragged, at the right screen edge like in ProjectAzilroka.
- **Dragging**: without ElvUI and Tukui the bar can be dragged with the left mouse button, on the bar or on one of its buttons, but only while it is not anchored to the minimap (so not with the defaults); the position is saved in the profile. The lock (*Lock Bar*) of the first test versions is gone. With ElvUI the bar has ElvUI's mover *SquareMinimapButtonBar Anchor* (frame name `SquareMinimapButtonBarMover`, as in ProjectAzilroka, so a mover position from an ElvUI profile applies), which starts at the position from the profile; with Tukui it is registered with Tukui's movers.
- **Fading**: with *Bar MouseOver* the bar fades out and fades in while the mouse is over the bar or one of its buttons.
- **Visibility**: the bar is shown whenever it has buttons. WoW Forever has no pet battles, so the macro condition of ProjectAzilroka (*Visibility*, `[petbattle] hide; show`) and its state driver are gone.
- **Combat**: the bar is rebuilt only out of combat; a rebuild asked for in combat follows when combat ends.
- **Profiles**: changing, copying or resetting the profile sets the position again and rebuilds the bar, the Blizzard buttons and the tracker glow.

### Tracker glow

With *Glowing Tracker Icon when not tracking* (tab *Blizzard*, on by default) a red glow pulses around the tracking button while the character knows one of the gathering tracking abilities Find Herbs, Find Minerals and Find Treasure and none of them is active. It replaces Zippy's earlier WeakAura for the same purpose, which also loaded only for these three spells. Until 2026-11-07 every tracking ability counted; since then, at the owner's request, only the three gathering abilities count now, so a character without a gathering profession (for example a paladin with Sense Undead) never sees the glow.

- **Source**: `C_Minimap.GetNumTrackingTypes()` and `C_Minimap.GetTrackingInfo(i)` (`MinimapScriptTrackingInfo`: `name`, `texture`, `active`, `type`, `subType`, `spellID`). The list also holds the townsfolk and quest filters of the tracking menu (repair, flight master, banker and so on; Blizzard_Minimap `MinimapConstants`: `OPTIONAL_FILTERS`, `ALWAYS_ON_FILTERS`), which are often on, and the other tracking abilities (the hunter's tracks, Sense Undead, Sense Demons).
- **Rule**: only entries of the spells in `SMB.TrackerGlowSpells` count: Find Herbs 2383, Find Minerals 2580, Find Treasure 2481 (spell IDs from Wowhead's WoW Forever database, 2026-11-07; Find Treasure is the dwarves' racial ability; every tooltip says *Only one type of thing can be tracked at a time*). An entry belongs to one of them by its `spellID`; an entry without `spellID` belongs to it when its `name` equals `C_Spell.GetSpellName(id)`, the client's own name of the spell, so the check needs no English names and works in every language (`SMB:TrackingEntryMatches`). At least one of these entries and none of them active: glow; otherwise no glow. Other tracking abilities neither start nor end the glow: in WoW Forever only one tracking ability is active at a time, so with Sense Undead on, no herbs are tracked.
- **Examples**: a herbalist with no tracking active: glow. With Find Herbs on: no glow. With Sense Undead on instead of Find Herbs: glow. A herbalist and miner with Find Minerals on: no glow. A paladin without a gathering profession: never a glow, whether Sense Undead is on or off. A hunter's tracks alone: no glow.
- **No glow** while the character is dead or a ghost (`UnitIsDeadOrGhost("player")`) or has no full control (`HasFullControl()`, for example on a flight path), as in the WeakAura; also not with the option or *Enable* off, or while the guard against ProjectAzilroka keeps the addon inactive. Turning the option or *Enable* off hides the glow at once, without a reload.
- **Events**: `MINIMAP_UPDATE_TRACKING`, `PLAYER_ENTERING_WORLD`, `SPELLS_CHANGED`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `PLAYER_CONTROL_GAINED`, `PLAYER_CONTROL_LOST`, through the addon's AceEvent registration; also after every rebuild of the bar and every profile change.
- **Where**: on `MinimapCluster.Tracking.Button`, which is the button in the bar with *Move Tracker Icon* and Blizzard's button at the minimap without it. The glow is a frame without mouse input (`EnableMouse(false)`) 2 px outside the button, two levels above it in the button's strata, with four red edges (`SetColorTexture`, blend mode `ADD`, no texture file) and an alpha pulse 0.35 to 1 and back, 0.6 s each way (`AnimationGroup` with `SetLooping("BOUNCE")`). The button's size and hit area do not change. With *Bar MouseOver* on and the tracking button in the bar, the glow fades out with the bar and is only seen while the bar is shown (mouse over the bar); *Bar MouseOver* is off by default. Nothing of this is secret in WoW Forever: `GetTrackingInfo` only has `SecretArguments = AllowedWhenUntainted` and `C_Spell.GetSpellName` `SecretArguments = AllowedWhenTainted` (it may return nothing), neither has secret returns.
- **Clients**: WoW Forever and Retail (where the tracking button is `MinimapCluster.Tracking.Button`); hidden in Classic, like *Move Tracker Icon*.

### Masks on button icons

Some addons put a round mask on the icon of their LibDBIcon button. *Connoisseur & Restocker* does this in WoW Forever and Retail (`Features/Minimap-Button.lua:22-31` in its source, commit `a6314a9`): it sets the icon to 20 x 20 at the center, creates a mask texture with the file ID 130924 (`Interface\CharacterFrame\TempPortraitAlphaMask`) on the button and adds it to the icon with `AddMaskTexture`; the icon itself is the best food and changes at run time (`UpdateMinimapIcon`, `:41-58`).

A mask texture is a texture object too (`IsObjectType("Texture")`), and 130924 is on the list of files the skin removes (`RemoveTextureID`, `SquareMinimapButtons.lua:92`; ProjectAzilroka `Modules/SquareMinimapButtons.lua:56`), from a time when that file was only used as a visible round texture. The skin of ProjectAzilroka and of this port up to the first client test therefore emptied the mask (`SetTexture()` in `SkinMinimapButton`, ProjectAzilroka `:297-303`), and an empty mask hides the whole icon: the button in the bar was an empty frame.

Now (`SquareMinimapButtons.lua:405-458`, generic, no special case for that addon):

- `SkinMinimapButton` and `HandleRegion` skip regions whose `GetObjectType()` is `"MaskTexture"`: they are never emptied, moved or cropped, and the addon may keep its mask.
- Every texture the skin fits into the button loses its masks (`GetNumMaskTextures`, `GetMaskTexture`, `RemoveMaskTexture`): the square skin needs no round mask, and a foreign mask would cut the cropped icon. If the client returns the count or a mask as a secret value (these functions have `SecretReturnsForAspect` *Hierarchy*), nothing is changed.
- 130924 stays on the list, because as an ordinary texture it is still a round border.

The functions exist in WoW Forever (`SimpleTextureAPIDocumentation.lua`: `AddMaskTexture`, `GetMaskTexture`, `GetNumMaskTextures`, `RemoveMaskTexture`; `SimpleFrameAPIDocumentation.lua`: `CreateMaskTexture`).

### Next to ProjectAzilroka

If ProjectAzilroka is loaded at the same time and its Square Minimap Buttons module is enabled, this addon stays inactive and says so once in the chat. The same happens, with its own message, when ProjectAzilroka is loaded but its settings cannot be read. While the addon is inactive it adds no options, and `/smb` and `/smb scan` only repeat that message.

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
| `/smb`, `/squareminimap` or `/squareminimapbuttons` | open the options dialog |
| `/smb scan` | scan the minimap for new buttons now |
| `/smb reset` | reset the current profile to the defaults |
| `/smb` with anything else | print the usage (it names all three commands) |

`scan` and `reset` work with each of the three commands. If another addon already uses `/smb`, `/squareminimap` and `/squareminimapbuttons` still work. The addon compartment entry opens the options as well. `/zmb` and `/zippyminimap` of the first test versions are gone.

## Options

`/smb` (or `/squareminimap`, `/squareminimapbuttons`) and the addon compartment entry open the options dialog. It has three tabs: **General**, **Blizzard** and **Profiles**. The same tabs are in the game settings under *Square Minimap Buttons* and, with ElvUI, in ElvUI's options under *Square Minimap Buttons* (there without *Profiles*, ElvUI has its own). The settings follow ProjectAzilroka's (labels in English and German as there).

| Option | Tab | Default (WoW Forever) | Range | Effect |
|---|---|---|---|---|
| *Enable* | General | on | toggle | off: reload dialog (the bar goes away with the reload), the tracker glow goes at once; on: builds the bar if it does not exist yet |
| *Enable Bar* | General > Minimap Buttons / Bar | on | toggle | without the bar the buttons are only skinned where they are, and no Blizzard buttons are added; turning it off takes effect after a reload (the bar stays until then, without a reload dialog) |
| *Bar MouseOver* | same | off | toggle | the bar fades out and fades in under the mouse |
| *Bar Backdrop* | same | on | toggle | backdrop of the bar |
| *Icon Size* | same | 18 | 12 to 48 | edge length of the buttons |
| *Button Spacing* | same | 0 | -1 to 10 | space between the buttons and to the edge |
| *Buttons Per Row* | same | 1 | 1 to 100 | columns per row |
| *Shadows* | same | on | toggle | shadows, only with AddOnSkins, ElvUI or Tukui |
| *Reverse Direction* | same | off | toggle | lay out from the top right |
| *Frame Strata* | General | `MEDIUM` | eight strata | strata of the bar and its buttons |
| *Frame Level* | General | 12 | 0 to 255 | level of the bar (buttons one higher) |
| *Hide Garrison*, *Move Garrison Icon* | Blizzard | off, on | toggle | no effect (as in ProjectAzilroka); each disables the other; hidden in WoW Forever and Classic |
| *Move Game Time Frame* | Blizzard | on | toggle | calendar button in the bar; hidden in Retail |
| *Move Mail Icon* | Blizzard | on | toggle | own mail button in the bar |
| *Move Tracker Icon* | Blizzard | on | toggle | tracking button in the bar; hidden in Classic |
| *Glowing Tracker Icon when not tracking* | Blizzard | on | toggle | red glow around the tracking button while the character knows Find Herbs, Find Minerals or Find Treasure but none of them is active (see [Tracker glow](#tracker-glow)); hidden in Classic |
| *Move Queue Status Icon* | Blizzard | off (Retail, Classic: on) | toggle | queue button in the bar; hidden in Classic, disabled with a hint while ElvUI's queue module holds the button |
| *Reset Profile*, *New*, *Existing Profiles*, *Copy From*, *Delete a Profile* | Profiles | profile *Default* | | only the profile controls of Ace3 (AceDBOptions); entries that other addons add to AceDBOptions are not shown (see [Known limits](#known-limits-and-client-checks)) |

- The tab *General* starts with the description and the authors (*Authors:* Azilroka, Sinaris, Omega, Durc; *WoW Forever port:* Zippy).
- Changes in *General* rebuild the bar, changes in *Blizzard* build the buttons turned on at once; turning off a Blizzard button that is already in the bar shows the reload dialog. In combat both wait until combat ends. The tracker glow needs neither a rebuild nor a reload.
- **Removed after the first client test** (2026-11-06): *Visibility* (no pet battles in WoW Forever) and the group *Extensions* (*Anchor to Minimap*, *Point*, *Relative Point*, *X Offset*, *Y Offset*, *Lock Bar*, *Ignore List*, the hint about the ElvUI or Tukui mover). The bar stays anchored to the minimap as before (see [The bar](#the-bar)); the ElvUI and Tukui movers stay. Old profiles with these keys load without errors: AceDB keeps unknown keys and the addon no longer reads `Visibility`, `Lock` and `IgnoreList`.
- **Profiles**: the profile controls of AceDBOptions (reset, create, choose, copy, delete), as an own group with only the eleven standard entries of AceDBOptions-3.0 revision 17 (`SMB.ProfileOptionKeys` in `Options.lua`; a test fails if a newer Ace3 copy brings an entry that is not listed). All characters share the profile **Default** (`AceDB:New("SquareMinimapButtonsDB", defaults, true)`; AceDB maps `true` to the name `Default`). A character that an earlier test version had put on its own profile (`Name - Realm`) is moved to *Default* once, at its first login with this version (marker in the character section of `SquareMinimapButtonsDB`), and the chat says so (*this character now uses the shared profile Default*). If *Default* is still untouched (AceDB stores only values that differ from the defaults, so an untouched profile is missing or empty) and the old profile has stored values, they are copied into *Default* (`CopyProfile`, `Libs/Ace3/AceDB-3.0/AceDB-3.0.lua` 620-664), so the first character keeps its settings and all characters share them from then on; the chat line ends with *(settings copied from Name - Realm)*. If *Default* has values already (another character was there first), nothing is copied: the old profile stays and can be chosen, and *Profiles* > *Copy From* takes its settings over. A character that chooses another profile later keeps it, and a character on a profile it chose itself is left alone. A profile change rebuilds the bar. The settings are saved in `SquareMinimapButtonsDB`.
- **ElvUI**: if ElvUI's plugin library is there, the addon registers as a plugin and adds its options (the tabs *General* and *Blizzard*) to ElvUI's options when ElvUI loads them.

### Options dialog: size and why nothing overflows

Before the changes after the first client test the dialog (700 x 620) showed one page: the description, *Enable*, the inline groups *General* (with *Blizzard*) and *Extensions*, the authors and, at the bottom, a tab group with the only tab *Profiles*. The lower part reached past the frame (screenshot of the owner). Cause in the Ace3 code (`Libs/Ace3`, the same as Ace3 commit `ac3d122`): `AceConfigDialog:FeedGroup` adds a scroll frame only when the group gets no tab, tree or select control; a root with `childGroups = "tab"` and a non-inline child group (the profiles) gets none. All controls of the root are then laid out directly into the frame, and the `TabGroup` follows below them with `height = "fill"`. The flow layout of the root needs about 677 px (layout model in the tests, the multi-line ignore list counted as only 40), the content area of the frame was 620 - 57 = 563.

Now the root holds only the three tabs. `FeedGroup` puts the `TabGroup` into the frame and, for the selected tab, a `ScrollFrame` into the tab (the tab's group has no further non-inline child groups), so a tab scrolls instead of overflowing. The default size is **640 x 560** (`SetDefaultSize`), measured after the fixed heights of the AceGUI widgets:

| Part | Width | Height | Source |
|---|---|---|---|
| Frame content | width - 34 | height - 57 | `AceGUIContainer-Frame.lua`, `OnWidthSet`, `OnHeightSet` |
| Tab content (one row of tabs, no title) | - 60 | - (10 + 20 + 23) = - 53 | `AceGUIContainer-TabGroup.lua`, `BuildTabs`, `OnWidthSet`, `OnHeightSet` |
| Tab area at 640 x 560 | 546 | 450 | |
| Inline group | content - 20 | content + 40 | `AceGUIContainer-InlineGroup.lua` |
| Flow layout | rows of controls | + 3 per row | `AceGUI-3.0.lua`, layout `Flow` |
| Checkbox, slider, dropdown with label, heading | 170 (`width_multiplier`) or full | 24, 44 (align 25), 40 (align 26), 18 | widget files, `AceConfigDialog-3.0.lua` |
| Labels | full | font height, estimated 12 / 14 / 18 for small / medium / large | `AceGUIWidget-Label.lua` |

- **General**: description 12, *Authors:* 18, the authors 18, port line 14, *Enable* 24, *Minimap Buttons / Bar* 3 rows (24, 47, 24) + 40 = 144, *Frame Strata* and *Frame Level* in one row 48, each row + 3: **299 of 450**.
- **Blizzard**: one toggle per row (full width, so the long label of the tracker glow fits), 24 + 3 each: WoW Forever 5 toggles **135**, Retail 6 toggles 162, Classic 2 toggles 54.
- **Profiles** (the eleven entries of AceDBOptions): descriptions small, the current profile 170 wide next to *Reset Profile* (button 24), *New* (edit box 44, double width), the three dropdowns 40 (double width), every line break of the texts one more line: **374 of 450** in English and German, the longest tab; the earlier estimate by hand was about 390 to 430. Entries that other addons add to AceDBOptions would add rows; the tab does not show them.
- Width 640 leaves 546: three controls of 170 per row (510), also inside the inline group (526), and the double-width profile fields (340).

The tests rebuild the flow layout from the options table (`test_options.lua`, "layout of the dialog") and check General, Blizzard and Profiles in WoW Forever, Retail, Classic, with ElvUI and in German. ElvUI's skin for Ace3 (`ElvUI/Game/Shared/Modules/Skins/Ace3.lua`, `Ace3_RegisterAsContainer`) only changes textures and backdrops of the containers and makes the checkbox square inside the same 24 px; it does not change any of the sizes above. In the game settings the same tabs are shown in Blizzard's settings canvas; each tab scrolls there as well. The profiles are a tab now, so the former subcategory *Profiles* in the game settings is gone.

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
- Default profile after Zippy's classic UI: one column of 18 px buttons without spacing, anchored inside the top left corner of the minimap (`ButtonsPerRow` 1, `IconSize` 18, `ButtonSpacing` 0; ProjectAzilroka: 12 and 20, bar at the right screen edge). The profile *Default* is shared by all characters (ProjectAzilroka uses the profiles of its own database).
- The own backdrop without ElvUI has a black border (ProjectAzilroka: dark grey).
- The bar is anchored to the minimap (keys in the profile, no options); a profile from an earlier test version with a free position keeps it.
- No *Visibility* option and no state driver: WoW Forever has no pet battles; the bar is shown whenever it has buttons.
- Mask textures are never emptied, and masks are taken off the skinned icons (ProjectAzilroka empties a mask with the file 130924, which hides the masked icon, for example of *Connoisseur & Restocker*).
- New option *Glowing Tracker Icon when not tracking* (red glow on the tracking button while the character tracks nothing).
- The options are three tabs (*General*, *Blizzard*, *Profiles*) instead of one page; the Blizzard toggles have a fixed order (ProjectAzilroka sorts them by name) so that the tracker glow stands under the tracker toggle.
- The tab *Profiles* is an own group with only the standard entries of AceDBOptions (ProjectAzilroka uses the table of AceDBOptions itself, which shows the entries of other addons too, see [Known limits](#known-limits-and-client-checks)).
- The first switch of an existing character to the shared profile *Default* copies its settings while *Default* is untouched (ProjectAzilroka has no shared profile).
- Without ElvUI and Tukui the bar itself can be dragged when it is not anchored to the minimap (ProjectAzilroka registers it for dragging but only its buttons move it), and its position is kept in the profile instead of the client's layout cache.
- Buttons that already sit in the bar are counted when they are shown, not when they are visible: in ProjectAzilroka a rebuild while the bar is hidden counted no buttons and hid the bar for good.
- Without buttons the bar stays hidden: ProjectAzilroka hid it and then faded it in again, which showed an empty strip.
- After adding the Blizzard buttons the bar is rebuilt in combat too (the rebuild waits until combat ends); ProjectAzilroka skipped it in combat, so new buttons stayed without a position until the next rebuild.
- A rebuild asked for in combat waits until combat ends; so do the Blizzard buttons after an option or profile change in combat.
- Turning off a Blizzard button that is already in the bar shows the reload dialog (ProjectAzilroka keeps the button until a reload without saying so). *Enable* turned on again before the reload only rebuilds the bar instead of asking for a reload.
- Profile changes, copies and resets rebuild the bar and the Blizzard buttons (ProjectAzilroka only rereads the settings).
- An ElvUI or Tukui that is enabled but not loaded does not cause an error; the bar can then be dragged.
- The backdrop of the bar is removed and the class color border on mouse-over is set only on frames that have the backdrop methods (frames skinned by AddOnSkins may lack them).
- The queue frame starts with the mouse state that matches the queue button (ProjectAzilroka set it only when the queue button was shown or hidden).
- Options per client after this port's detection: the garrison options are hidden in WoW Forever (they have no effect), mail, tracking, calendar and queue are shown.
- The options are in the game settings, in an own dialog and, with ElvUI, in ElvUI's options; ProjectAzilroka uses ElvUI's options or the game settings. They are registered only when the guard lets the addon run.
- Own slash commands `/smb`, `/squareminimap` and `/squareminimapbuttons` (ProjectAzilroka has none for the module).
- Unused code of the original (`CheckTexture`, `SMB.Hider`) is left out.

## Known limits and client checks

- The automatic tests run the Lua code outside the game with stubs of the WoW API; drawing, taint and Edit Mode can only be checked in the client.
- A Blizzard button that is already in the bar stays there until the interface is reloaded, also when it is turned off.
- There is no own ignore list any more (removed after the first client test); a button of another addon that should stay on the minimap cannot be excluded.
- Masks on button icons: masks are taken off the icons the skin fits in, and mask textures stay as their addon made them; an addon that adds a mask only after the scan keeps it on its icon (round icon in the square button).
- Tracker glow: only the entries of Find Herbs, Find Minerals and Find Treasure count; whether WoW Forever reports their `spellID` in `GetTrackingInfo` or only their name is to be checked in the client (C11). The name fallback (`C_Spell.GetSpellName`) covers the second case; an entry that has neither a matching `spellID` nor the client's name of the spell does not count.
- Tracker glow with *Bar MouseOver*: the glow is a child of the tracking button and fades out with the bar, so it only reminds while the bar is shown. Whether the glow should show the bar is open.
- Tracker glow pulse: if the client stops the animation while the interface is hidden (Alt+Z, cinematics), it starts again when the glow shows; to be checked in the client (C11).
- *Lock Bar* is gone; with a profile from an earlier test version that has a free position, the bar can be dragged and is not locked.
- *Enable Bar* turned off leaves the bar and its buttons in place until the interface is reloaded, as in ProjectAzilroka.
- The garrison options have no effect, as in ProjectAzilroka.
- Whether Tukui runs in WoW Forever is not checked; its branch stays as in the original.
- If the client does not keep the saved variables, the defaults apply at every start and changes are lost (check C9).
- Profiles of other addons: AceDBOptions keeps one table of profile entries for all addons. `AceDBOptions:GetOptionsTable(db)` returns a table per database, but sets its `args` to the same module-wide `optionsTable` every time (`Libs/Ace3/AceDBOptions-3.0/AceDBOptions-3.0.lua`, revision 17: table 360-453, `tbl.args = optionsTable` in `GetOptionsTable` 461-472, the same in the upgrade loop 475-479). An addon that writes its own entries into these `args` adds them to the profile page of every addon that shows that table. RestedXP does this (github.com/RestedXP/RXPGuides, commit `9115424`, `SettingsPanel.lua` 3578-3624: *Reload guides and UI*, *Reset Guide Progress*, a header and *Set current profile as default*), and these buttons appeared in the tab *Profiles* of this addon (screenshot of the owner, 2026-11-06). The tab is therefore an own group: name, description and handler come from the table of AceDBOptions, the entries only from the list of the eleven standard keys, each the library's own entry (their `get`, `set`, `values`, `disabled` and `func` are method names, which AceConfig resolves against the handler that the group passes down, `AceConfigDialog-3.0.lua` 191-205 and 669-699). AceDBOptions upgrades the handler in place (`getOptionsHandler` 341-353), and the tab is built at login; a newer copy of the library that another addon loads later (load on demand) upgrades the handler in place, while the tab keeps the entries of the copy loaded at login (the method names are the same). An addon that replaces one of the eleven standard entries with its own would still be seen here.
- First switch to *Default*: the copy takes every value stored in the old profile, including keys that no longer have a control (for example the removed *Lock*, *Visibility* and ignore list). An old profile that holds only such keys is copied as well, and the chat says *settings copied from Name - Realm* although nothing visible changes. A character whose marker an earlier test build (part 1 of this update) had already set is not switched or copied again; there *Profiles* > *Copy From* takes the old settings over.

Checks in the WoW Forever client, once with ElvUI and once without:

- [ ] **C1**: the addon loads without errors; `/smb`, `/squareminimap` and `/squareminimapbuttons` open the dialog; without ProjectAzilroka there is no guard message; the dialog at its default size shows the tabs *General*, *Blizzard* and *Profiles*, and nothing reaches past the frame.
- [ ] **C2**: LibDBIcon buttons become square, without the round border, with the icon cropped; map pins (HandyNotes, TomTom, Questie, if used) stay on the map; *Connoisseur & Restocker* shows its food icon (not an empty frame).
- [ ] **C3**: the bar matches the screenshot in column, border, backdrop and position; size 18 and spacing 0 are the defaults the owner chose on 2026-11-06, the screenshot showed 22 and 2.
- [ ] **C4**: tracking and calendar button in the bar: a click opens the menu or the calendar; the tracking button stays visible, the mail indicator does not jump; `taintLog` has no entries from this addon.
- [ ] **C5**: queue option on (without ElvUI): the eye is in the bar, a click opens the group finder, opening and closing Edit Mode and scaling the minimap cause no taint errors and no jump back; only then consider turning the option on by default.
- [ ] **C6**: together with ElvUI's minimap (tracking position, calendar, mail indicator, `ElvUI_MinimapHolder`) and ElvUI's queue module (option *Move Queue Status Icon* disabled, the eye at ElvUI's queue status mover, no empty frame in the bar).
- [ ] **C7**: mail button green with new mail, tooltip with the senders; the icons `INV_Letter_15` and `LFG-Eye` exist.
- [ ] **C8**: the bar is shown while it has buttons; fading with *Bar MouseOver*.
- [ ] **C9**: saved variables: change a setting, restart the client, the value is still there; a second character uses the same profile *Default*; the existing character from the first test is on *Default* and has its old values (the chat says *settings copied from Name - Realm*), its old profile is still in the list.
- [ ] **C10**: options in the game settings and, with ElvUI, in ElvUI's options (the same tabs); a profile change rebuilds the bar.
- [ ] **C11**: tracker glow: a herbalist (or miner) with no tracking active sees the tracking button pulse red (in the bar and, with *Move Tracker Icon* off, at the minimap); casting Find Herbs ends it, cancelling it starts it again; with Sense Undead (or another tracking ability) on instead of Find Herbs, the glow shows; a character without a gathering profession never sees it; no glow while dead, as a ghost or on a flight path; clicks on the tracking button still open its menu; after Alt+Z and back the glow still pulses. In a client with another language than English the glow behaves the same.
- [ ] **C12**: with RestedXP installed the tab *Profiles* shows no buttons *Reload guides and UI* or *Reset Guide Progress* (nor *Set current profile as default*); the profile controls work: *Reset Profile*, *New*, choosing an existing profile, *Copy From*, *Delete a Profile*.

## Credits and license

- **Azilroka**: ProjectAzilroka and the Square Minimap Buttons module, with **Sinaris**, **Omega** and **Durc** as authors of the module.
- **Zippy**: port to WoW Forever.
- **Ace3** (WoWUIDev/Ace3): addon framework, embedded unmodified (commit `ac3d122`).

The code is ported from ProjectAzilroka's module `Modules/SquareMinimapButtons.lua`, the helpers of its core and the option labels of its locales. Zippy reports that Azilroka personally allowed the port of this part of ProjectAzilroka to WoW Forever (reported on 2026-11-05); the written record of the permission will be added to `LICENSE.txt`. The addon keeps Azilroka's name for the module and the ProjectAzilroka copyright notice.

- Parts taken from ProjectAzilroka: ProjectAzilroka License (copyright notice kept), used with Azilroka's permission; the license text and the notes on the port are in `LICENSE.txt`.
- Ace3: BSD license of the Ace3 Development Team, see `Libs/Ace3/LICENSE.txt`.
