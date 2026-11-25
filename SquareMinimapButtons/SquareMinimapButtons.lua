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
	    no tracking ability is active (db.TrackerGlowMode: always, only outside of raid instances, or
	    off; new, after a WeakAura of the owner);
	  - CheckTexture and SMB.Hider of the original are unused there and left out.
]]

local _, ns = ...
local SMB = ns.SMB

local _G = _G
local type, next, pairs, ipairs, tostring, unpack, select = type, next, pairs, ipairs, tostring, unpack, select
local strmatch, strfind, strlower, format, tinsert = string.match, string.find, string.lower, string.format, table.insert

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
local TRACKING_ATLAS = 'ui-hud-minimap-tracking-button'

-- Tracking button in WoW Forever (1.0.2): Blizzard_Minimap/Camelot/MinimapTrackingButton.xml draws
-- the button with two textures of one atlas, ui-hud-minimap-tracking-button: StateTexture (layer
-- ARTWORK, shown) and AddTexture (the same atlas, blend mode ADD, shown with alpha 0.1 under the
-- mouse and 0.2 while pressed). The atlas is the magnifying glass inside a bronze square frame; the
-- frame is part of the image, so there is no region to hide for it, and Forever shows no image of
-- the active tracking on the button. Camelot/MinimapTrackingButton.lua (OnButtonStateChanged) sets
-- the atlas of StateTexture again on every button state (normal, mouse over, pressed, menu open)
-- and only the shown state and the alpha of AddTexture; it never touches the alpha of StateTexture
-- or the image of AddTexture. So StateTexture is made transparent and AddTexture emptied once, and
-- an own texture of the addon in the button shows the same atlas cropped by SMB.TrackingIconCrop on
-- each side, which cuts the frame away and keeps the glass. No method of the button or its textures
-- is replaced or hooked; the menu and its scripts stay Blizzard's. The crop of 15 % is measured on a
-- screenshot of the button (the frame with its corners covers about 13 % of each side, the glass
-- lies between 20 % and 80 %); the atlas file itself could not be read.
SMB.TrackingIconCrop = 0.15

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
			if SMB.IsForever then SMB:SkinTrackingIcon(TrackingButton) end

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

-- The glass of the tracking button without Blizzard's frame (see TRACKING_ATLAS above). Returns
-- true if the own icon shows; without the atlas or without the two textures nothing is changed.
function SMB:SkinTrackingIcon(button)
	local state, add = button.StateTexture, button.AddTexture
	if not (type(state) == 'table' and type(add) == 'table' and state.SetAlpha and add.SetTexture) then return false end
	local C_Texture = _G.C_Texture
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(TRACKING_ATLAS)
	if type(info) ~= 'table' then return false end
	local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	-- each of the four checked on its own: ipairs would stop at the first missing one
	for i = 1, 4 do
		local value = select(i, l, r, t, b)
		if type(value) ~= 'number' or (_G.issecretvalue and _G.issecretvalue(value)) then return false end
	end
	local Icon = button.SMBIcon
	if not Icon then
		Icon = button:CreateTexture(nil, 'ARTWORK')
		button.SMBIcon = Icon
	end
	Icon:ClearAllPoints()
	SMB:SetInside(Icon)
	Icon:SetAtlas(TRACKING_ATLAS)
	local f = SMB.TrackingIconCrop
	local w, h = r - l, b - t
	Icon:SetTexCoord(l + w * f, r - w * f, t + h * f, b - h * f)
	Icon:Show()
	state:SetAlpha(0)
	add:SetTexture()
	add:SetAlpha(0)
	return true
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

-- true for a secret value (never compared or computed with, see isPlainTexCoord)
local function isSecret(value)
	local issecretvalue = _G.issecretvalue
	return issecretvalue ~= nil and issecretvalue(value) and true or false
end

-- A MaskTexture is a texture object too (IsObjectType('Texture')), and the skin must never empty,
-- move or crop it: an emptied mask hides everything it masks. LibDBIcon buttons may carry one, for
-- example Connoisseur & Restocker masks its icon with the round file 130924, which is also in
-- RemoveTextureID.
local function isMaskTexture(region)
	return region.GetObjectType ~= nil and region:GetObjectType() == 'MaskTexture'
end
SMB.IsMaskTexture = isMaskTexture

local function isTexture(region)
	return type(region) == 'table' and region.IsObjectType ~= nil and region:IsObjectType('Texture') and not isMaskTexture(region)
end

-- The image of a texture: its file ID, else its file path, else its atlas (nil for none; an empty
-- path counts as none). GetTextureFileID, GetTexture and GetAtlas have no secret marking in WoW
-- Forever's API documentation (SimpleTextureBaseAPI).
local function regionImage(region)
	local texture = region.GetTextureFileID and region:GetTextureFileID() or region.GetTexture and region:GetTexture()
	if texture ~= nil and texture ~= '' then return texture end
	local atlas = region.GetAtlas and region:GetAtlas()
	if atlas ~= nil and atlas ~= '' then return atlas end
	return nil
end
SMB.RegionImage = regionImage

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

