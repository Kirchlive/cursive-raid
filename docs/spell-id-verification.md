# Cursive v3.2 — Spell ID Verification Report

> **Stand:** 7. Februar 2026
> **Methode:** Systematische Prüfung gegen classicdb.ch (Vanilla 1.12 DB) und wowhead.com/classic
> **Ergebnis:** Mehrere kritische Fehler gefunden, Details unten

---

## Zusammenfassung der Fehler

| # | Debuff | Problem | Schwere |
|---|--------|---------|---------|
| 1 | Shadow Vulnerability (ISB) | Falsche IDs — Spec hat Talent-IDs statt Debuff-IDs | 🔴 KRITISCH |
| 2 | Freezing Trap | Falsche IDs — Spec hat Trap-Platzierungs-IDs statt Debuff-IDs | 🔴 KRITISCH |
| 3 | Winter's Chill | Falsche IDs — Spec hat Talent-IDs statt Debuff-ID | 🔴 KRITISCH |
| 4 | Fire Vulnerability | Falsche IDs — Spec hat alte/deprecated Talent-IDs statt Debuff-ID | 🔴 KRITISCH |
| 5 | Shadow Weaving | Falsche IDs — Spec hat Talent-IDs statt Debuff-ID | 🔴 KRITISCH |
| 6 | Expose Armor | Falsche Stacks-Angabe | 🟡 MITTEL |
| 7 | Wound Poison | 1 von 5 IDs ist falsch (Coating statt Debuff) | 🟠 HOCH |
| 8 | Polymorph: Rodent | Existiert nicht in 1.12 | 🟡 MITTEL |
| 9 | Faerie Fire (Bear) | Deprecated IDs (zzOLD) | 🟡 MITTEL |
| 10 | Gift of Arthas | Falsche Beschreibung in Spec | 🟢 GERING |
| 11 | Nightfall/Spell Vulnerability | Duration in Spec falsch | 🟢 GERING |

---

## ⚠️ KERNPROBLEM: Talent-IDs vs Debuff-IDs

Die Spec macht bei 5 Debuffs denselben Fehler: Sie listet die **Talent-Rang-IDs** (passive Aura auf dem Caster) statt der **Debuff-IDs** (Aura auf dem Target).

Für das Addon brauchen wir die **Debuff-IDs**, denn diese erscheinen auf dem Target als Aura.

Betroffene Debuffs:
- Shadow Vulnerability → 5 Talent-IDs gelistet, aber es gibt 5 verschiedene Debuff-IDs
- Winter's Chill → 5 Talent-IDs gelistet, aber nur 1 Debuff-ID
- Fire Vulnerability → 5 alte Talent-IDs gelistet, aber nur 1 Debuff-ID
- Shadow Weaving → 5 Talent-IDs gelistet, aber nur 1 Debuff-ID
- Freezing Trap → Trap-Platzierungs-IDs statt Debuff-Effekt-IDs

**Für UNIT_CASTEVENT-Detection brauchen wir die Cast-Spell-IDs (Talent/Ability). Für Debuff-Tracking auf dem Target brauchen wir die Debuff-IDs.**

**→ Die Spec muss BEIDE ID-Sets dokumentieren, je nach Tracking-Methode.**

---

## Detaillierte Verifizierung — Bekannte Diskrepanzen

### 1. Shadow Vulnerability (Warlock ISB)
- **Quelle:** https://classicdb.ch/?spell=17793 ff.
- **Verifiziert:** ❌
- **IDs korrekt:** Nein — Spec hat teilweise Talent-IDs, teilweise richtige Debuff-IDs
- **Spec hat:** 17793, 17796, 17800, 17801, 17803
- **Analyse:**

