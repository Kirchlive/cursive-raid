-- defaultProfiles.lua — Built-in Default Profiles for Cursive Raid v4.0.1
-- Loaded once on first run (no saved profiles exist yet).
-- Each profile is a PARTIAL table — only keys that differ from RegisterDefaults.
-- Missing keys will use the addon defaults automatically.
-- Lua 5.0 compatible.

-- ============================================================
-- Default profile definitions
-- ============================================================
local CursiveDefaultProfiles = {}

-- ============================================================
-- 1. DEFAULT — Clean starting point with all core features
-- ============================================================
CursiveDefaultProfiles["Default"] = {
    maxcurses = 8,
    maxrow = 8,
    maxcol = 1,
    height = 18,
    healthwidth = 100,
    curseiconsize = 18,
    raidiconsize = 18,
    scale = 1.0,
    spacing = 3,
    debufficonspacing = 1,
    showtargetindicator = true,
    showraidicons = true,
    showhealthbar = true,
    showunitname = true,
    alwaysshowcurrenttarget = true,
    orderfront = "ownclass",
    ordermiddle = "ownraid",
    orderback = "otherraid",
    orderlast = "otherclass",
    orderotherside = "none",
    shareddebuffs = {
        sunderarmor = true, exposearmor = true, faeriefire = true,
        curseofrecklessness = true, curseoftheelements = true, curseofshadow = true,
    },
    borderownclass = "green",
    borderotherclass = "off",
    borderownraid = "off",
    borderotherraid = "off",
    borderwidth = 2,
    armorStatusEnabled = false,
    filterincombat = true,
    filterhostile = true,
    filterattackable = true,
}

-- ============================================================
-- 2. PRO FULL — Everything enabled, full raid intelligence
-- ============================================================
CursiveDefaultProfiles["Pro Full"] = {
    maxcurses = 14,
    maxrow = 15,
    maxcol = 1,
    height = 18,
    healthwidth = 110,
    curseiconsize = 18,
    raidiconsize = 18,
    scale = 1.0,
    spacing = 3,
    debufficonspacing = 1,
    showtargetindicator = true,
    showraidicons = true,
    showhealthbar = true,
    showunitname = true,
    alwaysshowcurrenttarget = true,
    showMissingDebuffs = true,
    -- Armor tracking fully enabled
    armorStatusEnabled = true,
    armorColorIndicator = true,
    armorDisplayStructure = "live+removed",
    -- Full debuff order with swap side
    orderfront = "ownclass",
    ordermiddle = "ownraid",
    orderback = "otherraid",
    orderlast = "otherclass",
    orderotherside = "none",
    -- ALL raid debuffs enabled
    shareddebuffs = {
        sunderarmor = true, exposearmor = true, faeriefire = true, curseofrecklessness = true,
        firevulnerability = true, winterschill = true, shadowvulnerability = true, shadowweaving = true,
        curseoftheelements = true, curseofshadow = true,
        armorshatter = true, spellvulnerability = true, thunderfury = true, puncturearmor = true,
        demoshout = true, demoroar = true, thunderclap = true, mortalstrike = true,
        huntersmark = true, woundpoison = true, giftofarthas = true,
    },
    -- Colored borders for quick identification
    borderownclass = "green",
    borderotherclass = "classcolor",
    borderownraid = "green",
    borderotherraid = "classcolor",
    borderwidth = 2,
    borderopacity = 85,
    coloreddecimalduration = true,
    durationtimercolor = "classcolor",
    filterincombat = true,
    filterhostile = true,
    filterattackable = true,
}

