--[[--------------------------------------------------------------------------
  threat.lua -- Cursive Threat module (OctoWoW / Turtle server threat API)
  Replaces TWThreat + TankPlates: per-enemy aggro coloring and threat text on
  the Cursive bars.

  Data source: the server-side TWTv4 threat feed (same protocol TWThreat uses).
    request : SendAddonMessage("TWT_UDTSv4_TM", "limit=N", "RAID"|"PARTY")
    reply   : CHAT_MSG_ADDON, message contains
              "TWTv4=player:tank:threat:perc:melee;..."       (current target)
     optionally .. "#TMTv1=creature:guid:holder:perc;..."      (per enemy)
  The feed only exists in a party or raid (server design, same as TWThreat).

  Zero OnUpdate work outside combat; one throttled request timer in combat;
  no per-frame table allocation on the parse path beyond the per-mob records.
----------------------------------------------------------------------------]]
if not Cursive.superwow then
	return
end

local GetTime = GetTime
local strfind = string.find
local strsub = string.sub
local strlen = string.len
local gfind = string.gfind
local strlower = string.lower
local tonumber = tonumber
local floor = math.floor

local THREAT_API = "TWTv4="
local TM_API = "TMTv1="
local REQUEST_MSG = "TWT_UDTSv4_TM"
local REQUEST_INTERVAL = 0.5   -- matches TWThreat tank cadence
local STALE_AFTER = 4          -- seconds without a packet -> stop coloring

local threat = {}
Cursive.threat = threat

-- Aggro palette (user spec; warrior forced red instead of class tan)
threat.palette = {
	warrior = { 0.90, 0.15, 0.15 },
	paladin = { 0.96, 0.55, 0.73 },
	hunter  = { 0.67, 0.83, 0.45 },
	rogue   = { 1.00, 0.96, 0.41 },
	priest  = { 0.95, 0.95, 0.95 },
	shaman  = { 0.00, 0.44, 0.87 },
	mage    = { 0.41, 0.80, 0.94 },
	warlock = { 0.58, 0.51, 0.79 },
	druid   = { 1.00, 0.49, 0.04 },
	unknown = { 0.55, 0.55, 0.55 },
}

threat.byGuid = {}       -- [guidKey] = { holder, perc, t }
threat.stats = { sent = 0, packets = 0, tm = 0, lastRaw = "" }
threat.debug = false
threat.target = {}       -- me-vs-target: { value, perc, holder, holderValue, t }
threat.lastPacket = 0

local roster = {}        -- [playerName] = lowercase class token
local playerName = nil

------------------------------------------------------------------------------
-- guid normalization: SuperWoW hands "0xF13...", the server feed may send
-- hex with/without 0x or decimal. Normalize everything to a number key.
------------------------------------------------------------------------------
-- NOTE: never convert 64-bit guids with tonumber -- Lua doubles only carry 53
-- mantissa bits, so 0x...AB12 and 0x...AB13 collapse to the SAME number.
-- Normalize as a string instead: strip 0x prefix, uppercase, strip leading 0s.
local gsub = string.gsub
local strupper = string.upper
local function guidKey(g)
	if g == nil then return nil end
	if type(g) ~= "string" then g = tostring(g) end
	g = strupper(g)
	g = gsub(g, "^0X", "")
	g = gsub(g, "^0+", "")
	if g == "" then return nil end
	return g
end

-- memoized wrapper for the hot bar-update path (bounded: Cursive caps live
-- guids at 60; cleared on every combat-end wipe)
local keyCache = {}
local function guidKeyCached(g)
	local hit = keyCache[g]
	if hit ~= nil then
		if hit == false then return nil end
		return hit
	end
	local k = guidKey(g)
	keyCache[g] = k or false
	return k
end
threat.guidKey = guidKey

------------------------------------------------------------------------------
-- roster class cache
------------------------------------------------------------------------------
local function rebuildRoster()
	local k
	for k in pairs(roster) do roster[k] = nil end
	playerName = UnitName("player")
	local _, pc = UnitClass("player")
	if playerName and pc then roster[playerName] = strlower(pc) end
	local i
	local nRaid = GetNumRaidMembers()
	if nRaid > 0 then
		for i = 1, nRaid do
			local n = UnitName("raid" .. i)
			local _, c = UnitClass("raid" .. i)
			if n and c then roster[n] = strlower(c) end
		end
	else
		for i = 1, GetNumPartyMembers() do
			local n = UnitName("party" .. i)
			local _, c = UnitClass("party" .. i)
			if n and c then roster[n] = strlower(c) end
		end
	end
end

function threat.classOf(name)
	return roster[name] or "unknown"
end

function threat.colorOf(name)
	return threat.palette[roster[name] or "unknown"]
