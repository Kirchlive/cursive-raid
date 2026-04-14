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

filter.range = function(unit)
	-- v4.0.5: TestOverlay GUIDs are always "in range"
	if CursiveTestOverlay_IsTestGuid and CursiveTestOverlay_IsTestGuid(unit) then return true end
	if IsSpellInRange and rangeSpells then
		for i = 1, table.getn(rangeSpells) do
			-- pcall: IsSpellInRange errors if spell is not in spellbook
			local ok, result = pcall(IsSpellInRange, rangeSpells[i], unit)
			if ok and result == 1 then return true end
		end
		-- All spells returned 0/nil/error — fall through to distance check
	end
	return CheckInteractDistance(unit, 4) and true or false
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

	-- v3.2.1: Raid-marked mobs ALWAYS shown (highest priority after target)
	if filter.icon(guid) and filter.attackable(guid) then
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
