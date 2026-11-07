-- Test group 10 (tracker glow, nachtrag 2 and 3): a red glow pulses around the tracker button while
-- the character knows a gathering tracking ability (Find Herbs, Find Minerals, Find Treasure) and none
-- of them is active; after the owner's WeakAura "Track Herbs/Minerals/etc." (no glow while dead or a
-- ghost or without full control). The tracking entries come from the stubs of
-- C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo (MinimapScriptTrackingInfo: name,
-- texture, active, type, subType, spellID), spell names from the stub of C_Spell.GetSpellName.

local FOREVER, RETAIL, CLASSIC = 18, 1, 2

-- Wowhead Forever, 2026-11-07
local HERBS = 2383
local MINERALS = 2580
local TREASURE = 2481
local SENSE_UNDEAD = 5502
local SENSE_DEMONS = 5500
local TRACK_BEASTS = 1494
local TRACK_HUMANOIDS = 19883

local function fresh(config)
    ReloadAddon(config or {})
    StartClient()
    return GetAddon()
end

local function withProfile(values, config)
    config = config or {}
    config.savedVariables = {
        profileKeys = { ["Zippy - Forever"] = "Default" },
        profiles = { Default = values },
    }
    return config
end

-- a herbalist and miner with nothing active, plus the townsfolk filters of the tracking menu
local function gatherer(activeHerbs)
    return {
        TRACKING_TOWNSFOLK("Repair", true),
        TRACKING_TOWNSFOLK("Flight Master", true),
        TRACKING_SPELL("Find Herbs", activeHerbs == true, HERBS),
        TRACKING_SPELL("Find Minerals", false, MINERALS),
    }
end

local function trackerButton()
    return MinimapCluster.Tracking.Button
end

local function glowShown(SMB)
    local Glow = SMB.TrackerGlow
    return Glow ~= nil and Glow:IsShown() and Glow.Pulse:IsPlaying()
end

