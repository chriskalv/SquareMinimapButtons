-- Test group 8 (part for package 1): default profile, MoveQueue per client, profile callbacks,
-- "/zmb reset", saved variables file.

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
    Visibility = "[petbattle] hide; show",
    HideGarrison = false,
    MoveGarrison = true,
    MoveMail = true,
    MoveGameTimeFrame = true,
    MoveTracker = true,
    MoveQueue = false,
    AnchorToMinimap = true,
    Point = "TOPLEFT",
    RelativePoint = "TOPLEFT",
    X = 1,
    Y = -1,
    Lock = false,
    IgnoreList = {},
}

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

    it("declares no other keys", function()
        local SMB = started({})
        local keys = {}
        for key in pairs(SMB.Defaults.profile) do keys[key] = true end
        local expected = {}
        for key in pairs(EXPECTED_FOREVER) do expected[key] = true end
        assert_eq(keys, expected)
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
    it("uses the AceDB file SquareMinimapButtonsDB with one profile per character", function()
        local SMB = started({})
        assert_eq(type(SquareMinimapButtonsDB), "table")
        assert_true(SMB.data.sv == SquareMinimapButtonsDB, "AceDB works on the global")
        assert_eq(SMB.data:GetCurrentProfile(), "Zippy - Forever")
        assert_eq(SquareMinimapButtonsDB.profileKeys["Zippy - Forever"], "Zippy - Forever")
    end)

    it("keeps stored values and fills the rest with the defaults", function()
        local SMB = started({
            savedVariables = {
                profileKeys = { ["Zippy - Forever"] = "Zippy - Forever" },
                profiles = { ["Zippy - Forever"] = { IconSize = 30, ButtonsPerRow = 6 } },
            },
        })
        assert_eq(SMB.db.IconSize, 30)
        assert_eq(SMB.db.ButtonsPerRow, 6)
        assert_eq(SMB.db.ButtonSpacing, 0)
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
        SMB.data:SetProfile("Zippy - Forever")
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

describe("/zmb reset", function()
    it("restores the defaults of the current profile and says so", function()
        local SMB = started({})
        SMB.db.IconSize = 40
        SMB.db.ButtonsPerRow = 8
        SMB.db.IgnoreList.SomeButton = true
        RunSlash("/zmb", "reset")
        assert_eq(profileValues(SMB.db), EXPECTED_FOREVER)
        assert_eq(ChatContains("The current profile was reset to the defaults."), 1)
    end)

    it("works with /zippyminimap too", function()
        local SMB = started({})
        SMB.db.Lock = true
        RunSlash("/zippyminimap", "reset")
        assert_false(SMB.db.Lock)
    end)
end)
