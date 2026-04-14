local L = AceLibrary("AceLocale-2.2"):new("Cursive")
Cursive = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDebug-2.0", "AceModuleCore-2.0", "AceConsole-2.0", "AceDB-2.0", "AceHook-2.1")
Cursive.superwow = true

if not GetPlayerBuffID or not CombatLogAdd or not SpellInfo then
	local notify = CreateFrame("Frame", "CursiveNoSuperwow", UIParent)
	notify:SetScript("OnUpdate", function()
		DEFAULT_CHAT_FRAME:AddMessage(L["|cffffcc00Cursive:|cffffaaaa Couldn't detect SuperWoW."])
		this:Hide()
	end)

	Cursive.superwow = false
end

function Cursive:OnEnable()
	if not Cursive.superwow then
		return
	end

	-- v3.2.1: Ensure debuff order config has valid, unique values
	-- Defaults in settings.lua are "_init" sentinel (so AceDB cleanDefaults never strips real values).
	-- On first load (or after reset), replace sentinel with real defaults.
	local p = Cursive.db.profile

	-- v4.0.4: Type validation for critical SavedVariable fields (guards against corruption)
	if type(p.anchor) ~= "string" or not Cursive.utils.IsValidAnchor(p.anchor) then
		p.anchor = "RIGHT"
	end
	if type(p.scale) ~= "number" or p.scale <= 0 or p.scale > 5 then
		p.scale = 1
	end
	if type(p.maxrow) ~= "number" or p.maxrow < 1 or p.maxrow > 40 then
		p.maxrow = 8
	end
	if type(p.maxcol) ~= "number" or p.maxcol < 1 or p.maxcol > 10 then
		p.maxcol = 1
	end
	if type(p.maxcurses) ~= "number" or p.maxcurses < 1 or p.maxcurses > 40 then
		p.maxcurses = 14
	end
	if type(p.height) ~= "number" or p.height < 5 or p.height > 100 then
		p.height = 20
	end
	if type(p.width) ~= "number" or p.width < 50 or p.width > 500 then
		p.width = 170
	end
	if type(p.spacing) ~= "number" then
		p.spacing = 2
	end
	-- v4.0.5: Patch new boolean settings into existing profiles (nil → default true)
	if p.oorstripes == nil then p.oorstripes = true end
	if p.cctransparency == nil then p.cctransparency = true end

	local validCats = { ownclass = true, ownraid = true, otherclass = true, otherraid = true, none = true }
	local mainCats = { ownclass = true, ownraid = true, otherclass = true, otherraid = true }
	local allCats = { "ownclass", "ownraid", "otherclass", "otherraid" }
	local slotKeys = { "orderfront", "ordermiddle", "orderback", "orderlast" }
	local slotDefaults = { "ownclass", "ownraid", "otherclass", "otherraid" }

	-- Apply real defaults if sentinel "_init" detected (first load or reset)
	if p.orderfront == "_init" or p.ordermiddle == "_init"
		or p.orderback == "_init" or p.orderlast == "_init" then
		p.orderfront = "ownclass"
		p.ordermiddle = "ownraid"
		p.orderback = "otherclass"
		p.orderlast = "otherraid"
	end
	if p.orderotherside == "_init" or not p.orderotherside then
		p.orderotherside = "none"
	end

	-- Validate: no category appears in both otherside and a main slot
	-- When otherside has a category, one main slot will be "none" (only 3 cats for 4 slots)
	local otherSideCat = p.orderotherside
	local usedCats = {}
	local needsRepair = false
	local noneCount = 0

	for _, sk in ipairs(slotKeys) do
		local val = p[sk]
		if val == "none" then
			noneCount = noneCount + 1
			-- "none" is only valid if otherside has a category
			if otherSideCat == "none" then
				needsRepair = true
				break
			end
			-- Max 1 "none" slot allowed
			if noneCount > 1 then
				needsRepair = true
				break
			end
		elseif not mainCats[val] or val == otherSideCat or usedCats[val] then
			needsRepair = true
			break
		else
			usedCats[val] = true
		end
	end

	-- When otherside is "none", all 4 main slots must be filled (no "none" allowed)
	-- When otherside has a category, exactly 1 main slot must be "none"
	if not needsRepair and otherSideCat ~= "none" and noneCount ~= 1 then
		needsRepair = true
	end

	if needsRepair then
		-- Build available categories (exclude otherside category)
		local availableCats = {}
		for _, cat in ipairs(allCats) do
			if cat ~= otherSideCat then
				table.insert(availableCats, cat)
			end
		end
		-- Distribute: 3 or 4 categories across 4 slots, rest gets "none"
		for i, sk in ipairs(slotKeys) do
			p[sk] = availableCats[i] or "none"
		end
	end

	-- Clean up old config keys
	p.orderownclass = nil
	p.orderownraid = nil
	p.orderotherclass = nil
	p.orderotherraid = nil

	-- v3.2.1: Sentinel for boolean settings (AceDB strips false == default)
	if p.includeOwnRaidInOrder == "_init" then p.includeOwnRaidInOrder = false end
	if p.showMissingDebuffs == "_init" then p.showMissingDebuffs = false end

	-- v3.2.1: Initialize raidDebuffOrder if empty
	-- Default order matches the category layout in the Raid tab
	if not p.raidDebuffOrder or table.getn(p.raidDebuffOrder) == 0 then
		p.raidDebuffOrder = {
			"sunderarmor", "exposearmor", "faeriefire", "curseofrecklessness",
			"firevulnerability", "winterschill", "shadowvulnerability", "shadowweaving",
			"curseoftheelements", "curseofshadow",
			"armorshatter", "puncturearmor", "spellvulnerability", "thunderfury",
			"scytheholy", "scytheshadow", "scythefire", "scythearcane", "scythenature", "scythefrost",
		}
	end

	DEFAULT_CHAT_FRAME:AddMessage(L["|cffffcc00Cursive:|cffffaaaa Loaded.  /cursive for commands and minimap icon for options."])

	Cursive._raidOrderDirty = true -- v4.0.4: Force initial BuildRaidOrderLookup
	Cursive.curses:LoadCurses()
	if Cursive.db.profile.enabled then
		Cursive.core.enable()
	end
end
