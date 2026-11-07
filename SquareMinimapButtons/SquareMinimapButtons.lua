--[[
	Square Minimap Buttons for WoW Forever: the module (scan, skinning, bar, Blizzard buttons).

	Ported from ProjectAzilroka (Azilroka), see LICENSE.txt.
	This file follows ProjectAzilroka's Modules/SquareMinimapButtons.lua. It contains the scan of
	the minimap (GrabMinimapButtons), the skinning of the buttons (SkinMinimapButton, HandleRegion),
	the locking of their position methods (LockButton, UnlockButton), the Blizzard buttons
	(HandleBlizzardButtons: mail, tracking, queue, calendar), the bar (Initialize, Update, fading,
	mover and dragging) and the glow on the tracker button (UpdateTrackerGlow). The options are in
	Options.lua.

	Changes from the original in this part:
	  - mask textures are never emptied, moved or cropped, and the masks of a skinned texture are
	    taken off it (the original empties a MaskTexture with file ID 130924, which hides the
	    masked icon completely, for example the icon of Connoisseur & Restocker);
	  - HandleRegion does not compare the texture coordinates when one of them is a secret value
	    (issecretvalue) or not a number; such a region keeps its coordinates;
	  - SkinMinimapButton returns at once for a button that is already skinned;
	  - GrabMinimapButtons returns the number of buttons it skinned (nil when it does not scan);
	  - Update counts a button that already sits in the bar by IsShown() instead of IsVisible(), so a
	    hidden bar does not count zero buttons and switch itself off for good;
	  - no visibility driver: WoW Forever has no pet battles, the bar is shown whenever it has
	    buttons (the original registers "[petbattle] hide; show" from db.Visibility);
	  - Update in combat waits for PLAYER_REGEN_ENABLED, and so do the Blizzard buttons requested by
	    an option or profile change in combat (SMB:RequestBlizzardButtons in Core.lua);
	  - the bar is anchored to the minimap by default (db.AnchorToMinimap, db.Point, db.RelativePoint,
	    db.X, db.Y); without that anchor it stands at its saved free position (db.BarPosition) or,
	    without one, where the original puts it (RIGHT of UIParent, -45/0);
	  - without ElvUI and Tukui the bar itself has OnDragStart/OnDragStop (the original registers it
	    for dragging but gives it no scripts), the position is saved in the profile, and
	    db.AnchorToMinimap (the default) stops the dragging (of the bar and of its buttons);
	  - the ElvUI and Tukui movers are used only if the global of that addon exists (an enabled but
	    not loaded ElvUI would raise an error in the original);
	  - Update fades the bar in or out only when it has buttons; in the original UIFrameFadeIn/Out
	    showed the empty bar again right after hiding it;
	  - HandleBlizzardButtons: branches for WoW Forever (tracking and queue as in Retail, the
	    calendar as in Classic); in Forever the tracking frame is shown instead of calling the
	    button's Show() (Blizzard's mixin hides the frame then), the queue click calls
	    ToggleGroupFinderFrame() and the calendar gets its own branch (no GameTimeTexture there);
	    in Retail the queue click uses PVEFrame and GroupFinderFrame_ShowGroupFrame only if they
	    exist; no queue frame while ElvUI's queue holder (ElvUIQueueStatus) exists; missing frames
	    are skipped; the class color border only on frames with backdrop methods; the queue frame
	    starts with the mouse state that its OnShow/OnHide hooks keep; Update runs at the end also
	    in combat, where it waits for the end of combat (the original skips it in combat);
	  - Initialize builds the bar only once;
	  - a red glow pulses around the tracker button while the character can track something but
	    no tracking ability is active (db.TrackerGlow; new, after a WeakAura of the owner);
	  - CheckTexture and SMB.Hider of the original are unused there and left out.
]]

local _, ns = ...
local SMB = ns.SMB