-- ============================================================
-- 3. RAID DEBUFF TRACKER — Focus on tracking all raid debuffs
-- ============================================================
CursiveDefaultProfiles["Raid Debuff Tracker"] = {
    maxcurses = 12,
    maxrow = 12,
    maxcol = 1,
    height = 16,
    healthwidth = 90,
    curseiconsize = 16,
    raidiconsize = 16,
    scale = 1.0,
    spacing = 2,
    debufficonspacing = 1,
    showtargetindicator = true,
    showraidicons = true,
    showhealthbar = true,
    showunitname = true,
    alwaysshowcurrenttarget = true,
    -- Raid debuffs first, own stuff behind
    orderfront = "otherraid",
    ordermiddle = "ownraid",
    orderback = "otherclass",
    orderlast = "ownclass",
    orderotherside = "none",
    -- All raid-relevant debuffs
    shareddebuffs = {
        sunderarmor = true, exposearmor = true, faeriefire = true, curseofrecklessness = true,
        firevulnerability = true, winterschill = true, shadowvulnerability = true, shadowweaving = true,
        curseoftheelements = true, curseofshadow = true,
        armorshatter = true, spellvulnerability = true, thunderfury = true, puncturearmor = true,
        demoshout = true, demoroar = true, thunderclap = true, mortalstrike = true,
        huntersmark = true, woundpoison = true, giftofarthas = true,
    },
    borderownclass = "off",
    borderotherclass = "classcolor",
    borderownraid = "off",
    borderotherraid = "classcolor",
    borderwidth = 2,
    borderopacity = 80,
    coloreddecimalduration = true,
    armorStatusEnabled = false,
    filterincombat = true,
    filterhostile = true,
    filterattackable = true,
}

-- ============================================================
-- 4. RAID LIVE ARMOR VIEW — Armor reduction monitoring
-- ============================================================
CursiveDefaultProfiles["Raid Live Armor View"] = {
    maxcurses = 6,
    maxrow = 10,
    maxcol = 1,
    height = 18,
    healthwidth = 100,
    curseiconsize = 18,
    raidiconsize = 18,
    scale = 1.0,
    spacing = 3,
    debufficonspacing = 1,
    showtargetindicator = true,
    showraidicons = true,
    showhealthbar = true,
    showunitname = true,
    alwaysshowcurrenttarget = true,
    -- Armor tracking is the star
    armorStatusEnabled = true,
    armorColorIndicator = true,
    armorDisplayStructure = "live+removed",
    armorTextSize = 11,
    -- Only armor-related debuffs
    orderfront = "otherraid",
    ordermiddle = "ownraid",
    orderback = "ownclass",
    orderlast = "otherclass",
    orderotherside = "none",
    shareddebuffs = {
        sunderarmor = true, exposearmor = true, faeriefire = true, curseofrecklessness = true,
        armorshatter = true, puncturearmor = true, thunderfury = true,
    },
    borderownclass = "green",
    borderotherclass = "classcolor",
    borderownraid = "green",
    borderotherraid = "classcolor",
    borderwidth = 2,
    coloreddecimalduration = true,
    filterincombat = true,
    filterhostile = true,
    filterattackable = true,
}

-- ============================================================
-- 5. SPY ENEMY PLAYER — Track enemy players in PvP
-- ============================================================
CursiveDefaultProfiles["Spy Enemy Player"] = {
    maxcurses = 6,
    maxrow = 10,
    maxcol = 1,
    height = 16,
    healthwidth = 90,
    curseiconsize = 16,
    raidiconsize = 16,
    scale = 1.0,
    spacing = 3,
    debufficonspacing = 1,
    showtargetindicator = true,
    showraidicons = true,
    showhealthbar = true,
    showunitname = true,
    alwaysshowcurrenttarget = true,
    -- Track players specifically
    filterincombat = false,
    filterhostile = true,
    filterattackable = true,
    filterplayer = true,
    -- CC and debuff awareness for PvP
    orderfront = "otherclass",
    ordermiddle = "ownclass",
    orderback = "otherraid",
    orderlast = "ownraid",
    orderotherside = "none",
    shareddebuffs = {
        polymorph = true, fear = true, howlofterror = true, psychicscream = true,
        intimidatingshout = true, hammerofjustice = true, sap = true,
        freezingtrap = true, scattershot = true, wyvernsting = true,
        banish = true, seduction = true, hibernate = true,
        shackleundead = true, mindcontrol = true,
        mortalstrike = true, woundpoison = true,
    },
    borderownclass = "green",
    borderotherclass = "red",
    borderownraid = "off",
    borderotherraid = "red",
    borderwidth = 3,
    borderopacity = 100,
    coloreddecimalduration = true,
    armorStatusEnabled = false,
}

