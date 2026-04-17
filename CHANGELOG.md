# Changelog

## v4.1.3 — 2026-04-17

Follow-up to v4.1.2. Split range semantics: the "Within Range" filter and the OOR-stripe indicator now use distinct range checks, matching their different purposes.

### Bug Fixes
- **OOR stripes showed up only as LoS-blocked, never as out-of-range (ui.lua:387)** — v4.1.2 made `filter.range()` a 120-yard check. Rob reported that a Bloodscalp attacked by another player showed up in his list without stripes at 80 yards — "in range" per the 120y rule, but obviously out of casting range for a Warlock (30-42y with talents). The real semantic he wanted was: **the filter broadens tracking to 120y, but the stripes tell him whether he can actually cast on the unit right now**. Fix: added `filter.inSpellRange(unit)` using `UnitXP("distanceBetween")` against a class-specific max spell range (Warlock 42y, Mage 41y, Priest 40y, Druid 35y, Hunter 41y, Shaman/Paladin 30y, melee 10y). ui.lua OOR-stripe code now calls this instead of `filter.range`. `filter.range` itself stays at 120y for the "Within Range" filter.
- **Why not IsSpellInRange?** — Verified 2026-04-17 via ClaudeBridge: `IsSpellInRange("Corruption", guid)` returns `1` (in range) for passive-acquired GUIDs at 600+ yards when the unit is not the current target. The WoW 1.12 API only evaluates the range predicate correctly for target/party/raid unit tokens. Using `UnitXP("distanceBetween", "player", guid)` is reliable regardless of target state and yields the actual yard value.

### Caching
- `spellRangeCache` added as a sibling to `rangeCache` (both 250ms TTL). `filter.cleanRangeCache()` now purges expired entries from both.

### Live Verification
- Live data: Bloodscalp at 80y → `filter.range = true` (within 120y), `filter.inSpellRange = false` (>42y) → stripes shown, still in list. Exactly Rob's intended semantic.

---

## v4.1.2 — 2026-04-17

Follow-up hotfix for three issues surfaced during v4.1.1 live validation.

### Bug Fixes
- **Targets disappeared at standstill (core.lua:93, regression from v4.1.1)** — the new `evictStale()` function used a 30-second TTL-based removal. Standing still meant no new UNIT_COMBAT events fired, GUID timestamps aged, and mobs still physically visible were silently removed from the list. Fix: evict based on `UnitExists(guid)` (SuperWoW GUID-based lookup) instead of elapsed time. A mob that's still in server-range keeps returning `exists=true` regardless of whether events fire. The 5-minute LRU_TTL stays as a safety-valve for edge cases where UnitExists lies. Resolves the "list goes empty after a few seconds of standing still" symptom.
- **Name Length slider had no effect (ui.lua:414)** — `nameText:SetWidth()` was only called once in `CreateBar` (ui.lua:1005, 1120). The slider wrote the new value to `Cursive.db.profile.namelength` but `BarUpdate` only set the text, never updated the widget width. Changing the slider required `/reload` to see any effect. Fix: apply `SetWidth` on each `BarUpdate` with a `_lastMaxW` cache-guard so the call only runs when the value actually changed.

### Semantics Change
- **"Within Range" is now a fixed 120-yard radius** (filter.lua:91) — previously the filter used `IsSpellInRange` against class-specific spells (~30-42 yards for Warlock, varied per class) which made the label misleading. New primary path uses `UnitXP("distanceBetween", "player", guid) <= 120`. When the filter is disabled, all `UnitExists`-trackable units are shown (server-range ~300 yards). The old spell-range logic remains as a fallback when `UnitXP` is unavailable. Tooltip updated to "Only show units within 120 yards (when disabled, all API-trackable units are shown)". No migration needed — existing `filterrange` DB flag is reused.

### Live Verification
All fixes validated 2026-04-17 via ClaudeBridge:
- `UnitXP("distanceBetween", "player", "player")` returns `0` as expected (API confirmed)
- Standing still for 60s+ no longer empties the list (mobs remain as long as `UnitExists` returns true)
- Name Length slider change applies within one `BarUpdate` tick (no `/reload` needed)

---

## v4.1.1 — 2026-04-17

Hotfix for three regressions observed during the 2026-04-16 Naxx raid, plus TestOverlay modernization so future regressions in CC/Reflect/OOR/LoS paths are catchable in isolation.