| Spell ID | Was ist es? | Typ |
|----------|-------------|-----|
| 17793 | Improved Shadow Bolt Rank 1 (4%) | TALENT (Passive auf Caster) |
| 17796 | Improved Shadow Bolt Rank 2 (8%) | TALENT (Passive auf Caster) |
| 17800 | Shadow Vulnerability (+20% Shadow) | ✅ DEBUFF auf Target |
| 17801 | Improved Shadow Bolt Rank 3 (12%) | TALENT (Passive auf Caster) |
| 17803 | Improved Shadow Bolt Rank 5 (20%) | TALENT (Passive auf Caster) |

**ISB Talent → Shadow Vulnerability Debuff Mapping:**

| Talent | Talent Spell ID | Debuff Spell ID | Shadow Dmg Increase |
|--------|----------------|-----------------|---------------------|
| ISB Rank 1 | 17793 | **17794** | +4% |
| ISB Rank 2 | 17796 | **17798** | +8% |
| ISB Rank 3 | 17801 | **17797** | +12% |
| ISB Rank 4 | 17802 | **17799** | +16% |
| ISB Rank 5 | 17803 | **17800** | +20% |

- **Korrekte Debuff-IDs:** `17794, 17797, 17798, 17799, 17800`
- **Notizen:**
  - Die "177801, 177802, 177803" in der Diskrepanz-Tabelle der Spec waren Tippfehler für 17801, 17802, 17803 (Talent-IDs)
  - Im Raid wird fast immer Rank 5 gespielt → Debuff-ID **17800** ist die wichtigste
  - **Für Addon:** Da ISB ein Proc ist (SB Crit → Debuff erscheint), muss per COMBAT_LOG nach Shadow Vulnerability Debuff-Application gescannt werden, nicht nach Cast. Die Debuff-IDs 17794-17800 sind die relevanten.

---

### 2. Freezing Trap (Hunter)
- **Quelle:** https://classicdb.ch/?spell=3355, https://classicdb.ch/?spell=1499
- **Verifiziert:** ❌
- **IDs korrekt:** Nein — Spec hat Trap-Platzierungs-IDs
- **Spec hat:** 1499, 14310, 14311

| Spell ID | Was ist es? | Typ |
|----------|-------------|-----|
| 1499 | Freezing Trap Rank 1 (Place Trap) | CAST — Summon Object |
| 14310 | Freezing Trap Rank 2 (Place Trap) | CAST — Summon Object |
| 14311 | Freezing Trap Rank 3 (Place Trap) | CAST — Summon Object |
| **3355** | **Freezing Trap Effect Rank 1** (Frozen 10s) | ✅ DEBUFF auf Target |
| **14308** | **Freezing Trap Effect Rank 2** (Frozen 15s) | ✅ DEBUFF auf Target |
| **14309** | **Freezing Trap Effect Rank 3** (Frozen 20s) | ✅ DEBUFF auf Target |

- **Korrekte Debuff-IDs:** `3355, 14308, 14309`
- **Cast-IDs (für UNIT_CASTEVENT):** `1499, 14310, 14311`
- **Notizen:** Die erste Liste in der Spec (3355, 14308, 14309) war korrekt! Die finale Liste (1499, 14310, 14311) ist falsch — das sind die Trap-Platzierungs-Spells.

---

### 3. Winter's Chill (Mage)
- **Quelle:** https://classicdb.ch/?spell=12579, https://classicdb.ch/?spell=11180
- **Verifiziert:** ❌
- **IDs korrekt:** Nein — Spec hat Talent-IDs statt Debuff-ID
- **Spec hat:** 11180, 28592, 28593, 28594, 28595

| Spell ID | Was ist es? | Typ |
|----------|-------------|-----|
| 11180 | Winter's Chill Talent Rank 1 (20% proc) | TALENT (Passive auf Caster) |
| 28592 | Winter's Chill Talent Rank 2 (40% proc) | TALENT (Passive auf Caster) |
| 28593 | Winter's Chill Talent Rank 3 (60% proc) | TALENT (Passive auf Caster) |
| 28594 | Winter's Chill Talent Rank 4 (80% proc) | TALENT (Passive auf Caster) |
| 28595 | Winter's Chill Talent Rank 5 (100% proc) | TALENT (Passive auf Caster) |
| **12579** | **Winter's Chill Debuff** (+2% Frost Crit, stacks) | ✅ DEBUFF auf Target |