end

------------------------------------------------------------------------------
-- packet parsing
------------------------------------------------------------------------------
local function parseTargetPart(part)
	-- player:tank:threat:perc:melee;...
	local me = playerName
	local topName, topVal = nil, -1
	local myVal, myPerc = nil, nil
	local entry
	for entry in gfind(part, "[^;]+") do
		local _, _, p, tank, th, pc = strfind(entry, "([^:]+):([^:]+):([^:]+):([^:]+)")
		if p then
			th = tonumber(th) or 0
			pc = tonumber(pc) or 0
			if th > topVal then
				topVal = th
				topName = p
			end
			if p == me then
				myVal = th
				myPerc = pc
			end
		end
	end
	threat.target.value = myVal
	threat.target.perc = myPerc
	threat.target.holder = topName
	threat.target.holderValue = (topVal >= 0) and topVal or nil
	threat.target.t = GetTime()
end

local function parseTankModePart(part)
	-- creature:guid:holder:perc;...
	local now = GetTime()
	local entry
	for entry in gfind(part, "[^;]+") do
		local _, _, creature, guid, holder, pc = strfind(entry, "([^:]+):([^:]+):([^:]+):([^:]+)")
		if creature and guid and holder and pc then
			threat.stats.tm = threat.stats.tm + 1
			-- primary key: normalized hex-style string. If the server ever sends
			-- decimal guids they can't be losslessly converted (53-bit doubles),
			-- but SuperWoW guids are hex "0x..." and TWThreat passes the same
			-- string through, so hex is the expected wire format.
			local key = guidKey(guid)
			if key then
				local rec = threat.byGuid[key]
				if rec == nil then
					rec = {}
					threat.byGuid[key] = rec
				end
				rec.holder = holder
				rec.perc = tonumber(pc) or 0
				rec.t = now
			end
		end
	end
end

local function handlePacket(msg)
	threat.lastPacket = GetTime()
	threat.stats.packets = threat.stats.packets + 1
	threat.stats.lastRaw = strsub(msg, 1, 160)
	if threat.debug then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CT|r pkt: " .. strsub(msg, 1, 120))
	end
	local hashPos = strfind(msg, "#", 1, true)
	local targetPart = msg
	if hashPos then
		targetPart = strsub(msg, 1, hashPos - 1)
		local tmPos = strfind(msg, TM_API, hashPos, true)
		if tmPos then
			parseTankModePart(strsub(msg, tmPos + strlen(TM_API)))
		end
	end
	local tPos = strfind(targetPart, THREAT_API, 1, true)
	if tPos then
		parseTargetPart(strsub(targetPart, tPos + strlen(THREAT_API)))
	end
end

------------------------------------------------------------------------------
-- bar-facing API
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- client-side aggro resolution (TankPlates method, SuperWoW required):
-- a guid chains like any unit token, so guid.."target" is whoever the mob is
-- attacking. Pets resolve to their owner via the "owner" suffix, so a
-- hunter pet tanking shows hunter green with the hunter's name.
-- Works everywhere, solo included -- no server packets involved.
------------------------------------------------------------------------------
local UnitExists = UnitExists
local UnitName = UnitName
local UnitClass = UnitClass
local UnitIsPlayer = UnitIsPlayer
local UnitAffectingCombat = UnitAffectingCombat

local RESOLVE_TTL = 0.2
local resolveCache = {}   -- [guid] = { t, holder, r, g, b }

local function resolveMobTarget(guid)
	local rec = resolveCache[guid]
	local now = GetTime()
	if rec and now - rec.t < RESOLVE_TTL then
		if rec.holder then return rec.holder, rec.r, rec.g, rec.b end
		return nil
	end
	if rec == nil then
		rec = {}
		resolveCache[guid] = rec
	end
	rec.t = now
	rec.holder = nil

	if not UnitAffectingCombat(guid) then return nil end
	local ok, tguid = UnitExists(guid .. "target")
	if not ok or not tguid then return nil end

	-- pet or guardian -> credit the owner
	if not UnitIsPlayer(tguid) then
		local ook, oguid = UnitExists(tguid .. "owner")
		if ook and oguid then tguid = oguid end
	end

	local name = UnitName(tguid)
	if not name then return nil end
	local _, cls = UnitClass(tguid)
	local col = threat.palette[cls and strlower(cls) or "unknown"] or threat.palette.unknown

	rec.holder = name
	rec.r = col[1]
	rec.g = col[2]
	rec.b = col[3]
	return name, col[1], col[2], col[3]
end