local _G = _G
local type, next, pairs, ipairs, tostring, unpack, select = type, next, pairs, ipairs, tostring, unpack, select
local strmatch, tinsert = string.match, table.insert

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
-- Ignore list (the fixed list of the original)
--------------------------------------------------------------------------------

function SMB:IsIgnored(name)
	return name ~= nil and SMB.IgnoreButton[name] == true
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
-- Blizzard buttons (mail, tracking, queue, calendar)
-- Like the original, this only adds buttons: every button is built once (the frames SMB_MailFrame
-- and SMB_QueueFrame exist once, Blizzard's buttons get the marker .SMB); taking one out again
-- needs a reload. Missing frames (for example no QueueStatusButton) are skipped.
--
-- Branches per client (the original knows Retail and the rest):
--   mail       all clients
--   tracking   Forever and Retail
--   queue      Forever and Retail; in Forever the click opens the group finder through
--              ToggleGroupFinderFrame() (PVEFrame and GroupFinderFrame_ShowGroupFrame do not exist
--              there); not with ElvUI's queue module (see below)
--   calendar   Forever and Classic; Forever has no GameTimeTexture (own branch below)
--   garrison   commented out in the original; nothing is built (HideGarrison and MoveGarrison have
--              no effect)
--------------------------------------------------------------------------------

-- Border in the class color while the mouse is over a Blizzard button (frames skinned by AddOnSkins
-- may lack the backdrop methods).
local function SetClassColorBorder(frame)
	if frame.SetBackdropBorderColor then
		frame:SetBackdropBorderColor(unpack(SMB.ClassColor))
	end
end

local CALENDAR_ATLAS = 'ui-hud-minimap-calendar-button'

function SMB:HandleBlizzardButtons()
	-- the bar exists only after Initialize
	if not SMB.Bar or not SMB.db.BarEnabled then return end
	local Size = SMB.db.IconSize
	local CreateFrame, GameTooltip = _G.CreateFrame, _G.GameTooltip
	local UIFrameFadeIn, UIFrameFadeOut = _G.UIFrameFadeIn, _G.UIFrameFadeOut

	if SMB.db.MoveMail and not _G.SMB_MailFrame then
		local Frame = CreateFrame('Frame', 'SMB_MailFrame', SMB.Bar)
		Frame:SetSize(Size, Size)
		SMB:SetTemplate(Frame)
		Frame.Icon = Frame:CreateTexture(nil, 'ARTWORK')
		SMB:SetInside(Frame.Icon)
		Frame.Icon:SetTexture('Interface/Icons/INV_Letter_15')
		Frame.Icon:SetTexCoord(SMB:TexCoords())
		Frame:EnableMouse(true)
		Frame:HookScript('OnEnter', function(_self)
			-- the mail globals are read on use, as in the original; the tooltip needs Blizzard's
			-- MinimapMailFrameUpdate
			if _G.HasNewMail() then
				GameTooltip:SetOwner(_self, "ANCHOR_BOTTOMRIGHT")
				if _G.MinimapMailFrameUpdate then _G.MinimapMailFrameUpdate() end
			end
			SetClassColorBorder(_self)
			if SMB.Bar:IsShown() and SMB.db.BarMouseOver then
				UIFrameFadeIn(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 1)
			end
		end)
		Frame:HookScript('OnLeave', function(s)
			GameTooltip:Hide()
			SMB:SetTemplate(s)
			if SMB.Bar:IsShown() and SMB.db.BarMouseOver then
				UIFrameFadeOut(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 0)
			end
		end)

		Frame:RegisterEvent('UPDATE_PENDING_MAIL')
		Frame:SetScript('OnEvent', function(_self, event)
			if event == 'UPDATE_PENDING_MAIL' then
				if _G.HasNewMail() then
					_self.Icon:SetVertexColor(0, 1, 0)
					if GameTooltip:IsOwned(_self) and _G.MinimapMailFrameUpdate then
						_G.MinimapMailFrameUpdate()
					end
				else
					_self.Icon:SetVertexColor(1, 1, 1)
				end
			end
		end)

		if _G.HasNewMail() then Frame.Icon:SetVertexColor(0, 1, 0) end
		if SMB.db.Shadows then SMB:CreateShadow(Frame) end

		tinsert(SMB.Buttons, Frame)
	end

	if SMB.IsForever or SMB.IsRetail then
		-- Garrison (ExpansionLandingPageMinimapButton): commented out in the original, not built.

		local MinimapCluster = _G.MinimapCluster
		local Tracking = MinimapCluster and MinimapCluster.Tracking
		local TrackingButton = Tracking and Tracking.Button
		if SMB.db.MoveTracker and TrackingButton and not TrackingButton.SMB then
			if SMB.IsForever then
				-- In WoW Forever MiniMapTrackingButtonMixin replaces Show(shown) with
				-- MinimapCluster.Tracking:SetShown(shown): the original's Show() without an argument
				-- would hide the tracking frame. Show the frame itself instead.
				Tracking:Show()
			else
				TrackingButton:Show()
			end
			SMB:SetTemplate(TrackingButton)
			TrackingButton:SetParent(SMB.Bar)
			TrackingButton:SetSize(Size, Size)
			if Tracking.Background then Tracking.Background:SetAlpha(0) end
			TrackingButton:ClearAllPoints()
			TrackingButton:SetAllPoints(Tracking)

			TrackingButton:SetScript('OnMouseDown', nil)
			TrackingButton:SetScript('OnMouseUp', nil)

			TrackingButton:HookScript('OnEnter', function()
				SetClassColorBorder(TrackingButton)
				if SMB.Bar:IsShown() then
					UIFrameFadeIn(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 1)
				end
			end)
			TrackingButton:HookScript('OnLeave', function()
				SMB:SetTemplate(TrackingButton)
				if SMB.Bar:IsShown() and SMB.db.BarMouseOver then
					UIFrameFadeOut(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 0)
				end
			end)

			TrackingButton.SMB = true

			if SMB.db.Shadows then
				SMB:CreateShadow(TrackingButton)
			end

			tinsert(SMB.Buttons, TrackingButton)
		end

		-- ElvUI's queue module keeps the QueueStatusButton in its holder ElvUIQueueStatus and puts it
		-- back there on every SetParent, SetPoint and SetScale (hooks in its QueueStatus.lua). With
		-- that holder the queue button is left alone; SMB.queueLocked tells the options.
		local QueueStatusButton = _G.QueueStatusButton
		SMB.queueLocked = _G.ElvUIQueueStatus ~= nil
		-- Taint: QueueStatusButton is an Edit Mode system (Group Finder) with secure anchor code;
		-- Blizzard anchors it again in UpdateDefaultAnchor, and a frame anchored by an addon can taint
		-- Edit Mode. MoveQueue is therefore off by default in WoW Forever (see Core.lua).
		if SMB.db.MoveQueue and QueueStatusButton and not QueueStatusButton.SMB and not SMB.queueLocked then
			local Frame = CreateFrame('Frame', 'SMB_QueueFrame', SMB.Bar)
			SMB:SetTemplate(Frame)
			Frame:SetSize(Size, Size)
			Frame.Icon = Frame:CreateTexture(nil, 'ARTWORK')
			Frame.Icon:SetSize(Size, Size)
			Frame.Icon:SetPoint('CENTER')
			Frame.Icon:SetTexture('Interface/LFGFrame/LFG-Eye')
			Frame.Icon:SetTexCoord(0, 64 / 512, 0, 64 / 256)
			Frame:SetScript('OnMouseDown', function()
				if SMB.IsForever then
					if _G.ToggleGroupFinderFrame then _G.ToggleGroupFinderFrame() end
				elseif _G.PVEFrame then
					if _G.PVEFrame:IsShown() then
						_G.HideUIPanel(_G.PVEFrame)
					else
						_G.ShowUIPanel(_G.PVEFrame)
						if _G.GroupFinderFrame_ShowGroupFrame then _G.GroupFinderFrame_ShowGroupFrame() end
					end
				end
			end)
			Frame:HookScript('OnEnter', function(s)
				SetClassColorBorder(s)
				if SMB.Bar:IsShown() then
					UIFrameFadeIn(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 1)
				end
			end)
			Frame:HookScript('OnLeave', function(s)
				SMB:SetTemplate(s)
				if SMB.Bar:IsShown() and SMB.db.BarMouseOver then
					UIFrameFadeOut(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 0)
				end
			end)

			QueueStatusButton:SetParent(SMB.Bar)
			QueueStatusButton:SetFrameLevel(Frame:GetFrameLevel() + 2)
			QueueStatusButton:ClearAllPoints()
			QueueStatusButton:SetPoint("CENTER", Frame, "CENTER", 0, 0)

			-- The frame takes the mouse only while the queue button over it is hidden.
			Frame:EnableMouse(not QueueStatusButton:IsShown())
			QueueStatusButton:HookScript('OnShow', function() Frame:EnableMouse(false) end)
			if QueueStatusButton.OnLeave then
				QueueStatusButton:HookScript('PostClick', QueueStatusButton.OnLeave)
			end
			QueueStatusButton:HookScript('OnHide', function() Frame:EnableMouse(true) end)

			QueueStatusButton.SMB = true

			if SMB.db.Shadows then
				SMB:CreateShadow(Frame)
			end

			tinsert(SMB.Buttons, Frame)
		end
	end

	if not SMB.IsRetail then
		local GameTimeFrame = _G.GameTimeFrame
		if SMB.db.MoveGameTimeFrame and GameTimeFrame and not GameTimeFrame.SMB then
			SMB:SetTemplate(GameTimeFrame)

			if SMB.IsForever then
				-- WoW Forever draws the button with StateTexture and AddTexture (atlas
				-- ui-hud-minimap-calendar-button) and has no GameTimeTexture. Blizzard sets the atlas of
				-- StateTexture and the alpha of AddTexture again on every button state, so both are
				-- emptied and made transparent; an own icon inside the frame shows the calendar. The
				-- click stays Blizzard's (OnClick opens the calendar).
				for _, region in next, { GameTimeFrame.StateTexture, GameTimeFrame.AddTexture } do
					region:SetTexture()
					region:SetAlpha(0)
				end
				if not GameTimeFrame.SMBIcon then
					local Icon = GameTimeFrame:CreateTexture(nil, 'ARTWORK')
					SMB:SetInside(Icon)
					local C_Texture = _G.C_Texture
					if Icon.SetAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(CALENDAR_ATLAS) then
						Icon:SetAtlas(CALENDAR_ATLAS)
					else
						Icon:SetTexture('Interface/Calendar/UI-Calendar-Button')
					end
					GameTimeFrame.SMBIcon = Icon
				end

				GameTimeFrame:HookScript('OnEnter', function()
					SetClassColorBorder(GameTimeFrame)
					if SMB.Bar:IsShown() then
						UIFrameFadeIn(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 1)
					end
				end)
				GameTimeFrame:HookScript('OnLeave', function()
					SMB:SetTemplate(GameTimeFrame)
					if SMB.Bar:IsShown() and SMB.db.BarMouseOver then
						UIFrameFadeOut(SMB.Bar, 0.2, SMB.Bar:GetAlpha(), 0)
					end
				end)
			elseif _G.GameTimeTexture then
				_G.GameTimeTexture:SetTexture('')
			end

			GameTimeFrame.SMB = true
			tinsert(SMB.Buttons, GameTimeFrame)
		end
	end

	-- The original calls Update only out of combat; Update itself waits for the end of combat.
	SMB:Update()
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

-- A MaskTexture is a texture object too (IsObjectType('Texture')), and the skin must never empty,
-- move or crop it: an emptied mask hides everything it masks. LibDBIcon buttons may carry one, for
-- example Connoisseur & Restocker masks its icon with the round file 130924, which is also in
-- RemoveTextureID.
local function isMaskTexture(region)
	return region.GetObjectType ~= nil and region:GetObjectType() == 'MaskTexture'
end
SMB.IsMaskTexture = isMaskTexture

-- Takes the masks off a texture (the square skin needs no round mask, and a mask of another addon
-- would cut the cropped icon). The masks themselves stay as they are; the addon may keep them.
-- GetNumMaskTextures and GetMaskTexture may return secret values (SecretReturnsForAspect
-- Hierarchy); then nothing is changed.
function SMB:RemoveMasks(region)
	if not (region.GetNumMaskTextures and region.GetMaskTexture and region.RemoveMaskTexture) then return 0 end
	local count = region:GetNumMaskTextures()
	local issecretvalue = _G.issecretvalue
	if type(count) ~= 'number' or (issecretvalue and issecretvalue(count)) then return 0 end
	local masks = {}
	for i = 1, count do
		local mask = region:GetMaskTexture(i)
		if mask ~= nil and not (issecretvalue and issecretvalue(mask)) then masks[#masks + 1] = mask end
	end
	for _, mask in ipairs(masks) do
		region:RemoveMaskTexture(mask)
	end
	return #masks
end

function SMB:HandleRegion(button, region)
	-- SkinMinimapButton already skips masks; HandleRegion is public and keeps them out on its own.
	if isMaskTexture(region) then return end
	local texture = region.GetTextureFileID and region:GetTextureFileID() or region.GetTexture and region:GetTexture()
	if not texture then return end

	SMB:RemoveMasks(region)
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
			if region.IsObjectType and region:IsObjectType('Texture') and not isMaskTexture(region) then
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

-- The bar may be dragged only without an ElvUI or Tukui mover and not anchored to the minimap
-- (db.AnchorToMinimap has no option since 2026-11-06; a profile from an earlier test version may
-- have it off). Dragging a button in the bar drags the bar (the original sets these scripts on the
-- buttons too); called as scripts, so self is the bar or a button.
function SMB:CanDragBar()
	return SMB.Bar ~= nil and not SMB.barMover and not SMB.db.AnchorToMinimap
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
-- profile takes effect at once. With an ElvUI or Tukui mover the mover holds the position
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
-- be hidden (it hides itself without buttons); every other button counts if it is visible
-- (IsVisible), as in the original, so that a button in a hidden frame (for example ElvUI's hidden
-- calendar) stays out.
local function countsForBar(Button, Bar)
	if Button:GetParent() == Bar then
		return Button:IsShown()
	end
	return Button:IsVisible()
end

-- After combat: the Blizzard buttons requested in combat (SMB:RequestBlizzardButtons in Core.lua;
-- HandleBlizzardButtons ends with Update), else the Update that waited.
function SMB:PLAYER_REGEN_ENABLED()
	SMB:UnregisterEvent('PLAYER_REGEN_ENABLED')
	local blizzard = SMB.blizzardPending
	SMB.updatePending, SMB.blizzardPending = nil, nil
	if blizzard then
		SMB:HandleBlizzardButtons()
	else
		SMB:Update()
	end
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

	-- No visibility driver (the original: RegisterStateDriver with db.Visibility, "[petbattle]
	-- hide; show"); WoW Forever has no pet battles.
	if ActualButtons == 0 then
		Bar:Hide()
	else
		Bar:Show()
	end

	-- Only with buttons: UIFrameFadeIn/Out show the frame (UIFrameFade calls frame:Show()), so in the
	-- original the empty bar came back as a narrow strip.
	if ActualButtons > 0 then
		if SMB.db.BarMouseOver then
			_G.UIFrameFadeOut(Bar, 0.2, Bar:GetAlpha(), 0)
		else
			_G.UIFrameFadeIn(Bar, 0.2, Bar:GetAlpha(), 1)
		end
	end

	-- the tracker button may have moved into the bar (frame level of its glow)
	SMB:UpdateTrackerGlow()
end

--------------------------------------------------------------------------------
-- Tracker glow (new in this port, after the owner's WeakAura "Track Herbs/Minerals/etc.")
-- A red glow pulses around the tracker button while the character knows one of the gathering
-- tracking abilities (SMB.TrackerGlowSpells: Find Herbs, Find Minerals, Find Treasure) and none of
-- them is active; the WeakAura loaded only with these three spells. Other tracking abilities (the
-- hunter's tracks, Sense Undead, Sense Demons) neither start nor end the glow: in WoW Forever only one
-- tracking ability is active at a time, so a herbalist with Sense Undead on sees the glow.
-- C_Minimap.GetTrackingInfo also lists the townsfolk and quest filters of the tracking menu
-- (Blizzard_Minimap: OPTIONAL_FILTERS, ALWAYS_ON_FILTERS); they do not count. An entry belongs to a
-- gathering ability by its spellID or, if the entry has no spellID, by its name compared with
-- C_Spell.GetSpellName(id) (the client's own spell name, so it works in every language).
-- No glow while the player is dead or a ghost or has no full control (as in the WeakAura), with
-- db.TrackerGlow or db.Enable off, or without a tracker button. The glow sits on
-- MinimapCluster.Tracking.Button, which is the button in the bar with MoveTracker and Blizzard's
-- button without it. None of these functions has secret returns in WoW Forever (GetTrackingInfo
-- only has SecretArguments = AllowedWhenUntainted, C_Spell.GetSpellName AllowedWhenTainted).
--------------------------------------------------------------------------------

SMB.TrackerGlowEvents = {
	'MINIMAP_UPDATE_TRACKING', 'SPELLS_CHANGED', 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST',
	'PLAYER_CONTROL_GAINED', 'PLAYER_CONTROL_LOST',
} -- and PLAYER_ENTERING_WORLD (SMB:PLAYER_ENTERING_WORLD)

-- Find Herbs, Find Minerals, Find Treasure (Wowhead Forever, 2026-11-07)
SMB.TrackerGlowSpells = { 2383, 2580, 2481 }

SMB.TrackerGlowColor = { 1, 0, 0 }
SMB.TrackerGlowSize = 2 -- thickness of the edges; they lie just outside the button

function SMB:GetTrackerButton()
	local MinimapCluster = _G.MinimapCluster
	local Tracking = type(MinimapCluster) == 'table' and MinimapCluster.Tracking
	return type(Tracking) == 'table' and Tracking.Button or nil
end

-- true if the tracking entry info belongs to the spell spellID: by its spellID, or, for an entry
-- without spellID, by its name (C_Spell.GetSpellName may return nothing: then no match)
function SMB:TrackingEntryMatches(info, spellID)
	if type(info) ~= 'table' then return false end
	if info.spellID ~= nil then return info.spellID == spellID end
	if info.name == nil then return false end
	local C_Spell = _G.C_Spell
	if not (C_Spell and C_Spell.GetSpellName) then return false end
	local name = C_Spell.GetSpellName(spellID)
	return name ~= nil and name ~= '' and info.name == name
end

-- true if the tracking entry info belongs to one of the gathering abilities (SMB.TrackerGlowSpells)
function SMB:IsGatheringTracking(info)
	for _, spellID in ipairs(SMB.TrackerGlowSpells) do
		if SMB:TrackingEntryMatches(info, spellID) then return true end
	end
	return false
end

-- true if the character knows a gathering tracking ability and none of them is active
function SMB:HasInactiveTracking()
	local C_Minimap = _G.C_Minimap
	if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return false end
	local count = C_Minimap.GetNumTrackingTypes()
	if type(count) ~= 'number' then return false end
	local known = 0
	for i = 1, count do
		local info = C_Minimap.GetTrackingInfo(i)
		if SMB:IsGatheringTracking(info) then
			if info.active then return false end
			known = known + 1
		end
	end
	return known > 0
end

function SMB:ShouldGlowTracker()
	local db = SMB.db
	if not (db and db.Enable and db.TrackerGlow) or SMB.blocked then return false end
	if _G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost('player') then return false end
	if _G.HasFullControl and not _G.HasFullControl() then return false end
	return SMB:HasInactiveTracking()
end

-- The glow: a frame without mouse input over the button, four red edges with additive blending and
-- an alpha pulse 0.35 <-> 1 (0.6 s each way, looping BOUNCE).
function SMB:CreateTrackerGlow(button)
	local Glow = _G.CreateFrame('Frame', nil, button)
	Glow:EnableMouse(false)
	local size = SMB.TrackerGlowSize
	Glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -size, size)
	Glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', size, -size)

	local r, g, b = unpack(SMB.TrackerGlowColor)
	local edges = {
		{ 'TOPLEFT', 'TOPRIGHT', nil, size },
		{ 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, size },
		{ 'TOPLEFT', 'BOTTOMLEFT', size, nil },
		{ 'TOPRIGHT', 'BOTTOMRIGHT', size, nil },
	}
	Glow.Edges = {}
	for i, edge in ipairs(edges) do
		local Edge = Glow:CreateTexture(nil, 'OVERLAY')
		Edge:SetColorTexture(r, g, b, 1)
		Edge:SetBlendMode('ADD')
		Edge:SetPoint(edge[1], Glow, edge[1])
		Edge:SetPoint(edge[2], Glow, edge[2])
		if edge[3] then Edge:SetWidth(edge[3]) end
		if edge[4] then Edge:SetHeight(edge[4]) end
		Glow.Edges[i] = Edge
	end

	local Pulse = Glow:CreateAnimationGroup()
	Pulse:SetLooping('BOUNCE')
	local Alpha = Pulse:CreateAnimation('Alpha')
	Alpha:SetFromAlpha(0.35)
	Alpha:SetToAlpha(1)
	Alpha:SetDuration(0.6)
	Glow.Pulse = Pulse
	-- The client may stop the animation while a parent is hidden (UI hidden, cinematic); start it
	-- again when the glow shows, so it does not stand still at full alpha until the next event.
	Glow:SetScript('OnShow', function(self)
		if not self.Pulse:IsPlaying() then self.Pulse:Play() end
	end)

	Glow:Hide()
	return Glow
end

function SMB:UpdateTrackerGlow()
	local button = SMB:GetTrackerButton()
	local Glow = SMB.TrackerGlow
	local show = button ~= nil and SMB:ShouldGlowTracker()

	if show and not Glow then
		Glow = SMB:CreateTrackerGlow(button)
		SMB.TrackerGlow = Glow
	end
	if not Glow then return false end

	if show then
		-- The glow is a child of the button and follows it into the bar; this only matters if
		-- MinimapCluster.Tracking.Button is replaced by another frame (for example by another addon).
		if Glow:GetParent() ~= button then
			Glow:SetParent(button)
			local size = SMB.TrackerGlowSize
			Glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -size, size)
			Glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', size, -size)
		end
		Glow:SetFrameStrata(button:GetFrameStrata())
		Glow:SetFrameLevel(button:GetFrameLevel() + 2)
		Glow:Show()
		if not Glow.Pulse:IsPlaying() then Glow.Pulse:Play() end
	else
		Glow.Pulse:Stop()
		Glow:Hide()
	end
	return show
end

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

function SMB:PLAYER_ENTERING_WORLD()
	SMB:GrabMinimapButtons(true)
	SMB:UpdateTrackerGlow()
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
	for _, event in ipairs(SMB.TrackerGlowEvents) do
		SMB:RegisterEvent(event, 'UpdateTrackerGlow')
	end
	SMB:ScheduleRepeatingTimer('GrabMinimapButtons', 6)
	SMB:ScheduleTimer('HandleBlizzardButtons', 7)
	SMB:UpdateTrackerGlow()
end
