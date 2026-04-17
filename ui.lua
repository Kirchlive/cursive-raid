if not Cursive.superwow then
	return
end

local L = AceLibrary("AceLocale-2.2"):new("Cursive")

local utils = Cursive.utils
local filter = Cursive.filter

-- Layout constant: reserved height for (hidden) title bar area
local TITLE_BAR_HEIGHT = 12

-- Local-cache frequently used globals (avoids repeated global table lookups in hot paths)
local GetTime = GetTime
local _RealUnitExists = UnitExists
local _RealUnitHealth = UnitHealth
local _RealUnitHealthMax = UnitHealthMax
local _RealUnitName = UnitName
local _RealUnitIsDead = UnitIsDead
local _RealUnitIsVisible = UnitIsVisible
local _RealUnitAffectingCombat = UnitAffectingCombat
local _RealGetRaidTargetIndex = GetRaidTargetIndex

-- v3.2.1: Test Overlay wrappers — intercept calls for fake GUIDs
-- v3.2.1: Test Overlay wrappers — intercept ALL calls for fake GUIDs (never fall through to real API)
local TEST_PREFIX = "CURSIVE_TEST_"
local function IsTestGuid(guid)
    if not guid then return false end
    return string.find(guid, TEST_PREFIX, 1, true) == 1
end

local function UnitExists(guid)
    if IsTestGuid(guid) then
        return CursiveTestOverlay_UnitExists(guid)
    end
    return _RealUnitExists(guid)
end
local function UnitHealth(guid)
    if IsTestGuid(guid) then
        return CursiveTestOverlay_UnitHealth(guid) or 0
    end
    return _RealUnitHealth(guid)
end
local function UnitHealthMax(guid)
    if IsTestGuid(guid) then
        return CursiveTestOverlay_UnitHealthMax(guid) or 1
    end
    return _RealUnitHealthMax(guid)
end
local function UnitName(guid)
    if IsTestGuid(guid) then
        return CursiveTestOverlay_UnitName(guid)
    end
    return _RealUnitName(guid)
end
local function UnitIsDead(guid)
    if IsTestGuid(guid) then
        return false
    end
    return _RealUnitIsDead(guid)
end
local function UnitIsVisible(guid)
    if IsTestGuid(guid) then
        return true
    end
    return _RealUnitIsVisible(guid)
end
local function UnitAffectingCombat(guid)
    if IsTestGuid(guid) then
        return true
    end
    return _RealUnitAffectingCombat(guid)
end
local function GetRaidTargetIndex(guid)
    if IsTestGuid(guid) then
        return CursiveTestOverlay_GetRaidTargetIndex(guid)
    end
    return _RealGetRaidTargetIndex(guid)
end

local _RealUnitIsPlayer = UnitIsPlayer
local function UnitIsPlayer(guid)
    if IsTestGuid(guid) then
        return false  -- Test units are NPCs, not players
    end
    return _RealUnitIsPlayer(guid)
end

local UnitIsUnit = UnitIsUnit
local UnitDebuff = UnitDebuff
local UnitBuff = UnitBuff
local UnitClass = UnitClass
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local pairs = pairs
local ipairs = ipairs
local floor = math.floor
local tinsert = table.insert
local tsort = table.sort
local getn = table.getn

local ui = CreateFrame("Frame", "CursiveUI", UIParent)

ui.border = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

ui.background = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true, tileSize = 16, edgeSize = 8,
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

ui.rootBarFrame = nil
ui.targetIndicatorSize = 8
ui.padding = 1  -- default, overridden by config.debufficonspacing in UpdateFramesFromConfig

ui.row = 1
ui.col = 1
ui.maxBarsDisplayed = false
ui.numDisplayed = 0

local function GetBarFirstSectionWidth()
	local config = Cursive.db.profile

	local size = 1
	if config.showraidicons then
		size = size + config.raidiconsize
	end
	if config.showtargetindicator then
		size = size + ui.targetIndicatorSize
	end
	if size > 0 then
		size = size + ui.padding
	end

	return size
end

local function GetBarSecondSectionWidth()
	local config = Cursive.db.profile

	if config.showhealthbar == false and config.showunitname == false then
		return 1
	end

	return config.healthwidth + ui.padding
end

local function GetBarThirdSectionWidth()
	local config = Cursive.db.profile
	return config.maxcurses * (config.curseiconsize + ui.padding)
end

local function GetBarOtherSideSectionWidth()
	local config = Cursive.db.profile
	if config.orderotherside == "none" then
		return 0
	end
	return config.maxcurses * (config.curseiconsize + ui.padding)
end

local function GetBarWidth()
	-- Other Side section is anchored opposite to the main bar — it does NOT add to the main width
	return GetBarFirstSectionWidth() +
			GetBarSecondSectionWidth() +
			GetBarThirdSectionWidth()
end

local function UpdateRootBarFrame()
	local config = Cursive.db.profile

	if config.showbackdrop then
		ui.rootBarFrame:SetBackdrop(ui.background)
	else
		ui.rootBarFrame:SetBackdrop(nil)
	end

	ui.rootBarFrame:EnableMouse(not config.clickthrough)

	ui.rootBarFrame.pos = config.anchor .. config.x .. config.y .. config.scale
	ui.rootBarFrame:ClearAllPoints()
	ui.rootBarFrame:SetPoint(config.anchor, config.x, config.y)

	ui.rootBarFrame:SetScale(config.scale)
	ui.rootBarFrame:SetAlpha(config.opacity or 1)

	ui.rootBarFrame.caption:SetFont(STANDARD_TEXT_FONT, Cursive.db.profile.textsize, "THINOUTLINE")
	ui.rootBarFrame.caption:SetText(Cursive.db.profile.caption)
	-- Title bar permanently hidden (v3.2.2)
	ui.rootBarFrame.caption:Hide()

	ui.rootBarFrame:SetWidth(config.maxcol * GetBarWidth())
	-- Calculate height: title area + all rows + extra spacing
	local title_size = TITLE_BAR_HEIGHT + config.spacing
	local total_height = title_size + (config.maxrow * (config.height + config.spacing)) + config.spacing
	ui.rootBarFrame:SetHeight(total_height)
end

local function CreateRoot()
	local frame = CreateFrame("Frame", Cursive.db.profile.caption, UIParent)
	ui.rootBarFrame = frame

	frame.id = Cursive.db.profile.caption

	frame:RegisterForDrag("LeftButton")
	frame:SetMovable(true)

	frame:SetScript("OnDragStart", function()
		this.lock = true
		this:StartMoving()
	end)

	frame:SetScript("OnDragStop", function()
		-- convert to best anchor depending on position
		local new_anchor = utils.GetBestAnchor(this)
		local anchor, x, y = utils.ConvertFrameAnchor(this, new_anchor)
		this:ClearAllPoints()
		this:SetPoint(anchor, UIParent, anchor, x, y)

		-- save new position
		anchor, _, _, x, y = this:GetPoint()
		Cursive.db.profile.anchor, Cursive.db.profile.x, Cursive.db.profile.y = anchor, x, y

		-- stop drag
		this:StopMovingOrSizing()
		this.lock = false

		this:ClearAllPoints()
		this:SetPoint(anchor, x, y)
	end)

	-- create title text
	frame.caption = frame:CreateFontString(nil, "HIGH", "GameFontWhite")
	frame.caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -2)
	frame.caption:SetTextColor(1, 1, 1, 1)

	UpdateRootBarFrame()

	frame:Show()

	return frame
end

ui.unitFrames = {} -- holds all unitFrames for all columns/rows

Cursive.UpdateFramesFromConfig = function()
	-- Update icon spacing from config
	ui.padding = Cursive.db.profile.debufficonspacing or 1

	for col, rows in pairs(ui.unitFrames) do
		for row, unitFrame in pairs(rows) do
			if unitFrame and unitFrame:IsShown() then
				unitFrame:Hide()
			end
		end
	end

	if ui.rootBarFrame then
		UpdateRootBarFrame()
	end

	-- after 3 seconds reset the unit frames so all changes are applied
	Cursive:ScheduleEvent("resetUnitFrames", Cursive.ResetUnitFrames, 3)
end

Cursive.ResetUnitFrames = function()
	-- hide all existing unit frames and clear guid associations
	for col, rows in pairs(ui.unitFrames) do
		for row, unitFrame in pairs(rows) do
			if unitFrame then
				unitFrame:Hide()
				unitFrame.guid = nil
			end
		end
	end
	-- v4.0.4: Keep frame objects for reuse (avoid orphans)
	-- ui.unitFrames = {} -- REMOVED: causes frame orphans

	-- Reapply opacity after frame rebuild
	if ui.rootBarFrame then
		ui.rootBarFrame:SetAlpha(Cursive.db.profile.opacity or 1)
	end
end

ui.BarEnter = function()
	this.parent.hover = true

	-- v3.2.1: Custom tooltip for test overlay GUIDs
	if IsTestGuid(this.parent.guid) then
		GameTooltip_SetDefaultAnchor(GameTooltip, this)
		local tData = CursiveTestOverlay_UnitName and CursiveTestOverlay_UnitName(this.parent.guid)
		local hp = CursiveTestOverlay_UnitHealth and CursiveTestOverlay_UnitHealth(this.parent.guid) or 0
		local maxHp = CursiveTestOverlay_UnitHealthMax and CursiveTestOverlay_UnitHealthMax(this.parent.guid) or 1
		GameTooltip:ClearLines()
		GameTooltip:AddLine(tData or "Test Target", 1, 0.2, 0.2)
		GameTooltip:AddLine("|cFFAAAAAA[Test Overlay]|r", 0.7, 0.7, 0.7)
		GameTooltip:Show()
		return
	end

	GameTooltip_SetDefaultAnchor(GameTooltip, this)
	GameTooltip:SetUnit(this.parent.guid)
	GameTooltip:Show()
end

ui.BarLeave = function()
	this.parent.hover = false
	GameTooltip:Hide()
end

-- Format armor values with k/m suffix (hoisted to file scope to avoid per-frame closure allocation)
local function FormatArmor(v)
	local n = tonumber(v) or 0
	local absN = math.abs(n)
	local prefix = ""
	if n < 0 then prefix = "-" end
	if absN >= 1000000 then
		return prefix .. floor(absN / 1000000) .. "m"
	elseif absN >= 10000 then
		return prefix .. floor(absN / 1000) .. "k"
	end
	return v
end

