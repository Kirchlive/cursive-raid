# Cursive v3.2 — Finale Spell-ID Referenz (TurtleWoW-verifiziert)

> **Stand:** 7. Februar 2026
> **Verifiziert gegen:** database.turtlecraft.gg (primär), classicdb.ch (sekundär)
> **Alle IDs sind die DEBUFF-IDs** (Aura auf dem Target), nicht Talent/Lern-IDs

---

## DRUID

### Faerie Fire (Caster)
| Rank | Spell ID | Duration | Armor Red. |
|------|----------|----------|------------|
| 1 | 770 | 40s | -175 |
| 2 | 778 | 40s | -285 |
| 3 | 9749 | 40s | -395 |
| 4 | 9907 | 40s | -505 |

### Faerie Fire (Feral)
| Rank | Spell ID | Duration | Armor Red. |
|------|----------|----------|------------|
| 1 | 16857 | 40s | -175 |
| 2 | 17390 | 40s | -285 |
| 3 | 17391 | 40s | -395 |
| 4 | 17392 | 40s | -505 |

### Faerie Fire (Bear)
| Rank | Spell ID | Duration | Armor Red. |
|------|----------|----------|------------|
| 1 | 16855 | 40s | -175 |
| 2 | 17387 | 40s | -285 |
| 3 | 17388 | 40s | -395 |
| 4 | 17389 | 40s | -505 |

### Demoralizing Roar
| Rank | Spell ID | Duration | AP Red. |
|------|----------|----------|---------|
| 1 | 99 | 30s | -30 |
| 2 | 1735 | 30s | -52 |
| 3 | 9490 | 30s | -78 |
| 4 | 9747 | 30s | -108 |
| 5 | 9898 | 30s | -138 |

### Hibernate (CC)
| Rank | Spell ID | Duration | Targets |
|------|----------|----------|---------|
| 1 | 2637 | 20s | Beasts, Dragonkin |
| 2 | 18657 | 30s | Beasts, Dragonkin |
| 3 | 18658 | 40s | Beasts, Dragonkin |

---

## HUNTER

### Hunter's Mark
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 1130 | 120s |
| 2 | 14323 | 120s |
| 3 | 14324 | 120s |
| 4 | 14325 | 120s |

### Freezing Trap Effect (Debuff-IDs, NICHT Cast-IDs!)
| Rank | Spell ID | Duration | Cast-ID (Trap) |
|------|----------|----------|----------------|
| 1 | 3355 | 10s | 1499 |
| 2 | 14308 | 15s | 14310 |
| 3 | 14309 | 20s | 14311 |

### Scatter Shot
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 19503 | 4s |

### Wyvern Sting (CC)
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 19386 | 12s |
| 2 | 24132 | 12s |
| 3 | 24133 | 12s |

---

## MAGE

### Polymorph (CC)
| Variant | Spell ID | Duration |
|---------|----------|----------|
| Sheep R1 | 118 | 20s |
| Sheep R2 | 12824 | 30s |
| Sheep R3 | 12825 | 40s |
| Sheep R4 | 12826 | 50s |
| Pig | 28272 | 50s |
| Turtle | 28271 | 50s |
| Rodent | **57561** | 50s |

### Fire Vulnerability (Improved Scorch Proc)
| Spell ID | Duration | Stacks | Effect |
|----------|----------|--------|--------|
| **22959** | 30s | 5 | +3% Fire Dmg/Stack |

> ⚡ PROC — nicht über UNIT_CASTEVENT trackbar. Scorch-Cast-IDs: 2948, 8444, 8445, 8446, 11352, 11353

### Winter's Chill (Proc)
| Spell ID | Duration | Stacks | Effect |
|----------|----------|--------|--------|
| **12579** | 15s | 5 | +2% Frost Crit/Stack |

> ⚡ PROC — Talent-IDs (Cast): 11180, 28592-28595

### Ignite (Proc)
| Spell ID | Duration | Effect |
|----------|----------|--------|
| 12654 | 4s | Fire DoT (% of crit dmg) |

---

## PALADIN

### Judgement of Light
| Rank | Spell ID | Duration | Stacks |
|------|----------|----------|--------|
| 1 | 20185 | 10s | 5 |
| 2 | 20344 | 10s | 5 |
| 3 | 20345 | 10s | 5 |
| 4 | 20346 | 10s | 5 |

