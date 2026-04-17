if not Cursive.superwow then
	return
end

-- Local-cache frequently used globals
local UnitCanAttack = UnitCanAttack
local UnitIsPlayer = UnitIsPlayer
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsDead = UnitIsDead
local UnitIsEnemy = UnitIsEnemy
local UnitExists = UnitExists
local UnitName = UnitName
local UnitClassification = UnitClassification
local GetRaidTargetIndex = GetRaidTargetIndex
local CheckInteractDistance = CheckInteractDistance
local getn = table.getn
local strfind = string.find
local strlower = string.lower

local GetTime = GetTime

local filter = {
}

filter.attackable = function(unit)
	if CursiveTestOverlay_UnitCanAttack and CursiveTestOverlay_UnitCanAttack(unit) then return true end
	return UnitCanAttack("player", unit) and true or false
end

filter.player = function(unit)
	return UnitIsPlayer(unit) and true or false
end

filter.notplayer = function(unit)
	return not UnitIsPlayer(unit) and true or false
end

filter.infight = function(unit)
	if CursiveTestOverlay_IsTestGuid and CursiveTestOverlay_IsTestGuid(unit) then return true end
	return UnitAffectingCombat(unit) and true or false
end

filter.hascurse = function(unit)
	return Cursive.curses:HasAnyCurse(unit) and true or false
end

filter.alive = function(unit)
	if CursiveTestOverlay_IsTestGuid and CursiveTestOverlay_IsTestGuid(unit) then return true end
	return not UnitIsDead(unit) and true or false
end

-- v4.0.4: Class-appropriate range spells per talent tree
-- IsSpellInRange auto-applies talent range bonuses (Grim Reach, Destructive Reach, etc.)
-- Multiple spells per class cover different talent trees — in range if ANY spell reaches
local _, playerClass = UnitClass("player")
local classRangeSpells = {
	WARLOCK = { "Corruption", "Immolate" },           -- Grim Reach (Affli) / Destructive Reach (Destro)
	MAGE    = { "Frostbolt", "Fireball", "Arcane Missiles" }, -- Arctic Reach / Flame Throwing / Magic Attunement
	PRIEST  = { "Shadow Word: Pain", "Smite" },       -- Shadow Reach / Holy Reach
	DRUID   = { "Moonfire" },                          -- Nature's Reach (all Balance)
	HUNTER  = { "Auto Shot" },                         -- Hawk Eye (all ranged)
	SHAMAN  = { "Lightning Bolt" },                    -- No range talents
}
local rangeSpells = classRangeSpells[playerClass]

-- v4.0.6: Range check cache — avoids redundant IsSpellInRange calls across
-- ShouldDisplayGuid (10Hz x all GUIDs) AND BarUpdate (20Hz x displayed bars)
local rangeCache = {}       -- guid -> { result = bool, expires = time }
local RANGE_CACHE_TTL = 0.25 -- v4.0.6: 250ms TTL — balanced between perf and responsiveness

filter.range = function(unit)
	-- v4.1.1: TestOverlay range override. Gate on string prefix directly instead of
	-- CursiveTestOverlay_IsTestGuid — that returns false when TestOverlay is disabled,
	-- which allowed stale test-GUIDs (seen briefly during Enable/Disable transitions or
	-- when cached by call-sites) to fall through to CheckInteractDistance(), throwing
	-- "Unknown unit name: CURSIVE_TEST_*" errors. Prefix check is state-independent.
	if type(unit) == "string" and strfind(unit, "CURSIVE_TEST_", 1, true) then
		if CursiveTestOverlay_IsOutOfRange and CursiveTestOverlay_IsOutOfRange(unit) then
			return false
		end
		return true
	end

	-- v4.0.6: Return cached result if fresh
	local now = GetTime()
	local cached = rangeCache[unit]
	if cached and cached.expires > now then
		return cached.result
	end

	local result = false
	if IsSpellInRange and rangeSpells then
		for i = 1, getn(rangeSpells) do
			-- pcall: IsSpellInRange errors if spell is not in spellbook
			local ok, inRange = pcall(IsSpellInRange, rangeSpells[i], unit)
			if ok and inRange == 1 then
				result = true
				break
			end
		end
	end
	if not result then
		result = CheckInteractDistance(unit, 4) and true or false
	end

	-- Store in cache
	rangeCache[unit] = rangeCache[unit] or {}
	rangeCache[unit].result = result
	rangeCache[unit].expires = now + RANGE_CACHE_TTL
	return result