- **Korrekte Debuff-ID:** `12579` (nur EINE ID, alle Talent-Ränge procen denselben Debuff)
- **Notizen:** Stacks up to 5 (je 2% = max 10% Frost Crit Bonus). Die erste Liste der Spec (12579) war korrekt!

---

### 4. Fire Vulnerability (Improved Scorch, Mage)
- **Quelle:** https://classicdb.ch/?spell=22959, https://classicdb.ch/?spell=22960
- **Verifiziert:** ❌
- **IDs korrekt:** Nein — Spec hat alte/deprecated Talent-IDs
- **Spec hat:** 22959, 22960, 22961, 22962, 22963, 22964

| Spell ID | Was ist es? | Typ |
|----------|-------------|-----|
| **22959** | **Fire Vulnerability Debuff** (+3% Fire Dmg, stacks 5x) | ✅ DEBUFF auf Target |
| 22960 | "zzOLDImproved Scorch" Rank 1 (20% proc) | ❌ DEPRECATED Talent |
| 22961 | "zzOLDImproved Scorch" Rank 2 (40% proc) | ❌ DEPRECATED Talent |
| 22962 | "zzOLDImproved Scorch" Rank 3 (60% proc) | ❌ DEPRECATED Talent |
| 22963-22964 | Vermutlich weitere zzOLD Ranks | ❌ DEPRECATED |

**Aktuelle Improved Scorch Talent-IDs:** 11095 (R1, 33%), 12872 (R2, 66%), 12873 (R3, 100%)

- **Korrekte Debuff-ID:** `22959` (nur EINE ID, alle Talent-Ränge procen denselben Debuff)
- **Notizen:** 22960-22964 sind "zzOLD"-prefixed (deprecated/removed) Spells. Stacks 5x à 3% = max 15% Fire Dmg.

---

### 5. Shadow Weaving (Priest)
- **Quelle:** https://classicdb.ch/?spell=15258, https://classicdb.ch/?spell=15257
- **Verifiziert:** ❌
- **IDs korrekt:** Nein — Spec hat Talent-IDs statt Debuff-ID
- **Spec hat:** 15257, 15331, 15332, 15333, 15334

| Spell ID | Was ist es? | Typ |
|----------|-------------|-----|
| 15257 | Shadow Weaving Talent Rank 1 (20% proc) | TALENT (Passive auf Caster) |
| 15331 | Shadow Weaving Talent Rank 2 (40% proc) | TALENT (Passive auf Caster) |
| 15332 | Shadow Weaving Talent Rank 3 (60% proc) | TALENT (Passive auf Caster) |
| 15333 | Shadow Weaving Talent Rank 4 (80% proc) | TALENT (Passive auf Caster) |
| 15334 | Shadow Weaving Talent Rank 5 (100% proc) | TALENT (Passive auf Caster) |
| **15258** | **Shadow Vulnerability Debuff** (+3% Shadow Dmg, stacks) | ✅ DEBUFF auf Target |

- **Korrekte Debuff-ID:** `15258` (nur EINE ID — der Debuff heißt "Shadow Vulnerability", nicht "Shadow Weaving")
- **Notizen:** Stacks 5x à 3% = max 15% Shadow Dmg. Die erste Liste (15258 allein) war korrekt! **Achtung:** Der Debuff-Name ist "Shadow Vulnerability" — gleicher Name wie ISB-Debuff, aber andere Spell-ID!

---

### 6. Expose Armor (Rogue)
- **Quelle:** https://classicdb.ch/?spell=8647
- **Verifiziert:** ⚠️
- **IDs korrekt:** Ja (die 5 Rank-IDs stimmen)
- **Stacks falsch:** Spec sagt "5 Stacks" — das ist **FALSCH**
- **Korrekte Spell IDs:** 8647, 8649, 8650, 11197, 11198 ✅

