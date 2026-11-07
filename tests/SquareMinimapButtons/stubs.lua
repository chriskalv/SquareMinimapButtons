-- Square Minimap Buttons tests: WoW API stubs.
--
-- The runner (tools/addon_test.mjs) loads this file first in a fresh Lua state, then _harness.lua,
-- calls __before_addon_load() (snapshot of the globals), loads the libraries and addon files in TOC
-- order and finally the test file. Tests change the simulated client with ReloadAddon(config):
-- it removes every global that did not exist before the addon was loaded, installs fresh stubs for
-- the given configuration and loads the addon again (LoadAddon is provided by the runner).
--
-- Configuration (all fields optional):
--   projectID     WOW_PROJECT_ID (default 18 = WOW_PROJECT_CAMELOT, WoW Forever)
--   interface     4th value of GetBuildInfo (default by projectID: 16001, 120105 or 11508)
--   locale        GetLocale() (default "enUS")
--   player        { name, realm, class, race, faction }
--   pa            false/nil, or { enabled = true|false, dbAtLogin = true|false }: ProjectAzilroka
--                 loaded; its SquareMinimapButtons module enabled or not; dbAtLogin: PA sets its
--                 profile only in its own PLAYER_LOGIN handler, after this addon's OnEnable;
--                 noDB = true: ProjectAzilroka never sets its profile (its settings cannot be read)
--   elvui         false/nil, or { cropIcon = n, frameAPI = true|false }: ElvUI loaded
--   tukui, addonskins   true: these addons are enabled and loaded
--   combat        InCombatLockdown()
--   petBattle     C_PetBattles.IsInBattle()
--   newMail       HasNewMail() (SetNewMail(v) changes it and fires UPDATE_PENDING_MAIL)
--   elvui.queueStatus  true: ElvUI's queue module is loaded (frame ElvUIQueueStatus exists)
--   elvui.options true or { loaded = true|false, noEP = true }: ElvUI has its options table
--                 ElvUI[1].Options.args and its plugin library ElvUI[1].Libs.EP (LibElvUIPlugin-1.0,
--                 RegisterPlugin); loaded = true: ElvUI_Options is loaded already, RegisterPlugin calls
--                 the callback at once, else STUB.FireElvUIOptions() calls the callbacks (as when
--                 ElvUI_Options loads); noEP = true: the options table without the plugin library
--   retailGlobals true: PVEFrame, ShowUIPanel, HideUIPanel and GroupFinderFrame_ShowGroupFrame
--                 exist (Retail; WoW Forever has none of them)
--   missing       { GameTimeFrame = true, QueueStatusButton = true, Tracking = true,
--                 MinimapMailFrameUpdate = true }: these frames or functions of the default UI do
--                 not exist (Tracking: MinimapCluster.Tracking)
--   noAtlasInfo   true: C_Texture.GetAtlasInfo knows no atlas
--   noSecretAPI   true: no issecretvalue (clients without the secret system)
--   savedVariables  initial value of SquareMinimapButtonsDB
--
-- Lua 5.3 (fengari) runs these stubs; the addon itself must stay Lua 5.1 code.

unpack = unpack or table.unpack
loadstring = loadstring or load

-- Lua 5.1 has none of these; remove them so that addon code using them fails here as in the client.
utf8 = nil
table.pack, table.unpack, table.move = nil, nil, nil
string.pack, string.unpack, string.packsize = nil, nil, nil
math.type, math.tointeger, math.ult = nil, nil, nil

STUB = nil -- the simulated world, rebuilt by InstallStubs

local DEFAULT_INTERFACE = { [1] = 120105, [2] = 11508, [18] = 16001 }

--------------------------------------------------------------------------------
-- Lua helpers of the WoW client
--------------------------------------------------------------------------------

