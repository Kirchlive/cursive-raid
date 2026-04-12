-- CursiveTestOverlay.lua (v3.2.1)
-- Test Overlay: generates fake targets with debuffs for live UI preview
-- Lua 5.0 compatible (Vanilla 1.12 / TurtleWoW)

-- No early return — functions must always be defined as globals
-- Cursive table is guaranteed to exist (global.lua loads before this)

-- ============================================================
-- Test Data Definition
-- ============================================================

local TEST_GUID_PREFIX = "CURSIVE_TEST_"

-- Own debuff sets per player class (key = lowercase class token)
-- These are SHARED debuffs the player "owns" (currentPlayer = true, tracked via sharedDebuffs)
local ownDebuffsByClass = {
    warlock = {
        { key = "curseofshadow", elapsed = 15 },
        { key = "curseoftheelements", elapsed = 40 },
        { key = "curseofrecklessness", elapsed = 8 },
        { key = "curseoftongues", elapsed = 22 },
        { key = "curseofweakness", elapsed = 50 },
    },
    druid = {
        { key = "faeriefire", elapsed = 12 },
        { key = "demoroar", elapsed = 8 },
    },
    warrior = {
        { key = "sunderarmor", elapsed = 4, stacks = 5 },
        { key = "demoshout", elapsed = 10 },
        { key = "thunderclap", elapsed = 6 },
    },
    mage = {
        { key = "winterschill", elapsed = 4, stacks = 5 },
        { key = "firevulnerability", elapsed = 6, stacks = 3 },
    },
    priest = {
        { key = "shadowweaving", elapsed = 2, stacks = 5 },
    },
    rogue = {
        { key = "exposearmor", elapsed = 8, stacks = 4 },
    },
    hunter = {
        { key = "faeriefire", elapsed = 20 },
    },
    shaman = {},
    paladin = {},
}

-- 8 test targets with varying HP, names, raid icons
-- own debuffs are injected dynamically based on player class
local testTargets = {
    {
        id = "001", name = "Raid Boss",
        hp = 100, maxHp = 2850000, raidIcon = 8, -- Skull
        debuffs = {
            { key = "sunderarmor", stacks = 5, elapsed = 4 },
            { key = "faeriefire", stacks = 0, elapsed = 12 },
            { key = "shadowvulnerability", stacks = 0, elapsed = 2 },
            { key = "thunderfury", stacks = 0, elapsed = 5 },
        },
        ownSlots = 3, -- how many own debuffs to add from class list
    },
    {
        id = "002", name = "Boss Add",
        hp = 82, maxHp = 1650000, raidIcon = 7, -- Cross
        debuffs = {
            { key = "sunderarmor", stacks = 3, elapsed = 9 },
            { key = "curseoftheelements", stacks = 0, elapsed = 20 },
            { key = "winterschill", stacks = 3, elapsed = 4 },
        },
        ownSlots = 2,
    },
    {
        id = "003", name = "Elite Add",
        hp = 65, maxHp = 2400000, raidIcon = 6, -- Square
        debuffs = {
            { key = "exposearmor", stacks = 5, elapsed = 3 },
            { key = "firevulnerability", stacks = 5, elapsed = 6 },
            { key = "shadowweaving", stacks = 5, elapsed = 1 },
            { key = "curseofshadow", stacks = 0, elapsed = 55 },
        },
        ownSlots = 2,
    },
    {
        id = "004", name = "Dragon",
        hp = 45, maxHp = 3100000, raidIcon = 4, -- Triangle
        debuffs = {
            { key = "sunderarmor", stacks = 5, elapsed = 2 },
            { key = "faeriefire", stacks = 0, elapsed = 30 },
            { key = "armorshatter", stacks = 3, elapsed = 10 },
            { key = "spellvulnerability", stacks = 0, elapsed = 1 },
            { key = "curseofrecklessness", stacks = 0, elapsed = 35 },
        },
        ownSlots = 1,
    },
    {
        id = "005", name = "Trash Mob",
        hp = 28, maxHp = 520000, raidIcon = 3, -- Diamond
        debuffs = {
            { key = "sunderarmor", stacks = 4, elapsed = 7 },
            { key = "thunderfury", stacks = 0, elapsed = 3 },
        },
        ownSlots = 1,
    },
    {
        id = "006", name = "Raid Boss 2",
        hp = 12, maxHp = 3300000, raidIcon = 2, -- Circle
        debuffs = {
            { key = "sunderarmor", stacks = 5, elapsed = 1 },
            { key = "exposearmor", stacks = 3, elapsed = 12 },
            { key = "firevulnerability", stacks = 5, elapsed = 2 },
            { key = "winterschill", stacks = 5, elapsed = 3 },
            { key = "shadowweaving", stacks = 5, elapsed = 5 },
            { key = "shadowvulnerability", stacks = 0, elapsed = 1 },
        },
        ownSlots = 1,
    },
    {
        id = "007", name = "Non-Elite",
        hp = 5, maxHp = 18000, raidIcon = nil,
        debuffs = {
            { key = "sunderarmor", stacks = 2, elapsed = 14 },
        },
        ownSlots = 1,
    },
    {
        id = "008", name = "Patrol Add",
        hp = 38, maxHp = 95000, raidIcon = nil,
        debuffs = {
            { key = "faeriefire", stacks = 0, elapsed = 18 },
        },
        ownSlots = 1,
    },
}

