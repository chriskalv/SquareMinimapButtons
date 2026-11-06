-- Square Minimap Buttons: English localization (enUS and enGB, also the fallback for every other locale).
-- Ported from ProjectAzilroka (Azilroka), see LICENSE.txt: the option labels and their keys are taken
-- from ProjectAzilroka's Locales/enUS.lua; the texts below "WoW Forever port" are new.

local L = LibStub('AceLocale-3.0'):NewLocale('SquareMinimapButtons', 'enUS', true, true)
if not L then return end

-- General (ProjectAzilroka)
L['Square Minimap Buttons'] = true
L['Minimap Button Bar / Minimap Button Skinning'] = true
L['Enable'] = true
L['General'] = true
L['Blizzard'] = true
L['Authors:'] = true
L['This setting requires that you reload your User Interface.'] = true

-- Options of the Square Minimap Buttons module (ProjectAzilroka)
L['Minimap Buttons / Bar'] = true
L['Enable Bar'] = true
L['Bar MouseOver'] = true
L['Bar Backdrop'] = true
L['Icon Size'] = true
L['Button Spacing'] = true
L['Buttons Per Row'] = true
L['Shadows'] = true
L['Reverse Direction'] = true
L['Frame Strata'] = true
L['Frame Level'] = true
L['Hide Garrison'] = true
L['Move Garrison Icon'] = true
L['Move Mail Icon'] = true
L['Move Game Time Frame'] = true
L['Move Tracker Icon'] = true
L['Move Queue Status Icon'] = true

-- WoW Forever port: options header
L['WoW Forever port:'] = true

-- WoW Forever port: Blizzard tab
L["Disabled while ElvUI's queue status mover is active."] = true
L['Glowing Tracker Icon when not tracking'] = true
L['A red glow pulses around the tracker icon while none of your tracking abilities (for example Find Herbs or Find Minerals) is active. Only takes effect when your character can track something.'] = true

-- WoW Forever port: guard against ProjectAzilroka
L['ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = true
L['ProjectAzilroka is loaded, but its settings could not be read, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = true

-- WoW Forever port: slash command
L['Usage: /smb [scan | reset] (also /squareminimap and /squareminimapbuttons)'] = true
L['/smb: open the options'] = true
L['/smb scan: scan the minimap for new buttons now'] = true
L['/smb reset: reset the current profile to the defaults'] = true
L['The options are not available yet.'] = true
L['Scanning is not available yet.'] = true
L['The current profile was reset to the defaults.'] = true
