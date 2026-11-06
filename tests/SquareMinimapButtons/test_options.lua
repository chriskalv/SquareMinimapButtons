-- Test group 8 (options, package 5): the AceConfig tree after ProjectAzilroka's
-- Modules/SquareMinimapButtons.lua GetOptions (454-489) and Init.lua (profiles 618, reload dialog
-- 548-556, Blizzard settings and ElvUI options 639-653), with the changes of the port: hidden per
-- client with WoW Forever, the reload dialog when a built Blizzard button is turned off, MoveQueue
-- disabled while ElvUI's queue module holds the button, the group "Extensions", Blizzard buttons in
-- combat after combat, Blizzard settings with a profiles subcategory and ElvUI's options.

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
        profileKeys = { ["Zippy - Forever"] = "Zippy - Forever" },
        profiles = { ["Zippy - Forever"] = values },
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

local MBB_KEYS = { "BarEnabled", "BarMouseOver", "Backdrop", "IconSize", "ButtonSpacing", "ButtonsPerRow", "Shadows", "ReverseDirection", "Visibility" }
local BLIZZARD_KEYS = { "HideGarrison", "MoveGarrison", "MoveMail", "MoveGameTimeFrame", "MoveTracker", "MoveQueue" }
local STRATA = { "BACKGROUND", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "HIGH", "LOW", "MEDIUM", "TOOLTIP" }
local POINTS = { "BOTTOM", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER", "LEFT", "RIGHT", "TOP", "TOPLEFT", "TOPRIGHT" }

-- a value of the right type that differs from the default
local SAMPLE = {
    BarEnabled = false, BarMouseOver = true, Backdrop = false, IconSize = 30, ButtonSpacing = 4,
    ButtonsPerRow = 3, Shadows = false, ReverseDirection = true, Visibility = "[combat] hide; show",
    Strata = "HIGH", Level = 20,
}

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
        assert_true(RunSlash("/zmb", ""))
        assert_eq(STUB.settings.dialogOpened, { { APP } })
    end)

    it("the validation would catch a broken field (the check is real)", function()
        local SMB = fresh()
        SMB.Options.args.General.args.MBB.args.Visibility.width = {}
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
        assert_eq(#STUB.settings.blizOptions, 2)
        assert_eq(STUB.errors, {})
    end)
end)

