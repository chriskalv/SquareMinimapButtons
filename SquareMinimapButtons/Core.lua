--[[
	Square Minimap Buttons for WoW Forever: core.

	Ported from ProjectAzilroka (Azilroka), see LICENSE.txt.
	The helpers in this file (Noop, TexCoords, SetTemplate, CreateShadow, SetInside, class color,
	addon detection, reload dialog) follow ProjectAzilroka's Init.lua; the client detection, the
	defaults of this port, the guard against a loaded ProjectAzilroka, the slash commands and the
	Blizzard buttons after combat for option changes (RequestBlizzardButtons) are new. Start registers
	the options (Options.lua) before Initialize, and only when the guard lets the addon run.

	Load order (see SquareMinimapButtons.toc): Libs, Locales, Core.lua, SquareMinimapButtons.lua,
	Options.lua. Every file receives the addon name and the shared addon table as varargs; the other
	files reach the addon object through that table (ns.SMB), not through the global, because the
	global SquareMinimapButtons may belong to ProjectAzilroka.
]]

local addonName, ns = ...
local _G = _G
local LibStub = _G.LibStub

local type, pairs, select, format, tostring = type, pairs, select, format, tostring
local strlower, strtrim = strlower, strtrim

local SMB = LibStub('AceAddon-3.0'):NewAddon('SquareMinimapButtons', 'AceEvent-3.0', 'AceHook-3.0', 'AceTimer-3.0', 'AceConsole-3.0')
local L = LibStub('AceLocale-3.0'):GetLocale('SquareMinimapButtons')

ns.SMB, ns.L = SMB, L
SMB.L = L
SMB.AddonName = addonName or 'SquareMinimapButtons'

-- ProjectAzilroka sets the same global for its module; keep it if it is taken (guard, see OnEnable).
if _G.SquareMinimapButtons == nil then
	_G.SquareMinimapButtons = SMB
end

SMB.Title = L['Square Minimap Buttons']
SMB.Description = L['Minimap Button Bar / Minimap Button Skinning']
SMB.Authors = 'Azilroka    Sinaris    Omega    Durc'
SMB.PortAuthor = 'Zippy'
SMB.Version = _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata and _G.C_AddOns.GetAddOnMetadata(SMB.AddonName, 'Version') or '1.0.0'

SMB.Noop = function() end
SMB.Solid = [[Interface\Buttons\WHITE8X8]]
SMB.isEnabled = false
SMB.blocked = false

--------------------------------------------------------------------------------
-- Client detection
-- WoW Forever reports WOW_PROJECT_CAMELOT; never compare the build number from GetBuildInfo.
-- Everything else that is neither Forever nor Retail (Mainline) counts as Classic, like the
-- non-Retail branches of ProjectAzilroka.
--------------------------------------------------------------------------------

function SMB.DetectClient(projectID)
	if projectID == nil then projectID = _G.WOW_PROJECT_ID end
	local isForever = projectID ~= nil and _G.WOW_PROJECT_CAMELOT ~= nil and projectID == _G.WOW_PROJECT_CAMELOT
	local isRetail = not isForever and projectID ~= nil and projectID == _G.WOW_PROJECT_MAINLINE
	local isClassic = not isForever and not isRetail
	return isForever, isRetail, isClassic
end

SMB.IsForever, SMB.IsRetail, SMB.IsClassic = SMB.DetectClient()

--------------------------------------------------------------------------------
-- Other addons (ProjectAzilroka Init.lua: IsAddOnEnabled and the ElvUI/Tukui/AddOnSkins flags)
--------------------------------------------------------------------------------

SMB.MyName = _G.UnitName and _G.UnitName('player')
SMB.MyClass = _G.UnitClass and select(2, _G.UnitClass('player'))

function SMB:IsAddOnEnabled(addon, character)
	if type(character) == 'boolean' and character == true then
		character = nil
	end
	local C_AddOns = _G.C_AddOns
	if not (C_AddOns and C_AddOns.GetAddOnEnableState) then return false end
	return C_AddOns.GetAddOnEnableState(addon, character) == 2
