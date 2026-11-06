-- Test group 5 (bar): Initialize and Update after ProjectAzilroka's Modules/SquareMinimapButtons.lua
-- (Initialize 522-558, Update 379-452, OnDragStart/OnDragStop 371-377), with the changes of the
-- port: position from the profile (anchored to the minimap by default), dragging of the bar itself
-- with a saved position, the lock, IsShown() for buttons already in the bar, Update after combat,
-- rebuild on profile changes.

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

-- a profile stored in the saved variables for the character Zippy - Forever
local function withProfile(values, config)
    config = config or {}
    config.savedVariables = {
        profileKeys = { ["Zippy - Forever"] = "Zippy - Forever" },
        profiles = { ["Zippy - Forever"] = values },
    }
    return config
end

local function addButtons(n)
    local list = {}
    for i = 1, n do list[i] = NewLibDBIconButton(string.format("Button%02d", i)) end
    return list
end

local function countFramesNamed(name)
    local count = 0
    for _, frame in ipairs(STUB.frames) do
        if frame:GetName() == name then count = count + 1 end
    end
    return count
end

-- { anchor, x, y } of each button; every button must be anchored with the same point to the bar
local function layout(SMB, buttons)
    local result = {}
    for i, button in ipairs(buttons) do
        local point, relativeTo, relativePoint, x, y = button:GetPoint()
        assert_true(relativeTo == SMB.Bar, "button " .. i .. " is anchored to the bar")
        assert_eq(relativePoint, point, "button " .. i .. " uses the same point on the bar")
        assert_eq(button:GetNumPoints(), 1, "button " .. i .. " has one point")
        result[i] = { point, x, y }
    end
    return result
end

