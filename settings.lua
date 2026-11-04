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
	-- Threat module (TWTv4 server feed)
	threatenabled = true,
	threatstacked = true,
	threatvalue = false,
	threatholdername = true,
	threatpullwarn = true,
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
		scytheholy = true,
		scytheshadow = true,
		scythefire = true,
		scythearcane = true,
		scythenature = true,
		scythefrost = true,
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
		burningzeal = false,
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
	cctransparency = true,
	oorstripes = true,
	filterraidmark = false,
	filterhascurse = false,
	filterignored = false,

	ignorelist = {},
	ignorelistuseregex = false,
})

-- v3.2: Raid Debuffs definition (13 debuffs, 3 categories)
local raidArmorKeys = { "sunderarmor", "exposearmor", "faeriefire", "curseofrecklessness" }
local raidSpellVulnKeys = { "firevulnerability", "winterschill", "shadowvulnerability", "shadowweaving", "curseoftheelements", "curseofshadow" }
local raidWeaponProcKeys = { "armorshatter", "puncturearmor", "spellvulnerability", "thunderfury", "scytheholy", "scytheshadow", "scythefire", "scythearcane", "scythenature", "scythefrost" }
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
	priest = { "shadowweaving", "shackleundead", "mindcontrol", "psychicscream", "burningzeal" },
	rogue = { "exposearmor", "woundpoison", "sap" },
	warlock = { "curseofrecklessness", "curseoftheelements", "curseofshadow", "curseoftongues", "curseofweakness", "shadowvulnerability", "banish", "enslavedemon", "fear", "howlofterror", "seduction" },
	warrior = { "sunderarmor", "demoshout", "thunderclap", "mortalstrike", "intimidatingshout" },
	item = { "armorshatter", "puncturearmor", "spellvulnerability", "thunderfury", "giftofarthas", "potentvenom", "scytheholy", "scytheshadow", "scythefire", "scythearcane", "scythenature", "scythefrost" },
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
	scytheholy = "Elune's Radiance |cFF808080(Holy Scythe)|r",
	scytheshadow = "Elune's Twilight |cFF808080(Shadow Scythe)|r",
	scythefire = "Elune's Rage |cFF808080(Fire Scythe)|r",
	scythearcane = "Elune's Wrath |cFF808080(Arcane Scythe)|r",
	scythenature = "Elune's Grace |cFF808080(Nature Scythe)|r",
	scythefrost = "Elune's Ire |cFF808080(Frost Scythe)|r",
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
	burningzeal = "Burning Zeal |cFF808080(Priest T3.5)|r",
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
	scytheholy = "Elune's Radiance |cFF808080(Holy Scythe)|r",
	scytheshadow = "Elune's Twilight |cFF808080(Shadow Scythe)|r",
	scythefire = "Elune's Rage |cFF808080(Fire Scythe)|r",
	scythearcane = "Elune's Wrath |cFF808080(Arcane Scythe)|r",
	scythenature = "Elune's Grace |cFF808080(Nature Scythe)|r",
	scythefrost = "Elune's Ire |cFF808080(Frost Scythe)|r",
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
	scytheholy = "10s\n+8% Holy damage taken (Scythe of Elune)",
	scytheshadow = "10s\n+8% Shadow damage taken, -25% Healing, 100 Mana/s, 120 Shadow/s (Scythe of Elune)",
	scythefire = "10s\n+8% Fire damage taken, +2% Spell Crit, 325 Fire on Crit (Scythe of Elune)",
	scythearcane = "10s\n+8% Arcane damage taken, next spell imbued (Scythe of Elune)",
	scythenature = "10s\n+8% Nature damage taken, -8% damage done, 200 Nature/action (Scythe of Elune)",
	scythefrost = "10s\n+8% Frost damage taken, -25% attack speed, 275 Frost on magic (Scythe of Elune)",
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
	burningzeal = "18s\n852 Holy damage over 18s, +2% Holy damage taken (T3.5 Set Proc)",
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


-- v5.0-octo: FuBar/Tablet/Dewdrop minimap plugin removed entirely.
-- Options open via /cursive options (see commands.lua) or this global:
function Cursive_ToggleOptions()
	if CursiveOptionsFrame then
		if CursiveOptionsFrame:IsShown() then
			CursiveOptionsFrame:Hide()
		else
			CursiveOptionsFrame:Show()
		end
	end
end

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
