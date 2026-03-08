# Cursive v3.2.0 — Implementierungsplan

> **Ziel:** Erweiterung des Shared Debuffs Systems auf alle raid-relevanten und klassenspezifischen Debuffs
> **Basis:** v3.1.0 (aktueller Stand auf GitHub)
> **Plattform:** Turtle WoW (Vanilla WoW 1.12, Interface 11200, Debuff-Limit: 64)
> **Sprache:** Lua 5.0 (NICHT 5.1!) — siehe `AGENTS_WoW_Vanilla_1.12_EN.md`
> **Abhängigkeit:** SuperWoW (UNIT_CASTEVENT, UnitDebuff mit Spell-ID)

---

## Getroffene Entscheidungen

### Menüstruktur
- **Zwei Ansichten:** Raid Debuffs (nach Funktion) + Class Debuffs (nach Klasse)
- **Shared Toggles:** Ein Toggle pro Debuff, sichtbar in beiden Ansichten
- **Quick-Toggles:** "Enable All" / "Disable All" pro Kategorie/Klasse
- **Format:** `Debuff Name (Quelle)` — Details im Hover-Tooltip

### Raid Shared Debuffs (13)
```
── Armor Reduction ──
  Sunder Armor (Warrior)
  Expose Armor (Rogue)
  Faerie Fire (Druid)
  Curse of Recklessness (Warlock)

── Spell Vulnerability ──
  Fire Vulnerability (Mage)
  Winter's Chill (Mage)
  Shadow Vulnerability (Warlock)
  Shadow Weaving (Priest)
  Curse of the Elements (Warlock)
  Curse of Shadow (Warlock)

── Weapon Procs ──
  Armor Shatter (Annihilator)
  Spell Vulnerability (Nightfall)
  Thunderfury (Thunderfury)
```

### Debuff-Kategorien (Drei Typen)
1. **Personal** — Nur für den Caster relevant (Ignite, eigene DoTs)
2. **Raid Shared** — Andere Spieler profitieren direkt (Sunder, CoE, etc.)
3. **Informational** — Keine direkte Auswirkung, aber nützliche Info (CC: Sheep, Banish, etc.)

### Tracking-Methodik
- **Direkte Casts** → UNIT_CASTEVENT (bestehendes Pattern)
- **Proc-basierte Debuffs** → UNIT_CASTEVENT des auslösenden Spells + verzögerter UnitDebuff-Scan (Hybrid, bestehendes Pattern erweitert)
- **Kein SendAddonMessage in v3.2** — ggf. in späterer Version

### Expose Armor
- Technisch 1 Debuff, aber **Combo Points werden als Stacks angezeigt** (2 CP = 2 Stacks)

### Ausschlüsse
- Gift of Arthas: Nur Klassen-/Item-Liste (kaum Raid-Nutzung)
- Hunter's Mark: Nur Klassen-Liste (nur Ranged AP, geringer Raid-Nutzen)
- Ignite: Nur Klassen-Liste (Personal DoT)
- Polymorph: Rodent → **57561** (nicht 57560, TurtleWoW Custom)

---

## Phase 1 — Daten-Layer
**Datei:** `spells/shared_debuffs.lua`
**Risiko:** Gering (reines Daten-File)

### Aufgaben
- [ ] Bestehende Faerie Fire Einträge beibehalten
- [ ] Alle neuen Debuffs hinzufügen gemäß `FINAL-SPELL-IDS.md`
- [ ] Neues Feld `stacks` für Stack-basierte Debuffs (Sunder=5, Shadow Weaving=5, etc.)
- [ ] Neues Feld `category` für Typ-Zuordnung ("armor", "spellvuln", "weaponproc", "cc", "tank", "healing", "utility")
- [ ] Neues Feld `class` für Klassen-Zuordnung ("warrior", "rogue", "druid", etc.)
- [ ] Neues Feld `raidRelevant` (boolean) für Raid-Debuffs-Filter
- [ ] Expose Armor: `displayStacks = true` (CP als Stacks anzeigen)
- [ ] Proc-basierte Debuffs markieren: `isProc = true` + `triggerSpells = {ID1, ID2, ...}`

### Struktur pro Debuff
```lua
sunderarmor = {
    category = "armor",
    class = "warrior",
    raidRelevant = true,
    stacks = 5,
    spells = {
        [7386] = { name = L["sunder armor"], rank = 1, duration = 30 },
        [7405] = { name = L["sunder armor"], rank = 2, duration = 30 },
        [8380] = { name = L["sunder armor"], rank = 3, duration = 30 },
        [11596] = { name = L["sunder armor"], rank = 4, duration = 30 },
        [11597] = { name = L["sunder armor"], rank = 5, duration = 30 },
    },
},
```

### Proc-basierte Debuffs (Sonderstruktur)
```lua
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
```

---