describe("start (Initialize)", function()
    it("builds the bar SquareMinimapButtonBar at UIParent, hidden until the first Update", function()
        ReloadAddon({})
        local SMB = GetAddon()
        assert_nil(SMB.Bar, "no bar before PLAYER_LOGIN")
        FireEvent("ADDON_LOADED", ADDON_NAME)
        STUB.loggedIn = true
        FireEvent("PLAYER_LOGIN")
        local Bar = SMB.Bar
        assert_true(Bar ~= nil and Bar == _G.SquareMinimapButtonBar)
        assert_eq(Bar:GetObjectType(), "Frame")
        assert_true(Bar:GetParent() == UIParent)
        assert_false(Bar:IsShown(), "hidden until PLAYER_ENTERING_WORLD scans")
        assert_true(Bar:IsClampedToScreen())
        assert_true(Bar:IsMovable())
        assert_true(Bar:IsMouseEnabled())
        assert_eq({ Bar:GetSize() }, { 22, 22 }, "IconSize until the first Update")
        assert_true(SMB.isEnabled)
        assert_eq(Bar:GetBackdrop(), { bgFile = SMB.Solid, edgeFile = SMB.Solid, edgeSize = 1 }, "template")
        assert_eq({ Bar:GetBackdropBorderColor() }, { 0, 0, 0, 1 }, "black border without ElvUI")
    end)

    it("is idempotent: a second Initialize builds no second bar and no second set of timers", function()
        local SMB = fresh()
        local Bar = SMB.Bar
        local timers = PendingTimers()
        SMB:Initialize()
        SMB:Initialize()
        assert_true(SMB.Bar == Bar)
        assert_eq(countFramesNamed("SquareMinimapButtonBar"), 1)
        assert_eq(PendingTimers(), timers)
    end)

    it("default profile: TOPLEFT of the bar at TOPLEFT of the minimap, offset +1/-1", function()
        local SMB = fresh()
        assert_eq(SMB.Bar:GetNumPoints(), 1)
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 })
    end)

    it("anchored with other points and offsets from the profile", function()
        local SMB = fresh(withProfile({ Point = "TOPRIGHT", RelativePoint = "TOPLEFT", X = -1, Y = 0 }))
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPRIGHT", Minimap, "TOPLEFT", -1, 0 })
    end)

    it("without the minimap anchor and without a saved position: RIGHT of UIParent, -45/0 (original)", function()
        local SMB = fresh(withProfile({ AnchorToMinimap = false }))
        assert_eq(SMB.Bar:GetNumPoints(), 1)
        assert_eq({ SMB.Bar:GetPoint() }, { "RIGHT", UIParent, "RIGHT", -45, 0 })
    end)

    it("without the minimap anchor: the saved free position", function()
        local SMB = fresh(withProfile({ AnchorToMinimap = false, BarPosition = { "BOTTOMLEFT", "BOTTOMLEFT", 120, 340 } }))
        assert_eq({ SMB.Bar:GetPoint() }, { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 120, 340 })
    end)

    it("a saved free position does not count while the bar is anchored to the minimap", function()
        local SMB = fresh(withProfile({ BarPosition = { "BOTTOMLEFT", "BOTTOMLEFT", 120, 340 } }))
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 })
    end)

    it("without ElvUI and Tukui: the bar is registered for dragging and has OnDragStart/OnDragStop", function()
        local SMB = fresh()
        assert_eq(StubState(SMB.Bar).dragButtons, { "LeftButton" })
        assert_true(SMB.Bar:GetScript("OnDragStart") == SMB.OnDragStart)
        assert_true(SMB.Bar:GetScript("OnDragStop") == SMB.OnDragStop)
        assert_nil(SMB.barMover)
        assert_nil(STUB.calls.ElvUICreateMover)
        assert_nil(STUB.calls.TukuiRegisterFrame)
    end)

    it("with ElvUI: E:CreateMover with the name SquareMinimapButtonBarMover, as in the original", function()
        local SMB = fresh({ elvui = {} })
        local call = STUB.calls.ElvUICreateMover
        assert_true(call ~= nil, "CreateMover called")
        assert_true(call[1] == SMB.Bar)
        assert_eq(call.n, 7)
        assert_eq(call[2], "SquareMinimapButtonBarMover")
        assert_eq(call[3], "SquareMinimapButtonBar Anchor")
        assert_nil(call[4])
        assert_nil(call[5])
        assert_nil(call[6])
        assert_eq(call[7], "ALL,GENERAL")
        assert_eq(call.originPoint, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 }, "the mover starts at the minimap")
        assert_nil(StubState(SMB.Bar).dragButtons, "no drag registration")
        assert_nil(SMB.Bar:GetScript("OnDragStart"))
        assert_eq(SMB.barMover, "ElvUI")
    end)

    it("with Tukui: Tukui[1].Movers:RegisterFrame(Bar); Tukui comes first, as in the original", function()
        local SMB = fresh({ tukui = true })
        assert_true(STUB.calls.TukuiRegisterFrame == SMB.Bar)
        assert_nil(StubState(SMB.Bar).dragButtons)
        assert_eq(SMB.barMover, "Tukui")
        SMB = fresh({ tukui = true, elvui = {} })
        assert_true(STUB.calls.TukuiRegisterFrame == SMB.Bar)
        assert_nil(STUB.calls.ElvUICreateMover)
    end)

    it("ElvUI enabled but not loaded (no global ElvUI): dragging as without ElvUI, no error", function()
        ReloadAddon({ elvui = {} })
        ElvUI = nil
        StartClient()
        local SMB = GetAddon()
        assert_true(SMB.ElvUI, "enabled for the character")
        assert_eq(STUB.errors, {})
        assert_nil(SMB.barMover)
        assert_eq(StubState(SMB.Bar).dragButtons, { "LeftButton" })
    end)

    it("Enable off: no bar, no scan on PLAYER_ENTERING_WORLD or by the timer", function()
        local SMB = fresh(withProfile({ Enable = false }))
        assert_nil(SMB.Bar)
        assert_nil(_G.SquareMinimapButtonBar)
        assert_false(SMB.isEnabled)
        local button = NewLibDBIconButton("Alpha")
        FireEvent("PLAYER_ENTERING_WORLD", false, true)
        AdvanceTime(20)
        assert_nil(button.isSkinned)
        assert_eq(STUB.errors, {})
    end)

    it("PLAYER_ENTERING_WORLD scans with forceUpdate", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        FireEvent("PLAYER_ENTERING_WORLD", false, true)
        assert_true(button.isSkinned)
        assert_true(button:GetParent() == SMB.Bar)
        local calls = 0
        local update = SMB.Update
        SMB.Update = function(self) calls = calls + 1 return update(self) end
        FireEvent("PLAYER_ENTERING_WORLD", false, true)
        assert_eq(calls, 1, "Update without a new button (forceUpdate)")
        SMB.Update = update
    end)

    it("scans every 6 seconds", function()
        local SMB = fresh()
        local a = NewLibDBIconButton("Alpha")
        AdvanceTime(5.9)
        assert_nil(a.isSkinned, "not before 6 s")
        AdvanceTime(0.2)
        assert_true(a.isSkinned, "after 6 s")
        local b = NewLibDBIconButton("Beta")
        AdvanceTime(5.8)
        assert_nil(b.isSkinned)
        AdvanceTime(0.2)
        assert_true(b.isSkinned, "after 12 s")
        assert_true(SMB.Buttons[2] == b)
    end)

    it("the 7 second timer calls HandleBlizzardButtons once if it exists, and raises no error without it", function()
        local SMB = fresh()
        AdvanceTime(7.1)
        assert_eq(STUB.errors, {})
        SMB = fresh()
        local calls = 0
        SMB.HandleBlizzardButtons = function(self)
            assert_true(self == SMB)
            calls = calls + 1
        end
        AdvanceTime(6.9)
        assert_eq(calls, 0)
        AdvanceTime(0.2)
        assert_eq(calls, 1)
        AdvanceTime(30)
        assert_eq(calls, 1, "only once")
    end)