ui.BarUpdate = function()
	if not this.guid or this.guid == 0 then
		this:Hide()
		return
	end

	if (this.tick or 1) > GetTime() then
		return
	else
		this.tick = GetTime() + 0.05
	end

	-- update statusbar values if it exists
	if this.healthBar then
		this.healthBar:SetMinMaxValues(0, UnitHealthMax(this.guid))
		this.healthBar:SetValue(UnitHealth(this.guid))

		-- update health bar color
		local hex, r, g, b, a = utils.GetUnitColor(this.guid)
		this.healthBar:SetStatusBarColor(r, g, b, a)

		-- update health bar border
		if this.healthBar.border then
			local isTargeted = not IsTestGuid(this.guid) and UnitIsUnit("target", this.guid)

			if isTargeted then
				-- White for current target only
				this.healthBar.border:SetBackdropBorderColor(1, 1, 1, 1)
			else
				-- Black default
				this.healthBar.border:SetBackdropBorderColor(0, 0, 0, 1)
			end
		end

		-- update hover glow effect
		if this.hoverGlow then
			if this.hover then
				-- Show all 4 glow edges
				for _, glow in ipairs(this.hoverGlow) do
					glow:Show()
				end
			else
				-- Hide all 4 glow edges
				for _, glow in ipairs(this.hoverGlow) do
					glow:Hide()
				end
			end
		end
	end

	-- v4.0.5: Out-of-range / line-of-sight stripe indicator
	-- v4.0.6: Throttled to 500ms per GUID (range is cached in filter.lua, LOS cached here)
	-- v4.1.1 FIX (Bug #2): UnitXP("inSight", ...) returns a BOOLEAN (true/false),
	-- not a number. The previous check `los == 0` was never true — LoS-blocked
	-- targets returned `false` which does not equal 0, so `inSight` stayed true
	-- forever. Live-verified via ClaudeBridge on 2026-04-17: subcommand is
	-- "inSight" (lowercase i), return type is boolean. Correct check: `los == false`.
	-- Additionally: decouple LoS from inRange. A target behind a wall IN range should
	-- still show as LoS-blocked (stripes). TestOverlay override runs before UnitXP.
	if this.oorFrame then
		if Cursive.db.profile.oorstripes then
			-- LOS check throttled independently per bar
			if not this._oorTick or this._oorTick < GetTime() then
				this._oorTick = GetTime() + 0.25
				local inRange = Cursive.filter.range(this.guid)
				local inSight = true
				-- v4.1.1: TestOverlay LoS override (nil = no override, real API runs)
				if CursiveTestOverlay_IsBlockedLoS and CursiveTestOverlay_IsBlockedLoS(this.guid) then
					inSight = false
				elseif UnitXP then
					local ok, los = pcall(UnitXP, "inSight", "player", this.guid)
					if ok and los == false then inSight = false end
				end
				this._oorCached = inRange and inSight
			end
			if this._oorCached then
				this.oorFrame:Hide()
			else
				this.oorFrame:Show()
			end
		else
			this.oorFrame:Hide()
		end
	end

	-- update caption text
	local name = UnitName(this.guid)
	if name and this.nameText then
		this.nameText:SetText(name)
	end

	if this.hpText then
		local hp = UnitHealth(this.guid)
		if GetLocale() == "zhCN" then
			if hp then
				if hp >= 10000 then
					hp = floor(hp / 1000) / 10 .. "万"
					-- elseif hp >= 1000 then
					-- 	hp = floor(hp / 100) / 10 .. "k"
				end
			end
		else
			-- convert hp: millions → "110m", thousands → "440k", rest → raw number
			if hp then
				if hp >= 1000000 then
					hp = floor(hp / 1000000) .. "m"
				elseif hp >= 10000 then
					hp = floor(hp / 1000) .. "k"
				end
			end
		end

		if hp then
			local hpStr = tostring(hp)
			if this.hpText._lastVal ~= hpStr then
				this.hpText._lastVal = hpStr
				this.hpText:SetText(hpStr)
			end
		end
	end

	-- show raid icon if existing
	if this.icon then
		if GetRaidTargetIndex(this.guid) and Cursive.filter.alive(this.guid) then
			SetRaidTargetIconTexture(this.icon, GetRaidTargetIndex(this.guid))
			this.icon:Show()
		else
			this.icon:Hide()
		end
	end

	-- v3.2.1: Update armor display (NPCs only, not players)
	if this.armorFrame and Cursive.db.profile.armorStatusEnabled then
		local curses = Cursive.curses
		if curses and not UnitIsPlayer(this.guid) then
			curses:UpdateArmorCache(this.guid)
			local live, total, removed = curses:GetArmorData(this.guid)
			if live then
				local config = Cursive.db.profile
				local structure = config.armorDisplayStructure or "live+removed"
				local val1, val2

				-- Determine which values to show
				if structure == "live+total" then
					val1 = tostring(live)
					val2 = tostring(total)
				elseif structure == "live+removed" then
					val1 = tostring(removed)
					val2 = tostring(live)
				elseif structure == "total+removed" then
					val1 = tostring(removed)
					val2 = tostring(total)
				elseif structure == "live" then
					val1 = tostring(live)
					val2 = nil
				elseif structure == "total" then
					val1 = tostring(total)
					val2 = nil
				elseif structure == "removed" then
					val1 = tostring(removed)
					val2 = nil
				end

				local iconPos = config.armorShowIcon or "left"

				-- Determine color for live value (based on thirds of total)
				local liveR, liveG, liveB = 1, 1, 1
				if config.armorColorIndicator and total > 0 then
					local ratio = live / total
					if ratio > 0.66 then
						liveR, liveG, liveB = 0.2, 1.0, 0.2   -- green (high armor)
					elseif ratio > 0.33 then
						liveR, liveG, liveB = 1.0, 1.0, 0.2   -- yellow (medium)
					else
						liveR, liveG, liveB = 1.0, 0.2, 0.2   -- red (low armor)
					end
				end

				-- Format and assign text — Live colored, Total and "/" always white
				local fVal1 = FormatArmor(val1)
				local fVal2 = val2 and FormatArmor(val2) or nil

				this.armorText1:SetText(fVal1)
				if fVal2 then
					if this.armorSep then
						this.armorSep:SetText("/")
						this.armorSep:Show()
					end
					this.armorText2:SetText(fVal2)
					this.armorText2:Show()
				else
					if this.armorSep then this.armorSep:Hide() end
					this.armorText2:SetText("")
					this.armorText2:Hide()
				end

				-- Color: Live value gets colored, everything else white
				if structure == "live+total" or structure == "live" then
					this.armorText1:SetTextColor(liveR, liveG, liveB)
					this.armorText2:SetTextColor(1, 1, 1)
				elseif structure == "live+removed" or structure == "total+removed" then
					-- Live/Total is val2 in these reversed structures
					this.armorText1:SetTextColor(1, 1, 1)
					if structure == "live+removed" then
						this.armorText2:SetTextColor(liveR, liveG, liveB)
					else
						this.armorText2:SetTextColor(1, 1, 1)
					end
				else
					this.armorText1:SetTextColor(1, 1, 1)
					this.armorText2:SetTextColor(1, 1, 1)
				end

				if this.armorIcon then
					if config.armorShowIcon ~= "none" then
						this.armorIcon:Show()
					else
						this.armorIcon:Hide()
					end
				end
				this.armorFrame:Show()
			else
				this.armorFrame:Hide()
			end
		else
			-- Player target or no curses module — hide armor
			this.armorFrame:Hide()
		end
	end

	-- update target indicator
	if this.target_left then
		if not IsTestGuid(this.guid) and UnitIsUnit("target", this.guid) then
			this.target_left:Show()
		else
			this.target_left:Hide()
		end
	end
end

ui.BarClick = function()
	-- v3.2.1: Block targeting for test overlay GUIDs
	if IsTestGuid(this.parent.guid) then return end
	if arg1 == "LeftButton" then
		TargetUnit(this.parent.guid)
	elseif arg1 == "RightButton" then
		TargetUnit(this.parent.guid)
		if (not PlayerFrame.inCombat) then
			AttackTarget()
		end
	end
end

-- ============================================================
-- v3.2: Debuff icon border helpers
-- ============================================================
local BORDER_COLORS = {
    ownclass    = { 0, 0.8, 0 },      -- green
    ownraid     = { 0.8, 0, 0 },      -- red
    otherclass  = { 0, 0.4, 0.8 },    -- blue
    otherraid   = { 0.6, 0, 0.8 },    -- purple
}

-- Class colors for border coloring (matches CursiveOptionsUI CLASS_COLORS)
-- Class colors at 0.9 for timer text — OUTLINE provides dark edge
local TIMER_CLASS_COLORS = {
    Warrior  = { 0.70, 0.55, 0.39 },
    Rogue    = { 0.90, 0.86, 0.37 },
    Hunter   = { 0.60, 0.75, 0.41 },
    Mage     = { 0.37, 0.72, 0.85 },
    Warlock  = { 0.52, 0.46, 0.71 },
    Priest   = { 0.90, 0.90, 0.90 },
    Druid    = { 0.90, 0.44, 0.04 },
    Shaman   = { 0.00, 0.40, 0.78 },
    Paladin  = { 0.86, 0.50, 0.66 },
    Item     = { 0.45, 0.45, 0.45 },
}

-- Class colors darkened (~70%) for thin borders — standard colors wash out on 1-2px lines
local BORDER_CLASS_COLORS = {
    Warrior  = { 0.55, 0.43, 0.30 },
    Rogue    = { 0.70, 0.67, 0.29 },
    Hunter   = { 0.47, 0.58, 0.32 },
    Mage     = { 0.29, 0.56, 0.66 },
    Warlock  = { 0.41, 0.36, 0.55 },
    Priest   = { 0.70, 0.70, 0.70 },
    Druid    = { 0.70, 0.34, 0.03 },
    Shaman   = { 0.00, 0.31, 0.61 },
    Paladin  = { 0.67, 0.39, 0.51 },
    Item     = { 0.30, 0.30, 0.30 },
}

-- Creates border textures on borderFrame itself.
-- Uses OVERLAY layer so they render over the icon but under FontStrings on parent.
local function CreateDebuffBorder(borderFrame)
    local border = {}
    
    border.top = borderFrame:CreateTexture(nil, "OVERLAY")
    border.top:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
    local bw = (Cursive.db and Cursive.db.profile and Cursive.db.profile.borderwidth) or 2
    border.top:SetHeight(bw)
    border.top:SetTexture(1, 1, 1, 1)
    border.top:Hide()
    
    border.bottom = borderFrame:CreateTexture(nil, "OVERLAY")
    border.bottom:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(bw)
    border.bottom:SetTexture(1, 1, 1, 1)
    border.bottom:Hide()
    
    border.left = borderFrame:CreateTexture(nil, "OVERLAY")
    border.left:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(bw)
    border.left:SetTexture(1, 1, 1, 1)
    border.left:Hide()
    
    border.right = borderFrame:CreateTexture(nil, "OVERLAY")
    border.right:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(bw)
    border.right:SetTexture(1, 1, 1, 1)
    border.right:Hide()
    
    return border
end

local function SetBorderColor(border, r, g, b)
    local alpha = 0.85
    if Cursive.db and Cursive.db.profile and Cursive.db.profile.borderopacity then
        alpha = Cursive.db.profile.borderopacity / 100
    end
    border.top:SetVertexColor(r, g, b, alpha)
    border.bottom:SetVertexColor(r, g, b, alpha)
    border.left:SetVertexColor(r, g, b, alpha)
    border.right:SetVertexColor(r, g, b, alpha)
    border.top:Show()
    border.bottom:Show()
    border.left:Show()
    border.right:Show()
end

local function HideBorder(border)
    if border then
        border.top:Hide()
        border.bottom:Hide()
        border.left:Hide()
        border.right:Hide()
    end
end

-- Determine border color for a debuff icon based on config and curse data
-- Returns r,g,b or nil if no border should be shown
-- Determine class color for timer text based on debuff source class
local function GetTimerClassColor(curseData)
    if not curseData then return nil end

    local debuffClass = nil

    -- Try shared debuff metadata (spellID → debuffKey → class)
    if curseData.spellID and Cursive.curses and Cursive.curses.sharedDebuffSpellLookup then
        local debuffKey = Cursive.curses.sharedDebuffSpellLookup[curseData.spellID]
        if debuffKey and Cursive.curses.sharedDebuffMeta[debuffKey] then
            debuffClass = Cursive.curses.sharedDebuffMeta[debuffKey].class
        end
    end

    -- Fallback for own debuffs not in shared debuffs: use player class
    if not debuffClass and curseData.currentPlayer then
        local _, playerClass = UnitClass("player")
        if playerClass then
            debuffClass = string.lower(playerClass)
        end
    end

    if debuffClass then
        local classKey = string.upper(string.sub(debuffClass, 1, 1)) .. string.sub(debuffClass, 2)
        local cc = TIMER_CLASS_COLORS[classKey]
        if cc then
            return cc[1], cc[2], cc[3]
        end
    end
    return nil
end

-- Hoisted helpers for GetDebuffBorderColor (avoids per-call closure allocation)
local function ResolveBorderMode(val)
    if val == true then return "green" end
    if not val or val == false or val == "off" then return "off" end
    return val
end

local function ResolveBorderColor(mode, curseData)
    if mode == "green" then return 0, 0.8, 0 end
    if mode == "red" then return 0.8, 0, 0 end
    if mode == "black" then return 0.1, 0.1, 0.1 end
    if mode == "classcolor" then
        local debuffClass = nil
        if curseData.spellID and Cursive.curses and Cursive.curses.sharedDebuffSpellLookup then
            local debuffKey = Cursive.curses.sharedDebuffSpellLookup[curseData.spellID]
            if debuffKey and Cursive.curses.sharedDebuffMeta[debuffKey] then
                debuffClass = Cursive.curses.sharedDebuffMeta[debuffKey].class
            end
        end
        if not debuffClass then
            local _, playerClass = UnitClass("player")
            if playerClass then debuffClass = string.lower(playerClass) end
        end
        if debuffClass then
            local classKey = string.upper(string.sub(debuffClass, 1, 1)) .. string.sub(debuffClass, 2)
            local cc = BORDER_CLASS_COLORS[classKey]
            if cc then return cc[1], cc[2], cc[3] end
        end
        return 0, 0.8, 0  -- fallback green
    end
    return nil
end

local function GetDebuffBorderColor(curseData, curseName, guid)
    if not curseData or not curseName then return nil end
    local config = Cursive.db.profile
    if not config then return nil end

    local ownclassMode = ResolveBorderMode(config.borderownclass)
    local ownraidMode = ResolveBorderMode(config.borderownraid)
    local otherclassMode = ResolveBorderMode(config.borderotherclass)
    local otherraidMode = ResolveBorderMode(config.borderotherraid)

    -- Fast exit if all borders are off
    if ownclassMode == "off" and ownraidMode == "off" and otherclassMode == "off" and otherraidMode == "off" then
        return nil
    end

    -- Normalize curseName: "winter's chill" → "winterschill" to match shareddebuffs keys
    local normalized = Cursive.curses.nameToNormalized[curseName] or string.gsub(string.lower(curseName), "[%s']", "")

    -- Determine ownership: currentPlayer for personal tracking, playerOwnedCasts for shared debuffs
    local isOwn = (curseData.currentPlayer == true)
    if not isOwn and guid and Cursive.curses and Cursive.curses.playerOwnedCasts then
        local ownCasts = Cursive.curses.playerOwnedCasts[guid]
        if ownCasts and ownCasts[normalized] then
            local castTime = ownCasts[normalized]
            if (GetTime() - castTime) < 600 then
                isOwn = true
            end
        end
    end

    -- Determine if this is a raid debuff (exists in shareddebuffs config)
    local isRaid = false
    local sd = config.shareddebuffs
    if sd then
        if sd[normalized] ~= nil then
            isRaid = true
        elseif curseData.sharedDebuffKey and sd[curseData.sharedDebuffKey] ~= nil then
            isRaid = true
        end
    end

    -- Resolve border color based on ownership + raid status
    local mode = "off"
    if isOwn and isRaid then
        mode = ownraidMode
    elseif isOwn and (not isRaid) then
        mode = ownclassMode
    elseif (not isOwn) and isRaid then
        mode = otherraidMode
    elseif (not isOwn) and (not isRaid) then
        mode = otherclassMode
    end

    if mode ~= "off" then
        return ResolveBorderColor(mode, curseData)
    end

    return nil
end

-- v3.2.1: Create armor display elements (shield icon + text)
local function CreateArmorDisplay(unitFrame, parentSection, config)
	local armorFrame = CreateFrame("Frame", nil, parentSection)
	armorFrame:SetHeight(config.height)
	armorFrame:SetWidth(80)  -- will auto-adjust with text
	armorFrame:EnableMouse(false)

	-- Position: stored on frame for later anchoring (needs unitFrame.icon reference)
	armorFrame._position = config.armorPosition
	armorFrame._invertbars = config.invertbars

	-- Shield icon
	local shieldIcon = armorFrame:CreateTexture(nil, "OVERLAY")
	shieldIcon:SetWidth(config.height - 2)
	shieldIcon:SetHeight(config.height - 2)
	shieldIcon:SetTexture("Interface\\Icons\\INV_Shield_06")
	shieldIcon:SetTexCoord(0.05, 0.82, 0.05, 0.82)
	unitFrame.armorIcon = shieldIcon

	-- Armor text (primary value — fixed width, right-aligned for column alignment)
	local fontSize = floor((config.armorTextSize or config.textsize or 10) * (config.fontscale or 1) + 0.5)

	local armorText1 = armorFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
	armorText1:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
	armorText1:SetJustifyH("RIGHT")
	armorText1:SetWidth(36)  -- fixed width for consistent "/" alignment
	unitFrame.armorText1 = armorText1

	-- Separator "/"
	local armorSep = armorFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
	armorSep:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
	armorSep:SetJustifyH("CENTER")
	armorSep:SetTextColor(1, 1, 1)
	armorSep:SetWidth(10)
	unitFrame.armorSep = armorSep

	-- Armor text (secondary value — left-aligned)
	local armorText2 = armorFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
	armorText2:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
	armorText2:SetJustifyH("LEFT")
	armorText2:SetWidth(36)
	unitFrame.armorText2 = armorText2

	-- Position icon + text based on armorShowIcon setting
	local iconPos = config.armorShowIcon or "left"
	if iconPos == "none" then
		shieldIcon:Hide()
		armorText1:SetPoint("LEFT", armorFrame, "LEFT", -3, 0)
		armorSep:SetPoint("LEFT", armorText1, "RIGHT", 0, 0)
		armorText2:SetPoint("LEFT", armorSep, "RIGHT", 0, 0)
	elseif iconPos == "left" then
		shieldIcon:SetPoint("LEFT", armorFrame, "LEFT", -3, 0)
		armorText1:SetPoint("LEFT", shieldIcon, "RIGHT", -3, 0)
		armorSep:SetPoint("LEFT", armorText1, "RIGHT", 0, 0)
		armorText2:SetPoint("LEFT", armorSep, "RIGHT", 0, 0)
	elseif iconPos == "center" then
		armorText1:SetPoint("LEFT", armorFrame, "LEFT", -3, 0)
		shieldIcon:SetPoint("LEFT", armorText1, "RIGHT", 3, 0)
		armorText2:SetPoint("LEFT", shieldIcon, "RIGHT", 3, 0)
		armorSep:Hide()  -- icon replaces separator
	elseif iconPos == "right" then
		armorText1:SetPoint("LEFT", armorFrame, "LEFT", -3, 0)
		armorSep:SetPoint("LEFT", armorText1, "RIGHT", 0, 0)
		armorText2:SetPoint("LEFT", armorSep, "RIGHT", 0, 0)
		shieldIcon:SetPoint("LEFT", armorText2, "RIGHT", -4, 0)  -- 4px gap to text (was 0)
	end

	armorFrame:Hide()
	unitFrame.armorFrame = armorFrame
end

local function CreateBarFirstSection(unitFrame, guid)
	local config = Cursive.db.profile
	local firstSection = CreateFrame("Frame", "Cursive1stSection", unitFrame)

	if config.invertbars then
		-- When inverted, position relative to second section (rightmost)
		firstSection:SetPoint("LEFT", unitFrame.secondSection, "RIGHT", 0, 0)
	else
		-- Normal positioning (leftmost)
		firstSection:SetPoint("LEFT", unitFrame, "LEFT", 0, 0)
	end

	firstSection:SetWidth(GetBarFirstSectionWidth())
	firstSection:SetHeight(config.height)
	firstSection:EnableMouse(false)
	unitFrame.firstSection = firstSection

	-- create target indicator
	if config.showtargetindicator then
		local targetLeft = firstSection:CreateTexture(nil, "OVERLAY")
		targetLeft:SetWidth(ui.targetIndicatorSize)
		targetLeft:SetHeight(8)
		if config.invertbars then
			targetLeft:SetPoint("RIGHT", firstSection, "RIGHT", 0, 0)
			targetLeft:SetTexture("Interface\\AddOns\\Cursive\\img\\target-right")
		else
			targetLeft:SetPoint("LEFT", unitFrame, "LEFT", 0, 0)
			targetLeft:SetTexture("Interface\\AddOns\\Cursive\\img\\target-left")
		end
		targetLeft:Hide()
		unitFrame.target_left = targetLeft
	end

	-- create raid icon textures
	if config.showraidicons then
		local icon = firstSection:CreateTexture(nil, "OVERLAY")
		icon:SetWidth(config.raidiconsize)
		icon:SetHeight(config.raidiconsize)
		if config.invertbars then
			icon:SetPoint("LEFT", firstSection, "LEFT", 2, 0)
		else
			icon:SetPoint("RIGHT", firstSection, "RIGHT", -2, 0)
		end
		icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		icon:Hide()
		unitFrame.icon = icon
	end

	-- v3.2.1: Create armor display elements (position "default" = near raid icon)
	if config.armorStatusEnabled and config.armorPosition == "default" then
		CreateArmorDisplay(unitFrame, firstSection, config)
		-- Anchor armor frame relative to raid icon or health bar
		if unitFrame.armorFrame then
			unitFrame.armorFrame:ClearAllPoints()
			local gap = 21  -- 3px base + 18px extra spacing
			local xOff = config.armorPositionOffset or 0
			if unitFrame.icon and config.showraidicons then
				-- Raid icon visible: anchor to icon
				if config.invertbars then
					unitFrame.armorFrame:SetPoint("LEFT", unitFrame.icon, "RIGHT", gap + xOff, 0)
				else
					unitFrame.armorFrame:SetPoint("RIGHT", unitFrame.icon, "LEFT", -gap + xOff, 0)
				end
			else
				-- No raid icon: anchor to section edge
				if config.invertbars then
					unitFrame.armorFrame:SetPoint("LEFT", firstSection, "LEFT", gap + xOff, 0)
				else
					unitFrame.armorFrame:SetPoint("RIGHT", firstSection, "RIGHT", -gap + xOff, 0)
				end
			end
		end
	end
end

local function CreateBarSecondSection(unitFrame, guid)
	local config = Cursive.db.profile
	local secondSection = CreateFrame("Button", "Cursive2ndSection", unitFrame)

	if config.invertbars then
		-- When inverted, position relative to third section (which is created first)
		secondSection:SetPoint("LEFT", unitFrame.thirdSection, "RIGHT", 0, 0)
	else
		-- Normal positioning relative to first section
		secondSection:SetPoint("LEFT", unitFrame.firstSection, "RIGHT", 0, 0)
	end

	secondSection:SetWidth(GetBarSecondSectionWidth())
	secondSection:SetHeight(config.height)
	unitFrame.secondSection = secondSection
	secondSection.parent = unitFrame

	secondSection:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	secondSection:SetScript("OnClick", ui.BarClick)
	secondSection:SetScript("OnEnter", ui.BarEnter)
	secondSection:SetScript("OnLeave", ui.BarLeave)

	-- create health bar
	if config.showhealthbar then
		local healthBar = CreateFrame("StatusBar", "CursiveHealthBar", secondSection)
		healthBar:SetStatusBarTexture(config.bartexture)
		healthBar:SetStatusBarColor(1, .8, .2, 1)
		healthBar:SetMinMaxValues(0, 100)
		healthBar:SetValue(20)
		healthBar:SetPoint("LEFT", secondSection, "LEFT", ui.padding, 0)
		healthBar:SetWidth(config.healthwidth)
		healthBar:SetHeight(config.height)
		unitFrame.healthBar = healthBar

		local hp = healthBar:CreateFontString(nil, "HIGH", "GameFontWhite")
		hp:SetFont(STANDARD_TEXT_FONT, floor(config.textsize * (config.fontscale or 1) + 0.5), "THINOUTLINE")
		hp:SetJustifyH("RIGHT")
		hp:SetHeight(config.height - 4)
		-- Anchor to right edge, no fixed width - let it expand naturally
		hp:SetPoint("RIGHT", healthBar, "RIGHT", -2, 0)
		-- Set a reasonable max width (prevents overflow on very wide bars)
		hp:SetWidth(config.healthwidth * 0.6)
		unitFrame.hpText = hp

		if config.showunitname then
			local nameMaxW = config.namelength or 80
			local name = healthBar:CreateFontString(nil, "HIGH", "GameFontWhite")
			name:SetFont(STANDARD_TEXT_FONT, floor((config.nameTextSize or config.textsize) * (config.fontscale or 1) + 0.5), "THINOUTLINE")
			name:SetJustifyH("LEFT")
			name:SetHeight(config.height - 4)
			-- Name uses fixed width from config so HP always has priority
			name:SetPoint("LEFT", healthBar, "LEFT", 2, 0)
			name:SetWidth(nameMaxW)
			unitFrame.nameText = name
		end

		-- v4.0.5: Reflect school text in own overlay frame (immune to parent alpha)
		local reflectOverlay = CreateFrame("Frame", nil, ui.rootBarFrame)
		reflectOverlay:SetFrameStrata("HIGH")
		reflectOverlay:SetFrameLevel((healthBar:GetFrameLevel() or 5) + 10)
		reflectOverlay:SetAllPoints(healthBar)
		reflectOverlay:EnableMouse(false)
		local reflectText = reflectOverlay:CreateFontString(nil, "OVERLAY", "GameFontWhite")
		reflectText:SetFont(STANDARD_TEXT_FONT, floor(config.textsize * (config.fontscale or 1) + 0.5), "THINOUTLINE")
		reflectText:SetJustifyH("CENTER")
		reflectText:SetPoint("CENTER", reflectOverlay, "CENTER", 0, 0)
		reflectText:SetWidth(config.healthwidth)
		reflectText:SetHeight(config.height)
		reflectText:SetTextColor(1, 0.8, 0, 1)
		reflectText:Hide()
		unitFrame.reflectOverlay = reflectOverlay
		unitFrame.reflectText = reflectText
		reflectOverlay:Hide()

		-- v4.0.5: Out-of-range diagonal stripe overlay (/ direction, tiled backdrop)
		local oorFrame = CreateFrame("Frame", nil, healthBar)
		oorFrame:SetFrameLevel(healthBar:GetFrameLevel() + 3)
		oorFrame:SetAllPoints(healthBar)
		oorFrame:SetBackdrop({
			bgFile = "Interface\\AddOns\\Cursive-Raid\\Textures\\diagonal_stripes_rev",
			tile = true,
			tileSize = 32,
		})
		oorFrame:SetBackdropColor(1, 1, 1, 0.35)
		oorFrame:EnableMouse(false)
		oorFrame:Hide()
		unitFrame.oorFrame = oorFrame

		-- create health bar backdrops
		if pfUI and pfUI.uf then
			pfUI.api.CreateBackdrop(healthBar)
			healthBar.border = healthBar.backdrop
		else
			healthBar:SetBackdrop(ui.background)
			healthBar:SetBackdropColor(0, 0, 0, 1)

			local border = CreateFrame("Frame", "CursiveBorder", healthBar.bar)
			border:SetBackdrop(ui.border)
			border:SetBackdropColor(.2, .2, .2, 1)
			border:SetPoint("TOPLEFT", healthBar.bar, "TOPLEFT", -2, 2)
			border:SetPoint("BOTTOMRIGHT", healthBar.bar, "BOTTOMRIGHT", 2, -2)
			healthBar.border = border
		end

		-- create inner glow effect for hover (gradient from edge)
		local glowLayers = {}
		local numLayers = 5  -- Number of gradient layers
		local maxGlowWidth = 8  -- Maximum glow reach in pixels

		-- Create gradient layers for each edge
		for layer = 1, numLayers do
			local intensity = (numLayers - layer + 1) / numLayers * 0.25  -- Decreasing intensity
			local width = floor(layer * maxGlowWidth / numLayers)  -- Increasing width

			-- Top glow layer
			local glowTop = healthBar:CreateTexture(nil, "ARTWORK")
			glowTop:SetTexture("Interface\\Buttons\\WHITE8X8")
			glowTop:SetBlendMode("ADD")
			glowTop:SetVertexColor(1, 1, 1, intensity)
			glowTop:SetPoint("TOPLEFT", healthBar, "TOPLEFT", width, -layer + 1)
			glowTop:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", -width, -layer + 1)
			glowTop:SetHeight(1)
			glowTop:Hide()
			tinsert(glowLayers, glowTop)

			-- Bottom glow layer
			local glowBottom = healthBar:CreateTexture(nil, "ARTWORK")
			glowBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
			glowBottom:SetBlendMode("ADD")
			glowBottom:SetVertexColor(1, 1, 1, intensity)
			glowBottom:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", width, layer - 1)
			glowBottom:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -width, layer - 1)
			glowBottom:SetHeight(1)
			glowBottom:Hide()
			tinsert(glowLayers, glowBottom)

			-- Left glow layer
			local glowLeft = healthBar:CreateTexture(nil, "ARTWORK")
			glowLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
			glowLeft:SetBlendMode("ADD")
			glowLeft:SetVertexColor(1, 1, 1, intensity)
			glowLeft:SetPoint("TOPLEFT", healthBar, "TOPLEFT", layer - 1, -width)
			glowLeft:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", layer - 1, width)
			glowLeft:SetWidth(1)
			glowLeft:Hide()
			tinsert(glowLayers, glowLeft)

			-- Right glow layer
			local glowRight = healthBar:CreateTexture(nil, "ARTWORK")
			glowRight:SetTexture("Interface\\Buttons\\WHITE8X8")
			glowRight:SetBlendMode("ADD")
			glowRight:SetVertexColor(1, 1, 1, intensity)
			glowRight:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", -layer + 1, -width)
			glowRight:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -layer + 1, width)
			glowRight:SetWidth(1)
			glowRight:Hide()
			tinsert(glowLayers, glowRight)
		end

		-- Store all glow layers in a table
		unitFrame.hoverGlow = glowLayers
	else
		if config.showunitname then
			local nameMaxW = config.namelength or 80
			local name = secondSection:CreateFontString(nil, "HIGH", "GameFontWhite")
			name:SetPoint("TOPLEFT", secondSection, "TOPLEFT", 2, -2)
			name:SetFont(STANDARD_TEXT_FONT, floor((config.nameTextSize or config.textsize) * (config.fontscale or 1) + 0.5), "THINOUTLINE")
			name:SetWidth(nameMaxW)
			name:SetHeight(config.height - 4)
			name:SetJustifyH("LEFT")
			unitFrame.nameText = name
		end
	end