local function installLuaHelpers()
    strlower, strupper, strfind, strmatch = string.lower, string.upper, string.find, string.match
    strsub, strlen, strrep, strbyte, strchar = string.sub, string.len, string.rep, string.byte, string.char
    gsub, gmatch, format = string.gsub, string.gmatch, string.format
    strrev = string.reverse
    floor, ceil, abs, min, max = math.floor, math.ceil, math.abs, math.min, math.max
    sqrt, mod = math.sqrt, math.fmod
    tinsert, tremove, sort, tconcat = table.insert, table.remove, table.sort, table.concat
    getn = function(t) return #t end
    table.getn = table.getn or getn
    table.wipe = function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end
    wipe = table.wipe

    function strtrim(s, chars)
        s = tostring(s or "")
        if chars then
            local set = "[" .. chars:gsub("[%]%^%-%%]", "%%%0") .. "]"
            return (s:gsub("^" .. set .. "+", ""):gsub(set .. "+$", ""))
        end
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end

    function strsplit(delimiter, str, pieces)
        local result = {}
        local start = 1
        local set = "[" .. delimiter:gsub("[%]%^%-%%]", "%%%0") .. "]"
        while true do
            if pieces and #result == pieces - 1 then
                result[#result + 1] = str:sub(start)
                break
            end
            local a, b = str:find(set, start)
            if not a then
                result[#result + 1] = str:sub(start)
                break
            end
            result[#result + 1] = str:sub(start, a - 1)
            start = b + 1
        end
        return unpack(result)
    end

    function strjoin(delimiter, ...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        return table.concat(parts, delimiter)
    end

    -- the client adds these to the string library (AceConfigCmd-3.0 uses string.trim and string.split)
    string.trim, string.split, string.join = strtrim, strsplit, strjoin

    function tostringall(...)
        local n = select("#", ...)
        local t = {}
        for i = 1, n do t[i] = tostring((select(i, ...))) end
        return unpack(t, 1, n)
    end

    function strlenutf8(s)
        local _, count = tostring(s):gsub("[^\128-\191]", "")
        return count
    end

    function tContains(t, value)
        for _, v in pairs(t) do
            if v == value then return true end
        end
        return false
    end

    function CopyTable(t)
        local copy = {}
        for k, v in pairs(t) do
            copy[k] = type(v) == "table" and CopyTable(v) or v
        end
        return copy
    end

    date = os.date
    time = function(t)
        if t then return os.time(t) end
        return 1700000000 + math.floor(STUB.time)
    end
end

--------------------------------------------------------------------------------
-- Frames, textures, font strings
--------------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- internal state per object, kept out of the object table

local Methods = {} -- per object type
local FRAME_TYPES = {
    "Frame", "Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "GameTooltip",
    "Cooldown", "Minimap", "DropdownButton", "ColorSelect", "SimpleHTML", "MessageFrame", "Model",
}
local IS_A = {
    Button = { Button = true, Frame = true },
    CheckButton = { CheckButton = true, Button = true, Frame = true },
    DropdownButton = { DropdownButton = true, Button = true, Frame = true },
    Texture = { Texture = true, TextureBase = true, Region = true },
    -- the brief of nachtrag 2: a MaskTexture answers IsObjectType('Texture') with true
    MaskTexture = { MaskTexture = true, Texture = true, TextureBase = true, Region = true },
    FontString = { FontString = true, Region = true },
}

local function st(obj)
    local s = S[obj]
    if not s then error("not a stub object: " .. tostring(obj), 3) end
    return s
end

local function resolveName(name, parent)
    if type(name) ~= "string" then return nil end
    if name:find("$parent", 1, true) then
        local pname = parent and S[parent] and S[parent].name or ""
        name = name:gsub("%$parent", pname)
    end
    return name
end

local function fireScript(obj, script, ...)
    local s = S[obj]
    local fn = s and s.scripts[script]
    if fn then return fn(obj, ...) end
end

-- methods shared by frames and regions
local Common = {}

function Common:GetName() return st(self).name end
function Common:GetDebugName() return st(self).name or ("<unnamed " .. st(self).type .. ">") end
function Common:GetObjectType() return st(self).type end
function Common:IsObjectType(t)
    local s = st(self)
    if s.type == t then return true end
    local isa = IS_A[s.type]
    if isa then return isa[t] == true end
    return t == "Frame" and s.isFrame == true
end
function Common:IsForbidden() return false end
function Common:GetParent() return st(self).parent end
function Common:SetParent(parent)
    if type(parent) == "string" then parent = _G[parent] end
    local s = st(self)
    if s.parent and S[s.parent] then
        local list = s.isFrame and S[s.parent].children or S[s.parent].regions
        for i = #list, 1, -1 do
            if list[i] == self then table.remove(list, i) end
        end
    end
    s.parent = parent
    if parent and S[parent] then
        local list = s.isFrame and S[parent].children or S[parent].regions
        list[#list + 1] = self
    end
end
function Common:Show() local s = st(self); if not s.shown then s.shown = true; fireScript(self, "OnShow") end end
function Common:Hide() local s = st(self); if s.shown then s.shown = false; fireScript(self, "OnHide") end end
function Common:SetShown(v) if v then self:Show() else self:Hide() end end
function Common:IsShown() return st(self).shown end
function Common:IsVisible()
    local obj = self
    while obj do
        local s = S[obj]
        if not s or not s.shown then return false end
        obj = s.parent
    end
    return true
end
function Common:SetAlpha(a) st(self).alpha = a end
function Common:GetAlpha() return st(self).alpha end
function Common:GetEffectiveAlpha() return st(self).alpha end

local function normalizePoint(self, point, relativeTo, relativePoint, x, y)
    if type(relativeTo) == "number" then
        -- SetPoint(point, x, y)
        relativeTo, relativePoint, x, y = nil, nil, relativeTo, relativePoint
    end
    if type(relativeTo) == "string" then relativeTo = _G[relativeTo] end
    if relativeTo == nil then relativeTo = st(self).parent end
    relativePoint = relativePoint or point
    return point, relativeTo, relativePoint, x or 0, y or 0
end

function Common:SetPoint(point, relativeTo, relativePoint, x, y)
    if type(point) ~= "string" then error("SetPoint: point must be a string", 2) end
    local p, r, rp, px, py = normalizePoint(self, point, relativeTo, relativePoint, x, y)
    local points = st(self).points
    for i, entry in ipairs(points) do
        if entry[1] == p then
            points[i] = { p, r, rp, px, py }
            return
        end
    end
    points[#points + 1] = { p, r, rp, px, py }
end
function Common:ClearAllPoints() st(self).points = {} end
function Common:GetNumPoints() return #st(self).points end
function Common:GetPoint(i)
    local entry = st(self).points[i or 1]
    if entry then return entry[1], entry[2], entry[3], entry[4], entry[5] end
end
function Common:SetAllPoints(relativeTo)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", 0, 0)
    self:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
end
function Common:SetSize(w, h)
    local s = st(self)
    local changed = s.width ~= w or s.height ~= (h or w)
    s.width, s.height = w, h or w
    if changed then fireScript(self, "OnSizeChanged", s.width, s.height) end
end
function Common:SetWidth(w) self:SetSize(w, st(self).height) end
function Common:SetHeight(h) self:SetSize(st(self).width, h) end
function Common:GetSize() local s = st(self); return s.width, s.height end
function Common:GetWidth() return st(self).width end
function Common:GetHeight() return st(self).height end
function Common:GetLeft() return 0 end
function Common:GetRight() return st(self).width end
function Common:GetTop() return st(self).height end
function Common:GetBottom() return 0 end
function Common:GetCenter() local s = st(self); return s.width / 2, s.height / 2 end
function Common:SetScale(v) st(self).scale = v end
function Common:GetScale() return st(self).scale end
function Common:GetEffectiveScale()
    local scale, obj = 1, self
    while obj and S[obj] do
        scale = scale * (S[obj].scale or 1)
        obj = S[obj].parent
    end
    return scale
end
function Common:SetIgnoreParentScale(v) st(self).ignoreParentScale = v and true or false end
function Common:IsIgnoringParentScale() return st(self).ignoreParentScale end
function Common:SetIgnoreParentAlpha(v) st(self).ignoreParentAlpha = v and true or false end

-- Frame methods
local Frame = setmetatable({}, { __index = Common })

function Frame:GetChildren() return unpack(st(self).children) end
function Frame:GetNumChildren() return #st(self).children end
function Frame:GetRegions() return unpack(st(self).regions) end
function Frame:GetNumRegions() return #st(self).regions end

function Frame:SetFrameStrata(strata)
    local s = st(self)
    if s.fixedStrata then return end
    s.strata = strata
end
function Frame:GetFrameStrata() return st(self).strata end
function Frame:SetFrameLevel(level)
    local s = st(self)
    if s.fixedLevel then return end
    s.level = level
end
function Frame:GetFrameLevel() return st(self).level end
function Frame:SetFixedFrameStrata(v) st(self).fixedStrata = v and true or false end
function Frame:SetFixedFrameLevel(v) st(self).fixedLevel = v and true or false end
function Frame:HasFixedFrameStrata() return st(self).fixedStrata end
function Frame:HasFixedFrameLevel() return st(self).fixedLevel end
function Frame:SetToplevel(v) st(self).toplevel = v end
function Frame:Raise() end
function Frame:Lower() end

function Frame:SetScript(script, fn) st(self).scripts[script] = fn end
function Frame:GetScript(script) return st(self).scripts[script] end
function Frame:HasScript() return true end
function Frame:HookScript(script, fn)
    local s = st(self)
    local old = s.scripts[script]
    if old then
        s.scripts[script] = function(...)
            old(...)
            fn(...)
        end
    else
        s.scripts[script] = fn
    end
end

function Frame:RegisterEvent(event)
    local s = st(self)
    if s.events[event] then return end
    s.events[event] = true
    local list = STUB.eventFrames[event]
    if not list then
        list = {}
        STUB.eventFrames[event] = list
    end
    list[#list + 1] = self
end
Frame.RegisterUnitEvent = function(self, event) return Frame.RegisterEvent(self, event) end
function Frame:UnregisterEvent(event)
    local s = st(self)
    if not s.events[event] then return end
    s.events[event] = nil
    local list = STUB.eventFrames[event] or {}
    for i = #list, 1, -1 do
        if list[i] == self then table.remove(list, i) end
    end
end
function Frame:UnregisterAllEvents()
    for event in pairs(st(self).events) do self:UnregisterEvent(event) end
end
function Frame:IsEventRegistered(event) return st(self).events[event] == true end

function Frame:EnableMouse(v) st(self).mouse = v and true or false end
function Frame:IsMouseEnabled() return st(self).mouse end
function Frame:EnableMouseWheel(v) st(self).mouseWheel = v and true or false end
function Frame:SetMouseClickEnabled(v) st(self).mouseClick = v end
function Frame:SetMouseMotionEnabled(v) st(self).mouseMotion = v end
function Frame:SetMovable(v) st(self).movable = v and true or false end
function Frame:IsMovable() return st(self).movable end
function Frame:SetResizable(v) st(self).resizable = v end
function Frame:SetClampedToScreen(v) st(self).clamped = v and true or false end
function Frame:IsClampedToScreen() return st(self).clamped end
function Frame:SetClampRectInsets() end
function Frame:SetUserPlaced(v) st(self).userPlaced = v end
function Frame:IsUserPlaced() return st(self).userPlaced end
function Frame:RegisterForDrag(...) st(self).dragButtons = { ... } end
-- StartMoving/StopMovingOrSizing: the client moves the frame with the cursor and, at the end,
-- anchors it to UIParent at the new place (SetMoveTarget gives that place in tests) and marks it
-- as placed by the user.
function Frame:StartMoving()
    local s = st(self)
    if not s.movable then error("StartMoving: frame is not movable", 2) end
    s.moving = true
    STUB.calls.StartMoving = (STUB.calls.StartMoving or 0) + 1
end
function Frame:StopMovingOrSizing()
    local s = st(self)
    STUB.calls.StopMovingOrSizing = (STUB.calls.StopMovingOrSizing or 0) + 1
    if s.moving and s.moveTarget then
        local t = s.moveTarget
        s.points = { { t[1], UIParent, t[2], t[3], t[4] } }
        s.userPlaced = true
    end
    s.moving = false
end
function Frame:IsMoving() return st(self).moving == true end
function Frame:SetHitRectInsets(...) st(self).hitRectInsets = { ... } end
function Frame:IsMouseOver() return st(self).mouseOver == true end
function Frame:SetID(id) st(self).id = id end
function Frame:GetID() return st(self).id or 0 end
function Frame:SetAttribute(k, v) st(self).attributes[k] = v end
function Frame:GetAttribute(k) return st(self).attributes[k] end

function Frame:CreateTexture(name, layer, template, sublevel)
    return CreateRegion("Texture", name, self, layer, sublevel)
end
function Frame:CreateMaskTexture(name, layer)
    return CreateRegion("MaskTexture", name, self, layer)
end
function Frame:CreateFontString(name, layer, template)
    local fs = CreateRegion("FontString", name, self, layer)
    S[fs].fontObject = template
    return fs
end
-- Animation groups: Play/Stop/IsPlaying, the looping type and the animations with the values set
-- on them (group.animations[i].calls.SetFromAlpha = { 0.35 } and so on) for the tests.
function Frame:CreateAnimationGroup()
    local group = { animations = {}, parent = self }
    local playing = false
    function group:Play() playing = true end
    function group:Stop() playing = false end
    function group:IsPlaying() return playing end
    function group:SetLooping(looping) group.looping = looping end
    function group:GetLooping() return group.looping or "NONE" end
    function group:SetScript() end
    function group:SetToFinalAlpha(v) group.toFinalAlpha = v end
    function group:CreateAnimation(animType)
        local anim = { type = animType, calls = {} }
        setmetatable(anim, { __index = function(_, key)
            return function(_, ...) anim.calls[key] = { ... } end
        end })
        group.animations[#group.animations + 1] = anim
        return anim
    end
    return group
end

-- Button methods
local Button = setmetatable({}, { __index = Frame })
function Button:Click(button) fireScript(self, "OnClick", button or "LeftButton", false) end
function Button:Enable() st(self).enabled = true end
function Button:Disable() st(self).enabled = false end
function Button:SetEnabled(v) st(self).enabled = v and true or false end
function Button:IsEnabled() return st(self).enabled ~= false end
function Button:RegisterForClicks(...) st(self).clickButtons = { ... } end
function Button:SetText(text) st(self).text = text end
function Button:GetText() return st(self).text end
local function buttonTexture(key)
    return function(self, texture)
        local s = st(self)
        if type(texture) == "table" then
            s[key] = texture
            return
        end
        if not s[key] then s[key] = self:CreateTexture(nil, "ARTWORK") end
        s[key]:SetTexture(texture)
    end
end
Button.SetNormalTexture = buttonTexture("normalTexture")
Button.SetPushedTexture = buttonTexture("pushedTexture")
Button.SetHighlightTexture = buttonTexture("highlightTexture")
Button.SetDisabledTexture = buttonTexture("disabledTexture")
function Button:GetNormalTexture() return st(self).normalTexture end
function Button:GetPushedTexture() return st(self).pushedTexture end
function Button:GetHighlightTexture() return st(self).highlightTexture end
function Button:GetDisabledTexture() return st(self).disabledTexture end
function Button:SetChecked(v) st(self).checked = v and true or false end
function Button:GetChecked() return st(self).checked end
function Button:SetFontString(fs) st(self).fontString = fs end
function Button:GetFontString() return st(self).fontString end
function Button:SetNormalFontObject() end
function Button:SetHighlightFontObject() end
function Button:SetDisabledFontObject() end

-- GameTooltip methods
local Tooltip = setmetatable({}, { __index = Frame })
function Tooltip:SetOwner(owner, anchor) local s = st(self); s.owner, s.anchor, s.lines = owner, anchor, {} end
function Tooltip:GetOwner() return st(self).owner end
function Tooltip:IsOwned(frame) local s = st(self); return s.shown and s.owner == frame or false end
function Tooltip:ClearLines() st(self).lines = {} end
function Tooltip:AddLine(text) local s = st(self); s.lines = s.lines or {}; s.lines[#s.lines + 1] = text end
function Tooltip:AddDoubleLine(a, b) Tooltip.AddLine(self, tostring(a) .. " " .. tostring(b)) end
function Tooltip:SetText(text) st(self).lines = { text } end
function Tooltip:NumLines() return #(st(self).lines or {}) end
function Tooltip:SetMinimumWidth() end
function Tooltip:SetPadding() end

-- Minimap methods
local MinimapMethods = setmetatable({}, { __index = Frame })
function MinimapMethods:SetMaskTexture(t) st(self).mask = t end
function MinimapMethods:GetZoom() return st(self).zoom or 0 end
function MinimapMethods:SetZoom(z) st(self).zoom = z end
function MinimapMethods:GetZoomLevels() return 5 end

for _, t in ipairs(FRAME_TYPES) do Methods[t] = Frame end
Methods.Button, Methods.CheckButton, Methods.DropdownButton = Button, Button, Button
Methods.GameTooltip = Tooltip
Methods.Minimap = MinimapMethods

-- Texture methods
local Texture = setmetatable({}, { __index = Common })
function Texture:SetTexture(...)
    local s = st(self)
    s.texture = (...)
    s.atlas = nil
    s.setTextureArgs = select("#", ...) -- 0 for SetTexture() without argument
end
function Texture:GetTexture() return st(self).texture end
function Texture:GetTextureFileID()
    local t = st(self).texture
    if type(t) == "number" then return t end
    return STUB.textureFileIDs[t]
end
function Texture:GetTextureFilePath() return st(self).texture end
function Texture:SetColorTexture(r, g, b, a) st(self).colorTexture = { r, g, b, a } end
function Texture:SetAtlas(atlas) local s = st(self); s.atlas = atlas; s.texture = nil end
function Texture:GetAtlas() return st(self).atlas end
function Texture:SetTexCoord(...)
    local n = select("#", ...)
    local s = st(self)
    if n == 4 then
        local l, r, t, b = ...
        s.texCoord = { l, t, l, b, r, t, r, b }
    else
        s.texCoord = { ... }
    end
end
-- A texture marked with MarkSecretTexCoord returns its coordinates as secret values: until the next
-- GetTexCoord call, issecretvalue answers true for every number (Lua cannot tag a single number).
function Texture:GetTexCoord()
    local s = st(self)
    STUB.secretTexCoordPending = s.secretTexCoord == true
    return unpack(s.texCoord)
end
function Texture:SetVertexColor(r, g, b, a) st(self).vertexColor = { r, g, b, a or 1 } end
function Texture:GetVertexColor() return unpack(st(self).vertexColor) end
function Texture:SetDrawLayer(layer, sublevel) local s = st(self); s.layer, s.sublevel = layer, sublevel end
function Texture:GetDrawLayer() local s = st(self); return s.layer, s.sublevel end
function Texture:SetMask(mask) st(self).mask = mask end
function Texture:GetMask() return st(self).mask end
-- Masks: a list per texture (AddMaskTexture appends, RemoveMaskTexture removes that mask).
function Texture:AddMaskTexture(mask)
    local s = st(self)
    s.masks = s.masks or {}
    for _, m in ipairs(s.masks) do if m == mask then return end end
    s.masks[#s.masks + 1] = mask
    s.maskTexture = mask
end
function Texture:RemoveMaskTexture(mask)
    local s = st(self)
    s.masks = s.masks or {}
    for i = #s.masks, 1, -1 do
        if s.masks[i] == mask then table.remove(s.masks, i) end
    end
    s.maskTexture = s.masks[#s.masks]
    STUB.calls.RemoveMaskTexture = (STUB.calls.RemoveMaskTexture or 0) + 1
end
function Texture:GetNumMaskTextures() return #(st(self).masks or {}) end
function Texture:GetMaskTexture(i) return (st(self).masks or {})[i] end
function Texture:SetDesaturated(v) st(self).desaturated = v end
function Texture:IsDesaturated() return st(self).desaturated end
function Texture:SetBlendMode(mode) st(self).blendMode = mode end
function Texture:SetHorizTile() end
function Texture:SetVertTile() end
function Texture:SetSnapToPixelGrid() end
function Texture:SetTexelSnappingBias() end
function Texture:SetRotation(r) st(self).rotation = r end
Methods.Texture = Texture
Methods.MaskTexture = Texture

-- FontString methods
local FontString = setmetatable({}, { __index = Common })
function FontString:SetText(text) st(self).text = text end
function FontString:GetText() return st(self).text end
function FontString:SetFormattedText(fmt, ...) st(self).text = string.format(fmt, ...) end
function FontString:SetFont(font, size, flags) local s = st(self); s.font = { font, size, flags }; return true end
function FontString:GetFont() local f = st(self).font; if f then return f[1], f[2], f[3] end end
function FontString:SetFontObject(obj) st(self).fontObject = obj end
function FontString:GetFontObject() return st(self).fontObject end
function FontString:SetTextColor(r, g, b, a) st(self).textColor = { r, g, b, a or 1 } end
function FontString:GetTextColor() return unpack(st(self).textColor or { 1, 1, 1, 1 }) end
function FontString:SetJustifyH(v) st(self).justifyH = v end
function FontString:SetJustifyV(v) st(self).justifyV = v end
function FontString:SetWordWrap(v) st(self).wordWrap = v end
function FontString:SetNonSpaceWrap() end
function FontString:SetMaxLines() end
function FontString:SetShadowColor() end
function FontString:SetShadowOffset() end
function FontString:SetDrawLayer(layer) st(self).layer = layer end
function FontString:GetStringWidth() return #(st(self).text or "") * 6 end
function FontString:GetStringHeight() return 12 end
function FontString:SetVertexColor() end
Methods.FontString = FontString

local function newState(objType, name, parent, isFrame)
    return {
        type = objType, name = name, parent = nil, shown = true, alpha = 1, scale = 1,
        points = {}, width = 0, height = 0, scripts = {}, events = {}, attributes = {},
        children = {}, regions = {}, isFrame = isFrame, strata = "MEDIUM", level = 0,
        texCoord = { 0, 0, 0, 1, 1, 0, 1, 1 }, vertexColor = { 1, 1, 1, 1 },
    }
end

function CreateRegion(objType, name, parent, layer, sublevel)
    local methods = Methods[objType] or Texture
    local obj = setmetatable({}, { __index = methods })
    name = resolveName(name, parent)
    local s = newState(objType, name, parent, false)
    s.layer, s.sublevel = layer or "ARTWORK", sublevel
    S[obj] = s
    if parent then obj:SetParent(parent) end
    if name then _G[name] = obj end
    STUB.regions[#STUB.regions + 1] = obj
    return obj
end

--------------------------------------------------------------------------------
-- Mixins and backdrops
--------------------------------------------------------------------------------

local function installMixins()
    function Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            for k, v in pairs(mixin) do object[k] = v end
        end
        return object
    end

    function CreateFromMixins(...)
        return Mixin({}, ...)
    end

    function CreateAndInitFromMixin(mixin, ...)
        local object = CreateFromMixins(mixin)
        if object.Init then object:Init(...) end
        return object
    end

    BackdropTemplateMixin = {}
    function BackdropTemplateMixin:OnBackdropLoaded() end
    function BackdropTemplateMixin:OnBackdropSizeChanged() end
    function BackdropTemplateMixin:ApplyBackdrop() end
    function BackdropTemplateMixin:ClearBackdrop() self.backdropInfo = nil end
    function BackdropTemplateMixin:SetBackdrop(info)
        self.backdropInfo = info
        STUB.calls.SetBackdrop = (STUB.calls.SetBackdrop or 0) + 1
    end
    function BackdropTemplateMixin:GetBackdrop() return self.backdropInfo end
    function BackdropTemplateMixin:SetBackdropColor(r, g, b, a) self.backdropColorValues = { r, g, b, a or 1 } end
    function BackdropTemplateMixin:GetBackdropColor()
        local c = self.backdropColorValues
        if c then return c[1], c[2], c[3], c[4] end
    end
    function BackdropTemplateMixin:SetBackdropBorderColor(r, g, b, a) self.backdropBorderColorValues = { r, g, b, a or 1 } end
    function BackdropTemplateMixin:GetBackdropBorderColor()
        local c = self.backdropBorderColorValues
        if c then return c[1], c[2], c[3], c[4] end
    end
end

--------------------------------------------------------------------------------
-- CreateFrame and the frames of the default UI
--------------------------------------------------------------------------------

local function installElvUIFrameAPI(methods)
    -- What ElvUI adds to the metatables of all frame types (only the parts the addon calls).
    methods.SetTemplate = function(self, template, glossTex)
        STUB.calls.ElvUISetTemplate = (STUB.calls.ElvUISetTemplate or 0) + 1
        st(self).elvTemplate = { template, glossTex }
    end
    methods.CreateShadow = function(self)
        STUB.calls.ElvUICreateShadow = (STUB.calls.ElvUICreateShadow or 0) + 1
        st(self).shadow = true
    end
end

local function removeElvUIFrameAPI(methods)
    methods.SetTemplate = nil
    methods.CreateShadow = nil
end

function CreateFrame(objType, name, parent, template, id)
    if type(objType) ~= "string" or not Methods[objType] or objType == "Texture" or objType == "FontString" then
        error("CreateFrame: unknown frame type " .. tostring(objType), 2)
    end
    if type(parent) == "string" then parent = _G[parent] end
    name = resolveName(name, parent)
    local obj = setmetatable({}, { __index = Methods[objType] })
    local s = newState(objType, name, parent, true)
    s.template = template
    S[obj] = s
    if parent then
        obj:SetParent(parent)
        s.strata = S[parent] and S[parent].strata or s.strata
        s.level = (S[parent] and S[parent].level or 0) + 1
    end
    if name then _G[name] = obj end
    if id then s.id = id end
    if type(template) == "string" and template:find("BackdropTemplate", 1, true) then
        Mixin(obj, BackdropTemplateMixin)
    end
    STUB.frames[#STUB.frames + 1] = obj
    return obj
end

-- State of a stub object for assertions in tests
function StubState(obj) return S[obj] end

local function installDefaultUI(config)
    UIParent = CreateFrame("Frame", "UIParent")
    UIParent:SetSize(1920, 1080)
    S[UIParent].strata = "MEDIUM"
    WorldFrame = CreateFrame("Frame", "WorldFrame")

    DEFAULT_CHAT_FRAME = CreateFrame("MessageFrame", "ChatFrame1", UIParent)
    function DEFAULT_CHAT_FRAME:AddMessage(text, r, g, b)
        STUB.chat[#STUB.chat + 1] = tostring(text)
    end
    SELECTED_CHAT_FRAME = DEFAULT_CHAT_FRAME

    GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
    GameTooltip:Hide()

    -- Minimap of WoW Forever (Blizzard_Minimap, Mainline files with the Camelot overrides)
    MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
    MinimapCluster:SetFrameStrata("LOW")
    MinimapCluster.ZoneTextButton = CreateFrame("Button", nil, MinimapCluster)
    MinimapCluster.Tracking = CreateFrame("Frame", nil, MinimapCluster)
    MinimapCluster.Tracking.Background = MinimapCluster.Tracking:CreateTexture(nil, "BACKGROUND")
    MinimapCluster.Tracking.Button = CreateFrame("DropdownButton", nil, MinimapCluster.Tracking)
    MinimapCluster.IndicatorFrame = CreateFrame("Frame", nil, MinimapCluster)
    MinimapCluster.IndicatorFrame.MailFrame = CreateFrame("Frame", nil, MinimapCluster.IndicatorFrame)
    MinimapCluster.IndicatorFrame.MailFrame:Hide()
    MinimapCluster.MinimapContainer = CreateFrame("Frame", nil, MinimapCluster)
    Minimap = CreateFrame("Minimap", "Minimap", MinimapCluster.MinimapContainer)
    Minimap:SetSize(198, 198)
    -- children in the order of Mainline/Minimap.xml: ZoomHitArea, ZoomIn, ZoomOut, MinimapBackdrop
    Minimap.ZoomHitArea = CreateFrame("Frame", nil, Minimap)
    Minimap.ZoomIn = CreateFrame("Button", nil, Minimap)
    Minimap.ZoomIn:Hide()
    Minimap.ZoomOut = CreateFrame("Button", nil, Minimap)
    Minimap.ZoomOut:Hide()
    MinimapBackdrop = CreateFrame("Frame", "MinimapBackdrop", Minimap)

    local missing = config.missing or {}
    local isForever = WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
    local isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

    -- Tracking: in WoW Forever the button's mixin replaces Show(shown) with
    -- MinimapCluster.Tracking:SetShown(shown) and moves the indicator frame
    -- (Blizzard_Minimap/Mainline/Minimap.lua MiniMapTrackingButtonMixin:Show); the Retail stubs keep
    -- the plain Show of the widget.
    if missing.Tracking then
        MinimapCluster.Tracking = nil
    elseif isForever then
        MinimapCluster.Tracking.Background:SetAtlas("ui-hud-minimap-button")
        MinimapCluster.Tracking.Button.Show = function(self, ...)
            local shown = ...
            STUB.calls.TrackingButtonShow = STUB.calls.TrackingButtonShow or {}
            table.insert(STUB.calls.TrackingButtonShow, { n = select("#", ...), shown = shown })
            MinimapCluster.Tracking:SetShown(shown)
            STUB.calls.IndicatorFrameUpdatePosition = (STUB.calls.IndicatorFrameUpdatePosition or 0) + 1
        end
    end
    if MinimapCluster.Tracking then
        local button = MinimapCluster.Tracking.Button
        button.log = {}
        button:SetScript("OnMouseDown", function(self) self.log[#self.log + 1] = "OnMouseDown" end)
        button:SetScript("OnMouseUp", function(self) self.log[#self.log + 1] = "OnMouseUp" end)
        button:SetScript("OnEnter", function(self) self.log[#self.log + 1] = "OnEnter" end)
        button:SetScript("OnLeave", function(self) self.log[#self.log + 1] = "OnLeave" end)
    end

    -- Calendar button, one version per client:
    --   Forever (Camelot/GameTimeFrameTemplate.xml, Camelot/GameTimeFrame.lua): StateTexture and
    --     AddTexture with the atlas ui-hud-minimap-calendar-button, no global GameTimeTexture (reading
    --     that global raises an error and is counted in STUB.calls.GameTimeTextureAccess); on every
    --     button state change Blizzard sets the atlas of StateTexture again and the alpha of
    --     AddTexture (OnButtonStateChanged, played here by OnEnter/OnLeave);
    --   Classic: the global texture GameTimeTexture in the button;
    --   Retail: the button only (the addon does not handle it there).
    GameTimeFrame, GameTimeTexture, QueueStatusButton = nil, nil, nil -- globals of the stub file itself
    if not missing.GameTimeFrame then
        GameTimeFrame = CreateFrame("Button", "GameTimeFrame", MinimapCluster)
        GameTimeFrame.log = {}
        GameTimeFrame:SetScript("OnClick", function(self) self.log[#self.log + 1] = "OnClick" end)
        if isForever then
            GameTimeFrame.StateTexture = GameTimeFrame:CreateTexture(nil, "ARTWORK")
            GameTimeFrame.StateTexture:SetAtlas("ui-hud-minimap-calendar-button")
            GameTimeFrame.AddTexture = GameTimeFrame:CreateTexture(nil, "ARTWORK")
            GameTimeFrame.AddTexture:SetAtlas("ui-hud-minimap-calendar-button")
            GameTimeFrame.AddTexture:Hide()
            GameTimeFrame.AddTexture:SetAlpha(0)
            local function onButtonStateChanged(self, over)
                self.StateTexture:SetAtlas("ui-hud-minimap-calendar-button")
                local addAlpha = over and 0.1 or 0
                self.AddTexture:SetShown(addAlpha > 0)
                self.AddTexture:SetAlpha(addAlpha)
            end
            GameTimeFrame:SetScript("OnEnter", function(self) self.log[#self.log + 1] = "OnEnter"; onButtonStateChanged(self, true) end)
            GameTimeFrame:SetScript("OnLeave", function(self) self.log[#self.log + 1] = "OnLeave"; onButtonStateChanged(self, false) end)
        elseif not isRetail then
            GameTimeTexture = GameTimeFrame:CreateTexture("GameTimeTexture", "BACKGROUND")
            GameTimeTexture:SetTexture("Interface\\Calendar\\UI-Calendar-Button")
        end
    end

    -- Queue button (Blizzard_QueueStatusFrame/Mainline/QueueStatusFrame.xml:136): parent UIParent,
    -- hidden until the player queues.
    if not missing.QueueStatusButton then
        QueueStatusButton = CreateFrame("Button", "QueueStatusButton", UIParent)
        QueueStatusButton:SetSize(45, 45)
        QueueStatusButton:SetPoint("CENTER", Minimap, "CENTER", -68, -68)
        QueueStatusButton:Hide()
        QueueStatusButton.log = {}
        function QueueStatusButton:OnLeave() self.log[#self.log + 1] = "OnLeave" end
        QueueStatusButton:SetScript("OnShow", function(self) self.log[#self.log + 1] = "OnShow" end)
        QueueStatusButton:SetScript("OnHide", function(self) self.log[#self.log + 1] = "OnHide" end)
        QueueStatusButton:SetScript("OnClick", function(self) self.log[#self.log + 1] = "OnClick" end)
    end

    AddonCompartmentFrame = CreateFrame("Button", "AddonCompartmentFrame", MinimapCluster)

    -- Reading the global GameTimeTexture in WoW Forever is an error (the frame does not exist there).
    setmetatable(_G, nil)
    if isForever then
        setmetatable(_G, {
            __index = function(_, key)
                if key == "GameTimeTexture" then
                    STUB.calls.GameTimeTextureAccess = (STUB.calls.GameTimeTextureAccess or 0) + 1
                    error("GameTimeTexture does not exist in WoW Forever", 2)
                end
            end,
        })
    end

    -- Retail group finder (absent in WoW Forever)
    if config.retailGlobals then
        PVEFrame = CreateFrame("Frame", "PVEFrame", UIParent)
        PVEFrame:Hide()
        function ShowUIPanel(frame)
            STUB.calls.ShowUIPanel = STUB.calls.ShowUIPanel or {}
            table.insert(STUB.calls.ShowUIPanel, frame)
            frame:Show()
        end
        function HideUIPanel(frame)
            STUB.calls.HideUIPanel = STUB.calls.HideUIPanel or {}
            table.insert(STUB.calls.HideUIPanel, frame)
            frame:Hide()
        end
        function GroupFinderFrame_ShowGroupFrame()
            STUB.calls.GroupFinderFrame_ShowGroupFrame = (STUB.calls.GroupFinderFrame_ShowGroupFrame or 0) + 1
        end
    end
end

--------------------------------------------------------------------------------
-- Events, timers, client state
--------------------------------------------------------------------------------

function FireEvent(event, ...)
    local list = STUB.eventFrames[event]
    if not list then return 0 end
    local snapshot = {}
    for i, f in ipairs(list) do snapshot[i] = f end
    for _, f in ipairs(snapshot) do
        if S[f] and S[f].events[event] then
            fireScript(f, "OnEvent", event, ...)
        end
    end
    return #snapshot
end

function RunOnUpdate(elapsed)
    for _, f in ipairs(STUB.frames) do
        fireScript(f, "OnUpdate", elapsed or 0)
    end
end

local function addTimer(delay, fn, handle)
    STUB.timerSeq = STUB.timerSeq + 1
    local timer = { due = STUB.time + math.max(delay or 0, 0), fn = fn, seq = STUB.timerSeq, handle = handle }
    STUB.timers[#STUB.timers + 1] = timer
    return timer
end

-- Moves the clock forward and runs every timer that is due, in order of due time.
function AdvanceTime(dt)
    local target = STUB.time + (dt or 0)
    while true do
        local bestIndex, best
        for i, timer in ipairs(STUB.timers) do
            if timer.due <= target and (not best or timer.due < best.due or (timer.due == best.due and timer.seq < best.seq)) then
                bestIndex, best = i, timer
            end
        end
        if not best then break end
        table.remove(STUB.timers, bestIndex)
        if best.due > STUB.time then STUB.time = best.due end
        if not (best.handle and best.handle._cancelled) then best.fn(best.handle) end
    end
    STUB.time = target
end

function PendingTimers() return #STUB.timers end

local function installTimers()
    GetTime = function() return STUB.time end
    GetTimePreciseSec = GetTime
    GetServerTime = function() return 1700000000 + math.floor(STUB.time) end

    C_Timer = {}
    function C_Timer.After(delay, fn)
        if type(fn) ~= "function" then error("C_Timer.After: callback must be a function", 2) end
        addTimer(delay, function() fn() end)
    end
    local function newHandle(delay, fn, iterations)
        local handle = { _cancelled = false, _remaining = iterations }
        function handle:Cancel() self._cancelled = true end
        function handle:IsCancelled() return self._cancelled end
        local function tick()
            if handle._cancelled then return end
            fn(handle)
            if handle._remaining then
                handle._remaining = handle._remaining - 1
                if handle._remaining <= 0 then
                    handle._cancelled = true
                    return
                end
            end
            if handle._repeat and not handle._cancelled then addTimer(delay, tick, handle) end
        end
        handle._tick = tick
        return handle, tick
    end
    function C_Timer.NewTimer(delay, fn)
        local handle, tick = newHandle(delay, fn, 1)
        addTimer(delay, tick, handle)
        return handle
    end
    function C_Timer.NewTicker(delay, fn, iterations)
        local handle, tick = newHandle(delay, fn, iterations)
        handle._repeat = true
        addTimer(delay, tick, handle)
        return handle
    end
end

local CLASS_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43, "ffc69b6d" }, PALADIN = { 0.96, 0.55, 0.73, "fff48cba" },
    HUNTER = { 0.67, 0.83, 0.45, "ffaad372" }, ROGUE = { 1.00, 0.96, 0.41, "fffff468" },
    PRIEST = { 1.00, 1.00, 1.00, "ffffffff" }, DEATHKNIGHT = { 0.77, 0.12, 0.23, "ffc41e3a" },
    SHAMAN = { 0.00, 0.44, 0.87, "ff0070dd" }, MAGE = { 0.25, 0.78, 0.92, "ff3fc7eb" },
    WARLOCK = { 0.53, 0.53, 0.93, "ff8788ee" }, MONK = { 0.00, 1.00, 0.60, "ff00ff98" },
    DRUID = { 1.00, 0.49, 0.04, "ffff7c0a" }, DEMONHUNTER = { 0.64, 0.19, 0.79, "ffa330c9" },
    EVOKER = { 0.20, 0.58, 0.50, "ff33937f" },
}

local function installClientState(config)
    local player = config.player or {}
    local name = player.name or "Zippy"
    local realm = player.realm or "Forever"
    local class = player.class or "MAGE"
    local race = player.race or "Human"
    local faction = player.faction or "Alliance"

    WOW_PROJECT_MAINLINE = 1
    WOW_PROJECT_CLASSIC = 2
    WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
    WOW_PROJECT_WRATH_CLASSIC = 11
    WOW_PROJECT_CATACLYSM_CLASSIC = 14
    WOW_PROJECT_MISTS_CLASSIC = 19
    WOW_PROJECT_CAMELOT = 18
    WOW_PROJECT_ID = config.projectID or WOW_PROJECT_CAMELOT

    local interface = config.interface or DEFAULT_INTERFACE[WOW_PROJECT_ID] or 11508
    GetBuildInfo = function()
        return "stub", "70755", "Nov 1 2026", interface, "", "", interface
    end

    GetLocale = function() return config.locale or "enUS" end
    UnitName = function(unit) if unit == "player" then return name, nil end return nil end
    UnitNameUnmodified = UnitName
    UnitClass = function(unit) if unit == "player" then return class:sub(1, 1) .. class:sub(2):lower(), class, 8 end end
    UnitRace = function(unit) if unit == "player" then return race, race, 1 end end
    UnitFactionGroup = function(unit) if unit == "player" then return faction, faction end end
    UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
    GetRealmName = function() return realm end
    GetNormalizedRealmName = function() return realm end
    GetCurrentRegion = function() return 3 end
    GetCurrentRegionName = function() return "EU" end
    RegionalUniqueNamesEnabled = nil
    IsLoggedIn = function() return STUB.loggedIn end
    InCombatLockdown = function() return STUB.combat end
    C_PetBattles = { IsInBattle = function() return STUB.petBattle end }
    -- Tracking (MinimapDocumentation.lua: GetNumTrackingTypes, GetTrackingInfo returning a
    -- MinimapScriptTrackingInfo { name, texture, active, type, subType, spellID? }). STUB.tracking
    -- holds the entries; SetTracking(list) replaces them (see below).
    C_Minimap = {
        GetNumTrackingTypes = function() return #STUB.tracking end,
        GetTrackingInfo = function(index)
            local entry = STUB.tracking[index]
            if not entry then return nil end
            local info = {}
            for k, v in pairs(entry) do info[k] = v end
            return info
        end,
        SetTracking = function(index, on)
            if STUB.tracking[index] then STUB.tracking[index].active = on and true or false end
        end,
    }
    -- Spell names (SpellDocumentation: C_Spell.GetSpellName(spellIdentifier) -> cstring, may return
    -- nothing). STUB.spellNames maps spell IDs to names (default: the names of the English client
    -- for the tracking abilities of the tests; config.spellNames replaces the table); an unknown ID
    -- returns nothing. config.noCSpell = true leaves C_Spell out.
    if config.noCSpell then
        C_Spell = nil
    else
        C_Spell = {
            GetSpellName = function(spellID)
                local name = STUB.spellNames[spellID]
                if name ~= nil then return name end
            end,
        }
    end
    UnitIsDeadOrGhost = function(unit) return unit == "player" and STUB.dead == true end
    HasFullControl = function() return STUB.control ~= false end
    HasNewMail = function() return STUB.newMail end
    GetPhysicalScreenSize = function() return 1920, 1080 end
    GetScreenWidth = function() return 1920 end
    GetScreenHeight = function() return 1080 end
    GetCVar = function() return nil end
    GetCVarBool = function() return false end

    RAID_CLASS_COLORS = {}
    for key, c in pairs(CLASS_COLORS) do
        RAID_CLASS_COLORS[key] = { r = c[1], g = c[2], b = c[3], colorStr = c[4] }
    end
    CUSTOM_CLASS_COLORS = nil
    LOCALIZED_CLASS_NAMES_MALE = {}
    LOCALIZED_CLASS_NAMES_FEMALE = {}

    ACCEPT, CANCEL, OKAY, YES, NO, CLOSE = "Accept", "Cancel", "Okay", "Yes", "No", "Close"
    NORMAL_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE = "|cffffd200", "|r" -- used by AceDBOptions (current profile)
    NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
    HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
    GameFontNormal, GameFontHighlight, GameFontHighlightSmall, GameFontNormalSmall = {}, {}, {}, {}
    GameFontDisable, GameFontNormalLarge, GameFontHighlightLarge, ChatFontNormal = {}, {}, {}, {}
end

local function installAddOns(config)
    local addons = {
        [ADDON_NAME or "SquareMinimapButtons"] = { enabled = true, loaded = true, metadata = ADDON_TOC or {} },
    }
    if config.pa then
        addons.ProjectAzilroka = { enabled = true, loaded = true, metadata = { Title = "ProjectAzilroka", Version = "stub" } }
    end
    if config.elvui then
        addons.ElvUI = { enabled = true, loaded = true, metadata = { Title = "ElvUI", Version = "stub" } }
    end
    if config.tukui then
        addons.Tukui = { enabled = true, loaded = true, metadata = {} }
    end
    if config.addonskins then
        addons.AddOnSkins = { enabled = true, loaded = true, metadata = {} }
    end
    STUB.addons = addons

    C_AddOns = {}
    function C_AddOns.GetAddOnEnableState(addon, character)
        local a = addons[addon]
        if a and a.enabled then return 2 end
        return 0
    end
    function C_AddOns.IsAddOnLoaded(addon)
        local a = addons[addon]
        local loaded = a and a.loaded or false
        return loaded, loaded
    end
    function C_AddOns.GetAddOnMetadata(addon, field)
        local a = addons[addon]
        return a and a.metadata and a.metadata[field] or nil
    end
    function C_AddOns.GetNumAddOns() return 0 end
    function C_AddOns.LoadAddOn(addon) return addons[addon] ~= nil, nil end

    -- ProjectAzilroka: _G.ProjectAzilroka is its engine table, [1] the addon object; its module
    -- sets the global SquareMinimapButtons before this addon loads (folder order).
    if config.pa then
        local PA = { Title = "ProjectAzilroka" }
        local module = { name = "ProjectAzilroka_SquareMinimapButtons", isPA = true }
        PA.SMB = module
        STUB.paDB = { SquareMinimapButtons = { Enable = config.pa.enabled ~= false } }
        if not config.pa.dbAtLogin and not config.pa.noDB then PA.db = STUB.paDB end
        ProjectAzilroka = { PA, {}, {} }
        SquareMinimapButtons = module
        STUB.paModule = module
    end

    if config.elvui then
        local E = { db = { general = { cropIcon = config.elvui.cropIcon } } }
        -- E:CreateMover(parent, name, textString, overlay, snapOffset, postdrag, types, ...)
        -- (ElvUI/Game/Shared/General/Movers.lua); ElvUI starts the mover at the parent's point.
        function E:CreateMover(parent, ...)
            STUB.calls.ElvUICreateMover = { parent, ... }
            STUB.calls.ElvUICreateMover.n = select("#", ...) + 1
            STUB.calls.ElvUICreateMover.originPoint = { parent:GetPoint() }
        end
        ElvUI = { E, {}, {}, {} }
        local elvOptions = config.elvui.options
        if elvOptions then
            if type(elvOptions) ~= "table" then elvOptions = {} end
            E.Options = { type = "group", name = "ElvUI", args = {} }
            STUB.elvuiPlugins = {}
            STUB.elvuiOptionsLoaded = elvOptions.loaded == true
            -- LibElvUIPlugin-1.0 RegisterPlugin(name, callback, isLib, version): only for a loaded
            -- addon; the callback runs (in pcall) when ElvUI_Options is loaded, at once if it is
            if not elvOptions.noEP then
                E.Libs = {
                    EP = {
                        plugins = {},
                        RegisterPlugin = function(self, name, callback, isLib, version)
                            if not C_AddOns.IsAddOnLoaded(name) then return end
                            local plugin = { name = name, callback = callback, isLib = isLib, version = version }
                            self.plugins[name] = plugin
                            STUB.elvuiPlugins[#STUB.elvuiPlugins + 1] = plugin
                            if STUB.elvuiOptionsLoaded and callback then
                                local ok, err = pcall(callback)
                                if not ok then STUB.errors[#STUB.errors + 1] = tostring(err) end
                            end
                            return plugin
                        end,
                    },
                }
            end
            function STUB.FireElvUIOptions()
                STUB.elvuiOptionsLoaded = true
                for _, plugin in ipairs(STUB.elvuiPlugins) do
                    if plugin.callback then
                        local ok, err = pcall(plugin.callback)
                        if not ok then STUB.errors[#STUB.errors + 1] = tostring(err) end
                    end
                end
            end
        end
        if config.elvui.queueStatus then
            -- ElvUI's queue module (Modules/Misc/QueueStatus.lua LoadQueueStatus): holder of the
            -- QueueStatusButton
            ElvUIQueueStatus = CreateFrame("Frame", "ElvUIQueueStatus", UIParent)
        end
        if config.elvui.frameAPI then
            for _, t in ipairs(FRAME_TYPES) do installElvUIFrameAPI(Methods[t]) end
        end
    end
    if config.tukui then
        Tukui = { { Movers = { RegisterFrame = function(_, frame) STUB.calls.TukuiRegisterFrame = frame end } } }
    end
    if config.addonskins then
        local AS = {}
        function AS:SetTemplate(frame) STUB.calls.AddOnSkinsSetTemplate = (STUB.calls.AddOnSkinsSetTemplate or 0) + 1 end
        function AS:CreateShadow(frame) STUB.calls.AddOnSkinsCreateShadow = (STUB.calls.AddOnSkinsCreateShadow or 0) + 1 end
        AddOnSkins = { AS }
    end
end

local function installUIFunctions()
    function hooksecurefunc(tbl, name, fn)
        if type(tbl) == "string" then
            tbl, name, fn = _G, tbl, name
        end
        local old = tbl[name]
        if type(old) ~= "function" then error("hooksecurefunc: " .. tostring(name) .. " is not a function", 2) end
        tbl[name] = function(...)
            local r = { old(...) }
            fn(...)
            return unpack(r)
        end
    end

    local errorHandler
    local function defaultErrorHandler(msg)
        STUB.errors[#STUB.errors + 1] = tostring(msg)
        print("        [error handler] " .. tostring(msg))
        return msg
    end
    errorHandler = defaultErrorHandler
    function geterrorhandler() return errorHandler end
    function seterrorhandler(fn) errorHandler = fn or defaultErrorHandler end

    function securecallfunction(fn, ...)
        local results = { xpcall(fn, function(e) return errorHandler(e) end, ...) }
        if results[1] then return unpack(results, 2) end
    end
    securecall = function(fn, ...)
        if type(fn) == "string" then fn = _G[fn] end
        return securecallfunction(fn, ...)
    end
    issecretvalue = function(value)
        return STUB.secretTexCoordPending == true and type(value) == "number"
    end
    if STUB.config.noSecretAPI then issecretvalue = nil end
    canaccessvalue = function() return true end
    issecure = function() return false end
    issecurevariable = function() return false, nil end
    forceinsecure = function() end
    debugstack = function() return "" end
    debugprofilestop = function() return STUB.time * 1000 end

    StaticPopupDialogs = {}
    function StaticPopup_Show(which, text1, text2, data)
        STUB.popups[#STUB.popups + 1] = which
        local info = StaticPopupDialogs[which]
        if not info then return nil end
        return { which = which, data = data }
    end
    function StaticPopup_Hide(which) STUB.popupsHidden[#STUB.popupsHidden + 1] = which end
    function ReloadUI() STUB.reloads = STUB.reloads + 1 end
    C_UI = { Reload = ReloadUI }

    SlashCmdList = {}
    hash_SlashCmdList = {}
    function RunSlash(command, input)
        -- finds the SlashCmdList entry whose SLASH_<KEY><n> global matches /command
        for key, fn in pairs(SlashCmdList) do
            local i = 1
            while _G["SLASH_" .. key .. i] do
                if _G["SLASH_" .. key .. i] == command then
                    fn(input or "", DEFAULT_CHAT_FRAME)
                    return true
                end
                i = i + 1
            end
        end
        return false
    end

    -- State drivers: the current condition per frame and state in STUB.stateDrivers, every call in
    -- STUB.stateDriverLog. SetStateDriverHidden(frame, true|false) plays the secure state driver
    -- manager: while a visibility driver is registered it hides or shows the frame, as when the
    -- macro condition changes (for example [petbattle] at the start and end of a pet battle).
    function RegisterStateDriver(frame, state, condition)
        STUB.stateDrivers[frame] = STUB.stateDrivers[frame] or {}
        STUB.stateDrivers[frame][state] = condition
        STUB.stateDriverLog[#STUB.stateDriverLog + 1] = { action = "register", frame = frame, state = state, condition = condition }
    end
    function UnregisterStateDriver(frame, state)
        if STUB.stateDrivers[frame] then STUB.stateDrivers[frame][state] = nil end
        STUB.stateDriverLog[#STUB.stateDriverLog + 1] = { action = "unregister", frame = frame, state = state }
    end
    function SetStateDriverHidden(frame, hidden)
        local drivers = STUB.stateDrivers[frame]
        if not (drivers and drivers.visibility) then return false end
        if hidden then frame:Hide() else frame:Show() end
        return true
    end
    function RegisterAttributeDriver(frame, attribute, condition) RegisterStateDriver(frame, attribute, condition) end
    function UnregisterAttributeDriver(frame, attribute) UnregisterStateDriver(frame, attribute) end

    -- UIFrameFadeIn/Out as in Blizzard_SharedXMLBase/FrameUtil.lua (UIFrameFade): start alpha, then
    -- frame:Show(); the fade itself is skipped, the frame gets the end alpha at once. Every call is
    -- recorded in STUB.fades.
    local function fade(mode, frame, duration, from, to)
        STUB.fades[#STUB.fades + 1] = { frame = frame, mode = mode, duration = duration, from = from, to = to }
        if from == nil then from = mode == "IN" and 0 or 1 end
        if to == nil then to = mode == "IN" and 1 or 0 end
        frame:SetAlpha(from)
        frame:Show()
        frame:SetAlpha(to)
    end
    function UIFrameFadeIn(frame, duration, from, to) fade("IN", frame, duration, from, to) end
    function UIFrameFadeOut(frame, duration, from, to) fade("OUT", frame, duration, from, to) end

    function ToggleGroupFinderFrame() STUB.calls.ToggleGroupFinderFrame = (STUB.calls.ToggleGroupFinderFrame or 0) + 1 end
    -- Blizzard_Minimap/Mainline/Minimap.lua MinimapMailFrameUpdate: fills GameTooltip with the latest
    -- senders and shows it.
    function MinimapMailFrameUpdate()
        STUB.calls.MinimapMailFrameUpdate = (STUB.calls.MinimapMailFrameUpdate or 0) + 1
        GameTooltip:AddLine("Unread mail")
        GameTooltip:Show()
    end
    if (STUB.config.missing or {}).MinimapMailFrameUpdate then MinimapMailFrameUpdate = nil end
    C_Texture = {
        GetAtlasInfo = function(atlas)
            if STUB.config.noAtlasInfo then return nil end
            if atlas == "ui-hud-minimap-calendar-button" then return { width = 23, height = 23 } end
        end,
    }
    function GetMinimapShape() return "SQUARE" end
    function PlaySound() end

    Settings = {}
    function Settings.RegisterCanvasLayoutCategory(frame, name)
        local category = { ID = name, name = name, frame = frame }
        function category:GetID() return self.ID end
        STUB.settings.categories[#STUB.settings.categories + 1] = category
        return category, nil
    end
    function Settings.RegisterCanvasLayoutSubcategory(parent, frame, name)
        local category = Settings.RegisterCanvasLayoutCategory(frame, name)
        category.parent = parent
        return category, nil
    end
    function Settings.RegisterAddOnCategory(category) STUB.settings.registered[#STUB.settings.registered + 1] = category end
    function Settings.GetCategory(id)
        for _, category in ipairs(STUB.settings.categories) do
            if category.ID == id then return category end
        end
    end
    function Settings.OpenToCategory(id) STUB.settings.opened[#STUB.settings.opened + 1] = id; return true end

    Enum = Enum or {}
    Enum.GameRule = Enum.GameRule or { RPRuleset = 1, PvPRuleset = 2, HardcoreRuleset = 3 }
    C_GameRules = { IsGameRuleActive = function() return false end }
end

--------------------------------------------------------------------------------
-- Installation, reset, reload
--------------------------------------------------------------------------------

function InstallStubs(config)
    config = config or {}
    for _, t in ipairs(FRAME_TYPES) do removeElvUIFrameAPI(Methods[t]) end
    STUB = {
        config = config, time = 0, timers = {}, timerSeq = 0, frames = {}, regions = {},
        eventFrames = {}, chat = {}, errors = {}, popups = {}, popupsHidden = {}, reloads = 0,
        stateDrivers = {}, stateDriverLog = {}, fades = {}, calls = {}, settings = { categories = {}, registered = {}, opened = {}, blizOptions = {}, dialogOpened = {}, defaultSize = {} },
        textureFileIDs = {}, loggedIn = config.loggedIn == true, combat = config.combat == true,
        petBattle = config.petBattle == true, newMail = config.newMail == true,
        tracking = config.tracking or {}, dead = config.dead == true, control = config.control ~= false,
        spellNames = config.spellNames or {
            [2383] = "Find Herbs", [2580] = "Find Minerals", [2481] = "Find Treasure",
            [5502] = "Sense Undead", [5500] = "Sense Demons", [1494] = "Track Beasts", [19883] = "Track Humanoids",
        },
    }
    installLuaHelpers()
    installMixins()
    installTimers()
    installClientState(config)
    installUIFunctions()
    installDefaultUI(config)
    installAddOns(config)
    SquareMinimapButtonsDB = config.savedVariables
end

local baseline -- globals that exist before the addon is loaded

-- Called by the runner after _harness.lua, before the first LoadAddon.
function __before_addon_load()
    baseline = {}
    for k in pairs(_G) do baseline[k] = true end
end

function ResetWorld(config)
    for k in pairs(_G) do
        if not baseline[k] then _G[k] = nil end
    end
    InstallStubs(config)
end

-- AceConfigDialog-3.0 is the real library. Its calls are recorded in STUB.settings:
--   blizOptions   { appName, name, parent, path... } per AddToBlizOptions (the real one runs: it
--                 builds an AceGUI BlizOptionsGroup and registers it with the Settings stubs)
--   defaultSize   { appName, width, height } per SetDefaultSize (the real one runs)
--   dialogOpened  { appName, path... } per Open; the real Open builds AceGUI widgets that the stubs
--                 do not draw, so this one only asks the registry for the table as Open does
--                 (GetOptionsTable(appName)("dialog", "AceConfigDialog-3.0"), which validates it)
function InstrumentAceConfigDialog()
    local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
    if not dialog or dialog.__stubbed then return end
    dialog.__stubbed = true
    local addToBlizOptions, setDefaultSize = dialog.AddToBlizOptions, dialog.SetDefaultSize
    function dialog:AddToBlizOptions(appName, name, parent, ...)
        local entry = { appName, name or false, parent or false, ... }
        STUB.settings.blizOptions[#STUB.settings.blizOptions + 1] = entry
        return addToBlizOptions(self, appName, name, parent, ...)
    end
    function dialog:SetDefaultSize(appName, width, height)
        STUB.settings.defaultSize[#STUB.settings.defaultSize + 1] = { appName, width, height }
        return setDefaultSize(self, appName, width, height)
    end
    function dialog:Open(appName, ...)
        STUB.settings.dialogOpened[#STUB.settings.dialogOpened + 1] = { appName, ... }
        local app = LibStub("AceConfigRegistry-3.0"):GetOptionsTable(appName)
        if not app then
            error(("%s isn't registed with AceConfigRegistry, unable to open config"):format(appName), 2)
        end
        return app("dialog", "AceConfigDialog-3.0")
    end
end

-- Fresh client with the given configuration, addon files loaded in TOC order (not logged in yet).
function ReloadAddon(config)
    ResetWorld(config)
    local ns = LoadAddon()
    InstrumentAceConfigDialog()
    return ns
end

-- The addon object as the addon itself sees it.
function GetAddon()
    return LibStub("AceAddon-3.0"):GetAddon("SquareMinimapButtons")
end

-- Client start after the files are loaded: ADDON_LOADED, PLAYER_LOGIN (OnEnable), next frame,
-- PLAYER_ENTERING_WORLD. With config.pa.dbAtLogin ProjectAzilroka sets its profile after this
-- addon's PLAYER_LOGIN handler, as if its handler ran later.
function StartClient()
    FireEvent("ADDON_LOADED", ADDON_NAME or "SquareMinimapButtons")
    STUB.loggedIn = true
    FireEvent("PLAYER_LOGIN")
    local pa = STUB.config.pa
    if pa and pa.dbAtLogin and not pa.noDB and ProjectAzilroka then ProjectAzilroka[1].db = STUB.paDB end
    AdvanceTime(0)
    FireEvent("PLAYER_ENTERING_WORLD", true, false)
end

-- Tracking entries as C_Minimap.GetTrackingInfo returns them. TRACKING_SPELL(name, active, id) is
-- a tracking ability (type "spell"), TRACKING_TOWNSFOLK(name, active) a townsfolk filter of the
-- tracking menu (type "other", no spellID). SetTrackingList replaces the list; fire
-- MINIMAP_UPDATE_TRACKING to tell the addon. TRACKING_NAMED(name, active) is a tracking ability whose
-- entry has no spellID (only its name, type "spell").
function TRACKING_SPELL(name, active, spellID)
    return { name = name, texture = 136025, active = active == true, type = "spell", subType = 0, spellID = spellID }
end
function TRACKING_NAMED(name, active)
    return { name = name, texture = 136025, active = active == true, type = "spell", subType = 0 }
end
function TRACKING_TOWNSFOLK(name, active)
    return { name = name, texture = 136456, active = active == true, type = "other", subType = 1 }
end
function SetTrackingList(list) STUB.tracking = list end
function SetPlayerDead(dead) STUB.dead = dead and true or false end
function SetFullControl(control) STUB.control = control and true or false end

-- New mail arrives or is read: HasNewMail() and the event UPDATE_PENDING_MAIL.
function SetNewMail(hasMail)
    STUB.newMail = hasMail and true or false
    return FireEvent("UPDATE_PENDING_MAIL")
end

-- Moves the cursor drag of a frame to this place (see Frame:StopMovingOrSizing).
function SetMoveTarget(frame, point, relativePoint, x, y)
    st(frame).moveTarget = { point, relativePoint or point, x or 0, y or 0 }
end

-- Combat: InCombatLockdown() and the events PLAYER_REGEN_DISABLED (entering) and
-- PLAYER_REGEN_ENABLED (leaving, fired after the lockdown ends, as in the client).
function SetCombat(inCombat)
    if inCombat then
        STUB.combat = true
        FireEvent("PLAYER_REGEN_DISABLED")
    else
        STUB.combat = false
        FireEvent("PLAYER_REGEN_ENABLED")
    end
end

function ChatContains(text)
    local count = 0
    for _, line in ipairs(STUB.chat) do
        if line:find(text, 1, true) then count = count + 1 end
    end
    return count
end


--------------------------------------------------------------------------------
-- Test buttons on the minimap
--------------------------------------------------------------------------------

-- Marks a texture whose GetTexCoord returns secret values (see Texture:GetTexCoord).
function MarkSecretTexCoord(texture)
    st(texture).secretTexCoord = true
end

-- LibDBIcon-1.0's updateCoord: full coordinates while the mouse is down, else 5 % inset per side.
local function libDBIconUpdateCoord(self)
    local coords = self:GetParent().dataObject.iconCoords or { 0, 1, 0, 1 }
    local deltaX, deltaY = 0, 0
    if not self:GetParent().isMouseDown then
        deltaX = (coords[2] - coords[1]) * 0.05
        deltaY = (coords[4] - coords[3]) * 0.05
    end
    self:SetTexCoord(coords[1] + deltaX, coords[2] - deltaX, coords[3] + deltaY, coords[4] - deltaY)
end

-- A minimap button as LibDBIcon-1.0 builds it (createButton and the Reset* functions of
-- LibDBIcon-1.0.lua): Button "LibDBIcon10_<name>" with parent Minimap, strata MEDIUM and level 8,
-- both fixed, clicks and drag registered, highlight 136477, border 136430 (OVERLAY), background
-- 136467 (BACKGROUND), icon (ARTWORK) with LibDBIcon's coordinates: 5 % inset on each side
-- (updateCoord), OnMouseDown and OnMouseUp that call icon:UpdateCoord(). opts.icon: icon texture (default 134400).
function NewLibDBIconButton(name, opts)
    opts = opts or {}
    local mainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
    button.dataObject = { icon = opts.icon or 134400 }
    button.db = {}
    button:SetFrameStrata("MEDIUM")
    button:SetFixedFrameStrata(true)
    button:SetFrameLevel(8)
    button:SetFixedFrameLevel(true)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture(136477)
    button:SetHighlightTexture(highlight)
    button:SetSize(31, 31)

    local border = button:CreateTexture(nil, "OVERLAY")
    button.border = border
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture(136430)
    border:SetSize(mainline and 50 or 53, mainline and 50 or 53)

    local background = button:CreateTexture(nil, "BACKGROUND")
    button.background = background
    background:SetTexture(136467)
    if mainline then
        background:SetSize(24, 24)
        background:SetPoint("CENTER", 0, 0)
    else
        background:SetSize(20, 20)
        background:SetPoint("TOPLEFT", 7, -5)
    end

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(button.dataObject.icon)
    icon.UpdateCoord = libDBIconUpdateCoord
    icon:UpdateCoord()
    icon:SetSize(mainline and 18 or 17, mainline and 18 or 17)
    if mainline then
        icon:SetPoint("CENTER")
    else
        icon:SetPoint("TOPLEFT", 7, -6)
    end
    button.icon = icon

    button.isMouseDown = false
    button.log = {}
    button:SetScript("OnEnter", function(self) self.log[#self.log + 1] = "OnEnter" end)
    button:SetScript("OnLeave", function(self) self.log[#self.log + 1] = "OnLeave" end)
    button:SetScript("OnClick", function(self) self.log[#self.log + 1] = "OnClick" end)
    button:SetScript("OnDragStart", function(self) self.log[#self.log + 1] = "OnDragStart" end)
    button:SetScript("OnDragStop", function(self) self.log[#self.log + 1] = "OnDragStop" end)
    button:SetScript("OnMouseDown", function(self)
        self.log[#self.log + 1] = "OnMouseDown"
        self.isMouseDown = true
        self.icon:UpdateCoord()
    end)
    button:SetScript("OnMouseUp", function(self)
        self.log[#self.log + 1] = "OnMouseUp"
        self.isMouseDown = false
        self.icon:UpdateCoord()
    end)
    return button
end

-- A named minimap button of an addon that draws its icon with the full texture coordinates
-- (0, 1, 0, 1), for example TomCats ("TomCats-MinimapButton"). opts.parent (default Minimap),
-- opts.icon (default 134400), opts.border: file ID or path of an extra OVERLAY texture.
function NewPlainButton(name, opts)
    opts = opts or {}
    local button = CreateFrame("Button", name, opts.parent or Minimap)
    button:SetSize(31, 31)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(opts.icon or 134400)
    icon:SetAllPoints(button)
    button.icon = icon
    if opts.border then
        button.border = button:CreateTexture(nil, "OVERLAY")
        button.border:SetTexture(opts.border)
    end
    return button
end

-- Map pins on the minimap, one per field that ProjectAzilroka's scan checks. Every pin is a named
-- Button, so that only the pin filter can reject it (the Questie pin by name has the name
-- QuestieFrame<n>).
PIN_KINDS = {
    "HereBeDragons.uiMapID", "HereBeDragons.minimap", "HandyNotes.acquired", "HandyNotes.arrow",
    "Zygor.waypoint", "Zygor.isZygorWaypoint", "GatherMate2.nodeID", "GatherMate2.titleXY",
    "Questie.data", "Questie.name", "TomTom.uid", "TomTom.point",
}

local pinSeq = 0
function NewMinimapPin(kind)
    pinSeq = pinSeq + 1
    local name = "TestPin" .. pinSeq
    if kind == "Questie.name" then name = "QuestieFrame" .. pinSeq end
    local pin = CreateFrame("Button", name, Minimap)
    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(134400)
    pin.icon = icon
    if kind == "HereBeDragons.uiMapID" then pin.uiMapID = 1429
    elseif kind == "HereBeDragons.minimap" then pin.minimap = true
    elseif kind == "HandyNotes.acquired" then pin.acquired = true
    elseif kind == "HandyNotes.arrow" then pin.arrow = pin:CreateTexture(nil, "OVERLAY")
    elseif kind == "Zygor.waypoint" then pin.waypoint = {}
    elseif kind == "Zygor.isZygorWaypoint" then pin.isZygorWaypoint = true
    elseif kind == "GatherMate2.nodeID" then pin.nodeID = 1731
    elseif kind == "GatherMate2.titleXY" then pin.title, pin.x, pin.y = "Copper Vein", 0.5, 0.5
    elseif kind == "Questie.data" then pin.data = { UiMapID = 1429 }
    elseif kind == "Questie.name" then -- the name is enough
    elseif kind == "TomTom.uid" then pin.uid = "tomtom-1"
    elseif kind == "TomTom.point" then pin.point = { uid = "tomtom-2" }
    else error("unknown pin kind " .. tostring(kind), 2) end
    return pin
end

-- A Button without a global name; withIcon: with an .icon texture (counts as a button then).
function NewUnnamedButton(withIcon)
    local button = CreateFrame("Button", nil, Minimap)
    if withIcon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetTexture(134400)
    end
    return button
end

InstallStubs({})
