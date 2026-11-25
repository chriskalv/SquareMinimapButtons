-- Test group 12 (1.0.2): the self-check of the buttons in the bar (SMB:CheckButton), the
-- replacement image and the diagnosis /smb debug.

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

local function fallbackOf(SMB, button)
    return SMB.FallbackTextures[button]
end

local function fallbackShown(SMB, button)
    local texture = fallbackOf(SMB, button)
    return texture ~= nil and texture:IsShown()
end

-- the methods of the texture type, as an addon would reach them past the locks
local function rawMethod(region, name)
    return getmetatable(region).__index[name]
end

local function linesContaining(text)
    local lines = {}
    for _, line in ipairs(STUB.chat) do
        if line:find(text, 1, true) then lines[#lines + 1] = line end
    end
    return lines
end

describe("a button with its own icon", function()
    it("passes the check: no replacement, no chat line", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:GrabMinimapButtons()
        assert_true(SMB:CheckButton(button))
        assert_nil(fallbackOf(SMB, button))
        assert_eq(ChatContains("replacement image"), 0)
    end)

    it("is repaired once when its icon lost its anchors past the lock; no replacement", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:GrabMinimapButtons()
        rawMethod(button.icon, "ClearAllPoints")(button.icon)
        assert_false(RegionDrawn(button.icon))
        assert_true(SMB:CheckButton(button), "repaired")
        assert_true(RegionDrawn(button.icon))
        assert_eq(#StubState(button.icon).points, 2)
        assert_nil(fallbackOf(SMB, button))
        assert_eq(ChatContains("replacement image"), 0)
    end)

    it("a hidden button is not judged (it is not in the bar)", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:GrabMinimapButtons()
        button.icon:Hide()
        button:Hide()
        assert_nil(SMB:CheckButton(button))
        assert_nil(fallbackOf(SMB, button))
    end)

    it("Blizzard's buttons are not judged", function()
        local SMB = fresh()
        SMB:HandleBlizzardButtons()
        for _, button in ipairs(SMB.Buttons) do
            assert_nil(SMB:CheckButton(button))
            assert_nil(fallbackOf(SMB, button))
        end
    end)
end)

describe("replacement image", function()
    it("an icon its addon hides: the broker icon, named once in the chat at the next scan", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Hidden", { icon = 136243 })
        SMB:GrabMinimapButtons()
        button.icon:Hide()
        AdvanceTime(0) -- the check queued by Hide
        assert_true(fallbackShown(SMB, button))
        local texture = fallbackOf(SMB, button)
        assert_eq(texture:GetTexture(), 136243, "the icon of the LibDataBroker object")
        assert_true(RegionDrawn(texture))
        assert_eq(StubState(texture).points, {
            { "TOPLEFT", button, "TOPLEFT", 1, -1 },
            { "BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1 },
        })
        assert_eq(ChatContains("showed no icon"), 0, "not at once (the addon may set its icon a moment later)")
        AdvanceTime(6) -- the next scan
        local lines = linesContaining("LibDBIcon10_Hidden showed no icon in the bar")
        assert_eq(#lines, 1)
        assert_contains(lines[1], "(LibDataBroker)")
        assert_contains(lines[1], "/smb debug LibDBIcon10_Hidden")
        SMB:GrabMinimapButtons()
        AdvanceTime(6)
        assert_eq(ChatContains("showed no icon"), 1, "once per button and session")
    end)

    it("an icon that gets its image a moment after the scan is not reported", function()
        local SMB = fresh()
        local button = NewPlainButton("SlowIcon")
        button.icon:SetTexture()
        SMB:GrabMinimapButtons()
        assert_true(fallbackShown(SMB, button), "the replacement meanwhile")
        AdvanceTime(1)
        button.icon:SetTexture(134401)
        AdvanceTime(0)
        assert_false(fallbackShown(SMB, button))
        assert_true(RegionDrawn(button.icon))
        AdvanceTime(12)
        assert_eq(ChatContains("showed no icon"), 0)
    end)

    it("goes away as soon as the button shows its own icon again", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Hidden")
        SMB:GrabMinimapButtons()
        button.icon:SetAlpha(0)
        AdvanceTime(0)
        assert_true(fallbackShown(SMB, button))
        button.icon:SetAlpha(1)
        AdvanceTime(0)
        assert_false(fallbackShown(SMB, button))
        assert_true(RegionDrawn(button.icon))
    end)

    it("without a broker icon: the IconTexture of the addon's TOC", function()
        local SMB = fresh()
        STUB.addons.Delta = { enabled = true, loaded = true, metadata = { IconTexture = "Interface\\AddOns\\Delta\\icon" } }
        local button = NewLibDBIconButton("Delta")
        button.dataObject.icon = nil
        SMB:GrabMinimapButtons()
        button.icon:SetTexture()
        AdvanceTime(0)
        assert_eq(fallbackOf(SMB, button):GetTexture(), "Interface\\AddOns\\Delta\\icon")
        AdvanceTime(6)
        assert_eq(ChatContains("(TOC IconTexture)"), 1)
    end)

    it("the broker's tocname comes first", function()
        local SMB = fresh()
        STUB.addons.RealFolder = { enabled = true, loaded = true, metadata = { IconTexture = "Interface\\AddOns\\RealFolder\\logo" } }
        local button = NewLibDBIconButton("Display Name")
        button.dataObject.icon = nil
        button.dataObject.tocname = "RealFolder"
        SMB:GrabMinimapButtons()
        button.icon:SetTexture()
        AdvanceTime(0)
        assert_eq(fallbackOf(SMB, button):GetTexture(), "Interface\\AddOns\\RealFolder\\logo")
    end)

    it("without either: the question mark; an error of GetAddOnMetadata is caught", function()
        local SMB = fresh()
        C_AddOns.GetAddOnMetadata = function(addon) error("Invalid AddOn name " .. tostring(addon)) end
        local button = NewPlainButton("NoBroker")
        SMB:GrabMinimapButtons()
        button.icon:SetTexture()
        AdvanceTime(0)
        assert_eq(fallbackOf(SMB, button):GetTexture(), QUESTION_MARK)
        AdvanceTime(6)
        assert_eq(ChatContains("(INV_Misc_QuestionMark)"), 1)
        assert_eq(STUB.errors, {})
    end)

    it("a button with only a highlight texture gets one; its texture is not taken as the icon", function()
        local SMB = fresh()
        local button = CreateFrame("Button", "OnlyHighlight", Minimap)
        button:SetSize(20, 20)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture(134401)
        highlight:SetAllPoints()
        SMB:GrabMinimapButtons()
        -- the skin puts every texture on ARTWORK; the addon sets HIGHLIGHT again past the lock
        rawMethod(highlight, "SetDrawLayer")(highlight, "HIGHLIGHT")
        assert_false(SMB:HasVisibleIcon(button))
    end)

    it("the replacement is not skinned or listed as an icon of the button", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Hidden")
        SMB:GrabMinimapButtons()
        button.icon:Hide()
        AdvanceTime(0)
        local texture = fallbackOf(SMB, button)
        SMB:GrabMinimapButtons()
        assert_nil(SMB.HandledRegions[texture])
        assert_false(SMB:HasVisibleIcon(button), "the replacement does not count as the own icon")
        assert_true(fallbackShown(SMB, button))
    end)
end)

describe("secret values", function()
    it("a secret alpha or shown state is not compared and counts as visible", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Secret")
        SMB:GrabMinimapButtons()
        local icon = button.icon
        local getAlpha = icon.GetAlpha
        icon.GetAlpha = function(self)
            STUB.secretTexCoordPending = true -- issecretvalue answers true for numbers now
            return getAlpha(self)
        end
        local ok, result = pcall(SMB.IsVisibleIcon, SMB, icon)
        STUB.secretTexCoordPending = false
        assert_true(ok, tostring(result))
        assert_true(result)
        icon.GetAlpha = nil
    end)
end)

describe("/smb debug", function()
    it("lists every button of the bar with its regions", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:GrabMinimapButtons()
        STUB.chat = {}
        RunSlash("/smb", "debug")
        local head = linesContaining("LibDBIcon10_Alpha (addon): shown=yes inBar=yes size=18x18 fallback=no")
        assert_eq(#head, 1)
        assert_eq(#linesContaining("Texture ARTWORK image=134400 shown=yes alpha=1 points=2 size=17x17 masks=0 role=skin locked"), 1)
        assert_eq(#linesContaining("Texture OVERLAY image=- shown=yes alpha=0 points=1 size=53x53 masks=0 role=removed"), 1)
        assert_eq(ChatContains("1 buttons listed (/smb debug )."), 1)
    end)

    it("filters by a part of the name, without regard to case; says when nothing matches", function()
        local SMB = fresh()
        NewLibDBIconButton("Alpha")
        NewLibDBIconButton("Beta")
        SMB:GrabMinimapButtons()
        STUB.chat = {}
        RunSlash("/smb", "debug BETA")
        assert_eq(ChatContains("LibDBIcon10_Beta (addon)"), 1)
        assert_eq(ChatContains("LibDBIcon10_Alpha"), 0)
        STUB.chat = {}
        RunSlash("/smb", "debug nothing")
        assert_eq(ChatContains('No button of the bar matches "nothing".'), 1)
    end)

    it("shows the replacement and its source, and Blizzard's buttons", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Hidden")
        SMB:GrabMinimapButtons()
        SMB:HandleBlizzardButtons()
        button.icon:Hide()
        AdvanceTime(0)
        STUB.chat = {}
        RunSlash("/smb", "debug")
        assert_eq(ChatContains("LibDBIcon10_Hidden (addon): shown=yes inBar=yes size=18x18 fallback=yes, broker"), 1)
        assert_eq(ChatContains("role=fallback (broker)"), 1)
        assert_eq(ChatContains("SMB_MailFrame (Blizzard)"), 1)
    end)

    it("prints secret values as secret", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Secret")
        SMB:GrabMinimapButtons()
        local icon = button.icon
        icon.GetAlpha = function()
            STUB.secretTexCoordPending = true
            return 1
        end
        local text = SMB:DescribeRegion(button, icon)
        STUB.secretTexCoordPending = false
        icon.GetAlpha = nil
        assert_contains(text, "alpha=secret")
    end)

    it("a blocked addon answers with the guard message", function()
        fresh({ pa = { enabled = true } })
        STUB.chat = {}
        RunSlash("/smb", "debug")
        assert_eq(ChatContains("ProjectAzilroka is loaded"), 1)
        assert_eq(ChatContains("buttons listed"), 0)
    end)

    it("before the bar exists it says so", function()
        local SMB = fresh({ savedVariables = { profileKeys = { ["Zippy - Forever"] = "Default" }, profiles = { Default = { Enable = false } } } })
        STUB.chat = {}
        assert_eq(SMB:DebugButtons(""), 0)
        assert_eq(ChatContains("The bar does not exist"), 1)
    end)
end)
