if not Cursive.superwow then
	return
end
local L = AceLibrary("AceLocale-2.2"):new("Cursive")

-- Local-cache frequently used globals
local GetTime = GetTime
local UnitExists = UnitExists
local UnitDebuff = UnitDebuff
local UnitBuff = UnitBuff
local UnitName = UnitName
local UnitClass = UnitClass
local UnitResistance = UnitResistance
local pairs = pairs
local floor = math.floor

-- Test Overlay: skip real API calls for fake GUIDs
local TEST_PREFIX = "CURSIVE_TEST_"
local function IsTestGuid(guid)
    if not guid then return false end
    return string.find(guid, TEST_PREFIX, 1, true) == 1
end
local ceil = math.ceil
local strfind = string.find
local strlower = string.lower
local strformat = string.format

local _, playerClassName = UnitClass("player")

local curses = {
	trackedCurseIds = {},
	trackedCurseNamesToTextures = {},
	trackedCurseNameRanksToSpellSlots = {},
	-- v3.2: Track player's own shared debuff casts for border color detection
	-- Format: playerOwnedCasts[targetGuid][debuffKey] = timestamp
	playerOwnedCasts = {},
	conflagrateSpellIds = {
		[17962] = true,
		[18930] = true,
		[18931] = true,
		[18932] = true,
	},
	darkHarvestSpellIds = {
		[52550] = true,
		[52551] = true,
		[52552] = true,
	},
	darkHarvestData = {},
	guids = {},
	isChanneling = false,
	pendingCast = {},
	resistSoundGuids = {},
	expiringSoundGuids = {},
	requestedExpiringSoundGuids = {}, -- guid added on spellcast, moved to expiringSoundGuids once rendered by ui
	previousComboPoints = 0,
	comboPoints = 0,
	lastFerociousBiteTime = 0,
	lastFerociousBiteTargetGuid = 0,
	lastMoltenBlastTargetGuid = 0,

	sharedDebuffs = {},      -- populated by LoadCurses() from shared_debuffs.lua
	sharedDebuffGuids = {},  -- populated by LoadCurses(), tracks active debuffs per target
	sharedDebuffMeta = {},   -- populated by LoadCurses(), metadata (category, stacks, isProc, etc.)
	-- Reverse lookup: spellID -> debuffKey (built in LoadCurses for fast event handling)
	sharedDebuffSpellLookup = {},
	-- Reverse lookup: trigger spellID -> debuffKey (for proc-based debuffs)
	sharedDebuffTriggerLookup = {},
	-- v3.2.1: Proc refresh tracking
	-- procExpected[targetGuid][debuffKey] = timestamp — set when trigger spell cast detected
	procExpected = {},
	-- lastProcStacks[targetGuid][debuffKey] = stackCount — for stack-change detection
	lastProcStacks = {},

	-- Whitelist of mobs that can bleed (for rake tracking at client debuff cap)
	mobsThatBleed = {
		["0xF13000F1F3276A33"] = true, -- Keeper Gnarlmoon
		["0xF13000F1FA276A32"] = true, -- Ley-Watcher Incantagos
		["0xF13000EA3F276C05"] = true, -- King
		["0xF13000EA31279058"] = true, -- Queen
		["0xF13000EA43276C06"] = true, -- Bishop
		["0xF13000EA44279044"] = true, -- Pawn
		["0xF13000EA42276C07"] = true, -- Rook
		["0xF13000EA4D05DA44"] = true, -- Sanv Tas'dal
		["0xF13000EA57276C04"] = true, -- Kruul
		["0xF130016C95276DAF"] = true, -- Mephistroth

		["0xF130003E5401591A"] = true, --Anub'Rekhan
		["0xF130003E510159B0"] = true, --Grand Widow Faerlina
		["0xF130003E500159A3"] = true, --Maexxna
		["0xF130003EBD01598C"] = true, --Razuvious
		["0xF130003EBC01599F"] = true, --Gothik
		["0xF130003EBF015AB2"] = true, --Zeliek
		["0xF130003EBE015AB3"] = true, --Mograine
		["0xF130003EC1015AB1"] = true, --Blaumeux
		["0xF130003EC0015AB0"] = true, --Thane
		["0xF130003E52015824"] = true, --Noth
		["0xF130003E4001588D"] = true, --Heigan
		["0xF130003E8B0158A2"] = true, --Loatheb
		["0xF130003E9C0158EA"] = true, --Patchwerk
		["0xF130003E3B0158EF"] = true, --Grobbulus
		["0xF130003E3C0158F0"] = true, --Gluth
		["0xF130003E380159A0"] = true, --Thaddius
		["0xF130003E75015AB4"] = true, --Sapphiron
		["0xF130003E76015AED"] = true, --Kel'Thuzad
	},
}

-- Bleed-immune creature types (Elementals, Undead, Mechanical cannot bleed)
local BLEED_IMMUNE_TYPES = {
	["Elemental"] = true,
	["Undead"] = true,
	["Mechanical"] = true,
}

-- Check if a unit can receive bleed effects
local function CanApplyBleed(guid)
	if IsTestGuid(guid) then return true end
	if not UnitExists(guid) then
		return true -- Can't check, assume can bleed
	end
	
	local creatureType = UnitCreatureType(guid)
	if creatureType and BLEED_IMMUNE_TYPES[creatureType] then
		return false
	end
	
	return true
end

-- combat events for curses
local fades_test = L["(.+) fades from (.+)"]
local resist_test = L["Your (.+) was resisted by (.+)"]
local missed_test = L["Your (.+) missed (.+)"]
local parry_test = L["Your (.+) is parried by (.+)"]
local immune_test = L["Your (.+) fail.+\. (.+) is immune"]
local block_test = L["Your (.+) was blocked by (.+)"]
local dodge_test = L["Your (.+) was dodged by (.+)"]

local molten_blast_test = L["Your Molten Blast(.+)for .+ Fire damage"]

local lastGuid = nil

-- I think depending on ping the combo point used event can fire either before or after your ability cast
function curses:GetComboPointsUsed()
	if curses.comboPoints == 0 then
		return curses.previousComboPoints
	else
		return curses.comboPoints
	end
end