describe("when the glow shows", function()
    it("no tracking entries: no glow (and no glow frame)", function()
        local SMB = fresh({ tracking = {} })
        assert_false(SMB:HasInactiveTracking())
        assert_false(SMB:UpdateTrackerGlow())
        assert_nil(SMB.TrackerGlow, "built only when needed")
    end)

    it("only townsfolk filters, even all off: no glow (nothing to track with an ability)", function()
        local SMB = fresh({ tracking = { TRACKING_TOWNSFOLK("Repair", false), TRACKING_TOWNSFOLK("Banker", false) } })
        assert_false(SMB:HasInactiveTracking())
        assert_false(glowShown(SMB))
    end)

    it("gathering abilities, none active: glow on the tracker button (after login)", function()
        local SMB = fresh({ tracking = gatherer(false) })
        assert_true(SMB:HasInactiveTracking())
        assert_true(glowShown(SMB), "glow at PLAYER_ENTERING_WORLD")
        assert_true(SMB.TrackerGlow:GetParent() == trackerButton())
    end)

    it("townsfolk filters that are on do not count as tracking", function()
        local SMB = fresh({ tracking = gatherer(false) })
        assert_true(glowShown(SMB), "Repair and Flight Master are on, but no ability")
    end)

    it("Find Herbs known and inactive (alone): glow", function()
        local SMB = fresh({ tracking = { TRACKING_SPELL("Find Herbs", false, HERBS) } })
        assert_true(SMB:HasInactiveTracking())
        assert_true(glowShown(SMB))
    end)

    it("Find Herbs active: no glow", function()
        local SMB = fresh({ tracking = gatherer(true) })
        assert_false(SMB:HasInactiveTracking())
        assert_false(glowShown(SMB))
    end)

    it("Find Minerals active, Find Herbs inactive: no glow", function()
        local list = gatherer(false)
        list[4].active = true
        local SMB = fresh({ tracking = list })
        assert_false(SMB:HasInactiveTracking())
        assert_false(glowShown(SMB))
    end)

    it("Find Treasure (dwarves) known and inactive: glow; active: no glow", function()
        local SMB = fresh({ tracking = { TRACKING_SPELL("Find Treasure", false, TREASURE) } })
        assert_true(SMB:HasInactiveTracking())
        SetTrackingList({ TRACKING_SPELL("Find Treasure", true, TREASURE) })
        assert_false(SMB:HasInactiveTracking())
    end)

    it("Sense Undead active, Find Herbs inactive: glow (no herbs are tracked)", function()
        local SMB = fresh({ tracking = {
            TRACKING_TOWNSFOLK("Repair", true),
            TRACKING_SPELL("Sense Undead", true, SENSE_UNDEAD),
            TRACKING_SPELL("Find Herbs", false, HERBS),
        } })
        assert_true(SMB:HasInactiveTracking())
        assert_true(glowShown(SMB))
    end)

    it("only Sense Undead known (a paladin without a gathering profession): never a glow", function()
        local SMB = fresh({ tracking = { TRACKING_SPELL("Sense Undead", false, SENSE_UNDEAD) } })
        assert_false(SMB:HasInactiveTracking())
        assert_false(glowShown(SMB))
        SetTrackingList({ TRACKING_SPELL("Sense Undead", true, SENSE_UNDEAD) })
        FireEvent("MINIMAP_UPDATE_TRACKING")
        assert_false(glowShown(SMB))
    end)

    it("only hunter tracks and Sense Demons, none active: no glow", function()
        local SMB = fresh({ tracking = {
            TRACKING_SPELL("Track Beasts", false, TRACK_BEASTS),
            TRACKING_SPELL("Track Humanoids", false, TRACK_HUMANOIDS),
            TRACKING_SPELL("Sense Demons", false, SENSE_DEMONS),
        } })
        assert_false(SMB:HasInactiveTracking())
        assert_false(glowShown(SMB))
    end)

    it("a gathering entry with its spellID counts without the type spell", function()
        local herbs = TRACKING_SPELL("Find Herbs", false, HERBS)
        herbs.type = "other"
        local SMB = fresh({ tracking = { herbs } })
        assert_true(SMB:HasInactiveTracking())
    end)

    it("dead or a ghost: no glow; alive again: glow", function()
        local SMB = fresh({ tracking = gatherer(false), dead = true })
        assert_false(glowShown(SMB))
        SetPlayerDead(false)
        FireEvent("PLAYER_ALIVE")
        assert_true(glowShown(SMB))
        SetPlayerDead(true)
        FireEvent("PLAYER_DEAD")
        assert_false(glowShown(SMB))
        SetPlayerDead(false)
        FireEvent("PLAYER_UNGHOST")
        assert_true(glowShown(SMB))
    end)

    it("without full control (for example on a taxi or stunned): no glow", function()
        local SMB = fresh({ tracking = gatherer(false) })
        SetFullControl(false)
        FireEvent("PLAYER_CONTROL_LOST")
        assert_false(glowShown(SMB))
        SetFullControl(true)
        FireEvent("PLAYER_CONTROL_GAINED")
        assert_true(glowShown(SMB))
    end)

    it("toggle off: no glow; the setter hides it at once and shows it again", function()
        local SMB = fresh(withProfile({ TrackerGlow = false }, { tracking = gatherer(false) }))
        assert_false(glowShown(SMB))
        SMB.db.TrackerGlow = true
        SMB:UpdateTrackerGlow()
        assert_true(glowShown(SMB))
        local o = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("SquareMinimapButtons", "dialog", "AceConfigDialog-3.0")
        local option = o.args.Blizzard.args.TrackerGlow
        option.set({ "Blizzard", "TrackerGlow" }, false)
        assert_eq(SMB.db.TrackerGlow, false)
        assert_false(glowShown(SMB), "hidden at once, no reload")
        assert_eq(STUB.popups, {}, "no reload dialog")
        option.set({ "Blizzard", "TrackerGlow" }, true)
        assert_true(glowShown(SMB))
    end)

    it("Enable off hides the glow at once (the bar itself waits for the reload)", function()
        local SMB = fresh({ tracking = gatherer(false) })
        assert_true(glowShown(SMB))
        local o = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("SquareMinimapButtons", "dialog", "AceConfigDialog-3.0")
        o.args.General.args.Enable.set({ "General", "Enable" }, false)
        assert_false(glowShown(SMB))
        assert_eq(STUB.popups, { "SQUAREMINIMAPBUTTONS_RL" })
    end)

    it("Enable off from the start: no glow and no events", function()
        local SMB = fresh(withProfile({ Enable = false }, { tracking = gatherer(false) }))
        FireEvent("MINIMAP_UPDATE_TRACKING")
        assert_false(glowShown(SMB))
    end)

    it("a blocked addon (ProjectAzilroka) shows no glow", function()
        local SMB = fresh({ pa = { enabled = true }, tracking = gatherer(false) })
        assert_true(SMB.blocked)
        assert_false(SMB:ShouldGlowTracker())
        assert_false(glowShown(SMB))
    end)

    it("a profile change applies the toggle of the new profile", function()
        local config = withProfile({}, { tracking = gatherer(false) })
        config.savedVariables.profiles.Other = { TrackerGlow = false }
        local SMB = fresh(config)
        assert_true(glowShown(SMB))
        SMB.data:SetProfile("Other")
        assert_false(glowShown(SMB))
    end)
end)

