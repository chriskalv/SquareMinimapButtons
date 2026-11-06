--[[
	Square Minimap Buttons for WoW Forever: the module (scan, skinning, bar, Blizzard buttons).

	Ported from ProjectAzilroka (Azilroka), see LICENSE.txt.
	This file follows ProjectAzilroka's Modules/SquareMinimapButtons.lua. It contains so far the
	scan of the minimap (GrabMinimapButtons), the skinning of the buttons (SkinMinimapButton,
	HandleRegion), the locking of their position methods (LockButton, UnlockButton), the bar
	(Initialize, Update, fading, visibility driver, mover and dragging). The Blizzard buttons
	(HandleBlizzardButtons) and the options follow in the next packages of the port; the code here
	calls SMB.HandleBlizzardButtons only if it exists.

	Changes from the original in this part:
	  - an own ignore list from the profile (db.IgnoreList: button names or Lua patterns) next to
	    the fixed list;
	  - HandleRegion does not compare the texture coordinates when one of them is a secret value
	    (issecretvalue) or not a number; such a region keeps its coordinates;
	  - SkinMinimapButton returns at once for a button that is already skinned;
	  - GrabMinimapButtons returns the number of buttons it skinned (nil when it does not scan);
	  - Update counts a button that already sits in the bar by IsShown() instead of IsVisible(), so a
	    hidden bar (pet battle driver) does not count zero buttons and switch itself off for good;
	  - Update in combat waits for PLAYER_REGEN_ENABLED;
	  - the bar is anchored to the minimap by default (db.AnchorToMinimap, db.Point, db.RelativePoint,
	    db.X, db.Y); without that anchor it stands at its saved free position (db.BarPosition) or,
	    without one, where the original puts it (RIGHT of UIParent, -45/0);
	  - without ElvUI and Tukui the bar itself has OnDragStart/OnDragStop (the original registers it
	    for dragging but gives it no scripts), the position is saved in the profile, and db.Lock or
	    db.AnchorToMinimap stop the dragging (of the bar and of its buttons);
	  - the ElvUI and Tukui movers are used only if the global of that addon exists (an enabled but
	    not loaded ElvUI would raise an error in the original);
	  - the HandleBlizzardButtons timer (7 seconds) calls it only if it exists;
	  - Initialize builds the bar only once;
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

function SMB:ToggleBar_FrameStrataLevel(value)
	if SMB.Bar.SetFixedFrameStrata then SMB.Bar:SetFixedFrameStrata(value) end
	if SMB.Bar.SetFixedFrameLevel then SMB.Bar:SetFixedFrameLevel(value) end
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

--------------------------------------------------------------------------------
-- Bar: dragging and position
--------------------------------------------------------------------------------

-- The bar may be dragged only without an ElvUI or Tukui mover, unlocked and not anchored to the
-- minimap. Dragging a button in the bar drags the bar (the original sets these scripts on the
-- buttons too); called as scripts, so self is the bar or a button.
function SMB:CanDragBar()
	return SMB.Bar ~= nil and not SMB.barMover and not SMB.db.Lock and not SMB.db.AnchorToMinimap
end

function SMB:OnDragStart()
	if not SMB:CanDragBar() then return end
	SMB.barMoving = true
	SMB.Bar:StartMoving()
end

-- Saves the position the client gives the bar after moving it ({ point, relativePoint, x, y },
-- relative to UIParent) and takes the bar out of the client's layout cache, so that the profile
-- alone holds the position.
function SMB:OnDragStop()
	if not SMB.barMoving then return end
	SMB.barMoving = nil
	local Bar = SMB.Bar
	Bar:StopMovingOrSizing()
	if Bar.SetUserPlaced then Bar:SetUserPlaced(false) end

	local point, _, relativePoint, x, y = Bar:GetPoint()
	if point then
		SMB.db.BarPosition = { point, relativePoint or point, x or 0, y or 0 }
	end
end

-- Sets the position of the bar from the profile: anchored to the minimap (db.Point of the bar at
-- db.RelativePoint of the minimap, offset db.X/db.Y), else the saved free position at UIParent, else
-- the position of the original (RIGHT of UIParent, -45/0). Ends a drag in progress, so that a new
-- profile or a lock takes effect at once. With an ElvUI or Tukui mover the mover holds the position
-- (it starts from the position set here in Initialize); then this does nothing else.
function SMB:ApplyBarPosition()
	local Bar = SMB.Bar
	if not Bar then return end

	if SMB.barMoving then
		SMB.barMoving = nil
		Bar:StopMovingOrSizing()
	end

	if SMB.barMover then return end

	local db = SMB.db
	Bar:ClearAllPoints()
	if db.AnchorToMinimap then
		Bar:SetPoint(db.Point or 'TOPLEFT', _G.Minimap, db.RelativePoint or db.Point or 'TOPLEFT', db.X or 0, db.Y or 0)
	else
		local position = db.BarPosition
		if type(position) == 'table' and type(position[1]) == 'string' then
			Bar:SetPoint(position[1], _G.UIParent, position[2] or position[1], position[3] or 0, position[4] or 0)
		else
			Bar:SetPoint('RIGHT', _G.UIParent, 'RIGHT', -45, 0)
		end
	end
end

--------------------------------------------------------------------------------
-- Bar: layout
--------------------------------------------------------------------------------

-- A button that already sits in the bar counts if it is shown (IsShown), because the bar itself may
-- be hidden by its visibility driver; every other button counts if it is visible (IsVisible), as in
-- the original, so that a button in a hidden frame (for example ElvUI's hidden calendar) stays out.
local function countsForBar(Button, Bar)
	if Button:GetParent() == Bar then
		return Button:IsShown()
	end
	return Button:IsVisible()
end

function SMB:PLAYER_REGEN_ENABLED()
	SMB:UnregisterEvent('PLAYER_REGEN_ENABLED')
	SMB.updatePending = nil
	SMB:Update()
end

function SMB:Update()
	if not SMB.db.BarEnabled or not SMB.db.Enable or not SMB.Bar then return end

	-- In combat: once, after combat (strata, level, scale of the buttons are protected on
	-- protected frames).
	if _G.InCombatLockdown() then
		if not SMB.updatePending then
			SMB.updatePending = true
			SMB:RegisterEvent('PLAYER_REGEN_ENABLED')
		end
		return
	end

	local Bar = SMB.Bar
	local AnchorX, AnchorY = 0, 1
	local ButtonsPerRow = SMB.db.ButtonsPerRow or 12
	local Spacing = SMB.db.ButtonSpacing or 2
	local Size = SMB.db.IconSize or 27
	local ActualButtons, Maxed = 0

	local Anchor, DirMult = 'TOPLEFT', 1

	if SMB.db.ReverseDirection then
		Anchor, DirMult = 'TOPRIGHT', -1
	end

	SMB:ToggleBar_FrameStrataLevel(false)
	Bar:SetFrameStrata(SMB.db.Strata)
	Bar:SetFrameLevel(SMB.db.Level)
	SMB:ToggleBar_FrameStrataLevel(true)

	-- drag scripts on the buttons only without an ElvUI or Tukui mover (original: not ElvUI or Tukui)
	local dragStart = not SMB.barMover and SMB.OnDragStart or nil
	local dragStop = not SMB.barMover and SMB.OnDragStop or nil

	for _, Button in next, SMB.Buttons do
		if countsForBar(Button, Bar) then
			AnchorX, ActualButtons = AnchorX + 1, ActualButtons + 1

			if (AnchorX % (ButtonsPerRow + 1)) == 0 then
				AnchorY, AnchorX, Maxed = AnchorY + 1, 1, true
			end

			SMB:UnlockButton(Button)

			SMB:SetTemplate(Button)

			Button:SetParent(Bar)
			Button:SetIgnoreParentScale(false)
			Button:ClearAllPoints()
			Button:SetPoint(Anchor, Bar, Anchor, DirMult * (Spacing + ((Size + Spacing) * (AnchorX - 1))), (- Spacing - ((Size + Spacing) * (AnchorY - 1))))
			Button:SetSize(Size, Size)
			Button:SetScale(1)
			Button:SetFrameStrata(SMB.db.Strata)
			Button:SetFrameLevel(SMB.db.Level + 1)
			Button:SetScript('OnDragStart', dragStart)
			Button:SetScript('OnDragStop', dragStop)

			SMB:LockButton(Button)

			if Maxed then ActualButtons = ButtonsPerRow end
		end
	end

	local BarWidth = Spacing + (Size * ActualButtons) + (Spacing * (ActualButtons - 1)) + Spacing
	local BarHeight = Spacing + (Size * AnchorY) + (Spacing * (AnchorY - 1)) + Spacing

	Bar:SetSize(BarWidth, BarHeight)

	if SMB.db.Backdrop then
		SMB:SetTemplate(Bar)
	elseif Bar.SetBackdrop then -- without SetBackdrop there is no backdrop to remove
		Bar:SetBackdrop(nil)
	end

	if ActualButtons == 0 then
		_G.UnregisterStateDriver(Bar, 'visibility')
		Bar:Hide()
	else
		_G.RegisterStateDriver(Bar, 'visibility', SMB.db.Visibility)
		Bar:Show()
	end

	if SMB.db.BarMouseOver then
		_G.UIFrameFadeOut(Bar, 0.2, Bar:GetAlpha(), 0)
	else
		_G.UIFrameFadeIn(Bar, 0.2, Bar:GetAlpha(), 1)
	end
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

function SMB:PLAYER_ENTERING_WORLD()
	SMB:GrabMinimapButtons(true)
end

function SMB:Initialize()
	if SMB.db.Enable ~= true then
		return
	end

	if SMB.isEnabled then return end -- the bar exists already
	SMB.isEnabled = true

	local UIParent = _G.UIParent
	local Bar = _G.CreateFrame('Frame', 'SquareMinimapButtonBar', UIParent)
	SMB.Bar = Bar
	Bar:Hide()
	SMB:ApplyBarPosition()
	Bar:SetClampedToScreen(true)
	Bar:SetMovable(true)
	Bar:EnableMouse(true)
	Bar:SetSize(SMB.db.IconSize, SMB.db.IconSize)
	SMB:SetTemplate(Bar)

	Bar:SetScript('OnEnter', function(s) _G.UIFrameFadeIn(s, 0.2, s:GetAlpha(), 1) end)
	Bar:SetScript('OnLeave', function(s)
		if SMB.db.BarMouseOver then
			_G.UIFrameFadeOut(s, 0.2, s:GetAlpha(), 0)
		end
	end)

	local Tukui, ElvUI = _G.Tukui, _G.ElvUI
	if SMB.Tukui and type(Tukui) == 'table' and Tukui[1] then
		SMB.barMover = 'Tukui'
		Tukui[1]['Movers']:RegisterFrame(Bar)
	elseif SMB.ElvUI and type(ElvUI) == 'table' and ElvUI[1] then
		SMB.barMover = 'ElvUI'
		ElvUI[1]:CreateMover(Bar, 'SquareMinimapButtonBarMover', 'SquareMinimapButtonBar Anchor', nil, nil, nil, 'ALL,GENERAL')
	else
		Bar:RegisterForDrag('LeftButton')
		Bar:SetScript('OnDragStart', SMB.OnDragStart)
		Bar:SetScript('OnDragStop', SMB.OnDragStop)
	end

	SMB:RegisterEvent('PLAYER_ENTERING_WORLD')
	SMB:ScheduleRepeatingTimer('GrabMinimapButtons', 6)
	SMB:ScheduleTimer(function()
		if SMB.HandleBlizzardButtons then SMB:HandleBlizzardButtons() end
	end, 7)
end