### Judgement of Wisdom
| Rank | Spell ID | Duration | Stacks |
|------|----------|----------|--------|
| 1 | 20186 | 10s | 5 |
| 2 | 20354 | 10s | 5 |
| 3 | 20355 | 10s | 5 |

### Judgement of the Crusader
| Rank | Spell ID | Duration | Stacks |
|------|----------|----------|--------|
| 1 | 21183 | 10s | 5 |
| 2 | 20188 | 10s | 5 |
| 3 | 20300 | 10s | 5 |
| 4 | 20301 | 10s | 5 |
| 5 | 20302 | 10s | 5 |
| 6 | 20303 | 10s | 5 |

### Hammer of Justice (CC)
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 853 | 3s |
| 2 | 5588 | 4s |
| 3 | 5589 | 5s |
| 4 | 10308 | 6s |

---

## PRIEST

### Shadow Weaving (Proc)
| Spell ID | Duration | Stacks | Effect |
|----------|----------|--------|--------|
| **15258** | 15s | 5 | +3% Shadow Dmg/Stack |

> ⚡ PROC — Debuff-Name auf TurtleWoW ist "Shadow Weaving" (KEINE Naming-Collision mit ISB!)
> Talent-IDs: 15257, 15331-15334

### Shackle Undead (CC)
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 9484 | 30s |
| 2 | 9485 | 40s |
| 3 | 10955 | 50s |

### Mind Control (CC)
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 605 | Channel |
| 2 | 10911 | Channel |
| 3 | 10912 | Channel |

### Psychic Scream (CC)
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 8122 | 8s |
| 2 | 8124 | 8s |
| 3 | 10888 | 8s |

---

## ROGUE

### Expose Armor
| Rank | Spell ID | Duration | Stacks | Note |
|------|----------|----------|--------|------|
| 1 | 8647 | 30s | 1-5 | Stacks = Combo Points bei Cast |
| 2 | 8649 | 30s | 1-5 | Mutually exclusive mit Sunder Armor |
| 3 | 8650 | 30s | 1-5 | |
| 4 | 11197 | 30s | 1-5 | |
| 5 | 11198 | 30s | 1-5 | |

> ⚠️ Expose Armor ist technisch 1 Debuff, aber die **Combo Points bei Cast werden als Stacks angezeigt**.
> 2 CP = 2 Stacks, 5 CP = 5 Stacks. Die Armor-Reduktion skaliert entsprechend.

### Wound Poison (TurtleWoW Custom!)
| Spell ID | Duration | Stacks | Effect |
|----------|----------|--------|--------|
| **13218** | 15s | 5 | **-5% Healing/Stack** |

> ⚠️ TurtleWoW hat nur 1 aktiven Rank! Ranks 2-4 (13222-13224) sind [Deprecated].
> Umgestellt auf prozentuale Reduktion statt flat.

### Sap (CC)
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 6770 | 25s |
| 2 | 2070 | 35s |
| 3 | 11297 | 45s |

---

## WARLOCK — Curses

### Curse of Recklessness
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 704 | 120s |
| 2 | 7658 | 120s |
| 3 | 7659 | 120s |
| 4 | 11717 | 120s |

### Curse of the Elements
| Rank | Spell ID | Duration | Effect |
|------|----------|----------|--------|
| 1 | 1490 | 300s | +Fire/Frost Dmg, -Resist |
| 2 | 11721 | 300s | +Fire/Frost Dmg, -Resist |
| 3 | 11722 | 300s | +Fire/Frost Dmg, -Resist |

### Curse of Shadow
| Rank | Spell ID | Duration | Effect |
|------|----------|----------|--------|
| 1 | 17862 | 300s | +Shadow/Arcane Dmg, -Resist |
| 2 | 17937 | 300s | +Shadow/Arcane Dmg, -Resist |

### Curse of Tongues
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 1714 | 30s |
| 2 | 11719 | 30s |

### Curse of Weakness
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 702 | 120s |
| 2 | 1108 | 120s |
| 3 | 6205 | 120s |
| 4 | 7646 | 120s |
| 5 | 11707 | 120s |
| 6 | 11708 | 120s |

### Shadow Vulnerability (ISB Proc)
| Spell ID | Duration | Stacks | Effect |
|----------|----------|--------|--------|
| **17794** | 10s | 1 | +20% Shadow Dmg |

