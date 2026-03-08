# TurtleWoW Database Re-Verification Report

> **Stand:** 7. Februar 2026
> **Quelle:** https://database.turtlecraft.gg/ (ausschließlich)
> **Methode:** Jede Spell-ID einzeln via web_fetch gegen database.turtlecraft.gg geprüft
> **Referenz:** spell-id-verification.md (vorheriger Report)

---

## Ergebnis-Übersicht

| # | Spell | Status | Anmerkung |
|---|-------|--------|-----------|
| 1 | Polymorph: Rodent (57561) | ✅ BESTÄTIGT | 57561 = Cast, 57560 = Learn Spell |
| 2 | Shadow Vulnerability / ISB (17794) | ✅ BESTÄTIGT | Einzige aktive Debuff-ID, 17797-17800 sind zzOLD |
| 3 | Freezing Trap Effect (3355, 14308, 14309) | ✅ BESTÄTIGT | R1/R2/R3, 10/15/20s |
| 4 | Winter's Chill (12579) | ✅ BESTÄTIGT | +2% Frost Crit, 15s, Magic |
| 5 | Fire Vulnerability (22959) | ✅ BESTÄTIGT | +3% Fire Dmg, 30s, Magic |
| 6 | Shadow Weaving (15258) | ✅ BESTÄTIGT | Name = "Shadow Weaving", +3% Shadow, 15s |
| 7 | Spell Vulnerability / Nightfall (23605) | ✅ BESTÄTIGT | **+10% Spell Dmg, 7s** |
| 8 | Gift of Arthas (11374) | ✅ BESTÄTIGT | **+8 Physical Dmg**, Disease, 180s |
| 9 | Faerie Fire (Bear) (16855-17389) | ✅ BESTÄTIGT | Alle 4 Ranks AKTIV (nicht deprecated) |
| 10 | Wound Poison (13218 vs 13225) | ✅ BESTÄTIGT | 13218 = aktiv (-5% Healing), 13225 = [Deprecated] |
| 11 | Seduction (6358) | ⚠️ KORREKTUR | **14s** auf TurtleWoW (nicht 15s wie im vorherigen Report!) |
| 12 | Armor Shatter (16928) | ⚠️ KORREKTUR | **-100 Armor** pro Stack (nicht -200 wie im vorherigen Report!) |

---

## ⚠️ Generelle Regel: Learn-Spell vs Cast-Spell IDs

Viele Spells auf TurtleWoW haben **zwei IDs**:
- **Learn Spell** (Buch/Tome/Trainer) — Effect: "Learn Spell", Range: Self, School: Physical → **NICHT für Addon relevant**
- **Cast Spell** (der eigentliche Zauber) — hat Aura-Effekte, Duration, Dispel Type → **DAS ist die Debuff-ID fürs Addon**

**Für Cursive gilt immer:** Die ID verwenden, die den **Debuff auf dem Target** erzeugt (Apply Aura), nicht die Lern-ID.

Beispiel: Polymorph: Rodent → 57560 (Learn) vs **57561** (Cast/Debuff)

Bei jeder neuen Spell-ID prüfen: Hat der Spell tatsächlich einen Aura-Effekt auf ein Target, oder ist es nur ein Lern-/Enchant-/Summon-Spell?

---

## Detaillierte Verifizierung

### 1. Polymorph: Rodent ✅

| Spell ID | TurtleWoW DB | Status |
|----------|--------------|--------|
| **57561** | "Polymorph: Rodent" — Arcane, 50s, 1.5s cast, 150 mana, 30yd, Confuse+Transform, Dispel: Magic | ✅ **Korrekter Cast-Spell** |
| 57560 | "Polymorph: Rodent" — "Teaches Polymorph: Rodent", 3s cast, Learn Spell → 57561 | ❌ Lern-Spell |

**Fazit:** Rob hat Recht. **57561** ist der Cast, 57560 ist der Lern-Spell. TurtleWoW Custom Spell, existiert nicht auf classicdb.

---

### 2. Shadow Vulnerability (ISB) ✅

**Talent-Ranks (alle procen → 17794):**

| Spell ID | TurtleWoW DB Name | Proc Chance | Triggered Spell |
|----------|-------------------|-------------|-----------------|
| 17793 | Shadow Vulnerability R1 | 2% (SB/Drain Soul) | → 17794 |
| 17796 | Shadow Vulnerability R2 | 4% (SB/Drain Soul) | → 17794 |
| 17801 | Shadow Vulnerability R3 | 6% (SB/Drain Soul) | → 17794 |
| 17802 | Shadow Vulnerability R4 | 8% (SB/Drain Soul) | → 17794 |
| 17803 | Shadow Vulnerability R5 | 10% (SB/Drain Soul) | → 17794 |