--------------------------------------------------------------------------------
-- Protection of skinned textures (1.0.2)
-- A texture the skin has fitted into a button keeps its place, layer and masks, whatever its addon
-- calls on it later. Up to 1.0.1 only SetPoint was replaced by a function that does nothing, while
-- ClearAllPoints stayed real: ItemRack Universal (4.59) clears the points of its LibDBIcon icon and
-- sets new ones on every change of the equipped set (ItemRack.SetMinimapButtonVisual), so the
-- icon was left without anchors, and a texture without anchors is not drawn: an empty square.
--
-- Locking, not restoring: the methods below become fields that do nothing on the texture object
-- (as LockButton does for the position of the buttons). A lock has no moment in which the icon is
-- gone, needs no hook that runs after the foreign call and cannot loop with it. The skin unlocks
-- (removes the fields again, a field the addon had set itself comes back) while it places the
-- texture and locks again afterwards. This is done only on textures of the addon buttons the scan
-- takes; Blizzard's own buttons (mail, tracking, calendar, queue) are never scanned, and nothing of
-- theirs is replaced (see HandleBlizzardButtons).
--
-- Not locked, because the content of the icon belongs to its addon: SetTexture, SetAtlas,
-- SetTexCoord (LibDBIcon shows the full image while the button is pressed), SetVertexColor, Show,
-- Hide and SetAlpha (addons fade or hide their icons on purpose). These are hooked instead
-- (hooksecurefunc on the texture of the addon): after such a call the button is checked again on
-- the next frame (CheckButton): new textures are skinned, a removed border that comes back is
-- emptied again, a crop that the addon reset to the full image is restored, and a button without a
-- visible icon is repaired or gets a replacement image.
--------------------------------------------------------------------------------

SMB.LockedRegionMethods = { 'ClearAllPoints', 'SetPoint', 'SetAllPoints', 'SetSize', 'SetWidth', 'SetHeight', 'SetDrawLayer', 'SetMask', 'AddMaskTexture' }
SMB.HookedRegionMethods = { 'SetTexture', 'SetAtlas', 'SetTexCoord', 'Show', 'Hide', 'SetAlpha' }

-- weak tables: region -> button (or true); nothing is written into the regions themselves except the
-- locked and hooked methods
local handledRegions = setmetatable({}, { __mode = 'k' }) -- fitted into the button by the skin
local removedRegions = setmetatable({}, { __mode = 'k' }) -- border, background, highlight: emptied
local croppedRegions = setmetatable({}, { __mode = 'k' }) -- region -> { l, r, t, b } of the crop
local hookedRegions = setmetatable({}, { __mode = 'k' })
local savedMethods = setmetatable({}, { __mode = 'k' }) -- region -> { name = own field or false }
local skinnedButtons = setmetatable({}, { __mode = 'k' }) -- buttons of other addons the scan took
local queuedButtons = setmetatable({}, { __mode = 'k' })
local hookChecks = setmetatable({}, { __mode = 'k' }) -- button -> { since = GetTime(), count = checks queued since }
local fallbackTextures = setmetatable({}, { __mode = 'k' }) -- button -> replacement texture
SMB.HandledRegions, SMB.RemovedRegions, SMB.CroppedRegions = handledRegions, removedRegions, croppedRegions
SMB.SkinnedButtons, SMB.FallbackTextures = skinnedButtons, fallbackTextures

-- While the skin itself works on textures, the hooks do not queue checks (no loop).
SMB.working = 0

function SMB:LockRegion(region)
	local saved = savedMethods[region]
	if not saved then
		saved = {}
		for _, name in ipairs(SMB.LockedRegionMethods) do
			local own = rawget(region, name)
			saved[name] = (own ~= nil and own ~= SMB.Noop) and own or false
		end
		savedMethods[region] = saved
	end
	for _, name in ipairs(SMB.LockedRegionMethods) do
		region[name] = SMB.Noop
	end
end

-- Only a region locked before is unlocked (a region seen for the first time keeps its own fields).
function SMB:UnlockRegion(region)
	local saved = savedMethods[region]
	if not saved then return end
	for _, name in ipairs(SMB.LockedRegionMethods) do
		region[name] = saved[name] or nil
	end
end

function SMB:IsRegionLocked(region)
	return rawget(region, 'ClearAllPoints') == SMB.Noop
end

-- Runs fn(region) with the region unlocked and locks it again afterwards.
function SMB:WithUnlockedRegion(region, fn)
	SMB.working = SMB.working + 1
	SMB:UnlockRegion(region)
	local ok, err = pcall(fn, region)
	SMB:LockRegion(region)
	SMB.working = SMB.working - 1
	if not ok then _G.geterrorhandler()(err) end
end

-- Checks the button again on the next frame (once, however many calls come in). An addon that
-- animates its icon (SetTexCoord or SetAlpha in OnUpdate) would ask for a check on every frame:
-- after SMB.HookCheckBurst checks of a button within one second, the next ones wait
-- SMB.HookCheckInterval seconds each (about five checks per second instead of one per frame).
SMB.HookCheckBurst = 5
SMB.HookCheckInterval = 0.2

