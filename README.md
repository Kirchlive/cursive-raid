<p align="center">
  <img src="https://github.com/user-attachments/assets/8ef4428f-9915-4149-b663-65ce0aa54115" alt="Cursive Raid v4.0" width="1768">
</p>

<h1 align="center">Cursive Raid</h1>

<p align="center">
  <b>The raid debuff tracker that Vanilla WoW never had.</b><br>
  <i>Real-time debuff tracking, live armor monitoring, and full raid visibility — powered by SuperWoW.</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/WoW-1.12%20Vanilla-blue?style=flat-square" alt="WoW 1.12">
  <img src="https://img.shields.io/badge/TurtleWoW-Compatible-green?style=flat-square" alt="TurtleWoW">
  <img src="https://img.shields.io/badge/SuperWoW-Required-orange?style=flat-square" alt="SuperWoW">
  <img src="https://img.shields.io/badge/Version-4.0.5-brightgreen?style=flat-square" alt="v4.0.5">
  <img src="https://img.shields.io/badge/Lua-5.0-purple?style=flat-square" alt="Lua 5.0">
</p>

---

## What is Cursive Raid?

In Vanilla WoW, you're blind. You can see your own debuffs, maybe your target's — but the full picture? Which mobs have Sunder Armor? Who's missing Curse of Elements? How much armor has that boss actually lost? Nobody knows. You guess. You hope. You ask in voice chat.

**Cursive Raid changes that.**