## Phase 2 — Core-Logik
**Datei:** `curses.lua`
**Risiko:** Mittel (Kern-Änderung am Event Handler)

### Aufgaben
- [ ] `sharedDebuffs` Struktur dynamisch aus `getSharedDebuffs()` aufbauen (statt hardcoded)
- [ ] `sharedDebuffGuids` analog dynamisch initialisieren
- [ ] Event Handler generisch machen: Iteration über alle `debuffKeys` statt hardcoded Faerie Fire
- [ ] Spell Name Handling erweitern (Zeile 321-327): generisch für alle Shared Debuffs
- [ ] Stack-Tracking implementieren: `sharedDebuffGuids[key][targetGuid] = { time = GetTime(), stacks = n }`
- [ ] Proc-Tracking: Bei `isProc`-Debuffs nach UNIT_CASTEVENT des Triggers → verzögerter `UnitDebuff(targetGuid)` Scan
- [ ] Mutual Exclusion: Sunder Armor vs Expose Armor (zeige nur den aktiven)
- [ ] Cleanup: Abgelaufene Shared Debuffs aus `sharedDebuffGuids` entfernen

### Generischer Event Handler (Kern-Änderung)
```lua
-- NEU: Generisch statt hardcoded
Cursive:RegisterEvent("UNIT_CASTEVENT", function(casterGuid, targetGuid, evt, spellID, castDuration)
    if evt == "CAST" then
        local _, guid = UnitExists("player")
        if casterGuid ~= guid then
            -- Prüfe alle shared debuffs
            for debuffKey, debuffData in pairs(curses.sharedDebuffs) do
                if Cursive.db.profile.shareddebuffs[debuffKey] then
                    if debuffData.spells and debuffData.spells[spellID] then
                        curses.sharedDebuffGuids[debuffKey][targetGuid] = GetTime()
                    elseif debuffData.isProc and debuffData.triggerSpells then
                        -- Proc: Schedule UnitDebuff Scan
                        for _, triggerID in ipairs(debuffData.triggerSpells) do
                            if spellID == triggerID then
                                Cursive:ScheduleEvent(
                                    "scanProc" .. targetGuid .. debuffKey,
                                    curses.ScanForProcDebuff, 0.5,
                                    curses, debuffKey, targetGuid
                                )
                                break
                            end
                        end
                    end
                end
            end
            return
        end
        -- ... Rest des bestehenden eigenen Cast-Handlings
    end
end)
```

### Proc-Scan Funktion (Neu)
```lua
function curses:ScanForProcDebuff(debuffKey, targetGuid)
    local debuffData = curses.sharedDebuffs[debuffKey]
    if not debuffData then return end
    for i = 1, 64 do
        local _, _, _, spellID = UnitDebuff(targetGuid, i)
        if not spellID then break end
        if debuffData.spells[spellID] then
            curses.sharedDebuffGuids[debuffKey][targetGuid] = GetTime()
            return
        end
    end
end
```

---

## Phase 3 — Settings / Options Panel
**Datei:** `settings.lua`
**Risiko:** Mittel

### Aufgaben
- [ ] Bestehenden "Shared Debuffs" Menüpunkt erweitern
- [ ] Untermenü "Raid Debuffs" mit Kategorien: Armor Reduction, Spell Vulnerability, Weapon Procs
- [ ] Untermenü "By Class" mit allen 8 Klassen
- [ ] "Enable All" / "Disable All" pro Kategorie und Klasse
- [ ] Shared Toggles: Ein `db.profile.shareddebuffs[key]` pro Debuff, beide Ansichten zeigen denselben Key
- [ ] Tooltips: `tooltipTitle` + `tooltipText` mit Stacks, Duration, Effekt
- [ ] Defaults: Alle Raid Debuffs standardmäßig AN, CC standardmäßig AUS

