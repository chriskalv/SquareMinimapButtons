--[[
	Square Minimap Buttons for WoW Forever: options (AceConfig), profiles and Blizzard settings.

	Ported from ProjectAzilroka (Azilroka), see LICENSE.txt.
	The options tree follows ProjectAzilroka's SquareMinimapButtons GetOptions (groups, order, getters
	and setters, hidden per client, the garrison toggles disabling each other) and its Init.lua
	(profiles from AceDBOptions, Blizzard settings, ElvUI options through LibElvUIPlugin). The tree is
	written as a plain AceConfig table; ProjectAzilroka's LibAceConfigHelper is not needed, the tables
	have the same fields that its helpers create.

	Changes from the original in this part:
	  - hidden per client after this port's client detection: the garrison toggles are hidden in WoW
	    Forever too (they have no effect, as in the original), mail, tracking, calendar and queue are
	    shown there;
	  - Enable: switched on while the bar exists, it only rebuilds the bar (the original shows the
	    reload dialog); switched off without a bar, nothing happens (as in the original);
	  - Blizzard: turning off a button that is already in the bar shows the reload dialog (the
	    original only adds buttons and needs a reload without saying so); MoveQueue is disabled with a
	    hint while ElvUI's queue module holds the queue button;
	  - Blizzard buttons in combat are built after combat (SMB:RequestBlizzardButtons in Core.lua);
	  - a group "Extensions" with the options of this port (anchor to the minimap, lock, own ignore
	    list); with an ElvUI or Tukui mover the anchor options are disabled with a hint;
	  - a line "WoW Forever port: Zippy" under the authors;
	  - registered both in the Blizzard settings (with a subcategory for the profiles) and, when
	    ElvUI's plugin library is there, in ElvUI's options (ProjectAzilroka uses one or the other).
]]

local _, ns = ...
local SMB, L = ns.SMB, ns.L

local _G = _G
local LibStub = _G.LibStub
local type, pairs, ipairs, sort, tconcat, tinsert = type, pairs, ipairs, table.sort, table.concat, table.insert
local strtrim, gmatch = strtrim, string.gmatch

SMB.OptionsName = 'SquareMinimapButtons' -- the AceConfig app name (Core.lua opens it under SMB.AddonName)

local STRATA = {
	BACKGROUND = 'BACKGROUND', LOW = 'LOW', MEDIUM = 'MEDIUM', HIGH = 'HIGH', DIALOG = 'DIALOG',
	FULLSCREEN = 'FULLSCREEN', FULLSCREEN_DIALOG = 'FULLSCREEN_DIALOG', TOOLTIP = 'TOOLTIP'
}

local POINTS = {
	TOPLEFT = 'TOPLEFT', TOP = 'TOP', TOPRIGHT = 'TOPRIGHT', LEFT = 'LEFT', CENTER = 'CENTER',
	RIGHT = 'RIGHT', BOTTOMLEFT = 'BOTTOMLEFT', BOTTOM = 'BOTTOM', BOTTOMRIGHT = 'BOTTOMRIGHT'
}

SMB.StrataValues, SMB.PointValues = STRATA, POINTS

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

-- The anchor options do nothing while an ElvUI or Tukui mover holds the bar.
local function anchorDisabled()
	return SMB.barMover ~= nil
end

local function anchorDetailDisabled()
	return SMB.barMover ~= nil or not SMB.db.AnchorToMinimap
end

-- Own ignore list: db.IgnoreList (list of strings; a set [entry] = true is read too) <-> one entry
-- per line.
function SMB:IgnoreListToText(list)
	if type(list) ~= 'table' then return '' end
	local lines, seen = {}, {}
	for _, entry in ipairs(list) do
		if type(entry) == 'string' and not seen[entry] then
			seen[entry] = true
			tinsert(lines, entry)
		end
	end
	local extra = {}
	for key, value in pairs(list) do
		if value == true and type(key) == 'string' and not seen[key] then
			seen[key] = true
			tinsert(extra, key)
		end
	end
	sort(extra)
	for _, entry in ipairs(extra) do tinsert(lines, entry) end
	return tconcat(lines, '\n')
end

