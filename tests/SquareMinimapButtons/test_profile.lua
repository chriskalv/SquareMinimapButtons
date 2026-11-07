-- Test group 8 (part for package 1): default profile, MoveQueue per client, profile callbacks,
-- "/smb reset", saved variables file; since nachtrag 2 the shared profile "Default" (AceDB:New with
-- defaultProfile true) and the one-time switch of characters on their own profile, which takes
-- their values over while Default is untouched (part 2 of nachtrag 2); since nachtrag 4 the tracker
-- glow mode TrackerGlowMode instead of the toggle TrackerGlow, with the migration of old profiles.

local EXPECTED_FOREVER = {
    Enable = true,
    BarEnabled = true,
    BarMouseOver = false,
    Backdrop = true,
    IconSize = 18,
    ButtonSpacing = 0,
    ButtonsPerRow = 1,
    Shadows = true,
    ReverseDirection = false,
    Strata = "MEDIUM",
    Level = 12,
    HideGarrison = false,
    MoveGarrison = true,
    MoveMail = true,
    MoveGameTimeFrame = true,
    MoveTracker = true,
    MoveQueue = false,
    TrackerGlowMode = "outsideRaid",
    AnchorToMinimap = true,
    Point = "TOPLEFT",
    RelativePoint = "TOPLEFT",
    X = 1,
    Y = -1,
}

-- keys that nachtrag 2 removed (Visibility, Lock, own ignore list) and nachtrag 4 (the toggle TrackerGlow)
local REMOVED = { "Visibility", "Lock", "IgnoreList", "TrackerGlow" }

local function copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and copy(v) or v end
    return c
end

-- the profile values as plain table (AceDB serves defaults through metatables)
local function profileValues(db)
    local values = {}
    for key in pairs(EXPECTED_FOREVER) do
        local v = db[key]
        if type(v) == "table" then
            local t = {}
            for k, x in pairs(v) do t[k] = x end
            v = t
        end
        values[key] = v
    end
    return values
end

