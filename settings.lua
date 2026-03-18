if not Cursive.superwow then
	return
end

local L = AceLibrary("AceLocale-2.2"):new("Cursive")
Cursive:RegisterDB("CursiveDB")
Cursive:RegisterDefaults("profile", {
	caption = L["Cursive"],
	anchor = "RIGHT",
	x = -147,
	y = 64,

	-- Core
	enabled = true,
	clickthrough = true,
	showbackdrop = false,
	showtitle = false,
	showtargetindicator = false,
	showraidicons = true,
	showhealthbar = true,
	showunitname = true,

	-- v4.0: Default shared debuffs — core raid debuffs enabled, class utility off
	shareddebuffs = {
		-- Armor Reduction (enabled)
		sunderarmor = true,
		exposearmor = true,
		faeriefire = true,
		curseofrecklessness = true,
		-- Spell Vulnerability (enabled)
		firevulnerability = true,
		winterschill = true,
		shadowvulnerability = true,
		shadowweaving = true,
		curseoftheelements = true,
		curseofshadow = true,
		-- Weapon Procs (mixed)
		armorshatter = true,
		spellvulnerability = true,
		thunderfury = true,
		puncturearmor = true,
		potentvenom = false,
		giftofarthas = false,
		-- Class Utility (off by default)
		demoroar = false,
		hibernate = false,
		huntersmark = false,
		freezingtrap = false,
		scattershot = false,
		wyvernsting = false,
		polymorph = false,
		ignite = false,
		judgementoflight = false,
		judgementofwisdom = false,
		judgementofthecrusader = false,
		hammerofjustice = false,
		shackleundead = false,
		mindcontrol = false,
		psychicscream = false,
		woundpoison = false,
		sap = false,
		curseoftongues = false,
		curseofweakness = false,
		banish = false,
		enslavedemon = false,
		fear = false,
		howlofterror = false,
		seduction = false,
		demoshout = false,
		thunderclap = false,
		mortalstrike = false,
		intimidatingshout = false,
	},

	alwaysshowcurrenttarget = false,

	scale = 1,
	opacity = 1.0,
	fontscale = 1.0,
	healthwidth = 100,
	height = 18,
	bartexture = "Interface\\TargetingFrame\\UI-StatusBar",

	raidiconsize = 18,
	curseiconsize = 18,
	maxcurses = 14,
	spacing = 3,
	debufficonspacing = 1,

	maxrow = 8,
	maxcol = 1,
	textsize = 9,
	nameTextSize = 8,
	cursetimersize = 10,
	namelength = 60,

	curseordering = L["Expiring soonest -> latest"],
	curseshowdecimals = false,
	coloreddecimalduration = false,
	decimalDurationColor = "none",
	cursetimeh = 5,
	cursetimev = 5,
	cursestacksize = 9,
	cursestackh = 10,
	cursestackv = 10,
	cursetimeyellow = false,
	cursestackyellow = true,
	classcolordurationtimer = true,

	-- Debuff frame border options
	borderownclass = "off",
	borderotherclass = "off",
	borderownraid = "off",
	borderotherraid = "off",
	borderclasscolors = true,
	borderwidth = 1,
	borderopacity = 50,

	durationtimercolor = "white",
	stackcountercolor = "white",

	-- Debuff order — sentinel defaults (real values applied in OnEnable)
	orderfront = "_init",
	ordermiddle = "_init",
	orderback = "_init",
	orderlast = "_init",
	orderotherside = "_init",

	-- Per-debuff order (initialized in OnEnable if empty)
	raidDebuffOrder = {},
	includeOwnRaidInOrder = "_init",
	showMissingDebuffs = "_init",

	-- Target Armor display
	armorStatusEnabled = false,
	armorColorIndicator = false,
	armorDisplayStructure = "total+removed",
	armorPosition = "default",
	armorShowIcon = "center",
	armorTextSize = 10,
	armorPositionOffset = 0,
	armorTextBorder = 3,

	invertbars = false,
	expandupwards = false,

	filtertarget = false,
	filterincombat = true,
	filterhostile = false,
	filterattackable = true,
	filterplayer = false,
	filternotplayer = false,
	filterrange = true,
	filterraidmark = false,
	filterhascurse = false,
	filterignored = false,

	ignorelist = {},
	ignorelistuseregex = false,
})
local function splitString(str, delimiter)
	local result = {}
	local from = 1
	local delim_from, delim_to = string.find(str, delimiter, from)
	while delim_from do
		table.insert(result, string.sub(str, from, delim_from - 1))
		from = delim_to + 1
		delim_from, delim_to = string.find(str, delimiter, from)
	end
	table.insert(result, string.sub(str, from))
	return result
end