end

local function CreateBarThirdSection(unitFrame, guid)
	local config = Cursive.db.profile

	local thirdSection = CreateFrame("Frame", "Cursive3rdSection", unitFrame)

	if config.invertbars then
		-- When inverted, this is positioned first (leftmost)
		thirdSection:SetPoint("LEFT", unitFrame, "LEFT", 0, 0)
	else
		-- Normal positioning relative to second section
		thirdSection:SetPoint("LEFT", unitFrame.secondSection, "RIGHT", 0, 0)
	end

	thirdSection:SetWidth(math.max(1, GetBarThirdSectionWidth()))
	thirdSection:SetHeight(config.height)
	thirdSection:EnableMouse(false)
	unitFrame.thirdSection = thirdSection

	-- display up to maxcurses curses
	for i = 1, config.maxcurses do
		local curse = thirdSection:CreateTexture(nil, "OVERLAY")
		curse:SetWidth(config.curseiconsize)
		curse:SetHeight(config.curseiconsize)

		if config.invertbars then
			-- When inverted, position from right to left
			local rightOffset = i * ui.padding + ((i - 1) * config.curseiconsize)
			curse:SetPoint("RIGHT", thirdSection, "RIGHT", -rightOffset, 0)
		else
			-- Normal positioning from left to right
			curse:SetPoint("LEFT", thirdSection, "LEFT", i * ui.padding + ((i - 1) * config.curseiconsize), 0)
		end

		-- v3.2: Create debuff border frame for this icon (level +1: over icon, under timer)
		local borderFrame = CreateFrame("Frame", nil, thirdSection)
		borderFrame:SetFrameLevel(thirdSection:GetFrameLevel() + 1)

		-- v3.2: Timer/Stack frame above borders (level +2: over borders)
		local timerFrame = CreateFrame("Frame", nil, thirdSection)
		timerFrame:SetAllPoints(thirdSection)
		timerFrame:SetFrameLevel(thirdSection:GetFrameLevel() + 2)

		curse.timer = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		curse.timer:SetFontObject(GameFontHighlight)
		curse.timer:SetFont(STANDARD_TEXT_FONT, floor(config.cursetimersize * (config.fontscale or 1) + 0.5), "OUTLINE")
		curse.timer:SetTextColor(1, 1, 1)

		-- Timer positioning: cursetimeh/cursetimev (0-10 grid, 5=center)
		curse.timer:ClearAllPoints()
		local th = (config.cursetimeh or 5)
		local tv = (config.cursetimev or 5)
		local xFrac = (th - 5) / 5
		local yFrac = (tv - 5) / 5
		local halfW = config.curseiconsize / 2
		local halfH = config.curseiconsize / 2
		curse.timer:SetPoint("CENTER", curse, "CENTER", floor(xFrac * halfW), floor(yFrac * halfH))

		-- v3.2: Stack count text with configurable size, color, and position
		curse.stackText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		curse.stackText:SetFont(STANDARD_TEXT_FONT, floor((config.cursestacksize or 10) * (config.fontscale or 1) + 0.5), "OUTLINE")
		local stackColorMode = config.stackcountercolor or "white"
		if stackColorMode == "yellow" or (stackColorMode ~= "classcolor" and config.cursestackyellow) then
			curse.stackText:SetTextColor(1, 1, 0)
		else
			curse.stackText:SetTextColor(1, 1, 1)
		end
		local sh = (config.cursestackh or 9)
		local sv = (config.cursestackv or 1)
		local sxFrac = (sh - 5) / 5
		local syFrac = (sv - 5) / 5
		local sHalfW = config.curseiconsize / 2
		local sHalfH = config.curseiconsize / 2
		curse.stackText:SetPoint("CENTER", curse, "CENTER", floor(sxFrac * sHalfW), floor(syFrac * sHalfH))
		curse.stackText:SetJustifyH("CENTER")
		curse.stackText:Hide()

		curse.timer:Hide()
		curse:Hide()
		borderFrame:SetWidth(config.curseiconsize)
		borderFrame:SetHeight(config.curseiconsize)
		if config.invertbars then
			local rightOffset = i * ui.padding + ((i - 1) * config.curseiconsize)
			borderFrame:SetPoint("RIGHT", thirdSection, "RIGHT", -rightOffset, 0)
		else
			borderFrame:SetPoint("LEFT", thirdSection, "LEFT", i * ui.padding + ((i - 1) * config.curseiconsize), 0)
		end
		curse.debuffBorder = CreateDebuffBorder(borderFrame)

		unitFrame["curse" .. i] = curse
	end