describe("structure (Bauplan 5.8, ProjectAzilroka GetOptions)", function()
    it("root: title, description, Enable, General, Extensions, profiles, authors", function()
        fresh()
        local o = options()
        assert_eq(o.type, "group")
        assert_eq(o.name, "Square Minimap Buttons")
        assert_eq(o.desc, "Minimap Button Bar / Minimap Button Skinning")
        assert_eq(type(o.get), "function")
        assert_eq(type(o.set), "function")
        assert_eq(keysOf(o.args), { "AuthorHeader", "Authors", "Description", "Enable", "Extensions", "General", "PortAuthor", "profiles" })
        assert_eq(o.args.Description.type, "description")
        assert_eq(o.args.Description.name, "Minimap Button Bar / Minimap Button Skinning")
        assert_eq(o.args.Description.order, 0)
        assert_eq(o.args.Enable.type, "toggle")
        assert_eq(o.args.Enable.name, "Enable")
        assert_eq(o.args.Enable.order, 1)
        assert_eq(o.args.General.order, 2)
        assert_true(o.args.General.inline)
        assert_eq(o.args.Extensions.order, 3)
        assert_eq(o.args.AuthorHeader.type, "header")
        assert_eq(o.args.AuthorHeader.name, "Authors:")
        assert_eq(o.args.Authors.type, "description")
        assert_eq(o.args.Authors.name, "Azilroka    Sinaris    Omega    Durc")
        assert_eq(o.args.Authors.fontSize, "large")
        assert_eq(o.args.PortAuthor.name, "WoW Forever port: Zippy")
        assert_true(o.args.AuthorHeader.order < o.args.Authors.order and o.args.Authors.order < o.args.PortAuthor.order,
            "authors, then the port line below them")
        assert_true(o.args.PortAuthor.order < 0, "at the end, as in the original (negative order)")
    end)

    it("General: MBB (order 1, inline), Blizzard (2, inline), Strata (3), Level (4)", function()
        fresh()
        local g = options().args.General.args
        assert_eq(keysOf(g), { "Blizzard", "Level", "MBB", "Strata" })
        assert_eq(g.MBB.name, "Minimap Buttons / Bar")
        assert_eq(g.MBB.order, 1)
        assert_true(g.MBB.inline)
        assert_eq(g.Blizzard.name, "Blizzard")
        assert_eq(g.Blizzard.order, 2)
        assert_true(g.Blizzard.inline)
        assert_eq(g.Strata.type, "select")
        assert_eq(g.Strata.name, "Frame Strata")
        assert_eq(g.Strata.order, 3)
        assert_eq(keysOf(g.Strata.values), STRATA)
        for key, label in pairs(g.Strata.values) do assert_eq(label, key) end
        assert_eq(g.Level.type, "range")
        assert_eq(g.Level.name, "Frame Level")
        assert_eq(g.Level.order, 4)
        assert_eq({ g.Level.min, g.Level.max, g.Level.step }, { 0, 255, 1 })
    end)

    it("MBB: the toggles and ranges in the original order, Visibility at 12 (single line, double width)", function()
        fresh()
        local m = options().args.General.args.MBB.args
        assert_eq(keysOf(m), { "Backdrop", "BarEnabled", "BarMouseOver", "ButtonSpacing", "ButtonsPerRow", "IconSize", "ReverseDirection", "Shadows", "Visibility" })
        local expected = {
            { "BarEnabled", "toggle", "Enable Bar", 1 },
            { "BarMouseOver", "toggle", "Bar MouseOver", 2 },
            { "Backdrop", "toggle", "Bar Backdrop", 3 },
            { "IconSize", "range", "Icon Size", 4 },
            { "ButtonSpacing", "range", "Button Spacing", 5 },
            { "ButtonsPerRow", "range", "Buttons Per Row", 6 },
            { "Shadows", "toggle", "Shadows", 7 },
            { "ReverseDirection", "toggle", "Reverse Direction", 8 },
            { "Visibility", "input", "Visibility", 12 },
        }
        for _, e in ipairs(expected) do
            local option = m[e[1]]
            assert_eq({ option.type, option.name, option.order }, { e[2], e[3], e[4] }, e[1])
        end
        assert_eq({ m.IconSize.min, m.IconSize.max, m.IconSize.step }, { 12, 48, 1 })
        assert_eq({ m.ButtonSpacing.min, m.ButtonSpacing.max, m.ButtonSpacing.step }, { -1, 10, 1 })
        assert_eq({ m.ButtonsPerRow.min, m.ButtonsPerRow.max, m.ButtonsPerRow.step }, { 1, 100, 1 })
        assert_eq(m.Visibility.width, "double")
        assert_nil(m.Visibility.multiline, "single line")
    end)

    it("Blizzard: six toggles without order (sorted by name, as in the original) and the group setter", function()
        fresh()
        local b = options().args.General.args.Blizzard
        assert_eq(type(b.set), "function")
        assert_nil(b.get, "reads through the root getter")
        assert_eq(keysOf(b.args), { "HideGarrison", "MoveGameTimeFrame", "MoveGarrison", "MoveMail", "MoveQueue", "MoveTracker" })
        local names = {
            HideGarrison = "Hide Garrison", MoveGarrison = "Move Garrison Icon", MoveMail = "Move Mail Icon",
            MoveGameTimeFrame = "Move Game Time Frame", MoveTracker = "Move Tracker Icon", MoveQueue = "Move Queue Status Icon",
        }
        for key, name in pairs(names) do
            assert_eq({ b.args[key].type, b.args[key].name }, { "toggle", name }, key)
            assert_nil(b.args[key].order, key)
        end
    end)

    it("Extensions: note, anchor, point, relative point, offsets, lock, ignore list", function()
        fresh()
        local e = options().args.Extensions
        assert_eq(e.name, "Extensions")
        assert_true(e.inline)
        local expected = {
            { "MoverNote", "description", 0 }, { "AnchorToMinimap", "toggle", 1 }, { "Point", "select", 2 },
            { "RelativePoint", "select", 3 }, { "X", "range", 4 }, { "Y", "range", 5 }, { "Lock", "toggle", 6 },
            { "IgnoreList", "input", 7 },
        }
        assert_eq(#keysOf(e.args), #expected)
        for _, x in ipairs(expected) do
            assert_eq({ e.args[x[1]].type, e.args[x[1]].order }, { x[2], x[3] }, x[1])
        end
        assert_eq(e.args.AnchorToMinimap.name, "Anchor to Minimap")
        assert_eq(e.args.Lock.name, "Lock Bar")
        assert_eq(e.args.IgnoreList.name, "Ignore List")
        assert_eq(keysOf(e.args.Point.values), POINTS)
        assert_eq(keysOf(e.args.RelativePoint.values), POINTS)
        assert_eq({ e.args.X.min, e.args.X.max, e.args.X.step }, { -200, 200, 1 })
        assert_eq({ e.args.Y.min, e.args.Y.max, e.args.Y.step }, { -200, 200, 1 })
        assert_true(e.args.IgnoreList.multiline ~= nil and e.args.IgnoreList.multiline ~= false, "multiline")
        assert_contains(e.args.IgnoreList.desc, "one frame name or Lua pattern per line")
        assert_contains(e.args.IgnoreList.desc, "stays there until you reload")
    end)

    it("profiles: the AceDBOptions group of the addon's database, last in the tree", function()
        local SMB = fresh()
        local p = options().args.profiles
        assert_true(p == LibStub("AceDBOptions-3.0"):GetOptionsTable(SMB.data), "AceDBOptions table")
        assert_eq(p.type, "group")
        assert_eq(p.order, -1)
        assert_eq(p.handler.db, SMB.data)
    end)

    it("German: PA's texts (original spelling) and the new ones", function()
        fresh({ locale = "deDE" })
        local o = options()
        assert_eq(o.args.Enable.name, "Aktivieren")
        assert_eq(o.args.General.name, "Allgemein")
        assert_eq(o.args.General.args.Blizzard.args.HideGarrison.name, "Verstecke Garnision")
        assert_eq(o.args.General.args.Strata.name, "Fenster Schicht")
        assert_eq(o.args.Extensions.name, "Erweiterungen")
        assert_eq(o.args.AuthorHeader.name, "Autoren:")
        assert_eq(o.args.PortAuthor.name, "Portierung für WoW Forever: Zippy")
        assert_eq(STUB.settings.blizOptions[2][2], "Profile")
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
            assert_eq(getValue({ "General", "Blizzard", key }), key == "HideGarrison", key)
        end
        SMB.db.Enable = false
        assert_eq(getValue({ "Enable" }), false)
        local ext = { AnchorToMinimap = false, Point = "BOTTOM", RelativePoint = "TOP", X = -7, Y = 9, Lock = true }
        for key, value in pairs(ext) do
            SMB.db[key] = value
            assert_eq(getValue({ "Extensions", key }), value, key)
        end
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

    it("the setters take effect: icon size, strata and visibility reach the bar", function()
        local SMB = fresh()
        NewLibDBIconButton("One")
        SMB:GrabMinimapButtons(true)
        setValue({ "General", "MBB", "IconSize" }, 30)
        assert_eq({ SMB.Buttons[1]:GetSize() }, { 30, 30 })
        setValue({ "General", "Strata" }, "HIGH")
        assert_eq(SMB.Bar:GetFrameStrata(), "HIGH")
        setValue({ "General", "MBB", "Visibility" }, "[combat] hide; show")
        assert_eq(STUB.stateDrivers[SMB.Bar].visibility, "[combat] hide; show")
    end)

    it("every Blizzard setter writes db and calls HandleBlizzardButtons exactly once", function()
        for _, id in ipairs({ FOREVER, RETAIL, CLASSIC }) do
            local SMB = fresh({ projectID = id })
            for _, key in ipairs(BLIZZARD_KEYS) do
                local blizzard = spy(SMB, "HandleBlizzardButtons")
                local value = not SMB.db[key]
                setValue({ "General", "Blizzard", key }, value)
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
        setValue({ "Enable" }, false)
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
        setValue({ "Enable" }, true)
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
        setValue({ "Enable" }, false)
        assert_eq(STUB.popups, {})
        assert_nil(SMB.Bar)
    end)

    it("on again while the bar exists rebuilds it without a dialog", function()
        local SMB = fresh()
        setValue({ "Enable" }, false)
        local update, initialize = spy(SMB, "Update"), spy(SMB, "Initialize")
        setValue({ "Enable" }, true)
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
            setValue({ "General", "Blizzard", key }, false)
            assert_eq(STUB.popups, { "SQUAREMINIMAPBUTTONS_RL" }, key)
        end
        assert_eq(#SMB.Buttons, 3, "nothing is taken out")
    end)

    it("turning off the built queue button shows the dialog too", function()
        local SMB = fresh(withProfile({ MoveQueue = true }))
        SMB:HandleBlizzardButtons()
        assert_true(QueueStatusButton.SMB)
        setValue({ "General", "Blizzard", "MoveQueue" }, false)
        assert_eq(STUB.popups, { "SQUAREMINIMAPBUTTONS_RL" })
    end)

    it("turning off a button that is not built shows no dialog", function()
        local SMB = fresh()
        -- before the 7 second timer: nothing is built yet
        setValue({ "General", "Blizzard", "MoveMail" }, false)
        assert_eq(STUB.popups, {})
        assert_nil(_G.SMB_MailFrame)
        assert_eq(SMB.db.MoveMail, false)
        -- the garrison toggles never build anything
        ReloadAddon({ projectID = RETAIL })
        StartClient()
        GetAddon():HandleBlizzardButtons()
        setValue({ "General", "Blizzard", "MoveGarrison" }, false)
        setValue({ "General", "Blizzard", "HideGarrison" }, false)
        assert_eq(STUB.popups, {})
    end)

    it("turning on builds the button at once", function()
        local SMB = fresh()
        assert_false(SMB.db.MoveQueue, "off by default in Forever")
        setValue({ "General", "Blizzard", "MoveQueue" }, true)
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
            map[key] = call("hidden", { "General", "Blizzard", key }) and true or false
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
        assert_true(call("disabled", { "General", "Blizzard", "HideGarrison" }))
        assert_false(call("disabled", { "General", "Blizzard", "MoveGarrison" }))
        SMB.db.MoveGarrison, SMB.db.HideGarrison = false, true
        assert_false(call("disabled", { "General", "Blizzard", "HideGarrison" }))
        assert_true(call("disabled", { "General", "Blizzard", "MoveGarrison" }))
    end)

    it("MoveQueue is disabled with a hint while ElvUI's queue module holds the button", function()
        for _, id in ipairs({ FOREVER, RETAIL }) do
            local SMB = fresh({ projectID = id, elvui = { queueStatus = true } })
            assert_true(call("disabled", { "General", "Blizzard", "MoveQueue" }), "before the build, client " .. id)
            SMB:HandleBlizzardButtons()
            assert_true(SMB.queueLocked)
            assert_true(call("disabled", { "General", "Blizzard", "MoveQueue" }), "client " .. id)
            assert_eq(call("desc", { "General", "Blizzard", "MoveQueue" }), "Disabled while ElvUI's queue status mover is active.")
        end
    end)

    it("MoveQueue is enabled without ElvUI's queue module, and follows SMB.queueLocked", function()
        local SMB = fresh({ elvui = {} })
        SMB:HandleBlizzardButtons()
        assert_false(SMB.queueLocked)
        assert_false(call("disabled", { "General", "Blizzard", "MoveQueue" }))
        assert_nil(call("desc", { "General", "Blizzard", "MoveQueue" }))
        SMB.queueLocked = true
        assert_true(call("disabled", { "General", "Blizzard", "MoveQueue" }))
    end)
end)

describe("extensions", function()
    it("anchor options write db and call ApplyBarPosition once; the bar follows", function()
        local SMB = fresh()
        local values = { Point = "BOTTOMLEFT", RelativePoint = "TOPRIGHT", X = 12, Y = -34 }
        for _, key in ipairs({ "Point", "RelativePoint", "X", "Y" }) do
            local apply, update = spy(SMB, "ApplyBarPosition"), spy(SMB, "Update")
            setValue({ "Extensions", key }, values[key])
            assert_eq(SMB.db[key], values[key], key)
            assert_eq(apply.n, 1, key)
            assert_eq(update.n, 0, key)
            apply.restore()
            update.restore()
        end
        local point, relativeTo, relativePoint, x, y = SMB.Bar:GetPoint()
        assert_eq({ point, relativePoint, x, y }, { "BOTTOMLEFT", "TOPRIGHT", 12, -34 })
        assert_true(relativeTo == Minimap)
    end)

    it("AnchorToMinimap off: the bar moves to its free position and can be dragged", function()
        local SMB = fresh()
        assert_false(SMB:CanDragBar())
        local apply = spy(SMB, "ApplyBarPosition")
        setValue({ "Extensions", "AnchorToMinimap" }, false)
        assert_eq(apply.n, 1)
        local point, relativeTo = SMB.Bar:GetPoint()
        assert_eq(point, "RIGHT")
        assert_true(relativeTo == UIParent)
        assert_true(SMB:CanDragBar())
        assert_true(call("disabled", { "Extensions", "Point" }), "point only with the anchor")
        assert_false(call("disabled", { "Extensions", "AnchorToMinimap" }))
    end)

    it("Lock: CanDragBar false, ApplyBarPosition ends a drag in progress", function()
        local SMB = fresh(withProfile({ AnchorToMinimap = false }))
        SMB:OnDragStart()
        assert_true(SMB.barMoving)
        setValue({ "Extensions", "Lock" }, true)
        assert_eq(SMB.db.Lock, true)
        assert_false(SMB:CanDragBar())
        assert_nil(SMB.barMoving, "drag ended")
        setValue({ "Extensions", "Lock" }, false)
        assert_true(SMB:CanDragBar())
    end)

    it("IgnoreList: text <-> list (blank lines, spaces, patterns, duplicates)", function()
        local SMB = fresh()
        setValue({ "Extensions", "IgnoreList" }, "  Foo  \n\n\nLibDBIcon10_.*\r\n   \n\tBar\nFoo\n")
        assert_eq(SMB.db.IgnoreList, { "Foo", "LibDBIcon10_.*", "Bar" })
        assert_eq(getValue({ "Extensions", "IgnoreList" }), "Foo\nLibDBIcon10_.*\nBar")
        setValue({ "Extensions", "IgnoreList" }, "")
        assert_eq(SMB.db.IgnoreList, {})
        assert_eq(getValue({ "Extensions", "IgnoreList" }), "")
        SMB.db.IgnoreList = { "B", Z = true, A = true } -- set form is read too
        assert_eq(getValue({ "Extensions", "IgnoreList" }), "B\nA\nZ")
        assert_eq(SMB:TextToIgnoreList(nil), {})
        assert_eq(SMB:IgnoreListToText(nil), "")
    end)

    it("IgnoreList: the setter scans again (GrabMinimapButtons(true)); built buttons stay", function()
        local SMB = fresh()
        local old = NewLibDBIconButton("Old")
        SMB:GrabMinimapButtons(true)
        local newOne = NewLibDBIconButton("NewOne")
        local other = NewLibDBIconButton("Other")
        local grab = spy(SMB, "GrabMinimapButtons")
        setValue({ "Extensions", "IgnoreList" }, "LibDBIcon10_New.*\nLibDBIcon10_Old")
        assert_eq(grab.n, 1)
        assert_eq(grab.args[1], { true })
        assert_nil(newOne.isSkinned, "pattern keeps the new button on the minimap")
        assert_true(other.isSkinned, "others are grabbed")
        assert_true(old:GetParent() == SMB.Bar, "a button already in the bar stays until the reload")
    end)

    it("without a mover: note hidden, anchor options enabled", function()
        fresh()
        assert_true(call("hidden", { "Extensions", "MoverNote" }))
        for _, key in ipairs({ "AnchorToMinimap", "Point", "RelativePoint", "X", "Y" }) do
            assert_false(call("disabled", { "Extensions", key }), key)
        end
        assert_false(call("disabled", { "Extensions", "Lock" }) or false)
    end)

    it("with an ElvUI or Tukui mover: note shown, anchor options disabled", function()
        for _, config in ipairs({ { elvui = {} }, { tukui = true } }) do
            local SMB = fresh(config)
            assert_true(SMB.barMover ~= nil)
            assert_false(call("hidden", { "Extensions", "MoverNote" }))
            assert_eq(call("name", { "Extensions", "MoverNote" }), "The ElvUI or Tukui mover holds the position of the bar, so the anchor options are disabled.")
            for _, key in ipairs({ "AnchorToMinimap", "Point", "RelativePoint", "X", "Y" }) do
                assert_true(call("disabled", { "Extensions", key }), key .. " with " .. SMB.barMover)
            end
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

    it("AddToBlizOptions twice: the category and the profiles as its subcategory", function()
        local SMB = fresh()
        assert_eq(STUB.settings.blizOptions, {
            { APP, "Square Minimap Buttons", false },
            { APP, "Profiles", "Square Minimap Buttons", "profiles" },
        })
        assert_eq(#STUB.settings.categories, 2)
        local main, sub = STUB.settings.categories[1], STUB.settings.categories[2]
        assert_eq(main.name, "Square Minimap Buttons")
        assert_eq(sub.name, "Profiles")
        assert_true(sub.parent == main, "subcategory of the addon's category")
        assert_eq(STUB.settings.registered, { main })
        assert_eq(SMB.SettingsCategoryID, main.ID)
        assert_eq(STUB.settings.defaultSize, { { APP, 700, 620 } })
    end)

    it("without the Settings API only the dialog is registered", function()
        ReloadAddon({})
        Settings = nil
        StartClient()
        assert_eq(STUB.settings.blizOptions, {})
        assert_true(LibStub("AceConfigRegistry-3.0"):GetOptionsTable(APP) ~= nil)
        assert_eq(STUB.errors, {})
    end)

    it("/zmb and /zippyminimap open the dialog", function()
        fresh()
        RunSlash("/zmb", "")
        RunSlash("/zippyminimap", "  ")
        assert_eq(STUB.settings.dialogOpened, { { APP }, { APP } })
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
        -- inline groups are flattened on the command line
        cmd:HandleCommand("zmbtest", APP, "iconsize 30")
        assert_eq(SMB.db.IconSize, 30)
        assert_eq(update.n, 1)
        local blizzard = spy(SMB, "HandleBlizzardButtons")
        cmd:HandleCommand("zmbtest", APP, "movequeue on")
        assert_eq(SMB.db.MoveQueue, true)
        assert_eq(blizzard.n, 1)
        cmd:HandleCommand("zmbtest", APP, "x 25")
        assert_eq(SMB.db.X, 25)
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
        assert_true(group.args.General == SMB.Options.args.General, "the same groups")
        assert_true(group.args.Extensions == SMB.Options.args.Extensions)
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
        setValue({ "General", "Blizzard", "MoveQueue" }, true)
        setValue({ "General", "Blizzard", "MoveMail" }, false)
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
        setValue({ "General", "Blizzard", "MoveMail" }, true)
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