### Menüstruktur
```
Shared Debuffs ►
├── Raid Debuffs ►
│   ├── ☑ Enable All Raid Debuffs
│   ├── ☐ Disable All
│   ├── ── Armor Reduction ──
│   │   ├── ✓ Sunder Armor (Warrior)
│   │   ├── ✓ Expose Armor (Rogue)
│   │   ├── ✓ Faerie Fire (Druid)
│   │   └── ✓ Curse of Recklessness (Warlock)
│   ├── ── Spell Vulnerability ──
│   │   ├── ✓ Fire Vulnerability (Mage)
│   │   ├── ✓ Winter's Chill (Mage)
│   │   ├── ✓ Shadow Vulnerability (Warlock)
│   │   ├── ✓ Shadow Weaving (Priest)
│   │   ├── ✓ Curse of the Elements (Warlock)
│   │   └── ✓ Curse of Shadow (Warlock)
│   └── ── Weapon Procs ──
│       ├── ✓ Armor Shatter (Annihilator)
│       ├── ✓ Spell Vulnerability (Nightfall)
│       └── ✓ Thunderfury (Thunderfury)
│
├── By Class ►
│   ├── Druid ►
│   │   ├── ☑ Enable All
│   │   ├── ✓ Faerie Fire
│   │   ├── ✓ Demoralizing Roar
│   │   └── ✓ Hibernate
│   ├── Hunter ►
│   │   ├── ✓ Hunter's Mark
│   │   ├── ✓ Freezing Trap
│   │   ├── ✓ Scatter Shot
│   │   └── ✓ Wyvern Sting
│   ├── Mage ►
│   │   ├── ✓ Polymorph
│   │   ├── ✓ Fire Vulnerability
│   │   ├── ✓ Winter's Chill
│   │   └── ✓ Ignite
│   ├── Paladin ►
│   │   ├── ✓ Judgement of Light
│   │   ├── ✓ Judgement of Wisdom
│   │   ├── ✓ Judgement of the Crusader
│   │   └── ✓ Hammer of Justice
│   ├── Priest ►
│   │   ├── ✓ Shadow Weaving
│   │   ├── ✓ Shackle Undead
│   │   ├── ✓ Mind Control
│   │   └── ✓ Psychic Scream
│   ├── Rogue ►
│   │   ├── ✓ Expose Armor
│   │   ├── ✓ Wound Poison
│   │   └── ✓ Sap
│   ├── Warlock ►
│   │   ├── ✓ Curse of Recklessness
│   │   ├── ✓ Curse of the Elements
│   │   ├── ✓ Curse of Shadow
│   │   ├── ✓ Curse of Tongues
│   │   ├── ✓ Curse of Weakness
│   │   ├── ✓ Shadow Vulnerability
│   │   ├── ✓ Banish
│   │   ├── ✓ Enslave Demon
│   │   ├── ✓ Fear
│   │   ├── ✓ Howl of Terror
│   │   └── ✓ Seduction
│   ├── Warrior ►
│   │   ├── ✓ Sunder Armor
│   │   ├── ✓ Demoralizing Shout
│   │   ├── ✓ Thunder Clap
│   │   ├── ✓ Mortal Strike
│   │   └── ✓ Intimidating Shout
│   └── Items/Weapons ►
│       ├── ✓ Armor Shatter (Annihilator)
│       ├── ✓ Spell Vulnerability (Nightfall)
│       ├── ✓ Thunderfury
│       └── ✓ Gift of Arthas
```

---

## Phase 4 — Lokalisierung
**Datei:** `Localization.lua`
**Risiko:** Gering

### Aufgaben
- [ ] Alle neuen Debuff-Namen in `enUS` hinzufügen
- [ ] Deutsche Übersetzungen (`deDE`) hinzufügen
- [ ] Kategorie-Header Strings ("Armor Reduction", "Spell Vulnerability", etc.)
- [ ] Tooltip-Strings für Hover-Beschreibungen
- [ ] "Enable All" / "Disable All" Strings

### Neue Locale-Einträge (enUS)
```lua
-- Debuff Names
L["sunder armor"] = "Sunder Armor"
L["expose armor"] = "Expose Armor"
L["curse of recklessness"] = "Curse of Recklessness"
L["curse of the elements"] = "Curse of the Elements"
L["curse of shadow"] = "Curse of Shadow"
L["curse of tongues"] = "Curse of Tongues"
L["curse of weakness"] = "Curse of Weakness"
L["fire vulnerability"] = "Fire Vulnerability"
L["winter's chill"] = "Winter's Chill"
L["shadow vulnerability"] = "Shadow Vulnerability"
L["shadow weaving"] = "Shadow Weaving"
L["spell vulnerability"] = "Spell Vulnerability"
L["ignite"] = "Ignite"
L["polymorph"] = "Polymorph"
L["hunter's mark"] = "Hunter's Mark"
L["freezing trap"] = "Freezing Trap"
L["scatter shot"] = "Scatter Shot"
L["wyvern sting"] = "Wyvern Sting"
L["demoralizing roar"] = "Demoralizing Roar"
L["demoralizing shout"] = "Demoralizing Shout"
L["thunder clap"] = "Thunder Clap"
L["mortal strike"] = "Mortal Strike"
L["wound poison"] = "Wound Poison"
L["hibernate"] = "Hibernate"
L["shackle undead"] = "Shackle Undead"
L["mind control"] = "Mind Control"
L["psychic scream"] = "Psychic Scream"
L["sap"] = "Sap"
L["banish"] = "Banish"
L["enslave demon"] = "Enslave Demon"
L["fear"] = "Fear"
L["howl of terror"] = "Howl of Terror"
L["seduction"] = "Seduction"
L["intimidating shout"] = "Intimidating Shout"
L["hammer of justice"] = "Hammer of Justice"
L["judgement of light"] = "Judgement of Light"
L["judgement of wisdom"] = "Judgement of Wisdom"
L["judgement of the crusader"] = "Judgement of the Crusader"
L["armor shatter"] = "Armor Shatter"
L["thunderfury"] = "Thunderfury"
L["gift of arthas"] = "Gift of Arthas"
-- Kategorie-Header
L["raid debuffs"] = "Raid Debuffs"
L["by class"] = "By Class"
L["armor reduction"] = "Armor Reduction"
L["spell vulnerability header"] = "Spell Vulnerability"
L["weapon procs"] = "Weapon Procs"
L["enable all"] = "Enable All"
L["disable all"] = "Disable All"
```