end

-- v3.2.1: Other Side section — debuff icons on opposite side of health bar
local function CreateBarOtherSideSection(unitFrame, guid)
	local config = Cursive.db.profile
	if config.orderotherside == "none" then return end

	local otherSection = CreateFrame("Frame", "Cursive4thSection", unitFrame)

	-- Anchor: behind armor frame if active, otherwise behind firstSection
	local anchor = unitFrame.firstSection
	local gap = 0
	if unitFrame.armorFrame and config.armorStatusEnabled then
		anchor = unitFrame.armorFrame
		gap = 3
	end

	if config.invertbars then
		otherSection:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
	else
		otherSection:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
	end

	local osWidth = GetBarOtherSideSectionWidth()
	otherSection:SetWidth(osWidth)
	otherSection:SetHeight(config.height)
	otherSection:EnableMouse(false)
	unitFrame.otherSideSection = otherSection

	for i = 1, config.maxcurses do
		local curse = otherSection:CreateTexture(nil, "OVERLAY")
		curse:SetWidth(config.curseiconsize)
		curse:SetHeight(config.curseiconsize)

		if config.invertbars then
			local leftOffset = i * ui.padding + ((i - 1) * config.curseiconsize)
			curse:SetPoint("LEFT", otherSection, "LEFT", leftOffset, 0)
		else
			local rightOffset = i * ui.padding + ((i - 1) * config.curseiconsize)
			curse:SetPoint("RIGHT", otherSection, "RIGHT", -rightOffset, 0)
		end

		-- Border frame
		local borderFrame = CreateFrame("Frame", nil, otherSection)
		borderFrame:SetFrameLevel(otherSection:GetFrameLevel() + 1)

		-- Timer/Stack frame
		local timerFrame = CreateFrame("Frame", nil, otherSection)
		timerFrame:SetAllPoints(otherSection)
		timerFrame:SetFrameLevel(otherSection:GetFrameLevel() + 2)

		curse.timer = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		curse.timer:SetFontObject(GameFontHighlight)
		curse.timer:SetFont(STANDARD_TEXT_FONT, floor(config.cursetimersize * (config.fontscale or 1) + 0.5), "OUTLINE")
		curse.timer:SetTextColor(1, 1, 1)

		local th = (config.cursetimeh or 5)
		local tv = (config.cursetimev or 5)
		local xFrac = (th - 5) / 5
		local yFrac = (tv - 5) / 5
		local halfW = config.curseiconsize / 2
		local halfH = config.curseiconsize / 2
		curse.timer:SetPoint("CENTER", curse, "CENTER", floor(xFrac * halfW), floor(yFrac * halfH))

		curse.stackText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		curse.stackText:SetFont(STANDARD_TEXT_FONT, floor((config.cursestacksize or 10) * (config.fontscale or 1) + 0.5), "OUTLINE")
		curse.stackText:SetTextColor(1, 1, 1)
		local sh = (config.cursestackh or 9)
		local sv = (config.cursestackv or 1)
		local sxFrac = (sh - 5) / 5
		local syFrac = (sv - 5) / 5
		curse.stackText:SetPoint("CENTER", curse, "CENTER", floor(sxFrac * halfW), floor(syFrac * halfH))
		curse.stackText:SetJustifyH("CENTER")
		curse.stackText:Hide()

		curse.timer:Hide()
		curse:Hide()
		borderFrame:SetWidth(config.curseiconsize)
		borderFrame:SetHeight(config.curseiconsize)
		if config.invertbars then
			local leftOffset = i * ui.padding + ((i - 1) * config.curseiconsize)
			borderFrame:SetPoint("LEFT", otherSection, "LEFT", leftOffset, 0)
		else
			local rightOffset = i * ui.padding + ((i - 1) * config.curseiconsize)
			borderFrame:SetPoint("RIGHT", otherSection, "RIGHT", -rightOffset, 0)
		end
		curse.debuffBorder = CreateDebuffBorder(borderFrame)

		unitFrame["othercurse" .. i] = curse
	end

	-- v3.2.2: Armor display hidden when position is "otherside" (Other Side is for debuffs only)
	-- Other Side position no longer creates armor display