local barOptions = {
	["invertbars"] = {
		type = "toggle",
		name = "Invert Bar Display",
		desc = "Show sections in order 3-2-1 and reverse element order in sections 1 and 3",
		order = 1,
		get = function()
			return Cursive.db.profile.invertbars
		end,
		set = function(v)
			Cursive.db.profile.invertbars = v
			Cursive.UpdateFramesFromConfig()
		end,
	},
	["expandupwards"] = {
		type = "toggle",
		name = "Expand Bars Upwards",
		desc = "Make bars expand upwards instead of downwards",
		order = 2,
		get = function()
			return Cursive.db.profile.expandupwards
		end,
		set = function(v)
			Cursive.db.profile.expandupwards = v
			Cursive.UpdateFramesFromConfig()
		end,
	},
	["spacer1"] = {
		type = "header",
		name = "Section Display",
		order = 5,
	},
	["showtargetindicator"] = {
		type = "toggle",
		name = L["Show Targeting Arrow"],
		desc = L["Show Targeting Arrow"],
		order = 10,
		get = function()
			return Cursive.db.profile.showtargetindicator
		end,
		set = function(v)
			Cursive.db.profile.showtargetindicator = v
			Cursive.UpdateFramesFromConfig()
		end,
	},
	["showraidicons"] = {
		type = "toggle",
		name = L["Show Raid Icons"],
		desc = L["Show Raid Icons"],
		order = 15,
		get = function()
			return Cursive.db.profile.showraidicons
		end,
		set = function(v)
			Cursive.db.profile.showraidicons = v
			Cursive.UpdateFramesFromConfig()
		end,
	},
	["showhealthbar"] = {
		type = "toggle",
		name = L["Show Health Bar"],
		desc = L["Show Health Bar"],
		order = 20,
		get = function()
			return Cursive.db.profile.showhealthbar
		end,
		set = function(v)
			Cursive.db.profile.showhealthbar = v
			Cursive.UpdateFramesFromConfig()
		end,
	},
	["showunitname"] = {
		type = "toggle",
		name = L["Show Unit Name"],
		desc = L["Show Unit Name"],
		order = 25,
		get = function()
			return Cursive.db.profile.showunitname
		end,
		set = function(v)
			Cursive.db.profile.showunitname = v
			Cursive.UpdateFramesFromConfig()
		end,
	},
	["alwaysshowcurrenttarget"] = {
		type = "toggle",
		name = "Always Show Current Target",
		desc = "Always show current target at the bottom of the mob list if it is not already shown",
		order = 30,
		get = function()
			return Cursive.db.profile.alwaysshowcurrenttarget
		end,
		set = function(v)
			Cursive.db.profile.alwaysshowcurrenttarget = v
		end,
	},
	["spacer2"] = {
		type = "header",
		name = "Size & Appearance",
		order = 35,
	},
	["barwidth"] = {
		type = "range",
		name = L["Health Bar/Unit Name Width"],
		desc = L["Health Bar/Unit Name Width"],
		order = 40,
		min = 30,
		max = 150,
		step = 5,
		get = function()
			return Cursive.db.profile.healthwidth
		end,
		set = function(v)
			if v ~= Cursive.db.profile.healthwidth then
				Cursive.db.profile.healthwidth = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["barheight"] = {
		type = "range",
		name = L["Health Bar/Unit Name Height"],
		desc = L["Health Bar/Unit Name Height"],
		order = 50,
		min = 10,
		max = 30,
		step = 2,
		get = function()
			return Cursive.db.profile.height
		end,
		set = function(v)
			if v ~= Cursive.db.profile.height then
				Cursive.db.profile.height = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["bartexture"] = {
		type = "text",
		name = L["Health Bar Texture"],
		desc = L["Health Bar Texture Desc"],
		order = 55,
		usage = "Interface\\TargetingFrame\\UI-StatusBar",
		get = function()
			return Cursive.db.profile.bartexture
		end,
		set = function(v)
			if v ~= Cursive.db.profile.bartexture then
				Cursive.db.profile.bartexture = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["raidiconsize"] = {
		type = "range",
		name = L["Raid Icon Size"],
		desc = L["Raid Icon Size"],
		order = 60,
		min = 10,
		max = 30,
		step = 1,
		get = function()
			return Cursive.db.profile.raidiconsize
		end,
		set = function(v)
			if v ~= Cursive.db.profile.raidiconsize then
				Cursive.db.profile.raidiconsize = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["curseiconsize"] = {
		type = "range",
		name = L["Curse Icon Size"],
		desc = L["Curse Icon Size"],
		order = 70,
		min = 10,
		max = 30,
		step = 1,
		get = function()
			return Cursive.db.profile.curseiconsize
		end,
		set = function(v)
			if v ~= Cursive.db.profile.curseiconsize then
				Cursive.db.profile.curseiconsize = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["curseordering"] = {
		type = "text",
		name = L["Curse Ordering"],
		desc = L["Curse Ordering"],
		order = 72,
		get = function()
			return Cursive.db.profile.curseordering
		end,
		validate = { L["Order applied"], L["Expiring soonest -> latest"], L["Expiring latest -> soonest"] },
		set = function(v)
			Cursive.db.profile.curseordering = v
		end,
	},
	["curseshowdecimals"] = {
		type = "toggle",
		name = L["Decimal Duration"],
		desc = L["Decimal Duration Desc"],
		order = 74,
		get = function()
			return Cursive.db.profile.curseshowdecimals
		end,
		set = function(v)
			Cursive.db.profile.curseshowdecimals = v
			Cursive.UpdateFramesFromConfig()
		end,
	},
	["spacing"] = {
		type = "range",
		name = L["Health Bar Spacing"],
		desc = L["Health Bar Spacing"],
		order = 80,
		min = 0,
		max = 10,
		step = 1,
		get = function()
			return Cursive.db.profile.spacing
		end,
		set = function(v)
			if v ~= Cursive.db.profile.spacing then
				Cursive.db.profile.spacing = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["debufficonspacing"] = {
		type = "range",
		name = L["Debuff Icon Spacing"],
		desc = L["Debuff Icon Spacing"],
		order = 81,
		min = 0,
		max = 10,
		step = 1,
		get = function()
			return Cursive.db.profile.debufficonspacing
		end,
		set = function(v)
			if v ~= Cursive.db.profile.debufficonspacing then
				Cursive.db.profile.debufficonspacing = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["textsize"] = {
		type = "range",
		name = L["Name/Hp Text Size"],
		desc = L["Name/Hp Text Size"],
		order = 90,
		min = 8,
		max = 20,
		step = 1,
		get = function()
			return Cursive.db.profile.textsize
		end,
		set = function(v)
			if v ~= Cursive.db.profile.textsize then
				Cursive.db.profile.textsize = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["cursetimersize"] = {
		type = "range",
		name = L["Curse Timer Text Size"],
		desc = L["Curse Timer Text Size"],
		order = 95,
		min = 6,
		max = 20,
		step = 1,
		get = function()
			return Cursive.db.profile.cursetimersize
		end,
		set = function(v)
			if v ~= Cursive.db.profile.cursetimersize then
				Cursive.db.profile.cursetimersize = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
	["scale"] = {
		type = "range",
		name = L["Scale"],
		desc = L["Scale"],
		order = 100,
		min = 0.5,
		max = 2,
		step = 0.1,
		get = function()
			return Cursive.db.profile.scale
		end,
		set = function(v)
			if v ~= Cursive.db.profile.scale then
				Cursive.db.profile.scale = v
				Cursive.UpdateFramesFromConfig()
			end
		end,
	},
}

local mobFilters = {
	["incombat"] = {
		type = "toggle",
		name = L["In Combat"],
		desc = L["In Combat"],
		order = 1,
		get = function()
			return Cursive.db.profile.filterincombat
		end,
		set = function(v)
			Cursive.db.profile.filterincombat = v
		end,
	},
	["hostile"] = {
		type = "toggle",
		name = L["Hostile"],
		desc = L["Hostile"],
		order = 11,
		get = function()
			return Cursive.db.profile.filterhostile
		end,
		set = function(v)
			Cursive.db.profile.filterhostile = v
		end,
	},
	["attackable"] = {
		type = "toggle",
		name = L["Attackable"],
		desc = L["Attackable"],
		order = 22,
		get = function()
			return Cursive.db.profile.filterattackable
		end,
		set = function(v)
			Cursive.db.profile.filterattackable = v
		end,
	},
	["player"] = {
		type = "toggle",
		name = L["Player"],
		desc = L["Player Desc"],
		order = 33,
		get = function()
			return Cursive.db.profile.filterplayer
		end,
		set = function(v)
			Cursive.db.profile.filterplayer = v
		end,
	},
	["notplayer"] = {
		type = "toggle",
		name = L["Not Player"],
		desc = L["Not Player Desc"],
		order = 33,
		get = function()
			return Cursive.db.profile.filternotplayer
		end,
		set = function(v)
			Cursive.db.profile.filternotplayer = v
		end,
	},
	["range"] = {
		type = "toggle",
		name = IsSpellInRange and L["Within 45 Range"] or L["Within 28 Range"],
		desc = IsSpellInRange and L["Within 45 Range"] or L["Within 28 Range"],
		order = 44,
		get = function()
			return Cursive.db.profile.filterrange
		end,
		set = function(v)
			Cursive.db.profile.filterrange = v
		end,
	},
	["raidmark"] = {
		type = "toggle",
		name = L["Has Raid Mark"],
		desc = L["Has Raid Mark"],
		order = 55,
		get = function()
			return Cursive.db.profile.filterraidmark
		end,
		set = function(v)
			Cursive.db.profile.filterraidmark = v
		end,
	},
	["hascurse"] = {
		type = "toggle",
		name = L["Has Curse"],
		desc = L["Only show units you have cursed"],
		order = 66,
		get = function()
			return Cursive.db.profile.filterhascurse
		end,
		set = function(v)
			Cursive.db.profile.filterhascurse = v
		end,
	},
	["notignored"] = {
		type = "toggle",
		name = L["Not ignored"],
		desc = L["Not ignored"],
		order = 67,
		get = function()
			return Cursive.db.profile.filterignored
		end,
		set = function(v)
			Cursive.db.profile.filterignored = v
		end,
	},
	["ignorelist"] = {
		type = "text",
		name = L["Ignored Mobs List (Enter to save)"],
		desc = L["Ignored Mobs Desc"],
		usage = "whelp, black dragonkin, player3",
		order = 68,
		get = function()
			if Cursive.db.profile.ignorelist and table.getn(Cursive.db.profile.ignorelist) > 0 then
				return table.concat(Cursive.db.profile.ignorelist, ",") or ""
			end
			return ""
		end,
		set = function(v)
			if not v or v == "" then
				Cursive.db.profile.ignorelist = {}
			else
				Cursive.db.profile.ignorelist = splitString(v, ",");
			end
			-- check for common lua regex patterns
			Cursive.db.profile.ignorelistuseregex = string.find(v, "[*+%%?]") ~= nil
		end,
	},
}

-- v3.2: Helper to create a shared debuff toggle entry
local function CreateSharedDebuffToggle(debuffKey, displayName, desc, order)
	return {
		type = "toggle",
		name = displayName,
		desc = desc,
		order = order,
		get = function()
			return Cursive.db.profile.shareddebuffs[debuffKey]
		end,
		set = function(v)
			Cursive.db.profile.shareddebuffs[debuffKey] = v
			Cursive.UpdateFramesFromConfig()
		end,
	}
end

-- v3.2: Helper to create Enable All / Disable All for a set of keys
local function CreateBulkToggle(name, desc, keys, value, order)
	return {
		type = "execute",
		name = name,
		desc = desc,
		order = order,
		func = function()
			for _, key in ipairs(keys) do
				Cursive.db.profile.shareddebuffs[key] = value
			end
			Cursive.UpdateFramesFromConfig()
		end,
	}
end

-- v3.2: Raid Debuffs definition (13 debuffs, 3 categories)
local raidArmorKeys = { "sunderarmor", "exposearmor", "faeriefire", "curseofrecklessness" }
local raidSpellVulnKeys = { "firevulnerability", "winterschill", "shadowvulnerability", "shadowweaving", "curseoftheelements", "curseofshadow" }
local raidWeaponProcKeys = { "armorshatter", "puncturearmor", "spellvulnerability", "thunderfury" }
local allRaidKeys = {}
for _, k in ipairs(raidArmorKeys) do table.insert(allRaidKeys, k) end
for _, k in ipairs(raidSpellVulnKeys) do table.insert(allRaidKeys, k) end
for _, k in ipairs(raidWeaponProcKeys) do table.insert(allRaidKeys, k) end

-- v3.2: Class debuffs definition
local classDebuffs = {
	druid = { "faeriefire", "demoroar", "hibernate" },
	hunter = { "huntersmark", "freezingtrap", "scattershot", "wyvernsting" },
	mage = { "polymorph", "firevulnerability", "winterschill", "ignite" },
	paladin = { "judgementoflight", "judgementofwisdom", "judgementofthecrusader", "hammerofjustice" },
	priest = { "shadowweaving", "shackleundead", "mindcontrol", "psychicscream" },
	rogue = { "exposearmor", "woundpoison", "sap" },
	warlock = { "curseofrecklessness", "curseoftheelements", "curseofshadow", "curseoftongues", "curseofweakness", "shadowvulnerability", "banish", "enslavedemon", "fear", "howlofterror", "seduction" },
	warrior = { "sunderarmor", "demoshout", "thunderclap", "mortalstrike", "intimidatingshout" },
	item = { "armorshatter", "puncturearmor", "spellvulnerability", "thunderfury", "giftofarthas", "potentvenom" },
}

-- v3.2: Display names for debuff keys
local debuffDisplayNames = {
	-- v3.2: Simple debuff names (used in By Class view)
	faeriefire = "Faerie Fire",
	sunderarmor = "Sunder Armor",
	exposearmor = "Expose Armor",
	curseofrecklessness = "Curse of Recklessness",
	curseoftheelements = "Curse of the Elements",
	curseofshadow = "Curse of Shadow",
	curseoftongues = "Curse of Tongues",
	curseofweakness = "Curse of Weakness",
	firevulnerability = "Fire Vulnerability",
	winterschill = "Winter's Chill",
	shadowvulnerability = "Shadow Vulnerability",
	shadowweaving = "Shadow Weaving",
	spellvulnerability = "Spell Vulnerability |cFF808080(Nightfall)|r",
	armorshatter = "Armor Shatter |cFF808080(Annihilator)|r",
	thunderfury = "Thunderfury |cFF808080(Thunderfury)|r",
	giftofarthas = "Gift of Arthas",
	puncturearmor = "Puncture Armor |cFF808080(Weapon Proc)|r",
	potentvenom = "Potent Venom |cFF808080(Vial of Potent Venoms)|r",
	demoshout = "Demoralizing Shout",
	demoroar = "Demoralizing Roar",
	thunderclap = "Thunder Clap",
	mortalstrike = "Mortal Strike",
	woundpoison = "Wound Poison",
	huntersmark = "Hunter's Mark",
	freezingtrap = "Freezing Trap",
	scattershot = "Scatter Shot",
	wyvernsting = "Wyvern Sting",
	polymorph = "Polymorph",
	ignite = "Ignite",
	hibernate = "Hibernate",
	shackleundead = "Shackle Undead",
	mindcontrol = "Mind Control",
	psychicscream = "Psychic Scream",
	sap = "Sap",
	banish = "Banish",
	fear = "Fear",
	howlofterror = "Howl of Terror",
	enslavedemon = "Enslave Demon",
	seduction = "Seduction",
	intimidatingshout = "Intimidating Shout",
	hammerofjustice = "Hammer of Justice",
	judgementoflight = "Judgement of Light",
	judgementofwisdom = "Judgement of Wisdom",
	judgementofthecrusader = "Judgement of the Crusader",
}

-- v3.2: Raid view names with source in parentheses: "Debuff (Source)"
local raidDisplayNames = {
	-- Armor Reduction
	sunderarmor = "Sunder Armor |cFFC69B6D(Warrior)|r",
	exposearmor = "Expose Armor |cFFFFF468(Rogue)|r",
	faeriefire = "Faerie Fire |cFFFF7C0A(Druid)|r",
	curseofrecklessness = "Curse of Recklessness |cFF9382C9(Warlock)|r",
	-- Spell Vulnerability
	firevulnerability = "Fire Vulnerability |cFF68CCEF(Mage)|r",
	winterschill = "Winter's Chill |cFF68CCEF(Mage)|r",
	shadowvulnerability = "Shadow Vulnerability |cFF9382C9(Warlock)|r",
	shadowweaving = "Shadow Weaving |cFFFFFFFF(Priest)|r",
	spellvulnerability = "Spell Vulnerability |cFF808080(Nightfall)|r",
	curseoftheelements = "Curse of the Elements |cFF9382C9(Warlock)|r",
	curseofshadow = "Curse of Shadow |cFF9382C9(Warlock)|r",
	-- Weapon Procs
	armorshatter = "Armor Shatter |cFF808080(Annihilator)|r",
	thunderfury = "Thunderfury |cFF808080(Thunderfury)|r",
	puncturearmor = "Puncture Armor |cFF808080(Weapon Proc)|r",
	-- Other Raid
	demoshout = "Demoralizing Shout |cFFC69B6D(Warrior)|r",
	demoroar = "Demoralizing Roar |cFFFF7C0A(Druid)|r",
	thunderclap = "Thunder Clap |cFFC69B6D(Warrior)|r",
	mortalstrike = "Mortal Strike |cFFC69B6D(Warrior)|r",
	woundpoison = "Wound Poison |cFFFFF468(Rogue)|r",
	huntersmark = "Hunter's Mark |cFFAAD372(Hunter)|r",
	giftofarthas = "Gift of Arthas |cFFFFFFFF(Item)|r",
	potentvenom = "Potent Venom |cFFFFFFFF(Vial of Potent Venoms)|r",
}

-- v3.2: Detailed tooltip descriptions for each debuff
-- Format: Each line separate, white for stats, yellow/gold for effects
-- |cFFFFFFFF = white, |cFFFFD100 = gold/yellow, |r = reset
local debuffDescriptions = {
	-- Armor Reduction
	sunderarmor = "30s\nReduce 450 Armor up to 5 Times (2250)",
	exposearmor = "30s\nReduce 340 Armor per Combo Point (1700)",
	faeriefire = "40s\nReduce Armor by 505",
	curseofrecklessness = "120s\nReduce Armor by 640",
	-- Spell Vulnerability
	firevulnerability = "30s\nIncreases Fire Damage by 3% up to 5 Times (15%)",
	winterschill = "15s\nIncreases Frost Crit Chance by 2% up to 5 Times (10%)",
	shadowvulnerability = "10s\nShadow Bolt and Drain Soul chance to Increases Shadow Damage by 20%",
	shadowweaving = "15s\nIncreases Shadow Damage by 3% up to 5 Times (15%)",
	spellvulnerability = "7s\nIncrease Spell Damage by 10%",
	curseoftheelements = "300s\nReducing Fire and Frost Resistances by 75 and Increases Fire and Frost Damage by 10%",
	curseofshadow = "300s\nReducing Shadow and Arcane Resistances by 75 and Increases Shadow and Arcane Damage by 10%",
	-- Weapon Procs
	armorshatter = "45s\nReduces armor by 100 up to 3 Times (300)",
	thunderfury = "12s\nReduces Nature Resistances by 25 and Slowing Attack Speed by 20%",
	puncturearmor = "30s\nReduces Armor by 200 up to 3 Times (600)",
	giftofarthas = "180s\nAttackers have 3% chance to deal 200 Shadow damage over 4 ticks",
	potentvenom = "12s\nDeals 120 Nature damage over 12 sec (Trinket Proc)",
	-- Warrior
	demoshout = "30s\nReduces melee AP by 140",
	thunderclap = "30s\nReduces attack speed by 10%",
	mortalstrike = "10s\nReduces healing taken by 50%",
	intimidatingshout = "8s\nFear effect",
	-- Druid
	demoroar = "30s\nReduces melee AP by 108",
	hibernate = "40s\nSleep on Beasts and Dragonkin",
	-- Hunter
	huntersmark = "120s\nIncreases Ranged AP by 110",
	freezingtrap = "20s\nFreezes target in ice",
	scattershot = "4s\nDisorient, damage breaks effect",
	wyvernsting = "12s\nSleep, damage breaks effect, Poison DoT after",
	-- Mage
	polymorph = "50s\nTransforms target into critter, damage breaks effect",
	ignite = "4s\n40% of crit damage over 2 ticks",
	-- Priest
	shackleundead = "50s\nIncapacitate Undead",
	mindcontrol = "60s\nControls target, caster immobilized",
	psychicscream = "8s\nAoE Fear",
	-- Rogue
	sap = "45s\nIncapacitate Humanoid, requires stealth",
	woundpoison = "15s\nReduces healing taken by 5% up to 5 Times (25%)",
	-- Warlock
	curseoftongues = "30s\nIncreases casting time by 50%",
	curseofweakness = "120s\nReduces melee AP by 31",
	banish = "30s\nBanish Demon or Elemental, target is invulnerable",
	fear = "20s\nFear, target runs in fear",
	howlofterror = "10s\nAoE Fear up to 5 enemies",
	enslavedemon = "300s\nControls a Demon",
	seduction = "14s\nCharm from Succubus pet",
	-- Paladin
	hammerofjustice = "6s\nStun",
	judgementoflight = "10s\nMelee attacks heal attacker for 61",
	judgementofwisdom = "10s\nAttacks restore 33 mana to attacker",
	judgementofthecrusader = "10s\nIncreases Holy damage taken by 140 and Increases melee and ranged AP",
}

-- v3.2: Build class display names
local classDisplayNames = {
	druid = "Druid",
	hunter = "Hunter",
	mage = "Mage",
	paladin = "Paladin",
	priest = "Priest",
	rogue = "Rogue",
	warlock = "Warlock",
	warrior = "Warrior",
	item = L["Items/Weapons"],
}

-- v3.2: Build a submenu for a list of debuff keys
-- useRaidNames: if true, use "Debuff (Source)" format for Raid view
local function BuildDebuffGroup(keys, startOrder, useRaidNames)
	local args = {}
	local order = startOrder or 10
	for _, key in ipairs(keys) do
		local name
		if useRaidNames then
			name = raidDisplayNames[key] or debuffDisplayNames[key] or key
		else
			name = debuffDisplayNames[key] or key
		end
		local desc = debuffDescriptions[key] or ""
		args[key] = CreateSharedDebuffToggle(key, name, desc, order)
		order = order + 1
	end
	return args
end

-- v3.2: Build Raid Debuffs submenu
local raidDebuffsArgs = {}
-- Enable/Disable All
raidDebuffsArgs["enableAll"] = CreateBulkToggle(L["Enable All"], L["Enable all debuffs in this category"], allRaidKeys, true, 1)
raidDebuffsArgs["disableAll"] = CreateBulkToggle(L["Disable All"], L["Disable all debuffs in this category"], allRaidKeys, false, 2)
-- Armor Reduction header + toggles (Raid view: with source)
raidDebuffsArgs["armorHeader"] = { type = "header", name = L["Armor Reduction"], order = 10 }
local armorOrder = 11
for _, key in ipairs(raidArmorKeys) do
	local name = raidDisplayNames[key] or debuffDisplayNames[key] or key
	raidDebuffsArgs[key] = CreateSharedDebuffToggle(key, name, debuffDescriptions[key] or "", armorOrder)
	armorOrder = armorOrder + 1
end
-- Spell Vulnerability header + toggles (Raid view: with source)
raidDebuffsArgs["spellvulnHeader"] = { type = "header", name = L["Spell Vulnerability"], order = 20 }
local svOrder = 21
for _, key in ipairs(raidSpellVulnKeys) do
	local name = raidDisplayNames[key] or debuffDisplayNames[key] or key
	raidDebuffsArgs[key] = CreateSharedDebuffToggle(key, name, debuffDescriptions[key] or "", svOrder)
	svOrder = svOrder + 1
end
-- Weapon Procs header + toggles (Raid view: with source)
raidDebuffsArgs["weaponHeader"] = { type = "header", name = L["Weapon Procs"], order = 30 }
local wpOrder = 31
for _, key in ipairs(raidWeaponProcKeys) do
	local name = raidDisplayNames[key] or debuffDisplayNames[key] or key
	raidDebuffsArgs[key] = CreateSharedDebuffToggle(key, name, debuffDescriptions[key] or "", wpOrder)
	wpOrder = wpOrder + 1
end

-- v3.2: Build By Class submenu
local byClassArgs = {}
local classOrder = 10
local classOrderList = { "druid", "hunter", "mage", "paladin", "priest", "rogue", "warlock", "warrior", "item" }
for _, className in ipairs(classOrderList) do
	local keys = classDebuffs[className]
	if keys then
		local classArgs = {}
		-- Enable/Disable All for this class
		classArgs["enableAll"] = CreateBulkToggle(L["Enable All"], L["Enable all debuffs in this category"], keys, true, 1)
		classArgs["disableAll"] = CreateBulkToggle(L["Disable All"], L["Disable all debuffs in this category"], keys, false, 2)
		-- Individual toggles
		local toggleOrder = 10
		for _, key in ipairs(keys) do
			classArgs[key] = CreateSharedDebuffToggle(key, debuffDisplayNames[key] or key, debuffDescriptions[key] or "", toggleOrder)
			toggleOrder = toggleOrder + 1
		end
		byClassArgs[className] = {
			type = "group",
			name = classDisplayNames[className] or className,
			desc = classDisplayNames[className] or className,
			order = classOrder,
			args = classArgs,
		}
		classOrder = classOrder + 1
	end
end

-- v3.2: Combined Shared Debuffs menu
local sharedDebuffs = {
	["raidDebuffs"] = {
		type = "group",
		name = L["Raid Debuffs"],
		desc = L["Raid Debuffs"],
		order = 10,
		args = raidDebuffsArgs,
	},
	["byClass"] = {
		type = "group",
		name = L["By Class"],
		desc = L["By Class"],
		order = 20,
		args = byClassArgs,
	},
}

Cursive.cmdtable = {
	type = "group",
	handler = Cursive,
	args = {
		["enabled"] = {
			type = "toggle",
			name = L["Enabled"],
			desc = L["Enable/Disable Cursive"],
			order = 1,
			get = function()
				return Cursive.db.profile.enabled
			end,
			set = function(v)
				Cursive.db.profile.enabled = v
				if v == true then
					Cursive.core.enable()
				else
					Cursive.core.disable()
				end
			end,
		},
		["showtitle"] = {
			type = "toggle",
			name = L["Show Title"],
			desc = L["Show the title of the frame"],
			order = 3,
			get = function()
				return Cursive.db.profile.showtitle
			end,
			set = function(v)
				Cursive.db.profile.showtitle = v
				Cursive.UpdateFramesFromConfig()
			end,
		},
		["clickthrough"] = {
			type = "toggle",
			name = L["Allow clickthrough"],
			desc = L["This will allow you to click through the frame to target mobs behind it, but prevents dragging the frame."],
			order = 5,
			get = function()
				return Cursive.db.profile.clickthrough
			end,
			set = function(v)
				Cursive.db.profile.clickthrough = v
				Cursive.UpdateFramesFromConfig()
			end,
		},
		["showbackdrop"] = {
			type = "toggle",
			name = L["Show Frame Background"],
			desc = L["Toggle the frame background to help with positioning"],
			order = 7,
			get = function()
				return Cursive.db.profile.showbackdrop
			end,
			set = function(v)
				Cursive.db.profile.showbackdrop = v
				Cursive.UpdateFramesFromConfig()
			end,
		},
		["resetframe"] = {
			type = "execute",
			name = L["Reset Frame"],
			desc = L["Move the frame back to the default position"],
			order = 9,
			func = function()
				Cursive.db.profile.anchor = "CENTER"
				Cursive.db.profile.x = -100
				Cursive.db.profile.y = -100
				Cursive.UpdateFramesFromConfig()
			end,
		},
		["spacer"] = {
			type = "header",
			name = " ",
			order = 11,
		},
		["bardisplay"] = {
			type = "group",
			name = L["Bar Display Settings"],
			desc = L["Bar Display Settings"],
			order = 13,
			args = barOptions
		},
		["filters"] = {
			type = "group",
			name = L["Mob filters"],
			desc = L["Target and Raid Marks always shown"],
			order = 19,
			args = mobFilters
		},
		["shareddebuffs"] = {
			type = "group",
			name = L["Shared Debuffs"],
			desc = L["Shared Debuffs"],
			order = 20,
			args = sharedDebuffs
		},
		["spacer2"] = {
			type = "header",
			name = " ",
			order = 21,
		},
		["maxcurses"] = {
			type = "range",
			name = L["Max Curses"],
			desc = L["Max Curses"],
			order = 22,
			min = 1,
			max = 15,
			step = 1,
			get = function()
				return Cursive.db.profile.maxcurses
			end,
			set = function(v)
				if v ~= Cursive.db.profile.maxcurses then
					Cursive.db.profile.maxcurses = v
					Cursive.UpdateFramesFromConfig()
				end
			end,
		},
		["maxrow"] = {
			type = "range",
			name = L["Max Rows"],
			desc = L["Max Rows"],
			order = 30,
			min = 1,
			max = 20,
			step = 1,
			get = function()
				return Cursive.db.profile.maxrow
			end,
			set = function(v)
				if v ~= Cursive.db.profile.maxrow then
					Cursive.db.profile.maxrow = v
					Cursive.UpdateFramesFromConfig()
				end
			end,
		},
		["maxcol"] = {
			type = "range",
			name = L["Max Columns"],
			desc = L["Max Columns"],
			order = 40,
			min = 1,
			max = 20,
			step = 1,
			get = function()
				return Cursive.db.profile.maxcol
			end,
			set = function(v)
				if v ~= Cursive.db.profile.maxcol then
					Cursive.db.profile.maxcol = v
					Cursive.UpdateFramesFromConfig()
				end
			end,
		},
	}
}

local deuce = Cursive:NewModule("Options Menu")
deuce.hasFuBar = IsAddOnLoaded("FuBar") and FuBar
deuce.consoleCmd = not deuce.hasFuBar

CursiveOptions = AceLibrary("AceAddon-2.0"):new("AceDB-2.0", "FuBarPlugin-2.0")
CursiveOptions.name = " "
CursiveOptions.title = " "
CursiveOptions.hasNoColor = true
CursiveOptions:RegisterDB("CursiveDB")
CursiveOptions.hasIcon = "Interface\\Icons\\INV_Misc_Head_Dragon_01"
CursiveOptions.defaultMinimapPosition = 180
CursiveOptions.independentProfile = true
CursiveOptions.hideWithoutStandby = false

-- v4.0: No Dewdrop menu — right-click fully disabled
CursiveOptions.OnMenuRequest = nil
CursiveOptions.overrideMenu = true
CursiveOptions.cannotDetachTooltip = true
CursiveOptions.tooltipHiddenWhenEmpty = true

-- v4.0: Custom tooltip with swapped name + red SUPERWOW
function CursiveOptions:OnTooltipUpdate()
	if AceLibrary:HasInstance("Tablet-2.0") then
		local Tablet = AceLibrary("Tablet-2.0")
		local cat = Tablet:AddCategory("columns", 1)
		cat:AddLine("text", "Cursive Raid v4.0.3 |CFFFFCC00[|r|CFFCC3333SUPERWOW|r|CFFFFCC00]|r")
	end
end

-- v4.0: Override FuBar OnClick — Left=Options only
function CursiveOptions:OnClick(button)
	-- Close Dewdrop if it somehow opened (AceDB profile menu)
	if AceLibrary:HasInstance("Dewdrop-2.0") then
		local Dewdrop = AceLibrary("Dewdrop-2.0")
		if Dewdrop:IsOpen() then Dewdrop:Close() end
	end
	if button == "LeftButton" then
		if CursiveOptionsFrame then
			if CursiveOptionsFrame:IsShown() then
				CursiveOptionsFrame:Hide()
			else
				CursiveOptionsFrame:Show()
			end
		end
	end
end

-- v4.0: Continuously suppress Dewdrop on minimap button
local mmPatch = CreateFrame("Frame")
mmPatch:RegisterEvent("PLAYER_LOGIN")
mmPatch.patched = false
mmPatch:SetScript("OnEvent", function()
	mmPatch:SetScript("OnUpdate", function()
		-- Check every frame until we find and patch the minimap button
		local mmFrame = CursiveOptions.minimapFrame
		if not mmFrame then return end
		if mmPatch.patched then
			-- Keep closing Dewdrop if it opens on right-click
			if AceLibrary:HasInstance("Dewdrop-2.0") then
				local Dewdrop = AceLibrary("Dewdrop-2.0")
				if Dewdrop:IsOpen(mmFrame) then Dewdrop:Close() end
			end
			return
		end
		mmPatch.patched = true

		-- Set colored name after FuBar created frames
		CursiveOptions.name = "Cursive Raid v4.0.3 |CFFFFCC00[|r|CFFCC3333SUPERWOW|r|CFFFFCC00]|r"

		-- Override OnClick — only LeftButton, right-click does nothing
		mmFrame:SetScript("OnClick", function()
			if arg1 == "LeftButton" then
				if CursiveOptionsFrame then
					if CursiveOptionsFrame:IsShown() then
						CursiveOptionsFrame:Hide()
					else
						CursiveOptionsFrame:Show()
					end
				end
			end
			-- Suppress any Dewdrop that might have been triggered
			if AceLibrary:HasInstance("Dewdrop-2.0") then
				local Dewdrop = AceLibrary("Dewdrop-2.0")
				if Dewdrop:IsOpen() then Dewdrop:Close() end
			end
		end)
	end)
end)

-- v4.0: Expose debuff data for CursiveOptionsUI.lua
Cursive.optionsData = {
	classDebuffs = classDebuffs,
	debuffDisplayNames = debuffDisplayNames,
	debuffDescriptions = debuffDescriptions,
	raidDisplayNames = raidDisplayNames,
	classDisplayNames = classDisplayNames,
	raidArmorKeys = raidArmorKeys,
	raidSpellVulnKeys = raidSpellVulnKeys,
	raidWeaponProcKeys = raidWeaponProcKeys,
	allRaidKeys = allRaidKeys,
	classOrderList = classOrderList,
}