**Mechanik:** Expose Armor ist ein Finishing Move. Die Armor-Reduktion skaliert mit Combo Points:
- 1 CP: -80 Armor (Rank 1)
- 5 CP: -400 Armor (Rank 1)

Es ist **1 Debuff**, dessen Stärke bei Application von CP abhängt. Es stapelt sich NICHT. Erneutes Anwenden überschreibt den vorherigen Debuff.

- **Korrekte Stacks:** `1` (nicht 5!)
- **Notizen:** Die "5" bezog sich vermutlich auf die 5 Combo Points, nicht auf Stacks. Jede Rank hat höhere Armor-Werte pro CP. Mutually exclusive mit Sunder Armor.

---

### 7. Scorpid Sting (Hunter)
- **Quelle:** https://classicdb.ch/?spell=3043
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Korrekte IDs:** 3043, 14275, 14276, 14277
- **Notizen:** Scorpid Sting Ranks 1-4. Reduziert Strength + Agility. Duration 20s. Dispel type: Poison. Diese IDs sind sowohl Cast-IDs als auch Debuff-IDs (direkter Cast → Debuff).

---

### 8. Wound Poison (Rogue)
- **Quelle:** https://classicdb.ch/?spell=13218 ff.
- **Verifiziert:** ❌
- **IDs korrekt:** Teilweise — 1 von 5 IDs ist falsch
- **Spec hat:** 13218, 13222, 13223, 13224, 13225

| Spell ID | Was ist es? | Typ |
|----------|-------------|-----|
| 13218 | Wound Poison Rank 1 (-55 healing) | ✅ DEBUFF auf Target |
| 13222 | Wound Poison Rank 2 (-75 healing) | ✅ DEBUFF auf Target |
| 13223 | Wound Poison Rank 3 (-105 healing) | ✅ DEBUFF auf Target |
| 13224 | Wound Poison Rank 4 (-135 healing) | ✅ DEBUFF auf Target |
| 13225 | Wound Poison Rank 2 (Weapon Coating) | ❌ COATING SPELL (Enchant Item Temporary) |

- **Korrekte Debuff-IDs:** `13218, 13222, 13223, 13224` (nur 4 Ranks in 1.12!)
- **Notizen:**
  - Wound Poison hat in WoW 1.12 nur **4 Ränge** (nicht 5!)
  - 13225 ist der Weapon-Coating-Spell für Rank 2, nicht ein Debuff
  - Weapon Coatings: 13219 (R1), 13225 (R2), 13226 (R3), 13227 (R4)
  - Stacks up to 5 (korrekt in Spec)

---

## Zusätzliche Verifizierungen — Spot Checks

### Faerie Fire (Druid)
- **Quelle:** https://classicdb.ch/?spell=770
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 770, 778, 9749, 9907
- **Notizen:** Alle 4 Ranks verifiziert. -Armor, prevents stealth/invis, 40s duration.

### Faerie Fire (Feral)
- **Quelle:** https://classicdb.ch/?spell=16857
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 16857, 17390, 17391, 17392
- **Notizen:** Feral-Version, kein Mana-Kosten. 4 Ranks.

### Faerie Fire (Bear) ⚠️
- **Quelle:** https://classicdb.ch/?spell=16855
- **Verifiziert:** ⚠️
- **IDs korrekt:** Fragwürdig
- **IDs in Spec:** 16855, 17387, 17388, 17389
- **Notizen:** 16855 wird als "**zzOLDFaerie Fire (Bear)**" gelistet — deprecated Spell! In WoW 1.12 gibt es kein separates "Faerie Fire (Bear)". Es gibt nur "Faerie Fire" (Caster) und "Faerie Fire (Feral)" (Cat/Bear). Die Bear-IDs existieren zwar in der DB, aber als deprecated. **Falls das Addon bereits mit diesen IDs funktioniert, könnten sie trotzdem in 1.12 aktiv sein** (manche zzOLD-Spells wurden dennoch intern verwendet). Empfehlung: Beibehalten als Fallback, aber testen.