describe("which entries count (SMB:TrackingEntryMatches)", function()
    it("SMB.TrackerGlowSpells: Find Herbs, Find Minerals, Find Treasure", function()
        local SMB = fresh({ tracking = {} })
        assert_eq(SMB.TrackerGlowSpells, { 2383, 2580, 2481 })
    end)

    it("by spellID: the same ID matches, another ID does not (also not by name)", function()
        local SMB = fresh({ tracking = {} })
        assert_true(SMB:TrackingEntryMatches(TRACKING_SPELL("Find Herbs", false, HERBS), HERBS))
        assert_false(SMB:TrackingEntryMatches(TRACKING_SPELL("Find Herbs", false, MINERALS), HERBS))
        assert_false(SMB:TrackingEntryMatches(TRACKING_SPELL("Sense Undead", false, SENSE_UNDEAD), HERBS))
    end)

    it("an entry without spellID whose name is GetSpellName(2383): counts (glow)", function()
        local SMB = fresh({ tracking = { TRACKING_NAMED("Find Herbs", false) } })
        assert_true(SMB:TrackingEntryMatches(STUB.tracking[1], HERBS))
        assert_true(SMB:HasInactiveTracking())
        assert_true(glowShown(SMB))
        STUB.tracking[1].active = true
        FireEvent("MINIMAP_UPDATE_TRACKING")
        assert_false(glowShown(SMB))
    end)

    it("the name comes from the client, so it works in other languages", function()
        local SMB = fresh({ locale = "deDE", spellNames = { [HERBS] = "Kräutersuche" },
            tracking = { TRACKING_NAMED("Kräutersuche", false) } })
        assert_true(SMB:HasInactiveTracking())
        assert_true(glowShown(SMB))
    end)

    it("an entry without spellID and another name: does not count", function()
        local SMB = fresh({ tracking = { TRACKING_NAMED("Sense Undead", false), TRACKING_NAMED("Herbs", false) } })
        assert_false(SMB:IsGatheringTracking(STUB.tracking[1]))
        assert_false(SMB:IsGatheringTracking(STUB.tracking[2]))
        assert_false(SMB:HasInactiveTracking())
        assert_false(glowShown(SMB))
    end)

    it("GetSpellName returns nothing: no match and no error", function()
        local SMB = fresh({ spellNames = {}, tracking = { TRACKING_NAMED("Find Herbs", false) } })
        assert_false(SMB:TrackingEntryMatches(STUB.tracking[1], HERBS))
        assert_false(SMB:HasInactiveTracking())
        assert_false(glowShown(SMB))
        assert_eq(STUB.errors, {})
    end)

    it("without C_Spell: entries without spellID do not count, entries with one do; no error", function()
        local SMB = fresh({ noCSpell = true, tracking = { TRACKING_NAMED("Find Herbs", false) } })
        assert_false(SMB:HasInactiveTracking())
        SetTrackingList({ TRACKING_NAMED("Find Herbs", false), TRACKING_SPELL("Find Minerals", false, MINERALS) })
        assert_true(SMB:HasInactiveTracking())
        assert_eq(STUB.errors, {})
    end)

    it("townsfolk filters are still ignored (no spellID, no gathering spell name)", function()
        local SMB = fresh({ tracking = { TRACKING_TOWNSFOLK("Repair", false), TRACKING_TOWNSFOLK("Banker", false) } })
        assert_false(SMB:HasInactiveTracking())
        assert_false(SMB:TrackingEntryMatches(nil, HERBS))
        assert_false(SMB:TrackingEntryMatches({ active = false }, HERBS), "no name, no spellID")
    end)
end)

