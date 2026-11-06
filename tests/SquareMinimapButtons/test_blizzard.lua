-- Test group 6 (Blizzard buttons): HandleBlizzardButtons after ProjectAzilroka's
-- Modules/SquareMinimapButtons.lua 98-275 (mail 102-147, garrison commented out 150-176, Retail
-- branch with tracking 178-210 and queue 212-260, else the calendar 263-269, Update 272-274), with
-- the branches of the port per client: Forever builds mail, tracking, queue (only with MoveQueue,
-- off by default, and not with ElvUI's queue holder) and the calendar (own Forever branch without
-- GameTimeTexture); Retail mail, tracking, queue; Classic mail and calendar.

local FOREVER, RETAIL, CLASSIC = 18, 1, 2
local MAGE = { 0.25, 0.78, 0.92, 1 }
local BLACK = { 0, 0, 0, 1 }

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

-- started client with the Blizzard buttons built (direct call, as the 7 second timer does)
local function built(config)
    local SMB = fresh(config)
    SMB:HandleBlizzardButtons()
    return SMB
end

local function countFramesNamed(name)
    local count = 0
    for _, frame in ipairs(STUB.frames) do
        if frame:GetName() == name then count = count + 1 end
    end
    return count
end

-- the entries of SMB.Buttons as names: SMB_MailFrame, Tracking, SMB_QueueFrame, GameTimeFrame
local function buttonNames(SMB)
    local names = {}
    for i, button in ipairs(SMB.Buttons) do
        if MinimapCluster.Tracking and button == MinimapCluster.Tracking.Button then
            names[i] = "Tracking"
        else
            names[i] = button:GetName() or "?"
        end
    end
    return names
end

-- every entry is a child of the bar and anchored to it (Update ran)
local function assertInBar(SMB)
    for i, button in ipairs(SMB.Buttons) do
        assert_true(button:GetParent() == SMB.Bar, "button " .. i .. " is a child of the bar")
        local _, relativeTo = button:GetPoint()
        assert_true(relativeTo == SMB.Bar, "button " .. i .. " is anchored to the bar")
    end
end

describe("branches per client", function()
    it("Forever, default profile: mail, tracking, calendar; no queue (MoveQueue off)", function()
        local SMB = built({ projectID = FOREVER })
        assert_eq(buttonNames(SMB), { "SMB_MailFrame", "Tracking", "GameTimeFrame" })
        assertInBar(SMB)
        assert_nil(_G.SMB_QueueFrame)
        assert_true(QueueStatusButton:GetParent() == UIParent, "queue button untouched")
        assert_nil(QueueStatusButton.SMB)
        assert_false(SMB.queueLocked)
        assert_eq({ SMB.Bar:GetSize() }, { 18, 54 })
        assert_true(SMB.Bar:IsShown())
        assert_eq(STUB.errors, {})
    end)

    it("Forever with MoveQueue on: mail, tracking, queue, calendar", function()
        local SMB = built(withProfile({ MoveQueue = true }, { projectID = FOREVER }))
        assert_eq(buttonNames(SMB), { "SMB_MailFrame", "Tracking", "SMB_QueueFrame", "GameTimeFrame" })
        assertInBar(SMB)
        assert_true(QueueStatusButton:GetParent() == SMB.Bar)
    end)

    it("Forever: each Blizzard button follows its option", function()
        local SMB = built(withProfile({ MoveMail = false, MoveTracker = false, MoveGameTimeFrame = false }, { projectID = FOREVER }))
        assert_eq(buttonNames(SMB), {})
        assert_true(MinimapCluster.Tracking.Button:GetParent() == MinimapCluster.Tracking)
        assert_true(GameTimeFrame:GetParent() == MinimapCluster)
        assert_nil(_G.SMB_MailFrame)
        SMB = built(withProfile({ MoveMail = false, MoveTracker = false }, { projectID = FOREVER }))
        assert_eq(buttonNames(SMB), { "GameTimeFrame" })
        SMB = built(withProfile({ MoveMail = false, MoveGameTimeFrame = false }, { projectID = FOREVER }))
        assert_eq(buttonNames(SMB), { "Tracking" })
    end)

    it("Retail: mail, tracking, queue; the calendar stays where it is", function()
        local SMB = built({ projectID = RETAIL })
        assert_eq(buttonNames(SMB), { "SMB_MailFrame", "Tracking", "SMB_QueueFrame" })
        assertInBar(SMB)
        assert_true(GameTimeFrame:GetParent() == MinimapCluster)
        assert_nil(GameTimeFrame.SMB)
        assert_eq(STUB.errors, {})
    end)

    it("Classic: mail and calendar; tracking and queue stay where they are", function()
        local SMB = built({ projectID = CLASSIC })
        assert_true(SMB.db.MoveQueue, "MoveQueue is on in Classic, but there is no queue branch")
        assert_eq(buttonNames(SMB), { "SMB_MailFrame", "GameTimeFrame" })
        assertInBar(SMB)
        assert_true(MinimapCluster.Tracking.Button:GetParent() == MinimapCluster.Tracking)
        assert_nil(MinimapCluster.Tracking.Button.SMB)
        assert_true(QueueStatusButton:GetParent() == UIParent)
        assert_nil(_G.SMB_QueueFrame)
    end)

    it("garrison: nothing is built in any client (HideGarrison, MoveGarrison without effect)", function()
        for _, id in ipairs({ FOREVER, RETAIL, CLASSIC }) do
            local SMB = built(withProfile({ HideGarrison = true, MoveGarrison = true }, { projectID = id }))
            assert_nil(_G.SMB_Garrison)
            for _, button in ipairs(SMB.Buttons) do
                assert_true(button:GetName() ~= "ExpansionLandingPageMinimapButton")
            end
        end
    end)
end)

