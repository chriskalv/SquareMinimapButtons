-- Test group 11 (1.0.2): what other addons do with their minimap buttons after the skin.
-- Each case plays the sequence of calls that the addon makes in its own source (read there, nothing
-- copied); RegionDrawn (stubs.lua) judges, independently of the addon's own check, whether the
-- client would draw a texture: without anchors it does not.
--
-- ItemRack Universal 4.59 (CurseForge project 1441253, ItemRack/ItemRack.lua):
--   ItemRack.InitBroker (7864-7879): LibDataBroker object "ItemRack" with the icon
--     Interface\AddOns\ItemRack\ItemRackIcon, registered with LibDBIcon (button LibDBIcon10_ItemRack);
--   ItemRack.OnEnterWorld (2085-2091): two seconds after login or reload UpdateButtons and
--     UpdateCurrentSet, that is after this addon's scan on PLAYER_ENTERING_WORLD;
--   ItemRack.UpdateCurrentSet (3291-3420) calls ItemRack.SetMinimapButtonVisual(owner, hybrid)
--     (3171-3285) and then sets ItemRack.Broker.icon, which LibDBIcon passes on with
--     icon:SetTexture (LibDBIcon-1.0 IconCallback);
--   SetMinimapButtonVisual, one set (3259-3284): hides SplitIcon and Divider, puts the original
--     UpdateCoord back, then icon:ClearAllPoints(), icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6),
--     icon:SetSize(17, 17), icon:UpdateCoord(), icon:SetTexture(set icon), icon:Show();
--   SetMinimapButtonVisual, hybrid (3185-3258): creates button.SplitIcon (ARTWORK) and button.Divider
--     (ARTWORK, sublevel 7) once; icon at TOPLEFT 7/-6, 8.5 x 17, TexCoord 0.05-0.5; SplitIcon at
--     TOPLEFT 15.5/-6, 8.5 x 17, TexCoord 0.5-0.95; Divider 1 px wide from TOPLEFT 15.5/-6 down 17 px,
--     WHITE8X8 in gold; replaces icon.UpdateCoord; creates button.CircleMask (TempPortraitAlphaMask)
--     once and adds it to icon and SplitIcon with AddMaskTexture;
--   ItemRack.ReflectEventsRunning (ItemRackEvents.lua 2924-2944): while events run, the broker icon
--     is the gear Interface\AddOns\ItemRack\ItemRackGear.
-- LibDBIcon-1.0 minor 57 (shipped by Connoisseur & Restocker; the highest minor wins in LibStub):
--   SetButtonIcon and ResetButtonIcon call icon:SetSize, icon:ClearAllPoints and icon:SetPoint;
--   ResetButtonBorder sets the border 136430 again with ClearAllPoints, SetPoint and SetSize.

local ITEMRACK_ICON = "Interface\\AddOns\\ItemRack\\ItemRackIcon"
local ITEMRACK_GEAR = "Interface\\AddOns\\ItemRack\\ItemRackGear"
local SET_A = 132341 -- icons of two equipment sets (any file IDs)
local SET_B = 135274

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

local function assertDrawn(region, msg)
    local drawn, why = RegionDrawn(region)
    assert_true(drawn, (msg or "drawn") .. ": " .. tostring(why))
end

