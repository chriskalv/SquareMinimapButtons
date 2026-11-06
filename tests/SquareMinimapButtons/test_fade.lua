-- Test group 7 (fade and visibility): UIFrameFadeIn/Out after ProjectAzilroka's
-- Modules/SquareMinimapButtons.lua (button hooks 324-334, bar scripts 540-545, end of Update
-- 447-451). Changes of the port: Update fades only with buttons (ActualButtons > 0), so an empty
-- bar stays hidden; since nachtrag 2 there is no visibility driver (the original's Update 439-445
-- with db.Visibility "[petbattle] hide; show"; WoW Forever has no pet battles).

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

local function withButtons(n, config)
    local SMB = fresh(config)
    local buttons = {}
    for i = 1, n do buttons[i] = NewLibDBIconButton("Fade" .. i) end
    SMB:GrabMinimapButtons()
    STUB.fades = {}
    return SMB, buttons
end

local function lastFade()
    return STUB.fades[#STUB.fades]
end

describe("fade at the end of Update", function()
    it("without BarMouseOver the bar fades in to 1", function()
        local SMB = withButtons(2)
        SMB.Bar:SetAlpha(0.3)
        SMB:Update()
        assert_eq(#STUB.fades, 1)
        local f = lastFade()
        assert_true(f.frame == SMB.Bar)
        assert_eq({ f.mode, f.duration, f.from, f.to }, { "IN", 0.2, 0.3, 1 })
        assert_eq(SMB.Bar:GetAlpha(), 1)
    end)

    it("with BarMouseOver the bar fades out to 0", function()
        local SMB = withButtons(2)
        SMB.db.BarMouseOver = true
        SMB:Update()
        local f = lastFade()
        assert_eq({ f.mode, f.duration, f.from, f.to }, { "OUT", 0.2, 1, 0 })
        assert_eq(SMB.Bar:GetAlpha(), 0)
        assert_true(SMB.Bar:IsShown(), "faded out, not hidden")
    end)
end)

describe("fade only with buttons (correction of the port)", function()
    it("without buttons: no fade, the bar stays hidden (also with BarMouseOver)", function()
        local SMB = fresh()
        assert_eq(#STUB.fades, 0, "the first scan found no button")
        assert_false(SMB.Bar:IsShown())
        SMB:Update()
        SMB.db.BarMouseOver = true
        SMB:Update()
        assert_eq(#STUB.fades, 0)
        assert_false(SMB.Bar:IsShown())
    end)

    it("the last button hidden: no fade, the bar is hidden; a button again: fade as before", function()
        local SMB, buttons = withButtons(1)
        buttons[1]:Hide()
        SMB:Update()
        assert_eq(#STUB.fades, 0)
        assert_false(SMB.Bar:IsShown())
        buttons[1]:Show()
        SMB:Update()
        assert_eq(#STUB.fades, 1)
        assert_eq(lastFade().mode, "IN")
        assert_true(SMB.Bar:IsShown())
    end)
end)

describe("fade on the buttons (hooks of SkinMinimapButton)", function()
    it("OnEnter fades the bar in; OnLeave fades it out only with BarMouseOver", function()
        local SMB, buttons = withButtons(2)
        local button = buttons[1]
        button:GetScript("OnEnter")(button)
        assert_eq(#STUB.fades, 1)
        assert_true(lastFade().frame == SMB.Bar)
        assert_eq({ lastFade().mode, lastFade().from, lastFade().to }, { "IN", 1, 1 })
        button:GetScript("OnLeave")(button)
        assert_eq(#STUB.fades, 1, "no fade out without BarMouseOver")

        SMB.db.BarMouseOver = true
        SMB:Update()
        STUB.fades = {}
        button:GetScript("OnEnter")(button)
        assert_eq({ lastFade().mode, lastFade().from, lastFade().to }, { "IN", 0, 1 })
        button:GetScript("OnLeave")(button)
        assert_eq(#STUB.fades, 2)
        assert_eq({ lastFade().mode, lastFade().duration, lastFade().from, lastFade().to }, { "OUT", 0.2, 1, 0 })
        assert_eq(button.log, { "OnEnter", "OnLeave", "OnEnter", "OnLeave" }, "the button's own scripts still run")
    end)

    it("a hidden bar does not fade", function()
        local SMB, buttons = withButtons(1)
        SMB.db.BarMouseOver = true
        SMB.Bar:Hide()
        buttons[1]:GetScript("OnEnter")(buttons[1])
        buttons[1]:GetScript("OnLeave")(buttons[1])
        assert_eq(#STUB.fades, 0)
        assert_false(SMB.Bar:IsShown())
    end)

    it("hooks only once: repeated scans and Updates do not add fades", function()
        local SMB, buttons = withButtons(2)
        for _ = 1, 3 do
            SMB:GrabMinimapButtons(true)
            AdvanceTime(6)
        end
        FireEvent("PLAYER_ENTERING_WORLD", false, true)
        STUB.fades = {}
        buttons[2]:GetScript("OnEnter")(buttons[2])
        assert_eq(#STUB.fades, 1)
    end)
end)

describe("fade on the bar (scripts of Initialize)", function()
    it("OnEnter fades in always; OnLeave fades out only with BarMouseOver", function()
        local SMB = withButtons(1)
        local Bar = SMB.Bar
        Bar:GetScript("OnEnter")(Bar)
        assert_eq({ lastFade().mode, lastFade().duration, lastFade().from, lastFade().to }, { "IN", 0.2, 1, 1 })
        Bar:GetScript("OnLeave")(Bar)
        assert_eq(#STUB.fades, 1)
        SMB.db.BarMouseOver = true
        Bar:GetScript("OnLeave")(Bar)
        assert_eq({ lastFade().mode, lastFade().duration, lastFade().from, lastFade().to }, { "OUT", 0.2, 1, 0 })
        Bar:GetScript("OnEnter")(Bar)
        assert_eq({ lastFade().mode, lastFade().from, lastFade().to }, { "IN", 0, 1 })
        assert_true(lastFade().frame == Bar)
    end)
end)

describe("visibility (no driver since nachtrag 2)", function()
    it("the bar is shown with buttons and hidden without; no state driver is ever registered", function()
        local SMB, buttons = withButtons(1)
        assert_true(SMB.Bar:IsShown())
        buttons[1]:Hide()
        SMB:Update()
        assert_false(SMB.Bar:IsShown())
        buttons[1]:Show()
        SMB:Update()
        assert_true(SMB.Bar:IsShown())
        assert_eq(STUB.stateDriverLog, {})
        assert_nil(STUB.stateDrivers[SMB.Bar])
    end)

    it("a stale db.Visibility from an old profile changes nothing", function()
        local SMB = withButtons(1)
        SMB.db.Visibility = "[combat] hide; show"
        SMB:Update()
        assert_eq(STUB.stateDriverLog, {})
        assert_true(SMB.Bar:IsShown())
    end)

    it("no driver on a minimap without addon buttons either", function()
        local SMB = fresh()
        assert_eq(STUB.stateDriverLog, {})
        assert_false(SMB.Bar:IsShown())
    end)
end)