-- ============================================================
-- Mock API State
-- ============================================================

local testActive = false
local testData = {} -- guid -> { name, hp, maxHp, raidIcon }
local randomSeed = 0 -- increments on each enable for varied debuff selection

-- ============================================================
-- Overlay Toggle
-- ============================================================

function CursiveTestOverlay_Enable()
    if testActive then return end
    testActive = true
    randomSeed = randomSeed + 1

    local curses = Cursive.curses
    local now = GetTime()

    -- Determine player class for own debuffs
    local _, playerClass = UnitClass("player")
    local classKey = string.lower(playerClass or "warlock")
    local classOwnDebuffs = ownDebuffsByClass[classKey] or {}

    -- Build test data and inject into tracking tables
    for tIdx, t in ipairs(testTargets) do
        local guid = TEST_GUID_PREFIX .. t.id
        testData[guid] = {
            name = t.name,
            hp = math.floor(t.maxHp * t.hp / 100),
            maxHp = t.maxHp,
            raidIcon = t.raidIcon,
        }

        -- Register in core.guids (makes them renderable)
        Cursive.core.guids[guid] = now

        -- Build debuff entries in curses.guids
        if not curses.guids[guid] then
            curses.guids[guid] = {}
        end

        -- Add shared/raid debuffs (only if enabled in config)
        for _, d in ipairs(t.debuffs) do
            if Cursive.db.profile.shareddebuffs[d.key] then
                local debuffMeta = curses.sharedDebuffs[d.key]
                if debuffMeta then
                    local spellID, spellData
                    for sid, sdata in pairs(debuffMeta) do
                        if type(sdata) == "table" and sdata.name then
                            spellID = sid
                            spellData = sdata
                            break
                        end
                    end

                    if spellData then
                        local _, _, tex = SpellInfo(spellID)
                        curses.guids[guid][spellData.name] = {
                            rank = spellData.rank or 1,
                            duration = spellData.duration,
                            start = now - (d.elapsed or 0),
                            spellID = spellID,
                            targetGuid = guid,
                            currentPlayer = false,
                            sharedTexture = tex,
                            sharedStacks = d.stacks or 0,
                            sharedDebuffKey = d.key,
                            testFrozenElapsed = d.elapsed or 0,
                        }
                    end
                end
            end
        end

        -- Add own debuffs from player class (rotate through list based on target + randomSeed)
        local ownSlots = t.ownSlots or 0
        local ownCount = table.getn(classOwnDebuffs)
        if ownCount > 0 and ownSlots > 0 then
            -- Pick starting index based on target index + seed for variety
            local startIdx = math.mod((tIdx - 1 + randomSeed), ownCount)
            for slot = 1, ownSlots do
                local ownIdx = math.mod(startIdx + slot - 1, ownCount) + 1
                local od = classOwnDebuffs[ownIdx]
                if od and Cursive.db.profile.shareddebuffs[od.key] then
                    local debuffMeta = curses.sharedDebuffs[od.key]
                    if debuffMeta then
                        local spellID, spellData
                        for sid, sdata in pairs(debuffMeta) do
                            if type(sdata) == "table" and sdata.name then
                                spellID = sid
                                spellData = sdata
                                break
                            end
                        end

                        if spellData then
                            local _, _, tex = SpellInfo(spellID)
                            -- Override shared debuff with own version (sets currentPlayer = true)
                            local existing = curses.guids[guid][spellData.name]
                            curses.guids[guid][spellData.name] = {
                                rank = spellData.rank or 1,
                                duration = spellData.duration,
                                start = existing and existing.start or (now - (od.elapsed or 0)),
                                spellID = spellID,
                                targetGuid = guid,
                                currentPlayer = true,
                                sharedTexture = tex or (existing and existing.sharedTexture),
                                sharedStacks = od.stacks or (existing and existing.sharedStacks) or 0,
                                sharedDebuffKey = od.key,
                                testFrozenElapsed = existing and existing.testFrozenElapsed or (od.elapsed or 0),
                            }
                        end
                    end
                end
            end
        end
    end

    -- v3.2.1 FIX: Inject own class DoTs (from trackedCurseIds, NOT shared debuffs)
    -- These are the player's own spells (Corruption, Immolate, CoA etc.)
    local ownDotsAdded = 0
    if curses.trackedCurseIds then
        -- Collect unique spell names to avoid duplicates (multiple ranks)
        local seenNames = {}
        local ownDots = {}
        for spellID, spellData in pairs(curses.trackedCurseIds) do
            if spellData.name and not seenNames[spellData.name] then
                seenNames[spellData.name] = true
                table.insert(ownDots, { spellID = spellID, name = spellData.name, duration = spellData.duration, rank = spellData.rank or 1 })
            end
        end
        -- Distribute own DoTs across test targets (2-3 per target for realism)
        local dotCount = table.getn(ownDots)
        if dotCount > 0 then
            for tIdx, t in ipairs(testTargets) do
                local guid = TEST_GUID_PREFIX .. t.id
                -- Add 2-3 own DoTs per target, rotating through the list
                local dotsPerTarget = 3
                if tIdx > 4 then dotsPerTarget = 2 end
                for d = 1, dotsPerTarget do
                    local dotIdx = math.mod((tIdx - 1) * dotsPerTarget + (d - 1) + randomSeed, dotCount) + 1
                    local dot = ownDots[dotIdx]
                    if dot and not curses.guids[guid][dot.name] then
                        local elapsed = math.mod((tIdx * 3 + d * 2 + randomSeed), math.max(dot.duration - 2, 1)) + 1
                        local _, _, tex = SpellInfo(dot.spellID)
                        curses.guids[guid][dot.name] = {
                            rank = dot.rank,
                            duration = dot.duration,
                            start = now - elapsed,
                            spellID = dot.spellID,
                            targetGuid = guid,
                            currentPlayer = true,
                            sharedTexture = tex,
                            testFrozenElapsed = elapsed,
                        }
                        ownDotsAdded = ownDotsAdded + 1
                    end
                end
            end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Cursive] Test Overlay enabled — " .. table.getn(testTargets) .. " targets (" .. classKey .. ", " .. ownDotsAdded .. " own DoTs, timers frozen)|r")