function curses:LoadCurses()
	-- reset dicts
	curses.trackedCurseIds = {}
	curses.trackedCurseNamesToTextures = {}
	curses.trackedCurseNameRanksToSpellSlots = {}

	curses.isWarlock = playerClassName == "WARLOCK"
	curses.isPriest = playerClassName == "PRIEST"
	curses.isMage = playerClassName == "MAGE"
	curses.isDruid = playerClassName == "DRUID"
	curses.isHunter = playerClassName == "HUNTER"
	curses.isRogue = playerClassName == "ROGUE"
	curses.isShaman = playerClassName == "SHAMAN"
	curses.isWarrior = playerClassName == "WARRIOR"

	-- curses to track
	if curses.isWarlock then
		curses.trackedCurseIds = getWarlockSpells()
	elseif curses.isPriest then
		curses.trackedCurseIds = getPriestSpells()
	elseif curses.isMage then
		curses.trackedCurseIds = getMageSpells()
	elseif curses.isDruid then
		curses.trackedCurseIds = getDruidSpells()
	elseif curses.isHunter then
		curses.trackedCurseIds = getHunterSpells()
	elseif curses.isRogue then
		curses.trackedCurseIds = getRogueSpells()
	elseif curses.isShaman then
		curses.trackedCurseIds = getShamanSpells()
	elseif curses.isWarrior then
		curses.trackedCurseIds = getWarriorSpells()
	end

	-- load shared debuffs (v3.2: full metadata structure)
	local sharedDebuffData = getSharedDebuffs()
	curses.sharedDebuffs = {}
	curses.sharedDebuffGuids = {}
	curses.sharedDebuffMeta = {}
	curses.sharedDebuffSpellLookup = {}
	curses.sharedDebuffTriggerLookup = {}

	-- v3.2.1: Target Armor cache — stores live + total (highest seen) armor per GUID
	curses.armorCache = {}  -- guid -> { live = number, total = number }

	-- v3.2: Expose Armor — armor reduction per combo point, per rank (TurtleWoW values)
	-- aDF-style: track frame-by-frame armor changes to detect exact EA reduction
	curses.exposeArmorPerCP = {
		[8647]  = 80,   -- Rank 1: 80 armor per CP
		[8649]  = 145,  -- Rank 2: 145 armor per CP
		[8650]  = 210,  -- Rank 3: 210 armor per CP
		[11197] = 275,  -- Rank 4: 275 armor per CP
		[11198] = 340,  -- Rank 5: 340 armor per CP
	}
	curses.exposeArmorTalentMults = { 1.00, 1.25, 1.50 } -- 0/1/2 talent points
	-- Armor monitor state per target
	curses.armorMonitor = {} -- targetGuid -> { prevArmor, baseArmor, expectingEA, eaSpellID, monitorUntil }

	for debuffKey, data in pairs(sharedDebuffData) do
		-- Build flat spell lookup (backward compatible: curses.sharedDebuffs.faeriefire[spellID])
		curses.sharedDebuffs[debuffKey] = {}
		if data.spells then
			for spellID, spellData in pairs(data.spells) do
				curses.sharedDebuffs[debuffKey][spellID] = spellData
				-- Reverse lookup: spellID -> debuffKey
				curses.sharedDebuffSpellLookup[spellID] = debuffKey
			end
		end

		-- Initialize guid tracking table
		curses.sharedDebuffGuids[debuffKey] = {}

		-- Store metadata
		curses.sharedDebuffMeta[debuffKey] = {
			category = data.category,
			class = data.class,
			raidRelevant = data.raidRelevant,
			stacks = data.stacks,
			isProc = data.isProc,
			triggerSpells = data.triggerSpells,
			displayStacks = data.displayStacks,
			exclusiveWith = data.exclusiveWith,
		}

		-- Build trigger spell reverse lookup for proc-based debuffs
		if data.isProc and data.triggerSpells then
			for _, triggerID in ipairs(data.triggerSpells) do
				curses.sharedDebuffTriggerLookup[triggerID] = debuffKey
			end
		end

		-- Initialize default setting if not set
		if Cursive.db.profile.shareddebuffs[debuffKey] == nil then
			-- Raid-relevant debuffs default to ON for existing faeriefire users
			if debuffKey == "faeriefire" then
				-- keep existing setting
			else
				Cursive.db.profile.shareddebuffs[debuffKey] = false
			end
		end
	end

	-- go through spell slots and
	local i = 1
	while true do
		local spellname, spellrank = GetSpellName(i, BOOKTYPE_SPELL)
		if not spellname then
			break
		end

		if spellrank == "" then
			spellrank = L["Rank 1"]
		end

		curses.trackedCurseNameRanksToSpellSlots[strlower(spellname) .. spellrank] = i
		i = i + 1
	end

	for id, data in pairs(curses.trackedCurseIds) do
		-- get the texture
		local name, rank, texture = SpellInfo(id)
		-- update trackedCurseNamesToTextures
		curses.trackedCurseNamesToTextures[data.name] = texture
		-- update trackedCurseIds
		curses.trackedCurseIds[id].texture = texture
	end

	if curses.isDruid or curses.isRogue then
		Cursive:RegisterEvent("PLAYER_COMBO_POINTS", function()
			local currentComboPoints = GetComboPoints()
			if curses.isDruid and currentComboPoints >= curses.comboPoints then
				-- combo points did not decrease, check if Ferocious Bite was used is the last .5 sec
				if GetTime() - curses.lastFerociousBiteTime < 0.5 and
						curses.lastFerociousBiteTargetGuid and
						curses.lastFerociousBiteTargetGuid ~= 0 then

					-- check if Rip active
					local rip = L["rip"]
					if curses:HasCurse(rip, curses.lastFerociousBiteTargetGuid, 0) then
						curses.guids[curses.lastFerociousBiteTargetGuid][rip]["start"] = GetTime() -- reset start time to current time
					end

					-- check if Rake active
					local rake = L["rake"]
					if curses:HasCurse(rake, curses.lastFerociousBiteTargetGuid, 0) then
						curses.guids[curses.lastFerociousBiteTargetGuid][rake]["start"] = GetTime() -- reset start time to current time
					end
				end
			end
			curses.previousComboPoints = curses.comboPoints
			curses.comboPoints = currentComboPoints
		end)
	end

	curses:CheckEyeOfDormantCorruption()

	Cursive:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function()
		curses:CheckEyeOfDormantCorruption()
	end)
end

function curses:CheckEyeOfDormantCorruption()
	local trinketItemId = 55111

	for slot = 13, 14 do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local _, _, itemId = strfind(link, "item:(%d+)")
			if itemId and tonumber(itemId) == trinketItemId then
				curses.hasEyeOfDormantCorruption = true
				return
			end
		end
	end

	curses.hasEyeOfDormantCorruption = false
end

function curses:ScanTooltipForDuration(curseSpellID)
	-- scan spellbook for duration in case they have haste talent
	local nameRank = curses.trackedCurseIds[curseSpellID].name .. L["Rank"] .. " " .. curses.trackedCurseIds[curseSpellID].rank
	local spellSlot = curses.trackedCurseNameRanksToSpellSlots[nameRank]

	if spellSlot then
		Cursive.core.tooltipScan:SetOwner(Cursive.core.tooltipScan, "ANCHOR_NONE")
		Cursive.core.tooltipScan:ClearLines()
		Cursive.core.tooltipScan:SetSpell(spellSlot, BOOKTYPE_SPELL)
		local numLines = Cursive.core.tooltipScan:NumLines()
		if numLines and numLines > 0 then
			-- get the last line
			local text = getglobal("CursiveTooltipScan" .. "TextLeft" .. numLines):GetText()
			if text then
				local _, _, duration = strfind(text, L["curse_duration_format"])
				if duration then
					return tonumber(duration)
				end
			end
		end
	end

	return curses.trackedCurseIds[curseSpellID].duration
end

function curses:GetCurseDuration(curseSpellID)
	local duration
	local durationFromTooltip = false

	if curses.trackedCurseIds[curseSpellID].variableDuration then
		duration = curses:ScanTooltipForDuration(curseSpellID)
		durationFromTooltip = true
	elseif curses.trackedCurseIds[curseSpellID].calculateDuration then
		duration = curses.trackedCurseIds[curseSpellID].calculateDuration()
	else
		duration = curses.trackedCurseIds[curseSpellID].duration
	end

	local spellName = curses.trackedCurseIds[curseSpellID].name
	local baseDuration = curses.trackedCurseIds[curseSpellID].duration
	
	-- Eye of Dormant Corruption trinket handling
	-- v4.0.3: Always add +3 when trinket is equipped for these spells.
	-- The tooltip already shows haste-reduced duration (e.g. 16.8 instead of 18).
	-- The server does NOT add the trinket bonus to the tooltip — we must always add it.
	-- eyeExtended flag prevents premature removal when server debuff expires before addon timer.
	curses._lastEyeExtended = false
	if spellName == L["corruption"] or spellName == L["shadow word: pain"] then
		curses:CheckEyeOfDormantCorruption()
		if curses.hasEyeOfDormantCorruption then
			duration = duration + 3
			curses._lastEyeExtended = true
		end
	end

	return duration
end

function curses:ScanGuidForCurse(guid, curseSpellID)
	if IsTestGuid(guid) then return false end
	for i = 1, 64 do
		local _, _, _, spellID = UnitDebuff(guid, i)
		if spellID then
			if spellID == curseSpellID then
				return true
			end
		else
			break
		end
	end
	for i = 1, 64 do
		local _, _, spellID = UnitBuff(guid, i)
		if spellID then
			if spellID == curseSpellID then
				return true
			end
		else
			break
		end
	end

	return nil