-- returns holder, perc, r, g, b  (or nil when no data)
-- priority: server TM record (exact %) > live mob-target resolution (no %)
function threat.get(guid)
	local key = guidKeyCached(guid)
	if key ~= nil then
		local rec = threat.byGuid[key]
		if rec and GetTime() - rec.t <= STALE_AFTER then
			local col = threat.palette[roster[rec.holder] or "unknown"]
			return rec.holder, rec.perc, col[1], col[2], col[3]
		end
	end
	local holder, r, g, b = resolveMobTarget(guid)
	if holder then
		return holder, nil, r, g, b
	end
	return nil
end

-- holder of aggro on the CURRENT TARGET from the base (non-TM) packet.
-- Fallback when the server has no _TM handler: at least the target bar
-- gets its holder name, percent, and class color.
function threat.getTargetFallback()
	if threat.target.t and GetTime() - threat.target.t <= STALE_AFTER then
		local holder = threat.target.holder
		if holder then
			local col = threat.palette[roster[holder] or "unknown"]
			return holder, threat.target.perc, col[1], col[2], col[3]
		end
	end
	return nil
end

-- my raw threat value vs current target, nil when stale/absent
function threat.myTargetValue()
	if threat.target.t and GetTime() - threat.target.t <= STALE_AFTER then
		return threat.target.value, threat.target.perc
	end
	return nil
end

function threat.fmtValue(v)
	if v == nil then return "" end
	if v >= 1000000 then
		return floor(v / 100000) / 10 .. "m"
	elseif v >= 10000 then
		return floor(v / 1000) .. "k"
	elseif v >= 1000 then
		return floor(v / 100) / 10 .. "k"
	end
	return floor(v)
end

------------------------------------------------------------------------------
-- request loop + events (no OnUpdate outside combat: the requester frame is
-- shown on PLAYER_REGEN_DISABLED and hidden on PLAYER_REGEN_ENABLED)
------------------------------------------------------------------------------
function threat.statusLine()
	local n = 0
	local k
	for k in pairs(threat.byGuid) do n = n + 1 end
	local age = "never"
	if threat.lastPacket > 0 then
		age = floor((GetTime() - threat.lastPacket) * 10) / 10 .. "s ago"
	end
	local rc = 0
	for k in pairs(resolveCache) do rc = rc + 1 end
	return "sent " .. threat.stats.sent .. " | packets " .. threat.stats.packets ..
		" (last " .. age .. ") | TM " .. threat.stats.tm ..
		" | server mobs " .. n .. " | client-resolved mobs " .. rc
end

local requester = CreateFrame("Frame", "CursiveThreatRequester", UIParent)
requester:Hide()

requester:SetScript("OnUpdate", function()
	if (this.tick or 0) > GetTime() then return end
	this.tick = GetTime() + REQUEST_INTERVAL

	local p = Cursive.db and Cursive.db.profile
	if p and p.threatenabled == false then return end

	local channel
	if GetNumRaidMembers() > 0 then
		channel = "RAID"
	elseif GetNumPartyMembers() > 0 then
		channel = "PARTY"
	else
		return -- server feed needs a group, same as TWThreat
	end

	-- server answers for the current target; TM part covers everything on us.
	-- Ask BOTH ways: plain UDTSv4 is the request every TWThreat user exercises
	-- (tank mode is opt-in there), _TM adds per-creature data where the server
	-- fork supports it. If _TM is unimplemented the plain reply still feeds
	-- the target bar.
	if UnitExists("target") and UnitAffectingCombat("target") and not UnitIsPlayer("target") then
		SendAddonMessage("TWT_UDTSv4", "limit=7", channel)
		SendAddonMessage(REQUEST_MSG, "limit=7", channel)
		threat.stats.sent = threat.stats.sent + 2
		if threat.debug then
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CT|r req -> " .. channel)
		end
	end
end)

local ev = CreateFrame("Frame", "CursiveThreatEvents", UIParent)
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
ev:RegisterEvent("RAID_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")

local function wipeThreat()
	local k
	for k in pairs(threat.byGuid) do threat.byGuid[k] = nil end
	for k in pairs(keyCache) do keyCache[k] = nil end
	for k in pairs(resolveCache) do resolveCache[k] = nil end
	threat.target.value = nil
	threat.target.perc = nil
	threat.target.holder = nil
	threat.target.holderValue = nil
	threat.target.t = nil
end

ev:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg2 and strfind(arg2, THREAT_API, 1, true) then
			handlePacket(arg2)
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		requester.tick = 0
		requester:Show()
	elseif event == "PLAYER_REGEN_ENABLED" then
		requester:Hide()
		wipeThreat()
	else
		rebuildRoster()
		if event == "PLAYER_ENTERING_WORLD" then
			wipeThreat()
			if UnitAffectingCombat("player") then
				requester:Show()
			else
				requester:Hide()
			end
		end
	end
end)