end

SMB.ElvUI = SMB:IsAddOnEnabled('ElvUI', SMB.MyName)
SMB.Tukui = SMB:IsAddOnEnabled('Tukui', SMB.MyName)
SMB.AddOnSkins = SMB:IsAddOnEnabled('AddOnSkins', SMB.MyName)

--------------------------------------------------------------------------------
-- Core helpers (ProjectAzilroka Init.lua)
--------------------------------------------------------------------------------

function SMB:GetClassColor(class)
	local custom = _G.CUSTOM_CLASS_COLORS
	return (custom and custom[class]) or _G.RAID_CLASS_COLORS[class or 'PRIEST'] or _G.RAID_CLASS_COLORS.PRIEST
end

do
	local color = SMB:GetClassColor(SMB.MyClass)
	SMB.ClassColor = { color.r, color.g, color.b }
end

do
	local modifier, left, right, top, bottom

	-- Icon crop: 0.04 * ElvUI's general.cropIcon (2 when ElvUI is not loaded), so 0.08 per side.
	function SMB:TexCoords(pack)
		if not modifier then
			local E = _G.ElvUI and _G.ElvUI[1]
			local crop = E and E.db and E.db.general and E.db.general.cropIcon
			if type(crop) ~= 'number' then crop = 2 end
			modifier = 0.04 * crop
			left, right, top, bottom = modifier, 1 - modifier, modifier, 1 - modifier
		end
		if pack then return { left, right, top, bottom } end
		return left, right, top, bottom
	end
end

-- Backdrop: AddOnSkins, then ElvUI's frame API (SetTemplate), then an own backdrop. The own backdrop
-- has a black border (ProjectAzilroka: 0.2/0.2/0.2) to match ElvUI's look without ElvUI.
function SMB:SetTemplate(frame)
	if self.AddOnSkins and _G.AddOnSkins then
		_G.AddOnSkins[1]:SetTemplate(frame)
		return
	end

	if not frame.SetBackdrop then
		_G.Mixin(frame, _G.BackdropTemplateMixin)
		-- what the BackdropTemplate XML does with OnSizeChanged
		if frame.HookScript and frame.OnBackdropSizeChanged then
			frame:HookScript('OnSizeChanged', frame.OnBackdropSizeChanged)
		end
	end

	if frame.SetTemplate then
		frame:SetTemplate('Transparent', true)
	else
		frame:SetBackdrop({ bgFile = SMB.Solid, edgeFile = SMB.Solid, edgeSize = 1 })
		frame:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
		frame:SetBackdropBorderColor(0, 0, 0, 1)
	end
end

-- Shadows exist only with AddOnSkins or a frame API that provides CreateShadow (ElvUI, Tukui).
function SMB:CreateShadow(frame)
	if self.AddOnSkins and _G.AddOnSkins then
		_G.AddOnSkins[1]:CreateShadow(frame)
	elseif frame.CreateShadow then
		frame:CreateShadow()
	end
end

function SMB:SetInside(obj, anchor, xOffset, yOffset, anchor2)
	xOffset, yOffset, anchor = xOffset or 1, yOffset or 1, anchor or obj:GetParent()

	if obj:GetPoint() then obj:ClearAllPoints() end
	obj:SetPoint('TOPLEFT', anchor, 'TOPLEFT', xOffset, -yOffset)
	obj:SetPoint('BOTTOMRIGHT', anchor2 or anchor, 'BOTTOMRIGHT', -xOffset, yOffset)
end

function SMB:Message(...)
	local text = format('|cFF16C3F2%s:|r', SMB.Title)
	for i = 1, select('#', ...) do
		text = text .. ' ' .. tostring((select(i, ...)))
	end
	local chat = _G.DEFAULT_CHAT_FRAME
	if chat and chat.AddMessage then
		chat:AddMessage(text)
	else
		_G.print(text)
	end
end