It tracks every debuff on every hostile unit in combat. Not just yours — everyone's. Duration timers, stack counts, who applied what, what's missing. All of it, all at once, on every mob. Things that were literally impossible in 1.12 before [SuperWoW](https://github.com/balakethelock/SuperWoW) opened the door.

> Built for [TurtleWoW](https://turtle-wow.org/) and compatible vanilla 1.12 servers.
> Requires [SuperWoW](https://github.com/balakethelock/SuperWoW).

---

## Features

### 🎯 Debuff Tracking
- **GUID-based scanning** — Tracks all hostile units simultaneously, not just your target
- **Shared Debuff Tracking** — See raid-wide debuffs from every class: Sunder Armor, Faerie Fire, Curse of Elements, Shadow Weaving, Winter's Chill, and 40+ more
- **Duration timers** — Accurate countdown on every debuff, color-coded (white/yellow/classcolor/none)
- **Stack tracking** — Sunder stacks, Shadow Vulnerability stacks, Expose Armor combo points
- **Decimal precision** — Optional sub-second display in the last 3 seconds (white or red)

### 🛡️ Target Armor (v4.0)
- **Live armor monitoring** — Reads actual armor values via `UnitResistance(GUID)` without targeting
- **Reduction tracking** — See how much armor has been stripped by Sunder/EA/Faerie Fire in real time
- **Color-coded display** — Green → Yellow → Red as armor drops
- **Shield icon** — Configurable position (left/center/right) with armor value pairs (Live + Total, Live + Reduced, etc.)

### ⚔️ Expose Armor Detection
The feature that made people say *"wait, that's possible in Vanilla?"*

Traditional addons need the rogue to be your current target. Cursive Raid uses SuperWoW's `UnitResistance(GUID, 0)` to read armor by GUID — **no targeting required**. It detects the armor diff after cast and computes the exact combo point count.

### 🔧 Debuff Order System
- **Configurable priority** — Drag debuffs into the order you want: Front → Mid → Rear → Last → Swap Side
- **Per-category positioning** — Own Class, Own Raid, Other Class, Other Raid — each with independent placement
- **Missing debuff icons** — Grey desaturated icons show which expected debuffs aren't active yet
- **Debuff borders** — Color-coded frames: green for your own, red for raid-critical, classcolor, or off

### 📋 Profile System (v4.0)
- **Save & Load** — Snapshot your entire configuration and switch between setups instantly
- **7 default profiles** — Default, Pro Full, Raid Debuff Tracker, Raid Live Armor View, Spy Enemy Player, Targeted Only Own Debuffs, Track All Near Friendly Player
- **Export & Import** — Share profiles as text strings. Paste and go.
- **Cross-character** — Profiles are global, not per-character
- **Live refresh** — No `/reload` needed. Settings apply instantly.
- **Minimap quickswitch** — Right-click the minimap icon to switch profiles on the fly

### 🖥️ Options UI
Six-tab configuration panel — everything is configurable, nothing needs manual editing:

| Tab | What it controls |
|-----|-----------------|
| **General** | Enable/disable, move UI, test overlay, bar inversion, debuff borders, debuff order |
| **Raid** | Shared debuff toggles, missing debuff display, raid debuff order grid |
| **Class** | Per-class debuff selection — choose exactly which spells to track for each class |
| **Display** | Scale, opacity, font sizes, icon sizes, bar dimensions, max targets, columns |
| **Filter** | Target filtering: combat, hostile, attackable, player/NPC, range, raid icons |
| **Profiles** | Save/load/delete profiles, export/import, default profile presets |

### 🧪 Test Overlay
Preview your UI without being in a raid. Generates 8 fake targets with realistic debuffs based on your class, complete with timers, stacks, health bars, and raid icons. Toggle with `/cursive test` or the checkbox in General settings.

### 🔄 Multi-Curse / Multi-DoT
Built-in macro system for Warlocks and other multi-DoT classes:
- `/cursive multicurse` — Auto-pick the best target and cast
- Priority modes: `HIGHEST_HP`, `LOWEST_HP`, `RAID_MARK`, `RAID_MARK_SQUARE`
- Never double-curse a target again

---

## Installation

1. Install **[SuperWoW](https://github.com/balakethelock/SuperWoW)** (required)
2. Download the [latest release](../../releases)
3. Extract the `Cursive-Raid` folder into your `Interface/AddOns/` directory
4. Restart the WoW client

> **Upgrading from v4.0?** The addon folder has been renamed from `Cursive` to `Cursive-Raid`. Copy your SavedVariables files:
> - `WTF/Account/<name>/SavedVariables/Cursive.lua` → `Cursive-Raid.lua`
> - `WTF/Account/<name>/<realm>/<char>/SavedVariables/Cursive.lua` → `Cursive-Raid.lua`
>
> Then remove or disable the old `Cursive` folder to avoid conflicts.

```
Interface/AddOns/Cursive-Raid/
├── Cursive-Raid.toc
├── profiles.lua          # Profile system
├── defaultProfiles.lua   # 7 built-in presets
├── profilesUI.lua        # Profiles tab UI
├── curses.lua            # Debuff detection engine
├── ui.lua                # Frame rendering
├── CursiveOptionsUI.lua  # 6-tab options panel
├── CursiveTestOverlay.lua
├── settings.lua
├── spells/               # Per-class spell definitions
│   ├── shared_debuffs.lua
│   ├── warlock.lua
│   ├── warrior.lua
│   └── ...
└── Libs/                 # Ace2 framework
```

---

## Commands

| Command | Description |
|---------|-------------|
| `/cursive` | Show help |
| `/cursive options` | Open the options UI |
| `/cursive test` | Toggle test overlay |
| `/cursive profile list` | List saved profiles |
| `/cursive profile save <name>` | Save current config as profile |
| `/cursive profile load <name>` | Load a saved profile |
| `/cursive profile delete <name>` | Delete a profile |
| `/cursive curse <spell>\|<guid>\|<options>` | Cast if debuff not on target |
| `/cursive multicurse <spell>\|<priority>\|<options>` | Auto-target and cast |
| `/cursive target <spell>\|<priority>\|<options>` | Target by priority |

---

## Tracked Debuffs

Cursive Raid tracks **40+ shared debuffs** across all classes:

| Class | Debuffs |
|-------|---------|
| **Warrior** | Sunder Armor, Demoralizing Shout, Thunder Clap, Mortal Strike, Intimidating Shout |
| **Warlock** | Curse of Recklessness, Curse of Elements, Curse of Shadow, Curse of Tongues, Curse of Weakness, Shadow Vulnerability, Banish, Enslave Demon, Fear, Howl of Terror, Seduction |
| **Druid** | Faerie Fire, Demoralizing Roar, Hibernate |
| **Mage** | Polymorph, Fire Vulnerability, Winter's Chill, Ignite |
| **Rogue** | Expose Armor, Wound Poison, Sap |
| **Hunter** | Hunter's Mark, Freezing Trap, Scatter Shot, Wyvern Sting |
| **Paladin** | Judgement of Light, Judgement of Wisdom, Judgement of the Crusader, Hammer of Justice |
| **Priest** | Shadow Weaving, Shackle Undead, Mind Control, Psychic Scream, Burning Zeal (T3.5) |
| **Weapon Procs** | Thunderfury, Nightfall (Spell Vulnerability), Annihilator (Armor Shatter), Puncture Armor, Gift of Arthas, Potent Venom |
| **Scythe of Elune** | Elune's Radiance (Holy), Elune's Twilight (Shadow), Elune's Rage (Fire), Elune's Wrath (Arcane), Elune's Grace (Nature), Elune's Ire (Frost) |

---

## How It Works

### The SuperWoW Advantage

Vanilla WoW's API is deliberately limited. You can only inspect your current target's debuffs. You can't read armor values by GUID. You can't detect casts from other players on arbitrary targets.

[SuperWoW](https://github.com/balakethelock/SuperWoW) changes the rules:

- `UnitDebuff(GUID, i)` — Read debuffs on any unit by GUID
- `UnitResistance(GUID, 0)` — Read armor values without targeting
- `UNIT_CASTEVENT` — Detect spell casts from all raid members with target info
- `SpellInfo(spellID)` — Look up spell data by ID

Cursive Raid builds on all of these. The result is a level of raid awareness that wasn't possible before — and still isn't without SuperWoW.

### Expose Armor Detection (Deep Dive)

1. `UNIT_CASTEVENT` fires when a Rogue begins casting Expose Armor
2. Cursive captures the target's current armor via `UnitResistance(GUID, 0)` as `baseArmor`
3. An OnUpdate poller monitors the armor value for 2 seconds
4. The armor difference maps directly to combo points via talent multiplier detection
5. The exact stack count is displayed — no guessing, no targeting required

> See [docs/DEBUFF-TRACKING.md](docs/DEBUFF-TRACKING.md) for the full technical breakdown.

### Profile System Architecture

Profiles are stored independently from AceDB in a separate `SavedVariables: CursiveProfiles` table. This allows:
- Cross-character sharing without AceDB's per-realm/per-class restrictions
- Clean export/import via serialization (no LZW compression — plain readable format)
- Safe sandbox import using `loadstring()` + `setfenv()` (pfUI-proven pattern)
- Live application via `UpdateFramesFromConfig()` — no reload required

---

## Commands & Macros

### Curse (Single Target)

Cast a spell on your target (or a specific GUID) if they don't already have it:

```
/cursive curse Corruption|target
/cursive curse Curse of Recklessness|target|refreshtime=1
```

### Multicurse (Smart Target Selection)

Automatically pick the best target and cast:

```
/cursive multicurse Corruption|HIGHEST_HP
/cursive multicurse Curse of Recklessness|RAID_MARK|warnings,resistsound,expiringsound
```

### Target (Target Without Casting)

```
/cursive target Icicles|HIGHEST_HP
```

### Priority Options

| Priority | Description |
|----------|-------------|
| `HIGHEST_HP` | Target highest HP enemy without the debuff |
| `LOWEST_HP` | Target lowest HP enemy without the debuff |
| `RAID_MARK` | Target by raid mark priority (Skull > Cross > Square > ... > Star > No mark) |
| `RAID_MARK_SQUARE` | Like RAID_MARK but ignores Skull and Cross |
| `INVERSE_RAID_MARK` | Reverse of RAID_MARK |
| `HIGHEST_HP_RAID_MARK` | Highest HP first, raid marks break ties |
| `HIGHEST_HP_RAID_MARK_SQUARE` | Like above but with RAID_MARK_SQUARE priority |
| `HIGHEST_HP_INVERSE_RAID_MARK` | Like above but with INVERSE_RAID_MARK priority |

### Command Options

Append options after the priority, comma-separated:

| Option | Description |
|--------|-------------|
| `warnings` | Display text warnings when a curse fails |
| `resistsound` | Play a sound when resisted |
| `expiringsound` | Play a sound when about to expire |
| `allowooc` | Allow out-of-combat targets (careful in raids!) |
| `priotarget` | Always prioritize current target for multicurse |
| `ignoretarget` | Ignore current target for multicurse |
| `playeronly` | Only target players, ignore NPCs |
| `minhp=<number>` | Minimum HP threshold |
| `refreshtime=<number>` | Allow refresh when remaining time is below this (seconds) |
| `name=<str>` | Filter targets by name (partial match) |
| `ignorespellid=<number>` | Skip targets with this spell ID |
| `ignorespelltexture=<str>` | Skip targets with this spell texture |
| `cooldown` | Check spell cooldown before casting — returns false if on CD (enables clean macro fallthrough) |
| `harvestrefresh=<number>` | Time threshold for refreshing DoTs when Dark Harvest is off cooldown |

### Macro Examples

**Simple chain** (game decides order):
```
/cursive curse Curse of Recklessness|target|refreshtime=1
/cursive curse Corruption|target|refreshtime=3
/cursive curse Siphon Life|target|refreshtime=1
```

**Controlled priority chain** (Lua, guaranteed order):
```
/script if not Cursive:Curse("Curse of Recklessness", "target", {refreshtime=1}) then if not Cursive:Curse("Corruption", "target", {refreshtime=3}) then Cursive:Curse("Siphon Life", "target", {refreshtime=1}) end end
```

**Multicurse with full options:**
```
/script Cursive:Multicurse("Curse of Recklessness", "HIGHEST_HP", {warnings=1,resistsound=1,expiringsound=1,refreshtime=2})
```

**Raid mark filtering with ignore:**
```
/cursive multicurse Curse of Recklessness|RAID_MARK|name=Touched Warrior,ignorespelltexture=Spell_Shadow_UnholyStrength,resistsound,expiringsound
```

**Affliction Warlock with cooldown-aware Dark Harvest:**
```
/script if buffed("Shadow Trance") then cast("Shadow Bolt") elseif Cursive:Curse("Curse of Shadow","target",{refreshtime=2}) then elseif Cursive:Curse("Corruption","target",{refreshtime=2}) then elseif Cursive:Curse("Curse of Agony","target",{refreshtime=2}) then elseif Cursive:Curse("Dark Harvest","target",{cooldown=true}) then else cast("Drain Soul") end
```
The `cooldown` option checks the spell's actual cooldown (filtering out GCD). If the spell is on CD, the command returns `false` immediately — enabling clean fallthrough to the next action in the macro chain.

### API for Other Addons

```lua
-- Check if a debuff is active
Cursive.curses:HasCurse("corruption", targetGuid, minRemaining)

-- Get raw curse data
local data = Cursive.curses:GetCurseData("Corruption", guid)
-- Returns: { rank, duration, start, spellID, targetGuid, currentPlayer }

-- Get time remaining
local remaining = Cursive.curses:TimeRemaining(data)

-- Get smart target GUID
local guid = Cursive:GetTarget("Corruption", "HIGHEST_HP", {})
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Debuff Tracking](docs/DEBUFF-TRACKING.md) | SharedDebuffs internals, procExpected system, armor-diff EA detection |
| [SuperWoW API](docs/SUPERWOW-API.md) | All SuperWoW APIs used and how |
| [Test Overlay](docs/TEST-OVERLAY.md) | Fake GUID system, API wrappers, class-specific debuff injection |
| [Spell ID Reference](docs/FINAL-SPELL-IDS.md) | All verified spell IDs for TurtleWoW |
| [Spell Verification](docs/spell-id-verification-turtlewow.md) | ID verification against database.turtlecraft.gg |
| [Vanilla Lua Reference](docs/AGENTS_WoW_Vanilla_1.12_EN.md) | Complete Lua 5.0 addon development guide |
| [v3.2 Implementation](docs/IMPLEMENTATION.md) | Shared Debuffs architecture & decisions |

---

## Version History

### v4.0.3 — March 2026 *(current)*

CC/Reflect Transparency, Mind Control fix, new consumable debuff.

**Fixes:**
- **Mind-Controlled players** — MC'd players no longer appear in mob list despite "Not Player" filter
- **armorCache nil crash** — Fixed `CleanupArmorCache` crash before initialization

**New Features:**
- **CC / Reflect Transparency** — CC'd (Banish, Poly, etc.) and Spell Reflect targets shown at 35% opacity. Checkbox in General Settings (default: on).
- **Spell Reflect detection** — Scans for known reflect buff IDs (Reflection, Magic Reflection, Fire/Arcane Reflect, Shadow/Frost Reflect, TurtleWoW Reflect Magic)
- **Potent Venom** — Vial of Potent Venoms (45416) added as trackable consumable debuff

### v4.0.2 — March 2026

Minor fixes and Turtle Launcher integration.

- Default profiles corrected to match live SavedVariables
- TOC adjustments for Turtle Launcher update detection
- Spy Enemy Player text size fix, README emoji update

### v4.0.1 — March 2026

Bugfixes, new features, and addon folder rename.

**Fixes:**
- **Shadow Weaving tracking** — Fixed consecutive Mind Flay casts cancelling each other's scan events (unique scan IDs per cast)
- **Shadow Weaving on non-targeted mobs** — Now correctly tracks and updates stacks on all mobs, not just your current target
- **Multicurse broken** — Fixed `getEffectiveRefreshTime` forward declaration error (Lua 5.0 scope issue)
- **isDarkHarvestReady nil error** — Moved `isSpellOnCooldown` and `isDarkHarvestReady` before `getEffectiveRefreshTime` to satisfy Lua 5.0's top-down function resolution
- **Consecutive proc scan cancellation** — All CAST and CHANNEL trigger scan events now use unique IDs via `GetTime()` to prevent overwriting

**New Features:**
- **Debuff Icon Spacing** — New slider (0–10, default 1) to control gap between debuff icons
- **Health Bar Spacing** — Renamed from "Spacing" for clarity
- **Target Armor Position** — New slider (-30 to +30) for horizontal offset of the armor display

**Changes:**
- **Addon folder renamed** — `Cursive` → `Cursive-Raid` (TOC file now matches folder name)
- **7 new default profiles** (replaces 12 class-specific profiles):
  - Default
  - Pro Full
  - Raid Debuff Tracker
  - Raid Live Armor View
  - Spy Enemy Player
  - Targeted Only Own Debuffs
  - Track All Near Friendly Player

### v4.0 — March 2026

The biggest update since the addon's creation. Complete UI overhaul, profile system, and dozens of polish items.

**New Features:**
- 📋 Full profile system — save, load, delete, rename, export, import
- 📋 Default profiles for every class and playstyle
- 📋 Minimap right-click profile quickswitch
- 🛡️ Target Armor display — live armor values with color coding and shield icon
- 🎨 Debuff Order rewrite — Swap Side, configurable per-category positioning
- 🧪 Test Overlay fixes — full API wrapper coverage (UnitIsPlayer, UnitResistance)
- ⚙️ Decimal Duration dropdown (None/White/Red)
- ⚙️ Duration Timer + Stack Counter "None" option (hide completely)

**UI Polish:**
- 6-tab options panel (new Profiles tab)
- Debuff border system with per-category color coding
- Slider limits refined (Max Debuffs 18, Icon Size 30)
- Armor Build dropdown (Live + Total, Live + Reduced, etc.)
- Pixel-perfect spacing across all panels
- No more `/reload` — everything applies live

### v3.2.1-beta — February 2026

- Expose Armor CP Detection (targetless, via armor-diff)
- Shadow Vulnerability complete fix
- Raid Debuff Order UI with icon grid
- Test Overlay system
- Show Missing Debuffs
- Winter's Chill fix
- Thunderfury/Nightfall/Annihilator timer fix

### v3.2.0 — February 2026

- Shared Debuff Tracking system
- Debuff Border Colors
- Complete Options UI (5 tabs)
- Fork of Kirchlive/Cursive v3.1

### v3.0–v3.1

- Original updates by [Kirchlive](https://github.com/Kirchlive): Dark Harvest, trinket fixes, UI improvements

### Pre-v3.0

- Original [Cursive](https://github.com/pepopo978/Cursive) by pepopo978: ShaguScan-based curse tracking

---

## Known Limitations

- **SuperWoW is required** — There is no fallback mode. Without SuperWoW, the addon will not load.
- **WoW 1.12 only** — No TBC, Wrath, or retail support.
- **Debuff slot cap** — Vanilla WoW has a 16-debuff cap per target (64 on TurtleWoW with SuperWoW). Cursive tracks what's visible.
- **Proc debuff timing** — Weapon procs (Thunderfury, Nightfall) rely on `UNIT_CASTEVENT` timing. Slight delays are possible.
- **External addon conflicts** — Some addons (e.g., SuperCleveRoidMacros) may log errors when Test Overlay is active. This is harmless and caused by those addons trying to resolve fake GUIDs.

---

## FAQ

**Does this work on TurtleWoW?**
Yes. Built for TurtleWoW, tested on TurtleWoW. SuperWoW is supported and widely used on the server.

**Do I need SuperWoW?**
Yes. SuperWoW provides the GUID-based APIs that make shared debuff tracking possible. Without it, Cursive Raid cannot function.

**Will this get me banned?**
SuperWoW is de facto supported on TurtleWoW — core developers maintain addons that depend on it. Cursive Raid uses only SuperWoW's Lua API extensions, nothing external.

**Can I use this in 5-man dungeons?**
Absolutely. It works in any combat scenario — raids, dungeons, world PvP, solo farming.

**How do I share my profile with guildmates?**
Open the Profiles tab → select your profile → click Export → copy the text string → share it. They paste it into their Import field and click Import.

**The addon folder changed from "Cursive" to "Cursive-Raid"?**
Yes, as of v4.0.1 the folder name matches the addon name. You'll need to copy your SavedVariables files (see Installation above). The internal Lua global stays `Cursive` for AceDB compatibility.

---

## Credits

| Who | What |
|-----|------|
| **[pepopo978](https://github.com/pepopo978/Cursive)** | Original Cursive addon — ShaguScan + curse tracking foundation |
| **[Kirchlive](https://github.com/Kirchlive)** | v3.0–v3.1 (Dark Harvest, trinket fixes, UI work) and v3.2–v4.0 architecture & design |
| **Teto** | v3.2–v4.0 implementation — shared debuffs, EA detection, profile system, options UI, test overlay |
| **[SuperWoW](https://github.com/balakethelock/SuperWoW)** | The mod that made all of this possible |
| **[pfUI](https://github.com/shagu/pfUI)** | Inspiration for dropdown patterns, profile serialization, and UI design philosophy |

---

## Dev Notes — From the Trenches

> *"We just implemented something for Vanilla WoW that was previously declared impossible."*
> — On targetless Expose Armor detection via `UnitResistance(GUID)`

> *"AceDB-2.0 silently deletes your config values on logout if they match the defaults. The fix? Set your defaults to a value that can never be real."*
> — The sentinel trick that saved debuff order persistence

> *"The apostrophe in Winter's Chill broke the entire debuff categorization. One character."*
> — `"winter'schill"` ≠ `"winterschill"`

> *"Fake GUIDs in WoW are like fake IDs at a bar — every bouncer (addon) will try to check them."*
> — On why Test Overlay needs 10+ API wrappers

> *"Lua 5.0 has a 32 upvalue limit per function. We hit it building the Raid Order UI."*
> — Solved with `do...end` scope blocks. Classic vanilla pitfall.

> *"No ReloadUI. Everything applies live. That's the standard now."*
> — On the profile system's instant-apply architecture

---

## Contributing

Found a bug? Have a feature idea? Open an [issue](../../issues).

Want to add debuff definitions for a new spell? Check `spells/shared_debuffs.lua` — the format is straightforward.

---

## License

Same license as the original Cursive project. See upstream repositories for details.

---

<p align="center">
  <i>Built with obsession, tested in raids, polished pixel by pixel.</i><br>
  <b>Kirchlive & Teto — 2026</b> 💠<br><br>
  <i>Thanks to our mates for the raid testing, feedback, and patience. This one's for you.</i> 🐢
</p>
