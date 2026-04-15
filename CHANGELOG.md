# Changelog

## v4.1.0 — 2026-04-15

Major performance update targeting BG/AV lag. All optimizations validated live via ClaudeBridge with zero new Lua errors.

### Performance — BG/AV Scaling Fix
- **GUID tracking cap (60)** — `UNIT_COMBAT` no longer floods the tracker with 80+ units in AV. Low-priority GUIDs (not target, not raid-marked, not cursed) are dropped when at cap. High-priority GUIDs (target, raid icons, units with active curses) always get through.
- **Range check cache (250ms TTL)** — `IsSpellInRange` results cached per GUID, shared across both `ShouldDisplayGuid` (10Hz main loop) and `BarUpdate` (20Hz per bar). Eliminates ~97% of redundant `IsSpellInRange` pcalls in AV.
- **LOS check throttled (250ms)** — `UnitXP("inSight")` raycast per bar reduced from 20Hz to 4Hz. OOR stripes still update fast enough for gameplay.
- **CC/Reflect cache (250ms TTL)** — `HasSpellReflect` (64-slot `UnitBuff` scan) and `HasActiveCC` results cached per GUID. Invalidated immediately on `UNIT_AURA` for current target, expires by TTL for others.
- **Aura snapshot (single-pass scan)** — `hasAnySpellId` now scans debuffs+buffs once per GUID per 150ms, then does O(1) lookups for each shared debuff. Replaces N separate 128-slot scans per GUID per tick.
- **EA Poller throttled (10Hz)** — Expose Armor armor-monitoring `OnUpdate` reduced from 60Hz (every frame) to 10Hz (100ms). Still catches armor changes within 2 server ticks (50ms each).
- **Aura-gone optimization** — `CHAT_MSG_SPELL_AURA_GONE_OTHER` handler now does direct key lookup per GUID instead of nested iteration over all curses on all GUIDs.

### Estimated Impact (AV with 80 units)
- WoW API calls: ~22,000/s → ~2,500/s (**-89%**)
- `IsSpellInRange` pcalls: ~3,040/s → ~160/s (**-95%**)
- `UnitBuff` scans (Reflect): ~10,240/s → ~64/s (**-99%**)
- `UnitXP` raycasts: ~320/s → ~64/s (**-80%**)
- Tracked GUIDs: unlimited → capped at 60

---

## v4.0.5 — 2026-04-14

Bugfixes for Scythe/weapon proc timers, checkbox defaults, and visual improvements.

### Bug Fixes
- **noTrigger proc timer reset** — Weapon procs without triggerSpells (Scythe of Elune, Thunderfury, Annihilator, Nightfall, Puncture Armor, Gift of Arthas, Potent Venom, Burning Zeal, Ignite) had their duration timer reset on every UNIT_AURA scan cycle, making the countdown appear frozen for ~4-5 seconds. Fix: `noTrigger` procs only refresh timer on first detection or re-application after expiry.
- **OOR/CC checkbox defaults** — `oorstripes` and `cctransparency` were not registered in AceDB defaults. Existing profiles had `nil` values, causing checkboxes to display unchecked even when the intended default was enabled. Fix: added AceDB defaults + nil-to-true profile patch in OnEnable + added missing `SetCheckbox` calls in `CursiveOpts.Initialize()`.