--------------------------------------------------------------------------------
-- Saved variables and profiles
-- Keys as in ProjectAzilroka's module; values after the screenshot of the requester (one column,
-- 22 px icons). MoveQueue is off in Forever until the queue button is cleared in the client.
--------------------------------------------------------------------------------

function SMB.BuildDefaults(isForever)
	return {
		profile = {
			Enable = true,
			BarEnabled = true,
			BarMouseOver = false,
			Backdrop = true,
			IconSize = 22,
			ButtonSpacing = 2,
			ButtonsPerRow = 1,
			Shadows = true,
			ReverseDirection = false,
			Strata = 'MEDIUM',
			Level = 12,
			Visibility = '[petbattle] hide; show',
			HideGarrison = false,
			MoveGarrison = true,
			MoveMail = true,
			MoveGameTimeFrame = true,
			MoveTracker = true,
			MoveQueue = not isForever,

			-- extensions of this port
			AnchorToMinimap = true,
			Point = 'TOPLEFT',
			RelativePoint = 'TOPLEFT',
			X = 1,
			Y = -1,
			Lock = false,
			IgnoreList = {},
			-- BarPosition: free position of the bar (only used without AnchorToMinimap); unset by default
		},
	}
end

SMB.Defaults = SMB.BuildDefaults(SMB.IsForever)

-- Called on profile change, copy and reset: read the settings again and rebuild what exists
-- (position and lock of the bar, the bar, the Blizzard buttons).
function SMB:ApplySettings()
	if not self.data then return end
	self.db = self.data.profile
	if self.blocked then return end
	if self.ApplyBarPosition then self:ApplyBarPosition() end
	if self.Update then self:Update() end
	if self.HandleBlizzardButtons then self:RequestBlizzardButtons() end
end

-- Builds the Blizzard buttons after an option or profile change. In combat this waits for
-- PLAYER_REGEN_ENABLED (registered once; SMB:PLAYER_REGEN_ENABLED in SquareMinimapButtons.lua runs
-- HandleBlizzardButtons there, which ends with Update). Returns true if it ran at once.
function SMB:RequestBlizzardButtons()
	if not self.HandleBlizzardButtons then return false end
	if _G.InCombatLockdown() then
		if not self.blizzardPending then
			self.blizzardPending = true
			self:RegisterEvent('PLAYER_REGEN_ENABLED')
		end
		return false
	end
	self:HandleBlizzardButtons()
	return true
end

--------------------------------------------------------------------------------
-- Reload dialog (ProjectAzilroka: PROJECTAZILROKA_RL)
--------------------------------------------------------------------------------

_G.StaticPopupDialogs.SQUAREMINIMAPBUTTONS_RL = {
	text = L['This setting requires that you reload your User Interface.'],
	button1 = _G.ACCEPT,
	button2 = _G.CANCEL,
	OnAccept = function() _G.ReloadUI() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
}

--------------------------------------------------------------------------------
-- Guard against ProjectAzilroka
-- With ProjectAzilroka loaded and its Square Minimap Buttons module enabled, both would grab the same
-- buttons and claim the frame SquareMinimapButtonBar. This addon then stays inactive.
-- Returns true (PA module active), false (no PA or module disabled) or nil (PA loaded, profile not
-- known yet, because ProjectAzilroka sets its profile in its own PLAYER_LOGIN handler).
--------------------------------------------------------------------------------

function SMB:IsProjectAzilrokaActive()
	local C_AddOns = _G.C_AddOns
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('ProjectAzilroka')
	if not loaded then return false end

	local engine = _G.ProjectAzilroka
	local PA = type(engine) == 'table' and engine[1]
	local db = type(PA) == 'table' and PA.db
	if type(db) ~= 'table' then return nil end

	local module = db.SquareMinimapButtons
	return type(module) == 'table' and module.Enable == true
end

