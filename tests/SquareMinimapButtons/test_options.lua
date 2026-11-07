-- Test group 8 (options, package 5, reworked in nachtrag 2): the AceConfig tree after
-- ProjectAzilroka's Modules/SquareMinimapButtons.lua GetOptions (454-489) and Init.lua (profiles
-- 618, reload dialog 548-556, Blizzard settings and ElvUI options 639-653), with the changes of the
-- port: three tabs (General, Blizzard, Profiles), no Visibility and no group "Extensions" any more,
-- the tracker glow toggle, hidden per client with WoW Forever, the reload dialog when a built
-- Blizzard button is turned off, MoveQueue disabled while ElvUI's queue module holds the button,
-- Blizzard buttons in combat after combat, Blizzard settings and ElvUI's options, and a layout model
-- of AceConfigDialog/AceGUI that checks that the tabs General, Blizzard and Profiles fit; part 2
-- of nachtrag 2: the tab Profiles is an own group with only the standard entries of AceDBOptions
-- (entries that other addons write into the library's shared args stay out); nachtrag 4: the tracker
-- glow is a select with style 'radio' (TrackerGlowMode: always, only outside of raid instances, off),
-- which the layout model counts as an inline group with one row per value.

local FOREVER, RETAIL, CLASSIC = 18, 1, 2
local APP = "SquareMinimapButtons"

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

local function withProfile(values, config)
    config = config or {}
    config.savedVariables = {
        profileKeys = { ["Zippy - Forever"] = "Default" },
        profiles = { Default = values },
    }
    return config
end

-- the table as AceConfigDialog gets it (validated by the registry on the first call)
local function options()
    return LibStub("AceConfigRegistry-3.0"):GetOptionsTable(APP, "dialog", "AceConfigDialog-3.0")
end

-- the option at a path such as { "General", "MBB", "IconSize" }, with the nearest get/set of the
-- groups above it (AceConfig inherits get and set from the parent groups)
local function resolve(path)
    local node = options()
    local get, set = node.get, node.set
    for _, key in ipairs(path) do
        node = node.args[key]
        assert_true(node ~= nil, "option " .. table.concat(path, ".") .. " exists")
        get = node.get or get
        set = node.set or set
    end
    local info = {}
    for i, key in ipairs(path) do info[i] = key end
    info.options, info.option, info.appName = options(), node, APP
    return node, info, get, set
end

local function getValue(path)
    local _, info, get = resolve(path)
    return get(info)
end

local function setValue(path, value)
    local _, info, _, set = resolve(path)
    return set(info, value)
end

local function call(field, path)
    local node, info = resolve(path)
    local v = node[field]
    if type(v) == "function" then return v(info) end
    return v
end

-- counts calls of SMB:<method> and still runs it
local function spy(SMB, method)
    local counter = { n = 0, args = {} }
    local original = SMB[method]
    function counter.restore() SMB[method] = original end
    SMB[method] = function(self, ...)
        counter.n = counter.n + 1
        counter.args[counter.n] = { ... }
        return original(self, ...)
    end
    return counter
end

local function keysOf(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local MBB_KEYS = { "BarEnabled", "BarMouseOver", "Backdrop", "IconSize", "ButtonSpacing", "ButtonsPerRow", "Shadows", "ReverseDirection" }
-- the Blizzard toggles that build buttons (TrackerGlowMode has its own getter and setter)
local BLIZZARD_KEYS = { "HideGarrison", "MoveGarrison", "MoveMail", "MoveGameTimeFrame", "MoveTracker", "MoveQueue" }
local STRATA = { "BACKGROUND", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "HIGH", "LOW", "MEDIUM", "TOOLTIP" }
-- options that nachtrag 2 removed, anywhere in the tree
local REMOVED = { "Visibility", "Extensions", "MoverNote", "AnchorToMinimap", "Point", "RelativePoint", "X", "Y", "Lock", "IgnoreList" }

-- a value of the right type that differs from the default
local SAMPLE = {
    BarEnabled = false, BarMouseOver = true, Backdrop = false, IconSize = 30, ButtonSpacing = 4,
    ButtonsPerRow = 3, Shadows = false, ReverseDirection = true,
    Strata = "HIGH", Level = 20,
}

-- every key in the tree (except inside the AceDBOptions group)
local function allKeys(node, out)
    out = out or {}
    for key, child in pairs(node.args or {}) do
        out[key] = true
        if key ~= "profiles" then allKeys(child, out) end
    end
    return out
end

describe("registration", function()
    it("registers the table under the app name SquareMinimapButtons before Initialize", function()
        local order = {}
        ReloadAddon({})
        local SMB = GetAddon()
        local register, initialize = SMB.RegisterOptions, SMB.Initialize
        SMB.RegisterOptions = function(self) order[#order + 1] = "options"; return register(self) end
        SMB.Initialize = function(self) order[#order + 1] = "initialize"; return initialize(self) end
        StartClient()
        assert_eq(order, { "options", "initialize" })
        local registered = LibStub("AceConfigRegistry-3.0"):GetOptionsTable(APP, "dialog", "AceConfigDialog-3.0")
        assert_true(registered == SMB.Options, "the registry returns the addon's table")
        assert_eq(STUB.errors, {})
    end)

    it("passes the validation of AceConfigRegistry (on registering and on opening)", function()
        local SMB = fresh()
        local registry = LibStub("AceConfigRegistry-3.0")
        registry:ValidateOptionsTable(SMB.Options, APP)
        for _, uiType in ipairs({ "dialog", "cmd", "dropdown" }) do
            assert_true(registry:GetOptionsTable(APP, uiType, "AceConfigDialog-3.0") == SMB.Options, uiType)
        end
        assert_true(RunSlash("/smb", ""))
        assert_eq(STUB.settings.dialogOpened, { { APP } })
    end)

    it("passes the validation in Forever, Retail, Classic, with ElvUI (also its own tree) and in German", function()
        local configs = {
            { projectID = FOREVER }, { projectID = RETAIL }, { projectID = CLASSIC },
            { elvui = { options = { loaded = true }, queueStatus = true } }, { tukui = true }, { locale = "deDE" },
        }
        for i, config in ipairs(configs) do
            local SMB = fresh(config)
            local registry = LibStub("AceConfigRegistry-3.0")
            local ok, err = pcall(registry.ValidateOptionsTable, registry, SMB.Options, APP)
            assert_true(ok, "config " .. i .. ": " .. tostring(err))
            if config.elvui then
                registry:ValidateOptionsTable(ElvUI[1].Options.args.SquareMinimapButtons, "ElvUI")
            end
            assert_eq(STUB.errors, {}, "config " .. i)
        end
    end)

    it("the validation would catch a broken field (the check is real)", function()
        local SMB = fresh()
        SMB.Options.args.General.args.MBB.args.IconSize.width = {}
        local ok = pcall(function() LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(SMB.Options, APP) end)
        assert_false(ok)
    end)

    it("stays unregistered while the guard blocks the addon", function()
        fresh({ pa = { enabled = true } })
        assert_nil(LibStub("AceConfigRegistry-3.0"):GetOptionsTable(APP))
        assert_eq(STUB.settings.blizOptions, {})
    end)

    it("registers once even if Start runs again", function()
        local SMB = fresh()
        SMB:RegisterOptions()
        assert_eq(#STUB.settings.blizOptions, 1)
        assert_eq(STUB.errors, {})
    end)
end)

describe("structure (nachtrag 2: three tabs)", function()
    it("root: childGroups tab with General, Blizzard, Profiles in this order and nothing else", function()
        fresh()
        local o = options()
        assert_eq(o.type, "group")
        assert_eq(o.name, "Square Minimap Buttons")
        assert_eq(o.desc, "Minimap Button Bar / Minimap Button Skinning")
        assert_eq(o.childGroups, "tab")
        assert_eq(type(o.get), "function")
        assert_eq(type(o.set), "function")
        assert_eq(keysOf(o.args), { "Blizzard", "General", "profiles" })
        assert_eq({ o.args.General.order, o.args.Blizzard.order, o.args.profiles.order }, { 1, 2, 3 })
        for key, tab in pairs(o.args) do
            assert_eq(tab.type, "group", key)
            assert_false(tab.inline, key .. " is a tab, not inline")
        end
        assert_eq({ o.args.General.name, o.args.Blizzard.name, o.args.profiles.name }, { "General", "Blizzard", "Profiles" })
    end)

    it("the tabs come in the order General, Blizzard, Profiles (AceConfigDialog sorts by order)", function()
        fresh()
        local o = options()
        local tabs = {}
        for key, tab in pairs(o.args) do tabs[#tabs + 1] = { key = key, order = tab.order } end
        table.sort(tabs, function(a, b) return a.order < b.order end)
        assert_eq({ tabs[1].key, tabs[2].key, tabs[3].key }, { "General", "Blizzard", "profiles" })
    end)

    it("General: description and authors at the top, then Enable, MBB (inline), Strata, Level", function()
        fresh()
        local g = options().args.General.args
        assert_eq(keysOf(g), { "AuthorHeader", "Authors", "Description", "Enable", "Level", "MBB", "PortAuthor", "Strata" })
        local expected = {
            { "Description", "description", 1 }, { "AuthorHeader", "header", 2 }, { "Authors", "description", 3 },
            { "PortAuthor", "description", 4 }, { "Enable", "toggle", 5 }, { "MBB", "group", 6 },
            { "Strata", "select", 7 }, { "Level", "range", 8 },
        }
        for _, e in ipairs(expected) do
            assert_eq({ g[e[1]].type, g[e[1]].order }, { e[2], e[3] }, e[1])
        end
        assert_eq(g.Description.name, "Minimap Button Bar / Minimap Button Skinning")
        assert_eq(g.AuthorHeader.name, "Authors:")
        assert_eq(g.Authors.name, "Azilroka    Sinaris    Omega    Durc")
        assert_eq(g.Authors.fontSize, "large")
        assert_eq(g.PortAuthor.name, "WoW Forever port: Zippy")
        assert_eq(g.PortAuthor.fontSize, "medium")
        assert_eq(g.Enable.name, "Enable")
        assert_eq(g.MBB.name, "Minimap Buttons / Bar")
        assert_true(g.MBB.inline)
        assert_eq(g.Strata.name, "Frame Strata")
        assert_eq(keysOf(g.Strata.values), STRATA)
        for key, label in pairs(g.Strata.values) do assert_eq(label, key) end
        assert_eq(g.Level.name, "Frame Level")
        assert_eq({ g.Level.min, g.Level.max, g.Level.step }, { 0, 255, 1 })
    end)

    it("MBB: the toggles and ranges in the original order, no Visibility", function()
        fresh()
        local m = options().args.General.args.MBB.args
        assert_eq(keysOf(m), { "Backdrop", "BarEnabled", "BarMouseOver", "ButtonSpacing", "ButtonsPerRow", "IconSize", "ReverseDirection", "Shadows" })
        local expected = {
            { "BarEnabled", "toggle", "Enable Bar", 1 },
            { "BarMouseOver", "toggle", "Bar MouseOver", 2 },
            { "Backdrop", "toggle", "Bar Backdrop", 3 },
            { "IconSize", "range", "Icon Size", 4 },
            { "ButtonSpacing", "range", "Button Spacing", 5 },
            { "ButtonsPerRow", "range", "Buttons Per Row", 6 },
            { "Shadows", "toggle", "Shadows", 7 },
            { "ReverseDirection", "toggle", "Reverse Direction", 8 },
        }
        for _, e in ipairs(expected) do
            local option = m[e[1]]
            assert_eq({ option.type, option.name, option.order }, { e[2], e[3], e[4] }, e[1])
        end
        assert_eq({ m.IconSize.min, m.IconSize.max, m.IconSize.step }, { 12, 48, 1 })
        assert_eq({ m.ButtonSpacing.min, m.ButtonSpacing.max, m.ButtonSpacing.step }, { -1, 10, 1 })
        assert_eq({ m.ButtonsPerRow.min, m.ButtonsPerRow.max, m.ButtonsPerRow.step }, { 1, 100, 1 })
    end)

    it("Blizzard: six full-width toggles and the tracker glow choice directly under the tracker toggle", function()
        fresh()
        local b = options().args.Blizzard
        assert_eq(type(b.set), "function")
        assert_nil(b.get, "reads through the root getter")
        assert_eq(keysOf(b.args), { "HideGarrison", "MoveGameTimeFrame", "MoveGarrison", "MoveMail", "MoveQueue", "MoveTracker", "TrackerGlowMode" })
        local expected = {
            { "HideGarrison", "Hide Garrison" }, { "MoveGarrison", "Move Garrison Icon" },
            { "MoveGameTimeFrame", "Move Game Time Frame" }, { "MoveMail", "Move Mail Icon" },
            { "MoveTracker", "Move Tracker Icon" }, { "TrackerGlowMode", "Glowing tracking icon", "select" },
            { "MoveQueue", "Move Queue Status Icon" },
        }
        for i, e in ipairs(expected) do
            local option = b.args[e[1]]
            assert_eq({ option.type, option.name, option.order, option.width }, { e[3] or "toggle", e[2], i, "full" }, e[1])
        end
        assert_eq(b.args.TrackerGlowMode.order, b.args.MoveTracker.order + 1, "directly under MoveTracker")
        assert_eq(b.args.TrackerGlowMode.order, 6)
        assert_nil(b.args.TrackerGlow, "the old toggle is gone")
    end)

    it("the tracker glow is a select with style radio: three values in a fixed order", function()
        local SMB = fresh()
        local option = options().args.Blizzard.args.TrackerGlowMode
        assert_eq(option.type, "select")
        assert_eq(option.style, "radio", "AceConfigDialog: an inline group with one radio button per value")
        assert_eq(option.width, "full", "one radio button per line")
        assert_eq(option.sorting, { "always", "outsideRaid", "off" })
        assert_eq(option.values, {
            always = "Enable glowing tracking icon if tracking is inactive (always)",
            outsideRaid = "Enable glowing tracking icon if tracking is inactive (only outside of raid instances)",
            off = "Disable glowing tracking icon",
        })
        assert_eq(option.sorting, SMB.TrackerGlowModes, "the same order as the profile values")
        assert_eq(option.desc, "A red glow pulses around the tracking icon while you know Find Herbs, Find Minerals or Find Treasure and none of them is active.")
        assert_eq(type(option.get), "function")
        assert_eq(type(option.set), "function")
        assert_true(option.set ~= options().args.Blizzard.set, "own setter: no Blizzard rebuild for the glow")
    end)

    it("the real AceConfigDialog draws an inline group with three radio buttons; a click writes the mode", function()
        -- without InstrumentAceConfigDialog: the real Open feeds the AceGUI widgets of the stubs
        ResetWorld({ tracking = { TRACKING_SPELL("Find Herbs", false, 2383) }, instanceType = "raid" })
        LoadAddon()
        StartClient()
        local SMB = GetAddon()
        local container = LibStub("AceGUI-3.0"):Create("SimpleGroup")
        LibStub("AceConfigDialog-3.0"):Open(APP, container, "Blizzard")
        local group
        for _, child in ipairs(container.children) do
            if child.type == "InlineGroup" then group = child end
        end
        assert_true(group ~= nil, "an InlineGroup in the tab")
        assert_eq(group.titletext:GetText(), "Glowing tracking icon")
        local shown = {}
        for i, radio in ipairs(group.children) do
            assert_eq(radio.type, "CheckBox")
            shown[i] = { radio:GetUserData("value"), radio.text:GetText(), radio.checked and true or false, radio.width }
        end
        assert_eq(shown, {
            { "always", "Enable glowing tracking icon if tracking is inactive (always)", false, "fill" },
            { "outsideRaid", "Enable glowing tracking icon if tracking is inactive (only outside of raid instances)", true, "fill" },
            { "off", "Disable glowing tracking icon", false, "fill" },
        })
        assert_false(SMB.TrackerGlow ~= nil and SMB.TrackerGlow:IsShown(), "no glow in the raid by default")
        group.children[1]:Fire("OnValueChanged", true)
        assert_eq(SMB.db.TrackerGlowMode, "always")
        assert_true(SMB.TrackerGlow ~= nil and SMB.TrackerGlow:IsShown(), "the glow at once")
        assert_eq(STUB.errors, {})
    end)

    it("the getter reads the mode, an unknown stored value reads as outsideRaid", function()
        local SMB = fresh()
        assert_eq(getValue({ "Blizzard", "TrackerGlowMode" }), "outsideRaid")
        for _, mode in ipairs({ "always", "off", "outsideRaid" }) do
            SMB.db.TrackerGlowMode = mode
            assert_eq(getValue({ "Blizzard", "TrackerGlowMode" }), mode)
        end
        SMB.db.TrackerGlowMode = "bogus"
        assert_eq(getValue({ "Blizzard", "TrackerGlowMode" }), "outsideRaid", "always one radio button checked")
    end)

    it("the setter writes the mode and updates the glow once, without Blizzard rebuild or dialog", function()
        local SMB = fresh()
        local glow, blizzard = spy(SMB, "UpdateTrackerGlow"), spy(SMB, "HandleBlizzardButtons")
        setValue({ "Blizzard", "TrackerGlowMode" }, "always")
        assert_eq(SMB.db.TrackerGlowMode, "always")
        assert_eq(glow.n, 1)
        assert_eq(blizzard.n, 0)
        assert_eq(STUB.popups, {})
    end)

    it("no Visibility and no Extensions anywhere in the tree", function()
        for _, config in ipairs({ { projectID = FOREVER }, { projectID = RETAIL }, { projectID = CLASSIC }, { elvui = {} } }) do
            fresh(config)
            local keys = allKeys(options())
            for _, key in ipairs(REMOVED) do
                assert_nil(keys[key], key .. " is gone")
            end
        end
        local SMB = GetAddon()
        assert_nil(SMB.IgnoreListToText)
        assert_nil(SMB.TextToIgnoreList)
        assert_nil(SMB.PointValues)
    end)

    it("profiles: an own group with the handler of the addon's database as the third tab", function()
        local SMB = fresh()
        local p = options().args.profiles
        assert_eq(p.type, "group")
        assert_eq(p.order, 3)
        assert_eq(p.handler.db, SMB.data)
        assert_eq(p.handler:GetCurrentProfile(), "Default")
    end)

    it("German: PA's texts (original spelling) and the new ones", function()
        fresh({ locale = "deDE" })
        local o = options()
        assert_eq(o.args.General.name, "Allgemein")
        assert_eq(o.args.General.args.Enable.name, "Aktivieren")
        assert_eq(o.args.Blizzard.args.HideGarrison.name, "Verstecke Garnision")
        assert_eq(o.args.General.args.Strata.name, "Fenster Schicht")
        assert_eq(o.args.General.args.AuthorHeader.name, "Autoren:")
        assert_eq(o.args.General.args.PortAuthor.name, "Portierung für WoW Forever: Zippy")
        local glow = o.args.Blizzard.args.TrackerGlowMode
        assert_eq(glow.name, "Leuchtendes Tracker-Symbol")
        assert_contains(glow.desc, "Kräutersuche, Mineraliensuche oder Schatzsuche beherrscht und keine davon aktiv ist.")
        assert_eq(glow.values, {
            always = "Tracker-Symbol leuchtet bei inaktiver Verfolgung (immer)",
            outsideRaid = "Tracker-Symbol leuchtet bei inaktiver Verfolgung (nur außerhalb von Schlachtzügen)",
            off = "Leuchtendes Tracker-Symbol ausschalten",
        })
        assert_eq(o.args.profiles.name, "Profile")
    end)
end)

-- The standard entries of AceDBOptions-3.0 revision 17 (Libs/Ace3), sorted.
local PROFILE_KEYS = { "choose", "choosedesc", "copydesc", "copyfrom", "current", "deldesc", "delete", "desc", "descreset", "new", "reset" }

-- The entries that RestedXP writes into the args of its AceDBOptions table (RXPGuides
-- SettingsPanel.lua 3583-3618), reduced to what the test needs.
local function addForeignEntries(args)
    args.reloadUI = { order = 0, name = "Reload guides and UI", type = "execute", func = function() end }
    args.setDefaultProfile = { order = 910, name = "Set current profile as default", type = "execute", func = function() end }
end

local function removeForeignEntries(args)
    args.reloadUI, args.setDefaultProfile = nil, nil
end

describe("tab Profiles (nachtrag 2 part 2: only the standard entries of AceDBOptions)", function()
    it("is not the library's table; the same handler; exactly the eleven standard entries, each the library's own", function()
        local SMB = fresh()
        local ADBO = LibStub("AceDBOptions-3.0")
        local library = ADBO:GetOptionsTable(SMB.data)
        local p = options().args.profiles
        assert_true(p ~= library, "an own group, not AceDBOptions' table")
        assert_true(p.args ~= library.args, "own args, not the library's shared args")
        assert_true(p.handler == library.handler, "the handler of the library's table")
        assert_true(p.handler == ADBO.handlers[SMB.data], "AceDBOptions' handler of this database")
        assert_eq(keysOf(p.args), PROFILE_KEYS)
        for _, key in ipairs(PROFILE_KEYS) do
            assert_true(p.args[key] ~= nil and p.args[key] == library.args[key], key .. " is the library's entry")
        end
        assert_eq({ p.name, p.desc }, { library.name, library.desc }, "name and desc of the library (localized)")
        assert_eq(p.name, "Profiles")
        assert_nil(p.childGroups)
    end)

    it("the constant lists the same keys", function()
        local SMB = fresh()
        local constant = {}
        for i, key in ipairs(SMB.ProfileOptionKeys) do constant[i] = key end
        table.sort(constant)
        assert_eq(constant, PROFILE_KEYS)
    end)

    it("entries of another addon in the library's args (as RestedXP writes them) stay out of the tab", function()
        -- ReloadAddon loads LibStub and every library again (ResetWorld removes the globals that did
        -- not exist before the first load), so the entries cannot leak into the next test; they are
        -- removed at the end all the same.
        ReloadAddon({})
        local ADBO = LibStub("AceDBOptions-3.0")
        -- another addon's database and its table, before this addon builds its options (login)
        local other = LibStub("AceDB-3.0"):New("OtherAddonTestDB", nil, true)
        local shared = ADBO:GetOptionsTable(other).args
        addForeignEntries(shared)
        StartClient()
        local SMB = GetAddon()
        local library = ADBO:GetOptionsTable(SMB.data)
        assert_true(library.args == shared, "AceDBOptions shares one args table between all databases")
        assert_true(library.args.reloadUI ~= nil and library.args.setDefaultProfile ~= nil, "the library's table has them")
        local p = options().args.profiles
        assert_nil(p.args.reloadUI, "no Reload guides and UI")
        assert_nil(p.args.setDefaultProfile, "no Set current profile as default")
        assert_eq(keysOf(p.args), PROFILE_KEYS)
        -- entries written after the build stay out as well
        shared.resetGuideProgress = { order = 0.1, name = "Reset Guide Progress", type = "execute", func = function() end }
        assert_nil(options().args.profiles.args.resetGuideProgress)
        assert_eq(keysOf(options().args.profiles.args), PROFILE_KEYS)
        removeForeignEntries(shared)
        shared.resetGuideProgress = nil
        assert_eq(STUB.errors, {})
    end)

    it("each ReloadAddon loads a fresh AceDBOptions (the foreign entries of a test do not carry over)", function()
        ReloadAddon({})
        local before = LibStub("AceDBOptions-3.0")
        local other = LibStub("AceDB-3.0"):New("OtherAddonTestDB", nil, true)
        addForeignEntries(before:GetOptionsTable(other).args)
        local SMB = fresh()
        local after = LibStub("AceDBOptions-3.0")
        assert_true(after ~= before, "a new library table")
        assert_nil(after:GetOptionsTable(SMB.data).args.reloadUI)
        removeForeignEntries(before:GetOptionsTable(other).args)
    end)

    it("maintenance guard: every entry of the shipped AceDBOptions is in the constant", function()
        local SMB = fresh()
        local ADBO, minor = LibStub("AceDBOptions-3.0")
        local listed = {}
        for _, key in ipairs(SMB.ProfileOptionKeys) do listed[key] = true end
        for key in pairs(ADBO:GetOptionsTable(SMB.data).args) do
            assert_true(listed[key], string.format("AceDBOptions-3.0 revision %s has the entry %s, add it to SMB.ProfileOptionKeys", tostring(minor), key))
        end
    end)

    it("the handler methods are resolved through the group (real AceConfigCmd): choose, copy, reset", function()
        local config = withProfile({})
        config.savedVariables.profiles.Other = { IconSize = 40 }
        local SMB = fresh(config)
        local apply = spy(SMB, "ApplySettings")
        local cmd = LibStub("AceConfigCmd-3.0")
        cmd:HandleCommand("smbtest", APP, "profiles choose Other")
        assert_eq(SMB.data:GetCurrentProfile(), "Other")
        assert_eq(SMB.db.IconSize, 40)
        cmd:HandleCommand("smbtest", APP, "profiles choose Default")
        cmd:HandleCommand("smbtest", APP, "profiles copyfrom Other")
        assert_eq(SMB.db.IconSize, 40, "copied")
        cmd:HandleCommand("smbtest", APP, "profiles reset")
        assert_eq(SMB.db.IconSize, 18, "reset")
        assert_eq(apply.n, 4, "every change rebuilds")
        assert_eq(STUB.errors, {})
    end)

    it("the name function of current gets the handler of the group as info.handler", function()
        local SMB = fresh()
        -- the handler as AceConfigDialog's GetOptionsMemberValue picks it up (AceConfigDialog-3.0.lua
        -- 191-205): the nearest handler on the way from the root to the option
        local root = options()
        local handler, group = root.handler, root
        for _, key in ipairs({ "profiles", "current" }) do
            group = group.args[key]
            handler = group.handler or handler
        end
        assert_true(handler == LibStub("AceDBOptions-3.0").handlers[SMB.data], "inherited from the tab")
        local text = group.name({ "profiles", "current", handler = handler })
        assert_eq(text, "Current Profile: |cffffd200Default|r")
    end)

    it("passes the validation with the own tab in Forever, Retail, Classic, with ElvUI and in German", function()
        local configs = {
            { projectID = FOREVER }, { projectID = RETAIL }, { projectID = CLASSIC },
            { elvui = { options = { loaded = true } } }, { locale = "deDE" },
        }
        for i, config in ipairs(configs) do
            local SMB = fresh(config)
            local registry = LibStub("AceConfigRegistry-3.0")
            local ok, err = pcall(registry.ValidateOptionsTable, registry, SMB.Options, APP)
            assert_true(ok, "config " .. i .. ": " .. tostring(err))
            assert_eq(keysOf(SMB.Options.args.profiles.args), PROFILE_KEYS, "config " .. i)
            assert_true(SMB.Options.args.profiles ~= LibStub("AceDBOptions-3.0"):GetOptionsTable(SMB.data), "config " .. i)
            if config.elvui then
                assert_nil(ElvUI[1].Options.args.SquareMinimapButtons.args.profiles, "ElvUI without the profiles")
            end
        end
        fresh({ locale = "deDE" })
        assert_eq(options().args.profiles.name, "Profile", "AceDBOptions' German name")
    end)

    it("the game settings category shows the same root, with this tab", function()
        local SMB = fresh()
        local dialog = LibStub("AceConfigDialog-3.0")
        local group = dialog.BlizOptions[APP] and dialog.BlizOptions[APP][APP]
        assert_true(group ~= nil, "AddToBlizOptions built its panel")
        assert_eq(group:GetUserData("appName"), APP)
        assert_nil(group:GetUserData("path"), "the root, no sub path")
        group:Fire("OnShow") -- FeedToBlizPanel opens the app in the panel
        assert_eq(#STUB.settings.dialogOpened, 1)
        assert_eq(STUB.settings.dialogOpened[1][1], APP)
        local root = LibStub("AceConfigRegistry-3.0"):GetOptionsTable(APP)("dialog", "AceConfigDialog-3.0")
        assert_true(root == SMB.Options, "the same root")
        assert_true(root.args.profiles ~= LibStub("AceDBOptions-3.0"):GetOptionsTable(SMB.data), "this tab, not the library's table")
        assert_eq(keysOf(root.args.profiles.args), PROFILE_KEYS)
    end)
end)

describe("getters and setters", function()
    it("every getter reads SMB.db[info[#info]]", function()
        local SMB = fresh()
        for key, value in pairs(SAMPLE) do SMB.db[key] = value end
        for _, key in ipairs(MBB_KEYS) do
            assert_eq(getValue({ "General", "MBB", key }), SAMPLE[key], key)
        end
        assert_eq(getValue({ "General", "Strata" }), "HIGH")
        assert_eq(getValue({ "General", "Level" }), 20)
        for _, key in ipairs(BLIZZARD_KEYS) do
            SMB.db[key] = (key == "HideGarrison")
            assert_eq(getValue({ "Blizzard", key }), key == "HideGarrison", key)
        end
        SMB.db.Enable = false
        assert_eq(getValue({ "General", "Enable" }), false)
        SMB.db.TrackerGlowMode = "off"
        assert_eq(getValue({ "Blizzard", "TrackerGlowMode" }), "off")
    end)

    it("the getters read the current profile after a profile change", function()
        local config = withProfile({ IconSize = 30 })
        config.savedVariables.profiles.Other = { IconSize = 40 }
        local SMB = fresh(config)
        assert_eq(getValue({ "General", "MBB", "IconSize" }), 30)
        SMB.data:SetProfile("Other")
        assert_eq(getValue({ "General", "MBB", "IconSize" }), 40)
    end)

    it("every MBB and General setter writes db and calls Update exactly once (not HandleBlizzardButtons)", function()
        local SMB = fresh()
        local keys = {}
        for _, key in ipairs(MBB_KEYS) do keys[#keys + 1] = { "General", "MBB", key } end
        keys[#keys + 1] = { "General", "Strata" }
        keys[#keys + 1] = { "General", "Level" }
        for _, path in ipairs(keys) do
            local key = path[#path]
            local update, blizzard = spy(SMB, "Update"), spy(SMB, "HandleBlizzardButtons")
            setValue(path, SAMPLE[key])
            assert_eq(SMB.db[key], SAMPLE[key], key .. " written")
            assert_eq(update.n, 1, key .. ": one Update")
            assert_eq(blizzard.n, 0, key .. ": no HandleBlizzardButtons")
            update.restore()
            blizzard.restore()
        end
        assert_eq(STUB.errors, {})
    end)

    it("the setters take effect: icon size and strata reach the bar", function()
        local SMB = fresh()
        NewLibDBIconButton("One")
        SMB:GrabMinimapButtons(true)
        setValue({ "General", "MBB", "IconSize" }, 30)
        assert_eq({ SMB.Buttons[1]:GetSize() }, { 30, 30 })
        setValue({ "General", "Strata" }, "HIGH")
        assert_eq(SMB.Bar:GetFrameStrata(), "HIGH")
        assert_eq(STUB.stateDriverLog, {}, "no visibility driver")
    end)

    it("every Blizzard setter writes db and calls HandleBlizzardButtons exactly once", function()
        for _, id in ipairs({ FOREVER, RETAIL, CLASSIC }) do
            local SMB = fresh({ projectID = id })
            for _, key in ipairs(BLIZZARD_KEYS) do
                local blizzard = spy(SMB, "HandleBlizzardButtons")
                local value = not SMB.db[key]
                setValue({ "Blizzard", key }, value)
                assert_eq(SMB.db[key], value, key .. " written, client " .. id)
                assert_eq(blizzard.n, 1, key .. ": one HandleBlizzardButtons, client " .. id)
                blizzard.restore()
            end
        end
        assert_eq(STUB.errors, {})
    end)
end)

describe("Enable", function()
    it("off with the bar built shows the reload dialog SQUAREMINIMAPBUTTONS_RL", function()
        local SMB = fresh()
        assert_true(SMB.Bar ~= nil)
        setValue({ "General", "Enable" }, false)
        assert_eq(SMB.db.Enable, false)
        assert_eq(STUB.popups, { "SQUAREMINIMAPBUTTONS_RL" })
        StaticPopupDialogs.SQUAREMINIMAPBUTTONS_RL.OnAccept()
        assert_eq(STUB.reloads, 1)
    end)

    it("on without a bar runs Initialize, which builds the bar", function()
        local SMB = fresh(withProfile({ Enable = false }))
        assert_nil(SMB.Bar)
        assert_false(SMB.isEnabled)
        local initialize = spy(SMB, "Initialize")
        setValue({ "General", "Enable" }, true)
        assert_eq(initialize.n, 1)
        assert_true(SMB.Bar ~= nil, "the bar exists")
        assert_true(SMB.isEnabled)
        assert_eq(STUB.popups, {})
        -- the timers of Initialize: scan after 6 s, Blizzard buttons after 7 s
        NewLibDBIconButton("Late")
        AdvanceTime(7)
        assert_true(_G.SMB_MailFrame ~= nil)
        assert_true(SMB.Bar:IsShown())
    end)

    it("off without a bar does nothing (as in the original)", function()
        local SMB = fresh(withProfile({ Enable = false }))
        setValue({ "General", "Enable" }, false)
        assert_eq(STUB.popups, {})
        assert_nil(SMB.Bar)
    end)

    it("on again while the bar exists rebuilds it without a dialog", function()
        local SMB = fresh()
        setValue({ "General", "Enable" }, false)
        local update, initialize = spy(SMB, "Update"), spy(SMB, "Initialize")
        setValue({ "General", "Enable" }, true)
        assert_eq(update.n, 1)
        assert_eq(initialize.n, 0)
        assert_eq(STUB.popups, { "SQUAREMINIMAPBUTTONS_RL" }, "only the first dialog")
    end)
end)

describe("Blizzard buttons: reload dialog and build", function()
    it("turning off a built button shows the reload dialog; the button stays until the reload", function()
        local SMB = fresh()
        SMB:HandleBlizzardButtons()
        for _, key in ipairs({ "MoveMail", "MoveTracker", "MoveGameTimeFrame" }) do
            STUB.popups = {}
            setValue({ "Blizzard", key }, false)
            assert_eq(STUB.popups, { "SQUAREMINIMAPBUTTONS_RL" }, key)
        end
        assert_eq(#SMB.Buttons, 3, "nothing is taken out")
    end)

    it("turning off the built queue button shows the dialog too", function()
        local SMB = fresh(withProfile({ MoveQueue = true }))
        SMB:HandleBlizzardButtons()
        assert_true(QueueStatusButton.SMB)
        setValue({ "Blizzard", "MoveQueue" }, false)
        assert_eq(STUB.popups, { "SQUAREMINIMAPBUTTONS_RL" })
    end)

    it("turning off a button that is not built shows no dialog", function()
        local SMB = fresh()
        -- before the 7 second timer: nothing is built yet
        setValue({ "Blizzard", "MoveMail" }, false)
        assert_eq(STUB.popups, {})
        assert_nil(_G.SMB_MailFrame)
        assert_eq(SMB.db.MoveMail, false)
        -- the garrison toggles never build anything
        ReloadAddon({ projectID = RETAIL })
        StartClient()
        GetAddon():HandleBlizzardButtons()
        setValue({ "Blizzard", "MoveGarrison" }, false)
        setValue({ "Blizzard", "HideGarrison" }, false)
        assert_eq(STUB.popups, {})
    end)

    it("turning on builds the button at once", function()
        local SMB = fresh()
        assert_false(SMB.db.MoveQueue, "off by default in Forever")
        setValue({ "Blizzard", "MoveQueue" }, true)
        assert_true(_G.SMB_QueueFrame ~= nil, "queue frame built")
        assert_true(QueueStatusButton:GetParent() == SMB.Bar)
        assert_true(_G.SMB_QueueFrame:GetParent() == SMB.Bar)
        assert_true(SMB.Bar:IsShown(), "laid out (Update)")
        assert_eq(STUB.popups, {})
    end)
end)

describe("hidden and disabled per client", function()
    local function hiddenMap()
        local map = {}
        for _, key in ipairs(BLIZZARD_KEYS) do
            map[key] = call("hidden", { "Blizzard", key }) and true or false
        end
        return map
    end

    it("Forever: garrison hidden; mail, calendar, tracking, queue shown", function()
        fresh({ projectID = FOREVER })
        assert_eq(hiddenMap(), { HideGarrison = true, MoveGarrison = true, MoveMail = false, MoveGameTimeFrame = false, MoveTracker = false, MoveQueue = false })
    end)

    it("Retail: calendar hidden; garrison, mail, tracking, queue shown", function()
        fresh({ projectID = RETAIL })
        assert_eq(hiddenMap(), { HideGarrison = false, MoveGarrison = false, MoveMail = false, MoveGameTimeFrame = true, MoveTracker = false, MoveQueue = false })
    end)

    it("Classic: garrison, tracking, queue hidden; mail and calendar shown", function()
        fresh({ projectID = CLASSIC })
        assert_eq(hiddenMap(), { HideGarrison = true, MoveGarrison = true, MoveMail = false, MoveGameTimeFrame = false, MoveTracker = true, MoveQueue = true })
    end)

    it("the garrison toggles disable each other (original 480-481)", function()
        local SMB = fresh({ projectID = RETAIL })
        SMB.db.MoveGarrison, SMB.db.HideGarrison = true, false
        assert_true(call("disabled", { "Blizzard", "HideGarrison" }))
        assert_false(call("disabled", { "Blizzard", "MoveGarrison" }))
        SMB.db.MoveGarrison, SMB.db.HideGarrison = false, true
        assert_false(call("disabled", { "Blizzard", "HideGarrison" }))
        assert_true(call("disabled", { "Blizzard", "MoveGarrison" }))
    end)

    it("MoveQueue is disabled with a hint while ElvUI's queue module holds the button", function()
        for _, id in ipairs({ FOREVER, RETAIL }) do
            local SMB = fresh({ projectID = id, elvui = { queueStatus = true } })
            assert_true(call("disabled", { "Blizzard", "MoveQueue" }), "before the build, client " .. id)
            SMB:HandleBlizzardButtons()
            assert_true(SMB.queueLocked)
            assert_true(call("disabled", { "Blizzard", "MoveQueue" }), "client " .. id)
            assert_eq(call("desc", { "Blizzard", "MoveQueue" }), "Disabled while ElvUI's queue status mover is active.")
        end
    end)

    it("MoveQueue is enabled without ElvUI's queue module, and follows SMB.queueLocked", function()
        local SMB = fresh({ elvui = {} })
        SMB:HandleBlizzardButtons()
        assert_false(SMB.queueLocked)
        assert_false(call("disabled", { "Blizzard", "MoveQueue" }))
        assert_nil(call("desc", { "Blizzard", "MoveQueue" }))
        SMB.queueLocked = true
        assert_true(call("disabled", { "Blizzard", "MoveQueue" }))
    end)
end)

-- Layout model of the own dialog after the Ace3 sources in Libs/Ace3 (AceConfigDialog-3.0 and
-- AceGUI-3.0); the stubs draw no widgets, so the heights are taken from the code:
--   Frame (AceGUIContainer-Frame.lua OnWidthSet/OnHeightSet): content = width - 34, height - 57
--   TabGroup (AceGUIContainer-TabGroup.lua): content width - 60; borderoffset 10 + 20 per tab row
--     (no title), content height = height - (borderoffset + 23), so - 53 with one row of tabs;
--     the root group with childGroups 'tab' gets no scroll frame, the TabGroup fills the frame
--     (height "fill"), and FeedGroup puts each tab's content into a ScrollFrame
--   ScrollFrame: the full content area, minus 20 for the scroll bar only when it is needed
--   InlineGroup (AceGUIContainer-InlineGroup.lua): content width - 20, height = content + 40
--     (LayoutFinished 32-35, OnWidthSet 37-45; the title of 18 and the border lie in the 40)
--   select with style "radio" (AceConfigDialog-3.0.lua 1232-1273): an InlineGroup with width
--     "fill", the option name as its title and one CheckBox of type radio per value in the order
--     of sorting (alphabetical without it); a radio with width "full" fills its row, so each value
--     is a row of 24 + 3 (CheckBox without description: SetDescription(nil) sets 24)
--   Flow layout (AceGUI-3.0.lua): rows packed left to right, 3 between rows and after the last;
--     a control offsets by its alignoffset (or half its height) when it shares a row
--   CheckBox 24 (no inline description), Slider 44 (alignoffset 25), Dropdown with label 40
--     (alignoffset 26), Button 24, EditBox with label 44 (alignoffset 30), Heading 18, Label =
--     string height (at least 1)
--   AceConfigDialog: width_multiplier 170 for controls without width (numbers multiply it),
--     "full", headers and descriptions without width fill the row
-- The font heights of the labels are estimated generously: small 12, medium 14, large 18 per line,
-- a line holds width / (0.6 * font size) characters, and every line break starts a new line.
local FONT = { small = { 10, 12 }, medium = { 12, 14 }, large = { 16, 18 } }
local WIDTH_MULTIPLIER = 170

local function textOf(value, info)
    if type(value) == "function" then return value(info) end
    return value
end

local function labelHeight(text, fontSize, width)
    local font = FONT[fontSize] or FONT.small
    local perLine = math.max(1, math.floor(width / (0.6 * font[1])))
    local lines = 0
    for part in ((text or "") .. "\n"):gmatch("([^\n]*)\n") do -- every "\n" starts a line
        lines = lines + math.max(1, math.ceil(#part / perLine))
    end
    return lines * font[2]
end

-- the width of a control that does not fill the row (AceConfigDialog "Common Init")
local function controlWidth(width)
    if width == "double" then return WIDTH_MULTIPLIER * 2
    elseif width == "half" then return WIDTH_MULTIPLIER / 2
    elseif type(width) == "number" then return WIDTH_MULTIPLIER * width end
    return WIDTH_MULTIPLIER
end

-- flow layout of the visible options of a group; returns the height and a list of
-- { key, bottom } with the bottom edge of every control (relative to the top of the content);
-- handler: the handler inherited from the groups above (AceConfig passes it as info.handler)
local function flowGroup(group, width, path, top, bottoms, handler)
    handler = group.handler or handler
    local keys = {}
    for key, option in pairs(group.args) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local oa, ob = group.args[a].order or 100, group.args[b].order or 100
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    local height, usedwidth, rowheight, rowoffset, first = 0, 0, 0, 0, true
    local row = {}
    local function closeRow()
        for _, key in ipairs(row) do bottoms[#bottoms + 1] = { key, top + height + rowheight } end
        row = {}
    end
    -- the top of the content of an inline group: a group fills its row, so it starts a new row
    -- below the open one (if any); its content starts 27 lower (InlineGroup Constructor: border at
    -- 0, -17 under the title, content at 10, -10 in the border; the other 13 of the 40 are below it)
    local function groupTop()
        return top + height + (first and 0 or rowheight + 3) + 27
    end
    for _, key in ipairs(keys) do
        local option = group.args[key]
        local info = {}
        for i, k in ipairs(path) do info[i] = k end
        info[#info + 1] = key
        info.handler = handler
        if not textOf(option.hidden, info) then
            local fh, fw, fo, fill
            if option.type == "group" then
                fill = true
                fw = width
                local inner = {}
                local innerHeight = flowGroup(option, width - 20, info, groupTop(), inner, handler)
                fh = innerHeight + 40
                for _, b in ipairs(inner) do bottoms[#bottoms + 1] = b end
            elseif option.type == "select" and option.style == "radio" then
                -- an InlineGroup of radio buttons (toggles of the option's width), one per value
                fill = true
                fw = width
                local values = textOf(option.values, info)
                local sorting = textOf(option.sorting, info)
                if not sorting then
                    sorting = {}
                    for value in pairs(values) do sorting[#sorting + 1] = value end
                    table.sort(sorting, function(a, b) return tostring(a) < tostring(b) end)
                end
                local radios = { args = {} }
                for i, value in ipairs(sorting) do
                    radios.args[key .. "." .. tostring(value)] = { type = "toggle", width = option.width, order = i }
                end
                local inner = {}
                local innerHeight = flowGroup(radios, width - 20, info, groupTop(), inner, handler)
                fh = innerHeight + 40
                for _, b in ipairs(inner) do bottoms[#bottoms + 1] = b end
            elseif option.type == "description" and not option.width then
                fill = true
                fw = width
                fh = labelHeight(textOf(option.name, info), option.fontSize, width)
            elseif option.type == "header" then
                fill, fw, fh = true, width, 18
            else
                fill = option.width == "full"
                fw = fill and width or controlWidth(option.width)
                if option.type == "toggle" or option.type == "execute" then fh = 24
                elseif option.type == "range" then fh, fo = 44, 25
                elseif option.type == "select" then fh, fo = 40, 26
                elseif option.type == "input" then fh, fo = 44, 30
                elseif option.type == "description" then fh = labelHeight(textOf(option.name, info), option.fontSize, fw)
                else error("no height for type " .. tostring(option.type)) end
            end
            fo = fo or fh / 2
            if first then
                rowheight, rowoffset, usedwidth, first = fh, fo, fw, false
            elseif usedwidth == 0 or fw + usedwidth > width or fill then
                closeRow()
                height = height + rowheight + 3
                rowheight, rowoffset, usedwidth = fh, fo, fw
            else
                rowoffset = math.max(rowoffset, fo)
                rowheight = math.max(rowheight, rowoffset + fh / 2)
                usedwidth = usedwidth + fw
            end
            row[#row + 1] = key
            if fill then usedwidth, rowheight, rowoffset = 0, fh, fo end
        end
    end
    closeRow()
    return height + rowheight + 3
end

-- the area of a tab in the own dialog and the flow height of the tab's content
local function measureTab(key, width, height)
    local o = options()
    local tabWidth, tabHeight = width - 34 - 60, height - 57 - 53
    local bottoms = {}
    local needed = flowGroup(o.args[key], tabWidth, { key }, 0, bottoms)
    return needed, tabHeight, tabWidth, bottoms
end

describe("layout of the dialog (nachtrag 2: nothing reaches past the frame)", function()
    local configs = {
        { name = "Forever", config = { projectID = FOREVER } },
        { name = "Retail", config = { projectID = RETAIL } },
        { name = "Classic", config = { projectID = CLASSIC } },
        { name = "ElvUI", config = { elvui = { queueStatus = true } } },
        { name = "German", config = { locale = "deDE" } },
    }

    it("General and Blizzard fit into the tab area of the default size without a scroll bar", function()
        for _, c in ipairs(configs) do
            local SMB = fresh(c.config)
            for _, key in ipairs({ "General", "Blizzard" }) do
                local needed, available, _, bottoms = measureTab(key, SMB.DialogWidth, SMB.DialogHeight)
                assert_true(needed <= available, string.format("%s, %s: %d needed, %d available", c.name, key, needed, available))
                for _, b in ipairs(bottoms) do
                    assert_true(b[2] <= available, string.format("%s, %s: %s ends at %d of %d", c.name, key, b[1], b[2], available))
                end
            end
        end
    end)

    it("the measured heights in Forever (README, Options dialog)", function()
        local SMB = fresh({ projectID = FOREVER })
        local general, available, width = measureTab("General", SMB.DialogWidth, SMB.DialogHeight)
        local blizzard = measureTab("Blizzard", SMB.DialogWidth, SMB.DialogHeight)
        -- Blizzard: four toggles (4 x 27) and the radio group (3 x 27 + 40, then 3)
        assert_eq({ general, blizzard, available, width }, { 299, 232, 450, 546 })
        fresh({ projectID = RETAIL })
        assert_eq((measureTab("Blizzard", SMB.DialogWidth, SMB.DialogHeight)), 259, "Retail: five toggles and the radio group")
    end)

    it("the radio group of the tracker glow: an inline group with one row per value", function()
        local SMB = fresh({ projectID = FOREVER })
        local _, _, _, bottoms = measureTab("Blizzard", SMB.DialogWidth, SMB.DialogHeight)
        local at = {}
        for _, b in ipairs(bottoms) do at[b[1]] = b[2] end
        -- MoveTracker ends at 3 x 27 - 3 = 78; the group starts at 81, its content 27 lower (108)
        assert_eq(at.MoveTracker, 78)
        assert_eq({ at["TrackerGlowMode.always"], at["TrackerGlowMode.outsideRaid"], at["TrackerGlowMode.off"] }, { 132, 159, 186 })
        assert_eq(at.MoveQueue, 81 + 121 + 3 + 24, "MoveQueue under the group (121 high)")
        -- without width "full" the three radios of 170 would share one row
        local option = SMB.Options.args.Blizzard.args.TrackerGlowMode
        option.width = nil
        local narrow = measureTab("Blizzard", SMB.DialogWidth, SMB.DialogHeight)
        option.width = "full"
        assert_eq(narrow, 232 - 54, "two rows fewer")
    end)

    it("Profiles: only the eleven standard entries count; 374 of 450, also with another addon's entries", function()
        for _, c in ipairs(configs) do
            local SMB = fresh(c.config)
            local needed, available, _, bottoms = measureTab("profiles", SMB.DialogWidth, SMB.DialogHeight)
            assert_eq({ needed, available, #bottoms }, { 374, 450, 11 }, c.name)
        end
        -- the entries of RestedXP in the library's args would add rows; the tab does not show them
        ReloadAddon({})
        local other = LibStub("AceDB-3.0"):New("OtherAddonTestDB", nil, true)
        local shared = LibStub("AceDBOptions-3.0"):GetOptionsTable(other).args
        addForeignEntries(shared)
        StartClient()
        local SMB = GetAddon()
        local needed, _, _, bottoms = measureTab("profiles", SMB.DialogWidth, SMB.DialogHeight)
        assert_eq({ needed, #bottoms }, { 374, 11 })
        removeForeignEntries(shared)
    end)

    it("three controls of 170 fit in a row of the tab and of the inline group MBB", function()
        local SMB = fresh()
        local _, _, width = measureTab("General", SMB.DialogWidth, SMB.DialogHeight)
        assert_true(3 * WIDTH_MULTIPLIER <= width - 20, "MBB: three per row")
    end)

    it("at least the sum of all widget heights of General and Blizzard is below the dialog height", function()
        local SMB = fresh({ projectID = RETAIL }) -- the most Blizzard toggles
        local o = options()
        local function sum(group, path)
            local total = 0
            for key, option in pairs(group.args) do
                local info = {}
                for i, k in ipairs(path) do info[i] = k end
                info[#info + 1] = key
                if not textOf(option.hidden, info) then
                    if option.type == "group" then total = total + 40 + sum(option, info)
                    elseif option.type == "select" and option.style == "radio" then
                        local n = 0
                        for _ in pairs(textOf(option.values, info)) do n = n + 1 end
                        total = total + 40 + 24 * n
                    elseif option.type == "toggle" then total = total + 24
                    elseif option.type == "range" then total = total + 44
                    elseif option.type == "select" then total = total + 40
                    elseif option.type == "header" then total = total + 18
                    else total = total + labelHeight(textOf(option.name, info), option.fontSize, 546) end
                end
            end
            return total
        end
        local general, blizzard = sum(o.args.General, { "General" }), sum(o.args.Blizzard, { "Blizzard" })
        assert_true(general < SMB.DialogHeight, "General " .. general)
        assert_true(blizzard < SMB.DialogHeight, "Blizzard " .. blizzard)
    end)

    it("the old one-page tree did not fit: the model reproduces the overflow of the screenshot", function()
        -- the tree before nachtrag 2 at 700 x 620: root without a scroll frame (childGroups 'tab'
        -- with the only tab Profiles), so everything above the TabGroup counted against the frame
        local SMB = fresh()
        local old = {
            args = {
                Description = { type = "description", name = SMB.Description, order = 0 },
                Enable = { type = "toggle", order = 1 },
                General = { type = "group", order = 2, args = {
                    MBB = SMB.Options.args.General.args.MBB,
                    Blizzard = { type = "group", order = 2, args = {
                        MoveMail = { type = "toggle" }, MoveGameTimeFrame = { type = "toggle" },
                        MoveTracker = { type = "toggle" }, MoveQueue = { type = "toggle" },
                    } },
                    Strata = { type = "select", order = 3 }, Level = { type = "range", order = 4 },
                } },
                Extensions = { type = "group", order = 3, args = {
                    AnchorToMinimap = { type = "toggle", order = 1, width = "full" },
                    Point = { type = "select", order = 2 }, RelativePoint = { type = "select", order = 3 },
                    X = { type = "range", order = 4 }, Y = { type = "range", order = 5 },
                    Lock = { type = "toggle", order = 6, width = "full" },
                    IgnoreList = { type = "select", order = 7 }, -- stands in for the 6-line input (much higher)
                } },
                AuthorHeader = { type = "header", order = 96 },
                Authors = { type = "description", name = SMB.Authors, order = 97, fontSize = "large" },
                PortAuthor = { type = "description", name = "WoW Forever port: Zippy", order = 98, fontSize = "medium" },
            },
        }
        local above = flowGroup(old, 700 - 34, {}, 0, {})
        local frameContent = 620 - 57
        local tabMinimum = 53 + 1 -- the TabGroup with the Profiles tab below needs at least its border
        assert_true(above + tabMinimum > frameContent, string.format("%d + %d > %d", above, tabMinimum, frameContent))
    end)
end)

describe("removed options keep the bar where it was", function()
    it("the bar stays anchored TOPLEFT +1/-1 at the minimap and cannot be dragged by default", function()
        local SMB = fresh()
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 })
        assert_false(SMB:CanDragBar())
    end)

    it("ElvUI and Tukui movers stay", function()
        for _, config in ipairs({ { elvui = {} }, { tukui = true } }) do
            local SMB = fresh(config)
            assert_true(SMB.barMover ~= nil)
        end
    end)
end)

describe("profiles, Blizzard settings, dialog", function()
    it("a profile change through the AceDBOptions handler rebuilds (ApplySettings)", function()
        local config = withProfile({})
        config.savedVariables.profiles.Other = { IconSize = 40 }
        local SMB = fresh(config)
        local apply = spy(SMB, "ApplySettings")
        local p = options().args.profiles
        p.handler:SetProfile({ "profiles", "choose" }, "Other")
        assert_eq(apply.n, 1)
        assert_eq(SMB.db.IconSize, 40)
    end)

    it("AddToBlizOptions once: one category with the three tabs (no profiles subcategory any more)", function()
        local SMB = fresh()
        assert_eq(STUB.settings.blizOptions, { { APP, "Square Minimap Buttons", false } })
        assert_eq(#STUB.settings.categories, 1)
        local main = STUB.settings.categories[1]
        assert_eq(main.name, "Square Minimap Buttons")
        assert_eq(STUB.settings.registered, { main })
        assert_eq(SMB.SettingsCategoryID, main.ID)
    end)

    it("SetDefaultSize 640 x 560", function()
        local SMB = fresh()
        assert_eq(STUB.settings.defaultSize, { { APP, 640, 560 } })
        assert_eq({ SMB.DialogWidth, SMB.DialogHeight }, { 640, 560 })
    end)

    it("without the Settings API only the dialog is registered", function()
        ReloadAddon({})
        Settings = nil
        StartClient()
        assert_eq(STUB.settings.blizOptions, {})
        assert_true(LibStub("AceConfigRegistry-3.0"):GetOptionsTable(APP) ~= nil)
        assert_eq(STUB.errors, {})
    end)

    it("/smb, /squareminimap and /squareminimapbuttons open the dialog", function()
        fresh()
        RunSlash("/smb", "")
        RunSlash("/squareminimap", "  ")
        RunSlash("/squareminimapbuttons", "")
        assert_eq(STUB.settings.dialogOpened, { { APP }, { APP }, { APP } })
        assert_eq(ChatContains("The options are not available yet."), 0)
    end)

    it("the addon compartment opens the dialog", function()
        fresh()
        SquareMinimapButtons_OnAddonCompartmentClick()
        assert_eq(STUB.settings.dialogOpened, { { APP } })
    end)

    it("AceConfigCmd reaches the same setters (inheritance through real Ace code)", function()
        local SMB = fresh()
        local cmd = LibStub("AceConfigCmd-3.0")
        local update = spy(SMB, "Update")
        -- tabs are sub-commands, inline groups are flattened on the command line
        cmd:HandleCommand("smbtest", APP, "general iconsize 30")
        assert_eq(SMB.db.IconSize, 30)
        assert_eq(update.n, 1)
        local blizzard = spy(SMB, "HandleBlizzardButtons")
        cmd:HandleCommand("smbtest", APP, "blizzard movequeue on")
        assert_eq(SMB.db.MoveQueue, true)
        assert_eq(blizzard.n, 1)
        cmd:HandleCommand("smbtest", APP, "blizzard trackerglowmode off")
        assert_eq(SMB.db.TrackerGlowMode, "off")
        cmd:HandleCommand("smbtest", APP, "blizzard trackerglowmode outsideraid")
        assert_eq(SMB.db.TrackerGlowMode, "outsideRaid", "AceConfigCmd maps the case back to the key")
        assert_eq(blizzard.n, 1, "the glow builds nothing")
        assert_eq(STUB.errors, {})
    end)
end)

describe("ElvUI options (LibElvUIPlugin)", function()
    local function assertInserted(SMB)
        local group = ElvUI[1].Options.args.SquareMinimapButtons
        assert_true(group ~= nil, "inserted")
        assert_eq(group.type, "group")
        assert_eq(group.name, "Square Minimap Buttons")
        assert_eq(group.childGroups, "tab")
        assert_nil(group.args.profiles, "without the profiles")
        assert_true(group.args.General == SMB.Options.args.General, "the same tabs")
        assert_true(group.args.Blizzard == SMB.Options.args.Blizzard)
        assert_eq(keysOf(group.args), { "Blizzard", "General" })
        assert_true(group.get == SMB.Options.get and group.set == SMB.Options.set, "the same getter and setter")
        LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(group, "ElvUI")
    end

    it("ElvUI_Options loaded: RegisterPlugin calls back at once and the group is inserted", function()
        local SMB = fresh({ elvui = { options = { loaded = true } } })
        assert_eq(#STUB.elvuiPlugins, 1)
        assert_eq(STUB.elvuiPlugins[1].name, "SquareMinimapButtons")
        assertInserted(SMB)
        assert_eq(STUB.errors, {})
    end)

    it("ElvUI_Options loaded later: inserted when ElvUI calls back", function()
        local SMB = fresh({ elvui = { options = true } })
        assert_nil(ElvUI[1].Options.args.SquareMinimapButtons)
        STUB.FireElvUIOptions()
        assertInserted(SMB)
    end)

    it("the setters work from ElvUI's group", function()
        local SMB = fresh({ elvui = { options = { loaded = true } } })
        local group = ElvUI[1].Options.args.SquareMinimapButtons
        group.set({ "SquareMinimapButtons", "General", "MBB", "IconSize" }, 33)
        assert_eq(SMB.db.IconSize, 33)
    end)

    it("nothing without ElvUI, without its options or without its plugin library", function()
        for _, config in ipairs({ {}, { elvui = {} }, { elvui = { options = { noEP = true, loaded = true } } } }) do
            fresh(config)
            assert_eq(STUB.errors, {})
            if ElvUI and ElvUI[1].Options then
                assert_nil(ElvUI[1].Options.args.SquareMinimapButtons)
            end
        end
        local SMB = GetAddon()
        ElvUI = { {} }
        assert_false(SMB.InsertElvUIOptions(), "no ElvUI options table")
        ElvUI = nil
        assert_false(SMB.InsertElvUIOptions(), "no ElvUI")
        ElvUI = { { Options = "broken" } }
        assert_false(SMB.InsertElvUIOptions(), "type guard")
    end)
end)

describe("combat", function()
    it("a Blizzard option in combat waits; HandleBlizzardButtons runs after PLAYER_REGEN_ENABLED exactly once", function()
        local SMB = fresh()
        local blizzard = spy(SMB, "HandleBlizzardButtons")
        SetCombat(true)
        setValue({ "Blizzard", "MoveQueue" }, true)
        setValue({ "Blizzard", "MoveMail" }, false)
        assert_eq(SMB.db.MoveQueue, true, "written at once")
        assert_eq(blizzard.n, 0, "nothing built in combat")
        assert_nil(_G.SMB_QueueFrame)
        assert_eq(#(STUB.eventFrames.PLAYER_REGEN_ENABLED or {}), 1, "the event is registered once")
        SetCombat(false)
        assert_eq(blizzard.n, 1, "once after combat")
        assert_true(_G.SMB_QueueFrame ~= nil)
        assert_true(SMB.Bar:IsShown(), "laid out")
        FireEvent("PLAYER_REGEN_ENABLED")
        SetCombat(true)
        SetCombat(false)
        assert_eq(blizzard.n, 1, "not again")
    end)

    it("an MBB option and a Blizzard option in combat: after combat one HandleBlizzardButtons, one Update", function()
        local SMB = fresh()
        NewLibDBIconButton("One")
        SMB:GrabMinimapButtons(true)
        SetCombat(true)
        local blizzard, update = spy(SMB, "HandleBlizzardButtons"), spy(SMB, "Update")
        setValue({ "General", "MBB", "IconSize" }, 30)
        setValue({ "Blizzard", "MoveMail" }, true)
        assert_eq(update.n, 1, "the setter's Update, which waits")
        SetCombat(false)
        assert_eq(blizzard.n, 1)
        assert_eq(update.n, 2, "one more Update, from HandleBlizzardButtons")
        assert_eq({ SMB.Buttons[1]:GetSize() }, { 30, 30 })
    end)

    it("a profile change in combat builds the Blizzard buttons after combat", function()
        local config = withProfile({})
        config.savedVariables.profiles.Other = { MoveQueue = true }
        local SMB = fresh(config)
        local blizzard = spy(SMB, "HandleBlizzardButtons")
        SetCombat(true)
        SMB.data:SetProfile("Other")
        assert_eq(blizzard.n, 0)
        SetCombat(false)
        assert_eq(blizzard.n, 1)
        assert_true(_G.SMB_QueueFrame ~= nil)
    end)
end)

describe("Lua 5.1", function()
    it("every function of the tree runs without Lua 5.2+ features (stubs remove them)", function()
        assert_nil(utf8)
        assert_nil(table.unpack)
        for _, config in ipairs({ { projectID = FOREVER }, { projectID = RETAIL, elvui = { queueStatus = true } }, { projectID = CLASSIC, tukui = true } }) do
            fresh(config)
            local function walk(node, path)
                local info = {}
                for i, key in ipairs(path) do info[i] = key end
                for _, field in ipairs({ "name", "desc", "hidden", "disabled", "get" }) do
                    if type(node[field]) == "function" then node[field](info) end
                end
                if node.args then
                    for key, child in pairs(node.args) do
                        if key ~= "profiles" then
                            local childPath = {}
                            for i, k in ipairs(path) do childPath[i] = k end
                            childPath[#childPath + 1] = key
                            walk(child, childPath)
                        end
                    end
                end
            end
            local o = options()
            for key, child in pairs(o.args) do
                if key ~= "profiles" and child.type ~= "group" then
                    if type(child.get or o.get) == "function" and child.type ~= "description" and child.type ~= "header" then
                        (child.get or o.get)({ key })
                    end
                end
            end
            walk(o, {})
            assert_eq(STUB.errors, {})
        end
    end)
end)
