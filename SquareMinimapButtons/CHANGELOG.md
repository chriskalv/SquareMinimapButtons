# Changelog

## 1.0.0 (2026-11-06)

First version: the *Square Minimap Buttons* module of ProjectAzilroka by Azilroka as a standalone addon for WoW Forever (Interface 16001), ported with Azilroka's permission. Details are in [`README.md`](README.md).

- **Scan and skin**: collects the buttons of other addons from the minimap (on entering the world, every 6 seconds and with `/smb scan`, not in combat or pet battles), skips ProjectAzilroka's fixed ignore list, map pins and unnamed buttons without an icon, and skins the buttons square with cropped icons, backdrop and, with AddOnSkins, ElvUI or Tukui, shadows.
- **Bar**: lays the buttons out in rows (default one column of 18 px buttons without spacing), with backdrop, strata and level, fading on mouse-over; anchored inside the top left corner of the minimap.
- **Lock**: the position methods of a button in the bar are locked so that its addon cannot move it out again.
- **Blizzard buttons**: mail, tracking, calendar and queue in the bar, with branches for WoW Forever (tracking frame kept visible, own calendar branch, queue click through `ToggleGroupFinderFrame()`, queue off by default and left alone while ElvUI's queue module holds it); the garrison options have no effect, as in ProjectAzilroka, and are hidden in WoW Forever.
- **Options**: the settings of ProjectAzilroka in three tabs (*General*, *Blizzard*, *Profiles*), in an own dialog (`/smb`, `/squareminimap`, `/squareminimapbuttons`, addon compartment), in the game settings and, with ElvUI, in ElvUI's options; changes in combat wait until combat ends; turning off a Blizzard button that is already in the bar asks for a reload.
- **Profiles**: AceDB profiles in `SquareMinimapButtonsDB` with the profile page of AceDBOptions; all characters share the profile *Default*; changing, copying or resetting a profile rebuilds the bar; `/smb reset` resets the current profile.
- **Tracker glow**: a red glow pulses around the tracking button while the character knows Find Herbs, Find Minerals or Find Treasure and none of them is active (*Glowing tracking icon*: always, only outside of raid instances, the default, or off).
- **ElvUI and Tukui movers**: with ElvUI the bar has ElvUI's mover *SquareMinimapButtonBar Anchor* (frame `SquareMinimapButtonBarMover`, as in ProjectAzilroka), with Tukui it is registered with Tukui's movers; an enabled but not loaded ElvUI or Tukui causes no error.
- **Guard**: stays inactive while ProjectAzilroka is loaded with its Square Minimap Buttons module enabled (or its settings cannot be read), and says so once in the chat.

### Changes after the first client test (2026-11-06)

Version 1.0.0 is not released yet; these changes go into it.

- Slash commands: `/smb` with the aliases `/squareminimap` and `/squareminimapbuttons`; `/zmb` and `/zippyminimap` are gone.
- Options as three tabs *General*, *Blizzard* and *Profiles*; the description and the authors stand at the top of *General*. The lower part of the dialog no longer reaches past the frame: every tab scrolls if needed, and the default size is 640 x 560, in which *General* and *Blizzard* fit completely (measurements in the README). The game settings no longer have the subcategory *Profiles* (it is a tab now).
- Removed: the option *Visibility* and the visibility driver (WoW Forever has no pet battles; the bar is shown whenever it has buttons) and the whole group *Extensions* (anchor, point, offsets, *Lock Bar*, own *Ignore List*). The bar stays anchored inside the top left corner of the minimap; the ElvUI and Tukui movers stay. Old profiles with these keys load without errors.
- New option *Glowing Tracker Icon when not tracking* (tab *Blizzard*, on by default): red glow around the tracking button while the character can track something but tracks nothing; not while dead, as a ghost or without full control.
  - 2026-11-07, at the owner's request: only the gathering tracking abilities Find Herbs, Find Minerals and Find Treasure count (by spell ID, or by the client's spell name for entries without one). Other tracking abilities such as Sense Undead or the hunter's tracks no longer start the glow, and having one of them on instead of a gathering ability does not end it.
  - 2026-11-07, at the owner's request: the toggle became the choice *Glowing tracking icon* with three radio buttons: *Enable glowing tracking icon if tracking is inactive (always)*, *Enable glowing tracking icon if tracking is inactive (only outside of raid instances)* (the default) and *Disable glowing tracking icon*. With the default there is no glow in a raid instance (`IsInInstance()`, instance type `raid`; read again on entering the world and on `ZONE_CHANGED_NEW_AREA`), because the owner's ForeverAuras reminder asks to disable tracking in raids. Profiles that had the toggle off get *Disable*, all others the default; the old key `TrackerGlow` is removed from the profile.
- Profile *Default* shared by all characters instead of one profile per character. A character that the first test versions put on its own profile (`Name - Realm`) moves to *Default* once and says so in the chat; while *Default* is still untouched, its settings are copied into *Default*, otherwise they can be taken over with *Profiles* > *Copy From* (the old profile stays).
- The tab *Profiles* shows only the profile controls of Ace3: entries that another addon writes into the shared table of AceDBOptions (RestedXP: *Reload guides and UI*, *Reset Guide Progress*, *Set current profile as default*) no longer appear there.
- 2026-11-07: the release asset is named `SquareMinimapButtons-<version>-forever.zip` and comes with a `release.json` in the format of the BigWigs packager, through which addon managers for WoW Forever detect updates.
- Fixed: the button of *Connoisseur & Restocker* (and any other button whose icon carries a mask with the file 130924) was an empty frame in the bar, because the skin emptied the mask. Mask textures are no longer emptied, moved or cropped, and masks are taken off the skinned icons.

Origin: ported from ProjectAzilroka (`Modules/SquareMinimapButtons.lua`, the helpers of its core and the option labels of its locales) by Azilroka, with Sinaris, Omega and Durc as authors of the module; the ProjectAzilroka License and the notes on the port are in [`LICENSE.txt`](LICENSE.txt). The differences from the original are listed in the README.
