if not Cursive.superwow then
	return
end

-- Local-cache frequently used globals
local UnitExists = UnitExists
local UnitIsDead = UnitIsDead
local GetTime = GetTime
local GetRaidTargetIndex = GetRaidTargetIndex
local strsub = string.sub
local pairs = pairs

-- add (1) for first stack of buffs/debuffs
-- other addons already do this, avoid having to parse both formats
AURAADDEDOTHERHELPFUL = "%s gains %s (1)."
AURAADDEDOTHERHARMFUL = "%s is afflicted by %s (1)."
AURAADDEDSELFHARMFUL = "You are afflicted by %s (1)."
AURAADDEDSELFHELPFUL = "You gain %s (1)."

Cursive.core = CreateFrame("Frame", "Cursive", UIParent)

Cursive.core.tooltipScan = CreateFrame("GameTooltip", "CursiveTooltipScan", UIParent, "GameTooltipTemplate")

Cursive.core.guids = {}
Cursive.core._guidCount = 0

-- v4.0.6: GUID cap to prevent O(N) explosion in BGs (AV = 80+ units)
local GUID_CAP = 60

-- v4.1.1: LRU TTL for stale-GUID eviction (seconds without refresh).
local LRU_TTL = 30

-- v4.0.6: Check if GUID is high-priority (target, raid-marked, or has our curses)
-- v4.1.1: Moved above add() so both add() and addGuid() can enforce the cap.
local function isHighPriorityGuid(guid)
	local _, targetGuid = UnitExists("target")
	if targetGuid and targetGuid == guid then return true end
	if GetRaidTargetIndex(guid) then return true end
	if Cursive.curses and Cursive.curses.guids and Cursive.curses.guids[guid] then return true end
	return false
end

Cursive.core.add = function(unit)
	local _, guid = UnitExists(unit)

	if guid and not UnitIsDead(unit) then
		if not Cursive.core.guids[guid] then
			-- v4.1.1: Enforce cap for passive UNIT_COMBAT adds as well.
			-- Previously only addGuid() enforced the cap; add() was a cap-bypass
			-- once we routed UNIT_COMBAT tokens here (Bug #1 fix).
			if Cursive.core._guidCount >= GUID_CAP and not isHighPriorityGuid(guid) then
				return
			end
			Cursive.core._guidCount = Cursive.core._guidCount + 1
		end
		Cursive.core.guids[guid] = GetTime()
	end
end

Cursive.core.addGuid = function(guid)
	-- Already tracked -- just refresh timestamp
	if Cursive.core.guids[guid] then
		Cursive.core.guids[guid] = GetTime()
		return
	end
	-- check if first two characters are 0x
	if strsub(guid, 1, 2) ~= "0x" then
		return
	end
	-- v4.0.6: Enforce GUID cap -- drop low-priority adds (UNIT_COMBAT spam in AV)
	if Cursive.core._guidCount >= GUID_CAP then
		if not isHighPriorityGuid(guid) then
			return
		end
	end
	if UnitExists(guid) and not UnitIsDead(guid) then
		Cursive.core._guidCount = Cursive.core._guidCount + 1
		Cursive.core.guids[guid] = GetTime()
	end
end

Cursive.core.remove = function(guid)
	if Cursive.core.guids[guid] then
		Cursive.core.guids[guid] = nil
		Cursive.core._guidCount = Cursive.core._guidCount - 1
		if Cursive.core._guidCount < 0 then Cursive.core._guidCount = 0 end
	end
end

-- v4.1.1: LRU evict stale non-priority GUIDs (>LRU_TTL seconds without refresh).
-- Complements the relaxed UNIT_COMBAT acquisition path: keeps _guidCount healthy
-- so legitimate new GUIDs can always enter when the cap is near-full.
Cursive.core.evictStale = function()
	local now = GetTime()
	for guid, lastSeen in pairs(Cursive.core.guids) do
		if (now - lastSeen) > LRU_TTL and not isHighPriorityGuid(guid) then
			Cursive.core.guids[guid] = nil
			Cursive.core._guidCount = Cursive.core._guidCount - 1
			if Cursive.core._guidCount < 0 then Cursive.core._guidCount = 0 end
		end
	end
end

Cursive.core.disable = function()
	Cursive.core:UnregisterAllEvents()
	Cursive.core.guids = {}
	Cursive.core._guidCount = 0
end

Cursive.core.enable = function()
	-- unitstr
	Cursive.core:RegisterEvent("PLAYER_TARGET_CHANGED")
	-- arg1
	Cursive.core:RegisterEvent("UNIT_COMBAT") -- this can get called with player/target/raid1 etc
	Cursive.core:RegisterEvent("UNIT_MODEL_CHANGED")
end

Cursive.core:SetScript("OnEvent", function()
	-- v4.1.1 FIX: Localize event/arg globals immediately (volatile in Vanilla 1.12).
	local evt = event
	local a1 = arg1
	if evt == "PLAYER_TARGET_CHANGED" then
		this.add("target")
	elseif evt == "UNIT_COMBAT" then
		-- v4.1.1 FIX (Bug #1): arg1 is a unit token (e.g. "raid5target"), not a GUID.
		-- The 0x-prefix guard in addGuid() rejected tokens silently, making
		-- UNIT_COMBAT a dead passive-acquisition path since v4.0.6. Route through
		-- add() which resolves the token via UnitExists().
		this.add(a1)
	else
		-- UNIT_MODEL_CHANGED — arg1 IS a GUID here (SuperWoW semantics)
		this.addGuid(a1)
	end
end)

-- v4.1.1: Drive LRU-Evict from core frame's OnUpdate, throttled to 2Hz.
local _lruTick = 0
Cursive.core:SetScript("OnUpdate", function()
	local now = GetTime()
	if now >= _lruTick then
		_lruTick = now + 0.5
		Cursive.core.evictStale()
	end
end)