function SMB:TextToIgnoreList(text)
	local list, seen = {}, {}
	if type(text) ~= 'string' then return list end
	for line in gmatch(text, '[^\r\n]+') do
		local entry = strtrim(line)
		if entry ~= '' and not seen[entry] then
			seen[entry] = true
			tinsert(list, entry)
		end
	end
	return list
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
end

local function setPosition(info, value)
	SMB.db[info[#info]] = value
	SMB:ApplyBarPosition()
end

local function getIgnoreList()
	return SMB:IgnoreListToText(SMB.db.IgnoreList)
end

local function setIgnoreList(_, value)
	SMB.db.IgnoreList = SMB:TextToIgnoreList(value)
	SMB:GrabMinimapButtons(true)
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
		get = get,
		set = setAndUpdate,
		args = {},
	}

	Options.args.Description = { type = 'description', name = SMB.Description, order = 0 }
	Options.args.Enable = { type = 'toggle', name = L['Enable'], order = 1, set = setEnable }

	local General = { type = 'group', name = L['General'], order = 2, inline = true, args = {} }
	Options.args.General = General

	local MBB = { type = 'group', name = L['Minimap Buttons / Bar'], order = 1, inline = true, args = {} }
	General.args.MBB = MBB
	MBB.args.BarEnabled = { type = 'toggle', name = L['Enable Bar'], order = 1 }
	MBB.args.BarMouseOver = { type = 'toggle', name = L['Bar MouseOver'], order = 2 }
	MBB.args.Backdrop = { type = 'toggle', name = L['Bar Backdrop'], order = 3 }
	MBB.args.IconSize = { type = 'range', name = L['Icon Size'], order = 4, min = 12, max = 48, step = 1 }
	MBB.args.ButtonSpacing = { type = 'range', name = L['Button Spacing'], order = 5, min = -1, max = 10, step = 1 }
	MBB.args.ButtonsPerRow = { type = 'range', name = L['Buttons Per Row'], order = 6, min = 1, max = 100, step = 1 }
	MBB.args.Shadows = { type = 'toggle', name = L['Shadows'], order = 7 }
	MBB.args.ReverseDirection = { type = 'toggle', name = L['Reverse Direction'], order = 8 }
	MBB.args.Visibility = { type = 'input', name = L['Visibility'], order = 12, width = 'double' }

	General.args.Strata = { type = 'select', name = L['Frame Strata'], order = 3, values = STRATA }
	General.args.Level = { type = 'range', name = L['Frame Level'], order = 4, min = 0, max = 255, step = 1 }

	-- The toggles of this group have no order, as in the original (sorted by name).
	local Blizzard = { type = 'group', name = L['Blizzard'], order = 2, inline = true, set = setBlizzard, args = {} }
	General.args.Blizzard = Blizzard
	Blizzard.args.HideGarrison = {
		type = 'toggle', name = L['Hide Garrison'],
		disabled = function() return SMB.db.MoveGarrison end,
		hidden = function() return SMB.IsClassic or SMB.IsForever end,
	}
	Blizzard.args.MoveGarrison = {
		type = 'toggle', name = L['Move Garrison Icon'],
		disabled = function() return SMB.db.HideGarrison end,
		hidden = function() return SMB.IsClassic or SMB.IsForever end,
	}
	Blizzard.args.MoveMail = { type = 'toggle', name = L['Move Mail Icon'] }
	Blizzard.args.MoveGameTimeFrame = {
		type = 'toggle', name = L['Move Game Time Frame'],
		hidden = function() return SMB.IsRetail end,
	}
	Blizzard.args.MoveTracker = {
		type = 'toggle', name = L['Move Tracker Icon'],
		hidden = function() return SMB.IsClassic end,
	}
	Blizzard.args.MoveQueue = {
		type = 'toggle', name = L['Move Queue Status Icon'], desc = queueDesc,
		disabled = function() return SMB:IsQueueLocked() end,
		hidden = function() return SMB.IsClassic end,
	}

	-- Extensions of this port (not in the original)
	local Extensions = { type = 'group', name = L['Extensions'], order = 3, inline = true, set = setPosition, args = {} }
	Options.args.Extensions = Extensions
	Extensions.args.MoverNote = {
		type = 'description', order = 0,
		name = L['The ElvUI or Tukui mover holds the position of the bar, so the anchor options are disabled.'],
		hidden = function() return SMB.barMover == nil end,
	}
	Extensions.args.AnchorToMinimap = {
		type = 'toggle', name = L['Anchor to Minimap'], order = 1, width = 'full',
		desc = L['Keeps the bar attached to the minimap. When disabled, the bar can be moved freely like in ProjectAzilroka.'],
		disabled = anchorDisabled,
	}
	Extensions.args.Point = {
		type = 'select', name = L['Point'], order = 2, values = POINTS,
		desc = L['Point of the bar that is attached to the minimap.'],
		disabled = anchorDetailDisabled,
	}
	Extensions.args.RelativePoint = {
		type = 'select', name = L['Relative Point'], order = 3, values = POINTS,
		desc = L['Point of the minimap that the bar is attached to.'],
		disabled = anchorDetailDisabled,
	}
	Extensions.args.X = { type = 'range', name = L['X Offset'], order = 4, min = -200, max = 200, step = 1, disabled = anchorDetailDisabled }
	Extensions.args.Y = { type = 'range', name = L['Y Offset'], order = 5, min = -200, max = 200, step = 1, disabled = anchorDetailDisabled }
	Extensions.args.Lock = {
		type = 'toggle', name = L['Lock Bar'], order = 6, width = 'full',
		desc = L['Prevents the bar from being dragged.'],
	}
	Extensions.args.IgnoreList = {
		type = 'input', name = L['Ignore List'], order = 7, multiline = 6, width = 'full',
		desc = L['Buttons that stay on the minimap: one frame name or Lua pattern per line.'] .. ' '
			.. L['A button that is already in the bar stays there until you reload your User Interface.'],
		get = getIgnoreList,
		set = setIgnoreList,
	}

	Options.args.AuthorHeader = { type = 'header', name = L['Authors:'], order = -4 }
	Options.args.Authors = { type = 'description', name = SMB.Authors, order = -3, fontSize = 'large' }
	Options.args.PortAuthor = { type = 'description', name = L['WoW Forever port:'] .. ' ' .. SMB.PortAuthor, order = -2, fontSize = 'medium' }

	-- Profiles (ProjectAzilroka Init.lua: AceDBOptions as a group of its options)
	local ADBO = LibStub('AceDBOptions-3.0', true)
	if ADBO and SMB.data then
		local profiles = ADBO:GetOptionsTable(SMB.data)
		profiles.order = -1
		Options.args.profiles = profiles
	end

	return Options
end

--------------------------------------------------------------------------------
-- ElvUI options (ProjectAzilroka Init.lua: LibElvUIPlugin calls back when ElvUI's options load)
--------------------------------------------------------------------------------

-- The tree for ElvUI's options: the same groups and settings, tabs, without the profiles (ElvUI has
-- its own profiles; these are in the Blizzard settings and the own dialog).
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
--------------------------------------------------------------------------------

SMB.DialogWidth, SMB.DialogHeight = 700, 620

function SMB:RegisterOptions()
	if SMB.optionsRegistered then return end
	SMB.optionsRegistered = true

	local registry = LibStub('AceConfigRegistry-3.0')
	local dialog = LibStub('AceConfigDialog-3.0')

	SMB.Options = SMB:GetOptions()
	registry:RegisterOptionsTable(SMB.OptionsName, SMB.Options)
	dialog:SetDefaultSize(SMB.OptionsName, SMB.DialogWidth, SMB.DialogHeight)

	-- Blizzard settings: the addon and its profiles as a subcategory.
	local Settings = _G.Settings
	if dialog.AddToBlizOptions and type(Settings) == 'table' and Settings.RegisterCanvasLayoutCategory then
		local _, categoryID = dialog:AddToBlizOptions(SMB.OptionsName, SMB.Title)
		SMB.SettingsCategoryID = categoryID
		if SMB.Options.args.profiles and Settings.RegisterCanvasLayoutSubcategory and Settings.GetCategory then
			dialog:AddToBlizOptions(SMB.OptionsName, L['Profiles'], SMB.Title, 'profiles')
		end
	end

	registerElvUIPlugin()
end
