-- profiles.lua — Cursive Raid Profile System
-- Save, load, delete, export and import full addon configuration snapshots.
-- Inspired by pfUI profile management. Lua 5.0 compatible (Vanilla 1.12).
-- NO string.match(), string.gmatch(), #table, {...}, table.unpack(), self in handlers

-- ============================================================
-- 1. Initialize global SavedVariable
-- ============================================================
if not CursiveProfiles then
    CursiveProfiles = {}
end

-- v4.0: Track currently loaded profile name
local currentProfileName = nil

-- ============================================================
-- 2. Deep copy (circular-reference safe, no metatables copied)
-- ============================================================
local function DeepCopy(src)
    local lookup = {}
    local function _copy(s)
        if type(s) ~= "table" then return s end
        if lookup[s] then return lookup[s] end
        local new = {}
        lookup[s] = new
        for k, v in pairs(s) do
            new[_copy(k)] = _copy(v)
        end
        return new
    end
    return _copy(src)
end

-- ============================================================
-- 3. Position keys (optionally excluded from profiles)
-- ============================================================
local POSITION_KEYS = {
    anchor = true,
    x = true,
    y = true,
}

-- ============================================================
-- 4. Snapshot: capture current config as plain table
-- ============================================================
-- AceDB-2.0 inheritDefaults() copies defaults directly into the profile
-- table (no lazy metatable for regular keys), so pairs() sees everything.

local function SnapshotProfile(includePosition)
    local p = Cursive.db.profile
    if not p then return nil end

    local snapshot = DeepCopy(p)

    if not includePosition then
        for key in pairs(POSITION_KEYS) do
            snapshot[key] = nil
        end
    end

    return snapshot
end

-- ============================================================
-- 5. Apply: load profile data into active config
-- ============================================================
local function ApplyProfile(profileData, includePosition)
    if not profileData then return false end
    local p = Cursive.db.profile
    if not p then return false end

    local data = DeepCopy(profileData)

    -- Strip position if not wanted
    if not includePosition then
        for key in pairs(POSITION_KEYS) do
            data[key] = nil
        end
    end

    -- Apply top-level values
    for key, value in pairs(data) do
        if type(value) == "table" then
            -- For sub-tables (shareddebuffs, ignorelist, raidDebuffOrder):
            -- replace entirely, then patch missing keys below
            p[key] = DeepCopy(value)
        else
            p[key] = value
        end
    end

    -- Patch shareddebuffs: keys in current but NOT in profile → false
    if data.shareddebuffs and p.shareddebuffs then
        for key in pairs(p.shareddebuffs) do
            if data.shareddebuffs[key] == nil then
                p.shareddebuffs[key] = false
            end
        end
    end

    -- Repair raidDebuffOrder: add missing known keys, remove unknown
    if p.raidDebuffOrder then
        local knownKeys = {}
        if Cursive.optionsData and Cursive.optionsData.allRaidKeys then
            for _, k in ipairs(Cursive.optionsData.allRaidKeys) do
                knownKeys[k] = true
            end
            -- Also add weapon proc keys not in allRaidKeys
            if Cursive.optionsData.raidWeaponProcKeys then
                for _, k in ipairs(Cursive.optionsData.raidWeaponProcKeys) do
                    knownKeys[k] = true
                end
            end
        end

        -- Only repair if we have known keys to compare against
        local hasKnown = false
        for _ in pairs(knownKeys) do hasKnown = true; break end

        if hasKnown then
            -- Build set of what's in the loaded order
            local inOrder = {}
            for _, k in ipairs(p.raidDebuffOrder) do
                inOrder[k] = true
            end
            -- Remove unknown keys
            local cleaned = {}
            for _, k in ipairs(p.raidDebuffOrder) do
                if knownKeys[k] then
                    table.insert(cleaned, k)
                end
            end
            -- Append missing known keys
            for k in pairs(knownKeys) do
                if not inOrder[k] then
                    table.insert(cleaned, k)
                end
            end
            p.raidDebuffOrder = cleaned
        end
    end

    return true
end

