-- Test group 4 (locking): LockButton and UnlockButton after ProjectAzilroka's
-- Modules/SquareMinimapButtons.lua.

local METHODS = { "SetParent", "ClearAllPoints", "SetPoint", "SetSize", "SetScale", "SetIgnoreParentScale", "SetFrameStrata", "SetFrameLevel" }

local function fresh()
    ReloadAddon({})
    StartClient()
    return GetAddon()
end

local function snapshot(button)
    local s = StubState(button)
    local points = {}
    for i, p in ipairs(s.points) do points[i] = { p[1], p[2], p[3], p[4], p[5] } end
    return {
        parent = s.parent, points = points, width = s.width, height = s.height, scale = s.scale,
        ignoreParentScale = s.ignoreParentScale, strata = s.strata, level = s.level,
    }
end

-- calls every locked method with values that would change the button
local function tryToMove(button, target)
    button:SetParent(target)
    button:ClearAllPoints()
    button:SetPoint("CENTER", target, "CENTER", 10, 10)
    button:SetSize(99, 99)
    button:SetScale(2)
    button:SetIgnoreParentScale(true)
    button:SetFrameStrata("TOOLTIP")
    button:SetFrameLevel(200)
end

local function newButton()
    local button = NewPlainButton("LockTestButton")
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 1, -1)
    button:SetSize(22, 22)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(12)
    return button
end

describe("LockButton", function()
    it("lists the eight methods of the original", function()
        local SMB = fresh()
        assert_eq(SMB.ButtonFunctions, METHODS)
    end)

    it("sets the eight methods as fields to Noop, so they have no effect", function()
        local SMB = fresh()
        local button = newButton()
        local before = snapshot(button)
        SMB:LockButton(button)
        for _, name in ipairs(METHODS) do
            assert_true(rawget(button, name) == SMB.Noop, name .. " is Noop")
        end
        local bar = CreateFrame("Frame", "SomeBar", UIParent)
        tryToMove(button, bar)
        assert_eq(snapshot(button), before)
        assert_true(button:GetParent() == Minimap, "SetParent changed nothing")
        assert_eq({ button:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 }, "SetPoint changed nothing")
    end)

    it("fixes strata and level (SetFixedFrameStrata/Level(true))", function()
        local SMB = fresh()
        local button = newButton()
        local calls = {}
        button.SetFixedFrameStrata = function(self, v) calls[#calls + 1] = { "strata", v }; StubState(self).fixedStrata = v end
        button.SetFixedFrameLevel = function(self, v) calls[#calls + 1] = { "level", v }; StubState(self).fixedLevel = v end
        SMB:LockButton(button)
        assert_eq(calls, { { "strata", true }, { "level", true } })
        SMB:UnlockButton(button)
        assert_eq(calls, { { "strata", true }, { "level", true }, { "strata", false }, { "level", false } })
    end)

    it("fixes strata and level of a stub frame", function()
        local SMB = fresh()
        local button = newButton()
        SMB:LockButton(button)
        assert_true(button:HasFixedFrameStrata())
        assert_true(button:HasFixedFrameLevel())
    end)

    it("overwrites an own method of the button like the original", function()
        local SMB = fresh()
        local button = newButton()
        local own = function() end
        button.SetPoint = own
        SMB:LockButton(button)
        assert_true(rawget(button, "SetPoint") == SMB.Noop)
        SMB:UnlockButton(button)
        assert_nil(rawget(button, "SetPoint"), "unlock removes the field, the own method is gone")
    end)

    it("works on objects without SetFixedFrameStrata/Level", function()
        local SMB = fresh()
        local object = {}
        SMB:LockButton(object)
        assert_true(object.SetPoint == SMB.Noop)
        SMB:UnlockButton(object)
        assert_nil(object.SetPoint)
    end)
end)

describe("UnlockButton", function()
    it("removes the fields, so the methods of the frame type apply again", function()
        local SMB = fresh()
        local button = newButton()
        SMB:LockButton(button)
        SMB:UnlockButton(button)
        for _, name in ipairs(METHODS) do
            assert_nil(rawget(button, name), name .. " field removed")
            assert_true(button[name] ~= SMB.Noop, name .. " is the real method")
        end
        assert_false(button:HasFixedFrameStrata())
        assert_false(button:HasFixedFrameLevel())
        local bar = CreateFrame("Frame", "SomeBar", UIParent)
        tryToMove(button, bar)
        local s = StubState(button)
        assert_true(button:GetParent() == bar)
        assert_eq({ button:GetPoint() }, { "CENTER", bar, "CENTER", 10, 10 })
        assert_eq(s.points[2], nil, "ClearAllPoints worked")
        assert_eq({ button:GetSize() }, { 99, 99 })
        assert_eq(button:GetScale(), 2)
        assert_true(button:IsIgnoringParentScale())
        assert_eq(button:GetFrameStrata(), "TOOLTIP")
        assert_eq(button:GetFrameLevel(), 200)
    end)

    it("locking and unlocking twice raises no error", function()
        local SMB = fresh()
        local button = newButton()
        local ok, err = pcall(function()
            SMB:LockButton(button)
            SMB:LockButton(button)
            assert_true(rawget(button, "SetPoint") == SMB.Noop)
            SMB:UnlockButton(button)
            SMB:UnlockButton(button)
        end)
        assert_true(ok, tostring(err))
        assert_nil(rawget(button, "SetPoint"))
        assert_false(button:HasFixedFrameLevel())
        button:SetSize(40, 40)
        assert_eq({ button:GetSize() }, { 40, 40 })
    end)

    it("unlocks a LibDBIcon button that LibDBIcon itself had fixed", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        assert_true(button:HasFixedFrameStrata())
        SMB:LockButton(button)
        SMB:UnlockButton(button)
        assert_false(button:HasFixedFrameStrata())
        button:SetFrameLevel(30)
        assert_eq(button:GetFrameLevel(), 30)
    end)
end)
