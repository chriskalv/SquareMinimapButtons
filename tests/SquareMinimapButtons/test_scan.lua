-- Test group 2 (scan): GrabMinimapButtons after ProjectAzilroka's Modules/SquareMinimapButtons.lua,
-- the fixed ignore list and the map pin filters (the own ignore list of the port is gone since
-- nachtrag 2).

local FIXED_NAMES = {
    "BattlefieldMinimap", "ButtonCollectFrame", "ElvUI_MinimapHolder", "ExpansionLandingPageMinimapButton",
    "GameTimeFrame", "HelpOpenWebTicketButton", "HelpOpenTicketButton", "InstanceDifficultyFrame",
    "MinimapBackdrop", "MiniMapMailFrame", "MinimapPanel", "MiniMapTracking", "MiniMapVoiceChatFrame",
    "MinimapZoomIn", "MinimapZoomOut", "QueueStatusButton", "RecipeRadarMinimapButtonFrame",
    "SexyMapCustomBackdrop", "SexyMapPingFrame", "TimeManagerClockButton", "TukuiMinimapCoord",
    "TukuiMinimapZone", "SL_MinimapDifficultyFrame", "SLECoordsHolder", "QuestieFrameGroup",
}

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

describe("scan basics", function()
    it("finds nothing on a fresh Forever minimap (ZoomHitArea, ZoomIn, ZoomOut, MinimapBackdrop)", function()
        local SMB = fresh()
        assert_eq(SMB:GrabMinimapButtons(), 0)
        assert_eq(#SMB.Buttons, 0)
        assert_nil(Minimap.ZoomIn.isSkinned)
        assert_nil(Minimap.ZoomOut.isSkinned)
        assert_nil(MinimapBackdrop.isSkinned)
        assert_nil(Minimap.ZoomHitArea.isSkinned)
    end)

    it("takes a LibDBIcon button and returns the number of new buttons", function()
        local SMB = fresh()
        local a = NewLibDBIconButton("Alpha")
        local b = NewLibDBIconButton("Beta")
        assert_eq(SMB:GrabMinimapButtons(), 2)
        assert_true(a.isSkinned)
        assert_true(b.isSkinned)
        assert_eq(#SMB.Buttons, 2)
    end)

    it("takes only buttons (IsObjectType('Button') as in the original, so also its subtypes)", function()
        local SMB = fresh()
        local frame = CreateFrame("Frame", "SomeAddonMinimapFrame", Minimap)
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        local check = CreateFrame("CheckButton", "SomeAddonCheckButton", Minimap)
        assert_eq(SMB:GrabMinimapButtons(), 1)
        assert_nil(frame.isSkinned)
        assert_true(check.isSkinned)
    end)

    it("does not take a button twice", function()
        local SMB = fresh()
        local a = NewLibDBIconButton("Alpha")
        assert_eq(SMB:GrabMinimapButtons(), 1)
        assert_eq(SMB:GrabMinimapButtons(), 0)
        assert_eq(SMB:GrabMinimapButtons(true), 0)
        assert_eq(#SMB.Buttons, 1)
        assert_true(SMB.Buttons[1] == a)
    end)

    it("keeps the order of the minimap children in SMB.Buttons", function()
        local SMB = fresh()
        local a = NewLibDBIconButton("Zulu")
        NewMinimapPin("TomTom.uid")
        local b = NewPlainButton("AnotherAddonButton")
        local c = NewLibDBIconButton("Alpha")
        SMB:GrabMinimapButtons()
        local d = NewLibDBIconButton("Late")
        SMB:GrabMinimapButtons()
        assert_eq(#SMB.Buttons, 4)
        assert_true(SMB.Buttons[1] == a and SMB.Buttons[2] == b and SMB.Buttons[3] == c and SMB.Buttons[4] == d)
    end)
end)

describe("ignore lists", function()
    it("has exactly the 25 names of the original", function()
        local SMB = fresh()
        local count = 0
        for name, value in pairs(SMB.IgnoreButton) do
            count = count + 1
            assert_eq(value, true, name)
        end
        assert_eq(count, 25)
        for _, name in ipairs(FIXED_NAMES) do
            assert_true(SMB.IgnoreButton[name], name .. " is in the fixed list")
        end
    end)

    it("skips every name of the fixed list", function()
        local SMB = fresh()
        local buttons = {}
        for _, name in ipairs(FIXED_NAMES) do
            buttons[name] = NewPlainButton(name)
        end
        local control = NewPlainButton("NotIgnoredButton")
        assert_eq(SMB:GrabMinimapButtons(), 1)
        for _, name in ipairs(FIXED_NAMES) do
            assert_nil(buttons[name].isSkinned, name .. " must be skipped")
        end
        assert_true(control.isSkinned)
    end)

    it("has no own ignore list any more: a stale db.IgnoreList from an old profile ignores nothing", function()
        local SMB = fresh()
        SMB.db.IgnoreList = { "LibDBIcon10_Exact", "^LibDBIcon10_Pat" }
        local exact = NewLibDBIconButton("Exact")
        local pattern = NewLibDBIconButton("Pattern")
        assert_eq(SMB:GrabMinimapButtons(), 2)
        assert_true(exact.isSkinned)
        assert_true(pattern.isSkinned)
        assert_nil(SMB.IsInIgnoreList, "the own list is gone")
        assert_false(SMB:IsIgnored(nil))
        assert_false(SMB:IsIgnored("LibDBIcon10_Exact"))
        assert_true(SMB:IsIgnored("MinimapZoomIn"))
    end)
end)

describe("map pins and unnamed buttons", function()
    it("rejects every kind of map pin", function()
        local SMB = fresh()
        local pins = {}
        for _, kind in ipairs(PIN_KINDS) do
            pins[kind] = NewMinimapPin(kind)
        end
        assert_eq(SMB:GrabMinimapButtons(), 0)
        for _, kind in ipairs(PIN_KINDS) do
            assert_nil(pins[kind].isSkinned, kind .. " must be rejected")
        end
    end)

    for _, kind in ipairs(PIN_KINDS) do
        it("rejects a pin of kind " .. kind .. " on its own", function()
            local SMB = fresh()
            local pin = NewMinimapPin(kind)
            assert_eq(SMB:GrabMinimapButtons(), 0)
            assert_nil(pin.isSkinned)
        end)
    end

    it("GatherMate2: title alone, or title with x only, is no pin", function()
        local SMB = fresh()
        local a = NewPlainButton("TitleOnly")
        a.title = "Copper Vein"
        local b = NewPlainButton("TitleAndX")
        b.title, b.x = "Copper Vein", 0.5
        assert_eq(SMB:GrabMinimapButtons(), 2)
    end)

    it("TomTom: a point table without uid is no pin", function()
        local SMB = fresh()
        local a = NewPlainButton("PointWithoutUid")
        a.point = {}
        assert_eq(SMB:GrabMinimapButtons(), 1)
    end)

    it("rejects an unnamed button without .icon and takes one with .icon", function()
        local SMB = fresh()
        local without = NewUnnamedButton(false)
        local with = NewUnnamedButton(true)
        assert_eq(SMB:GrabMinimapButtons(), 1)
        assert_nil(without.isSkinned)
        assert_true(with.isSkinned)
    end)

    it("uses .name when the button has no global name", function()
        local SMB = fresh()
        local a = NewUnnamedButton(false)
        a.name = "NamedByField"
        local b = NewUnnamedButton(false)
        b.name = "QueueStatusButton" -- in the fixed list
        assert_eq(SMB:GrabMinimapButtons(), 1)
        assert_true(a.isSkinned)
        assert_nil(b.isSkinned)
    end)

    it("takes TomCats' button (it has none of the pin fields)", function()
        local SMB = fresh()
        local tomcats = NewPlainButton("TomCats-MinimapButton")
        assert_eq(SMB:GrabMinimapButtons(), 1)
        assert_true(tomcats.isSkinned)
    end)
end)

describe("combat and pet battles", function()
    it("does not scan in combat", function()
        local SMB = fresh()
        local a = NewLibDBIconButton("Alpha")
        STUB.combat = true
        local ok, result = pcall(SMB.GrabMinimapButtons, SMB, true)
        assert_true(ok, tostring(result))
        assert_nil(result)
        assert_nil(a.isSkinned)
        assert_eq(#SMB.Buttons, 0)
        STUB.combat = false
        assert_eq(SMB:GrabMinimapButtons(), 1)
    end)

    it("does not scan in a pet battle", function()
        local SMB = fresh({ petBattle = true })
        local a = NewLibDBIconButton("Alpha")
        local ok, result = pcall(SMB.GrabMinimapButtons, SMB)
        assert_true(ok, tostring(result))
        assert_nil(result)
        assert_nil(a.isSkinned)
        STUB.petBattle = false
        assert_eq(SMB:GrabMinimapButtons(), 1)
    end)

    it("scans without C_PetBattles", function()
        local SMB = fresh()
        C_PetBattles = nil
        NewLibDBIconButton("Alpha")
        assert_eq(SMB:GrabMinimapButtons(), 1)
    end)
end)

describe("Update after the scan", function()
    it("calls SMB:Update only for new buttons or with forceUpdate", function()
        local SMB = fresh()
        local calls = 0
        SMB.Update = function(self)
            assert_true(self == SMB)
            calls = calls + 1
        end
        SMB:GrabMinimapButtons()
        assert_eq(calls, 0, "nothing new, no force")
        NewLibDBIconButton("Alpha")
        SMB:GrabMinimapButtons()
        assert_eq(calls, 1, "new button")
        SMB:GrabMinimapButtons()
        assert_eq(calls, 1, "nothing new")
        SMB:GrabMinimapButtons(true)
        assert_eq(calls, 2, "forceUpdate")
        STUB.combat = true
        SMB:GrabMinimapButtons(true)
        assert_eq(calls, 2, "no Update in combat")
        SMB.Update = nil
    end)

    it("runs without SMB.Update", function()
        local SMB = fresh()
        SMB.Update = nil
        NewLibDBIconButton("Alpha")
        local ok, result = pcall(SMB.GrabMinimapButtons, SMB, true)
        assert_true(ok, tostring(result))
        assert_eq(result, 1)
    end)

    it("/smb scan runs the scan", function()
        local SMB = fresh()
        local a = NewLibDBIconButton("Alpha")
        RunSlash("/smb", "scan")
        assert_true(a.isSkinned)
        assert_eq(#SMB.Buttons, 1)
        assert_eq(ChatContains("Scanning is not available yet."), 0)
    end)
end)