end)

-- Expected layouts with IconSize 22 and ButtonSpacing 2 (step 24), computed by hand from
-- ProjectAzilroka 388-431:
--   x = Spacing + (Size + Spacing) * (column - 1), y = -Spacing - (Size + Spacing) * (row - 1)
--   width = 2 * Spacing + Size * n + Spacing * (n - 1), n = columns of the widest row (0 without
--   buttons, so the width is Spacing), height the same with the number of rows (at least 1).
local GRID = {
    { n = 0, perRow = 1, size = { 2, 26 }, points = {} },
    { n = 1, perRow = 1, size = { 26, 26 }, points = { { 2, -2 } } },
    { n = 5, perRow = 1, size = { 26, 122 }, points = { { 2, -2 }, { 2, -26 }, { 2, -50 }, { 2, -74 }, { 2, -98 } } },
    { n = 12, perRow = 1, size = { 26, 290 }, points = {
        { 2, -2 }, { 2, -26 }, { 2, -50 }, { 2, -74 }, { 2, -98 }, { 2, -122 },
        { 2, -146 }, { 2, -170 }, { 2, -194 }, { 2, -218 }, { 2, -242 }, { 2, -266 } } },
    { n = 13, perRow = 1, size = { 26, 314 }, points = {
        { 2, -2 }, { 2, -26 }, { 2, -50 }, { 2, -74 }, { 2, -98 }, { 2, -122 },
        { 2, -146 }, { 2, -170 }, { 2, -194 }, { 2, -218 }, { 2, -242 }, { 2, -266 }, { 2, -290 } } },
    { n = 0, perRow = 3, size = { 2, 26 }, points = {} },
    { n = 1, perRow = 3, size = { 26, 26 }, points = { { 2, -2 } } },
    { n = 5, perRow = 3, size = { 74, 50 }, points = { { 2, -2 }, { 26, -2 }, { 50, -2 }, { 2, -26 }, { 26, -26 } } },
    { n = 12, perRow = 3, size = { 74, 98 }, points = {
        { 2, -2 }, { 26, -2 }, { 50, -2 }, { 2, -26 }, { 26, -26 }, { 50, -26 },
        { 2, -50 }, { 26, -50 }, { 50, -50 }, { 2, -74 }, { 26, -74 }, { 50, -74 } } },
    { n = 13, perRow = 3, size = { 74, 122 }, points = {
        { 2, -2 }, { 26, -2 }, { 50, -2 }, { 2, -26 }, { 26, -26 }, { 50, -26 },
        { 2, -50 }, { 26, -50 }, { 50, -50 }, { 2, -74 }, { 26, -74 }, { 50, -74 }, { 2, -98 } } },
    { n = 0, perRow = 12, size = { 2, 26 }, points = {} },
    { n = 1, perRow = 12, size = { 26, 26 }, points = { { 2, -2 } } },
    { n = 5, perRow = 12, size = { 122, 26 }, points = { { 2, -2 }, { 26, -2 }, { 50, -2 }, { 74, -2 }, { 98, -2 } } },
    { n = 12, perRow = 12, size = { 290, 26 }, points = {
        { 2, -2 }, { 26, -2 }, { 50, -2 }, { 74, -2 }, { 98, -2 }, { 122, -2 },
        { 146, -2 }, { 170, -2 }, { 194, -2 }, { 218, -2 }, { 242, -2 }, { 266, -2 } } },
    { n = 13, perRow = 12, size = { 290, 50 }, points = {
        { 2, -2 }, { 26, -2 }, { 50, -2 }, { 74, -2 }, { 98, -2 }, { 122, -2 },
        { 146, -2 }, { 170, -2 }, { 194, -2 }, { 218, -2 }, { 242, -2 }, { 266, -2 }, { 2, -26 } } },
}