end

function curses:GetLowercaseSpellName(spellName)
	spellName = strlower(spellName)

	-- handle faerie fire special case
	if curses.isDruid and strfind(spellName, L["faerie fire"]) then
		return L["faerie fire"]
	end

	return spellName
end

-- v3.2: Scan target debuffs for proc-based shared debuffs (ISB, Fire Vuln, etc.)
-- Called via ScheduleEvent after a trigger spell is cast
function curses.ScanForProcDebuff(self, debuffKey, targetGuid)
	if not curses.sharedDebuffs[debuffKey] then return end
	if not UnitExists(targetGuid) then return end

	local debuffSpells = curses.sharedDebuffs[debuffKey]
	for i = 1, 64 do
		local texture, stackCount, _, spellID = UnitDebuff(targetGuid, i)
		if not spellID then break end
		if debuffSpells[spellID] then
			local procSpellData = debuffSpells[spellID]
			-- v3.2.1 FIX: If already tracked in guids, only refresh timer when evidence exists
			-- Previously this was unconditional — caused phantom timer resets on every Shadow Bolt
			if procSpellData and curses.guids[targetGuid] and curses.guids[targetGuid][procSpellData.name] then
				local existing = curses.guids[targetGuid][procSpellData.name]
				existing.sharedTexture = texture
				local newStacks = stackCount or 0
				local meta = curses.sharedDebuffMeta[debuffKey]

				-- Check for actual evidence of refresh (same logic as ScanTargetForSharedDebuffs)
				local oldStacks = curses.lastProcStacks[targetGuid] and curses.lastProcStacks[targetGuid][debuffKey] or -1
				local stackChanged = (newStacks ~= oldStacks and oldStacks ~= -1)
				local isNewDebuff = (oldStacks == -1)
				local noTrigger = meta and (not meta.triggerSpells or table.getn(meta.triggerSpells) == 0)
				local elapsed = GetTime() - existing.start
				local halfDuration = (procSpellData.duration or 10) * 0.5
				local shouldRefresh = stackChanged or isNewDebuff or noTrigger or (elapsed > halfDuration)

				if shouldRefresh then
					existing.start = GetTime()
					existing.duration = procSpellData.duration
					existing.sharedStacks = newStacks
					if CursiveSVDebug then
						DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[SV] ScanProc REFRESH: "..tostring(procSpellData.name).." elapsed="..string.format("%.1f", elapsed).." stacks "..tostring(oldStacks).."->"..tostring(newStacks).."|r")
					end
				else
					-- No evidence of refresh — update stacks/texture only, keep timer
					existing.sharedStacks = newStacks
					if CursiveSVDebug then
						DEFAULT_CHAT_FRAME:AddMessage("|cFF888888[SV] ScanProc SKIP refresh: "..tostring(procSpellData.name).." elapsed="..string.format("%.1f", elapsed).." (< halfDur)|r")
					end
				end

				-- Track stacks for next comparison
				if not curses.lastProcStacks[targetGuid] then
					curses.lastProcStacks[targetGuid] = {}
				end
				curses.lastProcStacks[targetGuid][debuffKey] = newStacks
				return
			end
			-- No existing entry — queue for initial apply
			curses.sharedDebuffGuids[debuffKey][targetGuid] = {
				time = GetTime(),
				texture = texture,
				stacks = stackCount or 0,
				spellID = spellID,
			}
			-- v3.2.1 FIX: Ensure target is in core.guids for rendering
			Cursive.core.addGuid(targetGuid)
			-- v4.0.1 FIX: Run full shared debuff scan for this GUID
			-- Without this, Shadow Weaving on non-targeted mobs only shows initial state
			-- ScanTargetForSharedDebuffs updates stacks/timer in curses.guids directly
			curses:ScanTargetForSharedDebuffs(targetGuid)
			if CursiveSVDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[SV] ScanProc NEW: "..tostring(procSpellData and procSpellData.name).." queued|r")
			end
			return
		end
	end
end

-- v3.2.1: OnUpdate poller for Expose Armor — polls armor every frame after EA cast
-- This is more reliable than waiting for UNIT_AURA since armor changes may arrive late
if not CursiveEAPollerFrame then
	CursiveEAPollerFrame = CreateFrame("Frame")
	CursiveEAPollerFrame:Hide()
	CursiveEAPollerFrame:SetScript("OnUpdate", function()
		local now = GetTime()
		for targetGuid, mon in pairs(Cursive.curses.armorMonitor) do
			if mon.expectingEA and now <= mon.monitorUntil then
				-- SuperWoW: no need to check current target, GUID works directly
				Cursive.curses:CheckArmorChangeForEA(targetGuid)
			elseif mon.expectingEA and now > mon.monitorUntil then
				mon.expectingEA = false
				if CursiveEADebug then
					DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[EA Poll] Monitor expired for "..targetGuid.."|r")
				end
			end
		end
		-- Hide poller if no active monitors
		local anyActive = false
		for _, mon in pairs(Cursive.curses.armorMonitor) do
			if mon.expectingEA then
				anyActive = true
				break
			end
		end
		if not anyActive then
			CursiveEAPollerFrame:Hide()
		end
	end)
end

function curses:StartEAPoller()
	CursiveEAPollerFrame:Show()
end

-- v3.2: Check armor changes on target to detect Expose Armor CP (aDF-style)
-- Called from OnUpdate poller and UNIT_AURA
-- NOTE: UnitResistance() only accepts unit tokens ("target"), NOT GUIDs!
function curses:CheckArmorChangeForEA(targetGuid)
	local mon = curses.armorMonitor[targetGuid]
	if not mon or not mon.expectingEA then return end

	-- Check if monitor expired
	if GetTime() > mon.monitorUntil then
		mon.expectingEA = false
		return
	end

	-- SuperWoW: UnitResistance accepts GUIDs directly — no need to be targeting
	local armorNow = UnitResistance(targetGuid, 0) or 0

	-- Use baseArmor (armor without EA) for calculation, fall back to prevArmor
	local refArmor = mon.baseArmor or mon.prevArmor
	local armorDrop = refArmor - armorNow -- total EA reduction from base

	-- Debug output
	if CursiveEADebug then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[EA] base="..tostring(mon.baseArmor).." prev="..mon.prevArmor.." now="..armorNow.." drop="..armorDrop.." spellID="..tostring(mon.eaSpellID).."|r")
	end

	-- Only process if armor actually decreased from base
	if armorDrop <= 0 then
		-- Armor didn't drop (yet) — could be other changes, keep monitoring
		if CursiveEADebug then
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[EA] No drop yet, keep monitoring|r")
		end
		return
	end

	local basePerCP = curses.exposeArmorPerCP[mon.eaSpellID] or 340
	local comboPoints = 0
	local bestError = 999

	-- Try all talent multipliers (x1.00, x1.25, x1.50) and find cleanest CP fit
	for _, mult in ipairs(curses.exposeArmorTalentMults) do
		local perCP = basePerCP * mult
		local rawCP = armorDrop / perCP
		local roundedCP = floor(rawCP + 0.5)
		if CursiveEADebug then
			DEFAULT_CHAT_FRAME:AddMessage("|cFF888888[EA] mult="..mult.." perCP="..perCP.." raw="..strformat("%.2f", rawCP).." round="..roundedCP.."|r")
		end
		if roundedCP >= 1 and roundedCP <= 5 then
			local err = math.abs(rawCP - roundedCP)
			if err < bestError then
				bestError = err
				comboPoints = roundedCP
			end
		end
	end

	if CursiveEADebug then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[EA] RESULT: cp="..comboPoints.." err="..strformat("%.3f", bestError).."|r")
	end

	-- Accept result if close enough (tolerance: within 0.3 of a clean integer)
	if comboPoints > 0 and bestError < 0.3 then
		-- Ensure sharedDebuffGuids entry exists
		if not curses.sharedDebuffGuids["exposearmor"] then
			curses.sharedDebuffGuids["exposearmor"] = {}
		end
		local entry = curses.sharedDebuffGuids["exposearmor"][targetGuid]
		if entry and type(entry) == "table" then
			entry.stacks = comboPoints
			entry.spellID = mon.eaSpellID
			entry.time = GetTime()
		else
			-- Create entry if it doesn't exist yet (e.g. UNIT_AURA hasn't fired yet)
			curses.sharedDebuffGuids["exposearmor"][targetGuid] = {
				time = GetTime(),
				texture = nil,
				stacks = comboPoints,
				spellID = mon.eaSpellID,
			}
		end
		-- Also update if already in guids display table
		local eaName = L["expose armor"]
		if curses.guids[targetGuid] and curses.guids[targetGuid][eaName] then
			curses.guids[targetGuid][eaName].sharedStacks = comboPoints
			if CursiveEADebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[EA] Set sharedStacks="..comboPoints.." on guids["..eaName.."]|r")
			end
		elseif CursiveEADebug then
			-- Debug: show what keys exist for this target
			local keys = ""
			if curses.guids[targetGuid] then
				for k, _ in pairs(curses.guids[targetGuid]) do
					keys = keys .. tostring(k) .. ", "
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800[EA] guids key '"..tostring(eaName).."' not found. Keys: "..keys.."|r")
		end
	end

	-- Done monitoring — armor change detected and processed
	mon.expectingEA = false
	-- Update prevArmor for next time (aDF-style continuous tracking)
	mon.prevArmor = armorNow