---

## Phase 5 — UI & Darstellung
**Datei:** `ui.lua`
**Risiko:** Klein-Mittel

### Aufgaben
- [ ] Shared Debuff Bars für neue Debuffs anzeigen
- [ ] Stack-Anzeige auf Bars (Zahl auf Icon oder im Text)
- [ ] Farbcodierung nach Kategorie (optional: Armor=orange, SpellVuln=lila, CC=blau, etc.)
- [ ] Ablauf-Timer für alle Shared Debuffs (Duration-Bar)
- [ ] Proc-Debuffs visuell kennzeichnen (optional: Sparkle/Glow)

---

## Phase 6 — Test Framework
**Datei:** `CursiveTestFramework.lua`
**Risiko:** Gering (Test-Only)

### Aufgaben
- [ ] `/cursivetest debuff <key> [stacks]` — Shared Debuff simulieren
- [ ] `/cursivetest debufall` — Alle Shared Debuffs auf Mock-Target
- [ ] `/cursivetest list` — Alle registrierten Debuff-Keys + Status
- [ ] `/cursivetest clear` — Alle simulierten Debuffs entfernen
- [ ] `/cursivetest stack <key>` — Stack-Verhalten testen (1→2→3→4→5)
- [ ] `/cursivetest raid` — Alle 13 Raid Debuffs auf einmal simulieren

---

## Phase 7 — Finalisierung
**Risiko:** Gering

### Aufgaben
- [ ] `Cursive.toc` → Version 3.2.0
- [ ] `README.md` aktualisieren
- [ ] Changelog schreiben
- [ ] Git: Feature-Branch `v3.2-shared-debuffs` erstellen
- [ ] Commit-Strategie: 1 Commit pro Phase

---

## Reihenfolge & Abhängigkeiten

```
Phase 1 (Daten) ──→ Phase 2 (Core) ──→ Phase 3 (Settings)
                                    ──→ Phase 5 (UI)
Phase 4 (Locale) ──→ Phase 3 (Settings)
Phase 6 (Tests) ── unabhängig, kann parallel
Phase 7 (Final) ── nach allem anderen
```

**Empfohlener Ablauf:**
1. Phase 4 (Locale) — schnell, keine Abhängigkeiten
2. Phase 1 (Daten) — Grundlage für alles
3. Phase 2 (Core) — Kern-Logik
4. Phase 3 (Settings) — Menü
5. Phase 5 (UI) — Darstellung
6. Phase 6 (Tests) — Validierung
7. Phase 7 (Final) — Abschluss

---

## Lua 5.0 Checkliste (vor JEDEM Code-Output!)

- [ ] `this` statt `self` in Handlers
- [ ] `table.getn(t)` statt `#t`
- [ ] `string.find()` mit Captures statt `string.match()`
- [ ] `string.gfind()` statt `string.gmatch()`
- [ ] `event`, `arg1`-`arg9` als Globals
- [ ] Kein `C_*`, kein `hooksecurefunc()`
- [ ] Alle Variablen explizit `local`
- [ ] `ipairs` nur für sequentielle Arrays, `pairs` für alles andere
- [ ] Kein `{...}` — benutze `arg` Tabelle
- [ ] `unpack(t)` statt `table.unpack(t)`

---

## Referenz-Dateien

| Datei | Inhalt |
|-------|--------|
| `FINAL-SPELL-IDS.md` | ✅ Verifizierte Spell-IDs (TurtleWoW) — HAUPTREFERENZ |
| `spell-id-verification.md` | Erstverifizierung (classicdb.ch) |
| `spell-id-verification-turtlewow.md` | TurtleWoW-Gegenprüfung |
| `v31-update-notes.md` | v3.1 Bug-Fixes (Referenz) |
| `v32-shared-debuffs.md` | Original-Spec (überholt durch FINAL) |
| `cursive-roadmap.md` | Feature-Roadmap |
| `AGENTS_WoW_Vanilla_1.12_EN.md` | Lua 5.0 / WoW 1.12 Referenz (PFLICHTLEKTÜRE) |

---

*Stand: 7. Februar 2026 — Alle Entscheidungen mit Rob abgestimmt*