describe("events", function()
    it("MINIMAP_UPDATE_TRACKING switches the glow on and off", function()
        local SMB = fresh({ tracking = gatherer(false) })
        assert_true(glowShown(SMB))
        STUB.tracking[3].active = true -- Find Herbs cast
        FireEvent("MINIMAP_UPDATE_TRACKING")
        assert_false(glowShown(SMB))
        STUB.tracking[3].active = false -- cancelled
        FireEvent("MINIMAP_UPDATE_TRACKING")
        assert_true(glowShown(SMB))
    end)

    it("SPELLS_CHANGED: a new gathering ability starts the glow", function()
        local SMB = fresh({ tracking = {} })
        assert_false(glowShown(SMB))
        SetTrackingList({ TRACKING_SPELL("Find Minerals", false, MINERALS) })
        FireEvent("SPELLS_CHANGED")
        assert_true(glowShown(SMB))
    end)

    it("registers all eight events (PLAYER_ENTERING_WORLD through the scan handler)", function()
        local SMB = fresh({ tracking = gatherer(false) })
        assert_eq(SMB.TrackerGlowEvents, {
            "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
            "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST",
        })
        for _, event in ipairs(SMB.TrackerGlowEvents) do
            assert_true(#(STUB.eventFrames[event] or {}) >= 1, event)
        end
        STUB.tracking[3].active = true
        FireEvent("PLAYER_ENTERING_WORLD", false, true)
        assert_false(glowShown(SMB), "PLAYER_ENTERING_WORLD updates the glow")
    end)
end)

describe("where the glow sits", function()
    it("MoveTracker on: on the tracker button in the bar, following it there", function()
        local SMB = fresh({ tracking = gatherer(false) })
        AdvanceTime(7.1) -- HandleBlizzardButtons
        local button = trackerButton()
        assert_true(button:GetParent() == SMB.Bar, "the tracker button is in the bar")
        assert_true(SMB.TrackerGlow:GetParent() == button)
        assert_true(glowShown(SMB))
        assert_eq(SMB.TrackerGlow:GetFrameLevel(), button:GetFrameLevel() + 2, "above the button after Update")
        assert_eq(SMB.TrackerGlow:GetFrameStrata(), button:GetFrameStrata())
    end)

    it("MoveTracker off: on Blizzard's tracker button at the minimap", function()
        local SMB = fresh(withProfile({ MoveTracker = false }, { tracking = gatherer(false) }))
        AdvanceTime(7.1)
        local button = trackerButton()
        assert_false(button:GetParent() == SMB.Bar, "Blizzard's button stays")
        assert_true(SMB.TrackerGlow:GetParent() == button)
        assert_true(glowShown(SMB))
    end)

    it("moves to a replacement of MinimapCluster.Tracking.Button (parent and anchors)", function()
        local SMB = fresh({ tracking = gatherer(false) })
        local old, Glow = trackerButton(), SMB.TrackerGlow
        assert_true(Glow:GetParent() == old)
        local replacement = CreateFrame("Button", nil, Minimap)
        replacement:SetSize(18, 18)
        MinimapCluster.Tracking.Button = replacement
        assert_true(SMB:UpdateTrackerGlow())
        assert_true(SMB.TrackerGlow == Glow, "the same glow frame")
        assert_true(Glow:GetParent() == replacement)
        assert_eq(StubState(Glow).points, {
            { "TOPLEFT", replacement, "TOPLEFT", -2, 2 },
            { "BOTTOMRIGHT", replacement, "BOTTOMRIGHT", 2, -2 },
        })
        MinimapCluster.Tracking.Button = old
    end)

    it("the pulse starts again when the glow shows after the client stopped it", function()
        local SMB = fresh({ tracking = gatherer(false) })
        local Glow = SMB.TrackerGlow
        assert_true(glowShown(SMB))
        Glow:Hide()
        Glow.Pulse:Stop() -- as the client may do while a parent is hidden
        Glow:Show()
        assert_true(Glow.Pulse:IsPlaying(), "OnShow plays the pulse")
    end)

    it("does not catch the mouse and does not enlarge the button", function()
        local SMB = fresh({ tracking = gatherer(false) })
        AdvanceTime(7.1)
        local button, Glow = trackerButton(), SMB.TrackerGlow
        assert_false(Glow:IsMouseEnabled(), "EnableMouse(false)")
        assert_nil(Glow:GetScript("OnMouseDown"))
        assert_nil(Glow:GetScript("OnClick"))
        assert_eq({ button:GetSize() }, { 18, 18 }, "the button keeps its size")
        assert_nil(StubState(button).hitRectInsets, "no change of the hit rectangle")
        assert_eq(StubState(Glow).points, {
            { "TOPLEFT", button, "TOPLEFT", -2, 2 },
            { "BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2 },
        })
    end)

    it("four red edges with additive blending and a pulse 0.35 <-> 1, 0.6 s, BOUNCE", function()
        local SMB = fresh({ tracking = gatherer(false) })
        local Glow = SMB.TrackerGlow
        assert_eq(#Glow.Edges, 4)
        for _, edge in ipairs(Glow.Edges) do
            assert_eq(StubState(edge).colorTexture, { 1, 0, 0, 1 })
            assert_eq(StubState(edge).blendMode, "ADD")
        end
        assert_eq(Glow.Pulse.looping, "BOUNCE")
        local anim = Glow.Pulse.animations[1]
        assert_eq(anim.type, "Alpha")
        assert_eq(anim.calls.SetFromAlpha, { 0.35 })
        assert_eq(anim.calls.SetToAlpha, { 1 })
        assert_eq(anim.calls.SetDuration, { 0.6 })
    end)

    it("one glow frame only, however often it is updated", function()
        local SMB = fresh({ tracking = gatherer(false) })
        local Glow = SMB.TrackerGlow
        for _ = 1, 5 do
            FireEvent("MINIMAP_UPDATE_TRACKING")
            SMB:Update()
        end
        assert_true(SMB.TrackerGlow == Glow)
        assert_eq(#StubState(trackerButton()).children, 1, "one child frame on the button")
    end)

    it("no tracker button (Classic, or a client without MinimapCluster.Tracking): nothing, no error", function()
        local SMB = fresh({ projectID = CLASSIC, tracking = gatherer(false) })
        MinimapCluster.Tracking = nil
        assert_false(SMB:UpdateTrackerGlow())
        assert_eq(STUB.errors, {})
    end)

    it("works in Retail the same way", function()
        local SMB = fresh({ projectID = RETAIL, tracking = gatherer(false) })
        assert_true(glowShown(SMB))
        assert_eq(STUB.errors, {})
    end)

    it("the toggle is hidden in Classic, shown in Forever and Retail", function()
        for _, case in ipairs({ { FOREVER, false }, { RETAIL, false }, { CLASSIC, true } }) do
            fresh({ projectID = case[1] })
            local o = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("SquareMinimapButtons", "dialog", "AceConfigDialog-3.0")
            local hidden = o.args.Blizzard.args.TrackerGlow.hidden({ "Blizzard", "TrackerGlow" })
            assert_eq(hidden and true or false, case[2], "client " .. case[1])
        end
    end)
end)