end

-- v3.2: Scan target for all enabled shared debuffs (reliable detection for procs + direct casts)
-- Called on UNIT_AURA for target, and periodically via UI update
function curses:ScanTargetForSharedDebuffs(targetGuid)
	if not targetGuid then return end
	if not UnitExists(targetGuid) then return end

	local now = GetTime()
	for debuffKey, debuffSpells in pairs(curses.sharedDebuffs) do
		if Cursive.db.profile.shareddebuffs[debuffKey] then
			local found = false
			-- Scan all debuffs on the target
			for i = 1, 64 do
				local texture, stackCount, _, spellID = UnitDebuff(targetGuid, i)
				if not spellID then break end
				if debuffSpells[spellID] then
					found = true
					local spellData = debuffSpells[spellID]

					-- v3.2.1 FIX: Check if this debuff is already applied in guids table
					-- If yes, update texture/stacks and check for timer refresh (proc debuffs)
					-- IMPORTANT: own curses (currentPlayer=true) have precise timing from ApplyCurse
					-- and must NOT be overwritten by the shared debuff system
					local alreadyApplied = false
					if spellData and curses.guids[targetGuid] then
						local name = spellData.name
						local existing = curses.guids[targetGuid][name]
						if existing then
							alreadyApplied = true
							if existing.currentPlayer == false then
								-- Update live texture
								existing.sharedTexture = texture
								local meta = curses.sharedDebuffMeta[debuffKey]
								local newStacks = stackCount or 0

								-- v3.2.1 FIX: Detect proc debuff refresh
								-- Only reset timer when we have EVIDENCE the debuff was actually refreshed:
								-- 1. Stack count changed (e.g. SV 2→4 or 4→3)
								-- 2. Debuff is new (first scan, oldStacks == -1)
								-- 3. Weapon procs without triggerSpells (noTrigger)
								-- NOTE: procExpected alone is NOT enough — Shadow Bolt casts set this flag
								-- continuously but SV at max stacks does NOT refresh on every hit
								if meta and meta.isProc then
									local oldStacks = curses.lastProcStacks[targetGuid] and curses.lastProcStacks[targetGuid][debuffKey] or -1
									local stackChanged = (newStacks ~= oldStacks and oldStacks ~= -1)
									local isNewDebuff = (oldStacks == -1)

									-- Consume procExpected flag if present (prevents stale flags)
									local procTriggered = false
									if curses.procExpected[targetGuid] and curses.procExpected[targetGuid][debuffKey] then
										local triggerTime = curses.procExpected[targetGuid][debuffKey]
										if (now - triggerTime) < 2.0 then
											procTriggered = true
										end
										-- Always consume to prevent stale flags
										curses.procExpected[targetGuid][debuffKey] = nil
									end

									-- v3.2.1: Weapon procs without triggerSpells (Thunderfury, Nightfall, Annihilator)
								-- always refresh timer on scan since we can't track the trigger
								local noTrigger = (not meta.triggerSpells or table.getn(meta.triggerSpells) == 0)

								-- v3.2.1 FIX: Only reset timer on actual evidence of refresh
								-- For stacking procs: stack count change is reliable signal
								-- For non-stacking procs (SV): only refresh if debuff is new OR
								-- enough of its duration has elapsed that a real refresh is plausible
								-- (prevents timer reset from Shadow Bolt spam when SV is still fresh)
								-- noTrigger: weapon procs always refresh (no other signal available)
								local elapsed = now - existing.start
								local halfDuration = (spellData.duration or 10) * 0.5
								local procRefreshValid = procTriggered and (isNewDebuff or elapsed > halfDuration)

								if stackChanged or noTrigger or procRefreshValid then
										-- Debuff was refreshed → reset timer
										existing.start = now
										existing.duration = spellData.duration
										-- v3.2.1: If OUR trigger spell caused this, mark as own debuff
										-- Check playerOwnedCasts to distinguish own vs other player's procs
										if procTriggered and curses.playerOwnedCasts[targetGuid] and curses.playerOwnedCasts[targetGuid][debuffKey] then
											local ownCastTime = curses.playerOwnedCasts[targetGuid][debuffKey]
											if (now - ownCastTime) < 2.0 then
												existing.currentPlayer = true
											end
										end
										if CursiveSVDebug then
											DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[SV] REFRESH: "..tostring(name).." stacks "..tostring(oldStacks).."->"..tostring(newStacks).." procFlag="..tostring(procTriggered).." noTrig="..tostring(noTrigger).."|r")
										end
									end

									-- Track stacks for next comparison
									if not curses.lastProcStacks[targetGuid] then
										curses.lastProcStacks[targetGuid] = {}
									end
									curses.lastProcStacks[targetGuid][debuffKey] = newStacks
								end

								-- Update stacks (except EA which uses armor-diff calculated CP)
								if debuffKey ~= "exposearmor" then
									existing.sharedStacks = newStacks
								end
							end
						end
					end

					-- Only queue for initial apply if not already tracked
					if not alreadyApplied then
						if not curses.sharedDebuffGuids[debuffKey] then
							curses.sharedDebuffGuids[debuffKey] = {}
						end
						curses.sharedDebuffGuids[debuffKey][targetGuid] = {
							time = now,
							texture = texture,
							stacks = stackCount or 0,
							spellID = spellID,
						}
					end
					break
				end
			end
			-- v3.2: If shared debuff was NOT found on target but was tracked, remove it
			if not found and curses.sharedDebuffGuids[debuffKey] and curses.sharedDebuffGuids[debuffKey][targetGuid] then
				-- v3.2.1: Don't remove EA tracking while armor monitor is expecting a re-application
				if debuffKey == "exposearmor" and curses.armorMonitor[targetGuid] and curses.armorMonitor[targetGuid].expectingEA then
					if CursiveEADebug then
						DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[EA] Debuff temporarily gone but monitor active — keeping tracking|r")
					end
				else
					curses.sharedDebuffGuids[debuffKey][targetGuid] = nil
					-- v3.2: Reset armor monitor when EA actually falls off (no pending re-apply)
					if debuffKey == "exposearmor" and curses.armorMonitor[targetGuid] then
						curses.armorMonitor[targetGuid].expectingEA = false
						-- Reset baseArmor so next cast captures fresh base (SuperWoW: GUID direct)
						local freshArmor = UnitResistance(targetGuid, 0) or 0
						curses.armorMonitor[targetGuid].prevArmor = freshArmor
						curses.armorMonitor[targetGuid].baseArmor = freshArmor
						if CursiveEADebug then
							DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[EA REMOVED] baseArmor reset to "..freshArmor.."|r")
						end
					end
				end
				-- Also remove from guids display table
				local spellData = nil
				for sid, sd in pairs(debuffSpells) do
					spellData = sd
					break
				end
				if spellData and curses.guids[targetGuid] and curses.guids[targetGuid][spellData.name] then
					-- Only remove if it was a shared debuff (not own)
					if curses.guids[targetGuid][spellData.name].currentPlayer == false then
						curses.guids[targetGuid][spellData.name] = nil
					end
				end
			end
		end
	end