-- ============================================================
-- 6. Serialize: table → Lua source string
-- ============================================================
local function Serialize(tbl, name, spacing)
    spacing = spacing or ""
    local tname
    if spacing == "" then
        tname = name
    else
        tname = "[\"" .. tostring(name) .. "\"]"
    end
    local str = spacing .. tname .. " = {\n"
    local hasContent = false

    -- Sort keys for deterministic output
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        -- Sort by type first (numbers before strings), then by value
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)

    for _, k in ipairs(keys) do
        local v = tbl[k]
        local kStr
        if type(k) == "number" then
            kStr = "[" .. k .. "]"
        else
            kStr = "[\"" .. tostring(k) .. "\"]"
        end

        if type(v) == "table" then
            local result = Serialize(v, k, spacing .. "  ")
            if result then
                hasContent = true
                str = str .. result
            end
        elseif type(v) == "string" then
            hasContent = true
            str = str .. spacing .. "  " .. kStr .. " = \"" .. string.gsub(v, "\\", "\\\\") .. "\",\n"
        elseif type(v) == "number" then
            hasContent = true
            str = str .. spacing .. "  " .. kStr .. " = " .. tostring(v) .. ",\n"
        elseif type(v) == "boolean" then
            hasContent = true
            str = str .. spacing .. "  " .. kStr .. " = " .. tostring(v) .. ",\n"
        end
    end

    str = str .. spacing .. "}"
    if spacing ~= "" then
        str = str .. ","
    end
    str = str .. "\n"
    return hasContent and str or nil
end

-- ============================================================
-- 7. Public API: Cursive.profiles
-- ============================================================
Cursive.profiles = {}

function Cursive.profiles.GetCurrentName()
    return currentProfileName
end

function Cursive.profiles.List()
    local names = {}
    for name in pairs(CursiveProfiles) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function Cursive.profiles.Save(name, includePosition)
    if not name or name == "" then return false, "Name required" end

    -- Sanitize: allow alphanumeric, spaces, hyphens, underscores
    local _, _, bad = string.find(name, "([^%w%s%-_]+)")
    if bad then
        return false, "Invalid characters: " .. bad
    end

    -- Trim whitespace
    local _, _, trimmed = string.find(name, "^%s*(.-)%s*$")
    name = trimmed or name
    if name == "" then return false, "Name cannot be empty" end

    local includePos = (includePosition ~= false)
    CursiveProfiles[name] = SnapshotProfile(includePos)

    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Profile saved: |cFF00FF00" .. name .. "|r")
    return true
end

function Cursive.profiles.Load(name, includePosition)
    if not name or not CursiveProfiles[name] then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Profile not found: |cFFFF4444" .. (name or "nil") .. "|r")
        return false, "Profile not found"
    end

    local includePos = (includePosition ~= false)
    local success = ApplyProfile(CursiveProfiles[name], includePos)

    if success then
        currentProfileName = name
        if Cursive.UpdateFramesFromConfig then
            Cursive.UpdateFramesFromConfig()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Profile loaded: |cFF00FF00" .. name .. "|r")
    end

    return success
end

function Cursive.profiles.Delete(name)
    if not name or not CursiveProfiles[name] then
        return false, "Profile not found"
    end
    CursiveProfiles[name] = nil
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Profile deleted: |cFFFF8800" .. name .. "|r")
    return true
end

function Cursive.profiles.Rename(oldName, newName)
    if not CursiveProfiles[oldName] then return false, "Profile not found" end
    if not newName or newName == "" then return false, "New name required" end
    if CursiveProfiles[newName] then return false, "Name already exists" end

    CursiveProfiles[newName] = CursiveProfiles[oldName]
    CursiveProfiles[oldName] = nil
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Profile renamed: " .. oldName .. " -> |cFF00FF00" .. newName .. "|r")
    return true
end

function Cursive.profiles.Exists(name)
    return CursiveProfiles[name] ~= nil
end

function Cursive.profiles.Count()
    local count = 0
    for _ in pairs(CursiveProfiles) do count = count + 1 end
    return count
end

function Cursive.profiles.Export(name, includePosition)
    local data
    if name and CursiveProfiles[name] then
        data = CursiveProfiles[name]
    else
        data = SnapshotProfile(includePosition ~= false)
    end
    if not data then return nil end
    return Serialize(data, "CursiveProfile")
end

function Cursive.profiles.Import(str)
    if not str or str == "" then return false, nil, "Empty input" end

    local func, err = loadstring(str)
    if err then return false, nil, "Invalid format: " .. err end

    -- Sandbox: no access to globals
    local env = {}
    setfenv(func, env)

    -- Protected call
    local ok, runErr = pcall(func)
    if not ok then return false, nil, "Execution error: " .. tostring(runErr) end

    if not env.CursiveProfile then
        return false, nil, "No CursiveProfile table found in import string"
    end

    return true, DeepCopy(env.CursiveProfile), nil
end

-- ============================================================
-- 8. Slash commands
-- ============================================================
-- /cursive profile <save|load|delete|list> [name] is routed by the
-- single dispatcher in commands.lua (v5.1.0-octo). The old
-- PLAYER_LOGIN + one-frame-delay SlashCmdList wrapper was removed.
