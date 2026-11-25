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

-- WoW Forever port: Blizzard tab (the tracker glow is a radio group since 2026-11-07)
L["Disabled while ElvUI's queue status mover is active."] = 'Gesperrt, solange ElvUIs Mover für den Warteschlangen-Status aktiv ist.'
L['Glowing tracking icon'] = 'Leuchtendes Tracker-Symbol'
L['A red glow pulses around the tracking icon while you know Find Herbs, Find Minerals or Find Treasure and none of them is active.'] = 'Ein roter Schein pulsiert um das Tracker-Symbol, solange der Charakter Kräutersuche, Mineraliensuche oder Schatzsuche beherrscht und keine davon aktiv ist.'
L['Enable glowing tracking icon if tracking is inactive (always)'] = 'Tracker-Symbol leuchtet bei inaktiver Verfolgung (immer)'
L['Enable glowing tracking icon if tracking is inactive (only outside of raid instances)'] = 'Tracker-Symbol leuchtet bei inaktiver Verfolgung (nur außerhalb von Schlachtzügen)'
L['Disable glowing tracking icon'] = 'Leuchtendes Tracker-Symbol ausschalten'

-- WoW Forever port: guard against ProjectAzilroka
L['ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = 'ProjectAzilroka ist geladen und dessen Modul Square Minimap Buttons ist aktiv, deshalb bleibt dieses Addon inaktiv. Deaktiviere eines der beiden, um Konflikte zu vermeiden.'
L['ProjectAzilroka is loaded, but its settings could not be read, so this addon stays inactive. Disable one of the two to avoid conflicts.'] = 'ProjectAzilroka ist geladen, aber dessen Einstellungen konnten nicht gelesen werden, deshalb bleibt dieses Addon inaktiv. Deaktiviere eines der beiden, um Konflikte zu vermeiden.'

-- WoW Forever port: slash command
L['Usage: /smb [scan | reset | debug [name]] (also /squareminimap and /squareminimapbuttons)'] = 'Aufruf: /smb [scan | reset | debug [Name]] (auch /squareminimap und /squareminimapbuttons)'
L['/smb: open the options'] = '/smb: Optionen öffnen'
L['/smb scan: scan the minimap for new buttons now'] = '/smb scan: Minikarte sofort nach neuen Knöpfen durchsuchen'
L['/smb reset: reset the current profile to the defaults'] = '/smb reset: aktuelles Profil auf die Standardwerte zurücksetzen'
L['The options are not available yet.'] = 'Die Optionen sind noch nicht verfügbar.'
L['Scanning is not available yet.'] = 'Die Suche nach Knöpfen ist noch nicht verfügbar.'
L['The current profile was reset to the defaults.'] = 'Das aktuelle Profil wurde auf die Standardwerte zurückgesetzt.'
L['/smb debug [name]: list the buttons of the bar with their textures (all, or those whose name contains the text)'] = '/smb debug [Name]: Knöpfe der Leiste mit ihren Texturen auflisten (alle, oder die, deren Name den Text enthält)'

-- WoW Forever port 1.0.2: self-check of the buttons and diagnosis (chat; %s: button names, %d: count)
L['%s showed no icon in the bar and shows a replacement image now (%s). Please report it with the output of /smb debug %s.'] = '%s zeigte in der Leiste kein Symbol und zeigt jetzt ein Ersatzbild (%s). Bitte melde das mit der Ausgabe von /smb debug %s.'
L['The bar does not exist (the addon is turned off or inactive).'] = 'Die Leiste existiert nicht (das Addon ist ausgeschaltet oder inaktiv).'
L['No button of the bar matches "%s".'] = 'Kein Knopf der Leiste passt zu „%s“.'
L['%d buttons listed (/smb debug %s).'] = '%d Knöpfe aufgelistet (/smb debug %s).'

-- WoW Forever port: one-time switch to the shared profile (chat, %s: profile names)
L['this character now uses the shared profile %s'] = 'dieser Charakter nutzt jetzt das gemeinsame Profil %s'
L['this character now uses the shared profile %s (settings copied from %s)'] = 'dieser Charakter nutzt jetzt das gemeinsame Profil %s (Einstellungen übernommen aus %s)'