end

-- v3.2: Clean up expired shared debuffs from tracking tables
function curses:CleanupSharedDebuffs()
	local now = GetTime()

	-- v3.2.1 FIX: Clean up stale procExpected flags (>2s old)
	for guid, keys in pairs(curses.procExpected) do
		local empty = true
		for key, timestamp in pairs(keys) do
			if (now - timestamp) > 2.0 then
				keys[key] = nil
			else
				empty = false
			end
		end
		if empty then
			curses.procExpected[guid] = nil
		end
	end

	for debuffKey, targets in pairs(curses.sharedDebuffGuids) do
		local maxDuration = 0
		-- Find the longest duration for this debuff type
		if curses.sharedDebuffs[debuffKey] then
			for _, spellData in pairs(curses.sharedDebuffs[debuffKey]) do
				if spellData.duration and spellData.duration > maxDuration then
					maxDuration = spellData.duration
				end
			end
		end
		-- Remove entries older than max duration + buffer
		if maxDuration > 0 then
			for targetGuid, data in pairs(targets) do
				local appliedTime = data
				-- v3.2: data can be a table {time=...} or a plain timestamp
				if type(data) == "table" then
					appliedTime = data.time or 0
				end
				if now - appliedTime > maxDuration + 5 then
					targets[targetGuid] = nil
				end
			end
		end
	end

	-- v3.2.1: Clean up armor cache alongside shared debuffs
	curses:CleanupArmorCache()
end

Cursive:RegisterEvent("LEARNED_SPELL_IN_TAB", function()
	-- reload curses in case spell slots changed
	curses:LoadCurses()
end)

-- v3.2: Scan target debuffs when auras change (catches procs, direct casts, everything)
Cursive:RegisterEvent("UNIT_AURA", function()
	local a1 = arg1
	if a1 == "target" then
		local _, targetGuid = UnitExists("target")
		if targetGuid then
			curses:ScanTargetForSharedDebuffs(targetGuid)
			-- v3.2: Check armor monitor for Expose Armor CP detection (aDF-style)
			if curses.armorMonitor[targetGuid] and curses.armorMonitor[targetGuid].expectingEA then
				curses:CheckArmorChangeForEA(targetGuid)
			end
		end
	end
end)

-- v3.2: Also scan when target changes
Cursive:RegisterEvent("PLAYER_TARGET_CHANGED", function()
	local _, targetGuid = UnitExists("target")
	if targetGuid then
		curses:ScanTargetForSharedDebuffs(targetGuid)
	end
end)

-- Finalize Dark Harvest reduction when channeling stops
local function FinalizeDarkHarvest()
	if curses.darkHarvestData.targetGuid then
		local targetGuid = curses.darkHarvestData.targetGuid
		local dhEndTime = GetTime()
		
		if curses.guids[targetGuid] then
			for curseName, curseData in pairs(curses.guids[targetGuid]) do
				if curseData.dhStartTime then
					-- Calculate how long DH was active for this DoT
					local dhActiveTime = dhEndTime - curseData.dhStartTime
					-- Add 40% of that time as extra reduction (1.4x speed = 0.4 extra per second)
					curseData.dhAccumulatedReduction = (curseData.dhAccumulatedReduction or 0) + (dhActiveTime * 0.4)
					curseData.dhStartTime = nil
				end
			end
		end
		
		curses.darkHarvestData = {}
	end
end

local function StopChanneling()
	FinalizeDarkHarvest()
	curses.isChanneling = false
end

-- v3.2.1: Update armor cache for a GUID (called from ui.lua OnUpdate)
function curses:UpdateArmorCache(guid)
	if not curses.armorCache then curses.armorCache = {} end
	if not UnitResistance then return end
	if IsTestGuid(guid) then
		-- v4.0: Fake armor data for Test Overlay
		local entry = curses.armorCache[guid]
		if not entry then
			local fakeTotal = math.random(3000, 6000)
			local fakeReduced = math.random(500, 2000)
			local fakeLive = fakeTotal - fakeReduced
			curses.armorCache[guid] = { live = fakeLive, total = fakeTotal }
		end
		return
	end
	local _, effective = UnitResistance(guid, 0)
	if not effective then return end
	effective = math.max(0, effective)

	local entry = curses.armorCache[guid]
	if not entry then
		curses.armorCache[guid] = { live = effective, total = effective }
	else
		entry.live = effective
		if effective > entry.total then
			entry.total = effective
		end
	end
end

-- v3.2.1: Get armor data for a GUID (returns live, total, removed or nil)
function curses:GetArmorData(guid)
	local entry = curses.armorCache[guid]
	if not entry then return nil end
	return entry.live, entry.total, entry.live - entry.total
end

-- v3.2.1: Clean up armor cache for GUIDs we no longer track
function curses:CleanupArmorCache()
	if not curses.armorCache then return end
	for guid, _ in pairs(curses.armorCache) do
		if not curses.guids[guid] then
			curses.armorCache[guid] = nil
		end
	end
end

Cursive:RegisterEvent("SPELLCAST_CHANNEL_START", function()
	curses.isChanneling = true
end);
Cursive:RegisterEvent("SPELLCAST_CHANNEL_STOP", StopChanneling);
Cursive:RegisterEvent("SPELLCAST_INTERRUPTED", StopChanneling);
Cursive:RegisterEvent("SPELLCAST_FAILED", StopChanneling);

-- Start Dark Harvest tracking for all affected DoTs on target
function curses:StartDarkHarvestTracking(targetGuid)
	if not curses.guids[targetGuid] then return end
	
	local now = GetTime()
	
	for curseName, curseData in pairs(curses.guids[targetGuid]) do
		-- Check if this spell is affected by Dark Harvest
		if curses.trackedCurseIds[curseData.spellID] and 
		   curses.trackedCurseIds[curseData.spellID].darkHarvest then
			curseData.dhStartTime = now
		end
	end
end