local function assertInside(region, button, msg)
    local s = StubState(region)
    assert_eq(s.points, {
        { "TOPLEFT", button, "TOPLEFT", 1, -1 },
        { "BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1 },
    }, msg or "1 px inside the button")
end

-- the LibDBIcon button of ItemRack as LibDBIcon builds it in WoW Forever (not Mainline: icon 17 x 17
-- at TOPLEFT 7/-6)
local function itemRackButton()
    return NewLibDBIconButton("ItemRack", { icon = ITEMRACK_ICON })
end

-- LibDBIcon's IconCallback for the broker key "icon"
local function setBrokerIcon(button, icon)
    button.dataObject.icon = icon
    button.icon:SetTexture(icon)
end

-- ItemRack.SetMinimapButtonVisual with one set (or none: setIcon nil shows ItemRack's own icon)
local function itemRackSingle(button, setIcon)
    local icon = button.icon
    if button.SplitIcon then button.SplitIcon:Hide() end
    if button.Divider then button.Divider:Hide() end
    if icon.itemRackSavedUpdateCoord then
        icon.UpdateCoord = icon.itemRackSavedUpdateCoord
        icon.itemRackSavedUpdateCoord = nil
    end
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetSize(17, 17)
    icon:UpdateCoord()
    icon:SetTexture(setIcon or ITEMRACK_ICON)
    icon:Show()
    setBrokerIcon(button, setIcon or ITEMRACK_ICON)
end

-- ItemRack.SetMinimapButtonVisual in the hybrid state (two sets)
local function itemRackHybrid(button, leftIcon, rightIcon)
    local icon = button.icon
    if not button.SplitIcon then button.SplitIcon = button:CreateTexture(nil, "ARTWORK") end
    if not button.Divider then button.Divider = button:CreateTexture(nil, "ARTWORK", nil, 7) end
    local split, divider = button.SplitIcon, button.Divider

    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetSize(8.5, 17)
    icon:SetTexCoord(0.05, 0.5, 0.05, 0.95)
    icon:SetTexture(leftIcon)
    icon:Show()

    split:ClearAllPoints()
    split:SetPoint("TOPLEFT", button, "TOPLEFT", 15.5, -6)
    split:SetSize(8.5, 17)
    split:SetTexCoord(0.5, 0.95, 0.05, 0.95)
    split:SetTexture(rightIcon)
    split:Show()

    divider:ClearAllPoints()
    divider:SetPoint("TOP", button, "TOPLEFT", 15.5, -6)
    divider:SetPoint("BOTTOM", button, "TOPLEFT", 15.5, -23)
    divider:SetWidth(1)
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(1, 0.82, 0, 0.9)
    divider:Show()

    if not icon.itemRackSavedUpdateCoord then icon.itemRackSavedUpdateCoord = icon.UpdateCoord end
    icon.UpdateCoord = function(self) self:SetTexCoord(0.05, 0.5, 0.05, 0.95) end

    if not button.CircleMask then
        local mask = button:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetSize(17, 17)
        mask:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
        button.CircleMask = mask
    end
    icon:AddMaskTexture(button.CircleMask)
    split:AddMaskTexture(button.CircleMask)
    setBrokerIcon(button, leftIcon)
end

-- client start with ItemRack's button on the minimap, scanned on PLAYER_ENTERING_WORLD
local function startedWithItemRack()
    ReloadAddon({})
    local button = itemRackButton()
    StartClient()
    return GetAddon(), button
end

describe("ItemRack Universal: one set", function()
    it("the icon stays in the square when ItemRack shows its set after the scan (empty in 1.0.1)", function()
        local SMB, button = startedWithItemRack()
        assert_true(button.isSkinned, "the scan took the button")
        itemRackSingle(button, SET_A) -- two seconds after login: UpdateCurrentSet
        assertDrawn(button.icon, "the set icon")
        assertInside(button.icon, button)
        assert_eq(button.icon:GetTexture(), SET_A)
        assert_eq((button.icon:GetDrawLayer()), "ARTWORK")
        assert_eq(button.icon:GetNumMaskTextures(), 0)
        assert_true(button:GetParent() == SMB.Bar, "in the bar")
    end)

    it("regression probe: with only SetPoint locked (1.0.1) the same calls leave the icon without anchors", function()
        local SMB, button = startedWithItemRack()
        local icon = button.icon
        SMB:UnlockRegion(icon)
        icon.SetPoint = SMB.Noop -- the lock of 1.0.1: ClearAllPoints stays real
        itemRackSingle(button, SET_A)
        assert_eq(icon:GetNumPoints(), 0, "ClearAllPoints ran, ItemRack's SetPoint went nowhere")
        local drawn, why = RegionDrawn(icon)
        assert_false(drawn, "not drawn")
        assert_eq(why, "no anchors")
    end)

    it("follows every later change: another set, the gear while events run, the own icon", function()
        local SMB, button = startedWithItemRack()
        for _, image in ipairs({ SET_A, SET_B }) do
            itemRackSingle(button, image)
            assert_eq(button.icon:GetTexture(), image)
            assertDrawn(button.icon)
        end
        setBrokerIcon(button, ITEMRACK_GEAR) -- ReflectEventsRunning
        assert_eq(button.icon:GetTexture(), ITEMRACK_GEAR)
        assertDrawn(button.icon, "the gear")
        itemRackSingle(button, nil)
        assert_eq(button.icon:GetTexture(), ITEMRACK_ICON)
        assertDrawn(button.icon)
        assertInside(button.icon, button)
    end)

    it("keeps LibDBIcon's pressed look: full image while pressed, the 5 % inset again after", function()
        local SMB, button = startedWithItemRack()
        itemRackSingle(button, SET_A)
        button:GetScript("OnMouseDown")(button)
        assert_eq({ button.icon:GetTexCoord() }, { 0, 0, 0, 1, 1, 0, 1, 1 })
        button:GetScript("OnMouseUp")(button)
        local c = { button.icon:GetTexCoord() }
        assert_near(c[1], 0.05, 1e-9)
        assert_near(c[7], 0.95, 1e-9)
        assertDrawn(button.icon)
    end)

    it("the set shown before the scan is kept (ItemRack ran first)", function()
        ReloadAddon({})
        local button = itemRackButton()
        itemRackSingle(button, SET_B)
        StartClient()
        assertDrawn(button.icon)
        assertInside(button.icon, button)
        assert_eq(button.icon:GetTexture(), SET_B)
    end)
end)

describe("ItemRack Universal: hybrid (two sets)", function()
    local function assertSplit(button, msg)
        local icon, split, divider = button.icon, button.SplitIcon, button.Divider
        assert_eq(StubState(icon).points, {
            { "TOPLEFT", button, "TOPLEFT", 1, -1 },
            { "BOTTOMRIGHT", button, "BOTTOM", 0, 1 },
        }, msg .. ": left half")
        assert_eq(StubState(split).points, {
            { "TOPLEFT", button, "TOP", 0, -1 },
            { "BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1 },
        }, msg .. ": right half")
        assert_eq(StubState(divider).points, {
            { "TOP", button, "TOP", 0, -1 },
            { "BOTTOM", button, "BOTTOM", 0, 1 },
        }, msg .. ": line in the middle")
        assert_eq(divider:GetWidth(), 1, msg .. ": line 1 px")
        assert_eq({ divider:GetDrawLayer() }, { "OVERLAY", 1 }, msg .. ": line above the halves")
        assert_eq(icon:GetNumMaskTextures(), 0, msg .. ": no round mask on the left half")
        assert_eq(split:GetNumMaskTextures(), 0, msg .. ": no round mask on the right half")
        assertDrawn(icon, msg .. ": left half")
        assertDrawn(split, msg .. ": right half")
        assertDrawn(divider, msg .. ": line")
        -- ItemRack's coordinates: half of the image on half of the square
        local c, d = { icon:GetTexCoord() }, { split:GetTexCoord() }
        assert_near(c[1], 0.05, 1e-9, msg)
        assert_near(c[7], 0.5, 1e-9, msg)
        assert_near(d[1], 0.5, 1e-9, msg)
        assert_near(d[7], 0.95, 1e-9, msg)
    end

    it("after the scan: left half, right half and the line in the square on the next frame", function()
        local SMB, button = startedWithItemRack()
        itemRackHybrid(button, SET_A, SET_B)
        assertDrawn(button.icon, "the left half stays drawn at once (locked anchors)")
        AdvanceTime(0) -- the check queued by ItemRack's SetTexture on the icon
        assertSplit(button, "next frame")
        assert_eq(button.icon:GetTexture(), SET_A)
        assert_eq(button.SplitIcon:GetTexture(), SET_B)
    end)

    it("the next scan does it as well (without the queued check)", function()
        local SMB, button = startedWithItemRack()
        itemRackHybrid(button, SET_A, SET_B)
        SMB:GrabMinimapButtons()
        assertSplit(button, "scan")
    end)

    it("ItemRack's later calls change nothing of the layout", function()
        local SMB, button = startedWithItemRack()
        itemRackHybrid(button, SET_A, SET_B)
        AdvanceTime(0)
        itemRackHybrid(button, SET_B, SET_A)
        assertSplit(button, "second hybrid call, at once")
        AdvanceTime(0)
        assertSplit(button, "second hybrid call, next frame")
        assert_eq(button.icon:GetTexture(), SET_B)
    end)

    it("back to one set: the icon fills the square again, half and line hidden", function()
        local SMB, button = startedWithItemRack()
        itemRackHybrid(button, SET_A, SET_B)
        AdvanceTime(0)
        itemRackSingle(button, SET_B)
        AdvanceTime(0)
        assertInside(button.icon, button)
        assertDrawn(button.icon)
        assert_false(button.SplitIcon:IsShown())
        assert_false(button.Divider:IsShown())
        assert_eq(button.icon:GetNumMaskTextures(), 0)
    end)

    it("hybrid before the scan: the scan lays out the split and takes the round masks off", function()
        ReloadAddon({})
        local button = itemRackButton()
        itemRackHybrid(button, SET_A, SET_B)
        assert_eq(button.icon:GetNumMaskTextures(), 1)
        StartClient()
        assertSplit(button, "scan at login")
        assert_eq(button.CircleMask:GetTexture(), "Interface\\CharacterFrame\\TempPortraitAlphaMask", "the mask itself stays")
    end)
end)

describe("LibDBIcon-1.0 minor 57 (Connoisseur & Restocker ships it)", function()
    -- lib:SetButtonIcon(name, texture, size, point, x, y) and lib:ResetButtonIcon(name)
    local function setButtonIcon(button, texture, size, point, x, y)
        button.icon:SetTexture(texture)
        button.icon:SetSize(size, size)
        button.icon:ClearAllPoints()
        button.icon:SetPoint(point, x, y)
    end
    -- lib:ResetButtonBorder(name) in WoW Forever (not Mainline)
    local function resetButtonBorder(button)
        button.border:ClearAllPoints()
        button.border:SetPoint("TOPLEFT", 0, 0)
        button.border:SetTexture(136430)
        button.border:SetSize(53, 53)
    end

    it("SetButtonIcon after the scan: new image, the icon stays in the square", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Beta")
        SMB:GrabMinimapButtons()
        setButtonIcon(button, 134062, 20, "CENTER", 1, 0)
        assert_eq(button.icon:GetTexture(), 134062)
        assertInside(button.icon, button)
        assertDrawn(button.icon)
    end)

    it("ResetButtonBorder after the scan: the round border is emptied again on the next frame", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Beta")
        SMB:GrabMinimapButtons()
        resetButtonBorder(button)
        AdvanceTime(0)
        assert_nil(button.border:GetTexture())
        assert_eq(button.border:GetAlpha(), 0)
        assertDrawn(button.icon)
    end)
end)

describe("textures that come or change after the skin", function()
    it("a texture created after the scan is skinned by the next scan", function()
        local SMB = fresh()
        local button = NewPlainButton("LateTexture")
        SMB:GrabMinimapButtons()
        local late = button:CreateTexture(nil, "OVERLAY")
        late:SetTexture(134401)
        late:SetPoint("CENTER", button, "CENTER", 30, 0)
        SMB:GrabMinimapButtons()
        assertInside(late, button)
        assert_eq((late:GetDrawLayer()), "ARTWORK")
        assert_true(late.SetPoint == SMB.Noop)
    end)

    it("a texture that gets its image only after the skin is skinned on the next frame", function()
        local SMB = fresh()
        local button = NewPlainButton("LateImage")
        local empty = button:CreateTexture(nil, "BORDER")
        empty:SetPoint("CENTER")
        SMB:GrabMinimapButtons()
        assert_eq(#StubState(empty).points, 1, "left alone while it has no image")
        empty:SetTexture(134402)
        AdvanceTime(0)
        assertInside(empty, button)
        assertDrawn(empty)
    end)

    it("a mask added after the skin does not reach the icon (AddMaskTexture locked)", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Gamma")
        SMB:GrabMinimapButtons()
        local mask = button:CreateMaskTexture()
        mask:SetTexture(130924)
        button.icon:AddMaskTexture(mask)
        assert_eq(button.icon:GetNumMaskTextures(), 0)
        assert_eq(mask:GetTexture(), 130924, "the mask itself is not touched")
    end)

    it("SetAllPoints, SetSize, SetWidth, SetHeight and SetDrawLayer of the addon change nothing", function()
        local SMB = fresh()
        local button = NewPlainButton("Mover")
        SMB:GrabMinimapButtons()
        local icon = button.icon
        icon:SetAllPoints(UIParent)
        icon:SetSize(40, 40)
        icon:SetWidth(3)
        icon:SetHeight(3)
        icon:SetDrawLayer("BACKGROUND")
        assertInside(icon, button)
        assert_eq((icon:GetDrawLayer()), "ARTWORK")
        assertDrawn(icon)
    end)

    it("the crop comes back when the addon sets the full image again", function()
        local SMB = fresh()
        local button = NewPlainButton("Recropped")
        SMB:GrabMinimapButtons()
        button.icon:SetTexCoord(0, 1, 0, 1)
        AdvanceTime(0)
        local c = { button.icon:GetTexCoord() }
        assert_near(c[1], 0.08, 1e-9)
        assert_near(c[7], 0.92, 1e-9)
    end)

    it("an own field of the addon on a locked method comes back when the skin unlocks", function()
        local SMB = fresh()
        local button = NewPlainButton("OwnField")
        local own = function() end
        button.icon.SetSize = own
        SMB:GrabMinimapButtons()
        assert_true(button.icon.SetSize == SMB.Noop)
        SMB:UnlockRegion(button.icon)
        assert_true(button.icon.SetSize == own)
    end)

    it("hooks queue one check per button and frame, and the skin's own calls queue none", function()
        local SMB = fresh()
        local button = NewPlainButton("Quiet")
        SMB:GrabMinimapButtons()
        local before = PendingTimers()
        SMB:CheckButton(button)
        assert_eq(PendingTimers(), before, "the check itself queues nothing")
        button.icon:SetTexture(134401)
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.icon:Show()
        assert_eq(PendingTimers(), before + 1, "one queued check")
        AdvanceTime(0)
        assert_eq(PendingTimers(), before, "and no new one after it ran")
    end)
end)

describe("other addons of the owner", function()
    it("RXPGuides: a LibDataBroker data source with tocname; a new icon shows", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("RXPGuides", { icon = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64" })
        button.dataObject.tocname = "RXPGuides"
        SMB:GrabMinimapButtons()
        setBrokerIcon(button, "Interface\\AddOns\\RXPGuides\\Textures\\rxp-minimap-icon")
        assertDrawn(button.icon)
        assertInside(button.icon, button)
    end)

    it("ForeverAuras: hiding the minimap icon takes the button out of the bar, showing brings it back drawn", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("ForeverAuras", { icon = "Interface\\AddOns\\ForeverAuras\\Media\\Textures\\foreverauras_minimap.tga" })
        SMB:GrabMinimapButtons()
        assert_true(button:GetParent() == SMB.Bar)
        button:Hide() -- LibDBIcon:Hide("ForeverAuras")
        SMB:Update()
        assert_false(SMB.Bar:IsShown(), "no visible button: the bar hides")
        button:Show() -- LibDBIcon:Show("ForeverAuras")
        SMB:GrabMinimapButtons(true)
        assert_true(SMB.Bar:IsShown())
        assertDrawn(button.icon)
    end)

    it("an own button whose icon fills it and that places itself again when the minimap changes size", function()
        -- the minimap button of CooldownTimeline3: no LibDBIcon, icon with SetAllPoints, the button
        -- moved with ClearAllPoints and SetPoint around the minimap on OnSizeChanged
        local SMB = fresh()
        local button = CreateFrame("Button", "OwnRoundButton", Minimap)
        button:SetSize(24, 24)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture("Interface\\AddOns\\OwnAddon\\minimap.tga")
        SMB:GrabMinimapButtons()
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", -80, -80)
        local _, relativeTo = button:GetPoint()
        assert_true(relativeTo == SMB.Bar, "the button stays in the bar (LockButton)")
        assertInside(icon, button)
        assertDrawn(icon)
    end)
end)