local function started(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

describe("default profile", function()
    it("matches the build plan in Forever", function()
        local SMB = started({ projectID = 18 })
        assert_eq(profileValues(SMB.db), EXPECTED_FOREVER)
        assert_nil(SMB.db.BarPosition, "no free position by default")
    end)

    it("BuildDefaults: IconSize 18 and ButtonSpacing 0 (changed 2026-11-06), all other values unchanged", function()
        local SMB = started({})
        for _, isForever in ipairs({ true, false }) do
            local profile = SMB.BuildDefaults(isForever).profile
            assert_eq(profile.IconSize, 18, "IconSize")
            assert_eq(profile.ButtonSpacing, 0, "ButtonSpacing")
            local expected = copy(EXPECTED_FOREVER)
            expected.MoveQueue = not isForever
            assert_eq(profile, expected, "isForever " .. tostring(isForever))
        end
    end)

    it("declares no other keys (no Visibility, Lock, IgnoreList or TrackerGlow any more)", function()
        local SMB = started({})
        local keys = {}
        for key in pairs(SMB.Defaults.profile) do keys[key] = true end
        local expected = {}
        for key in pairs(EXPECTED_FOREVER) do expected[key] = true end
        assert_eq(keys, expected)
        for _, key in ipairs(REMOVED) do assert_nil(SMB.Defaults.profile[key], key) end
    end)

    it("TrackerGlowMode is outsideRaid by default in every client; no TrackerGlow", function()
        for _, id in ipairs({ 18, 1, 2 }) do
            local SMB = started({ projectID = id })
            assert_eq(SMB.db.TrackerGlowMode, "outsideRaid", "client " .. id)
            assert_nil(SMB.db.TrackerGlow, "client " .. id)
            assert_eq(SMB.DefaultTrackerGlowMode, "outsideRaid")
            assert_eq(SMB.TrackerGlowModes, { "always", "outsideRaid", "off" })
        end
    end)

    it("an old profile with the removed keys loads without errors; the keys do nothing", function()
        local SMB = started({
            savedVariables = {
                profileKeys = { ["Zippy - Forever"] = "Default" },
                profiles = { Default = { Visibility = "[combat] hide; show", Lock = true, IgnoreList = { "LibDBIcon10_Alpha" }, IconSize = 24 } },
            },
        })
        assert_eq(STUB.errors, {})
        assert_eq(SMB.db.IconSize, 24)
        local alpha = NewLibDBIconButton("Alpha")
        SMB:GrabMinimapButtons(true)
        assert_true(alpha:GetParent() == SMB.Bar, "the old ignore list ignores nothing")
        assert_nil(STUB.stateDrivers[SMB.Bar], "no visibility driver")
        assert_true(SMB.Bar:IsShown())
    end)

    it("MoveQueue is off in Forever and on (ProjectAzilroka's default) in Retail and Classic", function()
        assert_false(started({ projectID = 18 }).db.MoveQueue, "Forever")
        assert_true(started({ projectID = 1 }).db.MoveQueue, "Retail")
        assert_true(started({ projectID = 2 }).db.MoveQueue, "Classic")
    end)

    it("all other defaults are the same in Retail", function()
        local expected = copy(EXPECTED_FOREVER)
        expected.MoveQueue = true
        assert_eq(profileValues(started({ projectID = 1 }).db), expected)
    end)
end)

describe("saved variables", function()
    it("uses the AceDB file SquareMinimapButtonsDB with the shared profile Default", function()
        local SMB = started({})
        assert_eq(type(SquareMinimapButtonsDB), "table")
        assert_true(SMB.data.sv == SquareMinimapButtonsDB, "AceDB works on the global")
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq(SquareMinimapButtonsDB.profileKeys["Zippy - Forever"], "Default")
        assert_nil(SquareMinimapButtonsDB.profiles and SquareMinimapButtonsDB.profiles["Zippy - Forever"], "no profile per character")
    end)

    it("AceDB:New gets defaultProfile true (AceDB maps true to the name Default)", function()
        ReloadAddon({})
        local AceDB = LibStub("AceDB-3.0")
        local new, args = AceDB.New, nil
        AceDB.New = function(self, name, defaults, defaultProfile)
            args = { name, defaultProfile }
            return new(self, name, defaults, defaultProfile)
        end
        StartClient()
        assert_eq(args, { "SquareMinimapButtonsDB", true })
    end)

    it("two characters share the profile Default: a change on one is seen on the other", function()
        local SMB = started({ player = { name = "Zippy", realm = "Forever" } })
        SMB.db.IconSize = 26
        local saved = SquareMinimapButtonsDB
        SMB = started({ player = { name = "Alt", realm = "Other Realm" }, savedVariables = saved })
        assert_eq(SMB.data.keys.char, "Alt - Other Realm")
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq(SMB.db.IconSize, 26, "the value of the first character")
        assert_eq(saved.profileKeys, { ["Zippy - Forever"] = "Default", ["Alt - Other Realm"] = "Default" })
        local names = {}
        for name in pairs(saved.profiles) do names[#names + 1] = name end
        assert_eq(names, { "Default" }, "one profile for both")
    end)

    it("keeps stored values and fills the rest with the defaults", function()
        local SMB = started({
            savedVariables = {
                profileKeys = { ["Zippy - Forever"] = "Default" },
                profiles = { Default = { IconSize = 30, ButtonsPerRow = 6 } },
            },
        })
        assert_eq(SMB.db.IconSize, 30)
        assert_eq(SMB.db.ButtonsPerRow, 6)
        assert_eq(SMB.db.ButtonSpacing, 0)
    end)
end)

describe("one-time switch to Default for characters of the first test versions", function()
    -- the saved variables of a character that an earlier test version put on its own profile
    local function oldFile(values, default)
        return {
            profileKeys = { ["Zippy - Forever"] = "Zippy - Forever" },
            profiles = { ["Zippy - Forever"] = values or { IconSize = 24, Shadows = false }, Default = default },
        }
    end

    local function sortedProfiles(SMB)
        local profiles = SMB.data:GetProfiles()
        table.sort(profiles)
        return profiles
    end

    it("own profile with values, Default untouched: switches to Default and takes the values over", function()
        local SMB = started({ savedVariables = oldFile() })
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq({ SMB.db.IconSize, SMB.db.Shadows }, { 24, false }, "the old settings")
        assert_eq(SMB.db.ButtonsPerRow, 1, "the rest from the defaults")
        assert_true(SMB.db == SMB.data.profile, "db is the profile Default")
        assert_true(SMB.data.char.SharedProfileMigrated, "marker in the character section")
        assert_eq(sortedProfiles(SMB), { "Default", "Zippy - Forever" }, "the old profile is still there")
        assert_eq(SquareMinimapButtonsDB.profileKeys["Zippy - Forever"], "Default")
        assert_eq(ChatContains("Square Minimap Buttons:|r this character now uses the shared profile Default (settings copied from Zippy - Forever)"), 1)
        assert_eq(STUB.errors, {})
    end)

    it("an empty Default table counts as untouched (AceDB stores only values that differ from the defaults)", function()
        local SMB = started({ savedVariables = oldFile(nil, {}) })
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq({ SMB.db.IconSize, SMB.db.Shadows }, { 24, false })
    end)

    it("Default has values already (another character was first): switches without copying", function()
        local SMB = started({ savedVariables = oldFile({ IconSize = 24, Shadows = false }, { IconSize = 30 }) })
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq({ SMB.db.IconSize, SMB.db.Shadows }, { 30, true }, "the values of Default, nothing copied")
        assert_eq(sortedProfiles(SMB), { "Default", "Zippy - Forever" })
        SMB.data:CopyProfile("Zippy - Forever")
        assert_eq({ SMB.db.IconSize, SMB.db.Shadows }, { 24, false }, "Profiles > Copy From still takes the old settings over")
        assert_eq(ChatContains("this character now uses the shared profile Default"), 1)
        assert_eq(ChatContains("settings copied"), 0)
    end)

    it("own profile without values: switches without copying and without errors", function()
        for _, values in ipairs({ {}, false }) do
            local file = oldFile(values or nil)
            if values == false then file.profiles["Zippy - Forever"] = nil end
            local SMB = started({ savedVariables = file })
            assert_eq(SMB.data:GetCurrentProfile(), "Default")
            assert_eq(profileValues(SMB.db), EXPECTED_FOREVER)
            assert_eq(STUB.errors, {})
            assert_eq(ChatContains("this character now uses the shared profile Default"), 1)
            assert_eq(ChatContains("settings copied"), 0)
        end
    end)

    it("MigrateToSharedProfile returns switched and copied", function()
        ReloadAddon({})
        local SMB = GetAddon()
        local AceDB = LibStub("AceDB-3.0")
        SquareMinimapButtonsDB = oldFile()
        assert_eq({ SMB:MigrateToSharedProfile(AceDB:New("SquareMinimapButtonsDB", SMB.Defaults, true)) }, { true, true })
        SquareMinimapButtonsDB = oldFile(nil, { IconSize = 30 })
        assert_eq({ SMB:MigrateToSharedProfile(AceDB:New("SquareMinimapButtonsDB", SMB.Defaults, true)) }, { true, false })
        SquareMinimapButtonsDB = oldFile({})
        assert_eq({ SMB:MigrateToSharedProfile(AceDB:New("SquareMinimapButtonsDB", SMB.Defaults, true)) }, { true, false })
        local data = AceDB:New("SquareMinimapButtonsDB", SMB.Defaults, true)
        assert_eq({ SMB:MigrateToSharedProfile(data) }, { false, false }, "marker set")
        assert_eq({ SMB:MigrateToSharedProfile(nil) }, { false, false })
    end)

    it("happens only once: a character that chooses its own profile again keeps it", function()
        local SMB = started({ savedVariables = oldFile() })
        SMB.data:SetProfile("Zippy - Forever")
        SMB.db.IconSize = 26
        local saved = SquareMinimapButtonsDB
        SMB = started({ savedVariables = saved })
        assert_eq(SMB.data:GetCurrentProfile(), "Zippy - Forever")
        assert_eq(SMB.db.IconSize, 26)
        assert_eq(ChatContains("shared profile"), 0, "no second message")
    end)

    it("a character on another chosen profile (Foo) is left alone", function()
        local SMB = started({
            savedVariables = {
                profileKeys = { ["Zippy - Forever"] = "Foo" },
                profiles = { Foo = { IconSize = 40 }, ["Zippy - Forever"] = { IconSize = 24 } },
            },
        })
        assert_eq(SMB.data:GetCurrentProfile(), "Foo")
        assert_eq(SMB.db.IconSize, 40)
        assert_true(SMB.data.char.SharedProfileMigrated)
        assert_nil(rawget(SquareMinimapButtonsDB.profiles, "Default"), "Default not created")
        assert_eq(ChatContains("shared profile"), 0)
    end)

    it("the switch runs before the callbacks: no rebuild at load", function()
        ReloadAddon({ savedVariables = oldFile() })
        local SMB = GetAddon()
        local applied = 0
        local apply = SMB.ApplySettings
        SMB.ApplySettings = function(self) applied = applied + 1; return apply(self) end
        StartClient()
        assert_eq(applied, 0)
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq(SMB.db.IconSize, 24, "the copied value is read once after the switch")
        assert_true(SMB.Bar ~= nil, "the bar is built after the switch")
    end)

    it("the message is printed once at login, also while the guard blocks the addon", function()
        local SMB = started({ savedVariables = oldFile(), pa = { enabled = true } })
        assert_true(SMB.blocked)
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq(ChatContains("this character now uses the shared profile Default (settings copied from Zippy - Forever)"), 1)
    end)

    it("German message", function()
        started({ savedVariables = oldFile(), locale = "deDE" })
        assert_eq(ChatContains("dieser Charakter nutzt jetzt das gemeinsame Profil Default (Einstellungen übernommen aus Zippy - Forever)"), 1)
    end)
end)

describe("migration of the toggle TrackerGlow (nachtrag 4)", function()
    local function file(profiles, current)
        return {
            profileKeys = { ["Zippy - Forever"] = current or "Default" },
            profiles = profiles,
        }
    end

    it("stored TrackerGlow = false becomes TrackerGlowMode off, the old key is removed", function()
        local SMB = started({ savedVariables = file({ Default = { TrackerGlow = false, IconSize = 24 } }) })
        assert_eq(SMB.db.TrackerGlowMode, "off")
        local stored = SquareMinimapButtonsDB.profiles.Default
        assert_nil(rawget(stored, "TrackerGlow"), "old key removed from the stored table")
        assert_eq(rawget(stored, "TrackerGlowMode"), "off")
        assert_eq(SMB.db.IconSize, 24, "other values stay")
        assert_eq(STUB.errors, {})
    end)

    it("stored TrackerGlow = true keeps the default, the old key is removed", function()
        local SMB = started({ savedVariables = file({ Default = { TrackerGlow = true } }) })
        assert_eq(SMB.db.TrackerGlowMode, "outsideRaid")
        assert_nil(rawget(SquareMinimapButtonsDB.profiles.Default, "TrackerGlow"))
    end)

    it("no TrackerGlow stored: the default", function()
        local SMB = started({ savedVariables = file({ Default = { IconSize = 24 } }) })
        assert_eq(SMB.db.TrackerGlowMode, "outsideRaid")
        assert_nil(rawget(SquareMinimapButtonsDB.profiles.Default, "TrackerGlow"))
    end)

    it("a profile that stores TrackerGlowMode keeps it", function()
        for _, mode in ipairs({ "always", "off", "outsideRaid" }) do
            local SMB = started({ savedVariables = file({ Default = { TrackerGlowMode = mode } }) })
            assert_eq(SMB.db.TrackerGlowMode, mode)
        end
        -- both keys (only after a downgrade): the stored mode wins, the old key goes
        local SMB = started({ savedVariables = file({ Default = { TrackerGlowMode = "always", TrackerGlow = false } }) })
        assert_eq(SMB.db.TrackerGlowMode, "always")
        assert_nil(rawget(SquareMinimapButtonsDB.profiles.Default, "TrackerGlow"))
    end)

    it("runs again after SetProfile to another old profile (and after CopyProfile)", function()
        local SMB = started({ savedVariables = file({ Default = {}, Old = { TrackerGlow = false }, Older = { TrackerGlow = false } }) })
        assert_eq(SMB.db.TrackerGlowMode, "outsideRaid")
        SMB.data:SetProfile("Old")
        assert_eq(SMB.db.TrackerGlowMode, "off", "migrated on the profile change")
        assert_nil(rawget(SquareMinimapButtonsDB.profiles.Old, "TrackerGlow"))
        SMB.data:SetProfile("Default")
        assert_eq(SMB.db.TrackerGlowMode, "outsideRaid")
        SMB.data:CopyProfile("Older")
        assert_eq(SMB.db.TrackerGlowMode, "off", "the copy of an old profile is migrated")
        assert_nil(rawget(SquareMinimapButtonsDB.profiles.Default, "TrackerGlow"))
    end)

    it("after the one-time switch to Default the copied old values are migrated too", function()
        local SMB = started({ savedVariables = file({ ["Zippy - Forever"] = { TrackerGlow = false, IconSize = 24 } }, "Zippy - Forever") })
        assert_eq(SMB.data:GetCurrentProfile(), "Default")
        assert_eq(SMB.db.IconSize, 24)
        assert_eq(SMB.db.TrackerGlowMode, "off")
        assert_nil(rawget(SquareMinimapButtonsDB.profiles.Default, "TrackerGlow"))
    end)

    it("the stored mode survives the logout (AceDB removes only the defaults)", function()
        started({ savedVariables = file({ Default = { TrackerGlow = false } }) })
        FireEvent("PLAYER_LOGOUT")
        assert_eq(SquareMinimapButtonsDB.profiles.Default, { TrackerGlowMode = "off" })
        started({ savedVariables = file({ Default = { TrackerGlow = true } }) })
        FireEvent("PLAYER_LOGOUT")
        assert_nil(SquareMinimapButtonsDB.profiles.Default and next(SquareMinimapButtonsDB.profiles.Default), "nothing left to store")
    end)

    it("MigrateTrackerGlow is idempotent and returns whether the old key was there", function()
        ReloadAddon({})
        local SMB = GetAddon()
        local profile = { TrackerGlow = false }
        assert_true(SMB:MigrateTrackerGlow(profile))
        assert_eq(profile, { TrackerGlowMode = "off" })
        assert_false(SMB:MigrateTrackerGlow(profile))
        assert_eq(profile, { TrackerGlowMode = "off" })
        profile = { TrackerGlow = true }
        assert_true(SMB:MigrateTrackerGlow(profile))
        assert_eq(profile, {})
        assert_false(SMB:MigrateTrackerGlow(nil))
        assert_false(SMB:MigrateTrackerGlow({}))
    end)
end)

describe("profile callbacks", function()
    local function withSpies()
        local SMB = started({})
        local log = {}
        SMB.Update = function() log[#log + 1] = "Update" end
        SMB.HandleBlizzardButtons = function() log[#log + 1] = "HandleBlizzardButtons" end
        return SMB, log
    end

    it("a profile change calls ApplySettings, which reads the new profile and rebuilds", function()
        local SMB, log = withSpies()
        SMB.data:SetProfile("Other")
        assert_eq(log, { "Update", "HandleBlizzardButtons" })
        assert_true(SMB.db == SMB.data.profile, "db points to the new profile")
        assert_eq(SMB.data:GetCurrentProfile(), "Other")
    end)

    it("copying a profile calls ApplySettings", function()
        local SMB, log = withSpies()
        SMB.data:SetProfile("Other")
        SMB.db.IconSize = 40
        SMB.data:SetProfile("Default")
        for i = #log, 1, -1 do log[i] = nil end
        SMB.data:CopyProfile("Other")
        assert_eq(log, { "Update", "HandleBlizzardButtons" })
        assert_eq(SMB.db.IconSize, 40)
    end)

    it("resetting a profile calls ApplySettings", function()
        local SMB, log = withSpies()
        SMB.db.IconSize = 40
        SMB.data:ResetProfile()
        assert_eq(log, { "Update", "HandleBlizzardButtons" })
        assert_eq(SMB.db.IconSize, 18)
    end)

    it("sets the position of the bar again before the rebuild", function()
        local SMB, log = withSpies()
        SMB.ApplyBarPosition = function() log[#log + 1] = "ApplyBarPosition" end
        SMB.data:SetProfile("Other")
        assert_eq(log, { "ApplyBarPosition", "Update", "HandleBlizzardButtons" })
    end)

    it("without Update and HandleBlizzardButtons (package 1) ApplySettings only reads the settings", function()
        local SMB = started({})
        SMB.data:SetProfile("Other")
        assert_true(SMB.db == SMB.data.profile)
        assert_eq(STUB.errors, {})
    end)
end)

describe("/smb reset", function()
    it("restores the defaults of the current profile and says so", function()
        local SMB = started({})
        SMB.db.IconSize = 40
        SMB.db.ButtonsPerRow = 8
        SMB.db.TrackerGlowMode = "off"
        RunSlash("/smb", "reset")
        assert_eq(profileValues(SMB.db), EXPECTED_FOREVER)
        assert_eq(ChatContains("The current profile was reset to the defaults."), 1)
    end)

    it("works with /squareminimap and /squareminimapbuttons too", function()
        local SMB = started({})
        SMB.db.ReverseDirection = true
        RunSlash("/squareminimap", "reset")
        assert_false(SMB.db.ReverseDirection)
        SMB.db.Shadows = false
        RunSlash("/squareminimapbuttons", "reset")
        assert_true(SMB.db.Shadows)
    end)
end)