Cursive:RegisterEvent("UNIT_CASTEVENT", function(casterGuid, targetGuid, event, spellID, castDuration)
	-- Debug: Log own cast/channel spell IDs (enable with /script CursiveCastDetect=true)
	if CursiveCastDetect and (event == "CAST" or event == "CHANNEL") then
		local _, pg = UnitExists("player")
		if casterGuid == pg then
			local trig = curses.sharedDebuffTriggerLookup[spellID] or curses.sharedDebuffSpellLookup[spellID] or "-"
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00[DETECT] "..event.." id="..tostring(spellID).." ="..trig.."|r")
		end
	end
	-- Debug: Log castDuration for EA spells
	if CursiveEACastLog and curses.sharedDebuffSpellLookup and curses.sharedDebuffSpellLookup[spellID] == "exposearmor" then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFF00FF[EA EVENT] event="..tostring(event).." spellID="..tostring(spellID).." castDuration="..tostring(castDuration).."|r")
	end
	-- v3.2.1: Check channel spells for proc triggers (e.g. Drain Soul -> SV)
	-- Channel events fire once at start — check for trigger spells immediately
	if event == "CHANNEL" then
		local triggerKey = curses.sharedDebuffTriggerLookup[spellID]
		if triggerKey and Cursive.db.profile.shareddebuffs[triggerKey] then
			if not curses.procExpected[targetGuid] then
				curses.procExpected[targetGuid] = {}
			end
			curses.procExpected[targetGuid][triggerKey] = GetTime()

			-- v3.2.1 FIX: Track own channel casts for border color detection
			-- Without this, own Drain Soul -> SV proc would show as foreign (wrong border)
			local _, playerGuid = UnitExists("player")
			if casterGuid == playerGuid then
				if not curses.playerOwnedCasts[targetGuid] then
					curses.playerOwnedCasts[targetGuid] = {}
				end
				curses.playerOwnedCasts[targetGuid][triggerKey] = GetTime()
			end

			-- Schedule scan shortly after channel starts (Shadow Weaving procs once per cast)
			-- Use unique event name with timestamp so consecutive Mind Flays don't cancel each other
			local scanID = targetGuid .. triggerKey .. GetTime()
			Cursive:ScheduleEvent(
				"scanProc" .. scanID,
				curses.ScanForProcDebuff, 0.5,
				curses, triggerKey, targetGuid
			)
			-- Second scan as safety net (latency, server delay)
			Cursive:ScheduleEvent(
				"scanProc2" .. scanID,
				curses.ScanForProcDebuff, 1.5,
				curses, triggerKey, targetGuid
			)
		end
	end

	-- immolate will fire both start and cast
	if event == "CAST" then
		local _, guid = UnitExists("player")
		if casterGuid ~= guid then
			-- v3.2: Check all shared debuffs via reverse lookup
			local debuffKey = curses.sharedDebuffSpellLookup[spellID]
			if debuffKey and Cursive.db.profile.shareddebuffs[debuffKey] then
				local meta = curses.sharedDebuffMeta[debuffKey]
				if not meta or not meta.isProc then
					-- v3.2: Expose Armor — activate frame-by-frame armor monitor (aDF-style)
					-- NOTE: UnitResistance() only accepts unit tokens, NOT GUIDs
					if debuffKey == "exposearmor" and curses.exposeArmorPerCP[spellID] then
						local mon = curses.armorMonitor[targetGuid]
						if not mon then
							mon = { prevArmor = 0, baseArmor = nil, expectingEA = false, eaSpellID = nil, monitorUntil = 0 }
							curses.armorMonitor[targetGuid] = mon
						end
						-- SuperWoW: UnitResistance accepts GUIDs — capture armor directly
						local armorNow = UnitResistance(targetGuid, 0) or 0
						mon.prevArmor = armorNow
						-- baseArmor = armor without any EA applied (set once, or when EA was removed)
						if not mon.baseArmor then
							mon.baseArmor = armorNow
						end
						if CursiveEADebug then
							DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[EA CAST] prevArmor="..mon.prevArmor.." baseArmor="..tostring(mon.baseArmor).." spellID="..spellID.." target="..targetGuid.."|r")
						end
						mon.expectingEA = true
						mon.eaSpellID = spellID
						mon.monitorUntil = GetTime() + 2.0 -- monitor for 2 seconds max
						-- Start OnUpdate poller for reliable armor change detection
						curses:StartEAPoller()
					end

					-- Direct cast debuff: mark for scanning (texture will be picked up by UNIT_AURA scan)
					-- v3.2.1: Remove exclusive debuff (e.g. Sunder replaces EA)
					curses:RemoveExclusiveDebuff(debuffKey, targetGuid)
					-- v3.2 FIX: Remove existing entry from guids so timer resets on re-cast
					local recastSpellData = curses.sharedDebuffs[debuffKey][spellID]
					if recastSpellData and curses.guids[targetGuid] then
						curses.guids[targetGuid][recastSpellData.name] = nil
					end
					curses.sharedDebuffGuids[debuffKey][targetGuid] = {
						time = GetTime(),
						texture = nil, -- will be filled by ScanTargetForSharedDebuffs
						stacks = 0,
						spellID = spellID,
					}
					-- v3.2.1 FIX: Ensure target is registered in core.guids for rendering
					-- Without this, mobs only tracked via UNIT_CASTEVENT may not appear in UI
					Cursive.core.addGuid(targetGuid)
				end
			end

			-- v3.2.1: Check if this cast triggers a proc-based debuff
			local triggerKey = curses.sharedDebuffTriggerLookup[spellID]
			if triggerKey and Cursive.db.profile.shareddebuffs[triggerKey] then
				-- Mark proc expected for this target (used by ScanTargetForSharedDebuffs)
				if not curses.procExpected[targetGuid] then
					curses.procExpected[targetGuid] = {}
				end
				curses.procExpected[targetGuid][triggerKey] = GetTime()
				-- Schedule a delayed scan for non-targeted mobs (backup)
				-- Use unique event name so consecutive casts don't cancel each other
				local scanID = targetGuid .. triggerKey .. GetTime()
				Cursive:ScheduleEvent(
					"scanProc" .. scanID,
					curses.ScanForProcDebuff, 0.5,
					curses, triggerKey, targetGuid
				)
			end

			return
		end

		-- store pending cast
		curses.pendingCast = {
			spellID = spellID,
			targetGuid = targetGuid,
			castDuration = castDuration
		}

		-- v3.2.1: Track player's own shared debuff casts for border color detection
		-- Check both direct debuff spells AND trigger spells (e.g. Shadow Bolt → Shadow Vulnerability)
		local ownDebuffKey = (curses.sharedDebuffSpellLookup and curses.sharedDebuffSpellLookup[spellID])
			or (curses.sharedDebuffTriggerLookup and curses.sharedDebuffTriggerLookup[spellID])
		if ownDebuffKey then
			if not curses.playerOwnedCasts[targetGuid] then
				curses.playerOwnedCasts[targetGuid] = {}
			end
			curses.playerOwnedCasts[targetGuid][ownDebuffKey] = GetTime()
		end

		-- v3.2.1: Check proc triggers for own casts (e.g. own Shadow Bolt -> ISB proc)
		local triggerKey = curses.sharedDebuffTriggerLookup[spellID]
		if triggerKey and Cursive.db.profile.shareddebuffs[triggerKey] then
			-- Mark proc expected for this target (used by ScanTargetForSharedDebuffs)
			if not curses.procExpected[targetGuid] then
				curses.procExpected[targetGuid] = {}
			end
			curses.procExpected[targetGuid][triggerKey] = GetTime()
			-- Schedule a delayed scan for non-targeted mobs (backup)
			-- Use unique event name so consecutive casts don't cancel each other
			local scanID = targetGuid .. triggerKey .. GetTime()
			Cursive:ScheduleEvent(
				"scanProc" .. scanID,
				curses.ScanForProcDebuff, 0.5,
				curses, triggerKey, targetGuid
			)
		end

		if curses.isDruid then
			-- track ferocious bite cast time and target
			if spellID == 22557 or
					spellID == 22568 or
					spellID == 22827 or
					spellID == 22828 or
					spellID == 22829 or
					spellID == 31018 then
				curses.lastFerociousBiteTime = GetTime()
				curses.lastFerociousBiteTargetGuid = targetGuid
			end
		end

		if curses.isShaman then
			if spellID >= 36916 and spellID <= 36921 then
				curses.lastMoltenBlastTargetGuid = targetGuid
			end
		end

		-- delay to check for resists/failures
		local delay = 0.2

		local _, _, nping = GetNetStats()
		-- ignore extreme pings
		if nping and nping > 0 and nping < 500 then
			delay = 0.05 + (nping / 1000.0) -- convert to seconds
		end

		if curses.trackedCurseIds[spellID] then
			lastGuid = targetGuid
			local duration = curses:GetCurseDuration(spellID) - delay
			Cursive:ScheduleEvent("addCurse" .. targetGuid .. curses.trackedCurseIds[spellID].name, curses.ApplyCurse, delay, self, spellID, targetGuid, GetTime(), duration)
		elseif curses.conflagrateSpellIds[spellID] then
			Cursive:ScheduleEvent("updateCurse" .. targetGuid .. L["conflagrate"], curses.UpdateCurse, delay, self, spellID, targetGuid, GetTime())
		end
	elseif event == "START" then
		if curses.trackedCurseIds[spellID] then
			local _, guid = UnitExists("player")
			if casterGuid ~= guid then
				return
			end

			-- store pending cast
			curses.pendingCast = {
				spellID = spellID,
				targetGuid = targetGuid,
				castDuration = castDuration
			}
		end
	elseif event == "FAIL" then
		if curses.trackedCurseIds[spellID] then
			local _, guid = UnitExists("player")
			if casterGuid ~= guid then
				return
			end
			-- clear pending cast
			curses.pendingCast = {}
		end
	elseif event == "CHANNEL" then
		-- Dark Harvest
		if curses.darkHarvestSpellIds[spellID] then
			local _, guid = UnitExists("player")
			if casterGuid ~= guid then
				return
			end

			local now = GetTime()
			
			-- Check if this is a NEW Dark Harvest (not the same one we already processed)
			local lastDHTime = curses.darkHarvestData.start or 0
			if now > lastDHTime + 1 then  -- At least 1 second since last DH
				-- Store Dark Harvest data
				curses.darkHarvestData = {
					spellID = spellID,
					targetGuid = targetGuid,
					start = now
				}
				
				-- Start tracking for all affected DoTs on this target
				curses:StartDarkHarvestTracking(targetGuid)
			end
		end
	end
end)