function SMB:QueueCheck(button)
	if SMB.working > 0 or queuedButtons[button] then return end
	queuedButtons[button] = true
	local C_Timer = _G.C_Timer
	if not (C_Timer and C_Timer.After) then
		queuedButtons[button] = nil
		return
	end
	local delay = 0
	local now = _G.GetTime and _G.GetTime() or 0
	local checks = hookChecks[button]
	if not checks or now - checks.since >= 1 then
		checks = { since = now, count = 0 }
		hookChecks[button] = checks
	end
	checks.count = checks.count + 1
	if checks.count > SMB.HookCheckBurst then delay = SMB.HookCheckInterval end
	C_Timer.After(delay, function()
		queuedButtons[button] = nil
		SMB:CheckButton(button)
	end)
end

function SMB:HookRegion(button, region)
	if hookedRegions[region] then return end
	hookedRegions[region] = true
	for _, name in ipairs(SMB.HookedRegionMethods) do
		if type(region[name]) == 'function' then
			_G.hooksecurefunc(region, name, function() SMB:QueueCheck(button) end)
		end
	end
end

-- Places a texture 1 px inside its frame on the layer ARTWORK, without masks, and locks it.
function SMB:PlaceRegion(region)
	SMB:WithUnlockedRegion(region, function()
		SMB:RemoveMasks(region)
		region:ClearAllPoints()
		region:SetDrawLayer('ARTWORK')
		SMB:SetInside(region)
		region:SetMask('')
	end)
end

function SMB:RemoveRegion(button, region)
	SMB.working = SMB.working + 1
	region:SetTexture()
	region:SetAlpha(0)
	SMB.working = SMB.working - 1
	removedRegions[region] = button
	SMB:HookRegion(button, region)
end

function SMB:HandleRegion(button, region)
	-- SkinMinimapButton already skips masks; HandleRegion is public and keeps them out on its own.
	if isMaskTexture(region) then return end
	local texture = regionImage(region)
	if not texture then return end

	local first = not handledRegions[region]
	handledRegions[region] = button
	SMB:PlaceRegion(region)

	-- The crop is decided once, when the skin first sees the texture.
	if first then
		local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = region:GetTexCoord()
		if isPlainTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
			and (ULx == 0 and ULy == 0 and LLx == 0 and LLy == 1 and URx == 1 and URy == 0 and LRx == 1 and LRy == 1) then
			local l, r, t, b = unpack(SpecialTexCoords[button:GetDebugName()] or SMB:TexCoords(true))
			SMB.working = SMB.working + 1
			region:SetTexCoord(l, r, t, b)
			SMB.working = SMB.working - 1
			croppedRegions[region] = { l, r, t, b }
			button:HookScript('OnLeave', function() region:SetTexCoord(l, r, t, b) end)
		end
	end

	SMB:HookRegion(button, region)
end

-- A cropped texture whose addon set the full image again gets the crop back.
local function restoreCrop(region)
	local crop = croppedRegions[region]
	if not crop then return end
	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = region:GetTexCoord()
	if isPlainTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
		and (ULx == 0 and ULy == 0 and LLx == 0 and LLy == 1 and URx == 1 and URy == 0 and LRx == 1 and LRy == 1) then
		SMB.working = SMB.working + 1
		region:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
		SMB.working = SMB.working - 1
	end
end

-- The textures of the button and its direct children (not their children), as the skin of the
-- original takes them.
local function eachRegion(button, fn)
	for _, frame in next, { button, button:GetChildren() } do
		for _, region in next, { frame:GetRegions() } do
			fn(region, frame)
		end
	end
end
SMB.EachRegion = eachRegion