end

function CursiveTestOverlay_Disable()
    if not testActive then return end
    testActive = false

    local curses = Cursive.curses

    -- Remove all test entries
    for guid, _ in pairs(testData) do
        curses:RemoveGuid(guid)
        Cursive.core.guids[guid] = nil
        curses.guids[guid] = nil

        -- Clean up sharedDebuffGuids
        for sharedDebuffKey, guids in pairs(curses.sharedDebuffGuids) do
            if guids[guid] then
                guids[guid] = nil
            end
        end
    end

    testData = {}

    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[Cursive] Test Overlay disabled|r")
end

function CursiveTestOverlay_IsActive()
    return testActive
end

function CursiveTestOverlay_IsTestGuid(guid)
    if not guid then return false end
    if not testActive then return false end
    return testData[guid] ~= nil
end

-- ============================================================
-- Timer Freeze: keep debuff timers frozen at their initial elapsed values
-- Called from ui.lua OnUpdate before rendering
-- ============================================================

-- Call this to refresh overlay after config changes (e.g. debuff enable/disable)
function CursiveTestOverlay_Refresh()
    if not testActive then return end
    CursiveTestOverlay_Disable()
    CursiveTestOverlay_Enable()
end

function CursiveTestOverlay_FreezeTimers()
    if not testActive then return end
    local curses = Cursive.curses
    local now = GetTime()

    for guid, _ in pairs(testData) do
        local debuffs = curses.guids[guid]
        if debuffs then
            for name, data in pairs(debuffs) do
                if data.testFrozenElapsed and data.duration then
                    -- Loop timer: when it would expire, restart from beginning
                    local elapsed = now - data.start
                    if elapsed >= data.duration then
                        -- Reset to initial elapsed offset
                        data.start = now - data.testFrozenElapsed
                    end
                end
            end
        end
        -- Keep core.guids timestamp fresh so cleanup doesn't remove them
        Cursive.core.guids[guid] = now
    end
end

-- ============================================================
-- API Overrides
-- These return mock values for test GUIDs, nil for real GUIDs
-- ============================================================

function CursiveTestOverlay_UnitExists(guid)
    if testActive and testData[guid] then
        return true, guid
    end
    return nil
end

function CursiveTestOverlay_UnitHealth(guid)
    if testActive and testData[guid] then
        return testData[guid].hp
    end
    return nil
end

function CursiveTestOverlay_UnitHealthMax(guid)
    if testActive and testData[guid] then
        return testData[guid].maxHp
    end
    return nil
end

function CursiveTestOverlay_UnitName(guid)
    if testActive and testData[guid] then
        return testData[guid].name
    end
    return nil
end

function CursiveTestOverlay_GetRaidTargetIndex(guid)
    if testActive and testData[guid] then
        return testData[guid].raidIcon
    end
    return nil
end

function CursiveTestOverlay_UnitIsDead(guid)
    if testActive and testData[guid] then
        return false
    end
    return nil
end

function CursiveTestOverlay_UnitIsVisible(guid)
    if testActive and testData[guid] then
        return true
    end
    return nil
end

function CursiveTestOverlay_UnitAffectingCombat(guid)
    if testActive and testData[guid] then
        return true
    end
    return nil
end

function CursiveTestOverlay_GetUnitColor(guid)
    if testActive and testData[guid] then
        return "FFC80000", 0.78, 0, 0, 1
    end
    return nil
end

function CursiveTestOverlay_UnitCanAttack(guid)
    if testActive and testData[guid] then
        return true
    end
    return nil
end