Cursive:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE",
		function(message)
			local spell_failed_tests = {
				resist_test,
				immune_test
			}
			-- only some classes have melee spells that need to check for dodge, parry, miss, block
			if playerClassName == "DRUID" or playerClassName == "HUNTER" or playerClassName == "ROGUE" then
				spell_failed_tests = {
					resist_test,
					immune_test,
					missed_test,
					parry_test,
					block_test,
					dodge_test
				}
			end

			local spellName, failedTarget
			for _, test in pairs(spell_failed_tests) do
				local _, _, foundSpell, foundTarget = strfind(message, test)
				if foundSpell and foundTarget then
					spellName = foundSpell
					failedTarget = foundTarget
					break
				end
			end

			if spellName and failedTarget then
				spellName = curses:GetLowercaseSpellName(spellName)

				curses.pendingCast = {}

				if curses.trackedCurseNamesToTextures[spellName] and lastGuid then
					Cursive:CancelScheduledEvent("addCurse" .. lastGuid .. spellName)
					-- check if sound should be played
					if curses:ShouldPlayResistSound(lastGuid) then
						PlaySoundFile("Interface\\AddOns\\Cursive\\Sounds\\resist.mp3")
					end
				elseif spellName == L["conflagrate"] and lastGuid then
					Cursive:CancelScheduledEvent("updateCurse" .. lastGuid .. spellName)
				end
				return
			end

			if curses.isShaman and strfind(message, molten_blast_test) then
				local flame_shock = L["flame shock"]
				if curses:HasCurse(flame_shock, curses.lastMoltenBlastTargetGuid, 0) then
					curses.guids[curses.lastMoltenBlastTargetGuid][flame_shock]["start"] = GetTime() -- reset start time to current time
				end
			end
		end
) -- resists

Cursive:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER", function(message)
	-- check if spell that faded is relevant
	local _, _, spellName, target = strfind(message, fades_test)
	if spellName and target then
		spellName = curses:GetLowercaseSpellName(spellName)
		if curses.trackedCurseNamesToTextures[spellName] then
			-- loop through targets with active curses
			for guid, data in pairs(curses.guids) do
				for curseName, curseData in pairs(data) do
					if curseName == spellName then
						-- see if target still has that curse
						if not curses:ScanGuidForCurse(guid, curseData.spellID) then
							-- v4.0.3: Eye of Dormant Corruption extends duration beyond server debuff
							-- Don't remove if trinket bonus time is still remaining
							local keepForTrinket = false
							if curses.hasEyeOfDormantCorruption and curseData.eyeExtended then
								local rawRemaining = curses:TimeRemainingRaw(curseData)
								if rawRemaining > 0.5 then
									keepForTrinket = true
								end
							end
							if not keepForTrinket then
								curses:RemoveCurse(guid, curseName)
							end
						end
					end
				end
			end
		end
	end
end
)

function curses:TimeRemainingRaw(curseData)
	local dhReduction = curseData.dhAccumulatedReduction or 0
	
	-- If Dark Harvest is currently active for this DoT, calculate live reduction
	if curseData.dhStartTime then
		local dhActiveTime = GetTime() - curseData.dhStartTime
		-- 1.4x speed means 0.4 extra seconds per real second
		dhReduction = dhReduction + (dhActiveTime * 0.4)
	end
	
	return curseData.duration - (GetTime() - curseData.start) - dhReduction
end

function curses:TimeRemaining(curseData)
	local remaining = curses:TimeRemainingRaw(curseData)
	
	local profile = Cursive.db.profile
	if remaining >= 100 then
		-- Return raw float for minute display (2m+)
		-- ui.lua uses ceil((remaining-30)/60) for midpoint transitions
	elseif (profile.curseshowdecimals and remaining < 10) or (profile.coloreddecimalduration and remaining < 5 and remaining > 0) then
		-- round to 1 decimal point
		remaining = floor(remaining * 10) / 10
	else
		remaining = ceil(remaining)
	end

	return remaining
end

function curses:EnableResistSound(guid)
	curses.resistSoundGuids[guid] = true
end

function curses:EnableExpiringSound(lowercaseSpellNameNoRank, guid)
	if curses.requestedExpiringSoundGuids[guid] and curses.requestedExpiringSoundGuids[guid][lowercaseSpellNameNoRank] then
		curses.requestedExpiringSoundGuids[guid][lowercaseSpellNameNoRank] = nil
	end

	if not curses.expiringSoundGuids[guid] then
		curses.expiringSoundGuids[guid] = {}
	end
	curses.expiringSoundGuids[guid][lowercaseSpellNameNoRank] = true
end

function curses:RequestExpiringSound(lowercaseSpellNameNoRank, guid)
	if not curses.requestedExpiringSoundGuids[guid] then
		curses.requestedExpiringSoundGuids[guid] = {}
	end
	curses.requestedExpiringSoundGuids[guid][lowercaseSpellNameNoRank] = true
end

function curses:HasRequestedExpiringSound(lowercaseSpellNameNoRank, guid)
	return curses.requestedExpiringSoundGuids[guid] and curses.requestedExpiringSoundGuids[guid][lowercaseSpellNameNoRank]
end

function curses:ShouldPlayExpiringSound(lowercaseSpellNameNoRank, guid)
	if curses.expiringSoundGuids[guid] and curses.expiringSoundGuids[guid][lowercaseSpellNameNoRank] then
		curses.expiringSoundGuids[guid][lowercaseSpellNameNoRank] = nil -- remove entry to avoid playing sound multiple times
		return true
	end

	return false
end

function curses:ShouldPlayResistSound(guid)
	if curses.resistSoundGuids[guid] then
		curses.resistSoundGuids[guid] = nil -- remove entry to avoid playing sound multiple times
		return true
	end

	return false
end

function curses:HasAnyCurse(guid)
	if curses.guids[guid] and next(curses.guids[guid]) then
		return true
	end
	return nil
end

function curses:GetCurseData(spellName, guid)
	-- convert to lowercase and remove rank
	local lowercaseSpellNameNoRank = Cursive.utils.GetLowercaseSpellNameNoRank(spellName)

	if curses.guids[guid] and curses.guids[guid][lowercaseSpellNameNoRank] then
		return curses.guids[guid][lowercaseSpellNameNoRank]
	end

	return nil
end