local function runGrid(case, reverse)
    local SMB = fresh()
    SMB.db.ButtonsPerRow = case.perRow
    SMB.db.ReverseDirection = reverse
    local buttons = addButtons(case.n)
    SMB:GrabMinimapButtons()
    SMB:Update()
    local expected = {}
    for i, p in ipairs(case.points) do
        if reverse then
            expected[i] = { "TOPRIGHT", -p[1], p[2] }
        else
            expected[i] = { "TOPLEFT", p[1], p[2] }
        end
    end
    local label = string.format("n=%d perRow=%d reverse=%s", case.n, case.perRow, tostring(reverse))
    assert_eq(layout(SMB, buttons), expected, label .. ": points")
    assert_eq({ SMB.Bar:GetSize() }, case.size, label .. ": bar size")
    for _, button in ipairs(buttons) do
        assert_eq({ button:GetSize() }, { 22, 22 }, label .. ": button size")
    end
end

describe("grid (Update)", function()
    for _, case in ipairs(GRID) do
        it(string.format("%d buttons, %d per row, left to right", case.n, case.perRow), function()
            runGrid(case, false)
        end)
        it(string.format("%d buttons, %d per row, ReverseDirection (TOPRIGHT, x negative)", case.n, case.perRow), function()
            runGrid(case, true)
        end)
    end

    it("reverse direction written out: 5 buttons, 3 per row", function()
        local SMB = fresh()
        SMB.db.ButtonsPerRow = 3
        SMB.db.ReverseDirection = true
        local buttons = addButtons(5)
        SMB:GrabMinimapButtons()
        assert_eq(layout(SMB, buttons), {
            { "TOPRIGHT", -2, -2 }, { "TOPRIGHT", -26, -2 }, { "TOPRIGHT", -50, -2 },
            { "TOPRIGHT", -2, -26 }, { "TOPRIGHT", -26, -26 },
        })
        assert_eq({ SMB.Bar:GetSize() }, { 74, 50 })
    end)

    it("other size and spacing: IconSize 20, ButtonSpacing 3, 5 buttons, 3 per row", function()
        local SMB = fresh()
        SMB.db.ButtonsPerRow = 3
        SMB.db.IconSize = 20
        SMB.db.ButtonSpacing = 3
        local buttons = addButtons(5)
        SMB:GrabMinimapButtons()
        -- step 23; width 3 + 60 + 6 + 3, height 3 + 40 + 3 + 3
        assert_eq(layout(SMB, buttons), {
            { "TOPLEFT", 3, -3 }, { "TOPLEFT", 26, -3 }, { "TOPLEFT", 49, -3 },
            { "TOPLEFT", 3, -26 }, { "TOPLEFT", 26, -26 },
        })
        assert_eq({ SMB.Bar:GetSize() }, { 72, 49 })
        assert_eq({ buttons[1]:GetSize() }, { 20, 20 })
    end)

    it("default profile: one column from the top, 26 wide and 122 high with five buttons", function()
        local SMB = fresh()
        local buttons = addButtons(5)
        SMB:GrabMinimapButtons()
        assert_eq(layout(SMB, buttons), {
            { "TOPLEFT", 2, -2 }, { "TOPLEFT", 2, -26 }, { "TOPLEFT", 2, -50 }, { "TOPLEFT", 2, -74 }, { "TOPLEFT", 2, -98 },
        })
        assert_eq({ SMB.Bar:GetSize() }, { 2 * 2 + 22, 2 + 5 * 22 + 4 * 2 + 2 })
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 })
        assert_true(SMB.Bar:IsShown())
        assert_eq(SMB.Bar:GetAlpha(), 1)
    end)

    it("leaves out hidden buttons and buttons in a hidden frame", function()
        local SMB = fresh()
        local buttons = addButtons(3)
        buttons[2]:Hide()
        SMB:GrabMinimapButtons()
        assert_true(buttons[2].isSkinned, "skinned, but not laid out")
        assert_true(buttons[2]:GetParent() == Minimap, "stays at the minimap")
        assert_eq(layout(SMB, { buttons[1], buttons[3] }), { { "TOPLEFT", 2, -2 }, { "TOPLEFT", 2, -26 } })
        assert_eq({ SMB.Bar:GetSize() }, { 26, 50 })

        -- a button outside the bar counts only if it is visible (IsVisible), as in the original
        local late = NewLibDBIconButton("Late")
        MinimapCluster:Hide()
        SMB:GrabMinimapButtons()
        assert_true(late.isSkinned)
        assert_true(late:GetParent() == Minimap, "in a hidden frame: not laid out")
        MinimapCluster:Show()
        SMB:Update()
        assert_true(late:GetParent() == SMB.Bar)
        assert_eq({ SMB.Bar:GetSize() }, { 26, 74 })
    end)

    it("a button in the bar that its addon hides drops out at the next Update", function()
        local SMB = fresh()
        local buttons = addButtons(3)
        SMB:GrabMinimapButtons()
        buttons[1]:Hide()
        SMB:Update()
        assert_eq(layout(SMB, { buttons[2], buttons[3] }), { { "TOPLEFT", 2, -2 }, { "TOPLEFT", 2, -26 } })
        assert_eq({ SMB.Bar:GetSize() }, { 26, 50 })
    end)

    it("buttons are children of the bar, locked, with strata and level from the profile", function()
        local SMB = fresh()
        SMB.db.Strata = "HIGH"
        SMB.db.Level = 20
        local buttons = addButtons(2)
        SMB:GrabMinimapButtons()
        local Bar = SMB.Bar
        assert_eq(Bar:GetFrameStrata(), "HIGH")
        assert_eq(Bar:GetFrameLevel(), 20)
        assert_true(Bar:HasFixedFrameStrata() and Bar:HasFixedFrameLevel(), "strata and level of the bar fixed again")
        for _, button in ipairs(buttons) do
            assert_true(button:GetParent() == Bar)
            assert_eq(button:GetFrameStrata(), "HIGH")
            assert_eq(button:GetFrameLevel(), 21)
            assert_eq(button:GetScale(), 1)
            assert_false(button:IsIgnoringParentScale())
            assert_true(button.SetPoint == SMB.Noop and button.SetParent == SMB.Noop, "locked")
            assert_true(button:HasFixedFrameStrata() and button:HasFixedFrameLevel())
            assert_eq(button:GetBackdrop(), { bgFile = SMB.Solid, edgeFile = SMB.Solid, edgeSize = 1 }, "template")
        end
        -- the owning addon cannot move a locked button out
        buttons[1]:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
        buttons[1]:SetParent(Minimap)
        assert_true(buttons[1]:GetParent() == Bar)
        assert_eq({ buttons[1]:GetPoint() }, { "TOPLEFT", Bar, "TOPLEFT", 2, -2 })
        -- a new strata from the options reaches the bar and the buttons
        SMB.db.Strata = "LOW"
        SMB:Update()
        assert_eq(Bar:GetFrameStrata(), "LOW")
        assert_eq(buttons[2]:GetFrameStrata(), "LOW")
    end)

    it("backdrop on: template on the bar; off: SetBackdrop(nil)", function()
        local SMB = fresh()
        addButtons(1)
        SMB:GrabMinimapButtons()
        assert_eq(SMB.Bar:GetBackdrop(), { bgFile = SMB.Solid, edgeFile = SMB.Solid, edgeSize = 1 })
        SMB.db.Backdrop = false
        SMB:Update()
        assert_nil(SMB.Bar:GetBackdrop())
        SMB.db.Backdrop = true
        SMB:Update()
        assert_true(SMB.Bar:GetBackdrop() ~= nil)
    end)

    it("with ElvUI's frame API the bar and buttons get SetTemplate('Transparent', true)", function()
        local SMB = fresh({ elvui = { frameAPI = true } })
        local buttons = addButtons(1)
        SMB:GrabMinimapButtons()
        assert_eq(StubState(SMB.Bar).elvTemplate, { "Transparent", true })
        assert_eq(StubState(buttons[1]).elvTemplate, { "Transparent", true })
    end)

    it("without visible buttons: driver off and Hide; the fade of the original shows the bar again", function()
        local SMB = fresh()
        local hides = 0
        SMB.Bar:HookScript("OnHide", function() hides = hides + 1 end)
        local buttons = addButtons(2)
        SMB:GrabMinimapButtons()
        assert_eq(STUB.stateDrivers[SMB.Bar].visibility, "[petbattle] hide; show")
        buttons[1]:Hide()
        buttons[2]:Hide()
        STUB.stateDriverLog = {}
        SMB:Update()
        assert_nil(STUB.stateDrivers[SMB.Bar].visibility, "driver unregistered")
        assert_eq(STUB.stateDriverLog, { { action = "unregister", frame = SMB.Bar, state = "visibility" } })
        assert_eq(hides, 1, "Hide called")
        assert_eq({ SMB.Bar:GetSize() }, { 2, 26 })
        -- ProjectAzilroka fades the bar in after hiding it (447-451), and UIFrameFadeIn shows the
        -- frame (FrameUtil.lua UIFrameFade): the empty bar ends up shown, as in the original.
        assert_true(SMB.Bar:IsShown())
    end)

    it("does nothing with BarEnabled off, and nothing before the bar exists", function()
        local SMB = fresh()
        SMB.db.BarEnabled = false
        local buttons = addButtons(1)
        SMB:GrabMinimapButtons()
        assert_true(buttons[1].isSkinned)
        assert_true(buttons[1]:GetParent() == Minimap)
        SMB = fresh(withProfile({ Enable = false }))
        SMB:Update()
        assert_eq(STUB.errors, {})
    end)
