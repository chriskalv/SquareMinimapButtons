-- Test group 1: loading, client detection, guard against ProjectAzilroka, slash commands,
-- reload dialog, addon compartment.

local GUARD_TEXT = "ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled"
local UNREADABLE_TEXT = "ProjectAzilroka is loaded, but its settings could not be read"

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then return i end
    end
end

describe("load order", function()
    it("the TOC lists the libraries first, then the locales, Core.lua, the module and Options.lua", function()
        local core = indexOf(ADDON_FILES, "SquareMinimapButtons/Core.lua")
        local enUS = indexOf(ADDON_FILES, "SquareMinimapButtons/Locales/enUS.lua")
        local deDE = indexOf(ADDON_FILES, "SquareMinimapButtons/Locales/deDE.lua")
        local module = indexOf(ADDON_FILES, "SquareMinimapButtons/SquareMinimapButtons.lua")
        local options = indexOf(ADDON_FILES, "SquareMinimapButtons/Options.lua")
        local libstub = indexOf(ADDON_FILES, "SquareMinimapButtons/Libs/Ace3/LibStub/LibStub.lua")
        local aceConfig = indexOf(ADDON_FILES, "SquareMinimapButtons/Libs/Ace3/AceConfig-3.0/AceConfig-3.0.lua")
        assert_eq(libstub, 1, "LibStub loads first")
        assert_true(aceConfig < enUS, "Ace3 before the locales")
        assert_true(enUS < deDE and deDE < core and core < module and module < options, "addon file order")
        assert_eq(options, #ADDON_FILES, "Options.lua loads last")
    end)

    it("embeds exactly the Ace3 libraries of the build plan", function()
        local seen = {}
        for _, file in ipairs(ADDON_FILES) do
            local lib = file:match("^SquareMinimapButtons/Libs/Ace3/([^/]+)/")
            if lib then seen[lib] = true end
        end
        assert_eq(seen, {
            ["LibStub"] = true, ["CallbackHandler-1.0"] = true, ["AceAddon-3.0"] = true,
            ["AceEvent-3.0"] = true, ["AceTimer-3.0"] = true, ["AceHook-3.0"] = true,
            ["AceDB-3.0"] = true, ["AceDBOptions-3.0"] = true, ["AceLocale-3.0"] = true,
            ["AceConsole-3.0"] = true, ["AceGUI-3.0"] = true, ["AceConfig-3.0"] = true,
        })
        for _, sub in ipairs({ "AceConfigRegistry-3.0", "AceConfigCmd-3.0", "AceConfigDialog-3.0" }) do
            assert_true(indexOf(ADDON_FILES, "SquareMinimapButtons/Libs/Ace3/AceConfig-3.0/" .. sub .. "/" .. sub .. ".lua"), sub)
        end
    end)

    it("loads all files and starts without errors", function()
        local ns = ReloadAddon({})
        StartClient()
        assert_eq(STUB.errors, {}, "no errors reported to the error handler")
        assert_true(ns.SMB ~= nil, "addon table carries the addon object")
        assert_true(ns.SMB == GetAddon(), "same object as AceAddon's")
        assert_eq(ns.L["Enable Bar"], "Enable Bar")
    end)

    it("the TOC carries the metadata of the build plan", function()
        assert_eq(ADDON_TOC["Interface"], "16001", "no 120105 in 1.0.0")
        assert_eq(ADDON_TOC["Interface-Forever"], "16001")
        assert_eq(ADDON_TOC["Title"], "Square Minimap Buttons")
        assert_eq(ADDON_TOC["Author"], "Azilroka (original), Zippy (WoW Forever port)")
        assert_eq(ADDON_TOC["Version"], "1.0.1")
        assert_eq(ADDON_TOC["OptionalDeps"], "ElvUI, Tukui, AddOnSkins")
        assert_eq(ADDON_TOC["SavedVariables"], "SquareMinimapButtonsDB")
        assert_eq(ADDON_TOC["AddonCompartmentFunc"], "SquareMinimapButtons_OnAddonCompartmentClick")
        assert_true(ADDON_TOC["IconTexture"] ~= nil and ADDON_TOC["X-Website"] ~= nil and ADDON_TOC["X-License"] ~= nil)
    end)
end)

describe("addon object", function()
    it("the global SquareMinimapButtons is the AceAddon object when it is free", function()
        ReloadAddon({})
        local SMB = GetAddon()
        assert_true(_G.SquareMinimapButtons == SMB)
        assert_eq(SMB:GetName(), "SquareMinimapButtons")
        for _, method in ipairs({ "RegisterEvent", "ScheduleTimer", "ScheduleRepeatingTimer", "SecureHook", "RegisterChatCommand" }) do
            assert_eq(type(SMB[method]), "function", method .. " embedded")
        end
        assert_eq(SMB.Version, "1.0.1", "version from the TOC")
    end)
end)

describe("client detection", function()
    it("WOW_PROJECT_ID 18 (WOW_PROJECT_CAMELOT) is Forever", function()
        ReloadAddon({ projectID = 18 })
        local SMB = GetAddon()
        assert_eq({ SMB.IsForever, SMB.IsRetail, SMB.IsClassic }, { true, false, false })
    end)

    it("WOW_PROJECT_ID 1 (WOW_PROJECT_MAINLINE) is Retail", function()
        ReloadAddon({ projectID = 1 })
        local SMB = GetAddon()
        assert_eq({ SMB.IsForever, SMB.IsRetail, SMB.IsClassic }, { false, true, false })
    end)

    it("WOW_PROJECT_ID 2 (WOW_PROJECT_CLASSIC) and other projects are Classic", function()
        ReloadAddon({ projectID = 2 })
        local SMB = GetAddon()
        assert_eq({ SMB.IsForever, SMB.IsRetail, SMB.IsClassic }, { false, false, true })
        assert_eq({ SMB.DetectClient(5) }, { false, false, true }, "TBC Classic")
        assert_eq({ SMB.DetectClient(14) }, { false, false, true }, "Cataclysm Classic")
    end)

    it("ignores the build number: a Retail build number does not make Forever Retail", function()
        ReloadAddon({ projectID = 18, interface = 120105 })
        assert_true(GetAddon().IsForever, "Forever with Retail interface number")
        ReloadAddon({ projectID = 1, interface = 16001 })
        assert_true(GetAddon().IsRetail, "Retail with Forever interface number")
        ReloadAddon({ projectID = 2, interface = 120105 })
        assert_true(GetAddon().IsClassic, "Classic with Retail interface number")
    end)

    it("detects ElvUI, Tukui and AddOnSkins through C_AddOns.GetAddOnEnableState", function()
        ReloadAddon({})
        local SMB = GetAddon()
        assert_eq({ SMB.ElvUI, SMB.Tukui, SMB.AddOnSkins }, { false, false, false })
        ReloadAddon({ elvui = {}, tukui = true, addonskins = true })
        SMB = GetAddon()
        assert_eq({ SMB.ElvUI, SMB.Tukui, SMB.AddOnSkins }, { true, true, true })
    end)
end)

describe("guard against ProjectAzilroka", function()
    local function startWithSpy(config)
        ReloadAddon(config)
        local SMB = GetAddon()
        local calls = 0
        SMB.Initialize = function() calls = calls + 1 end
        StartClient()
        return SMB, function() return calls end
    end

    it("without ProjectAzilroka the addon starts and says nothing", function()
        local SMB, initCalls = startWithSpy({})
        assert_false(SMB.blocked)
        assert_eq(initCalls(), 1, "Initialize called once")
        assert_eq(ChatContains(GUARD_TEXT), 0)
    end)

    it("with ProjectAzilroka and its module enabled the addon stays inactive and reports once", function()
        local SMB, initCalls = startWithSpy({ pa = { enabled = true } })
        assert_true(SMB.blocked, "blocked")
        assert_eq(initCalls(), 0, "Initialize not called")
        assert_eq(ChatContains(GUARD_TEXT), 1, "one chat message")
        SMB:OnEnable()
        AdvanceTime(1)
        assert_eq(ChatContains(GUARD_TEXT), 1, "still one message after a second start")
    end)

    it("leaves the global SquareMinimapButtons to ProjectAzilroka", function()
        local SMB = startWithSpy({ pa = { enabled = true } })
        assert_true(_G.SquareMinimapButtons == STUB.paModule, "global is PA's module")
        assert_true(_G.SquareMinimapButtons ~= SMB)
    end)

    it("with ProjectAzilroka loaded but its module disabled the addon runs", function()
        local SMB, initCalls = startWithSpy({ pa = { enabled = false } })
        assert_false(SMB.blocked)
        assert_eq(initCalls(), 1)
        assert_eq(ChatContains(GUARD_TEXT), 0)
        assert_true(_G.SquareMinimapButtons == STUB.paModule, "global still PA's")
    end)

    it("waits one frame when ProjectAzilroka sets its profile after this addon's PLAYER_LOGIN", function()
        local SMB, initCalls = startWithSpy({ pa = { enabled = true, dbAtLogin = true } })
        assert_true(SMB.blocked)
        assert_eq(initCalls(), 0)
        assert_eq(ChatContains(GUARD_TEXT), 1)

        SMB, initCalls = startWithSpy({ pa = { enabled = false, dbAtLogin = true } })
        assert_false(SMB.blocked)
        assert_eq(initCalls(), 1)
    end)

    it("with ProjectAzilroka loaded but its settings unreadable the addon stays inactive and says so", function()
        local SMB, initCalls = startWithSpy({ pa = { enabled = true, noDB = true } })
        assert_true(SMB.blocked, "blocked")
        assert_eq(initCalls(), 0, "Initialize not called")
        assert_eq(ChatContains(UNREADABLE_TEXT), 1, "one chat message about unreadable settings")
        assert_eq(ChatContains(GUARD_TEXT), 0, "no claim that PA's module is enabled")
        RunSlash("/smb", "scan")
        assert_eq(ChatContains(UNREADABLE_TEXT), 2, "/smb scan repeats the same reason")
        assert_eq(ChatContains(GUARD_TEXT), 0)
    end)

    it("a blocked addon does not rebuild on profile changes", function()
        local SMB = startWithSpy({ pa = { enabled = true } })
        local updates = 0
        SMB.Update = function() updates = updates + 1 end
        SMB.data:SetProfile("Other")
        assert_eq(updates, 0)
    end)
end)

describe("slash commands", function()
    it("registers /smb, /squareminimap and /squareminimapbuttons, and no longer /zmb or /zippyminimap", function()
        ReloadAddon({})
        StartClient()
        assert_eq(SLASH_ACECONSOLE_SMB1, "/smb")
        assert_eq(SLASH_ACECONSOLE_SQUAREMINIMAP1, "/squareminimap")
        assert_eq(SLASH_ACECONSOLE_SQUAREMINIMAPBUTTONS1, "/squareminimapbuttons")
        assert_eq(type(SlashCmdList.ACECONSOLE_SMB), "function")
        assert_eq(type(SlashCmdList.ACECONSOLE_SQUAREMINIMAP), "function")
        assert_eq(type(SlashCmdList.ACECONSOLE_SQUAREMINIMAPBUTTONS), "function")
        assert_nil(SlashCmdList.ACECONSOLE_ZMB)
        assert_nil(SlashCmdList.ACECONSOLE_ZIPPYMINIMAP)
        assert_false(RunSlash("/zmb", ""))
        assert_false(RunSlash("/zippyminimap", ""))
    end)

    it("without arguments prints a hint while no options are registered", function()
        ReloadAddon({})
        StartClient()
        LibStub("AceConfigRegistry-3.0").tables.SquareMinimapButtons = nil -- as before package 5
        assert_true(RunSlash("/smb", ""))
        assert_eq(ChatContains("The options are not available yet."), 1)
    end)

    it("without arguments opens the AceConfig dialog once options are registered", function()
        ReloadAddon({})
        StartClient()
        local opened
        LibStub("AceConfigDialog-3.0").Open = function(_, name) opened = name end
        RunSlash("/squareminimapbuttons", "")
        assert_eq(opened, "SquareMinimapButtons")
        assert_eq(ChatContains("The options are not available yet."), 0)
    end)

    it("scan calls GrabMinimapButtons(true) when it exists, otherwise prints a hint", function()
        ReloadAddon({})
        StartClient()
        GetAddon().GrabMinimapButtons = nil -- as before the scan was ported
        RunSlash("/smb", "scan")
        assert_eq(ChatContains("Scanning is not available yet."), 1)
        local arg
        GetAddon().GrabMinimapButtons = function(_, force) arg = force end
        RunSlash("/squareminimap", "  SCAN ")
        assert_eq(arg, true)
    end)

    it("an unknown argument prints the usage", function()
        ReloadAddon({})
        StartClient()
        RunSlash("/smb", "help")
        assert_eq(ChatContains("Usage: /smb [scan | reset] (also /squareminimap and /squareminimapbuttons)"), 1)
        assert_eq(ChatContains("/smb scan: scan the minimap for new buttons now"), 1)
    end)

    it("a blocked addon answers /smb with the guard message", function()
        ReloadAddon({ pa = { enabled = true } })
        StartClient()
        RunSlash("/smb", "")
        assert_eq(ChatContains(GUARD_TEXT), 2, "start message plus answer")
    end)
end)

describe("reload dialog and addon compartment", function()
    it("defines StaticPopupDialogs.SQUAREMINIMAPBUTTONS_RL", function()
        ReloadAddon({})
        local dialog = StaticPopupDialogs.SQUAREMINIMAPBUTTONS_RL
        assert_true(dialog ~= nil)
        assert_eq(dialog.text, "This setting requires that you reload your User Interface.")
        assert_eq(dialog.button1, ACCEPT)
        assert_eq(dialog.button2, CANCEL)
        assert_eq(dialog.timeout, 0)
        dialog.OnAccept()
        assert_eq(STUB.reloads, 1, "accept reloads the UI")
    end)

    it("SquareMinimapButtons_OnAddonCompartmentClick opens the options", function()
        ReloadAddon({})
        StartClient()
        assert_eq(type(SquareMinimapButtons_OnAddonCompartmentClick), "function")
        local registry = LibStub("AceConfigRegistry-3.0")
        local registered = registry.tables.SquareMinimapButtons
        registry.tables.SquareMinimapButtons = nil -- as before package 5
        SquareMinimapButtons_OnAddonCompartmentClick()
        assert_eq(ChatContains("The options are not available yet."), 1)
        registry.tables.SquareMinimapButtons = registered
        local opened
        LibStub("AceConfigDialog-3.0").Open = function(_, name) opened = name end
        SquareMinimapButtons_OnAddonCompartmentClick()
        assert_eq(opened, "SquareMinimapButtons")
    end)
end)

describe("German locale", function()
    it("uses the German texts of ProjectAzilroka and the new ones", function()
        local ns = ReloadAddon({ locale = "deDE" })
        assert_eq(ns.L["Enable Bar"], "Aktiviere Leiste")
        assert_eq(ns.L["Move Tracker Icon"], "Verflogen Symbol bewegen", "original spelling kept")
        assert_eq(ns.L["Move Game Time Frame"], "Kalender Symbol bewegen", "added")
        assert_eq(ns.L["Glowing tracking icon"], "Leuchtendes Tracker-Symbol")
        assert_eq(ns.L["Enable glowing tracking icon if tracking is inactive (only outside of raid instances)"], "Tracker-Symbol leuchtet bei inaktiver Verfolgung (nur außerhalb von Schlachtzügen)")
        assert_eq(ns.L["/smb: open the options"], "/smb: Optionen öffnen")
        assert_eq(STUB.errors, {})
    end)
end)
