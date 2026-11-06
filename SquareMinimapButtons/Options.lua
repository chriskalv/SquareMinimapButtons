--[[
	Square Minimap Buttons for WoW Forever: options (AceConfig), profiles and Blizzard settings.

	Ported from ProjectAzilroka (Azilroka), see LICENSE.txt.
	The options tree follows ProjectAzilroka's SquareMinimapButtons GetOptions (groups, order, getters
	and setters, hidden per client, the garrison toggles disabling each other) and its Init.lua
	(profiles from AceDBOptions, Blizzard settings, ElvUI options through LibElvUIPlugin). The tree is
	written as a plain AceConfig table; ProjectAzilroka's LibAceConfigHelper is not needed, the tables
	have the same fields that its helpers create.

	Changes from the original in this part:
	  - three tabs (General, Blizzard, Profiles) instead of one page with inline groups: the root
	    group has childGroups 'tab', and AceConfigDialog puts the content of each tab into a scroll
	    frame (FeedGroup), so nothing reaches past the frame; the description and the authors stand
	    at the top of the tab General; the Blizzard toggles have an order (the original sorts them by
	    name) so that the tracker glow stands under the tracker toggle;
	  - Visibility is gone (WoW Forever has no pet battles);
	  - hidden per client after this port's client detection: the garrison toggles are hidden in WoW
	    Forever too (they have no effect, as in the original), mail, tracking, calendar and queue are
	    shown there;
	  - Enable: switched on while the bar exists, it only rebuilds the bar (the original shows the
	    reload dialog); switched off without a bar, nothing happens (as in the original);
	  - Blizzard: turning off a button that is already in the bar shows the reload dialog (the
	    original only adds buttons and needs a reload without saying so); MoveQueue is disabled with a
	    hint while ElvUI's queue module holds the queue button;
	  - Blizzard buttons in combat are built after combat (SMB:RequestBlizzardButtons in Core.lua);
	  - a toggle "Glowing Tracker Icon when not tracking" (db.TrackerGlow) under the tracker toggle;
	  - a line "WoW Forever port: Zippy" under the authors;
	  - registered both in the Blizzard settings (the same three tabs) and, when ElvUI's plugin
	    library is there, in ElvUI's options (ProjectAzilroka uses one or the other).
]]

local _, ns = ...
local SMB, L = ns.SMB, ns.L

local _G = _G
local LibStub = _G.LibStub
local type, pairs = type, pairs

SMB.OptionsName = 'SquareMinimapButtons' -- the AceConfig app name (Core.lua opens it under SMB.AddonName)

local STRATA = {
	BACKGROUND = 'BACKGROUND', LOW = 'LOW', MEDIUM = 'MEDIUM', HIGH = 'HIGH', DIALOG = 'DIALOG',
	FULLSCREEN = 'FULLSCREEN', FULLSCREEN_DIALOG = 'FULLSCREEN_DIALOG', TOOLTIP = 'TOOLTIP'
}

SMB.StrataValues = STRATA

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- The Blizzard buttons that HandleBlizzardButtons has built (key of the option -> built?).
function SMB:IsBlizzardButtonBuilt(key)
	if key == 'MoveMail' then
		return _G.SMB_MailFrame ~= nil
	elseif key == 'MoveTracker' then
		local MinimapCluster = _G.MinimapCluster
		local Tracking = MinimapCluster and MinimapCluster.Tracking
		return Tracking ~= nil and Tracking.Button ~= nil and Tracking.Button.SMB == true
	elseif key == 'MoveQueue' then
		local QueueStatusButton = _G.QueueStatusButton
		return QueueStatusButton ~= nil and QueueStatusButton.SMB == true
	elseif key == 'MoveGameTimeFrame' then
		local GameTimeFrame = _G.GameTimeFrame
		return GameTimeFrame ~= nil and GameTimeFrame.SMB == true
	end
	return false -- HideGarrison, MoveGarrison: nothing is built
end

-- ElvUI's queue module holds the queue button (SMB.queueLocked from HandleBlizzardButtons; before
-- that, the holder frame itself).
function SMB:IsQueueLocked()
	return SMB.queueLocked == true or _G.ElvUIQueueStatus ~= nil
end

--------------------------------------------------------------------------------
-- Options tree (ProjectAzilroka GetOptions)
--------------------------------------------------------------------------------

