local L = AceLibrary("AceLocale-2.2"):new("Cursive")

function getSharedDebuffs()
	return {
		-- ============================================
		-- DRUID
		-- ============================================
		faeriefire = {
			category = "armor",
			class = "druid",
			raidRelevant = true,
			spells = {
				-- Faerie Fire (Caster)
				[770] = { name = L["faerie fire"], rank = 1, duration = 40 },
				[778] = { name = L["faerie fire"], rank = 2, duration = 40 },
				[9749] = { name = L["faerie fire"], rank = 3, duration = 40 },
				[9907] = { name = L["faerie fire"], rank = 4, duration = 40 },
				-- Faerie Fire (Bear) - use same name so they block each other
				[16855] = { name = L["faerie fire"], rank = 1, duration = 40 },
				[17387] = { name = L["faerie fire"], rank = 2, duration = 40 },
				[17388] = { name = L["faerie fire"], rank = 3, duration = 40 },
				[17389] = { name = L["faerie fire"], rank = 4, duration = 40 },
				-- Faerie Fire (Feral) - use same name so they block each other
				[16857] = { name = L["faerie fire"], rank = 1, duration = 40 },
				[17390] = { name = L["faerie fire"], rank = 2, duration = 40 },
				[17391] = { name = L["faerie fire"], rank = 3, duration = 40 },
				[17392] = { name = L["faerie fire"], rank = 4, duration = 40 },
			},
		},
		demoroar = {
			category = "tank",
			class = "druid",
			raidRelevant = false,
			spells = {
				[99] = { name = L["demoralizing roar"], rank = 1, duration = 30 },
				[1735] = { name = L["demoralizing roar"], rank = 2, duration = 30 },
				[9490] = { name = L["demoralizing roar"], rank = 3, duration = 30 },
				[9747] = { name = L["demoralizing roar"], rank = 4, duration = 30 },
				[9898] = { name = L["demoralizing roar"], rank = 5, duration = 30 },
			},
		},
		hibernate = {
			category = "cc",
			class = "druid",
			raidRelevant = false,
			spells = {
				[2637] = { name = L["hibernate"], rank = 1, duration = 20 },
				[18657] = { name = L["hibernate"], rank = 2, duration = 30 },
				[18658] = { name = L["hibernate"], rank = 3, duration = 40 },
			},
		},

		-- ============================================
		-- HUNTER
		-- ============================================
		huntersmark = {
			category = "utility",
			class = "hunter",
			raidRelevant = false,
			spells = {
				[1130] = { name = L["hunter's mark"], rank = 1, duration = 120 },
				[14323] = { name = L["hunter's mark"], rank = 2, duration = 120 },
				[14324] = { name = L["hunter's mark"], rank = 3, duration = 120 },
				[14325] = { name = L["hunter's mark"], rank = 4, duration = 120 },
			},
		},
		freezingtrap = {
			category = "cc",
			class = "hunter",
			raidRelevant = false,
			-- Note: These are the DEBUFF effect IDs, not the trap placement IDs (1499, 14310, 14311)
			spells = {
				[3355] = { name = L["freezing trap"], rank = 1, duration = 10 },
				[14308] = { name = L["freezing trap"], rank = 2, duration = 15 },
				[14309] = { name = L["freezing trap"], rank = 3, duration = 20 },
			},
		},
		scattershot = {
			category = "cc",
			class = "hunter",
			raidRelevant = false,
			spells = {
				[19503] = { name = L["scatter shot"], rank = 1, duration = 4 },
			},
		},
		wyvernsting = {
			category = "cc",
			class = "hunter",
			raidRelevant = false,
			spells = {
				[19386] = { name = L["wyvern sting"], rank = 1, duration = 12 },
				[24132] = { name = L["wyvern sting"], rank = 2, duration = 12 },
				[24133] = { name = L["wyvern sting"], rank = 3, duration = 12 },
			},
		},

		-- ============================================
		-- MAGE
		-- ============================================
		polymorph = {
			category = "cc",
			class = "mage",
			raidRelevant = false,
			spells = {
				-- Sheep
				[118] = { name = L["polymorph"], rank = 1, duration = 20 },
				[12824] = { name = L["polymorph"], rank = 2, duration = 30 },
				[12825] = { name = L["polymorph"], rank = 3, duration = 40 },
				[12826] = { name = L["polymorph"], rank = 4, duration = 50 },
				-- Pig
				[28272] = { name = L["polymorph"], rank = 4, duration = 50 },
				-- Turtle
				[28271] = { name = L["polymorph"], rank = 4, duration = 50 },
				-- Rodent (TurtleWoW Custom)
				[57561] = { name = L["polymorph"], rank = 4, duration = 50 },
			},
		},
		firevulnerability = {
			category = "spellvuln",
			class = "mage",
			raidRelevant = true,
			stacks = 5,
			isProc = true,
			triggerSpells = { 2948, 8444, 8445, 8446, 11352, 11353 }, -- Scorch Ranks
			spells = {
				[22959] = { name = L["fire vulnerability"], rank = 1, duration = 30 },
			},
		},
		winterschill = {
			category = "spellvuln",
			class = "mage",
			raidRelevant = true,
			stacks = 5,
			isProc = true,
			-- Talent IDs: 11180, 28592, 28593, 28594, 28595 (proc on any Frost spell hit)
			-- Triggers: Frostbolt (all ranks) as most common trigger
			triggerSpells = {
				116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, -- Frostbolt R1-R10
				120, 8492, 10159, 10160, 10161, -- Cone of Cold R1-R5
			},
			spells = {
				[12579] = { name = L["winter's chill"], rank = 1, duration = 15 },
			},
		},
		ignite = {
			category = "personal",
			class = "mage",
			raidRelevant = false,
			isProc = true,
			spells = {
				[12654] = { name = L["ignite"], rank = 1, duration = 4 },
			},
		},

		-- ============================================
		-- PALADIN
		-- ============================================
		judgementoflight = {
			category = "utility",
			class = "paladin",
			raidRelevant = false,
			stacks = 5,
			spells = {
				[20185] = { name = L["judgement of light"], rank = 1, duration = 10 },
				[20344] = { name = L["judgement of light"], rank = 2, duration = 10 },
				[20345] = { name = L["judgement of light"], rank = 3, duration = 10 },
				[20346] = { name = L["judgement of light"], rank = 4, duration = 10 },
			},
		},
		judgementofwisdom = {
			category = "utility",
			class = "paladin",
			raidRelevant = false,
			stacks = 5,
			spells = {
				[20186] = { name = L["judgement of wisdom"], rank = 1, duration = 10 },
				[20354] = { name = L["judgement of wisdom"], rank = 2, duration = 10 },
				[20355] = { name = L["judgement of wisdom"], rank = 3, duration = 10 },
			},
		},
		judgementofthecrusader = {
			category = "utility",
			class = "paladin",
			raidRelevant = false,
			stacks = 5,
			spells = {
				[21183] = { name = L["judgement of the crusader"], rank = 1, duration = 10 },
				[20188] = { name = L["judgement of the crusader"], rank = 2, duration = 10 },
				[20300] = { name = L["judgement of the crusader"], rank = 3, duration = 10 },
				[20301] = { name = L["judgement of the crusader"], rank = 4, duration = 10 },
				[20302] = { name = L["judgement of the crusader"], rank = 5, duration = 10 },
				[20303] = { name = L["judgement of the crusader"], rank = 6, duration = 10 },
			},
		},
		hammerofjustice = {
			category = "cc",
			class = "paladin",
			raidRelevant = false,
			spells = {
				[853] = { name = L["hammer of justice"], rank = 1, duration = 3 },
				[5588] = { name = L["hammer of justice"], rank = 2, duration = 4 },
				[5589] = { name = L["hammer of justice"], rank = 3, duration = 5 },
				[10308] = { name = L["hammer of justice"], rank = 4, duration = 6 },
			},
		},

		-- ============================================
		-- PRIEST
		-- ============================================
		shadowweaving = {
			category = "spellvuln",
			class = "priest",
			raidRelevant = true,
			stacks = 5,
			isProc = true,
			-- Talent IDs: 15257, 15331, 15332, 15333, 15334 (proc on Shadow spell hit)
			-- Triggers: Shadow Word: Pain, Mind Blast, Mind Flay as common Shadow casts
			triggerSpells = {
				589, 594, 970, 992, 2767, 10892, 10893, 10894, -- Shadow Word: Pain R1-R8
				8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947, -- Mind Blast R1-R9
				15407, 17311, 17312, 17313, 17314, -- Mind Flay R1-R5
			},
			spells = {
				[15258] = { name = L["shadow weaving"], rank = 1, duration = 15 },
			},
		},
		shackleundead = {
			category = "cc",
			class = "priest",
			raidRelevant = false,
			spells = {
				[9484] = { name = L["shackle undead"], rank = 1, duration = 30 },
				[9485] = { name = L["shackle undead"], rank = 2, duration = 40 },
				[10955] = { name = L["shackle undead"], rank = 3, duration = 50 },
			},
		},
		mindcontrol = {
			category = "cc",
			class = "priest",
			raidRelevant = false,
			spells = {
				[605] = { name = L["mind control"], rank = 1, duration = 60 },
				[10911] = { name = L["mind control"], rank = 2, duration = 60 },
				[10912] = { name = L["mind control"], rank = 3, duration = 60 },
			},
		},
		psychicscream = {
			category = "cc",
			class = "priest",
			raidRelevant = false,
			spells = {
				[8122] = { name = L["psychic scream"], rank = 1, duration = 8 },
				[8124] = { name = L["psychic scream"], rank = 2, duration = 8 },
				[10888] = { name = L["psychic scream"], rank = 3, duration = 8 },
			},
		},

		-- ============================================
		-- ROGUE
		-- ============================================
		exposearmor = {
			category = "armor",
			class = "rogue",
			raidRelevant = true,
			displayStacks = true, -- CP count shown as stacks
			exclusiveWith = "sunderarmor", -- Sunder and EA cannot coexist on same target
			spells = {
				[8647] = { name = L["expose armor"], rank = 1, duration = 30 },
				[8649] = { name = L["expose armor"], rank = 2, duration = 30 },
				[8650] = { name = L["expose armor"], rank = 3, duration = 30 },
				[11197] = { name = L["expose armor"], rank = 4, duration = 30 },
				[11198] = { name = L["expose armor"], rank = 5, duration = 30 },
			},
		},
		woundpoison = {
			category = "healing",
			class = "rogue",
			raidRelevant = false,
			stacks = 5,
			-- TurtleWoW: Only 1 active rank, -5% Healing per stack
			spells = {
				[13218] = { name = L["wound poison"], rank = 1, duration = 15 },
			},
		},
		sap = {
			category = "cc",
			class = "rogue",
			raidRelevant = false,
			spells = {
				[6770] = { name = L["sap"], rank = 1, duration = 25 },
				[2070] = { name = L["sap"], rank = 2, duration = 35 },
				[11297] = { name = L["sap"], rank = 3, duration = 45 },
			},
		},

		-- ============================================
		-- WARLOCK - CURSES
		-- ============================================
		curseofrecklessness = {
			category = "armor",
			class = "warlock",
			raidRelevant = true,
			spells = {
				[704] = { name = L["curse of recklessness"], rank = 1, duration = 120 },
				[7658] = { name = L["curse of recklessness"], rank = 2, duration = 120 },
				[7659] = { name = L["curse of recklessness"], rank = 3, duration = 120 },
				[11717] = { name = L["curse of recklessness"], rank = 4, duration = 120 },
			},
		},
		curseoftheelements = {
			category = "spellvuln",
			class = "warlock",
			raidRelevant = true,
			spells = {
				[1490] = { name = L["curse of the elements"], rank = 1, duration = 300 },
				[11721] = { name = L["curse of the elements"], rank = 2, duration = 300 },
				[11722] = { name = L["curse of the elements"], rank = 3, duration = 300 },
			},
		},
		curseofshadow = {
			category = "spellvuln",
			class = "warlock",
			raidRelevant = true,
			spells = {
				[17862] = { name = L["curse of shadow"], rank = 1, duration = 300 },
				[17937] = { name = L["curse of shadow"], rank = 2, duration = 300 },
			},
		},
		curseoftongues = {
			category = "utility",
			class = "warlock",
			raidRelevant = false,
			spells = {
				[1714] = { name = L["curse of tongues"], rank = 1, duration = 30 },
				[11719] = { name = L["curse of tongues"], rank = 2, duration = 30 },
			},
		},
		curseofweakness = {
			category = "utility",
			class = "warlock",
			raidRelevant = false,
			spells = {
				[702] = { name = L["curse of weakness"], rank = 1, duration = 120 },
				[1108] = { name = L["curse of weakness"], rank = 2, duration = 120 },
				[6205] = { name = L["curse of weakness"], rank = 3, duration = 120 },
				[7646] = { name = L["curse of weakness"], rank = 4, duration = 120 },
				[11707] = { name = L["curse of weakness"], rank = 5, duration = 120 },
				[11708] = { name = L["curse of weakness"], rank = 6, duration = 120 },
			},
		},
		shadowvulnerability = {
			category = "spellvuln",
			class = "warlock",
			raidRelevant = true,
			isProc = true,
			-- ISB Talent: All 5 ranks (17793/17796/17801/17802/17803) trigger debuff 17794
			-- Triggers: Shadow Bolt (all ranks) + Drain Soul (all ranks)
			triggerSpells = {
				686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, -- Shadow Bolt R1-R9
				25307, -- Shadow Bolt R10 (TurtleWoW)
				1120, 8288, 8289, 11675, -- Drain Soul R1-R4
				51687, -- Drain Soul R5 (TurtleWoW)
			},
			spells = {
				[17794] = { name = L["shadow vulnerability"], rank = 1, duration = 10 },
			},
		},

		-- WARLOCK - CC
		banish = {
			category = "cc",
			class = "warlock",
			raidRelevant = false,
			spells = {
				[710] = { name = L["banish"], rank = 1, duration = 20 },
				[18647] = { name = L["banish"], rank = 2, duration = 30 },
			},
		},
		enslavedemon = {
			category = "cc",
			class = "warlock",
			raidRelevant = false,
			spells = {
				[1098] = { name = L["enslave demon"], rank = 1, duration = 300 },
				[11725] = { name = L["enslave demon"], rank = 2, duration = 300 },
				[11726] = { name = L["enslave demon"], rank = 3, duration = 300 },
			},
		},
		fear = {
			category = "cc",
			class = "warlock",
			raidRelevant = false,
			spells = {
				[5782] = { name = L["fear"], rank = 1, duration = 10 },
				[6213] = { name = L["fear"], rank = 2, duration = 15 },
				[6215] = { name = L["fear"], rank = 3, duration = 20 },
			},
		},
		howlofterror = {
			category = "cc",
			class = "warlock",
			raidRelevant = false,
			spells = {
				[5484] = { name = L["howl of terror"], rank = 1, duration = 10 },
				[17928] = { name = L["howl of terror"], rank = 2, duration = 15 },
			},
		},
		seduction = {
			category = "cc",
			class = "warlock",
			raidRelevant = false,
			spells = {
				[6358] = { name = L["seduction"], rank = 1, duration = 14 }, -- TurtleWoW: 14s (not 15s)
			},
		},

		-- ============================================
		-- WARRIOR
		-- ============================================
		sunderarmor = {
			category = "armor",
			class = "warrior",
			raidRelevant = true,
			stacks = 5,
			exclusiveWith = "exposearmor", -- Sunder and EA cannot coexist on same target
			spells = {
				[7386] = { name = L["sunder armor"], rank = 1, duration = 30 },
				[7405] = { name = L["sunder armor"], rank = 2, duration = 30 },
				[8380] = { name = L["sunder armor"], rank = 3, duration = 30 },
				[11596] = { name = L["sunder armor"], rank = 4, duration = 30 },
				[11597] = { name = L["sunder armor"], rank = 5, duration = 30 },
			},
		},
		demoshout = {
			category = "tank",
			class = "warrior",
			raidRelevant = false,
			spells = {
				[1160] = { name = L["demoralizing shout"], rank = 1, duration = 30 },
				[6190] = { name = L["demoralizing shout"], rank = 2, duration = 30 },
				[11554] = { name = L["demoralizing shout"], rank = 3, duration = 30 },
				[11555] = { name = L["demoralizing shout"], rank = 4, duration = 30 },
				[11556] = { name = L["demoralizing shout"], rank = 5, duration = 30 },
			},
		},
		thunderclap = {
			category = "tank",
			class = "warrior",
			raidRelevant = false,
			spells = {
				[6343] = { name = L["thunder clap"], rank = 1, duration = 30 },
				[8198] = { name = L["thunder clap"], rank = 2, duration = 30 },
				[8204] = { name = L["thunder clap"], rank = 3, duration = 30 },
				[8205] = { name = L["thunder clap"], rank = 4, duration = 30 },
				[11580] = { name = L["thunder clap"], rank = 5, duration = 30 },
				[11581] = { name = L["thunder clap"], rank = 6, duration = 30 },
			},
		},
		mortalstrike = {
			category = "healing",
			class = "warrior",
			raidRelevant = false,
			spells = {
				[12294] = { name = L["mortal strike"], rank = 1, duration = 10 },
				[21551] = { name = L["mortal strike"], rank = 2, duration = 10 },
				[21552] = { name = L["mortal strike"], rank = 3, duration = 10 },
				[21553] = { name = L["mortal strike"], rank = 4, duration = 10 },
			},
		},
		intimidatingshout = {
			category = "cc",
			class = "warrior",
			raidRelevant = false,
			spells = {
				[5246] = { name = L["intimidating shout"], rank = 1, duration = 8 },
			},
		},

		-- ============================================
		-- WEAPON PROCS / ITEMS
		-- ============================================
		armorshatter = {
			category = "weaponproc",
			class = "item",
			raidRelevant = true,
			stacks = 3,
			isProc = true,
			spells = {
				[16928] = { name = L["armor shatter"], rank = 1, duration = 45 },
			},
		},
		spellvulnerability = {
			category = "weaponproc",
			class = "item",
			raidRelevant = true,
			isProc = true,
			spells = {
				[23605] = { name = L["spell vulnerability"], rank = 1, duration = 7 },
			},
		},
		thunderfury = {
			category = "weaponproc",
			class = "item",
			raidRelevant = true,
			isProc = true,
			spells = {
				[21992] = { name = L["thunderfury"], rank = 1, duration = 12 },
			},
		},
		giftofarthas = {
			category = "utility",
			class = "item",
			raidRelevant = false,
			isProc = true,
			spells = {
				[11374] = { name = L["gift of arthas"], rank = 1, duration = 180 },
			},
		},
		puncturearmor = {
			category = "armor",
			class = "item",
			raidRelevant = false,
			stacks = 3,
			isProc = true,
			spells = {
				[17315] = { name = L["puncture armor"], rank = 1, duration = 30 },
			},
		},
		potentvenom = {
			category = "utility",
			class = "item",
			raidRelevant = false,
			isProc = true,
			spells = {
				[45416] = { name = L["potent venom"], rank = 1, duration = 12 },
			},
		},
	}