### Sunder Armor (Warrior)
- **Quelle:** https://classicdb.ch/?spell=7386
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 7386, 7405, 8380, 11596, 11597
- **Notizen:** 5 Ranks, stacks 5x, -Armor pro Stack. Korrekt.

### Demoralizing Shout (Warrior)
- **Quelle:** https://classicdb.ch/?spell=1160
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 1160, 6190, 11554, 11555, 11556
- **Notizen:** 5 Ranks, -AP, 30s duration. Korrekt.

### Mortal Strike (Warrior)
- **Quelle:** https://classicdb.ch/?spell=12294
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 12294, 21551, 21552, 21553
- **Notizen:** 4 Ranks, -50% Healing, 10s duration. Korrekt.

### Polymorph (Mage)
- **Quelle:** https://classicdb.ch/?spell=118
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 118, 12824, 12825, 12826
- **Notizen:** 4 Ranks (20/30/40/50s). Korrekt.

### Polymorph: Pig
- **Quelle:** https://classicdb.ch/?spell=28272
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Notizen:** 50s, existiert in Classic (Tome of Polymorph: Pig).

### Polymorph: Turtle
- **Quelle:** https://classicdb.ch/?spell=28271
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Notizen:** 50s, existiert in Classic (Tome of Polymorph: Turtle).

### Polymorph: Rodent ❌
- **Quelle:** https://classicdb.ch/?spell=57560
- **Verifiziert:** ❌
- **IDs korrekt:** Nein
- **Notizen:** Spell 57560 **existiert NICHT** in der Classic DB. "Polymorph: Rodent" (57560) ist ein WotLK-Spell. **Muss entfernt werden aus der 1.12 Spec.**

### Sap (Rogue)
- **Quelle:** https://classicdb.ch/?spell=6770
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 6770, 2070, 11297
- **Notizen:** 3 Ranks (25/35/45s). Korrekt.

### Hunter's Mark
- **Quelle:** https://classicdb.ch/?spell=1130
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 1130, 14323, 14324, 14325
- **Notizen:** 4 Ranks, +RAP, 120s. Korrekt.

### Scatter Shot (Hunter)
- **Quelle:** https://classicdb.ch/?spell=19503
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Notizen:** Disorient 4s. Korrekt.

### Curse of Shadow (Warlock)
- **Quelle:** https://classicdb.ch/?spell=17862
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 17862, 17937
- **Notizen:** 2 Ranks, -Shadow/Arcane Resist + % Shadow/Arcane dmg increase. Korrekt.

### Judgement of the Crusader (Paladin)
- **Quelle:** https://classicdb.ch/?spell=21183
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **IDs:** 21183, 20188, 20300, 20301, 20302, 20303
- **Notizen:** 6 Ranks, +Holy dmg taken. Korrekt.

### Ignite (Mage)
- **Quelle:** https://classicdb.ch/?spell=12654
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Notizen:** Fire DoT, 4s duration. Korrekt.

### Armor Shatter (Annihilator)
- **Quelle:** https://classicdb.ch/?spell=16928
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Notizen:** -200 Armor, stacks 3x, 45s. Korrekt.

### Spell Vulnerability (Nightfall)
- **Quelle:** https://classicdb.ch/?spell=23605
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Notizen:** +15% Spell Dmg, 5s duration. Spec sagt 7s — **DB sagt 5s**. Prüfen ob TurtleWoW abweicht.

### Gift of Arthas
- **Quelle:** https://classicdb.ch/?spell=11374
- **Verifiziert:** ✅ (ID korrekt)
- **IDs korrekt:** Ja
- **Notizen:** +8 **Physical** damage taken, 180s, Disease. **Spec sagt "+8 Shadow Dmg" — das ist FALSCH.** Es ist Physical damage, nicht Shadow.

