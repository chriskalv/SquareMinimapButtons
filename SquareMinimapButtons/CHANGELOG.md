# Changelog

## 1.0.0 (2026-11-06)

First version: the *Square Minimap Buttons* module of ProjectAzilroka by Azilroka as a standalone addon for WoW Forever (Interface 16001), ported with Azilroka's permission. Details are in [`README.md`](README.md).

- **Scan and skin**: collects the buttons of other addons from the minimap (on entering the world, every 6 seconds and with `/zmb scan`, not in combat or pet battles), skips ProjectAzilroka's fixed ignore list, map pins and unnamed buttons without an icon, and skins the buttons square with cropped icons, backdrop and, with AddOnSkins, ElvUI or Tukui, shadows.
- **Bar**: lays the buttons out in rows (default one column of 18 px buttons without spacing), with backdrop, strata and level, fading on mouse-over and a visibility condition (default `[petbattle] hide; show`); anchored inside the top left corner of the minimap by default, or at a free position that is dragged and saved in the profile.
- **Lock**: the position methods of a button in the bar are locked so that its addon cannot move it out again; the bar itself can be locked against dragging (*Lock Bar*).
- **Ignore list**: an own list of frame names or Lua patterns next to the fixed list.
- **Blizzard buttons**: mail, tracking, calendar and queue in the bar, with branches for WoW Forever (tracking frame kept visible, own calendar branch, queue click through `ToggleGroupFinderFrame()`, queue off by default and left alone while ElvUI's queue module holds it); the garrison options have no effect, as in ProjectAzilroka, and are hidden in WoW Forever.
- **Options**: the options tree of ProjectAzilroka plus the group *Extensions*, in an own dialog (`/zmb`, `/zippyminimap`, addon compartment), in the game settings and, with ElvUI, in ElvUI's options; changes in combat wait until combat ends; turning off a Blizzard button that is already in the bar asks for a reload.
- **Profiles**: AceDB profiles in `SquareMinimapButtonsDB` (one per character by default) with the profile page of AceDBOptions; changing, copying or resetting a profile rebuilds the bar; `/zmb reset` resets the current profile.
- **ElvUI and Tukui movers**: with ElvUI the bar has ElvUI's mover *SquareMinimapButtonBar Anchor* (frame `SquareMinimapButtonBarMover`, as in ProjectAzilroka), with Tukui it is registered with Tukui's movers; an enabled but not loaded ElvUI or Tukui causes no error.
- **Guard**: stays inactive while ProjectAzilroka is loaded with its Square Minimap Buttons module enabled (or its settings cannot be read), and says so once in the chat.

Origin: ported from ProjectAzilroka (`Modules/SquareMinimapButtons.lua`, the helpers of its core and the option labels of its locales) by Azilroka, with Sinaris, Omega and Durc as authors of the module; the ProjectAzilroka License and the notes on the port are in [`LICENSE.txt`](LICENSE.txt). The differences from the original are listed in the README.
