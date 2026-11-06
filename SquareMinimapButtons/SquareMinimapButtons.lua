--[[
	Square Minimap Buttons for WoW Forever: the module (scan, skinning, bar, Blizzard buttons).

	Ported from ProjectAzilroka (Azilroka), see LICENSE.txt.
	This file follows ProjectAzilroka's Modules/SquareMinimapButtons.lua. It contains so far the
	scan of the minimap (GrabMinimapButtons), the skinning of the buttons (SkinMinimapButton,
	HandleRegion) and the locking of their position methods (LockButton, UnlockButton). The bar
	(Update, Initialize, fading, mover), the Blizzard buttons and the options follow in the next
	packages of the port; the code here calls SMB.Update and touches SMB.Bar only if they exist.

	Changes from the original in this part:
	  - an own ignore list from the profile (db.IgnoreList: button names or Lua patterns) next to
	    the fixed list;
	  - HandleRegion does not compare the texture coordinates when one of them is a secret value
	    (issecretvalue) or not a number; such a region keeps its coordinates;
	  - SkinMinimapButton returns at once for a button that is already skinned;
	  - GrabMinimapButtons returns the number of buttons it skinned (nil when it does not scan);
	  - CheckTexture and SMB.Hider of the original are unused there and left out.
]]

local _, ns = ...
local SMB = ns.SMB

local _G = _G
local type, next, pairs, ipairs, pcall, tostring, unpack, select = type, next, pairs, ipairs, pcall, tostring, unpack, select
local strfind, strmatch, tinsert = string.find, string.match, table.insert

-- Buttons in the order they were skinned; the bar (Update) lays them out in this order.
SMB.Buttons = SMB.Buttons or {}

-- Fixed ignore list of the original (25 names).
SMB.IgnoreButton = {
	BattlefieldMinimap = true,
	ButtonCollectFrame = true,
	ElvUI_MinimapHolder = true,
	ExpansionLandingPageMinimapButton = true,
	GameTimeFrame = true,
	HelpOpenWebTicketButton = true,
	HelpOpenTicketButton = true,
	InstanceDifficultyFrame = true,
	MinimapBackdrop = true,
	MiniMapMailFrame = true,
	MinimapPanel = true,
	MiniMapTracking = true,
	MiniMapVoiceChatFrame = true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	QueueStatusButton = true,
	RecipeRadarMinimapButtonFrame = true,
	SexyMapCustomBackdrop = true,
	SexyMapPingFrame = true,
	TimeManagerClockButton = true,
	TukuiMinimapCoord = true,
	TukuiMinimapZone = true,
	SL_MinimapDifficultyFrame = true, -- S&L Instance Indicator
	SLECoordsHolder = true, -- S&L Coords Holder
	QuestieFrameGroup = true -- Questie
}

local ButtonFunctions = { 'SetParent', 'ClearAllPoints', 'SetPoint', 'SetSize', 'SetScale', 'SetIgnoreParentScale', 'SetFrameStrata', 'SetFrameLevel' }
-- File IDs of border, background and highlight textures (LibDBIcon: 136430, 136467, 136477)
local RemoveTextureID = { ['136430'] = true, ['136467'] = true, ['136477'] = true, ['136468'] = true, ['130924'] = true, ['982840'] = true }
local SpecialTexCoords = { ['TomCats-MinimapButton'] = { 0, .64, 0, .64 } }

SMB.ButtonFunctions = ButtonFunctions

-- True if the texture (file ID or path, compared as a string) is one that the skin removes.
function SMB:RemoveTexture(texture)
	return RemoveTextureID[tostring(texture)]
end

--------------------------------------------------------------------------------
-- Ignore lists
--------------------------------------------------------------------------------

-- An entry of the own list matches if it equals the name or, as a Lua pattern, is found in it.
-- An invalid pattern raises no error; the entry then only matches the name literally.
local function matchesEntry(name, entry)
	if type(entry) ~= 'string' or entry == '' then return false end
	if entry == name then return true end
	local ok, found = pcall(strfind, name, entry)
	return ok and found ~= nil
end

-- db.IgnoreList holds the entries as a list of strings; a set of the form [entry] = true is read too.
function SMB:IsInIgnoreList(name)
	if type(name) ~= 'string' then return false end
	local list = SMB.db and SMB.db.IgnoreList
	if type(list) ~= 'table' then return false end
	for key, value in pairs(list) do
		local entry = value
		if value == true then entry = key end
		if matchesEntry(name, entry) then return true end
	end
	return false
end

function SMB:IsIgnored(name)
	if name ~= nil and SMB.IgnoreButton[name] then return true end
	return SMB:IsInIgnoreList(name)
end

--------------------------------------------------------------------------------
-- Locking: the position methods become fields that do nothing; UnlockButton removes the fields
-- again, so the methods of the frame type apply.
--------------------------------------------------------------------------------

function SMB:LockButton(Button)
	for _, Function in pairs(ButtonFunctions) do
		Button[Function] = SMB.Noop
	end

	if Button.SetFixedFrameStrata then Button:SetFixedFrameStrata(true) end
	if Button.SetFixedFrameLevel then Button:SetFixedFrameLevel(true) end