end

-- v4.0.6: Periodic cache cleanup (called from main UI loop)
filter.cleanRangeCache = function()
	local now = GetTime()
	for guid, entry in pairs(rangeCache) do
		if entry.expires < now then
			rangeCache[guid] = nil
		end
	end
end

filter.icon = function(unit)
	if CursiveTestOverlay_GetRaidTargetIndex and CursiveTestOverlay_GetRaidTargetIndex(unit) then return true end
	return GetRaidTargetIndex(unit) and true or false
end

filter.normal = function(unit)
	local elite = UnitClassification(unit)
	return elite == "normal" and true or false
end

filter.elite = function(unit)
	local elite = UnitClassification(unit)
	return (elite == "elite" or elite == "rareelite") and true or false
end

filter.hostile = function(unit)
	return UnitIsEnemy("player", unit) and true or false
end

filter.notignored = function(unit)
	if not Cursive.db.profile.ignorelist or getn(Cursive.db.profile.ignorelist) == 0 then
		return true
	end

	local unitName = UnitName(unit)
	if not unitName then
		return true
	end
	local lowerName = strlower(unitName)
	for _, str in ipairs(Cursive.db.profile.ignorelist) do
		if strfind(lowerName, strlower(str), nil, not Cursive.db.profile.ignorelistuseregex) then
			return false
		end
	end
	return true
end

Cursive.filter = filter

function Cursive:ShouldDisplayGuid(guid)
	-- v3.2.1: Test Overlay GUIDs always display
	if CursiveTestOverlay_IsTestGuid and CursiveTestOverlay_IsTestGuid(guid) then
		return true
	end

	-- never display units that don't exist
	if not UnitExists(guid) then
		return false
	end

	-- never display dead units
	if not Cursive.filter.alive(guid) then
		return false
	end

	-- v3.2.2: Never display mind-controlled players
	-- MC'd players are UnitIsPlayer=true but UnitCanAttack=true (hostile)
	-- Must be checked before priority shortcuts (target/raidmark) that bypass filters
	if UnitIsPlayer(guid) and UnitCanAttack("player", guid) then
		return false
	end

	local _, targetGuid = UnitExists("target")

	-- FILTER TARGET: only show current target, hide everything else
	if Cursive.db.profile.filtertarget then
		if targetGuid and targetGuid == guid then
			return true
		end
		return false
	end

	-- always show target if attackable
	if (targetGuid == guid) and filter.attackable(guid) then
		return true
	end

	-- v4.1.1 FIX (Bug #3): Raid-mark bypass only applies when "Has Raid Mark"
	-- filter is explicitly enabled. Pre-fix: stale-marked OOC bosses leaked past
	-- combat/range filters regardless of user settings. Users who want the old
	-- "always show marked mobs" behavior must enable the "Has Raid Mark" checkbox.
	if Cursive.db.profile.filterraidmark and filter.icon(guid) and filter.attackable(guid) then
		return true
	end

	-- v3.2.1 FIX: Combat filter — show all mobs in combat
	-- Note: UnitAffectingCombat can briefly return false for freshly-pulled mobs
	-- Use both the unit's AND the player's combat state as fallback
	if Cursive.db.profile.filterincombat then
		if not filter.infight(guid) then
			return false
		end
	end

	if Cursive.db.profile.filterhascurse and not filter.hascurse(guid) then
		return false
	end

	if Cursive.db.profile.filterhostile and not filter.hostile(guid) then
		return false
	end

	if Cursive.db.profile.filterattackable and not filter.attackable(guid) then
		return false
	end

	if Cursive.db.profile.filterrange and not filter.range(guid) then
		return false
	end

	if Cursive.db.profile.filterraidmark and not filter.icon(guid) then
		return false
	end

	if Cursive.db.profile.filterplayer and not filter.player(guid) then
		return false
	end

	if Cursive.db.profile.filternotplayer and not filter.notplayer(guid) then
		return false
	end

	if Cursive.db.profile.filterignored and not filter.notignored(guid) then
		return false
	end

	return true
end