end

-- Backward compatibility: build flat spell lookup from new structure
-- This allows existing code (curses.sharedDebuffs.faeriefire[spellID]) to keep working
function getSharedDebuffsFlat()
	local debuffs = getSharedDebuffs()
	local flat = {}
	for key, data in pairs(debuffs) do
		flat[key] = {}
		if data.spells then
			for spellID, spellData in pairs(data.spells) do
				flat[key][spellID] = spellData
			end
		end
	end
	return flat
end

-- Get metadata for a debuff key (category, class, raidRelevant, stacks, isProc, etc.)
function getSharedDebuffMeta(debuffKey)
	local debuffs = getSharedDebuffs()
	local data = debuffs[debuffKey]
	if not data then return nil end
	return {
		category = data.category,
		class = data.class,
		raidRelevant = data.raidRelevant,
		stacks = data.stacks,
		isProc = data.isProc,
		triggerSpells = data.triggerSpells,
		displayStacks = data.displayStacks,
	}
end

-- Get all debuff keys filtered by property
function getSharedDebuffKeys(filterKey, filterValue)
	local debuffs = getSharedDebuffs()
	local result = {}
	for key, data in pairs(debuffs) do
		if data[filterKey] == filterValue then
			table.insert(result, key)
		end
	end
	return result
end