end

function SMB:UnlockButton(Button)
	for _, Function in pairs(ButtonFunctions) do
		Button[Function] = nil
	end

	if Button.SetFixedFrameStrata then Button:SetFixedFrameStrata(false) end
	if Button.SetFixedFrameLevel then Button:SetFixedFrameLevel(false) end
end

--------------------------------------------------------------------------------
-- Skinning
--------------------------------------------------------------------------------

-- The eight texture coordinates may be compared only if none is a secret value (WoW Forever's
-- secret system, issecretvalue exists only in clients that have it) and all are numbers.
local function isPlainTexCoord(...)
	local issecretvalue = _G.issecretvalue
	for i = 1, select('#', ...) do
		local value = select(i, ...)
		if issecretvalue and issecretvalue(value) then return false end
		if type(value) ~= 'number' then return false end
	end
	return true
end

function SMB:HandleRegion(button, region)
	local texture = region.GetTextureFileID and region:GetTextureFileID() or region.GetTexture and region:GetTexture()
	if not texture then return end

	region:ClearAllPoints()
	region:SetDrawLayer('ARTWORK')
	SMB:SetInside(region)

	region:SetMask('')

	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = region:GetTexCoord()
	if isPlainTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
		and (ULx == 0 and ULy == 0 and LLx == 0 and LLy == 1 and URx == 1 and URy == 0 and LRx == 1 and LRy == 1) then
		local l, r, t, b = unpack(SpecialTexCoords[button:GetDebugName()] or SMB:TexCoords(true))
		region:SetTexCoord(l, r, t, b)
		button:HookScript('OnLeave', function() region:SetTexCoord(l, r, t, b) end)
	end

	region.SetPoint = SMB.Noop
end

function SMB:SkinMinimapButton(button)
	if button.isSkinned then return end

	for _, frames in next, { button, button:GetChildren() } do
		for _, region in next, { frames:GetRegions() } do
			if region.IsObjectType and region:IsObjectType('Texture') then
				local texture = region.GetTextureFileID and region:GetTextureFileID() or region.GetTexture and region:GetTexture()
				if texture and SMB:RemoveTexture(texture) then
					region:SetTexture()
					region:SetAlpha(0)
				else
					SMB:HandleRegion(button, region)
				end
			end
		end
	end

	local Minimap = _G.Minimap
	button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	button:SetFrameStrata(Minimap:GetFrameStrata())
	button:SetSize(SMB.db.IconSize, SMB.db.IconSize)

	if not button.ignoreTemplate then
		SMB:SetTemplate(button)

		if SMB.db.Shadows then
			SMB:CreateShadow(button)
		end
	end

	-- Fading of the bar; the bar exists from package 3 on.
	button:HookScript('OnEnter', function()
		local Bar = SMB.Bar
		if Bar and Bar:IsShown() then
			_G.UIFrameFadeIn(Bar, 0.2, Bar:GetAlpha(), 1)
		end
	end)
	button:HookScript('OnLeave', function(s)
		SMB:SetTemplate(s)
		local Bar = SMB.Bar
		if Bar and Bar:IsShown() and SMB.db.BarMouseOver then
			_G.UIFrameFadeOut(Bar, 0.2, Bar:GetAlpha(), 0)
		end
	end)

	button.isSkinned = true
	tinsert(SMB.Buttons, button)
end

--------------------------------------------------------------------------------
-- Scan
--------------------------------------------------------------------------------

-- Skins every new button among the children of the minimap. Returns the number of new buttons,
-- or nil when it does not scan (combat, pet battle).
function SMB:GrabMinimapButtons(forceUpdate)
	local C_PetBattles = _G.C_PetBattles
	if (_G.InCombatLockdown() or C_PetBattles and C_PetBattles.IsInBattle()) then return end

	local UpdateBar = forceUpdate
	local count = 0

	for _, btn in ipairs({ _G.Minimap:GetChildren() }) do
		local name = btn.GetName and btn:GetName() or btn.name

		if not (not btn:IsObjectType('Button') or -- Don't want frames only buttons
			SMB:IsIgnored(name) or -- Ignored by default or by the own list
			btn.isSkinned or -- Skinned buttons
			btn.uiMapID or btn.minimap or btn.acquired or -- HereBeDragons | HandyNotes
			btn.arrow or -- HandyNotes | TomCat Tours
			(btn.waypoint or btn.isZygorWaypoint) or -- Zygor
			(btn.nodeID or btn.title and btn.x and btn.y) or -- GatherMate2
			(btn.data and btn.data.UiMapID) or (name and strmatch(name, '^QuestieFrame')) or -- Questie
			(btn.uid or btn.point and btn.point.uid) or -- TomTom
			not name and not btn.icon -- don't want unnamed ones
			)
		then
			SMB:SkinMinimapButton(btn)
			UpdateBar = true
			count = count + 1
		end
	end

	if UpdateBar and SMB.Update then
		SMB:Update()
	end

	return count
end