### Bug Fixes
- **Target tracking broken in v4.1.0 (Bug #1)** — `UNIT_COMBAT` delivers a unit token (e.g. `"raid5target"`) in `arg1`, not a GUID. The v4.0.6 `0x`-prefix guard in `addGuid()` silently rejected every token, making UNIT_COMBAT a dead passive-acquisition path. Symptoms: mobs only appeared after being actively targeted; one guild member had a completely empty Cursive list until he manually clicked each mob. Fix: `core.lua` OnEvent dispatcher now routes UNIT_COMBAT through `add(token)` which resolves the token via `UnitExists()`. `add()` also gained the same GUID-cap check that `addGuid()` already had to prevent cap bypass.
- **LoS check permanently true (Bug #2)** — `UnitXP("inSight", ...)` returns a **boolean** (`true`/`false`), not a number. `ui.lua` checked `if ok and los == 0 then inSight = false end` — but `false == 0` is never true in Lua, so `inSight` stayed `true` regardless of actual line-of-sight state. Mobs behind walls/pillars showed no OOR stripes. Additionally: LoS check was gated by `inRange` — a target behind a wall IN range was never detected as LoS-blocked. Fix: changed the check to `los == false` and decoupled LoS from inRange. Live-verified return type via ClaudeBridge on 2026-04-17.
- **Raid-mark filter bypass (Bug #3)** — `filter.lua:192` had an unconditional early-return `return true` for any raid-icon + attackable unit, overriding Combat/Range/Hostile filters regardless of the `filterraidmark` toggle. Symptom: an OOC boss with a stale Skull mark stayed visible even when "In Combat" filter was active. Fix: bypass now applies only when the `filterraidmark` checkbox is explicitly enabled. **Migration note:** users who relied on the old implicit "marked mobs always show" behavior must now enable the "Has Raid Mark" filter toggle to restore prior behavior.

### Stability
- **LRU evict for stale GUIDs** — Added `Cursive.core.evictStale()` running at 2Hz from the core frame's OnUpdate. Drops non-priority GUIDs (not target, not raid-marked, not cursed) that have not been refreshed for 30s. Keeps `_guidCount` healthy so legitimate new mobs can always enter when the cap is near-full. Complements the relaxed UNIT_COMBAT acquisition path.
- **Broken "?" debuff icons (ui.lua:1696)** — render priority chain locked in the "INV_Misc_QuestionMark" fallback texture for spells the player doesn't know (Hand of Reckoning, cross-class judgements etc.), ignoring the valid `sharedTexture` from the debuff data. Happens when a third-party addon (e.g. SuperCleveRoidMacros/CursiveCustomSpells) injects entries into `trackedCurseIds` with `texture = "?"` after LoadCurses. Fix: skip the cached texture in the render chain when it's the "?" fallback. Now falls through to `sharedTexture` → `SpellInfo` → live scan → fallback (correct behavior).
- **"?" texture cached by Cursive itself (curses.lua:283)** — if `SpellInfo(id)` returned "?" directly (some client/DLL combinations do this instead of nil for unknown spells), the init loop cached it permanently. Fix: treat a "?" return from `SpellInfo` as nil, letting downstream fallbacks try other sources.
- **TestOverlay "Unknown unit name" errors (filter.lua:100)** — regression introduced when the test-GUID gate was switched to `CursiveTestOverlay_IsTestGuid` (state-dependent on `testActive`). Stale test-GUIDs observed by callers during Enable/Disable transitions fell through to `CheckInteractDistance()` and errored. Fix: gate on string prefix `strfind(unit, "CURSIVE_TEST_", 1, true)` — state-independent.

### TestOverlay Consolidation
Reduced from 14 targets to **8 targets**, each with a unique raid icon (1-8) so they always fit the default `maxrow=8`. Every Cursive feature still covered:

| ID | Name | Icon | Exercise |
|----|------|------|----------|
| 001 | Raid Boss | Skull | Shared debuffs + own DoTs (mixed ownership) |
| 002 | Scythe Dummy | Cross | All 6 Scythe-of-Elune procs |
| 003 | Elite Tank Target | Square | Stacked debuffs (Expose/Fire/Shadow/Winter all 5x) |
| 004 | Weapon Proc Dummy | Triangle | Weapon/trinket procs (Armor Shatter, Puncture Armor, Spell Vuln, Thunderfury) |
| 005 | CC'd Add | Diamond | CC transparency (`HasActiveCC` → α 0.35) |
| 006 | Reflector | Circle | Spell Reflect (`HasSpellReflect` → red overlay + school label) |
| 007 | OOR Test | Moon | Out-of-range stripes (`filter.range` override) |
| 008 | LoS Block | Star | Line-of-sight stripes (`UnitXP("inSight")` override) |

**Feature mocks**: `CursiveTestOverlay_HasActiveCC`, `HasSpellReflect`, `IsOutOfRange`, `IsBlockedLoS` — all return `nil` for real GUIDs, `true/false`/school-string for test GUIDs, so call-sites use `if mock ~= nil then return mock end` to distinguish override from no-override.

**TestOverlay ownDots filter** — class-own DoT injection (via `trackedCurseIds`) now skips spells whose `SpellInfo` returns nil or the "?" fallback, preventing broken icons on test targets for spells the player doesn't know.

---

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