**Debuff (der auf dem Target landet):**

| Spell ID | TurtleWoW DB Name | Effekt | Duration | Dispel |
|----------|-------------------|--------|----------|--------|
| **17794** | Shadow Vulnerability | +20% Shadow Dmg Taken (Aura #87, school mask 32) | **10s** | Magic |

**Deprecated IDs (zzOLD):**

| Spell ID | TurtleWoW DB Name | Value | Duration | Status |
|----------|-------------------|-------|----------|--------|
| 17797 | zzOLD Shadow Vulnerability R3 | +12% | 12s | ❌ DEPRECATED |
| 17798 | zzOLD Shadow Vulnerability R2 | +8% | 12s | ❌ DEPRECATED |
| 17799 | zzOLD Shadow Vulnerability R4 | +16% | 12s | ❌ DEPRECATED |
| 17800 | zzOLD Shadow Vulnerability R5 | +20% | 12s | ❌ DEPRECATED |

**Fazit:** Vorheriger Report korrekt. Nur **17794** ist der aktive Debuff. 17797-17800 sind alle "zzOLD" und deprecated. Alle 5 Talent-Ranks triggern denselben Debuff 17794.

---

### 3. Freezing Trap Effect ✅

| Spell ID | TurtleWoW DB Name | Rank | Duration | School | Mechanic | Dispel |
|----------|-------------------|------|----------|--------|----------|--------|
| **3355** | Freezing Trap Effect | R1 | 10s | Frost | frozen | Magic |
| **14308** | Freezing Trap Effect | R2 | 15s | Frost | frozen | Magic |
| **14309** | Freezing Trap Effect | R3 | 20s | Frost | frozen | Magic |

**Fazit:** Alle 3 bestätigt. Stun-Aura, korrekte Durations.

---

### 4. Winter's Chill (12579) ✅

| Feld | TurtleWoW DB Wert |
|------|-------------------|
| Name | Winter's Chill |
| Spell ID | 12579 |
| School | Frost |
| Duration | 15 seconds |
| Dispel | Magic |
| Effekt | Apply Aura: Unknown_Aura(179) — Value: 2 |
| Range | 100yd (Vision) |

**Hinweis:** "Unknown_Aura(179)" = Mod Spell Crit Chance Taken. +2% Frost Crit pro Stack.

**Fazit:** Bestätigt. 12579 ist der einzige Debuff.

---

### 5. Fire Vulnerability (22959) ✅

| Feld | TurtleWoW DB Wert |
|------|-------------------|
| Name | Fire Vulnerability |
| Spell ID | 22959 |
| School | Fire |
| Duration | 30 seconds |
| Dispel | Magic |
| Effekt | Mod Dmg % Taken (school mask 4 = Fire) — Value: 3 |
| Range | 100yd (Vision) |

**Fazit:** Bestätigt. +3% Fire Dmg per stack, 30s. Einzige Debuff-ID.

---

### 6. Shadow Weaving (15258) ✅

| Feld | TurtleWoW DB Wert |
|------|-------------------|
| Name | **Shadow Weaving** (NICHT "Shadow Vulnerability"!) |
| Spell ID | 15258 |
| School | Shadow |
| Duration | 15 seconds |
| Dispel | Magic |
| Effekt | Mod Dmg % Taken (school mask 32 = Shadow) — Value: 3 |
| Range | 100yd (Vision) |

**Fazit:** Bestätigt. Name ist "Shadow Weaving" auf TurtleWoW — keine Naming-Collision mit ISB's "Shadow Vulnerability" (17794).

---

### 7. Spell Vulnerability / Nightfall (23605) ✅

| Feld | TurtleWoW DB Wert |
|------|-------------------|
| Name | Spell Vulnerability |
| Spell ID | 23605 |
| Beschreibung | "Spell damage taken by target increased by 10% for 7 sec." |
| School | Physical |
| Duration | **7 seconds** |
| Effekt | Mod Dmg % Taken (school mask 126 = alle Spell-Schools) — Value: **10** |
| Range | 5yd (Combat) |
| Dispel | n/a |

**Fazit:** Bestätigt. **+10% Spell Dmg, 7s**. Die TurtleWoW-Werte (nicht Vanilla's 15%/5s).

---

### 8. Gift of Arthas (11374) ✅

| Feld | TurtleWoW DB Wert |
|------|-------------------|
| Name | Gift of Arthas |
| Spell ID | 11374 |
| Beschreibung | "Increases physical damage taken by 8 for 180 sec" |
| School | Nature |
| Duration | 180 seconds |
| Effekt | Mod Damage Taken (school mask 1 = **Physical**) — Value: **8** |
| Dispel | Disease |
| Range | 5yd (Combat) |

**Fazit:** Bestätigt. **+8 Physical Damage** (NICHT Shadow!). Spec-Korrektur nötig.

---

### 9. Faerie Fire (Bear) ✅

| Spell ID | TurtleWoW DB Name | Rank | Armor Reduction | Duration | Status |
|----------|-------------------|------|-----------------|----------|--------|
| **16855** | Faerie Fire (Bear) R1 | 1 | -175 | 40s | ✅ AKTIV |
| **17387** | Faerie Fire (Bear) R2 | 2 | -285 | 40s | ✅ AKTIV |
| **17388** | Faerie Fire (Bear) R3 | 3 | -395 | 40s | ✅ AKTIV |
| **17389** | Faerie Fire (Bear) R4 | 4 | -505 | 40s | ✅ AKTIV |

Alle haben: School = Nature, Dispel = Magic, Cost = 50 Mana, Range = 30yd.
Zusätzliche Effekte: Immune Dispel Type (Stealth + Invisibility Prevention).

**Fazit:** Bestätigt. Alle 4 Ranks sind auf TurtleWoW AKTIV (nicht "zzOLD" / deprecated wie auf classicdb). Beibehalten!

---

### 10. Wound Poison ✅

| Spell ID | TurtleWoW DB Name | Status | Effekt |
|----------|-------------------|--------|--------|
| **13218** | Wound Poison | ✅ AKTIV | Mod Healing % (Aura #118) = **-5%** pro Stack, 15s, Poison, Nature |
| 13222 | [Deprecated] Wound Poison R2 | ❌ | -75 flat (Aura #115), Poison |
| 13223 | [Deprecated] Wound Poison R3 | ❌ | -105 flat, Poison |
| 13224 | [Deprecated] Wound Poison R4 | ❌ | -135 flat, Poison |
| 13225 | [Deprecated] Wound Poison R2 | ❌ | **Enchant Item Temporary** (Weapon Coating), nicht der Debuff! |

**Wichtig zu 13225:** Auf TurtleWoW ist 13225 ein "[Deprecated] Wound Poison" Rank 2, aber als **Enchant Item Temporary** (Weapon Coating Spell) — kein Debuff auf das Target! Es ist also doppelt falsch: deprecated UND kein Debuff.

**Fazit:** Bestätigt. **Nur 13218** ist der aktive Wound Poison Debuff auf TurtleWoW. -5% Healing pro Stack (Prozent, nicht flat!), 15s, Poison.

---

## ⚠️ NEU GEFUNDENE KORREKTUREN

### 11. Seduction (6358) — Duration-Korrektur

| Feld | Vorheriger Report | TurtleWoW DB |
|------|-------------------|--------------|
| Duration | 15s | **14s** |
| School | Shadow | Shadow ✅ |
| Mechanic | charmed | charmed ✅ |
| Dispel | Magic | Magic ✅ |

**Fazit:** Die Seduction-Duration auf TurtleWoW ist **14 Sekunden**, nicht 15s. Spec/vorheriger Report muss korrigiert werden.

---

### 12. Armor Shatter (16928) — Armor-Wert-Korrektur

| Feld | Vorheriger Report | TurtleWoW DB |
|------|-------------------|--------------|
| Name | Armor Shatter | Armor Shatter ✅ |
| Armor Reduction | -200 pro Stack | **-100 pro Stack** |
| Stacks | 3 | 3 (per Beschreibung) ✅ |
| Duration | 45s | 45s ✅ |
| School | - | Shadow |

TurtleWoW DB zeigt: "Reduces an enemy's armor by 100. Stacks up to 3 times."
Aura #22: Mod Resistance (1) — Value: -100

**Fazit:** Annihilator's Armor Shatter reduziert **-100 Armor pro Stack** (max -300 bei 3 Stacks), nicht -200 wie im vorherigen Report angegeben.

---

## Stichproben-Verifizierung (Spot Checks)

### Bestätigte Spells

| Spell ID | Name auf TurtleWoW | Details | Status |
|----------|---------------------|---------|--------|
| 21992 | Thunderfury | Nature, 12s, -25 NR, -20% AtkSpd, 300 dmg | ✅ |
| 12654 | Ignite | Fire, 4s, Periodic Damage (DoT) | ✅ |
| 19503 | Scatter Shot | Physical, 4s Disorient, 50% weapon dmg | ✅ |
| 6358 | Seduction | Shadow, **14s**, Stun, Magic | ⚠️ 14s nicht 15s |
| 5246 | Intimidating Shout | Physical, 8s, Fear+Speed debuff | ✅ |
| 8647 | Expose Armor R1 | Physical, 30s, scales with CP (80-400) | ✅ |
| 17862 | Curse of Shadow R1 | Shadow, 300s, -60 Shadow/Arcane Resist + 8% dmg | ✅ |
| 21183 | Judgement of the Crusader R1 | Holy, 10s, +20 Holy dmg taken | ✅ |
| 12294 | Mortal Strike R1 | Physical, 10s, -50% Healing, 115% weapon dmg | ✅ |
| 99 | Demoralizing Roar R1 | Physical, 30s, -30 AP | ✅ |
| 7386 | Sunder Armor R1 | Physical, 30s, -90 Armor | ✅ |
| 770 | Faerie Fire R1 | Nature, 40s, -175 Armor, Magic, anti-stealth | ✅ |
| 16857 | Faerie Fire (Feral) R1 | Nature, 40s, -175 Armor, Magic | ✅ |
| 19386 | Wyvern Sting R1 | Nature, 12s, Sleep (Stun), Poison | ✅ |
| 710 | Banish R1 | Shadow, 20s, Stun+Immune | ✅ |

### ISB-Talent Vollständige Kette (alle 5 Ranks verifiziert)

| Spell ID | Rank | Proc % | Triggered Debuff | Status |
|----------|------|--------|-----------------|--------|
| 17793 | R1 | 2% | → 17794 | ✅ |
| 17796 | R2 | 4% | → 17794 | ✅ |
| 17801 | R3 | 6% | → 17794 | ✅ |
| 17802 | R4 | 8% | → 17794 | ✅ |
| 17803 | R5 | 10% | → 17794 | ✅ |

Alle 5 Talent-Ranks haben auf TurtleWoW DB explizit den Link "Shadow Vulnerability → spell=17794" als Proc Trigger Spell. Die Beschreibung sagt: "Your Shadow Bolt and Drain Soul have a X% chance to increase Shadow damage dealt to the target by 20% for 10 sec, with a higher chance to trigger on critical hits."

---

## Zusammenfassung: Korrekturen zum vorherigen Report

### Bestätigt (keine Änderung nötig):
1. ✅ Polymorph: Rodent = 57561 (nicht 57560)
2. ✅ Shadow Vulnerability Debuff = nur 17794 (17797-17800 = zzOLD)
3. ✅ Freezing Trap Effect = 3355, 14308, 14309
4. ✅ Winter's Chill Debuff = 12579
5. ✅ Fire Vulnerability Debuff = 22959
6. ✅ Shadow Weaving Debuff = 15258 (Name: "Shadow Weaving")
7. ✅ Nightfall/Spell Vulnerability = 23605 (+10%, 7s)
8. ✅ Gift of Arthas = 11374 (+8 Physical, Disease)
9. ✅ Faerie Fire (Bear) = 16855, 17387, 17388, 17389 (alle aktiv)
10. ✅ Wound Poison = nur 13218 aktiv (-5% Healing), 13222-13225 deprecated

### NEU — Korrekturen nötig:
11. ⚠️ **Seduction (6358)**: Duration ist **14s** auf TurtleWoW (nicht 15s)
12. ⚠️ **Armor Shatter (16928)**: Armor-Reduktion ist **-100/Stack** auf TurtleWoW (nicht -200)

---

## Korrigierte Werte für Cursive

### Seduction — Korrigiert
```
Seduction (6358): 14s Duration, Shadow, Magic, Stun
```

### Armor Shatter — Korrigiert  
```
Armor Shatter (16928): -100 Armor/Stack, 3 Stacks max = -300 total, 45s, Shadow
```

### Alles andere: Unverändert zum vorherigen Report

---

*Alle 35+ Spell-IDs einzeln verifiziert gegen database.turtlecraft.gg am 7. Februar 2026*