### Thunderfury
- **Quelle:** https://classicdb.ch/?spell=21992
- **Verifiziert:** ✅
- **IDs korrekt:** Ja
- **Notizen:** -25 Nature Resist + -20% Attack Speed, 12s. Spec sagt nur "-Nature Resist" — die Attack Speed Reduction fehlt.

---

## Korrigierte Referenz-Tabelle für Addon

### Debuffs die NUR 1 Debuff-ID haben (obwohl mehrere Talent-Ränge existieren)

| Debuff | Debuff-ID | Talent/Cast-IDs | Max Stacks |
|--------|-----------|------------------|------------|
| Winter's Chill | **12579** | 11180, 28592-28595 | 5 |
| Fire Vulnerability | **22959** | 11095, 12872, 12873 | 5 |
| Shadow Weaving ("Shadow Vulnerability") | **15258** | 15257, 15331-15334 | 5 |

### Debuffs mit mehreren Debuff-IDs (1 pro Talent-Rank)

| Debuff | Debuff-IDs | Talent-IDs |
|--------|------------|------------|
| Shadow Vulnerability (ISB) | **17794**, **17797**, **17798**, **17799**, **17800** | 17793, 17796, 17801, 17802, 17803 |

### Freezing Trap — Cast vs Effect

| Zweck | Spell IDs |
|-------|-----------|
| Debuff auf Target | **3355**, **14308**, **14309** |
| Hunter Cast (Trap platzieren) | 1499, 14310, 14311 |

### Wound Poison — Korrigiert (nur 4 Ranks in 1.12)

| Rank | Debuff-ID | -Healing |
|------|-----------|----------|
| 1 | **13218** | -55 |
| 2 | **13222** | -75 |
| 3 | **13223** | -105 |
| 4 | **13224** | -135 |

### Expose Armor — Korrigiert

| Stacks | Korrektur |
|--------|-----------|
| Spec sagt 5 | **Korrekt: 1** (Armor-Reduktion skaliert mit CP, kein Stacking) |

---

## Empfehlungen für die Implementierung

### 1. UNIT_CASTEVENT vs Debuff-Tracking

**Für Spells die direkt gecastet werden** (Sunder Armor, Faerie Fire, Curses, etc.):
→ Nutze Cast-Spell-IDs mit UNIT_CASTEVENT

**Für Proc-basierte Debuffs** (ISB Shadow Vulnerability, Winter's Chill, Fire Vulnerability, Shadow Weaving):
→ Nutze Debuff-IDs und scanne die Target-Debuffs (z.B. via COMBAT_LOG_EVENT oder UnitDebuff)
→ UNIT_CASTEVENT funktioniert NICHT, weil der Spieler nichts "castet" — die Debuffs werden automatisch durch Procs angewendet

**Für Freezing Trap:**
→ UNIT_CASTEVENT mit Cast-IDs (1499, 14310, 14311) für das Platzieren
→ Aber der Debuff-Effekt (3355, 14308, 14309) wird erst ausgelöst wenn ein Mob reinläuft — kein Cast-Event

### 2. Naming Collision: "Shadow Vulnerability"

Zwei komplett verschiedene Debuffs heißen "Shadow Vulnerability":
- **ISB:** 17794, 17797, 17798, 17799, 17800 (Warlock, +4-20% Shadow Dmg, 12s, 4 charges)
- **Shadow Weaving:** 15258 (Priest, +3% Shadow Dmg per stack, 15s, 5 stacks)

→ Unterscheidung nur über Spell ID möglich, nicht über Name!

### 3. Entfernen

- **Polymorph: Rodent (57560)** — existiert nicht in 1.12
- **Wound Poison ID 13225** — ist Weapon Coating, kein Debuff

### 4. Korrektur Expose Armor Stacks

- Von `stacks = 5` auf `stacks = 1` ändern

### 5. Gift of Arthas Beschreibung

- Von "+8 Shadow Dmg" auf "+8 Physical Dmg taken" korrigieren

---

*Verifiziert am 7. Februar 2026 gegen classicdb.ch (Vanilla 1.12 WoW Database)*
