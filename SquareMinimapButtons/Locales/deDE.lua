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
L['Hide Garrison'] = 'Verstecke Garnision'
L['Move Garrison Icon'] = 'Garnision Symbol bewegen'
L['Move Mail Icon'] = 'Post Symbol bewegen'
L['Move Game Time Frame'] = 'Kalender Symbol bewegen' -- missing in ProjectAzilroka
L['Move Tracker Icon'] = 'Verflogen Symbol bewegen'
L['Move Queue Status Icon'] = 'LFG Symbol bewegen'

-- WoW Forever port: options header
L['WoW Forever port:'] = 'Portierung für WoW Forever:'

-- WoW Forever port: Blizzard tab
L["Disabled while ElvUI's queue status mover is active."] = 'Gesperrt, solange ElvUIs Mover für den Warteschlangen-Status aktiv ist.'
L['Glowing Tracker Icon when not tracking'] = 'Tracker-Symbol leuchtet, wenn nichts verfolgt wird'
L['A red glow pulses around the tracker icon while none of your tracking abilities (for example Find Herbs or Find Minerals) is active. Only takes effect when your character can track something.'] = 'Ein roter Schein pulsiert um das Tracker-Symbol, solange keine Aufspürfähigkeit (etwa Kräutersuche oder Mineraliensuche) aktiv ist. Greift nur, wenn der Charakter etwas verfolgen kann.'

-- WoW Forever port: guard against ProjectAzilroka
L['ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = 'ProjectAzilroka ist geladen und dessen Modul Square Minimap Buttons ist aktiv, deshalb bleibt dieses Addon inaktiv. Deaktiviere eines der beiden, um Konflikte zu vermeiden.'
L['ProjectAzilroka is loaded, but its settings could not be read, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = 'ProjectAzilroka ist geladen, aber dessen Einstellungen konnten nicht gelesen werden, deshalb bleibt dieses Addon inaktiv. Deaktiviere eines der beiden, um Konflikte zu vermeiden.'

-- WoW Forever port: slash command
L['Usage: /smb [scan | reset] (also /squareminimap and /squareminimapbuttons)'] = 'Aufruf: /smb [scan | reset] (auch /squareminimap und /squareminimapbuttons)'
L['/smb: open the options'] = '/smb: Optionen öffnen'
L['/smb scan: scan the minimap for new buttons now'] = '/smb scan: Minikarte sofort nach neuen Knöpfen durchsuchen'
L['/smb reset: reset the current profile to the defaults'] = '/smb reset: aktuelles Profil auf die Standardwerte zurücksetzen'
L['The options are not available yet.'] = 'Die Optionen sind noch nicht verfügbar.'
L['Scanning is not available yet.'] = 'Die Suche nach Knöpfen ist noch nicht verfügbar.'
L['The current profile was reset to the defaults.'] = 'Das aktuelle Profil wurde auf die Standardwerte zurückgesetzt.'