end)

describe("bar hidden by its driver (pet battle), then Update", function()
    it("the bar and its driver come back (IsShown for buttons in the bar)", function()
        local SMB = fresh()
        local buttons = addButtons(5)
        SMB:GrabMinimapButtons()
        local Bar = SMB.Bar
        assert_true(SetStateDriverHidden(Bar, true), "driver registered")
        assert_false(Bar:IsShown())
        assert_false(buttons[1]:IsVisible(), "the buttons are not visible in the hidden bar")
        SMB:Update() -- for example from the HandleBlizzardButtons timer or an option
        assert_eq(STUB.stateDrivers[Bar].visibility, "[petbattle] hide; show", "driver still registered")
        assert_true(Bar:IsShown())
        assert_eq({ Bar:GetSize() }, { 26, 122 })
        assert_eq(layout(SMB, buttons), {
            { "TOPLEFT", 2, -2 }, { "TOPLEFT", 2, -26 }, { "TOPLEFT", 2, -50 }, { "TOPLEFT", 2, -74 }, { "TOPLEFT", 2, -98 },
        })
        -- the end of the pet battle shows the bar through its driver
        SetStateDriverHidden(Bar, true)
        assert_true(SetStateDriverHidden(Bar, false))
        assert_true(Bar:IsShown())
    end)

    -- Counter-check against the original (IsVisible() for every button, ProjectAzilroka 400): in the
    -- hidden bar no button is visible, Update counts zero, unregisters the driver and shrinks the
    -- bar to 2 x 26; this test then fails at "driver still registered" (mutation probe in the
    -- report of package 3).
end)

