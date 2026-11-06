-- Square Minimap Buttons: German localization (deDE).
-- Ported from ProjectAzilroka (Azilroka), see LICENSE.txt: the option labels are taken verbatim from
-- ProjectAzilroka's Locales/deDE.lua (original spelling kept); texts missing there and the texts
-- below "WoW Forever port" are new.

local L = LibStub('AceLocale-3.0'):NewLocale('SquareMinimapButtons', 'deDE')
if not L then return end

-- General (ProjectAzilroka)
L['Square Minimap Buttons'] = true
L['Minimap Button Bar / Minimap Button Skinning'] = 'Minimap Tastenleiste / Skinnen der Minimap Tasten'
L['Enable'] = 'Aktivieren'
L['General'] = 'Allgemein'
L['Blizzard'] = true
L['Authors:'] = 'Autoren:'
L['This setting requires that you reload your User Interface.'] = 'Diese Einstellung erfordert, dass Du Deine Benutzeroberfläche neu laden musst.'
L['Profiles'] = 'Profile'

-- Options of the Square Minimap Buttons module (ProjectAzilroka)
L['Minimap Buttons / Bar'] = 'Minikarte Tasten / Leiste'
L['Enable Bar'] = 'Aktiviere Leiste'
L['Bar MouseOver'] = 'Leiste MouseOver'
L['Bar Backdrop'] = 'Leistenhintergrund'
L['Icon Size'] = 'Symbolgröße'
L['Button Spacing'] = 'Tasten Abstand'
L['Buttons Per Row'] = 'Tasten pro Reihe'
L['Shadows'] = 'Schatten'
L['Reverse Direction'] = 'Rückwärtsrichtung'
L['Frame Strata'] = 'Fenster Schicht'
L['Frame Level'] = 'Fenster Ebene'
L['Visibility'] = 'Sichtbarkeit'
L['Hide Garrison'] = 'Verstecke Garnision'
L['Move Garrison Icon'] = 'Garnision Symbol bewegen'
L['Move Mail Icon'] = 'Post Symbol bewegen'
L['Move Game Time Frame'] = 'Kalender Symbol bewegen' -- missing in ProjectAzilroka
L['Move Tracker Icon'] = 'Verflogen Symbol bewegen'
L['Move Queue Status Icon'] = 'LFG Symbol bewegen'

-- WoW Forever port: options header
L['WoW Forever port:'] = 'Portierung für WoW Forever:'

-- WoW Forever port: extensions (anchor to the minimap, lock, own ignore list)
L['Extensions'] = 'Erweiterungen'
L['Anchor to Minimap'] = 'An Minikarte binden'
L['Keeps the bar attached to the minimap. When disabled, the bar can be moved freely like in ProjectAzilroka.'] = 'Hält die Leiste an der Minikarte. Ausgeschaltet lässt sich die Leiste wie in ProjectAzilroka frei verschieben.'
L['Point'] = 'Punkt'
L['Relative Point'] = 'Bezugspunkt'
L['X Offset'] = 'Versatz X'
L['Y Offset'] = 'Versatz Y'
L['Lock Bar'] = 'Leiste sperren'
L['Prevents the bar from being dragged.'] = 'Verhindert, dass die Leiste verschoben wird.'
L['Ignore List'] = 'Eigene Ignorierliste'
L['Buttons that stay on the minimap: one frame name or Lua pattern per line.'] = 'Knöpfe, die auf der Minikarte bleiben: ein Framename oder Lua-Muster je Zeile.'
L["Disabled while ElvUI's queue status mover is active."] = 'Gesperrt, solange ElvUIs Mover für den Warteschlangen-Status aktiv ist.'
L['Point of the bar that is attached to the minimap.'] = 'Punkt der Leiste, der an der Minikarte hängt.'
L['Point of the minimap that the bar is attached to.'] = 'Punkt der Minikarte, an dem die Leiste hängt.'
L['The ElvUI or Tukui mover holds the position of the bar, so the anchor options are disabled.'] = 'Der Mover von ElvUI oder Tukui hält die Lage der Leiste, deshalb sind die Ankeroptionen gesperrt.'
L['A button that is already in the bar stays there until you reload your User Interface.'] = 'Ein Knopf, der schon in der Leiste ist, bleibt dort bis zum Neuladen der Benutzeroberfläche.'

-- WoW Forever port: guard against ProjectAzilroka
L['ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = 'ProjectAzilroka ist geladen und dessen Modul Square Minimap Buttons ist aktiv, deshalb bleibt dieses Addon inaktiv. Deaktiviere eines der beiden, um Konflikte zu vermeiden.'
L['ProjectAzilroka is loaded, but its settings could not be read, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = 'ProjectAzilroka ist geladen, aber dessen Einstellungen konnten nicht gelesen werden, deshalb bleibt dieses Addon inaktiv. Deaktiviere eines der beiden, um Konflikte zu vermeiden.'

-- WoW Forever port: slash command
L['Usage: /zmb [scan | reset] (also /zippyminimap)'] = 'Aufruf: /zmb [scan | reset] (auch /zippyminimap)'
L['/zmb: open the options'] = '/zmb: Optionen öffnen'
L['/zmb scan: scan the minimap for new buttons now'] = '/zmb scan: Minikarte sofort nach neuen Knöpfen durchsuchen'
L['/zmb reset: reset the current profile to the defaults'] = '/zmb reset: aktuelles Profil auf die Standardwerte zurücksetzen'
L['The options are not available yet.'] = 'Die Optionen sind noch nicht verfügbar.'
L['Scanning is not available yet.'] = 'Die Suche nach Knöpfen ist noch nicht verfügbar.'
L['The current profile was reset to the defaults.'] = 'Das aktuelle Profil wurde auf die Standardwerte zurückgesetzt.'