function curses:HasCurse(lowercaseSpellNameNoRank, targetGuid, minRemaining)
	if not minRemaining then
		minRemaining = 0 -- default to 0
	end

	-- handle faerie fire special case
	if curses.isDruid and strfind(lowercaseSpellNameNoRank, L["faerie fire"]) then
		-- remove (feral) or (bear) from spell name
		lowercaseSpellNameNoRank = L["faerie fire"]
	end

	if curses.guids[targetGuid] and curses.guids[targetGuid][lowercaseSpellNameNoRank] then
		local remaining = Cursive.curses:TimeRemaining(curses.guids[targetGuid][lowercaseSpellNameNoRank])
		if remaining >= minRemaining then
			return true
		end
	end

	-- check pending cast
	if curses.pendingCast and
			curses.pendingCast.targetGuid == targetGuid and
			curses.pendingCast.spellID and
			curses.trackedCurseIds[curses.pendingCast.spellID] and
			curses.trackedCurseIds[curses.pendingCast.spellID].name == lowercaseSpellNameNoRank then
		return true
	end

	return nil
end

-- v3.2.1: Remove exclusive debuff from target (e.g. Sunder removes EA and vice versa)
function curses:RemoveExclusiveDebuff(debuffKey, targetGuid)
	local meta = curses.sharedDebuffMeta[debuffKey]
	if not meta or not meta.exclusiveWith then return end

	local exKey = meta.exclusiveWith
	-- Remove from sharedDebuffGuids tracking
	if curses.sharedDebuffGuids[exKey] then
		curses.sharedDebuffGuids[exKey][targetGuid] = nil
	end
	-- Remove from display guids table
	if curses.sharedDebuffs[exKey] and curses.guids[targetGuid] then
		for _, spellData in pairs(curses.sharedDebuffs[exKey]) do
			if spellData and spellData.name and curses.guids[targetGuid][spellData.name] then
				curses.guids[targetGuid][spellData.name] = nil
			end
			break -- all spells share the same name
		end
	end
end

-- Apply shared curse from another player
-- v3.2: accepts optional texture and stacks from scan data
function curses:ApplySharedCurse(sharedDebuffKey, spellID, targetGuid, startTime, scanTexture, scanStacks)
	local spellData = curses.sharedDebuffs[sharedDebuffKey][spellID]
	if not spellData then return end

	-- v3.2.1: Remove exclusive debuff (e.g. Sunder replaces EA)
	curses:RemoveExclusiveDebuff(sharedDebuffKey, targetGuid)

	local name = spellData.name
	local rank = spellData.rank
	local duration = spellData.duration

	if not curses.guids[targetGuid] then
		curses.guids[targetGuid] = {}
	end

	-- v3.2.1 FIX: Resolve texture via SpellInfo if scan didn't provide one
	if not scanTexture then
		local _, _, siTex = SpellInfo(spellID)
		if siTex then
			scanTexture = siTex
		end
	end

	curses.guids[targetGuid][name] = {
		rank = rank,
		duration = duration,
		start = startTime,
		spellID = spellID,
		targetGuid = targetGuid,
		currentPlayer = false,
		sharedTexture = scanTexture, -- v3.2.1: texture from scan or SpellInfo fallback
		sharedStacks = scanStacks or 0, -- v3.2: stack count from UnitDebuff scan
	}
end

-- Apply curse from player
function curses:ApplyCurse(spellID, targetGuid, startTime, duration)
	-- clear pending cast
	curses.pendingCast = {}

	local name = curses.trackedCurseIds[spellID].name
	local rank = curses.trackedCurseIds[spellID].rank

	if curses.isDruid and name == L["rake"] then
		-- First check: Creature type based bleed immunity (Elementals, Undead, Mechanical)
		if not CanApplyBleed(targetGuid) then
			-- Target is bleed immune by creature type, do not track
			return
		end
		
		-- Second check: For mobs not in whitelist, verify debuff is actually on target
		-- (handles debuff cap scenarios where rake might not have been applied)
		if not curses.mobsThatBleed[targetGuid] then
			if not curses:ScanGuidForCurse(targetGuid, spellID) then
				-- rake not found on target, do not apply
				return
			end
		end
	end

	if not curses.guids[targetGuid] then
		curses.guids[targetGuid] = {}
	end

	curses.guids[targetGuid][name] = {
		rank = rank,
		duration = duration,
		start = startTime,
		spellID = spellID,
		targetGuid = targetGuid,
		currentPlayer = true,
		eyeExtended = curses._lastEyeExtended or false,
	}
	
	-- If Dark Harvest is currently active on this target, start tracking for this new DoT
	if curses.isChanneling and 
	   curses.darkHarvestData.targetGuid == targetGuid and
	   curses.trackedCurseIds[spellID] and
	   curses.trackedCurseIds[spellID].darkHarvest then
		curses.guids[targetGuid][name].dhStartTime = GetTime()
	end
end

function curses:UpdateCurse(spellID, targetGuid, startTime)
	-- clear pending cast
	curses.pendingCast = {}

	if curses.conflagrateSpellIds[spellID] then
		-- check if target has immolate
		if curses:HasCurse(L["immolate"], targetGuid) then
			-- reduce duration by 3 sec
			curses.guids[targetGuid][L["immolate"]].duration = curses.guids[targetGuid][L["immolate"]].duration - 3
		end
	end
end

function curses:RemoveCurse(guid, curseName)
	if curses.guids[guid] and curses.guids[guid][curseName] then
		curses.guids[guid][curseName] = nil
	end
	if curses.expiringSoundGuids[guid] and curses.expiringSoundGuids[guid][curseName] then
		curses.expiringSoundGuids[guid][curseName] = nil
	end
end

function curses:RemoveGuid(guid)
	curses.guids[guid] = nil
	curses.resistSoundGuids[guid] = nil
	curses.expiringSoundGuids[guid] = nil
	curses.requestedExpiringSoundGuids[guid] = nil
	curses.playerOwnedCasts[guid] = nil
	-- v3.2: Clean up armor monitor
	curses.armorMonitor[guid] = nil
	-- v3.2.1: Clean up proc tracking
	curses.procExpected[guid] = nil
	curses.lastProcStacks[guid] = nil
end

-- v3.2.2: Known Spell Reflect buff IDs (mob buffs, not player abilities)
-- These are buffs on mobs that reflect spells back at casters
curses.reflectBuffIds = {
	[22067]  = true, -- Reflection (100% All Spells, 10s) - Majordomo Adds, misc dungeon mobs
	[20619]  = true, -- Magic Reflection (50% All Spells, 10s AoE) - MC mobs
	[13022]  = true, -- Fire and Arcane Reflect (100% Fire+Arcane) - Anubisath (AQ)
	[19595]  = true, -- Shadow and Frost Reflect (100% Shadow+Frost) - Anubisath (AQ)
	[460856] = true, -- Reflect Magic (101% All Spells, 5s) - TurtleWoW Custom
}

-- v3.2.2: Check if a GUID has any active CC debuff (banish, polymorph, etc.)
-- Returns true if at least one tracked debuff with category "cc" is active
function curses:HasActiveCC(guid)
	local guidCurses = curses.guids[guid]
	if not guidCurses then return false end

	for curseName, curseData in pairs(guidCurses) do
		if curseData.spellID then
			local debuffKey = curses.sharedDebuffSpellLookup[curseData.spellID]
			if debuffKey then
				local meta = curses.sharedDebuffMeta[debuffKey]
				if meta and meta.category == "cc" then
					-- Check if still active (not expired)
					local remaining = curses:TimeRemaining(curseData)
					if remaining and remaining > 0 then
						return true
					end
				end
			end
		end
	end

	return false
end

-- v3.2.2: Check if a GUID has an active Spell Reflect buff
-- Scans UnitBuff for known reflect spell IDs (requires SuperWoW for spellID)
function curses:HasSpellReflect(guid)
	if not UnitExists(guid) then return false end

	for i = 1, 64 do
		local _, _, spellID = UnitBuff(guid, i)
		if not spellID then break end
		if curses.reflectBuffIds[spellID] then
			return true
		end
	end

	return false
end

Cursive.curses = curses