local function get(info)
	return SMB.db[info[#info]]
end

local function setAndUpdate(info, value)
	SMB.db[info[#info]] = value
	SMB:Update()
end

-- Blizzard group: write the option and build what is new; a button that is already built stays
-- until a reload, so turning it off asks for one.
local function setBlizzard(info, value)
	local key = info[#info]
	local built = SMB:IsBlizzardButtonBuilt(key)
	SMB.db[key] = value
	if not value and built then
		_G.StaticPopup_Show('SQUAREMINIMAPBUTTONS_RL')
	end
	SMB:RequestBlizzardButtons()
end

local function setEnable(info, value)
	SMB.db[info[#info]] = value
	if value then
		if not SMB.isEnabled then
			SMB:Initialize()
		else
			SMB:Update() -- switched off and on again without a reload: the bar exists
		end
	elseif SMB.isEnabled then
		_G.StaticPopup_Show('SQUAREMINIMAPBUTTONS_RL')
	end
	SMB:UpdateTrackerGlow() -- off: the glow goes at once
end

-- The tracker glow needs no rebuild and no reload.
local function setTrackerGlow(info, value)
	SMB.db[info[#info]] = value
	SMB:UpdateTrackerGlow()
end

local function queueDesc()
	if SMB:IsQueueLocked() then
		return L["Disabled while ElvUI's queue status mover is active."]
	end
	return nil
end

function SMB:GetOptions()
	local Options = {
		type = 'group',
		name = SMB.Title,
		desc = SMB.Description,
		childGroups = 'tab',
		get = get,
		set = setAndUpdate,
		args = {},
	}

	-- Tab General: description, authors, Enable, the bar, strata and level
	local General = { type = 'group', name = L['General'], order = 1, args = {} }
	Options.args.General = General
	General.args.Description = { type = 'description', name = SMB.Description, order = 1 }
	General.args.AuthorHeader = { type = 'header', name = L['Authors:'], order = 2 }
	General.args.Authors = { type = 'description', name = SMB.Authors, order = 3, fontSize = 'large' }
	General.args.PortAuthor = { type = 'description', name = L['WoW Forever port:'] .. ' ' .. SMB.PortAuthor, order = 4, fontSize = 'medium' }
	General.args.Enable = { type = 'toggle', name = L['Enable'], order = 5, set = setEnable }

	local MBB = { type = 'group', name = L['Minimap Buttons / Bar'], order = 6, inline = true, args = {} }
	General.args.MBB = MBB
	MBB.args.BarEnabled = { type = 'toggle', name = L['Enable Bar'], order = 1 }
	MBB.args.BarMouseOver = { type = 'toggle', name = L['Bar MouseOver'], order = 2 }
	MBB.args.Backdrop = { type = 'toggle', name = L['Bar Backdrop'], order = 3 }
	MBB.args.IconSize = { type = 'range', name = L['Icon Size'], order = 4, min = 12, max = 48, step = 1 }
	MBB.args.ButtonSpacing = { type = 'range', name = L['Button Spacing'], order = 5, min = -1, max = 10, step = 1 }
	MBB.args.ButtonsPerRow = { type = 'range', name = L['Buttons Per Row'], order = 6, min = 1, max = 100, step = 1 }
	MBB.args.Shadows = { type = 'toggle', name = L['Shadows'], order = 7 }
	MBB.args.ReverseDirection = { type = 'toggle', name = L['Reverse Direction'], order = 8 }

	General.args.Strata = { type = 'select', name = L['Frame Strata'], order = 7, values = STRATA }
	General.args.Level = { type = 'range', name = L['Frame Level'], order = 8, min = 0, max = 255, step = 1 }

	-- Tab Blizzard: one toggle per line (full width), the tracker glow under the tracker toggle
	local Blizzard = { type = 'group', name = L['Blizzard'], order = 2, set = setBlizzard, args = {} }
	Options.args.Blizzard = Blizzard
	Blizzard.args.HideGarrison = {
		type = 'toggle', name = L['Hide Garrison'], order = 1, width = 'full',
		disabled = function() return SMB.db.MoveGarrison end,
		hidden = function() return SMB.IsClassic or SMB.IsForever end,
	}
	Blizzard.args.MoveGarrison = {
		type = 'toggle', name = L['Move Garrison Icon'], order = 2, width = 'full',
		disabled = function() return SMB.db.HideGarrison end,
		hidden = function() return SMB.IsClassic or SMB.IsForever end,
	}
	Blizzard.args.MoveGameTimeFrame = {
		type = 'toggle', name = L['Move Game Time Frame'], order = 3, width = 'full',
		hidden = function() return SMB.IsRetail end,
	}
	Blizzard.args.MoveMail = { type = 'toggle', name = L['Move Mail Icon'], order = 4, width = 'full' }
	Blizzard.args.MoveTracker = {
		type = 'toggle', name = L['Move Tracker Icon'], order = 5, width = 'full',
		hidden = function() return SMB.IsClassic end,
	}
	Blizzard.args.TrackerGlow = {
		type = 'toggle', name = L['Glowing Tracker Icon when not tracking'], order = 6, width = 'full',
		desc = L['A red glow pulses around the tracker icon while none of your tracking abilities (for example Find Herbs or Find Minerals) is active. Only takes effect when your character can track something.'],
		set = setTrackerGlow,
		hidden = function() return SMB.IsClassic end,
	}
	Blizzard.args.MoveQueue = {
		type = 'toggle', name = L['Move Queue Status Icon'], order = 7, width = 'full', desc = queueDesc,
		disabled = function() return SMB:IsQueueLocked() end,
		hidden = function() return SMB.IsClassic end,
	}

	-- Tab Profiles (ProjectAzilroka Init.lua: AceDBOptions as a group of its options)
	local ADBO = LibStub('AceDBOptions-3.0', true)
	if ADBO and SMB.data then
		local profiles = ADBO:GetOptionsTable(SMB.data)
		profiles.order = 3
		Options.args.profiles = profiles
	end

	return Options
end

--------------------------------------------------------------------------------
-- ElvUI options (ProjectAzilroka Init.lua: LibElvUIPlugin calls back when ElvUI's options load)
--------------------------------------------------------------------------------

-- The tree for ElvUI's options: the same tabs and settings without the profiles (ElvUI has its own
-- profiles; these are in the Blizzard settings and the own dialog).
function SMB:GetElvUIOptions()
	local options = SMB.Options or SMB:GetOptions()
	local args = {}
	for key, option in pairs(options.args) do
		if key ~= 'profiles' then args[key] = option end
	end
	return {
		type = 'group',
		name = options.name,
		desc = options.desc,
		childGroups = 'tab',
		get = options.get,
		set = options.set,
		args = args,
	}
end

function SMB.InsertElvUIOptions()
	local ElvUI = _G.ElvUI
	local E = type(ElvUI) == 'table' and ElvUI[1]
	local Options = type(E) == 'table' and E.Options
	if type(Options) ~= 'table' or type(Options.args) ~= 'table' then return false end
	Options.args.SquareMinimapButtons = SMB:GetElvUIOptions()
	return true
end

local function registerElvUIPlugin()
	local ElvUI = _G.ElvUI
	local E = type(ElvUI) == 'table' and ElvUI[1]
	local Libs = type(E) == 'table' and E.Libs
	local EP = type(Libs) == 'table' and Libs.EP
	if type(EP) ~= 'table' or type(EP.RegisterPlugin) ~= 'function' then return false end
	EP:RegisterPlugin(SMB.AddonName, SMB.InsertElvUIOptions)
	return true
end

--------------------------------------------------------------------------------
-- Registration (called from Core.lua SMB:Start, before Initialize)
--
-- Size of the own dialog (AceGUI Frame): its content is 34 narrower and 57 lower than the frame,
-- the TabGroup takes another 60 in width and 53 in height (one row of tabs), so a tab shows
-- (width - 94) x (height - 110). 640 leaves 546 for three controls of 170 per row (510), also in
-- an inline group (526); 560 leaves 450 in height, enough for the tab Profiles (about 390 to 430,
-- the longest), General (about 300) and Blizzard (about 165). Every tab scrolls if it ever needs
-- more. Measurements in the README (Options dialog).
--------------------------------------------------------------------------------

SMB.DialogWidth, SMB.DialogHeight = 640, 560

function SMB:RegisterOptions()
	if SMB.optionsRegistered then return end
	SMB.optionsRegistered = true

	local registry = LibStub('AceConfigRegistry-3.0')
	local dialog = LibStub('AceConfigDialog-3.0')

	SMB.Options = SMB:GetOptions()
	registry:RegisterOptionsTable(SMB.OptionsName, SMB.Options)
	dialog:SetDefaultSize(SMB.OptionsName, SMB.DialogWidth, SMB.DialogHeight)

	-- Blizzard settings: one category with the same three tabs (the profiles are a tab now, so the
	-- former subcategory "Profiles" is gone).
	local Settings = _G.Settings
	if dialog.AddToBlizOptions and type(Settings) == 'table' and Settings.RegisterCanvasLayoutCategory then
		local _, categoryID = dialog:AddToBlizOptions(SMB.OptionsName, SMB.Title)
		SMB.SettingsCategoryID = categoryID
	end

	registerElvUIPlugin()
end