function SMB:SkinMinimapButton(button)
	if button.isSkinned then return end

	-- textures a layout claims (ItemRack's SplitIcon and Divider) are left to the layout; it runs at
	-- the check right after the scan
	local claimed = SMB:ClaimedRegions(button)
	eachRegion(button, function(region)
		if isTexture(region) and claimed[region] then
			SMB:HookRegion(button, region)
		elseif isTexture(region) then
			local texture = regionImage(region)
			if texture and SMB:RemoveTexture(texture) then
				SMB:RemoveRegion(button, region)
			elseif texture then
				SMB:HandleRegion(button, region)
			else
				-- no image yet: skinned once it gets one (CheckButton)
				SMB:HookRegion(button, region)
			end
		end
	end)

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
	skinnedButtons[button] = true
	tinsert(SMB.Buttons, button)
end

--------------------------------------------------------------------------------
-- Layouts for buttons that draw more than one icon
-- An addon that draws its button with several textures side by side cannot be shown by fitting
-- every texture into the whole square. A layout claims these textures (the generic skin leaves
-- them alone) and places them itself; apply runs after every check of the button.
--
-- ItemRack Universal (LibDBIcon10_ItemRack): in the hybrid state (the set of the active queue and a
-- detected gear set differ) ItemRack.SetMinimapButtonVisual shows the left half of the first set's
-- icon on button.icon (TexCoord 0.05-0.5) and the right half of the second set's icon on
-- button.SplitIcon (0.5-0.95), each 8.5 x 17 px inside LibDBIcon's round inset, with a 1 px gold line
-- button.Divider between them; otherwise it hides SplitIcon and Divider and shows one icon. In the
-- square the same split is kept, as ItemRack draws its own square button 20 (SetButton20Visual): the
-- left half of the inner square for button.icon, the right half for SplitIcon, both with ItemRack's
-- texture coordinates (a half of the image on a half of the square, so nothing is stretched), and the
-- line 1 px wide in the middle on OVERLAY. ItemRack's round mask (button.CircleMask) is not added
-- (AddMaskTexture is locked) or taken off again.
--------------------------------------------------------------------------------

SMB.ButtonLayouts = SMB.ButtonLayouts or {}
local splitButtons = setmetatable({}, { __mode = 'k' }) -- buttons whose layout shows a split icon

local function isShownPlain(region)
	local shown = region:IsShown()
	if isSecret(shown) then return true end
	return shown and true or false
end

SMB.ButtonLayouts.LibDBIcon10_ItemRack = {
	claims = function(button)
		local list = {}
		for _, key in ipairs({ 'SplitIcon', 'Divider' }) do
			local region = button[key]
			if isTexture(region) then list[#list + 1] = region end
		end
		return list
	end,
	apply = function(_, button)
		local icon, split, divider = button.icon, button.SplitIcon, button.Divider
		if not (isTexture(icon) and handledRegions[icon]) then return end
		local hybrid = isTexture(split) and isShownPlain(split) and regionImage(split) ~= nil
		if not hybrid then
			-- one icon again: the whole inner square (the generic place)
			if splitButtons[button] then
				splitButtons[button] = nil
				SMB:PlaceRegion(icon)
			end
			return
		end
		splitButtons[button] = true
		SMB:WithUnlockedRegion(icon, function()
			SMB:RemoveMasks(icon)
			icon:ClearAllPoints()
			icon:SetDrawLayer('ARTWORK')
			icon:SetPoint('TOPLEFT', button, 'TOPLEFT', 1, -1)
			icon:SetPoint('BOTTOMRIGHT', button, 'BOTTOM', 0, 1)
		end)
		handledRegions[split] = button
		SMB:WithUnlockedRegion(split, function()
			SMB:RemoveMasks(split)
			split:ClearAllPoints()
			split:SetDrawLayer('ARTWORK')
			split:SetPoint('TOPLEFT', button, 'TOP', 0, -1)
			split:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -1, 1)
		end)
		SMB:HookRegion(button, split)
		if isTexture(divider) then
			SMB:WithUnlockedRegion(divider, function()
				divider:ClearAllPoints()
				divider:SetDrawLayer('OVERLAY', 1)
				divider:SetPoint('TOP', button, 'TOP', 0, -1)
				divider:SetPoint('BOTTOM', button, 'BOTTOM', 0, 1)
				divider:SetWidth(1)
			end)
			SMB:HookRegion(button, divider)
		end
	end,
}

function SMB:GetButtonLayout(button)
	local name = button.GetName and button:GetName()
	if type(name) ~= 'string' or isSecret(name) then return nil end
	return SMB.ButtonLayouts[name]
end

-- region -> true for the textures the layout of the button claims
function SMB:ClaimedRegions(button)
	local claimed = {}
	local layout = SMB:GetButtonLayout(button)
	if layout then
		for _, region in ipairs(layout.claims(button)) do claimed[region] = true end
	end
	return claimed
end

--------------------------------------------------------------------------------
-- Check of a skinned button: on every scan and on the next frame after its addon changed one of
-- its textures (see the hooks above). Textures that came after the first skin, or got their image
-- only later, are skinned now; a removed border or background that the addon set again (for
-- example LibDBIcon's ResetButtonBorder) is emptied again; a crop the addon reset to the full image
-- comes back; then the layout of the button, if it has one, places its textures.
--------------------------------------------------------------------------------

local function checkRegions(button)
	local layout = SMB:GetButtonLayout(button)
	local claimed = SMB:ClaimedRegions(button)
	local fallback = fallbackTextures[button]
	eachRegion(button, function(region)
		if not isTexture(region) or claimed[region] or region == fallback then return end
		local image = regionImage(region)
		if removedRegions[region] then
			if image and SMB:RemoveTexture(image) then
				region:SetTexture()
				region:SetAlpha(0)
			end
		elseif handledRegions[region] then
			restoreCrop(region)
		elseif image then
			if SMB:RemoveTexture(image) then
				SMB:RemoveRegion(button, region)
			else
				SMB:HandleRegion(button, region)
			end
		else
			SMB:HookRegion(button, region)
		end
	end)
	if layout then layout.apply(SMB, button) end
end

--------------------------------------------------------------------------------
-- Self-check (1.0.2): every addon button in the bar shows an icon
-- A visible icon is a texture the skin (or a layout) placed in the button that is shown, has an
-- image (file ID, path or atlas), an alpha above 0 and at least one anchor; with a single anchor it
-- also needs a width and a height above 0 (the client draws no texture without anchors). The layer
-- HIGHLIGHT does not count (shown only under the mouse). IsShown, GetAlpha and GetSize may return
-- secret values in WoW Forever (SecretReturnsForAspect Shown and Alpha, SecretWhenAnchoringSecret);
-- a secret value is never compared and counts as visible. GetNumPoints, GetTexture,
-- GetTextureFileID, GetAtlas and GetDrawLayer have no secret marking.
-- A button in the bar without a visible icon is repaired once: its textures are placed again and
-- its layout runs again. If it still has none, a replacement image fills the square: the icon of
-- its LibDataBroker object, else the IconTexture from the TOC of its addon, else the question mark
-- Interface\Icons\INV_Misc_QuestionMark (the client's own QUESTION_MARK_ICON). The chat names such a
-- button once per session, so that it can be reported (with /smb debug), when it still needs the
-- replacement at a check at least SMB.FallbackReportDelay seconds after the replacement appeared (at
-- the next scan, 6 s, at the latest): an addon that sets its icon a moment after login is not
-- reported. The replacement goes away as soon as the button shows its own icon again.
-- An icon that is intact (image, anchors, size) but hidden or at alpha 0 may be the addon's own
-- doing (a blinking icon, an off state). It gets no replacement at once: the replacement comes only
-- if the icon is still hidden SMB.HiddenIconDelay seconds after it was first found so (at a later
-- check, the next scan or the one after); an icon that loses its image or its place gets the
-- replacement at once. Only the addon buttons the scan took are checked; the Blizzard buttons are
-- built by this addon itself.
--------------------------------------------------------------------------------

SMB.FallbackIcon = [[Interface\Icons\INV_Misc_QuestionMark]]
SMB.FallbackReportDelay = 5
SMB.HiddenIconDelay = 5
SMB.FallbackReported = SMB.FallbackReported or {}
local fallbackSince = setmetatable({}, { __mode = 'k' }) -- button -> GetTime() when the replacement appeared
local hiddenSince = setmetatable({}, { __mode = 'k' }) -- button -> GetTime() when its intact icon was first found hidden

-- true if the texture has an image and a place: not HIGHLIGHT, an image, at least one anchor, with a
-- single anchor a size above 0 (shown state and alpha are not looked at)
local function isIntactIcon(region)
	if not isTexture(region) then return false end
	if region:GetDrawLayer() == 'HIGHLIGHT' then return false end
	if regionImage(region) == nil then return false end
	local points = region:GetNumPoints()
	if isSecret(points) then return true end
	if type(points) ~= 'number' or points < 1 then return false end
	if points >= 2 then return true end
	local width, height = region:GetSize()
	if isSecret(width) or isSecret(height) then return true end
	return type(width) == 'number' and type(height) == 'number' and width > 0 and height > 0
end

local function isOpaque(region)
	local alpha = region:GetAlpha()
	if isSecret(alpha) then return true end
	return type(alpha) == 'number' and alpha > 0
end

function SMB:IsVisibleIcon(region)
	if not isIntactIcon(region) then return false end
	return isShownPlain(region) and isOpaque(region)
end

-- true if a texture the skin or a layout placed in the button is a visible icon (the replacement
-- image does not count)
function SMB:HasVisibleIcon(button)
	local found = false
	eachRegion(button, function(region, frame)
		if found or handledRegions[region] ~= button then return end
		if frame ~= button and not isShownPlain(frame) then return end
		if SMB:IsVisibleIcon(region) then found = true end
	end)
	return found
end

-- true if a texture the skin or a layout placed in the button has its image and its place but is
-- hidden (itself or its frame) or at alpha 0: possibly the addon's own doing
function SMB:HasHiddenIcon(button)
	local found = false
	eachRegion(button, function(region)
		if found or handledRegions[region] ~= button then return end
		if isIntactIcon(region) then found = true end
	end)
	return found
end

-- the LibDataBroker object of a button: LibDBIcon keeps it in button.dataObject; else by the name
-- LibDBIcon10_<name>
function SMB:GetBrokerObject(button)
	local object = button.dataObject
	if type(object) == 'table' then return object end
	local name = button.GetName and button:GetName()
	if type(name) ~= 'string' or isSecret(name) then return nil end
	local key = strmatch(name, '^LibDBIcon10_(.+)$')
	local LibStub = _G.LibStub
	local LDB = key and LibStub and LibStub('LibDataBroker-1.1', true)
	if LDB and LDB.GetDataObjectByName then return LDB:GetDataObjectByName(key) end
	return nil
end

-- candidate addon names for the TOC: the broker's tocname, the broker's name, the name after
-- LibDBIcon10_
function SMB:GetButtonAddOnNames(button, object)
	local names = {}
	if object and type(object.tocname) == 'string' then names[#names + 1] = object.tocname end
	local LibStub = _G.LibStub
	local LDB = object and LibStub and LibStub('LibDataBroker-1.1', true)
	if LDB and LDB.GetNameByDataObject then
		local brokerName = LDB:GetNameByDataObject(object)
		if type(brokerName) == 'string' then names[#names + 1] = brokerName end
	end
	local name = button.GetName and button:GetName()
	if type(name) == 'string' and not isSecret(name) then
		names[#names + 1] = strmatch(name, '^LibDBIcon10_(.+)$') or name
	end
	return names
end

local function plainImage(value)
	if (type(value) == 'string' and value ~= '') or type(value) == 'number' then
		if not isSecret(value) then return value end
	end
	return nil
end

-- The replacement image and its source ('broker', 'toc' or 'default').
function SMB:GetFallbackImage(button)
	local object = SMB:GetBrokerObject(button)
	local icon = object and plainImage(object.icon)
	if icon then return icon, 'broker' end
	local C_AddOns = _G.C_AddOns
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		for _, addon in ipairs(SMB:GetButtonAddOnNames(button, object)) do
			-- an unknown addon name may raise an error
			local ok, value = pcall(C_AddOns.GetAddOnMetadata, addon, 'IconTexture')
			value = ok and plainImage(value)
			if value then return value, 'toc' end
		end
	end
	return SMB.FallbackIcon, 'default'
end

function SMB:GetButtonLabel(button)
	local name = button.GetName and button:GetName()
	if type(name) == 'string' and not isSecret(name) then return name end
	local debugName = button.GetDebugName and button:GetDebugName()
	if type(debugName) == 'string' and not isSecret(debugName) then return debugName end
	return '?'
end

function SMB:ShowFallback(button)
	local texture = fallbackTextures[button]
	if not texture then
		texture = button:CreateTexture(nil, 'ARTWORK')
		fallbackTextures[button] = texture
	end
	local image, source = SMB:GetFallbackImage(button)
	SMB.working = SMB.working + 1
	texture:SetTexture(image)
	SMB:SetInside(texture, button)
	texture:SetTexCoord(SMB:TexCoords())
	texture:SetAlpha(1)
	texture:Show()
	SMB.working = SMB.working - 1
	texture.SMBSource = source

	local now = _G.GetTime and _G.GetTime() or 0
	if not fallbackSince[button] then fallbackSince[button] = now end
	local label = SMB:GetButtonLabel(button)
	if not SMB.FallbackReported[label] and now - fallbackSince[button] >= SMB.FallbackReportDelay then
		SMB.FallbackReported[label] = true
		local sources = { broker = 'LibDataBroker', toc = 'TOC IconTexture', default = 'INV_Misc_QuestionMark' }
		SMB:Message(format(SMB.L['%s showed no icon in the bar and shows a replacement image now (%s). Please report it with the output of /smb debug %s.'], label, sources[source], label))
	end
	return texture
end

function SMB:HideFallback(button)
	fallbackSince[button] = nil
	local texture = fallbackTextures[button]
	if texture and texture:IsShown() then texture:Hide() end
end

-- The check of the regions (above), then the self-check of a button that is shown. Returns true if
-- the button shows its own icon, false if it shows the replacement, nil for a button that is not
-- checked (hidden, or not taken by the scan) or whose intact icon its addon hid only a moment ago.
local function checkButton(button)
	checkRegions(button)
	if not isShownPlain(button) then return nil end
	if SMB:HasVisibleIcon(button) then
		hiddenSince[button] = nil
		SMB:HideFallback(button)
		return true
	end
	-- repair once: place every skinned texture again, then the layout (not needed when an icon has
	-- its image and its place and is only hidden)
	if not SMB:HasHiddenIcon(button) then
		eachRegion(button, function(region)
			if handledRegions[region] == button then SMB:PlaceRegion(region) end
		end)
		local layout = SMB:GetButtonLayout(button)
		if layout then layout.apply(SMB, button) end
		if SMB:HasVisibleIcon(button) then
			hiddenSince[button] = nil
			SMB:HideFallback(button)
			return true
		end
	end
	-- an intact icon its addon hid: wait (blinking, off state), unless the replacement is up already
	local fallback = fallbackTextures[button]
	if SMB:HasHiddenIcon(button) and not (fallback and isShownPlain(fallback)) then
		local now = _G.GetTime and _G.GetTime() or 0
		if not hiddenSince[button] then hiddenSince[button] = now end
		if now - hiddenSince[button] < SMB.HiddenIconDelay then return nil end
	end
	SMB:ShowFallback(button)
	return false
end

function SMB:CheckButton(button)
	if not skinnedButtons[button] then return nil end
	SMB.working = SMB.working + 1
	local ok, result = pcall(checkButton, button)
	SMB.working = SMB.working - 1
	if not ok then
		_G.geterrorhandler()(result)
		return nil
	end
	return result
end

--------------------------------------------------------------------------------
-- Diagnosis: /smb debug [name]
-- Lists the buttons of the bar (in its order; all, or those whose name contains the text, without
-- regard to case) and for each its textures and other regions, and those of its direct children:
-- object type, layer, image, shown, alpha, number of anchors, size, number of masks and the role
-- (skin: placed by the skin; removed: border or background emptied by the skin; layout: placed by
-- a layout; fallback: the replacement image; none: left alone). Values the client keeps secret are
-- printed as "secret".
--------------------------------------------------------------------------------

local function show(value)
	if isSecret(value) then return 'secret' end
	if value == nil then return '-' end
	if type(value) == 'boolean' then return value and 'yes' or 'no' end
	if type(value) == 'number' then return (format('%.4g', value)) end
	return tostring(value)
end

local function printLine(text)
	local chat = _G.DEFAULT_CHAT_FRAME
	if chat and chat.AddMessage then chat:AddMessage(text) else _G.print(text) end
end

function SMB:DescribeRegion(button, region)
	local objectType = region.GetObjectType and region:GetObjectType() or '?'
	local layer, sublevel
	if region.GetDrawLayer then layer, sublevel = region:GetDrawLayer() end
	local parts = { show(objectType), show(layer) .. (sublevel and ('/' .. show(sublevel)) or '') }
	if region.IsObjectType and region:IsObjectType('Texture') then
		parts[#parts + 1] = 'image=' .. show(regionImage(region))
	end
	parts[#parts + 1] = 'shown=' .. show(region.IsShown and region:IsShown())
	parts[#parts + 1] = 'alpha=' .. show(region.GetAlpha and region:GetAlpha())
	parts[#parts + 1] = 'points=' .. show(region.GetNumPoints and region:GetNumPoints())
	if region.GetSize then
		local width, height = region:GetSize()
		parts[#parts + 1] = 'size=' .. show(width) .. 'x' .. show(height)
	end
	if region.GetNumMaskTextures then
		parts[#parts + 1] = 'masks=' .. show(region:GetNumMaskTextures())
	end
	local role = 'none'
	if fallbackTextures[button] == region then
		role = 'fallback (' .. show(region.SMBSource) .. ')'
	elseif handledRegions[region] then
		local layout = SMB:GetButtonLayout(button)
		role = 'skin'
		if layout then
			for _, claimed in ipairs(layout.claims(button)) do
				if claimed == region then role = 'layout' end
			end
		end
	elseif removedRegions[region] then
		role = 'removed'
	end
	parts[#parts + 1] = 'role=' .. role
	if SMB:IsRegionLocked(region) then parts[#parts + 1] = 'locked' end
	return table.concat(parts, ' ')
end

function SMB:DebugButtons(filter)
	filter = strlower(filter or '')
	local L = SMB.L
	if not SMB.Bar then
		SMB:Message(L['The bar does not exist (the addon is turned off or inactive).'])
		return 0
	end
	local count = 0
	for index, button in ipairs(SMB.Buttons) do
		local label = SMB:GetButtonLabel(button)
		if filter == '' or strfind(strlower(label), filter, 1, true) then
			count = count + 1
			local width, height = button:GetSize()
			local fallback = fallbackTextures[button]
			local hasFallback = fallback ~= nil and isShownPlain(fallback)
			local kind = skinnedButtons[button] and 'addon' or 'Blizzard'
			printLine(format('%d. %s (%s): shown=%s inBar=%s size=%sx%s fallback=%s', index, label, kind,
				show(button:IsShown()), show(button:GetParent() == SMB.Bar), show(width), show(height),
				hasFallback and ('yes, ' .. show(fallback.SMBSource)) or 'no'))
			for _, frame in next, { button, button:GetChildren() } do
				local prefix = frame == button and '   ' or ('   [' .. SMB:GetButtonLabel(frame) .. '] ')
				for _, region in next, { frame:GetRegions() } do
					printLine(prefix .. SMB:DescribeRegion(button, region))
				end
			end
		end
	end
	if count == 0 then
		SMB:Message(format(L['No button of the bar matches "%s".'], filter))
	else
		SMB:Message(format(L['%d buttons listed (/smb debug %s).'], count, filter))
	end
	return count
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

	-- every button the scan took, also the ones skinned earlier (textures that came later, a
	-- foreign change the hooks did not see)
	for _, button in ipairs(SMB.Buttons) do
		if skinnedButtons[button] then SMB:CheckButton(button) end
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
-- them is active; the WeakAura also checked only these three spells (IsSpellKnown in its trigger), but
-- unlike it, another active tracking ability no longer hides the glow. Other tracking abilities (the
-- hunter's tracks, Sense Undead, Sense Demons) neither start nor end the glow: in WoW Forever only one
-- tracking ability is active at a time, so a herbalist with Sense Undead on sees the glow.
-- C_Minimap.GetTrackingInfo also lists the townsfolk and quest filters of the tracking menu
-- (Blizzard_Minimap: OPTIONAL_FILTERS, ALWAYS_ON_FILTERS); they do not count. An entry belongs to a
-- gathering ability by its spellID or, if the entry has no spellID, by its name compared with
-- C_Spell.GetSpellName(id) (the client's own spell name, so it works in every language).
-- No glow while the player is dead or a ghost or has no full control (as in the WeakAura), with
-- db.Enable off, or without a tracker button.
-- db.TrackerGlowMode (2026-11-07, replaces the toggle db.TrackerGlow, see SMB:MigrateTrackerGlow in
-- Core.lua): 'always'; 'outsideRaid' (the default), which shows no glow while the player is in a
-- raid instance (IsInInstance() returns true and the instance type 'raid'; dungeons, battlegrounds
-- and the open world still glow), because the owner's ForeverAuras reminder asks to disable tracking
-- in raids; or 'off'. An unknown value counts as the default. Without IsInInstance the player counts
-- as outside of a raid. The instance is read again at PLAYER_ENTERING_WORLD (loading screen) and
-- ZONE_CHANGED_NEW_AREA (a new zone without a loading screen).
-- The glow sits on MinimapCluster.Tracking.Button, which is the button in the bar with MoveTracker
-- and Blizzard's button without it. None of these functions has secret returns in WoW Forever
-- (GetTrackingInfo only has SecretArguments = AllowedWhenUntainted, C_Spell.GetSpellName
-- AllowedWhenTainted, IsInInstance and the two events carry no secret markings in the API
-- documentation of the client).
--------------------------------------------------------------------------------

SMB.TrackerGlowEvents = {
	'MINIMAP_UPDATE_TRACKING', 'SPELLS_CHANGED', 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST',
	'PLAYER_CONTROL_GAINED', 'PLAYER_CONTROL_LOST', 'ZONE_CHANGED_NEW_AREA',
} -- and PLAYER_ENTERING_WORLD (SMB:PLAYER_ENTERING_WORLD)

-- Find Herbs, Find Minerals, Find Treasure (Wowhead Forever, 2026-11-07)
SMB.TrackerGlowSpells = { 2383, 2580, 2481 }

SMB.TrackerGlowColor = { 1, 0, 0 }
-- 1.0.2: a soft glow instead of two hard pixels: SMB.TrackerGlowSize rings of 1 px around the
-- button, the alpha of ring i (1 = next to the button) is TrackerGlowAlpha * ((size - i + 1) / size)^2,
-- so the light falls off outward (0.85, 0.54, 0.31, 0.14, 0.03).
SMB.TrackerGlowSize = 5
SMB.TrackerGlowAlpha = 0.85

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

-- db.TrackerGlowMode if it is one of SMB.TrackerGlowModes, otherwise the default
function SMB:GetTrackerGlowMode()
	local mode = SMB.db and SMB.db.TrackerGlowMode
	for _, value in ipairs(SMB.TrackerGlowModes) do
		if mode == value then return mode end
	end
	return SMB.DefaultTrackerGlowMode
end

-- true while the player is in a raid instance (false without IsInInstance)
function SMB:IsInRaidInstance()
	local IsInInstance = _G.IsInInstance
	if type(IsInInstance) ~= 'function' then return false end
	local inInstance, instanceType = IsInInstance()
	return (inInstance and instanceType == 'raid') and true or false
end

function SMB:ShouldGlowTracker()
	local db = SMB.db
	if not (db and db.Enable) or SMB.blocked then return false end
	local mode = SMB:GetTrackerGlowMode()
	if mode == 'off' then return false end
	if mode == 'outsideRaid' and SMB:IsInRaidInstance() then return false end
	if _G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost('player') then return false end
	if _G.HasFullControl and not _G.HasFullControl() then return false end
	return SMB:HasInactiveTracking()
end

-- The glow: a frame without mouse input around the button (SMB.TrackerGlowSize larger on each side)
-- with SMB.TrackerGlowSize rings of 1 px, each four textures of a plain color (SetColorTexture: no
-- image file, so nothing depends on a texture of the client) in red with additive blending, and an
-- alpha pulse 0.35 <-> 1 (0.6 s each way, looping BOUNCE). Additive light only brightens: the glow
-- may reach over the neighbouring buttons but covers nothing, and it takes no mouse input.
function SMB:CreateTrackerGlow(button)
	local Glow = _G.CreateFrame('Frame', nil, button)
	Glow:EnableMouse(false)
	local size = SMB.TrackerGlowSize
	Glow:SetPoint('TOPLEFT', button, 'TOPLEFT', -size, size)
	Glow:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', size, -size)

	local r, g, b = unpack(SMB.TrackerGlowColor)
	Glow.Edges, Glow.Rings = {}, {}
	for ring = 1, size do
		-- k: distance of the ring from the outer edge of the glow frame
		local k = size - ring
		local alpha = SMB.TrackerGlowAlpha * ((size - ring + 1) / size) ^ 2
		local edges = {
			{ 'TOPLEFT', k, -k, 'TOPRIGHT', -k, -k, nil, 1 }, -- top, with the corners
			{ 'BOTTOMLEFT', k, k, 'BOTTOMRIGHT', -k, k, nil, 1 }, -- bottom, with the corners
			{ 'TOPLEFT', k, -k - 1, 'BOTTOMLEFT', k, k + 1, 1, nil }, -- left, between them
			{ 'TOPRIGHT', -k, -k - 1, 'BOTTOMRIGHT', -k, k + 1, 1, nil }, -- right, between them
		}
		local textures = {}
		for _, edge in ipairs(edges) do
			local Edge = Glow:CreateTexture(nil, 'OVERLAY')
			Edge:SetColorTexture(r, g, b, alpha)
			Edge:SetBlendMode('ADD')
			Edge:SetPoint(edge[1], Glow, edge[1], edge[2], edge[3])
			Edge:SetPoint(edge[4], Glow, edge[4], edge[5], edge[6])
			if edge[7] then Edge:SetWidth(edge[7]) end
			if edge[8] then Edge:SetHeight(edge[8]) end
			textures[#textures + 1] = Edge
			Glow.Edges[#Glow.Edges + 1] = Edge
		end
		Glow.Rings[ring] = textures
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