-- ============================================================
-- 6. TARGETED ONLY OWN DEBUFFS — Minimal, only your own stuff
-- ============================================================
CursiveDefaultProfiles["Targeted Only Own Debuffs"] = {
    maxcurses = 8,
    maxrow = 1,
    maxcol = 1,
    height = 18,
    healthwidth = 100,
    curseiconsize = 18,
    raidiconsize = 18,
    scale = 1.0,
    spacing = 3,
    debufficonspacing = 1,
    showtargetindicator = false,
    showraidicons = true,
    showhealthbar = true,
    showunitname = true,
    alwaysshowcurrenttarget = true,
    -- Only show current target
    filtertarget = true,
    filterincombat = true,
    filterhostile = true,
    -- Own debuffs only — no raid tracking
    orderfront = "ownclass",
    ordermiddle = "ownraid",
    orderback = "none",
    orderlast = "none",
    orderotherside = "none",
    shareddebuffs = {},
    borderownclass = "green",
    borderotherclass = "off",
    borderownraid = "green",
    borderotherraid = "off",
    borderwidth = 2,
    coloreddecimalduration = true,
    armorStatusEnabled = false,
}

-- ============================================================
-- 7. TRACK ALL NEAR FRIENDLY PLAYER — Monitor nearby friendlies
-- ============================================================
CursiveDefaultProfiles["Track All Near Friendly Player"] = {
    maxcurses = 6,
    maxrow = 15,
    maxcol = 1,
    height = 14,
    healthwidth = 80,
    curseiconsize = 14,
    raidiconsize = 14,
    scale = 0.95,
    spacing = 2,
    debufficonspacing = 1,
    showtargetindicator = true,
    showraidicons = true,
    showhealthbar = true,
    showunitname = true,
    alwaysshowcurrenttarget = true,
    -- Track all nearby — no combat/hostile filter
    filterincombat = false,
    filterhostile = false,
    filterattackable = false,
    filterplayer = false,
    filternotplayer = false,
    -- Raid debuffs to watch on friendlies
    orderfront = "otherraid",
    ordermiddle = "ownraid",
    orderback = "otherclass",
    orderlast = "ownclass",
    orderotherside = "none",
    shareddebuffs = {
        sunderarmor = true, exposearmor = true, faeriefire = true, curseofrecklessness = true,
        curseoftheelements = true, curseofshadow = true,
        mortalstrike = true, woundpoison = true,
        demoshout = true, demoroar = true, thunderclap = true,
    },
    borderownclass = "off",
    borderotherclass = "off",
    borderownraid = "off",
    borderotherraid = "classcolor",
    borderwidth = 2,
    coloreddecimalduration = true,
    armorStatusEnabled = false,
}

-- ============================================================
-- Install defaults on first run
-- ============================================================
local installFrame = CreateFrame("Frame")
installFrame:RegisterEvent("PLAYER_LOGIN")
installFrame:SetScript("OnEvent", function()
    installFrame:UnregisterEvent("PLAYER_LOGIN")

    -- Only install if NO profiles exist yet (first run)
    if not CursiveProfiles then CursiveProfiles = {} end

    local hasAny = false
    for _ in pairs(CursiveProfiles) do hasAny = true; break end

    if not hasAny then
        for name, data in pairs(CursiveDefaultProfiles) do
            CursiveProfiles[name] = data
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive Raid:|r 7 default profiles installed. Open Profiles tab to browse.")
    end
end)