describe("dragging and lock (without ElvUI and Tukui)", function()
    local function free(config)
        local SMB = fresh(config)
        SMB.db.AnchorToMinimap = false
        SMB:ApplyBarPosition()
        return SMB
    end

    it("the bar drags itself and saves the position in the profile", function()
        local SMB = free()
        local Bar = SMB.Bar
        assert_eq({ Bar:GetPoint() }, { "RIGHT", UIParent, "RIGHT", -45, 0 })
        SetMoveTarget(Bar, "TOPLEFT", "TOPLEFT", 300, -200)
        Bar:GetScript("OnDragStart")(Bar, "LeftButton")
        assert_true(Bar:IsMoving())
        Bar:GetScript("OnDragStop")(Bar)
        assert_false(Bar:IsMoving())
        assert_eq({ Bar:GetPoint() }, { "TOPLEFT", UIParent, "TOPLEFT", 300, -200 })
        assert_eq(SMB.db.BarPosition, { "TOPLEFT", "TOPLEFT", 300, -200 })
        assert_false(Bar:IsUserPlaced(), "the profile holds the position, not the layout cache")
        -- a reload places the bar there again
        local saved = SquareMinimapButtonsDB
        ReloadAddon({ savedVariables = saved })
        StartClient()
        assert_eq({ GetAddon().Bar:GetPoint() }, { "TOPLEFT", UIParent, "TOPLEFT", 300, -200 })
    end)

    it("a button in the bar drags the bar too (original 419-420, 371-377)", function()
        local SMB = free()
        local buttons = addButtons(2)
        SMB:GrabMinimapButtons()
        assert_true(buttons[1]:GetScript("OnDragStart") == SMB.OnDragStart)
        assert_true(buttons[1]:GetScript("OnDragStop") == SMB.OnDragStop)
        SetMoveTarget(SMB.Bar, "CENTER", "CENTER", 10, 20)
        buttons[1]:GetScript("OnDragStart")(buttons[1], "LeftButton")
        assert_true(SMB.Bar:IsMoving())
        buttons[1]:GetScript("OnDragStop")(buttons[1])
        assert_eq({ SMB.Bar:GetPoint() }, { "CENTER", UIParent, "CENTER", 10, 20 })
        assert_eq(SMB.db.BarPosition, { "CENTER", "CENTER", 10, 20 })
    end)

    it("with Lock nothing moves, neither by the bar nor by a button", function()
        local SMB = free()
        SMB.db.Lock = true
        local buttons = addButtons(1)
        SMB:GrabMinimapButtons()
        SetMoveTarget(SMB.Bar, "CENTER", "CENTER", 10, 20)
        SMB.Bar:GetScript("OnDragStart")(SMB.Bar, "LeftButton")
        SMB.Bar:GetScript("OnDragStop")(SMB.Bar)
        buttons[1]:GetScript("OnDragStart")(buttons[1], "LeftButton")
        buttons[1]:GetScript("OnDragStop")(buttons[1])
        assert_nil(STUB.calls.StartMoving)
        assert_nil(STUB.calls.StopMovingOrSizing)
        assert_nil(SMB.db.BarPosition)
        assert_eq({ SMB.Bar:GetPoint() }, { "RIGHT", UIParent, "RIGHT", -45, 0 })
    end)

    it("anchored to the minimap (default) nothing moves either", function()
        local SMB = fresh()
        local buttons = addButtons(1)
        SMB:GrabMinimapButtons()
        SetMoveTarget(SMB.Bar, "CENTER", "CENTER", 10, 20)
        SMB.Bar:GetScript("OnDragStart")(SMB.Bar, "LeftButton")
        SMB.Bar:GetScript("OnDragStop")(SMB.Bar)
        buttons[1]:GetScript("OnDragStart")(buttons[1], "LeftButton")
        buttons[1]:GetScript("OnDragStop")(buttons[1])
        assert_nil(STUB.calls.StartMoving)
        assert_nil(SMB.db.BarPosition)
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 })
    end)

    it("with ElvUI or Tukui the buttons get no drag scripts and OnDragStart does nothing", function()
        for _, config in ipairs({ { elvui = {} }, { tukui = true } }) do
            local SMB = fresh(config)
            SMB.db.AnchorToMinimap = false
            local buttons = addButtons(1)
            SMB:GrabMinimapButtons()
            assert_nil(buttons[1]:GetScript("OnDragStart"))
            assert_nil(buttons[1]:GetScript("OnDragStop"))
            SMB.OnDragStart(SMB.Bar)
            SMB.OnDragStop(SMB.Bar)
            assert_nil(STUB.calls.StartMoving)
        end
    end)

    it("ApplyBarPosition leaves the position to the ElvUI mover", function()
        local SMB = fresh({ elvui = {} })
        SMB.Bar:ClearAllPoints()
        SMB.Bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- as if ElvUI anchored it to its mover
        SMB.db.AnchorToMinimap = false
        SMB:ApplyBarPosition()
        assert_eq({ SMB.Bar:GetPoint() }, { "CENTER", UIParent, "CENTER", 0, 0 })
    end)