> ⚡ PROC — Alle 5 Talent-Ranks (17793/17796/17801/17802/17803) triggern → 17794
> IDs 17797-17800 sind alle zzOLD/deprecated auf TurtleWoW

---

## WARLOCK — CC

### Banish
| Rank | Spell ID | Duration | Targets |
|------|----------|----------|---------|
| 1 | 710 | 20s | Demons, Elementals |
| 2 | 18647 | 30s | Demons, Elementals |

### Enslave Demon
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 1098 | 300s |
| 2 | 11725 | 300s |
| 3 | 11726 | 300s |

### Fear
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 5782 | 10s |
| 2 | 6213 | 15s |
| 3 | 6215 | 20s |

### Howl of Terror
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 5484 | 10s |
| 2 | 17928 | 15s |

### Seduction (Succubus)
| Spell ID | Duration |
|----------|----------|
| 6358 | **14s** |

> ⚠️ TurtleWoW: 14s (nicht 15s wie in Vanilla)

---

## WARRIOR

### Sunder Armor
| Rank | Spell ID | Duration | Stacks | Armor Red./Stack |
|------|----------|----------|--------|------------------|
| 1 | 7386 | 30s | 5 | -90 |
| 2 | 7405 | 30s | 5 | -135 |
| 3 | 8380 | 30s | 5 | -180 |
| 4 | 11596 | 30s | 5 | -225 |
| 5 | 11597 | 30s | 5 | -270 |

### Demoralizing Shout
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 1160 | 30s |
| 2 | 6190 | 30s |
| 3 | 11554 | 30s |
| 4 | 11555 | 30s |
| 5 | 11556 | 30s |

### Thunder Clap
| Rank | Spell ID | Duration |
|------|----------|----------|
| 1 | 6343 | 30s |
| 2 | 8198 | 30s |
| 3 | 8204 | 30s |
| 4 | 8205 | 30s |
| 5 | 11580 | 30s |
| 6 | 11581 | 30s |

### Mortal Strike
| Rank | Spell ID | Duration | Effect |
|------|----------|----------|--------|
| 1 | 12294 | 10s | -50% Healing |
| 2 | 21551 | 10s | -50% Healing |
| 3 | 21552 | 10s | -50% Healing |
| 4 | 21553 | 10s | -50% Healing |

### Intimidating Shout (CC)
| Spell ID | Duration |
|----------|----------|
| 5246 | 8s |

---

## WEAPON PROCS / ITEMS

### Spell Vulnerability (Nightfall)
| Spell ID | Duration | Effect |
|----------|----------|--------|
| 23605 | **7s** | +10% Spell Dmg |

### Armor Shatter (Annihilator)
| Spell ID | Duration | Stacks | Armor Red./Stack |
|----------|----------|--------|------------------|
| 16928 | 45s | 3 | **-100** (max -300) |

### Gift of Arthas
| Spell ID | Duration | Effect | Dispel |
|----------|----------|--------|--------|
| 11374 | 180s | **+8 Physical Dmg taken** | Disease |

### Thunderfury
| Spell ID | Duration | Effect |
|----------|----------|--------|
| 21992 | 12s | -25 Nature Resist, -20% Atk Speed |

---

## ⚡ Tracking-Methodik

### Direkte Casts → UNIT_CASTEVENT trackbar
Sunder Armor, Faerie Fire, Curses, Hunter's Mark, Expose Armor, alle CCs, Demoralizing Shout/Roar, Thunder Clap, Mortal Strike

### Procs → NICHT über UNIT_CASTEVENT trackbar
| Debuff | Debuff-ID | Getriggert durch |
|--------|-----------|------------------|
| Shadow Vulnerability (ISB) | 17794 | Shadow Bolt/Drain Soul Crit |
| Fire Vulnerability | 22959 | Scorch Cast (Improved Scorch Talent) |
| Winter's Chill | 12579 | Frost Spell Hit |
| Shadow Weaving | 15258 | Shadow Spell Hit |
| Ignite | 12654 | Fire Spell Crit |
| Spell Vulnerability | 23605 | Nightfall Weapon Proc |
| Armor Shatter | 16928 | Annihilator Weapon Proc |

> Diese Debuffs brauchen alternatives Tracking (Combat Log, UnitDebuff-Scan, oder addon-to-addon Kommunikation)

---

*TurtleWoW-verifiziert am 7. Februar 2026 — database.turtlecraft.gg*