-- reason: the guard message for the chat (PA module enabled, or PA settings unreadable)
function SMB:Block(reason)
	self.blocked = true
	self.guardMessage = reason or self.guardMessage or L['ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled, so this addon stays inactive. Disable one of the two to avoid conflicts.']
	if not self.guardWarned then
		self.guardWarned = true
		self:Message(self.guardMessage)
	end
end

function SMB:GuardMessage()
	return self.guardMessage or L['ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled, so this addon stays inactive. Disable one of the two to avoid conflicts.']
end

function SMB:Start()
	local active = self:IsProjectAzilrokaActive()
	if active == nil then
		-- Profile still unknown one frame after PLAYER_LOGIN (for example, ProjectAzilroka failed to
		-- load its settings): stay inactive to be safe, since ProjectAzilroka enables the module by
		-- default, but say that its settings could not be read.
		self:Block(L['ProjectAzilroka is loaded, but its settings could not be read, so this addon stays inactive. Disable one of the two to avoid conflicts.'])
		return
	end
	if active then
		self:Block(L['ProjectAzilroka is loaded and its Square Minimap Buttons module is enabled, so this addon stays inactive. Disable one of the two to avoid conflicts.'])
		return
	end

	self.blocked = false
	-- options first (Bauplan: register the options, then Initialize as ProjectAzilroka)
	if self.RegisterOptions then self:RegisterOptions() end
	if self.Initialize then self:Initialize() end
end

--------------------------------------------------------------------------------
-- Options, slash commands, addon compartment
--------------------------------------------------------------------------------

function SMB:OpenOptions()
	if self.blocked then
		self:Message(self:GuardMessage())
		return false
	end

	local registry = LibStub('AceConfigRegistry-3.0', true)
	local dialog = LibStub('AceConfigDialog-3.0', true)
	if registry and dialog and registry:GetOptionsTable(self.AddonName) then
		dialog:Open(self.AddonName)
		return true
	end

	self:Message(L['The options are not available yet.'])
	return false
end

function SMB:PrintHelp()
	self:Message(L['Usage: /zmb [scan | reset] (also /zippyminimap)'])
	self:Message(L['/zmb: open the options'])
	self:Message(L['/zmb scan: scan the minimap for new buttons now'])
	self:Message(L['/zmb reset: reset the current profile to the defaults'])
end

function SMB:SlashCommand(input)
	local command = strlower(strtrim(input or ''))

	if command == '' then
		self:OpenOptions()
	elseif command == 'scan' then
		if self.blocked then
			self:Message(self:GuardMessage())
		elseif self.GrabMinimapButtons then
			self:GrabMinimapButtons(true)
		else
			self:Message(L['Scanning is not available yet.'])
		end
	elseif command == 'reset' then
		if self.data then
			self.data:ResetProfile()
			self:Message(L['The current profile was reset to the defaults.'])
		end
	else
		self:PrintHelp()
	end
end

function _G.SquareMinimapButtons_OnAddonCompartmentClick()
	SMB:OpenOptions()
end

--------------------------------------------------------------------------------
-- AceAddon life cycle
--------------------------------------------------------------------------------

function SMB:OnInitialize()
	self.data = LibStub('AceDB-3.0'):New('SquareMinimapButtonsDB', self.Defaults)
	self.db = self.data.profile

	self.data.RegisterCallback(self, 'OnProfileChanged', 'ApplySettings')
	self.data.RegisterCallback(self, 'OnProfileCopied', 'ApplySettings')
	self.data.RegisterCallback(self, 'OnProfileReset', 'ApplySettings')

	self:RegisterChatCommand('zmb', 'SlashCommand')
	self:RegisterChatCommand('zippyminimap', 'SlashCommand')
end

-- OnEnable runs at PLAYER_LOGIN. If ProjectAzilroka is loaded but has not set its profile yet, decide
-- on the next frame, after its own PLAYER_LOGIN handler.
function SMB:OnEnable()
	if self:IsProjectAzilrokaActive() == nil and _G.C_Timer and _G.C_Timer.After then
		_G.C_Timer.After(0, function() SMB:Start() end)
	else
		self:Start()
	end
end