describe("missing frames, idempotence, guards", function()
    it("no GameTimeFrame, no QueueStatusButton, no MinimapCluster.Tracking: no error, only the mail", function()
        local missing = { GameTimeFrame = true, QueueStatusButton = true, Tracking = true }
        for _, id in ipairs({ FOREVER, RETAIL, CLASSIC }) do
            local SMB = built(withProfile({ MoveQueue = true }, { projectID = id, missing = missing }))
            assert_eq(buttonNames(SMB), { "SMB_MailFrame" })
            assert_eq(STUB.errors, {})
        end
    end)

    it("every combination of missing frames, in every client: no error, OnEnter/OnLeave work", function()
        local kinds = { "GameTimeFrame", "QueueStatusButton", "Tracking" }
        for _, id in ipairs({ FOREVER, RETAIL, CLASSIC }) do
            for mask = 0, 7 do
                local missing = {}
                for bit, kind in ipairs(kinds) do
                    if math.floor(mask / 2 ^ (bit - 1)) % 2 == 1 then missing[kind] = true end
                end
                local SMB = built(withProfile({ MoveQueue = true }, { projectID = id, missing = missing }))
                for _, button in ipairs(SMB.Buttons) do
                    local onEnter, onLeave = button:GetScript("OnEnter"), button:GetScript("OnLeave")
                    if onEnter then onEnter(button) end
                    if onLeave then onLeave(button) end
                end
                assert_eq(STUB.errors, {}, "client " .. id .. ", mask " .. mask)
            end
        end
    end)

    it("a second call builds nothing twice and SMB.Buttons does not grow", function()
        local SMB = built(withProfile({ MoveQueue = true }, { projectID = FOREVER }))
        assert_eq(#SMB.Buttons, 4)
        SMB:HandleBlizzardButtons()
        SMB:HandleBlizzardButtons()
        AdvanceTime(30) -- the 7 second timer runs once more
        assert_eq(#SMB.Buttons, 4)
        assert_eq(countFramesNamed("SMB_MailFrame"), 1)
        assert_eq(countFramesNamed("SMB_QueueFrame"), 1)
        local icons = 0
        for _, region in ipairs({ GameTimeFrame:GetRegions() }) do
            if region:GetAtlas() == "ui-hud-minimap-calendar-button" then icons = icons + 1 end
        end
        assert_eq(icons, 1, "one own calendar icon")
        -- the hooks exist once: one fade per OnEnter
        SMB.db.BarMouseOver = true
        SMB:Update()
        for _, button in ipairs(SMB.Buttons) do
            STUB.fades = {}
            button:GetScript("OnEnter")(button)
            assert_eq(#STUB.fades, 1, button:GetDebugName() .. ": one fade")
        end
    end)

    it("does nothing with BarEnabled off or before the bar exists", function()
        local SMB = fresh(withProfile({ BarEnabled = false }))
        SMB:HandleBlizzardButtons()
        assert_eq(#SMB.Buttons, 0)
        assert_nil(_G.SMB_MailFrame)
        ReloadAddon({})
        SMB = GetAddon()
        SMB:HandleBlizzardButtons()
        assert_nil(_G.SMB_MailFrame)
        assert_eq(STUB.errors, {})
    end)

    it("a profile change adds the Blizzard buttons the new profile asks for", function()
        local config = withProfile({ MoveMail = false, MoveTracker = false, MoveGameTimeFrame = false })
        config.savedVariables.profiles.Other = {}
        local SMB = built(config)
        assert_eq(#SMB.Buttons, 0)
        SMB.data:SetProfile("Other")
        assert_eq(buttonNames(SMB), { "SMB_MailFrame", "Tracking", "GameTimeFrame" })
        assertInBar(SMB)
    end)

    it("in combat the buttons are added and laid out after combat (Update waits)", function()
        local SMB = fresh()
        SetCombat(true)
        SMB:HandleBlizzardButtons()
        assert_eq(#SMB.Buttons, 3)
        assert_false(SMB.Bar:IsShown(), "no Update in combat")
        SetCombat(false)
        assertInBar(SMB)
        assert_true(SMB.Bar:IsShown())
        assert_eq({ SMB.Bar:GetSize() }, { 18, 54 })
    end)
end)

describe("mail (SMB_MailFrame)", function()
    it("is a frame of the bar with the letter icon, cropped and fitted inside", function()
        local SMB = built()
        local Frame = _G.SMB_MailFrame
        assert_eq(Frame:GetObjectType(), "Frame")
        assert_eq({ Frame:GetSize() }, { 18, 18 })
        assert_true(Frame:IsMouseEnabled())
        assert_eq(Frame.Icon:GetTexture(), "Interface/Icons/INV_Letter_15")
        assert_eq({ Frame.Icon:GetTexCoord() }, { 0.08, 0.08, 0.08, 0.92, 0.92, 0.08, 0.92, 0.92 })
        assert_eq({ Frame.Icon:GetPoint(1) }, { "TOPLEFT", Frame, "TOPLEFT", 1, -1 })
        assert_eq({ Frame.Icon:GetPoint(2) }, { "BOTTOMRIGHT", Frame, "BOTTOMRIGHT", -1, 1 })
        assert_eq({ Frame:GetBackdropBorderColor() }, BLACK, "own backdrop")
        assert_eq({ Frame.Icon:GetVertexColor() }, { 1, 1, 1, 1 }, "white without mail")
        assert_true(SMB.Buttons[1] == Frame)
    end)

    it("is green with new mail at the start", function()
        built({ newMail = true })
        assert_eq({ SMB_MailFrame.Icon:GetVertexColor() }, { 0, 1, 0, 1 })
    end)

    it("follows UPDATE_PENDING_MAIL: green with mail, white again without", function()
        built()
        local Icon = SMB_MailFrame.Icon
        assert_true(SMB_MailFrame:IsEventRegistered("UPDATE_PENDING_MAIL"))
        SetNewMail(true)
        assert_eq({ Icon:GetVertexColor() }, { 0, 1, 0, 1 })
        SetNewMail(false)
        assert_eq({ Icon:GetVertexColor() }, { 1, 1, 1, 1 })
        SetNewMail(true)
        assert_eq({ Icon:GetVertexColor() }, { 0, 1, 0, 1 })
    end)

    it("OnEnter with mail: tooltip through MinimapMailFrameUpdate, border in the class color", function()
        built({ newMail = true })
        local Frame = SMB_MailFrame
        Frame:GetScript("OnEnter")(Frame)
        assert_true(GameTooltip:GetOwner() == Frame)
        assert_eq(StubState(GameTooltip).anchor, "ANCHOR_BOTTOMRIGHT")
        assert_eq(STUB.calls.MinimapMailFrameUpdate, 1)
        assert_true(GameTooltip:IsShown())
        assert_eq({ Frame:GetBackdropBorderColor() }, MAGE)
        -- new mail while the tooltip is open updates it
        SetNewMail(true)
        assert_eq(STUB.calls.MinimapMailFrameUpdate, 2)
        Frame:GetScript("OnLeave")(Frame)
        assert_false(GameTooltip:IsShown())
        assert_eq({ Frame:GetBackdropBorderColor() }, BLACK, "template again")
        SetNewMail(true)
        assert_eq(STUB.calls.MinimapMailFrameUpdate, 2, "no update when the tooltip is closed")
    end)

    it("without MinimapMailFrameUpdate: OnEnter and UPDATE_PENDING_MAIL raise no error", function()
        built({ newMail = true, missing = { MinimapMailFrameUpdate = true } })
        local Frame = SMB_MailFrame
        assert_nil(MinimapMailFrameUpdate)
        Frame:GetScript("OnEnter")(Frame)
        assert_true(GameTooltip:GetOwner() == Frame)
        SetNewMail(true)
        assert_eq({ Frame.Icon:GetVertexColor() }, { 0, 1, 0, 1 })
        Frame:GetScript("OnLeave")(Frame)
        assert_eq(STUB.errors, {})
    end)

    it("reads HasNewMail and MinimapMailFrameUpdate on use, as the original does", function()
        built()
        local Frame = SMB_MailFrame
        local calls = 0
        HasNewMail = function() return true end
        MinimapMailFrameUpdate = function() calls = calls + 1; GameTooltip:Show() end
        Frame:GetScript("OnEnter")(Frame)
        assert_eq(calls, 1)
        FireEvent("UPDATE_PENDING_MAIL")
        assert_eq({ Frame.Icon:GetVertexColor() }, { 0, 1, 0, 1 })
        assert_eq(calls, 2)
    end)

    it("OnEnter without mail: no tooltip, border in the class color", function()
        built()
        SMB_MailFrame:GetScript("OnEnter")(SMB_MailFrame)
        assert_nil(STUB.calls.MinimapMailFrameUpdate)
        assert_false(GameTooltip:IsShown())
        assert_eq({ SMB_MailFrame:GetBackdropBorderColor() }, MAGE)
    end)

    it("fades the bar only with BarMouseOver (as the original does for the mail frame)", function()
        local SMB = built()
        STUB.fades = {}
        SMB_MailFrame:GetScript("OnEnter")(SMB_MailFrame)
        SMB_MailFrame:GetScript("OnLeave")(SMB_MailFrame)
        assert_eq(#STUB.fades, 0)
        SMB.db.BarMouseOver = true
        SMB:Update()
        STUB.fades = {}
        SMB_MailFrame:GetScript("OnEnter")(SMB_MailFrame)
        assert_eq({ STUB.fades[1].mode, STUB.fades[1].duration, STUB.fades[1].from, STUB.fades[1].to }, { "IN", 0.2, 0, 1 })
        SMB_MailFrame:GetScript("OnLeave")(SMB_MailFrame)
        assert_eq({ STUB.fades[2].mode, STUB.fades[2].from, STUB.fades[2].to }, { "OUT", 1, 0 })
    end)

    it("gets a shadow only with db.Shadows (ElvUI frame API)", function()
        built({ elvui = { frameAPI = true } })
        assert_true(StubState(SMB_MailFrame).shadow)
        built(withProfile({ Shadows = false }, { elvui = { frameAPI = true } }))
        assert_nil(StubState(SMB_MailFrame).shadow)
    end)
end)

describe("tracking", function()
    it("Forever: the tracking frame stays shown, the button is a child of the bar", function()
        local SMB = fresh()
        local Tracking = MinimapCluster.Tracking
        local Button = Tracking.Button
        assert_true(Tracking:IsShown())
        SMB:HandleBlizzardButtons()
        assert_true(Tracking:IsShown(), "the tracking frame is not hidden")
        -- Tracking:Show() or Button:Show(true) are both fine; the mixin's Show() without argument is not
        for i, call in ipairs(STUB.calls.TrackingButtonShow or {}) do
            assert_true(call.n > 0 and call.shown == true, "mixin Show call " .. i .. " shows the frame")
        end
        assert_true(Button:GetParent() == SMB.Bar)
        assert_true(Button:IsShown())
        assert_eq(Tracking.Background:GetAlpha(), 0)
        assert_true(Button.SMB)
        assert_eq({ Button:GetSize() }, { 18, 18 })
        assert_eq({ Button:GetBackdropBorderColor() }, BLACK)
    end)

    it("Forever: a hidden tracking frame is shown", function()
        local SMB = fresh()
        MinimapCluster.Tracking:Hide()
        SMB:HandleBlizzardButtons()
        assert_true(MinimapCluster.Tracking:IsShown())
    end)

    it("OnMouseDown and OnMouseUp are cleared as in the original; OnEnter/OnLeave hooked", function()
        local SMB = built()
        local Button = MinimapCluster.Tracking.Button
        assert_nil(Button:GetScript("OnMouseDown"))
        assert_nil(Button:GetScript("OnMouseUp"))
        STUB.fades = {}
        Button:GetScript("OnEnter")(Button)
        assert_eq({ Button:GetBackdropBorderColor() }, MAGE)
        assert_eq(#STUB.fades, 1, "fades in whenever the bar is shown")
        Button:GetScript("OnLeave")(Button)
        assert_eq({ Button:GetBackdropBorderColor() }, BLACK)
        assert_eq(#STUB.fades, 1, "no fade out without BarMouseOver")
        assert_eq(Button.log, { "OnEnter", "OnLeave" }, "Blizzard's scripts still run")
    end)

    it("Retail: shown with the plain Show of the original, child of the bar", function()
        local SMB = fresh({ projectID = RETAIL })
        MinimapCluster.Tracking.Button:Hide()
        SMB:HandleBlizzardButtons()
        assert_true(MinimapCluster.Tracking.Button:GetParent() == SMB.Bar)
        assert_true(MinimapCluster.Tracking.Button:IsShown(), "Button:Show() ran")
        assert_true(MinimapCluster.Tracking:IsShown())
        assert_nil(STUB.calls.TrackingButtonShow)
    end)

    it("the button is moved into the bar by the build itself, not only by Update", function()
        for _, id in ipairs({ FOREVER, RETAIL }) do
            local SMB = fresh({ projectID = id })
            SetCombat(true) -- Update waits for the end of combat
            SMB:HandleBlizzardButtons()
            assert_true(MinimapCluster.Tracking.Button:GetParent() == SMB.Bar, "client " .. id)
            SetCombat(false)
        end
    end)
end)

describe("calendar", function()
    it("Forever: no GameTimeTexture, Blizzard's textures transparent, own icon, child of the bar", function()
        local SMB = built()
        assert_nil(STUB.calls.GameTimeTextureAccess, "GameTimeTexture is never read")
        assert_eq(STUB.errors, {})
        for _, key in ipairs({ "StateTexture", "AddTexture" }) do
            local region = GameTimeFrame[key]
            assert_eq(region:GetAlpha(), 0, key .. " transparent")
            assert_nil(region:GetTexture(), key .. " emptied")
            assert_nil(region:GetAtlas(), key .. " without atlas")
        end
        local Icon = GameTimeFrame.SMBIcon
        assert_eq(Icon:GetAtlas(), "ui-hud-minimap-calendar-button")
        assert_eq(Icon:GetAlpha(), 1)
        assert_eq({ Icon:GetPoint(1) }, { "TOPLEFT", GameTimeFrame, "TOPLEFT", 1, -1 })
        assert_eq({ Icon:GetPoint(2) }, { "BOTTOMRIGHT", GameTimeFrame, "BOTTOMRIGHT", -1, 1 })
        assert_true(GameTimeFrame:GetParent() == SMB.Bar)
        assert_true(GameTimeFrame.SMB)
        assert_eq({ GameTimeFrame:GetSize() }, { 18, 18 })
    end)

    it("Forever: Blizzard's button states do not bring the textures back; the click stays Blizzard's", function()
        local SMB = built()
        GameTimeFrame:GetScript("OnEnter")(GameTimeFrame)
        assert_eq(GameTimeFrame.StateTexture:GetAtlas(), "ui-hud-minimap-calendar-button", "Blizzard set the atlas again")
        assert_eq(GameTimeFrame.StateTexture:GetAlpha(), 0, "still transparent")
        assert_nil(GameTimeFrame.AddTexture:GetTexture())
        assert_nil(GameTimeFrame.AddTexture:GetAtlas(), "AddTexture stays empty")
        assert_eq({ GameTimeFrame:GetBackdropBorderColor() }, MAGE)
        GameTimeFrame:GetScript("OnLeave")(GameTimeFrame)
        assert_eq({ GameTimeFrame:GetBackdropBorderColor() }, BLACK)
        GameTimeFrame:Click()
        assert_eq(GameTimeFrame.log, { "OnEnter", "OnLeave", "OnClick" })
        assert_true(SMB.Buttons[#SMB.Buttons] == GameTimeFrame)
    end)

    it("Forever without the atlas: the calendar texture file", function()
        built({ noAtlasInfo = true })
        assert_nil(GameTimeFrame.SMBIcon:GetAtlas())
        assert_eq(GameTimeFrame.SMBIcon:GetTexture(), "Interface/Calendar/UI-Calendar-Button")
    end)

    it("Classic: GameTimeTexture emptied as in the original", function()
        local SMB = built({ projectID = CLASSIC })
        assert_eq(GameTimeTexture:GetTexture(), "")
        assert_true(GameTimeFrame:GetParent() == SMB.Bar)
        assert_nil(GameTimeFrame.SMBIcon)
    end)
end)

describe("queue", function()
    local function queueConfig(extra)
        local config = withProfile({ MoveQueue = true }, { projectID = FOREVER })
        for k, v in pairs(extra or {}) do config[k] = v end
        return config
    end

    it("Forever with MoveQueue: frame with the eye, queue button centered on it in the bar", function()
        local SMB = built(queueConfig())
        local Frame = _G.SMB_QueueFrame
        assert_true(Frame:GetParent() == SMB.Bar)
        assert_eq(Frame.Icon:GetTexture(), "Interface/LFGFrame/LFG-Eye")
        assert_eq({ Frame.Icon:GetTexCoord() }, { 0, 0, 0, 64 / 256, 64 / 512, 0, 64 / 512, 64 / 256 })
        assert_eq({ Frame.Icon:GetSize() }, { 18, 18 })
        assert_true(QueueStatusButton:GetParent() == SMB.Bar)
        assert_eq({ QueueStatusButton:GetPoint() }, { "CENTER", Frame, "CENTER", 0, 0 })
        assert_eq(QueueStatusButton:GetNumPoints(), 1)
        assert_true(QueueStatusButton.SMB)
        assert_false(SMB.queueLocked)
    end)

    it("Forever: the click opens the group finder through ToggleGroupFinderFrame, also with Retail globals", function()
        built(queueConfig({ retailGlobals = true }))
        SMB_QueueFrame:GetScript("OnMouseDown")(SMB_QueueFrame, "LeftButton")
        assert_eq(STUB.calls.ToggleGroupFinderFrame, 1)
        assert_nil(STUB.calls.ShowUIPanel, "PVEFrame is not used in Forever")
        assert_nil(STUB.calls.GroupFinderFrame_ShowGroupFrame)
        assert_eq(STUB.errors, {})
    end)

    it("the frame takes the mouse only while the queue button is hidden", function()
        built(queueConfig())
        assert_true(SMB_QueueFrame:IsMouseEnabled(), "queue button hidden at the start")
        QueueStatusButton:Show()
        assert_false(SMB_QueueFrame:IsMouseEnabled())
        QueueStatusButton:Hide()
        assert_true(SMB_QueueFrame:IsMouseEnabled())
        assert_eq(QueueStatusButton.log, { "OnShow", "OnHide" }, "Blizzard's scripts still run")
        QueueStatusButton:GetScript("PostClick")(QueueStatusButton)
        assert_eq(QueueStatusButton.log[3], "OnLeave", "PostClick calls OnLeave")
    end)

    it("a shown queue button at build time disables the mouse of the frame at once", function()
        ReloadAddon(queueConfig())
        StartClient()
        QueueStatusButton:Show()
        GetAddon():HandleBlizzardButtons()
        assert_false(SMB_QueueFrame:IsMouseEnabled())
    end)

    it("with ElvUI's queue holder: no frame, the queue button untouched, SMB.queueLocked", function()
        local SMB = built(queueConfig({ elvui = { queueStatus = true } }))
        assert_true(_G.ElvUIQueueStatus ~= nil)
        assert_nil(_G.SMB_QueueFrame)
        assert_true(QueueStatusButton:GetParent() == UIParent)
        assert_eq({ QueueStatusButton:GetPoint() }, { "CENTER", Minimap, "CENTER", -68, -68 })
        assert_nil(QueueStatusButton.SMB)
        assert_true(SMB.queueLocked)
        assert_eq(buttonNames(SMB), { "SMB_MailFrame", "Tracking", "GameTimeFrame" })
    end)

    it("ElvUI without its queue module does not lock the queue", function()
        local SMB = built(queueConfig({ elvui = {} }))
        assert_false(SMB.queueLocked)
        assert_true(_G.SMB_QueueFrame ~= nil)
    end)

    it("Forever default (MoveQueue off): nothing", function()
        local SMB = built({ projectID = FOREVER })
        assert_false(SMB.db.MoveQueue)
        assert_nil(_G.SMB_QueueFrame)
        assert_true(QueueStatusButton:GetParent() == UIParent)
    end)

    it("Retail with its globals: ShowUIPanel(PVEFrame) and GroupFinderFrame_ShowGroupFrame, then HideUIPanel", function()
        built({ projectID = RETAIL, retailGlobals = true })
        local onMouseDown = SMB_QueueFrame:GetScript("OnMouseDown")
        onMouseDown(SMB_QueueFrame, "LeftButton")
        assert_eq(#STUB.calls.ShowUIPanel, 1)
        assert_true(STUB.calls.ShowUIPanel[1] == PVEFrame)
        assert_eq(STUB.calls.GroupFinderFrame_ShowGroupFrame, 1)
        assert_true(PVEFrame:IsShown())
        onMouseDown(SMB_QueueFrame, "LeftButton")
        assert_true(STUB.calls.HideUIPanel[1] == PVEFrame)
        assert_false(PVEFrame:IsShown())
        assert_nil(STUB.calls.ToggleGroupFinderFrame)
    end)

    it("Retail without the globals: the click raises no error", function()
        built({ projectID = RETAIL })
        SMB_QueueFrame:GetScript("OnMouseDown")(SMB_QueueFrame, "LeftButton")
        assert_eq(STUB.errors, {})
        assert_nil(STUB.calls.ToggleGroupFinderFrame)
    end)
end)

describe("timer", function()
    it("7 seconds after Initialize HandleBlizzardButtons runs, then Update lays the buttons out", function()
        local SMB = fresh()
        AdvanceTime(6.9)
        assert_nil(_G.SMB_MailFrame, "not before 7 s")
        assert_false(SMB.Bar:IsShown(), "empty bar hidden")
        AdvanceTime(0.2)
        assert_eq(buttonNames(SMB), { "SMB_MailFrame", "Tracking", "GameTimeFrame" })
        assertInBar(SMB)
        assert_true(SMB.Bar:IsShown())
        assert_eq({ SMB.Bar:GetSize() }, { 18, 54 })
        assert_eq(STUB.stateDrivers[SMB.Bar].visibility, "[petbattle] hide; show")
        assert_eq(STUB.errors, {})
    end)

    it("addon buttons and Blizzard buttons share the bar in the order they were added", function()
        local SMB = fresh()
        NewLibDBIconButton("Alpha")
        AdvanceTime(7.1) -- scan at 6 s, Blizzard buttons at 7 s
        assert_eq(buttonNames(SMB), { "LibDBIcon10_Alpha", "SMB_MailFrame", "Tracking", "GameTimeFrame" })
        local _, _, _, x, y = GameTimeFrame:GetPoint()
        assert_eq({ x, y }, { 0, -54 })
    end)
end)