end

local function CreateBar(row, col, guid)
	local unitFrame = CreateFrame("Frame", "CursiveUnitFrame", ui.rootBarFrame)
	unitFrame.guid = guid

	unitFrame:SetScript("OnUpdate", ui.BarUpdate)

	local config = Cursive.db.profile
	local width = GetBarWidth()
	unitFrame:SetWidth(width)
	unitFrame:SetHeight(config.height)

	if config.invertbars then
		-- Create sections in reverse order: 3 -> 2 -> 1 -> otherside
		CreateBarThirdSection(unitFrame, guid)
		CreateBarSecondSection(unitFrame, guid)
		CreateBarFirstSection(unitFrame, guid)
		CreateBarOtherSideSection(unitFrame, guid)
	else
		-- Normal order: otherside -> 1 -> 2 -> 3
		CreateBarFirstSection(unitFrame, guid)
		CreateBarOtherSideSection(unitFrame, guid)
		CreateBarSecondSection(unitFrame, guid)
		CreateBarThirdSection(unitFrame, guid)
	end

	ui.unitFrames[col][row] = unitFrame
	return unitFrame
end

local function GetBarCords(row, col)
	local config = Cursive.db.profile
	local x = (col - 1) * GetBarWidth()
	local y
	if config.expandupwards then
		-- For upward expansion: start from bottom with spacing, then go up
		y = config.spacing + ((row - 1) * (config.height + config.spacing))
	else
		-- For downward expansion: use original logic (don't subtract 1 to account for header)
		y = -(row * (config.height + config.spacing))
	end
	return x, y
end

-- v4.0.6: Single-pass aura scan per GUID per frame tick
-- Scans all debuffs+buffs once, caches every spellId -> {texture, stacks}
-- Subsequent hasAnySpellId calls for the same GUID do O(1) lookup instead of 128-slot rescan
local auraSnapshotCache = {}  -- guid -> { spellId -> {texture, stacks}, _tick = time }
local AURA_SNAPSHOT_TTL = 0.15 -- slightly longer than 10Hz main loop tick

local function getAuraSnapshot(guid)
	local now = GetTime()
	local cached = auraSnapshotCache[guid]
	if cached and cached._tick and (now - cached._tick) < AURA_SNAPSHOT_TTL then
		return cached
	end

	-- Reuse existing table if available, wipe numeric spellId keys
	local snapshot = cached or {}
	if cached then
		for k, _ in pairs(snapshot) do
			if k ~= "_tick" then
				snapshot[k] = nil
			end
		end
	end
	snapshot._tick = now

	for i = 1, 64 do
		local texture, stacks, spellSchool, spellId = UnitDebuff(guid, i)
		if not spellId then break end
		local entry = snapshot[spellId]
		if not entry then
			entry = {}
			snapshot[spellId] = entry
		end
		entry.texture = texture
		entry.stacks = stacks
	end

	for i = 1, 64 do
		local texture, stacks, spellId = UnitBuff(guid, i)
		if not spellId then break end
		if not snapshot[spellId] then
			local entry = {}
			entry.texture = texture
			entry.stacks = stacks
			snapshot[spellId] = entry
		end
	end

	auraSnapshotCache[guid] = snapshot
	return snapshot
end

-- v3.2: Returns spellId, texture, stacks from cached aura snapshot
local function hasAnySpellId(guid, spellIds)
	local snapshot = getAuraSnapshot(guid)
	for spellId, _ in pairs(spellIds) do
		local entry = snapshot[spellId]
		if entry then
			return spellId, entry.texture, entry.stacks
		end
	end
	return nil, nil, nil
end

-- v3.2.1: Determine debuff category for ordering
-- Returns: "ownclass", "ownraid", "otherclass", or "otherraid"
local function GetDebuffCategory(curseData, curseName, guid)
	if not curseData or not curseName then return "otherclass" end

	-- Normalize curseName for shareddebuffs key lookup
	local normalized = Cursive.curses.nameToNormalized[curseName] or string.gsub(string.lower(curseName), "[%s']", "")

	-- Determine ownership
	local isOwn = (curseData.currentPlayer == true)
	if not isOwn and guid and Cursive.curses and Cursive.curses.playerOwnedCasts then
		local ownCasts = Cursive.curses.playerOwnedCasts[guid]
		if ownCasts and ownCasts[normalized] then
			local castTime = ownCasts[normalized]
			if (GetTime() - castTime) < 600 then
				isOwn = true
			end
		end
	end

	-- Determine if raid debuff (check normalized name AND sharedDebuffKey from data)
	local isRaid = false
	local sd = Cursive.db.profile.shareddebuffs
	if sd then
		if sd[normalized] ~= nil then
			isRaid = true
		elseif curseData.sharedDebuffKey and sd[curseData.sharedDebuffKey] ~= nil then
			isRaid = true
		end
	end

	if isOwn and isRaid then
		-- v3.2.1: If "Include Own Raid in Order" is active, treat own raid as otherraid for sorting
		if Cursive.db.profile.includeOwnRaidInOrder == true then
			return "otherraid"
		end
		return "ownraid"
	elseif isOwn then return "ownclass"
	elseif isRaid then return "otherraid"
	else return "otherclass"
	end
end

-- v3.2.1: Get positional order weight for a debuff
-- Config: orderfront/ordermiddle/orderback/orderlast = category name
-- Returns weight 1-4 (front=1, last=4), or -1 for "other side"
local function GetOrderWeight(curseData, curseName, guid)
	local category = GetDebuffCategory(curseData, curseName, guid)
	local config = Cursive.db.profile

	-- Check if this category is assigned to "other side"
	if config.orderotherside == category then return -1 end

	-- Check each position slot for our category
	if config.orderfront == category then return 1 end
	if config.ordermiddle == category then return 2 end
	if config.orderback == category then return 3 end
	if config.orderlast == category then return 4 end

	-- v4.0: Category not in any slot — hidden (None)
	return -2
end

-- v3.2.1: Build reverse lookup for raidDebuffOrder (debuffKey -> position index)
-- Rebuilt once per sort cycle from config
local raidOrderLookup = {}

local function BuildRaidOrderLookup()
	for k in pairs(raidOrderLookup) do raidOrderLookup[k] = nil end
	local order = Cursive.db.profile.raidDebuffOrder
	if order then
		for i = 1, getn(order) do
			raidOrderLookup[order[i]] = i
		end
	end
end

-- Get sub-order weight for raid debuffs (within same category weight)
-- Returns position in raidDebuffOrder, or 999 if not found
local function GetRaidSubWeight(curseData, curseName)
	if not curseName then return 999 end
	-- Check via sharedDebuffKey first (handles ghost/missing entries)
	if curseData and curseData.sharedDebuffKey and raidOrderLookup[curseData.sharedDebuffKey] then
		return raidOrderLookup[curseData.sharedDebuffKey]
	end
	-- Normalize curseName to debuffKey (lowercase, no spaces)
	local normalized = Cursive.curses.nameToNormalized[curseName] or string.gsub(string.lower(curseName), "[%s']", "")
	-- Check direct match
	if raidOrderLookup[normalized] then return raidOrderLookup[normalized] end
	-- Check via sharedDebuffSpellLookup (spellID -> debuffKey)
	if curseData and curseData.spellID and Cursive.curses and Cursive.curses.sharedDebuffSpellLookup then
		local debuffKey = Cursive.curses.sharedDebuffSpellLookup[curseData.spellID]
		if debuffKey and raidOrderLookup[debuffKey] then
			return raidOrderLookup[debuffKey]
		end
	end
	return 999
end

-- Reusable pool table for curse sorting (avoids table allocation per frame per unit)
local curseNamesPool = {}

-- Reusable pool for missing debuff keys (avoids table allocation per unit per render tick)
local missingKeys = {}

-- Reusable cache for order weights per sort cycle (avoids recalculating per comparison)
local orderWeightCache = {}

-- Cache for raid sub-weights
local raidSubWeightCache = {}

local function GetSortedCurses(guidCurses, guid)
	-- Wipe and reuse pool instead of creating new table each call
	-- NOTE: must reset .n because tinsert uses it; setting [i]=nil does NOT update .n in Lua 5.0
	for i = getn(curseNamesPool), 1, -1 do
		curseNamesPool[i] = nil
	end
	curseNamesPool.n = 0

	-- Wipe order weight cache
	for k in pairs(orderWeightCache) do
		orderWeightCache[k] = nil
	end
	for k in pairs(raidSubWeightCache) do
		raidSubWeightCache[k] = nil
	end

	-- v4.0.4: Only rebuild when order changed
	if Cursive._raidOrderDirty then
		BuildRaidOrderLookup()
		Cursive._raidOrderDirty = false
	end

	-- Collect keys and pre-compute order weights
	local config = Cursive.db.profile
	local useRaidOrder = (getn(config.raidDebuffOrder or {}) > 0)
	for key in pairs(guidCurses) do
		local w = GetOrderWeight(guidCurses[key], key, guid)
		if w == -2 then
			-- v4.0: Category set to None — skip entirely
		else
			tinsert(curseNamesPool, key)
			orderWeightCache[key] = w
			-- Pre-compute raid sub-weight for raid categories
			if useRaidOrder then
				local cat = GetDebuffCategory(guidCurses[key], key, guid)
				if cat == "otherraid" or (cat == "ownraid" and config.includeOwnRaidInOrder) then
					raidSubWeightCache[key] = GetRaidSubWeight(guidCurses[key], key)
				end
			end
		end
	end

	-- v3.2.1: Primary sort by positional group, secondary by raid debuff order, tertiary by timer
	local ordering = Cursive.db.profile.curseordering
	tsort(curseNamesPool, function(a, b)
		local wa = orderWeightCache[a]
		local wb = orderWeightCache[b]
		if wa ~= wb then
			return wa < wb
		end
		-- v3.2.1: Within same position group, sort by raidDebuffOrder if applicable
		local ra = raidSubWeightCache[a]
		local rb = raidSubWeightCache[b]
		if ra and rb and ra ~= rb then
			return ra < rb
		end
		-- Tertiary sort within same position group
		-- v4.0.3: Use raw float (hundredths) for stable sorting, prevents flicker when
		-- two debuffs have the same rounded second value. Tie-breaker: application time.
		if ordering == L["Order applied"] then
			return guidCurses[a].start < guidCurses[b].start
		elseif ordering == L["Expiring latest -> soonest"] then
			local ra = Cursive.curses:TimeRemainingRaw(guidCurses[a])
			local rb = Cursive.curses:TimeRemainingRaw(guidCurses[b])
			if ra ~= rb then return ra > rb end
			return guidCurses[a].start < guidCurses[b].start
		else
			-- Default: expiring soonest first
			local ra = Cursive.curses:TimeRemainingRaw(guidCurses[a])
			local rb = Cursive.curses:TimeRemainingRaw(guidCurses[b])
			if ra ~= rb then return ra > rb end
			return guidCurses[a].start < guidCurses[b].start
		end
	end)

	-- Return snapshot as array (caller iterates before next GetSortedCurses call)
	local i = 0
	return function()
		i = i + 1
		local key = curseNamesPool[i]
		if key then
			return key, guidCurses[key]
		end
	end
end

local function DisplayGuid(guid)
	if not ui.unitFrames[ui.col] then
		ui.unitFrames[ui.col] = {}
	end

	local unitFrame
	if ui.unitFrames[ui.col][ui.row] then
		unitFrame = ui.unitFrames[ui.col][ui.row]
		unitFrame.guid = guid
	else
		unitFrame = CreateBar(ui.row, ui.col, guid)
		ui.unitFrames[ui.col][ui.row] = unitFrame
	end

	local x, y = GetBarCords(ui.row, ui.col)

	-- v4.0.5: Update section widths on reuse (stale widths from old config cause bar misalignment)
	local config = Cursive.db.profile
	local expectedBarWidth = GetBarWidth()
	if math.floor(unitFrame:GetWidth()) ~= math.floor(expectedBarWidth) then
		unitFrame:SetWidth(expectedBarWidth)
		if unitFrame.thirdSection then
			unitFrame.thirdSection:SetWidth(math.max(1, GetBarThirdSectionWidth()))
		end
		if unitFrame.secondSection then
			unitFrame.secondSection:SetWidth(GetBarSecondSectionWidth())
		end
		if unitFrame.firstSection then
			unitFrame.firstSection:SetWidth(GetBarFirstSectionWidth())
		end
	end

	-- update position if required (separate x/y fields to avoid string concat per frame)
	if unitFrame.posX ~= x or unitFrame.posY ~= y then
		unitFrame:ClearAllPoints()
		if config.expandupwards then
			unitFrame:SetPoint("BOTTOMLEFT", ui.rootBarFrame, "BOTTOMLEFT", x, y)
		else
			unitFrame:SetPoint("TOPLEFT", ui.rootBarFrame, "TOPLEFT", x, y)
		end
		unitFrame.posX = x
		unitFrame.posY = y
	end

	-- check for shared debuffs
	for sharedDebuffKey, guids in pairs(Cursive.curses.sharedDebuffGuids) do
		local guidData = guids[guid]
		if guidData then
			local sharedDebuffSpellIds = Cursive.curses.sharedDebuffs[sharedDebuffKey]
			-- v3.2: hasAnySpellId now returns texture and stacks directly from UnitDebuff
			local spellId, liveTexture, liveStacks = hasAnySpellId(guid, sharedDebuffSpellIds)
			if spellId ~= nil then
				-- Use live texture; for Expose Armor prefer stored CP from armor diff calculation
				local finalStacks = liveStacks or 0
				if type(guidData) == "table" and guidData.stacks and guidData.stacks > 0 then
					-- EA armor-diff stacks override scan stacks (scan always returns 1)
					if sharedDebuffKey == "exposearmor" or finalStacks == 0 then
						finalStacks = guidData.stacks
					end
				end
				-- v3.2.1 FIX: Use detection time from sharedDebuffGuids, not GetTime()
				local startTime = (type(guidData) == "table" and guidData.time) or GetTime()
				Cursive.curses:ApplySharedCurse(sharedDebuffKey, spellId, guid, startTime, liveTexture, finalStacks)
				-- remove guid from pending list
				Cursive.curses.sharedDebuffGuids[sharedDebuffKey][guid] = nil
			elseif type(guidData) == "table" and guidData.spellID then
				-- v3.2.1 FIX: Unit not scannable (not current target / out of range)
				-- Apply using stored data from initial detection (ScanForProcDebuff etc.)
				-- Timer will naturally expire; ScanTargetForSharedDebuffs cleans up on target
				local startTime = guidData.time or GetTime()
				Cursive.curses:ApplySharedCurse(sharedDebuffKey, guidData.spellID, guid, startTime, guidData.texture, guidData.stacks or 0)
				Cursive.curses.sharedDebuffGuids[sharedDebuffKey][guid] = nil
			end
		end
	end

	-- v3.2.1: Shared rendering function for debuff icons (main side + other side)
	local function RenderCurseIcon(curse, curseData, curseName, remaining)
		-- Get texture — priority: own spell > stored scan > SpellInfo > live scan > fallback
		-- v4.1.1 FIX: skip trackedCurseIds texture when it's the "?" fallback — otherwise
		-- the priority chain locks in a broken icon and sharedTexture (correct) is never used.
		-- Happens for cross-class spells that aren't in the player's spellbook (SpellInfo
		-- returns nil → some init paths cache the "?" icon).
		local textureData = Cursive.curses.trackedCurseIds[curseData.spellID]
		if textureData and textureData.texture and not string.find(textureData.texture, "INV_Misc_QuestionMark", 1, true) then
			curse:SetTexture(textureData.texture)
		elseif curseData.sharedTexture then
			curse:SetTexture(curseData.sharedTexture)
		else
			-- v3.2.1 FIX: Try SpellInfo first (works for any spell ID without needing target scan)
			local siName, siRank, siTex = SpellInfo(curseData.spellID)
			if siTex then
				curseData.sharedTexture = siTex
				curse:SetTexture(siTex)
			else
				-- Fallback: live scan target debuffs
				local liveTex = nil
				if curseData.targetGuid and UnitExists(curseData.targetGuid) then
					for si = 1, 64 do
						local tex, _, _, sid = UnitDebuff(curseData.targetGuid, si)
						if not sid then break end
						if sid == curseData.spellID then
							liveTex = tex
							curseData.sharedTexture = tex
							break
						end
					end
				end
				curse:SetTexture(liveTex or "Interface\\Icons\\INV_Misc_QuestionMark")
			end
		end

		curse:SetDesaturated(false)
		curse:SetAlpha(1.0)
		curse:SetTexCoord(0.078, 0.92, 0.079, 0.937)

		-- Timer display
		local timerConfig = Cursive.db.profile
		local timerColorMode = timerConfig.durationtimercolor or "white"
		if timerColorMode == true or timerColorMode == false then
			if timerConfig.classcolordurationtimer then timerColorMode = "classcolor"
			elseif timerConfig.cursetimeyellow then timerColorMode = "yellow"
			else timerColorMode = "white" end
		end

		local function ApplyTimerColor()
			if timerColorMode == "classcolor" then
				local tr, tg, tb = GetTimerClassColor(curseData)
				if tr then curse.timer:SetTextColor(tr, tg, tb)
				else curse.timer:SetTextColor(1, 1, 1) end
			elseif timerColorMode == "yellow" then
				curse.timer:SetTextColor(1, 1, 0)
			else
				curse.timer:SetTextColor(1, 1, 1)
			end
		end

		-- v4.0.3: Always use tostring() to prevent text clipping with numeric SetText
		if remaining >= 100 then
			curse.timer:SetText(tostring(ceil((remaining - 30) / 60)) .. "m")
			ApplyTimerColor()
		elseif timerConfig.coloreddecimalduration and remaining < 5 and remaining >= 0 then
			curse.timer:SetText(tostring(remaining))
			curse.timer:SetTextColor(1, 0, 0)
		else
			curse.timer:SetText(tostring(remaining))
			ApplyTimerColor()
		end
		curse.timer:Show()
		curse:Show()

		-- Border
		if curse.debuffBorder then
			local bok, berr = pcall(function()
				local br, bg, bb = GetDebuffBorderColor(curseData, curseName, guid)
				if br then SetBorderColor(curse.debuffBorder, br, bg, bb)
				else HideBorder(curse.debuffBorder) end
			end)
			if not bok and CursiveBorderDebug then
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000BORDER ERR: "..tostring(berr).."|r")
			end
		end

		-- Stacks
		if curse.stackText then
			local showStacks = curseData.sharedStacks and curseData.sharedStacks > 1
			-- v3.2.1: EA always shows CP count (1-5)
			if not showStacks and curseData.sharedStacks and curseData.sharedStacks >= 1 and curseName == L["expose armor"] then
				showStacks = true
			end
			if showStacks then
				curse.stackText:SetText(curseData.sharedStacks)
				local sColorMode = timerConfig.stackcountercolor or "white"
				if sColorMode == "classcolor" then
					local sr, sg, sb = GetTimerClassColor(curseData)
					if sr then curse.stackText:SetTextColor(sr, sg, sb)
					else curse.stackText:SetTextColor(1, 1, 1) end
				elseif sColorMode == "yellow" then
					curse.stackText:SetTextColor(1, 1, 0)
				else
					curse.stackText:SetTextColor(1, 1, 1)
				end
				curse.stackText:Show()
			else
				curse.stackText:SetText("")
				curse.stackText:Hide()
			end
		end

		-- Expiring sound
		if remaining < 1 then
			if Cursive.curses:ShouldPlayExpiringSound(curseName, guid) then
				PlaySoundFile("Interface\\AddOns\\Cursive\\sounds\\expiring.mp3")
			end
		elseif Cursive.curses:HasRequestedExpiringSound(curseName, guid) then
			Cursive.curses:EnableExpiringSound(curseName, guid)
		end
	end

	-- update curses
	local curseNumber = 1
	local otherCurseNumber = 1

	-- make sure old curses are hidden (main side)
	for i = 1, Cursive.db.profile.maxcurses do
		local curse = unitFrame["curse" .. i]
		if curse then
			curse:Hide()
			curse.timer:Hide()
			if curse.stackText then curse.stackText:Hide() end
			HideBorder(curse.debuffBorder)
		end
		-- other side
		local ocurse = unitFrame["othercurse" .. i]
		if ocurse then
			ocurse:Hide()
			ocurse.timer:Hide()
			if ocurse.stackText then ocurse.stackText:Hide() end
			HideBorder(ocurse.debuffBorder)
		end
	end

	local guidCurses = Cursive.curses.guids[guid]

	-- v3.2.1: Inject missing raid debuffs as ghost entries for correct sort order
	for i = table.getn(missingKeys), 1, -1 do missingKeys[i] = nil end
	missingKeys.n = 0
	if Cursive.db.profile.showMissingDebuffs == true and guidCurses and Cursive.curses.sharedDebuffs then
		local sd = Cursive.db.profile.shareddebuffs
		if sd then
			for debuffKey, enabled in pairs(sd) do
				if enabled then
					-- Check if already active on this target
					local found = false
					for curseName, curseData in pairs(guidCurses) do
						if curseData.sharedDebuffKey == debuffKey then
							found = true
							break
						end
						local normalized = Cursive.curses.nameToNormalized[curseName] or string.gsub(string.lower(curseName), "[%s']", "")
						if normalized == debuffKey then
							found = true
							break
						end
					end
					if not found then
						-- Get first spell from debuff meta for name/texture
						local debuffMeta = Cursive.curses.sharedDebuffs[debuffKey]
						if debuffMeta then
							for sid, sdata in pairs(debuffMeta) do
								if type(sdata) == "table" and sdata.name then
									local _, _, tex = SpellInfo(sid)
									local ghostName = "_missing_" .. debuffKey
									guidCurses[ghostName] = {
										rank = 1,
										duration = sdata.duration or 30,
										start = GetTime(),
										spellID = sid,
										targetGuid = guid,
										currentPlayer = false,
										sharedTexture = tex,
										sharedStacks = 0,
										sharedDebuffKey = debuffKey,
										isMissing = true,
									}
									table.insert(missingKeys, ghostName)
									break
								end
							end
						end
					end
				end
			end
		end
	end

	if guidCurses then
		for curseName, curseData in GetSortedCurses(guidCurses, guid) do
			local remaining = Cursive.curses:TimeRemaining(curseData)

			if curseData.isMissing then
				-- v3.2.1: Render missing debuff as greyed-out icon (follows Debuff Order from General)
				local weight = GetOrderWeight(curseData, curseName, guid)
				local targetCurse
				if weight == -2 then
					-- v4.0: Category hidden (None) — skip
				elseif weight == -1 then
					-- Other Side
					if otherCurseNumber <= Cursive.db.profile.maxcurses then
						targetCurse = unitFrame["othercurse" .. otherCurseNumber]
						if targetCurse then otherCurseNumber = otherCurseNumber + 1 end
					end
				else
					-- Main side
					if curseNumber <= Cursive.db.profile.maxcurses then
						targetCurse = unitFrame["curse" .. curseNumber]
						if targetCurse then curseNumber = curseNumber + 1 end
					end
				end
				if targetCurse then
					local tex = curseData.sharedTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
					targetCurse:SetTexture(tex)
					targetCurse:SetTexCoord(0.078, 0.92, 0.079, 0.937)
					targetCurse:SetDesaturated(true)
					targetCurse:SetAlpha(0.5)
					targetCurse:Show()
					targetCurse.timer:Hide()
					if targetCurse.stackText then targetCurse.stackText:Hide() end
					HideBorder(targetCurse.debuffBorder)
				end
			elseif remaining >= 0 then
				-- v3.2.1: Check if this debuff goes to "other side" or is hidden
				local weight = GetOrderWeight(curseData, curseName, guid)
				if weight == -2 then
					-- v4.0: Category hidden (None) — skip
				elseif weight == -1 then
					-- Render on other side
					if otherCurseNumber <= Cursive.db.profile.maxcurses then
						local ocurse = unitFrame["othercurse" .. otherCurseNumber]
						if ocurse then
							RenderCurseIcon(ocurse, curseData, curseName, remaining)
							otherCurseNumber = otherCurseNumber + 1
						end
					end
				else
					-- Render on main side
					if curseNumber <= Cursive.db.profile.maxcurses then
						local curse = unitFrame["curse" .. curseNumber]
						if curse then
							RenderCurseIcon(curse, curseData, curseName, remaining)
							curseNumber = curseNumber + 1
						end
					end
				end
			else
				-- Expired shared debuff - remove
				if curseData.currentPlayer == false then
					Cursive.curses.guids[guid][curseName] = nil
				end
			end
		end
	end

	-- Clean up ghost entries for missing debuffs
	if guidCurses then
		for _, gk in ipairs(missingKeys) do
			guidCurses[gk] = nil
		end
	end

	unitFrame:Show()

	-- v3.2.2: Transparent display for CC'd / Spell Reflect targets
	local reflectSchool = Cursive.curses:HasSpellReflect(guid)
	if Cursive.db.profile.cctransparency and (Cursive.curses:HasActiveCC(guid) or reflectSchool) then
		unitFrame:SetAlpha(0.35)
	else
		unitFrame:SetAlpha(1.0)
	end
	-- v4.0.5: Reflect overlay is independent frame (not affected by unitFrame alpha)
	if unitFrame.reflectOverlay then
		if reflectSchool then
			unitFrame.reflectText:SetText("Reflect: " .. reflectSchool)
			unitFrame.reflectText:Show()
			unitFrame.reflectOverlay:Show()
		else
			unitFrame.reflectText:Hide()
			unitFrame.reflectOverlay:Hide()
		end
	end

	ui.numDisplayed = ui.numDisplayed + 1

	local config = Cursive.db.profile

	-- update row/col
	ui.row = ui.row + 1
	if ui.row > config.maxrow then
		ui.row = 1
		ui.col = ui.col + 1
		if ui.col > config.maxcol then
			ui.maxBarsDisplayed = true
		end
	end
end

local function CheckForCleanup(guid, time)
	-- v3.2.1: Never clean up test overlay GUIDs
	if IsTestGuid(guid) then return end
	local active = UnitExists(guid) and Cursive.filter.alive(guid)
	if active then
		local old = GetTime() - time >= 900 -- >= 15 minutes old
		if old and not UnitIsVisible(guid) then
			active = false
		end
	end

	if not active then
		-- remove from core
		Cursive.core.remove(guid)
		-- remove from curses
		Cursive.curses:RemoveGuid(guid)

		-- remove from sharedDebuffGuids
		for sharedDebuffKey, guids in pairs(Cursive.curses.sharedDebuffGuids) do
			if guids[guid] then
				Cursive.curses.sharedDebuffGuids[sharedDebuffKey][guid] = nil
			end
		end
	end
end

local shouldDisplayGuids = {};
local displayedGuids = {};

ui:SetAllPoints()
ui:SetScript("OnUpdate", function()
	local config = Cursive.db.profile

	if not config.enabled then
		return
	end

	if (this.tick or 1) > GetTime() then
		return
	else
		this.tick = GetTime() + 0.1
	end

	-- v4.0.4: Protect scan loop with pcall to prevent silent tracking death on Lua errors
	local scanOk, scanErr = pcall(function()

	-- v3.2.1: Freeze test overlay timers every frame
	if CursiveTestOverlay_FreezeTimers then
		CursiveTestOverlay_FreezeTimers()
	end

	-- v3.2.1 FIX: Periodic cleanup of stale shared debuff tracking data
	if not ui.sharedCleanupTick or ui.sharedCleanupTick < GetTime() then
		ui.sharedCleanupTick = GetTime() + 3.0
		Cursive.curses:CleanupSharedDebuffs()
		-- v4.0.6: Clean stale caches (range, CC/reflect, aura snapshots)
		Cursive.filter.cleanRangeCache()
		Cursive.curses:CleanCCReflectCache()
		for guid, snap in pairs(auraSnapshotCache) do
			if snap._tick and (GetTime() - snap._tick) > 0.3 then
				auraSnapshotCache[guid] = nil
			end
		end
	end

	if not ui.rootBarFrame then
		ui.rootBarFrame = CreateRoot()
	end

	-- skip if locked (due to moving)
	if ui.rootBarFrame.lock then
		return
	end

	-- reset display data
	ui.row = 1
	ui.col = 1
	ui.maxBarsDisplayed = false
	ui.numDisplayed = 0

	-- clear shouldDisplayGuids
	for guid, _ in pairs(shouldDisplayGuids) do
		shouldDisplayGuids[guid] = nil
	end

	-- clear displayedGuids
	for guid, _ in pairs(displayedGuids) do
		displayedGuids[guid] = nil
	end

	-- run through all guids and fill with bars
	local title_size = TITLE_BAR_HEIGHT + config.spacing

	local topMaxHp = 0
	local secondMaxHp = 0
	local thirdMaxHp = 0

	local topMaxGuid = 0
	local secondMaxGuid = 0
	local thirdMaxGuid = 0

	local numDisplayable = 0

	local averageMaxHp = 0

	local _, currentTargetGuid = UnitExists("target")

	-- first consider raid marks
	for i = 8, 1, -1 do
		local _, guid = UnitExists("mark" .. i)
		if guid then
			if Cursive:ShouldDisplayGuid(guid) then
				numDisplayable = numDisplayable + 1

				-- display guid
				displayedGuids[guid] = true
				DisplayGuid(guid)
				if ui.maxBarsDisplayed then
					break
				end
			end
			-- don't try to display this guid again
			shouldDisplayGuids[guid] = false
		end
	end

	for guid, time in pairs(Cursive.core.guids) do
		-- calculate shouldDisplay
		local shouldDisplay = false
		if shouldDisplayGuids[guid] == nil then
			shouldDisplay = Cursive:ShouldDisplayGuid(guid)
			shouldDisplayGuids[guid] = shouldDisplay

			if shouldDisplay then
				numDisplayable = numDisplayable + 1
			end
		else
			shouldDisplay = shouldDisplayGuids[guid]
		end

		-- calculate top 3 max hps
		if shouldDisplay then
			local maxHp = UnitHealthMax(guid)
			if maxHp > topMaxHp then
				thirdMaxHp = secondMaxHp
				thirdMaxGuid = secondMaxGuid
				secondMaxHp = topMaxHp
				secondMaxGuid = topMaxGuid
				topMaxHp = maxHp
				topMaxGuid = guid
			elseif maxHp > secondMaxHp then
				thirdMaxHp = secondMaxHp
				thirdMaxGuid = secondMaxGuid
				secondMaxHp = maxHp
				secondMaxGuid = guid
			elseif maxHp > thirdMaxHp then
				thirdMaxHp = maxHp
				thirdMaxGuid = guid
			end
		else
			CheckForCleanup(guid, time)
		end
	end

	-- top max hp
	if not ui.maxBarsDisplayed and numDisplayable > ui.numDisplayed and not displayedGuids[topMaxGuid] then
		displayedGuids[topMaxGuid] = true
		DisplayGuid(topMaxGuid)
	end

	-- second max hp
	if not ui.maxBarsDisplayed and numDisplayable > ui.numDisplayed and not displayedGuids[secondMaxGuid] then
		displayedGuids[secondMaxGuid] = true
		DisplayGuid(secondMaxGuid)
	end

	-- third max hp
	if not ui.maxBarsDisplayed and numDisplayable > ui.numDisplayed and not displayedGuids[thirdMaxGuid] then
		displayedGuids[thirdMaxGuid] = true

		DisplayGuid(thirdMaxGuid)
	end

	-- fill in remaining slots
	for guid, time in pairs(Cursive.core.guids) do
		if ui.maxBarsDisplayed or numDisplayable <= ui.numDisplayed then
			break
		end

		if not displayedGuids[guid] and shouldDisplayGuids[guid] == true then
			displayedGuids[guid] = true
			DisplayGuid(guid)
		end
	end

	-- if current target not yet displayed, show it at maxrow/maxcol
	if currentTargetGuid and
			shouldDisplayGuids[currentTargetGuid] and
			not displayedGuids[currentTargetGuid] and
			Cursive.db.profile.alwaysshowcurrenttarget then
		-- replace the last displayed guid with the current target
		displayedGuids[currentTargetGuid] = true
		ui.col = config.maxcol
		ui.row = config.maxrow
		DisplayGuid(currentTargetGuid)
	end

	-- hide any remaining unit frames
	for col, rows in pairs(ui.unitFrames) do
		for row, unitFrame in pairs(rows) do
			if unitFrame:IsShown() then
				if not displayedGuids[unitFrame.guid] then
					unitFrame:Hide()
				else
					displayedGuids[unitFrame.guid] = nil -- avoid displaying duplicate rows
				end
			end
		end
	end

	end) -- end pcall
	if not scanOk then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Cursive] Scan error:|r " .. tostring(scanErr))
	end

end)

Cursive.ui = ui