### Visual Improvements
- **Reflect text at full opacity** — Spell school text ("Reflect: Fire/Arcane") is now rendered in an independent overlay frame, so it stays fully visible even when the bar is transparent from CC/Reflect Transparency.
- **OOR stripe direction** — Diagonal stripes changed from `\` to `/` direction (new mirrored TGA texture `diagonal_stripes_rev.tga`).
- **Line-of-Sight detection** — OOR stripes now also show when the target is not in line of sight (via `UnitXP('inSight', ...)`, requires UnitXP SP3). Checkbox renamed to "Out-of-Range / Line-of-Sight Stripes".

---

## v4.0.4 — 2026-04-12

Scythe of Elune debuffs, Burning Zeal, Reflect text, OOR stripes, class range, performance optimization, TestOverlay fixes.

### New Debuffs
- **Scythe of Elune** — 6 legendary trinket debuffs tracked as raid weapon procs (10s each, `isProc=true`):
  - Elune's Radiance (Holy, 57666), Elune's Twilight (Shadow, 57665), Elune's Rage (Fire, 52376), Elune's Wrath (Arcane, 57663), Elune's Grace (Nature, 57664), Elune's Ire (Frost, 57662)
  - Full integration: `shared_debuffs.lua`, `Localization.lua` (enUS + zhCN), `settings.lua` (6 structures), `global.lua` (raidDebuffOrder)
- **Burning Zeal** — Priest T3.5 "Attire of Pestilence" set proc (52980, 18s Holy DoT + 2% Holy vuln). Category: spellvuln, default disabled.

### New Features
- **Reflect Spell-School Text** — Health bar overlay shows "Reflect: Fire/Arcane" etc. when target has a known spell reflect buff. `reflectBuffIds` now maps to school strings instead of boolean.
- **Out-of-Range Stripes** — Diagonal white stripe overlay (40% alpha) on health bars for targets outside spell range. Toggleable checkbox in General settings (default: on).
- **Class-Specific Range Check** — Replaced hardcoded Hex (45yd, Warlock-only) with per-class reference spells covering different talent trees (Grim Reach, Destructive Reach, Arctic Reach, etc.). `IsSpellInRange()` auto-applies talent bonuses. Target is "in range" if ANY class spell reaches.

### Performance Optimization (4 phases)
- **Phase 1 — Quick Wins:** Extended `CleanupSharedDebuffs()` to clean orphaned `armorCache`, `lastProcStacks`, `playerOwnedCasts`. Cached CHAT_MSG pattern arrays as module-level locals. Test overlay `RemoveGuid()` call in disable.
- **Phase 2 — String Caching:** `normalizedToKey` + `nameToNormalized` cache built in `LoadCurses()`. 4 hot-path sites use cache lookup instead of `string.gsub(string.lower(...))`. Eliminates ~4,480 string allocs/sec.
- **Phase 3 — Scan Optimization:** UNIT_AURA debouncing (50ms coalescing via `ScheduleEvent`). Removed redundant `ScanTargetForSharedDebuffs` call in `ScanForProcDebuff`. Combat-state gating: skip scan when no GUIDs tracked.
- **Phase 4 — Structural:** `FormatArmor()` and `ResolveBorderMode()`/`ResolveBorderColor()` hoisted to file scope (no per-call closure allocation). Frame reuse: `guid=nil` instead of `ui.unitFrames = {}` (prevents orphans). `BuildRaidOrderLookup` dirty flag: only rebuild when order changes. `missingKeys` pool reused across render ticks. Position comparison uses separate x/y fields (avoids string concat). HP text `SetText()` skipped when value unchanged. Minimap patch OnUpdate throttled to 200ms. `pcall` protection around scan loop. `TITLE_BAR_HEIGHT` constant extracted.

### Bug Fixes
- **Bar misalignment on frame reuse** — Reused frames retained stale section widths from previous config. Now `DisplayGuid` checks and updates `firstSection`/`secondSection`/`thirdSection` widths when they don't match current config.
- **TestOverlay `filter.range` error** — `IsSpellInRange()` threw "Unknown unit name" on fake test GUIDs. Added `CursiveTestOverlay_IsTestGuid` guard (always returns "in range").
- **TestOverlay `HasSpellReflect` error** — `UnitExists()` threw error on fake GUIDs. Added TestOverlay guard (returns nil).
- **Proc refresh refactor** — Extracted 11-tab nested `ProcessProcDebuffRefresh()` into standalone function for readability. Fixed own Shadow Weaving being skipped by proc refresh check.
- **SavedVariable type validation** — Added guards for `anchor`, `scale`, `maxrow`, `maxcol`, `maxcurses`, `height`, `width`, `spacing` to prevent corruption crashes.
- **`puncturearmor` in raidDebuffOrder** — Was missing from the default order array in `global.lua`.

---

## v4.0.3 — 2026-03-22

CC/Reflect Transparency, Mind Control fix, sort stability, Eye of Dormant fix.

### Bug Fixes (2026-03-22)
- **Sort flicker fix** — Debuffs with identical rounded duration no longer flicker between positions. Sorting now uses raw float (hundredths of a second) for stable ordering, with application time as tie-breaker.
- **Eye of Dormant Corruption (55111)** — Duration extension (+3s) now always applied when trinket is equipped. Previous logic incorrectly compared haste-reduced tooltip duration against base duration, causing double-counting or missed extension. New `eyeExtended` flag prevents premature icon removal when server debuff expires before addon timer.
- **Duration text clipping** — Timer display now uses explicit `tostring()` conversion, fixing cases where digits ("7", "6") disappeared or values were truncated ("30" shown as "3") under certain UI scale/font configurations.
- **New: `TimeRemainingRaw()`** — Internal function returning unrounded remaining time for stable sub-second sort comparisons.

### Previous (2026-03-18)

CC/Reflect Transparency, Mind Control fix, and new consumable debuff.

### Bug Fixes
- **Mind-Controlled players in mob list** — MC'd players appeared in the tracking list despite "Not Player" filter being active. The target/raidmark priority shortcuts in `ShouldDisplayGuid` were bypassing all filters. Fix: MC detection guard (`UnitIsPlayer + UnitCanAttack`) at the top of the filter chain, before any shortcuts.
- **armorCache nil crash** — `CleanupArmorCache()` could crash with `bad argument to pairs (table expected, got nil)` when called before initialization. Added nil guard and lazy-init in `UpdateArmorCache`.

### New Features
- **CC / Reflect Transparency** — Targets under crowd control (Banish, Polymorph, Hibernate, Freezing Trap, Scatter Shot, Wyvern Sting, etc.) or Spell Reflect are now displayed with reduced opacity (alpha 0.35), making it visually clear that attacking them is pointless. Toggleable via "CC / Reflect Transparency" checkbox in General Settings (default: on).
  - CC detection via existing `shared_debuffs` category system (`category = "cc"`)
  - Spell Reflect detection via `UnitBuff` scan for known reflect buff IDs:
    - `22067` — Reflection (Majordomo Adds, misc dungeon mobs)
    - `20619` — Magic Reflection (Molten Core mobs)
    - `13022` — Fire and Arcane Reflect (Anubisath, AQ)
    - `19595` — Shadow and Frost Reflect (Anubisath, AQ)
    - `460856` — Reflect Magic (TurtleWoW Custom)
  - New reflect IDs can be added to `curses.reflectBuffIds` table
- **Potent Venom tracking** — Added Vial of Potent Venoms (Spell ID 45416, 12s Nature DoT) as trackable consumable debuff. Category: Item/Utility, proc-based. Requested by community.

### New Functions
- `curses:HasActiveCC(guid)` — Checks if a GUID has any active CC debuff via shared debuff metadata
- `curses:HasSpellReflect(guid)` — Scans UnitBuff for known Spell Reflect buff IDs (requires SuperWoW)

---

## v4.0.2 — 2026-03-15

Minor fixes and Turtle Launcher integration.

### Changes
- **Default profiles corrected** — Fixed default profile data to match actual live SavedVariables
- **Turtle Launcher compatibility** — TOC adjustments to trigger launcher update detection (title version bump, Notes-zhCN removal, TOC touch)
- **Spy Enemy Player profile** — Reduced text sizes (10 → 9), README wording fix (guildmates → mates)
- **README** — Dragon emoji replaced with turtle emoji in footer

---

## v4.0.1 — 2026-03-11

Bugfixes, new display features, addon rename, and updated default profiles.

### Bug Fixes
- **Shadow Weaving: Mind Flay tracking** — Consecutive Mind Flay casts were cancelling each other's delayed scan events because they shared the same `ScheduleEvent` ID. Each scan now uses a unique ID via `GetTime()`.
- **Shadow Weaving: non-targeted mobs** — Shadow Weaving stacks were only updating on your current target because `ScanTargetForSharedDebuffs` was only called on `UNIT_AURA "target"`. Now `ScanForProcDebuff` triggers a full shared debuff scan immediately after queuing a new proc debuff, enabling stack/timer updates on all mobs.
- **Multicurse / isDarkHarvestReady nil error** — The `getEffectiveRefreshTime` function was moved above `pickTarget` (for multicurse to work) but its dependencies `isSpellOnCooldown` and `isDarkHarvestReady` were still defined later. Lua 5.0 requires top-down declaration order. All three functions are now in correct order.
- **Consecutive CAST proc scan cancellation** — The unique scan ID fix was only applied to CHANNEL events (Mind Flay). Now also applied to all CAST trigger events (Mind Blast, Shadow Bolt, etc.) for both foreign and own casts.

### New Features
- **Debuff Icon Spacing** — New slider (0–10, default 1) under Display > Layout to control the pixel gap between debuff icons. Previously hardcoded to 2.
- **Health Bar Spacing** — Renamed from "Spacing" for clarity.
- **Target Armor Position** — New slider (-30 to +30, default 0) under Display > Target Armor for horizontal offset of the armor display relative to its anchor point.

### Changes
- **Addon folder renamed: `Cursive` → `Cursive-Raid`** — TOC file renamed to match folder name (`Cursive-Raid.toc`). Users upgrading from v4.0 need to copy their SavedVariables files from `Cursive.lua` to `Cursive-Raid.lua` in both account and character WTF folders.
- **7 new default profiles** replacing the previous 12 class-specific ones: Default, Pro Full, Raid Debuff Tracker, Raid Live Armor View, Spy Enemy Player, Targeted Only Own Debuffs, Track All Near Friendly Player. Feature-focused rather than class-focused to inspire creative use.
- **Version bumped** to 4.0.1 in TOC, Options UI, and settings.

---

## v4.0 — 2026-03-08

The biggest update since the addon's creation. Complete UI overhaul, full profile system, and dozens of polish items across every aspect of the addon.

### New Features

#### Profile System
- **Save & Load profiles** — Snapshot your entire configuration and switch instantly
- **12 default profiles** — Raid Leader, Warlock, Warrior Tank, Mage, Healer, Rogue, Hunter, Priest, Compact, Wide, PvP, Druid
- **Export & Import** — Share profiles as text strings between players
- **Cross-character** — Profiles stored globally via `SavedVariables: CursiveProfiles`
- **Live refresh** — No `/reload` needed, all changes apply instantly
- **Minimap quickswitch** — Right-click the minimap icon for a profile selection menu
- **6th Options tab** — Full profile management UI (select, load, save, delete, save as new, export/import)
- **Scrollable dropdown** — Profile list dynamically sizes up to 16 visible entries, scrollable beyond that

#### Target Armor Display
- **Live armor monitoring** — Reads armor via `UnitResistance(GUID, 0)` without targeting
- **Build options** — Live + Total, Live + Reduced, Total + Reduced, or individual values
- **Color-coded** — Green → Yellow → Red as armor is stripped
- **Shield icon** — Configurable position (Left, Center, Right, None)
- **Position** — Anchored relative to raid icons with intelligent spacing
- **NPC-only** — Automatically hidden for player targets

#### Debuff Order Rewrite
- **Swap Side** — Categories can be moved to the opposite side of the bar
- **Per-category dropdowns** — Front, Mid, Rear, Last, Swap Side for each category (Own Class, Own Raid, Other Class, Other Raid)
- **Multiple categories per position** — Several categories can share Swap Side simultaneously

#### Options UI Overhaul
- **Decimal Duration dropdown** — None, White, or Red (replaces old checkbox)
- **Duration Timer / Stack Counter** — Added "None" option to hide completely
- **Debuff border system** — Per-category color coding (Own Class, Own Raid, Other Class, Other Raid)
- **Slider refinements** — Max Debuffs 18, Debuff Icon Size 30, Raid Icon Size 30
- **Armor section** — Enable toggle, Build dropdown, Position dropdown, Show Icon dropdown
- **Armor text size** — Separate slider (6-15)
- **Name text size** — Separate slider, independent from HP text size
- **HP formatting** — Clean display without decimals (110m, 440k, full number under 10k)

### Bug Fixes
- **Class Enable All button** — Fixed using wrong data key (`classDebuffKeys` → `classDebuffs`)
- **Test Overlay errors** — Added `UnitIsPlayer` wrapper and `IsTestGuid` guards in `curses.lua`
  - Fixed `CanApplyBleed`, `UpdateArmorCache`, `ScanGuidForCurse` for fake GUIDs
- **AceDB sentinel pattern** — Debuff order now persists correctly across sessions
- **Winter's Chill** — Apostrophe in normalization fixed
- **Sunder/EA exclusivity** — Bidirectional replacement (EA removes Sunder, Sunder removes EA)
- **Expose Armor** — Targetless CP detection via armor-diff now fully reliable

### UI Polish
- Display checkbox reorder: Health Bar → Unit Name → Raid Icons → Invert Bar Layout → Reverse Bars Upwards → Always Show Current Target
- Removed checkboxes: Show Targeting Arrow, Colored Decimal Duration (replaced by dropdown)
- Renamed labels throughout for clarity and consistency
- "Cursive" title above bars permanently removed
- Profiles info text removed for cleaner look
- Pixel-perfect spacing across all 6 tabs
- Dynamic raid order icon grid (auto-shrink at 14+ icons)

### Technical
- Profile serialization via `loadstring()` + `setfenv()` sandbox (pfUI-proven pattern)
- `raidDebuffOrder` auto-repair on profile load (missing keys appended, unknown keys removed)
- `shareddebuffs` patch on load (keys not in profile set to `false`)
- `DeepCopy` without metatables for clean snapshots
- New files: `profiles.lua` (385 lines), `profilesUI.lua` (733 lines), `defaultProfiles.lua` (439 lines)

---

## v3.2.1-beta — 2026-02-15

### New Features
- **Expose Armor CP Detection** — Targetless detection via SuperWoW `UnitResistance(GUID)` API. Monitors armor diff to detect Expose Armor stacks without requiring the rogue's target.
- **Shadow Vulnerability** — Complete fix for Shadow Weaving stack tracking and proc detection.
- **Raid Debuff Order UI** — Icon-grid reordering of debuff display priority in the Raid tab.
- **Test Overlay** — Live UI preview with 8 fake targets and class-specific debuffs. Toggle via `/cursive test`.
- **Show Missing Debuffs** — Grey desaturated icons for expected but inactive raid debuffs.
- **Winter's Chill Fix** — Correct stack tracking (apostrophe normalization).
- **Thunderfury / Nightfall / Annihilator** — Proc-based debuffs now track duration via `procExpected` system.
- **Weapon Procs** — Puncture Armor tracking added.

### Bug Fixes
- Fixed Shadow Vulnerability not appearing when cast by other raid members.
- Fixed proc debuff timers resetting on re-scan.
- Fixed debuff order not persisting across sessions (AceDB sentinel trick).
- Fixed `ScanForProcDebuff` destroying running timers.
- Fixed `DisplayGuid` using `GetTime()` instead of detection timestamp.

---

## v3.2.0 — 2026-02-08

### New Features (Initial Raid Edition)
- **Shared Debuff Tracking** — Full raid-wide debuff tracking via SuperWoW GUID + UNIT_CASTEVENT
- **Debuff Order System** — Configurable display order for shared raid debuffs
- **Debuff Border Colors** — Color-coded borders by debuff category
- **Complete Options UI** — 5-tab configuration panel
- Fork of [Kirchlive/Cursive](https://github.com/Kirchlive/Cursive) v3.1.0

---

## v3.0–v3.1

Updates by [Kirchlive](https://github.com/Kirchlive): Dark Harvest support, trinket duration fixes, UI improvements.

## Pre-v3.0

Original [Cursive](https://github.com/pepopo978/Cursive) by pepopo978: ShaguScan-based multi-curse tracking foundation.