end)

describe("combat", function()
    it("Update in combat waits for PLAYER_REGEN_ENABLED and runs there exactly once", function()
        local SMB = fresh()
        local buttons = addButtons(2)
        SMB:GrabMinimapButtons()
        assert_eq({ SMB.Bar:GetSize() }, { 26, 50 })
        SetCombat(true)
        SMB.db.ButtonsPerRow = 2
        STUB.fades = {}
        SMB:Update()
        SMB:Update()
        assert_eq({ SMB.Bar:GetSize() }, { 26, 50 }, "nothing changes in combat")
        assert_eq(#STUB.fades, 0)
        assert_eq(#(STUB.eventFrames.PLAYER_REGEN_ENABLED or {}), 1, "the event is registered once")
        SetCombat(false)
        assert_eq({ SMB.Bar:GetSize() }, { 50, 26 }, "rebuilt after combat")
        assert_eq(layout(SMB, buttons), { { "TOPLEFT", 2, -2 }, { "TOPLEFT", 26, -2 } })
        assert_eq(#STUB.fades, 1, "exactly one Update")
        FireEvent("PLAYER_REGEN_ENABLED")
        assert_eq(#STUB.fades, 1, "the event is unregistered after the run")
        assert_nil(SMB.updatePending)
        assert_eq(STUB.errors, {})
    end)

    it("the scan does not run in combat (original 342), so the timer does not rebuild either", function()
        local SMB = fresh()
        SetCombat(true)
        local button = NewLibDBIconButton("Alpha")
        AdvanceTime(6.1)
        assert_nil(button.isSkinned)
        SetCombat(false)
        AdvanceTime(6)
        assert_true(button:GetParent() == SMB.Bar)
    end)
end)

describe("profile change", function()
    local function twoProfiles()
        return {
            savedVariables = {
                profileKeys = { ["Zippy - Forever"] = "Zippy - Forever" },
                profiles = {
                    ["Zippy - Forever"] = {},
                    Other = { ButtonsPerRow = 5, AnchorToMinimap = false, BarPosition = { "TOP", "TOP", 0, -50 } },
                },
            },
        }
    end

    it("rebuilds the bar: layout and position from the new profile", function()
        local SMB = fresh(twoProfiles())
        local buttons = addButtons(5)
        SMB:GrabMinimapButtons()
        assert_eq({ SMB.Bar:GetSize() }, { 26, 122 })
        SMB.data:SetProfile("Other")
        assert_eq({ SMB.Bar:GetSize() }, { 122, 26 }, "Update ran")
        assert_eq(layout(SMB, buttons)[5], { "TOPLEFT", 98, -2 })
        assert_eq({ SMB.Bar:GetPoint() }, { "TOP", UIParent, "TOP", 0, -50 }, "position set again")
        SMB.data:SetProfile("Zippy - Forever")
        assert_eq({ SMB.Bar:GetSize() }, { 26, 122 })
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 })
    end)

    it("a reset puts the bar back to the minimap and ends a drag in progress", function()
        local SMB = fresh()
        SMB.db.AnchorToMinimap = false
        SMB:ApplyBarPosition()
        SMB.Bar:GetScript("OnDragStart")(SMB.Bar, "LeftButton")
        assert_true(SMB.Bar:IsMoving())
        SMB.data:ResetProfile()
        assert_false(SMB.Bar:IsMoving(), "drag ended")
        assert_eq({ SMB.Bar:GetPoint() }, { "TOPLEFT", Minimap, "TOPLEFT", 1, -1 })
        SMB.Bar:GetScript("OnDragStop")(SMB.Bar)
        assert_nil(SMB.db.BarPosition, "nothing saved after the drag was ended")
    end)

    it("a profile change in combat moves the bar at once and rebuilds it after combat", function()
        local SMB = fresh(twoProfiles())
        addButtons(5)
        SMB:GrabMinimapButtons()
        SetCombat(true)
        SMB.data:SetProfile("Other")
        assert_eq({ SMB.Bar:GetPoint() }, { "TOP", UIParent, "TOP", 0, -50 })
        assert_eq({ SMB.Bar:GetSize() }, { 26, 122 })
        SetCombat(false)
        assert_eq({ SMB.Bar:GetSize() }, { 122, 26 })
    end)
end)
