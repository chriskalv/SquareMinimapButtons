-- Test group 3 (skinning): SkinMinimapButton and HandleRegion after ProjectAzilroka's
-- Modules/SquareMinimapButtons.lua, with the issecretvalue guard of the port.

local FULL = { 0, 0, 0, 1, 1, 0, 1, 1 }

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

local function texCoord(region) return { region:GetTexCoord() } end

local function assertCoords(region, l, r, t, b, msg)
    local c = texCoord(region)
    local expected = { l, t, l, b, r, t, r, b }
    for i = 1, 8 do
        assert_near(c[i], expected[i], 1e-9, (msg or "texture coordinate") .. " " .. i)
    end
end

local function assertInside(region, button)
    local s = StubState(region)
    assert_eq(#s.points, 2, "two points")
    assert_eq(s.points[1], { "TOPLEFT", button, "TOPLEFT", 1, -1 })
    assert_eq(s.points[2], { "BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1 })
end

describe("textures of a LibDBIcon button", function()
    it("empties border, background and highlight (SetTexture() and alpha 0)", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        local highlight = button:GetHighlightTexture()
        SMB:SkinMinimapButton(button)
        for _, region in ipairs({ button.border, button.background, highlight }) do
            local s = StubState(region)
            assert_nil(region:GetTexture(), "texture removed")
            assert_eq(s.setTextureArgs, 0, "SetTexture without argument")
            assert_eq(region:GetAlpha(), 0)
            assert_true(region.SetPoint ~= SMB.Noop, "removed textures are not handled further")
        end
    end)

    it("fits the icon into the button (SetInside, ARTWORK, empty mask, SetPoint without effect)", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:SkinMinimapButton(button)
        local icon = button.icon
        assertInside(icon, button)
        assert_eq((icon:GetDrawLayer()), "ARTWORK")
        assert_eq(icon:GetMask(), "")
        assert_eq(icon:GetAlpha(), 1)
        assert_true(icon.SetPoint == SMB.Noop)
        icon:SetPoint("CENTER", button, "CENTER", 5, 5)
        assertInside(icon, button)
    end)

    it("keeps LibDBIcon's own 5 % inset of the icon (the crop applies only to full coordinates)", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:SkinMinimapButton(button)
        assertCoords(button.icon, 0.05, 0.95, 0.05, 0.95)
    end)

    it("removes every file ID of the list, also when the texture was set by path", function()
        local SMB = fresh()
        STUB.textureFileIDs["Interface\\Minimap\\MiniMap-TrackingBorder"] = 136430
        local button = NewPlainButton("ManyTextures")
        local regions = {}
        for i, id in ipairs({ 136430, 136467, 136477, 136468, 130924, 982840 }) do
            regions[i] = button:CreateTexture(nil, "OVERLAY")
            regions[i]:SetTexture(id)
        end
        local byPath = button:CreateTexture(nil, "OVERLAY")
        byPath:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        local kept = button:CreateTexture(nil, "OVERLAY")
        kept:SetTexture(136431)
        SMB:SkinMinimapButton(button)
        for i, region in ipairs(regions) do
            assert_nil(region:GetTexture(), "file ID " .. i)
            assert_eq(region:GetAlpha(), 0)
        end
        assert_nil(byPath:GetTexture())
        assert_eq(kept:GetTexture(), 136431, "other file IDs stay")
        assertInside(kept, button)
    end)
end)

describe("crop", function()
    it("crops 0.08 per side without ElvUI when the coordinates are full", function()
        local SMB = fresh()
        local button = NewPlainButton("PlainAddonButton")
        assert_eq(texCoord(button.icon), FULL)
        SMB:SkinMinimapButton(button)
        assertCoords(button.icon, 0.08, 0.92, 0.08, 0.92)
        assertInside(button.icon, button)
        assert_eq((button.icon:GetDrawLayer()), "ARTWORK", "BACKGROUND becomes ARTWORK")
    end)

    it("crops after ElvUI's cropIcon", function()
        local SMB = fresh({ elvui = { cropIcon = 1 } })
        local button = NewPlainButton("PlainAddonButton")
        SMB:SkinMinimapButton(button)
        assertCoords(button.icon, 0.04, 0.96, 0.04, 0.96)
    end)

    it("uses the special coordinates for TomCats (GetDebugName)", function()
        local SMB = fresh()
        local button = NewPlainButton("TomCats-MinimapButton")
        assert_eq(button:GetDebugName(), "TomCats-MinimapButton")
        SMB:SkinMinimapButton(button)
        assertCoords(button.icon, 0, 0.64, 0, 0.64)
    end)

    it("restores the crop on OnLeave after a foreign change", function()
        local SMB = fresh()
        local button = NewPlainButton("PlainAddonButton")
        SMB:SkinMinimapButton(button)
        button.icon:SetTexCoord(0, 1, 0, 1)
        button:GetScript("OnLeave")(button)
        assertCoords(button.icon, 0.08, 0.92, 0.08, 0.92)
    end)

    it("restores only cropped regions on OnLeave", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:SkinMinimapButton(button)
        button:GetScript("OnMouseDown")(button) -- LibDBIcon: full coordinates while pressed
        assertCoords(button.icon, 0, 1, 0, 1, "OnMouseDown shows the full icon")
        button:GetScript("OnLeave")(button)
        assertCoords(button.icon, 0, 1, 0, 1, "LibDBIcon's icon was not cropped, so OnLeave leaves it")
        assert_eq(button.log[#button.log], "OnLeave", "the button's own OnLeave still runs")
        button:GetScript("OnMouseUp")(button)
        assertCoords(button.icon, 0.05, 0.95, 0.05, 0.95, "OnMouseUp restores LibDBIcon's inset")
    end)

    it("does not crop coordinates that differ from the full ones in a single value", function()
        -- Each case changes exactly one of the eight values that HandleRegion compares.
        local cases = {
            { 0.1, 0, 0, 1, 1, 0, 1, 1 }, { 0, 0.1, 0, 1, 1, 0, 1, 1 },
            { 0, 0, 0.1, 1, 1, 0, 1, 1 }, { 0, 0, 0, 0.5, 1, 0, 1, 1 },
            { 0, 0, 0, 1, 0.9, 0, 1, 1 }, { 0, 0, 0, 1, 1, 0.1, 1, 1 },
            { 0, 0, 0, 1, 1, 0, 0.9, 1 }, { 0, 0, 0, 1, 1, 0, 1, 0.5 },
        }
        for i, coords in ipairs(cases) do
            local SMB = fresh()
            local button = NewPlainButton("PlainAddonButton")
            button.icon:SetTexCoord(unpack(coords))
            SMB:SkinMinimapButton(button)
            assert_eq(texCoord(button.icon), coords, "case " .. i .. ": coordinates unchanged")
            button.icon:SetTexCoord(0, 1, 0, 1)
            button:GetScript("OnLeave")(button)
            assert_eq(texCoord(button.icon), FULL, "case " .. i .. ": no crop restored on OnLeave")
        end
    end)

    it("does not crop a texture cut only at the bottom (0, 1, 0, 0.5)", function()
        local SMB = fresh()
        local button = NewPlainButton("PlainAddonButton")
        button.icon:SetTexCoord(0, 1, 0, 0.5)
        SMB:SkinMinimapButton(button)
        assertCoords(button.icon, 0, 1, 0, 0.5)
        button.icon:SetTexCoord(0, 1, 0, 1)
        button:GetScript("OnLeave")(button)
        assertCoords(button.icon, 0, 1, 0, 1, "no OnLeave restore for an uncropped region")
    end)
end)

describe("secret texture coordinates", function()
    it("does not crop when the coordinates are secret values; everything else runs", function()
        local SMB = fresh()
        local button = NewPlainButton("SecretButton")
        MarkSecretTexCoord(button.icon)
        assert_true(issecretvalue(({ button.icon:GetTexCoord() })[1]), "the stub reports the values as secret")
        local ok, err = pcall(SMB.SkinMinimapButton, SMB, button)
        assert_true(ok, tostring(err))
        assert_eq(texCoord(button.icon), FULL, "no crop")
        assertInside(button.icon, button)
        assert_eq((button.icon:GetDrawLayer()), "ARTWORK")
        assert_eq(button.icon:GetMask(), "")
        assert_true(button.icon.SetPoint == SMB.Noop)
        assert_eq({ button:GetSize() }, { 18, 18 })
        assert_true(button.backdropInfo ~= nil, "template applied")
        assert_true(button.isSkinned)
        button.icon:SetTexCoord(0.2, 0.8, 0.2, 0.8)
        button:GetScript("OnLeave")(button)
        assertCoords(button.icon, 0.2, 0.8, 0.2, 0.8, "no restore hook for an uncropped region")
    end)

    it("crops other regions of the same button", function()
        local SMB = fresh()
        local button = NewPlainButton("SecretButton")
        MarkSecretTexCoord(button.icon)
        local second = button:CreateTexture(nil, "ARTWORK")
        second:SetTexture(134401)
        SMB:SkinMinimapButton(button)
        assert_eq(texCoord(button.icon), FULL)
        assertCoords(second, 0.08, 0.92, 0.08, 0.92)
    end)

    it("does not crop when a coordinate is not a number", function()
        local SMB = fresh()
        local button = NewPlainButton("OddCoords")
        StubState(button.icon).texCoord = {}
        local ok, err = pcall(SMB.SkinMinimapButton, SMB, button)
        assert_true(ok, tostring(err))
        assert_eq(texCoord(button.icon), {})
        assertInside(button.icon, button)
    end)

    it("crops in clients without issecretvalue", function()
        local SMB = fresh({ noSecretAPI = true })
        assert_nil(issecretvalue)
        local button = NewPlainButton("PlainAddonButton")
        SMB:SkinMinimapButton(button)
        assertCoords(button.icon, 0.08, 0.92, 0.08, 0.92)
    end)
end)

describe("regions and children", function()
    it("handles the textures of direct children, not of grandchildren, and no font strings", function()
        local SMB = fresh()
        local button = NewPlainButton("Parent")
        local child = CreateFrame("Frame", nil, button)
        local childTexture = child:CreateTexture(nil, "OVERLAY")
        childTexture:SetTexture(134402)
        local childBorder = child:CreateTexture(nil, "OVERLAY")
        childBorder:SetTexture(136430)
        local grandchild = CreateFrame("Frame", nil, child)
        local deep = grandchild:CreateTexture(nil, "OVERLAY")
        deep:SetTexture(136430)
        local text = button:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER")
        SMB:SkinMinimapButton(button)
        assertInside(childTexture, child) -- SetInside anchors to the region's own parent
        assert_eq(childTexture:GetMask(), "")
        assert_nil(childBorder:GetTexture())
        assert_eq(deep:GetTexture(), 136430, "grandchildren stay")
        assert_eq(deep:GetAlpha(), 1)
        assert_eq({ text:GetPoint() }, { "CENTER", button, "CENTER", 0, 0 }, "font strings stay")
        assert_nil(rawget(text, "SetPoint"))
    end)

    it("leaves a texture without file alone", function()
        local SMB = fresh()
        local button = NewPlainButton("EmptyTexture")
        local empty = button:CreateTexture(nil, "BORDER")
        empty:SetPoint("CENTER")
        SMB:SkinMinimapButton(button)
        assert_eq(#StubState(empty).points, 1)
        assert_eq((empty:GetDrawLayer()), "BORDER")
        assert_nil(rawget(empty, "SetPoint"))
    end)
end)

describe("the button", function()
    it("gets IconSize, the minimap's level + 10 and the minimap's strata", function()
        local SMB = fresh()
        Minimap:SetFrameLevel(5)
        Minimap:SetFrameStrata("LOW")
        SMB.db.IconSize = 30
        local button = NewPlainButton("PlainAddonButton")
        button:SetFrameStrata("HIGH")
        SMB:SkinMinimapButton(button)
        assert_eq({ button:GetSize() }, { 30, 30 })
        assert_eq(button:GetFrameLevel(), 15)
        assert_eq(button:GetFrameStrata(), "LOW")
    end)

    it("uses the default IconSize of the profile (18)", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:SkinMinimapButton(button)
        assert_eq({ button:GetSize() }, { 18, 18 })
    end)

    it("gets the template, and a shadow only with db.Shadows (ElvUI frame API)", function()
        local SMB = fresh({ elvui = { frameAPI = true } })
        local a = NewPlainButton("WithShadow")
        SMB:SkinMinimapButton(a)
        assert_eq(StubState(a).elvTemplate, { "Transparent", true })
        assert_true(StubState(a).shadow)
        SMB.db.Shadows = false
        local b = NewPlainButton("WithoutShadow")
        SMB:SkinMinimapButton(b)
        assert_eq(StubState(b).elvTemplate, { "Transparent", true })
        assert_nil(StubState(b).shadow)
    end)

    it("gets the own backdrop without ElvUI", function()
        local SMB = fresh()
        local button = NewPlainButton("PlainAddonButton")
        SMB:SkinMinimapButton(button)
        assert_eq(button.backdropInfo, { bgFile = [[Interface\Buttons\WHITE8X8]], edgeFile = [[Interface\Buttons\WHITE8X8]], edgeSize = 1 })
    end)

    it("gets neither template nor shadow with ignoreTemplate", function()
        local SMB = fresh({ elvui = { frameAPI = true } })
        local button = NewPlainButton("OwnLook")
        button.ignoreTemplate = true
        SMB:SkinMinimapButton(button)
        assert_nil(StubState(button).elvTemplate)
        assert_nil(StubState(button).shadow)
        assert_eq(STUB.calls.ElvUICreateShadow, nil)
    end)

    it("applies the template on OnLeave like the original, also with ignoreTemplate", function()
        local SMB = fresh({ elvui = { frameAPI = true } })
        local button = NewPlainButton("OwnLook")
        button.ignoreTemplate = true
        SMB:SkinMinimapButton(button)
        button:GetScript("OnLeave")(button)
        assert_eq(StubState(button).elvTemplate, { "Transparent", true })
    end)

    it("is marked as skinned and listed once", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:SkinMinimapButton(button)
        assert_true(button.isSkinned)
        assert_eq(#SMB.Buttons, 1)
        assert_true(SMB.Buttons[1] == button)
        local onLeave = button:GetScript("OnLeave")
        SMB:SkinMinimapButton(button)
        assert_eq(#SMB.Buttons, 1, "a second call does nothing")
        assert_true(button:GetScript("OnLeave") == onLeave, "no second set of hooks")
    end)
end)

describe("fading hooks", function()
    it("OnEnter and OnLeave run without the bar", function()
        local SMB = fresh()
        local realBar = SMB.Bar
        SMB.Bar = nil -- as with BarEnabled off or before Initialize
        STUB.fades = {}
        local button = NewLibDBIconButton("Alpha")
        SMB:SkinMinimapButton(button)
        local ok, err = pcall(function()
            button:GetScript("OnEnter")(button)
            button:GetScript("OnLeave")(button)
        end)
        assert_true(ok, tostring(err))
        assert_eq(#STUB.fades, 0)
        assert_eq(button.log, { "OnEnter", "OnLeave" }, "the button's own scripts still run")
        SMB.Bar = realBar
    end)

    it("fade the bar in on OnEnter and out on OnLeave only with BarMouseOver", function()
        local SMB = fresh()
        local button = NewLibDBIconButton("Alpha")
        SMB:SkinMinimapButton(button)
        local realBar = SMB.Bar
        SMB.Bar = CreateFrame("Frame", nil, UIParent)
        SMB.Bar:SetAlpha(0.5)
        STUB.fades = {}
        button:GetScript("OnEnter")(button)
        assert_eq(#STUB.fades, 1)
        assert_eq(STUB.fades[1].mode, "IN")
        assert_true(STUB.fades[1].frame == SMB.Bar)
        assert_eq({ STUB.fades[1].duration, STUB.fades[1].from, STUB.fades[1].to }, { 0.2, 0.5, 1 })
        button:GetScript("OnLeave")(button)
        assert_eq(#STUB.fades, 1, "no fade out without BarMouseOver")
        SMB.db.BarMouseOver = true
        button:GetScript("OnLeave")(button)
        assert_eq(#STUB.fades, 2)
        assert_eq(STUB.fades[2].mode, "OUT")
        assert_eq({ STUB.fades[2].from, STUB.fades[2].to }, { 1, 0 })
        SMB.Bar:Hide()
        button:GetScript("OnEnter")(button)
        button:GetScript("OnLeave")(button)
        assert_eq(#STUB.fades, 2, "a hidden bar does not fade")
        SMB.Bar = realBar
    end)
end)

-- A LibDBIcon button as Connoisseur & Restocker adjusts it for Camelot and Mainline
-- (Features/Minimap-Button.lua, RegisterMinimapIcon): icon 20 x 20 at CENTER +1/-0.35 and a mask
-- texture with the round file 130924 (TempPortraitAlphaMask) on the icon; the icon itself is the
-- best food (UpdateMinimapIcon sets it again later).
local FOOD_ICON = 133945
local MASK_FILE = 130924

local function connoisseurButton()
    local button = NewLibDBIconButton("Connoisseur")
    button.icon:SetSize(20, 20)
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER", 1, -0.35)
    local mask = button:CreateMaskTexture()
    mask:SetTexture(MASK_FILE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(button.icon)
    button.icon:AddMaskTexture(mask)
    button.icon:SetTexture(FOOD_ICON)
    return button, mask
end

describe("mask textures (nachtrag 2: empty button of Connoisseur & Restocker)", function()
    it("the stub mask is a texture object of type MaskTexture with the file ID 130924", function()
        fresh()
        local _, mask = connoisseurButton()
        assert_true(mask:IsObjectType("Texture"))
        assert_eq(mask:GetObjectType(), "MaskTexture")
        assert_eq(mask:GetTextureFileID(), MASK_FILE)
        assert_true(GetAddon():RemoveTexture(mask:GetTextureFileID()), "130924 stays in RemoveTextureID")
    end)

    it("keeps the icon: texture, alpha, no mask on it; the mask itself is left untouched", function()
        local SMB = fresh()
        local button, mask = connoisseurButton()
        local maskPoints = StubState(mask).points
        SMB:SkinMinimapButton(button)
        local icon = button.icon
        assert_eq(icon:GetTexture(), FOOD_ICON, "the food icon stays")
        assert_eq(icon:GetAlpha(), 1)
        assert_eq(icon:GetNumMaskTextures(), 0, "the round mask is taken off the icon")
        assertInside(icon, button)
        assert_eq(mask:GetTexture(), MASK_FILE, "the mask is not emptied")
        assert_eq(mask:GetAlpha(), 1, "the mask keeps its alpha")
        assert_true(StubState(mask).points == maskPoints, "the mask is not moved")
        assert_true(rawget(mask, "SetPoint") == nil, "the mask's SetPoint is not locked")
        assert_eq(texCoord(mask), FULL, "the mask is not cropped")
    end)

    it("a later icon change of the addon shows in the bar (UpdateMinimapIcon)", function()
        local SMB = fresh()
        local button = connoisseurButton()
        SMB:GrabMinimapButtons(true)
        assert_true(button:GetParent() == SMB.Bar)
        button.icon:SetTexture(134062)
        assert_eq(button.icon:GetTexture(), 134062)
        assert_eq(button.icon:GetNumMaskTextures(), 0)
    end)

    -- Regression probe: the code before nachtrag 2 emptied the mask (it is a texture with a file
    -- ID of RemoveTextureID), and a texture masked by an empty mask is invisible.
    it("the old logic (masks treated as textures) would have emptied the mask", function()
        local SMB = fresh()
        local button, mask = connoisseurButton()
        local isMask = SMB.IsMaskTexture
        assert_true(isMask(mask))
        assert_false(isMask(button.icon))
        SMB:SkinMinimapButton(button)
        assert_true(mask:GetTexture() ~= nil, "not emptied")
        assert_true(StubState(mask).setTextureArgs ~= 0, "never SetTexture() without argument")
    end)

    it("130924 as an ordinary round texture (not a mask) is still emptied", function()
        local SMB = fresh()
        local button = NewPlainButton("RoundBorderButton", { border = MASK_FILE })
        SMB:SkinMinimapButton(button)
        assert_nil(button.border:GetTexture())
        assert_eq(button.border:GetAlpha(), 0)
        assert_eq(button.icon:GetTexture(), 134400)
    end)

    it("takes every mask off a skinned texture, also masks with other files, and leaves them alone", function()
        local SMB = fresh()
        local button = NewPlainButton("TwoMasks")
        local a, b = button:CreateMaskTexture(), button:CreateMaskTexture()
        a:SetTexture("Interface\\Masks\\CircleMaskScalable")
        b:SetTexture(MASK_FILE)
        button.icon:AddMaskTexture(a)
        button.icon:AddMaskTexture(b)
        SMB:SkinMinimapButton(button)
        assert_eq(button.icon:GetNumMaskTextures(), 0)
        assert_eq(a:GetTexture(), "Interface\\Masks\\CircleMaskScalable")
        assert_eq(b:GetTexture(), MASK_FILE)
        assert_eq(STUB.calls.RemoveMaskTexture, 2)
    end)

    it("RemoveMasks changes nothing when the count is a secret value", function()
        local SMB = fresh()
        local button, mask = connoisseurButton()
        local icon = button.icon
        local count = icon.GetNumMaskTextures
        icon.GetNumMaskTextures = function(self)
            STUB.secretTexCoordPending = true -- issecretvalue answers true for the next numbers
            return count(self)
        end
        assert_eq(SMB:RemoveMasks(icon), 0)
        STUB.secretTexCoordPending = false
        assert_eq(icon:GetNumMaskTextures(), 1, "the mask stays")
        assert_true(icon:GetMaskTexture(1) == mask)
    end)

    it("RemoveMasks works on regions without the mask API", function()
        local SMB = fresh()
        assert_eq(SMB:RemoveMasks({}), 0)
    end)
end)
