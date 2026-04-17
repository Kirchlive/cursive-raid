-- CursiveOptionsUI.lua  (v5)
-- Complete options UI for Cursive Raid 4.0
-- Lua 5.0 compatible (Vanilla 1.12 / TurtleWoW)
-- NO select(), string.match(), string.gmatch(), #table, {...}, table.unpack(), self in handlers
-- NO SetNormalFontObject on naked buttons

-- ============================================================
-- 1. Local cache of frequently used globals
-- ============================================================
local pairs = pairs
local ipairs = ipairs
local floor = math.floor
local format = string.format
local getn = table.getn
local tinsert = table.insert
local tremove = table.remove
local getglobal = getglobal

-- ============================================================
-- 2. Global table for options functions
-- ============================================================
CursiveOpts = {}

-- ============================================================
-- 3. State variables
-- ============================================================
local selectedTab = 1
local selectedClass = "warrior"
local initialized = false

-- ============================================================
-- 4. Constants
-- ============================================================
local FRAME_WIDTH = 338
local FRAME_HEIGHT = 500
local CONTENT_WIDTH = FRAME_WIDTH - 30  -- padding left/right
local ROW_HEIGHT = 22
local ROW_SPACING = 1
local SLIDER_ROW_HEIGHT = 55
local SLIDER_ROW_SPACING = 4
local HEADER_HEIGHT = 22
local HEADER_EXTRA_TOP = 14  -- extra space above non-first headers (matches tab-to-content gap)
local SLIDER_WIDTH = floor((CONTENT_WIDTH - 30) * 0.95) + 9
local SLIDER_X_OFFSET = floor((CONTENT_WIDTH - SLIDER_WIDTH) / 2)

local TAB_COUNT = 5
local TAB_GAP = 2
local TAB_HEIGHT = 22
local TAB_WIDTH = floor((FRAME_WIDTH - (TAB_COUNT - 1) * TAB_GAP) / TAB_COUNT)

local tabLabels = { "General", "Raid", "Class", "Display", "Filter" }
local tabButtonNames = {
    "CursiveTabGeneral", "CursiveTabRaid", "CursiveTabClass",
    "CursiveTabDisplay", "CursiveTabFilter",
}
local panelFrameNames = {
    "CursiveGeneralPanel", "CursiveRaidPanel", "CursiveClassPanel",
    "CursiveDisplayPanel", "CursiveFilterPanel",
}

-- Class colors for sub-tabs (including Procs)
local CLASS_COLORS = {
    warrior  = { 0.78, 0.61, 0.43 },
    rogue    = { 1, 0.96, 0.41 },
    hunter   = { 0.67, 0.83, 0.45 },
    mage     = { 0.41, 0.80, 0.94 },
    warlock  = { 0.58, 0.51, 0.79 },
    priest   = { 1, 1, 1 },
    druid    = { 1, 0.49, 0.04 },
    shaman   = { 0, 0.44, 0.87 },
    paladin  = { 0.96, 0.55, 0.73 },
    procs    = { 0.5, 0.5, 0.5 },
}

-- Class order for sub-tabs (2 rows x 5)
local CLASS_ORDER = { "warrior", "rogue", "hunter", "mage", "warlock", "priest", "druid", "shaman", "paladin", "procs" }
local CLASS_LABELS = {
    warrior = "Warrior", rogue = "Rogue", hunter = "Hunter", mage = "Mage",
    warlock = "Warlock", priest = "Priest", druid = "Druid", shaman = "Shaman",
    paladin = "Paladin", procs = "Procs",
}

-- Keys per tab for Restore Section Settings
local GENERAL_KEYS = {
    "enabled", "clickthrough", "showbackdrop", "invertbars",
    "expandupwards", "showtargetindicator", "showraidicons", "showhealthbar",
    "showunitname", "alwaysshowcurrenttarget", "coloreddecimalduration",
}
local DISPLAY_KEYS = {
    "scale", "opacity", "fontscale", "maxcurses", "maxrow", "maxcol", "spacing", "debufficonspacing",
    "healthwidth", "height", "raidiconsize", "curseiconsize", "textsize",
    "cursetimersize", "cursetimeh", "cursetimev", "cursestacksize", "cursestackh",
    "cursestackv", "cursetimeyellow", "classcolordurationtimer", "cursestackyellow", "namelength",
}
local FILTER_KEYS = {
    "filtertarget", "filterincombat", "filterhostile", "filterattackable", "filterplayer",
    "filternotplayer", "filterrange", "filterraidmark", "filterhascurse",
    "filterignored", "ignorelistuseregex",
}

-- Default config values for Restore Section Settings
local DEFAULTS = {
    enabled = true, showtitle = false, clickthrough = true, showbackdrop = false,
    invertbars = false, expandupwards = false, showtargetindicator = false,
    showraidicons = true, showhealthbar = true, showunitname = true,
    alwaysshowcurrenttarget = false, coloreddecimalduration = false,
    scale = 1.0, opacity = 1.0, fontscale = 1.0,
    maxcurses = 14, maxrow = 8, maxcol = 1, spacing = 3, debufficonspacing = 1,
    healthwidth = 100, height = 18, raidiconsize = 18, curseiconsize = 18,
    textsize = 9, cursetimersize = 10, nameTextSize = 8,
    cursetimeh = 5, cursetimev = 5,
    cursestacksize = 9, cursestackh = 10, cursestackv = 10,
    cursetimeyellow = false, classcolordurationtimer = true, cursestackyellow = true,
    namelength = 60,
    anchor = "RIGHT", x = -147, y = 64,
    filtertarget = false,
    filterincombat = true, filterhostile = false, filterattackable = true,
    filterplayer = false, filternotplayer = false, filterrange = true,
    cctransparency = true,
    oorstripes = true,
    filterraidmark = false, filterhascurse = false, filterignored = false,
    ignorelistuseregex = false,
}

local MAIN_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    tile = true,
    tileSize = 16,
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}


-- ============================================================
-- 5a. Custom Tooltip Frame (avoids modifying GameTooltip globally)
-- ============================================================
local CursiveTooltip = CreateFrame("Frame", "CursiveOptionsTooltip", UIParent)
CursiveTooltip:SetFrameStrata("TOOLTIP")
CursiveTooltip:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
CursiveTooltip:SetBackdropColor(0, 0, 0, 1)
CursiveTooltip:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
CursiveTooltip:SetScale(0.9)
CursiveTooltip:Hide()

CursiveTooltip.title = CursiveTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CursiveTooltip.title:SetPoint("TOPLEFT", CursiveTooltip, "TOPLEFT", 8, -8)
CursiveTooltip.title:SetJustifyH("LEFT")

CursiveTooltip.lines = {}
for i = 1, 5 do
    local line = CursiveTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    line:SetJustifyH("LEFT")
    line:Hide()
    CursiveTooltip.lines[i] = line
end

local function CursiveTooltip_Show(anchorFrame, title, text)
    local maxWidth = 250
    local padding = 16
    local lineSpacing = 2
    local lineCount = 0
    local totalHeight = 8  -- top padding

    -- Title
    CursiveTooltip.title:ClearAllPoints()
    CursiveTooltip.title:SetPoint("TOPLEFT", CursiveTooltip, "TOPLEFT", 8, -8)
    if title then
        CursiveTooltip.title:SetText(title)
        CursiveTooltip.title:SetTextColor(1, 1, 0)
        CursiveTooltip.title:SetWidth(maxWidth - padding)
        CursiveTooltip.title:Show()
        totalHeight = totalHeight + CursiveTooltip.title:GetHeight() + lineSpacing
    else
        CursiveTooltip.title:Hide()
    end

    -- Hide all lines first
    for i = 1, 5 do
        CursiveTooltip.lines[i]:Hide()
    end

    -- Parse text lines (split on \n)
    if text and text ~= "" then
        local lineTexts = {}
        local remaining = text
        while remaining and remaining ~= "" do
            local nlPos = string.find(remaining, "\n")
            if nlPos then
                table.insert(lineTexts, string.sub(remaining, 1, nlPos - 1))
                remaining = string.sub(remaining, nlPos + 1)
            else
                table.insert(lineTexts, remaining)
                remaining = nil
            end
        end

        local hasMultiLine = (table.getn(lineTexts) > 1)

        for i, lt in ipairs(lineTexts) do
            if i > 5 then break end
            local line = CursiveTooltip.lines[i]
            line:ClearAllPoints()
            line:SetText(lt)
            line:SetWidth(maxWidth - padding)
            -- Anchor all lines to the frame directly at x=8, stacked by totalHeight
            line:SetPoint("TOPLEFT", CursiveTooltip, "TOPLEFT", 8, -totalHeight)
            if title and i == 1 and hasMultiLine then
                line:SetTextColor(1, 1, 0)  -- duration: yellow
            elseif title and i == 1 then
                line:SetTextColor(1, 1, 1)  -- simple description: white
            elseif title then
                line:SetTextColor(1, 1, 1)  -- effect: white
            else
                line:SetTextColor(1, 1, 1)
            end
            line:Show()
            totalHeight = totalHeight + line:GetHeight() + lineSpacing
            lineCount = i
        end
    end

    totalHeight = totalHeight + 8  -- bottom padding
    CursiveTooltip:SetWidth(maxWidth)
    CursiveTooltip:SetHeight(totalHeight)

    -- Position near cursor
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() * 0.9
    CursiveTooltip:ClearAllPoints()
    CursiveTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cx / scale) + 30, (cy / scale) - 12)
    CursiveTooltip:Show()
end

local function CursiveTooltip_Hide()
    CursiveTooltip:Hide()
end

-- ============================================================
-- 5. Helper: CreateScrollPanel (custom scrollbar, RollFor-style)
-- ============================================================
-- Returns: scrollFrame, scrollChild, slider, update_scroll_state
local function CreateScrollPanel(parent, name)
    -- ScrollFrame
    local sf = CreateFrame("ScrollFrame", name, parent)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Vertical slider on the right
    local slider = CreateFrame("Slider", name .. "Slider", sf)
    slider:SetOrientation("VERTICAL")
    slider:SetPoint("TOPLEFT", sf, "TOPRIGHT", -10, 0)
    slider:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 0)

    -- Track background (dark, matching theme)
    local track = slider:CreateTexture(name .. "SliderTrack", "BACKGROUND")
    track:SetTexture(0.08, 0.08, 0.08, 0.5)
    track:SetAllPoints(slider)

    -- Thumb: matching inactive tab color
    slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetWidth(10)
        thumb:SetHeight(80)
        thumb:SetTexture(0.15, 0.15, 0.15, 0.8)
    end

    -- update_scroll_state: recalculates slider range and thumb size proportionally
    local function update_scroll_state()
        local range = sf:GetVerticalScrollRange()
        slider:SetMinMaxValues(0, range)
        slider:SetValue(sf:GetVerticalScroll())
        local viewH = sf:GetHeight()
        local totalH = viewH + range
        if totalH > 0 then
            local ratio = viewH / totalH
            if ratio < 1 then
                local size = floor(viewH * ratio)
                if size < 30 then size = 30 end
                if thumb then thumb:SetHeight(size) end
                slider:Show()
            else
                slider:Hide()
            end
        else
            slider:Hide()
        end
    end

    sf.update_scroll_state = update_scroll_state

    -- OnValueChanged: sync scroll position
    slider:SetScript("OnValueChanged", function()
        sf:SetVerticalScroll(this:GetValue())
        update_scroll_state()
    end)

    -- Mouse wheel scrolling
    sf:EnableMouseWheel(1)
    sf:SetScript("OnMouseWheel", function()
        local current = sf:GetVerticalScroll()
        local maxVal = sf:GetVerticalScrollRange()
        local step = 20
        local newVal = current - (arg1 * step)
        if newVal < 0 then newVal = 0 end
        if newVal > maxVal then newVal = maxVal end
        sf:SetVerticalScroll(newVal)
        update_scroll_state()
    end)

    -- ScrollChild
    local child = CreateFrame("Frame", name .. "Child", sf)
    child:SetWidth(1)
    child:SetHeight(1)
    sf:SetScrollChild(child)

    -- OnUpdate on child: keep scroll state in sync (change-detection to avoid per-frame work)
    child:SetScript("OnUpdate", function()
        local h = child:GetHeight()
        if child._lastH == h then return end
        child._lastH = h
        update_scroll_state()
    end)

    return sf, child, slider, update_scroll_state
end


-- ============================================================
-- 6. Helper: CreateRow — creates a single options row
-- ============================================================
-- widget types: "header", "checkbox", "debuff_checkbox", "slider", "button"
-- Returns: rowFrame, newYOffset
local function CreateRow(scrollChild, globalPrefix, yOffset, label, widget, configKey, options)
    options = options or {}

    local rowName = globalPrefix
    local rowHeight = ROW_HEIGHT
    local spacing = ROW_SPACING

    if widget == "header" then
        rowHeight = HEADER_HEIGHT
    elseif widget == "slider" then
        rowHeight = SLIDER_ROW_HEIGHT
        spacing = SLIDER_ROW_SPACING
    end

    -- Extra top margin for non-first headers
    if widget == "header" and yOffset < -5 then
        yOffset = yOffset - HEADER_EXTRA_TOP
    end

    local row = CreateFrame("Frame", rowName, scrollChild)
    row:SetWidth(CONTENT_WIDTH)
    row:SetHeight(rowHeight)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)

    if widget == "header" then
        -- Gold/Yellow section header — aligned with slider start
        local headerText = row:CreateFontString(rowName .. "HeaderText", "ARTWORK", "GameFontNormal")
        headerText:SetPoint("LEFT", row, "LEFT", options.headerIndent or 16, 0)
        headerText:SetJustifyH("LEFT")
        headerText:SetText(label)
        headerText:SetTextColor(1, 0.82, 0, 1)  -- Gold/Gelb
        -- Increase header text size by 1px, bold outline
        local font, size, flags = headerText:GetFont()
        headerText:SetFont(font, size + 1, "OUTLINE")
        return row, yOffset - rowHeight - ROW_SPACING
    end

    -- Hover highlight
    local highlight = row:CreateTexture(rowName .. "Highlight", "BACKGROUND")
    highlight:SetTexture(1, 1, 1, 0.05)
    highlight:SetAllPoints(row)
    highlight:Hide()

    row:EnableMouse(true)
    row:SetScript("OnEnter", function()
        getglobal(this:GetName() .. "Highlight"):Show()
        if this.tooltipText and this.tooltipText ~= "" then
            local title = nil
            if this.tooltipTitle then
                local cleanTitle = this.tooltipTitle
                local paren = string.find(cleanTitle, " |c")
                if not paren then paren = string.find(cleanTitle, " %(") end
                if paren then cleanTitle = string.sub(cleanTitle, 1, paren - 1) end
                title = cleanTitle
            end
            CursiveTooltip_Show(this, title, this.tooltipText)
        end
    end)
    row:SetScript("OnLeave", function()
        getglobal(this:GetName() .. "Highlight"):Hide()
        CursiveTooltip_Hide()
    end)
    row.tooltipText = options.tooltipText or ""
    row.tooltipTitle = label

    if widget == "checkbox" then
        -- Label on the left (margin 16, or indented if checkboxIndent given)
        local cbIndent = (options and options.checkboxIndent) or 0
        local labelText = row:CreateFontString(rowName .. "Label", "ARTWORK", "GameFontHighlightSmall")
        if options and options.sliderAlign then
            labelText:SetPoint("LEFT", row, "LEFT", SLIDER_X_OFFSET, 0)
        else
            labelText:SetPoint("LEFT", row, "LEFT", 16 + cbIndent, 0)
        end
        labelText:SetJustifyH("LEFT")
        labelText:SetText(label)
        -- Increase text size by 1px
        local font, size, flags = labelText:GetFont()
        labelText:SetFont(font, size + 1, flags)

        -- Checkbox on the right (margin -16, or aligned with slider end if checkboxIndent/sliderAlign)
        local cb = CreateFrame("CheckButton", rowName .. "Check", row, "OptionsCheckButtonTemplate")
        cb:SetWidth(22)
        cb:SetHeight(22)
        if cbIndent > 0 then
            cb:SetPoint("LEFT", row, "LEFT", cbIndent + SLIDER_WIDTH - 6, 0)
        elseif options and options.sliderAlign then
            cb:SetPoint("RIGHT", row, "LEFT", SLIDER_X_OFFSET + SLIDER_WIDTH + 16, 0)
        else
            cb:SetPoint("RIGHT", row, "RIGHT", -16, 0)
        end
        cb:SetHitRectInsets(0, 0, 0, 0)

        -- Hide template text
        local cbText = getglobal(rowName .. "CheckText")
        if cbText then cbText:SetText("") end

        cb.configKey = configKey
        cb:SetScript("OnClick", function()
            CursiveOpts.ToggleOption(this.configKey)
        end)

        -- Initialize checkbox state from config
        if Cursive and Cursive.db and Cursive.db.profile and configKey then
            local val = Cursive.db.profile[configKey]
            if val ~= nil then
                cb:SetChecked(val and true or false)
            end
        end

        row.checkbox = cb
        return row, yOffset - rowHeight - spacing

    elseif widget == "debuff_checkbox" then
        -- Like checkbox but reads/writes Cursive.db.profile.shareddebuffs[key]
        -- v3.2: Show spell icon before label
        local iconSize = rowHeight - 4
        local iconOffset = 18
        local labelOffset = iconOffset + iconSize + 4  -- icon + gap

        -- Try to get spell texture from shared debuffs data via SpellInfo(spellID)
        local iconTexture = nil
        if configKey and Cursive.curses and Cursive.curses.sharedDebuffs and Cursive.curses.sharedDebuffs[configKey] then
            for spellID, _ in pairs(Cursive.curses.sharedDebuffs[configKey]) do
                local _, _, tex = SpellInfo(spellID)
                if tex then
                    iconTexture = tex
                    break
                end
            end
        end

        if iconTexture then
            local icon = row:CreateTexture(rowName .. "Icon", "ARTWORK")
            icon:SetWidth(iconSize)
            icon:SetHeight(iconSize)
            icon:SetPoint("LEFT", row, "LEFT", iconOffset, 0)
            icon:SetTexture(iconTexture)
            icon:SetTexCoord(0.078, 0.92, 0.079, 0.937)  -- crop icon border
        else
            -- No icon found — use standard indent
            labelOffset = iconOffset
        end

        local labelText = row:CreateFontString(rowName .. "Label", "ARTWORK", "GameFontHighlightSmall")
        labelText:SetPoint("LEFT", row, "LEFT", labelOffset, 0)
        labelText:SetJustifyH("LEFT")
        labelText:SetText(label)
        -- Increase text size by 1px
        local font, size, flags = labelText:GetFont()
        labelText:SetFont(font, size + 1, flags)

        local cb = CreateFrame("CheckButton", rowName .. "Check", row, "OptionsCheckButtonTemplate")
        cb:SetWidth(22)
        cb:SetHeight(22)
        cb:SetPoint("RIGHT", row, "RIGHT", -16, 0)
        cb:SetHitRectInsets(0, 0, 0, 0)

        local cbText = getglobal(rowName .. "CheckText")
        if cbText then cbText:SetText("") end

        cb.configKey = configKey
        cb:SetScript("OnClick", function()
            CursiveOpts.ToggleDebuff(this.configKey)
        end)

        -- Tooltip from debuffDescriptions
        if options.tooltipText and options.tooltipText ~= "" then
            row.tooltipText = options.tooltipText
        end

        row.checkbox = cb
        return row, yOffset - rowHeight - spacing

    elseif widget == "slider" then
        -- Left-aligned label on top, aligned with slider start
        local sliderW = SLIDER_WIDTH
        local sliderXOffset = SLIDER_X_OFFSET

        local labelText = row:CreateFontString(rowName .. "Label", "ARTWORK", "GameFontHighlightSmall")
        labelText:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -2)
        labelText:SetJustifyH("LEFT")
        labelText:SetText(label)

        -- Slider below label, aligned with label start
        local sl = CreateFrame("Slider", rowName .. "Slider", row, "OptionsSliderTemplate")
        sl:SetWidth(sliderW)
        sl:SetHeight(17)
        sl:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -18)

        sl:SetMinMaxValues(options.min or 0, options.max or 1)
        sl:SetValueStep(options.step or 1)
        sl.tooltipText = options.tooltipText or ""

        -- Set Low/High labels
        local slLow = getglobal(rowName .. "SliderLow")
        local slHigh = getglobal(rowName .. "SliderHigh")
        local slText = getglobal(rowName .. "SliderText")
        if slLow then slLow:SetText(format(options.fmt or "%s", options.min or 0)) end
        if slHigh then slHigh:SetText(format(options.fmt or "%s", options.max or 1)) end
        if slText then slText:SetText("") end

        -- Move Low/High labels 3px further down
        if slLow then
            slLow:ClearAllPoints()
            slLow:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 0, -3)
        end
        if slHigh then
            slHigh:ClearAllPoints()
            slHigh:SetPoint("TOPRIGHT", sl, "BOTTOMRIGHT", 0, -3)
        end

        sl.configKey = configKey
        sl.fmt = options.fmt or "%s"
        sl.labelText = labelText
        sl.labelBase = label

        sl:SetScript("OnValueChanged", function()
            CursiveOpts.OnSliderChanged(this.configKey, this, this.fmt)
        end)

        -- v3.2.1: Disable OptionsSliderTemplate's built-in GameTooltip
        -- (conflicts with row's CursiveTooltip — shows old/different tooltip on hover)
        sl:SetScript("OnEnter", function()
            getglobal(this:GetParent():GetName() .. "Highlight"):Show()
            local parentRow = this:GetParent()
            if parentRow and parentRow.tooltipText and parentRow.tooltipText ~= "" then
                CursiveTooltip_Show(parentRow, parentRow.tooltipTitle, parentRow.tooltipText)
            end
        end)
        sl:SetScript("OnLeave", function()
            getglobal(this:GetParent():GetName() .. "Highlight"):Hide()
            CursiveTooltip_Hide()
        end)

        row.slider = sl
        row.labelText = labelText

        return row, yOffset - rowHeight - spacing

    elseif widget == "button" then
        local btn = CreateFrame("Button", rowName .. "Btn", row, "UIPanelButtonTemplate")
        btn:SetHeight(20)
        btn:SetText(label)
        if options.onClick then
            btn:SetScript("OnClick", options.onClick)
        end
        -- Reduce button font size by 2px, then auto-fit width to text
        local btnFS = btn:GetFontString()
        if btnFS then
            local font, size, flags = btnFS:GetFont()
            btnFS:SetFont(font, size - 2, flags)
            btn:SetWidth(btnFS:GetStringWidth() + 24)
        else
            btn:SetWidth(options.buttonWidth or 100)
        end
        if options.align == "left" then
            btn:SetPoint("LEFT", row, "LEFT", 16, 0)
        else
            btn:SetPoint("CENTER", row, "CENTER", 0, 0)
        end
        row.button = btn
        return row, yOffset - rowHeight - spacing
    end

    -- Fallback: plain label row
    local labelText = row:CreateFontString(rowName .. "Label", "ARTWORK", "GameFontHighlightSmall")
    labelText:SetPoint("LEFT", row, "LEFT", 16, 0)
    labelText:SetText(label)
    return row, yOffset - rowHeight - spacing
end


-- ============================================================
-- 7. Helper: GetOptionsData
-- ============================================================
local function GetOptionsData()
    if Cursive and Cursive.optionsData then
        return Cursive.optionsData
    end
    return nil
end

-- Helper: Get debuff tooltip text
local function GetDebuffTooltip(debuffKey)
    local data = GetOptionsData()
    if not data or not data.debuffDescriptions then return "" end
    return data.debuffDescriptions[debuffKey] or ""
end


-- ############################################################
-- 8. FRAME CREATION (file scope — runs immediately on load)
-- ############################################################

-- ============================================================
-- 8a. Main Options Frame (340x500)
-- ============================================================
local mainFrame = CreateFrame("Frame", "CursiveOptionsFrame", UIParent)
mainFrame:SetWidth(FRAME_WIDTH)
mainFrame:SetHeight(FRAME_HEIGHT)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
mainFrame:SetFrameStrata("DIALOG")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:SetClampedToScreen(true)
mainFrame:Hide()
mainFrame:SetToplevel(true)
mainFrame:SetBackdrop(MAIN_BACKDROP)
mainFrame:SetBackdropColor(0, 0, 0, 0.85)

-- Title background overlay (darker)
local titleBG = CreateFrame("Frame", nil, mainFrame)
titleBG:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
titleBG:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
titleBG:SetHeight(TAB_HEIGHT)
titleBG:SetFrameLevel(mainFrame:GetFrameLevel() + 1)
local titleBGTex = titleBG:CreateTexture(nil, "BACKGROUND")
titleBGTex:SetAllPoints(titleBG)
titleBGTex:SetTexture(0, 0, 0, 0.95)

-- Title (on its own frame above titleBG so it isn't hidden by the overlay)
local titleFrame = CreateFrame("Frame", nil, mainFrame)
titleFrame:SetAllPoints(titleBG)
titleFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 2)
local title = titleFrame:CreateFontString("CursiveOptionsTitle", "ARTWORK", "GameFontNormalLarge")
title:SetPoint("CENTER", titleFrame, "CENTER", 0, 0)
title:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
title:SetText("Cursive Raid")
-- Version number (smaller, to the right of title)
local versionText = titleFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
versionText:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 3, 1)
versionText:SetFont(STANDARD_TEXT_FONT, 8, "")
versionText:SetText("v4.0.3")
versionText:SetTextColor(1, 1, 1)

-- Close button (scaled to fit title bar, 1px from edges)
local closeBtn = CreateFrame("Button", "CursiveOptionsCloseButton", titleFrame, "UIPanelCloseButton")
closeBtn:SetWidth(20)
closeBtn:SetHeight(20)
closeBtn:SetScale(1.05)
closeBtn:ClearAllPoints()
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -1 / 1.05, -1 / 1.05)
closeBtn:SetScript("OnClick", function() CursiveOptionsFrame:Hide() end)

-- ESC to close
tinsert(UISpecialFrames, "CursiveOptionsFrame")

-- Dragging
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
mainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

-- OnShow -> Initialize + select tab 1
mainFrame:SetScript("OnShow", function()
    if CursiveOpts.Initialize then CursiveOpts.Initialize() end
    if CursiveOpts.SelectTab then CursiveOpts.SelectTab(1) end
end)


-- ============================================================
-- 8b. Tab Buttons (5 frameless rectangle tabs)
-- ============================================================
local prevTab = nil

for i = 1, TAB_COUNT do
    local tabName = tabButtonNames[i]
    local tab = CreateFrame("Button", tabName, mainFrame)
    tab:SetWidth(TAB_WIDTH)
    tab:SetHeight(TAB_HEIGHT)
    tab:EnableMouse(true)

    if i == 1 then
        tab:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, -(TAB_HEIGHT + 2))
    else
        tab:SetPoint("LEFT", prevTab, "RIGHT", TAB_GAP, 0)
    end

    -- Background texture (inactive)
    local bg = tab:CreateTexture(tabName .. "BG", "BACKGROUND")
    bg:SetTexture(0.15, 0.15, 0.15, 0.8)
    bg:SetAllPoints(tab)

    -- Text (GameFontNormalSmall for smaller text)
    local tabText = tab:CreateFontString(tabName .. "Text", "ARTWORK", "GameFontNormalSmall")
    tabText:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tabText:SetText(tabLabels[i])

    -- Hover effects
    tab:SetScript("OnEnter", function()
        local bgTex = getglobal(this:GetName() .. "BG")
        if this.tabIndex ~= selectedTab then
            bgTex:SetTexture(0.3, 0.3, 0.3, 1)
        end
        getglobal(this:GetName() .. "Text"):SetTextColor(1, 1, 1)
    end)
    tab:SetScript("OnLeave", function()
        local bgTex = getglobal(this:GetName() .. "BG")
        if this.tabIndex ~= selectedTab then
            bgTex:SetTexture(0.15, 0.15, 0.15, 0.8)
        end
        getglobal(this:GetName() .. "Text"):SetTextColor(0.82, 0.82, 0.82)
    end)

    tab.tabIndex = i
    tab:SetScript("OnClick", function()
        CursiveOpts.SelectTab(this.tabIndex)
    end)

    prevTab = tab
end


-- ============================================================
-- 8c. "Restore Section Settings" button at BOTTOM of mainFrame
-- ============================================================
-- Toggle All button (only visible on Raid + Class tabs)
local toggleAllBtn = CreateFrame("Button", "CursiveToggleAllBtn", mainFrame, "UIPanelButtonTemplate")
toggleAllBtn:SetHeight(20)
toggleAllBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 26, 24)
toggleAllBtn:SetText("Enable All")
toggleAllBtn:Hide()
toggleAllBtn:SetScript("OnClick", function()
    CursiveOpts.ToggleAll()
end)
do
    local fs = toggleAllBtn:GetFontString()
    if fs then
        local font, size, flags = fs:GetFont()
        fs:SetFont(font, size - 2, flags)
        toggleAllBtn:SetWidth(fs:GetStringWidth() + 24)
    end
end

local resetFrameBtn = CreateFrame("Button", "CursiveResetFrameBtn", mainFrame, "UIPanelButtonTemplate")
resetFrameBtn:SetHeight(20)
resetFrameBtn:SetText("Reset UI Frames")
do local fs = resetFrameBtn:GetFontString(); if fs then local w = fs:GetStringWidth(); resetFrameBtn:SetWidth(w + 24) end end
do local fs = resetFrameBtn:GetFontString(); if fs then local f,s,fl = fs:GetFont(); fs:SetFont(f,s-2,fl) end end
resetFrameBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 26, 24)
resetFrameBtn:SetScript("OnClick", function()
    local p = Cursive.db.profile
    p.anchor = "CENTER"
    p.x = 0
    p.y = 0
    if Cursive.UpdateFramesFromConfig then Cursive.UpdateFramesFromConfig() end
end)

-- v3.2.1: Restore Section button removed (will be replaced by Profile system)


-- ============================================================
-- 8d. Panel containers (one per tab)
-- ============================================================
-- Panels sit between tabs and the restore button
local PANEL_TOP_OFFSET = -48   -- below tabs (22 title + 2 gap + 22 tabs + 2 gap)
local PANEL_BOTTOM_OFFSET = 62 -- above bottom buttons

-- General Panel
local generalPanel = CreateFrame("Frame", "CursiveGeneralPanel", mainFrame)
generalPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, PANEL_TOP_OFFSET)
generalPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, PANEL_BOTTOM_OFFSET)
generalPanel:Hide()

-- Display Panel (no bottom buttons → 16px more space)
local displayPanel = CreateFrame("Frame", "CursiveDisplayPanel", mainFrame)
displayPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, PANEL_TOP_OFFSET)
displayPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, PANEL_BOTTOM_OFFSET - 16)
displayPanel:Hide()

-- Raid Panel
local raidPanel = CreateFrame("Frame", "CursiveRaidPanel", mainFrame)
raidPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, PANEL_TOP_OFFSET)
raidPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, PANEL_BOTTOM_OFFSET)
raidPanel:Hide()

-- Class Panel (flush with mainFrame edges so sub-tabs align with main tabs)
local classPanel = CreateFrame("Frame", "CursiveClassPanel", mainFrame)
classPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, PANEL_TOP_OFFSET)
classPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, PANEL_BOTTOM_OFFSET)
classPanel:Hide()

-- Filter Panel
local filterPanel = CreateFrame("Frame", "CursiveFilterPanel", mainFrame)
filterPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, PANEL_TOP_OFFSET)
filterPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, PANEL_BOTTOM_OFFSET)
filterPanel:Hide()


-- ============================================================
-- 8e. Tab 1: General (Checkboxes)
-- ============================================================
local genSF, genChild = CreateScrollPanel(generalPanel, "CursiveGeneralScroll")
local y = -8
local _

-- Header: Addon
_, y = CreateRow(genChild, "CursiveGenHdrAddon", y, "Addon", "header")

_, y = CreateRow(genChild, "CursiveOptEnabled", y, "Enabled", "checkbox", "enabled",
    { tooltipText = "Enable or disable Cursive" })

_, y = CreateRow(genChild, "CursiveOptMove", y, "Move UI Frame", "checkbox", "move_special",
    { tooltipText = "Enable to move and show frame background. Disable to lock." })

_, y = CreateRow(genChild, "CursiveOptTestOverlay", y, "Test Overlay", "checkbox", "testoverlay_special",
    { tooltipText = "Show fake raid targets with debuffs for live UI preview. Disable to clear." })

-- Header: Display
_, y = CreateRow(genChild, "CursiveGenHdrDisplay", y, "Display", "header")

_, y = CreateRow(genChild, "CursiveOptHealthBar", y, "Show Health Bar", "checkbox", "showhealthbar",
    { tooltipText = "Show unit health bars" })

_, y = CreateRow(genChild, "CursiveOptUnitName", y, "Show Unit Name", "checkbox", "showunitname",
    { tooltipText = "Show unit name text" })

_, y = CreateRow(genChild, "CursiveOptRaidIcons", y, "Show Raid Icons", "checkbox", "showraidicons",
    { tooltipText = "Show raid target icons" })

_, y = CreateRow(genChild, "CursiveOptInvertBars", y, "Invert Bar Layout", "checkbox", "invertbars",
    { tooltipText = "Show sections in reverse order" })

_, y = CreateRow(genChild, "CursiveOptExpandUp", y, "Reverse Bars Upwards", "checkbox", "expandupwards",
    { tooltipText = "Make bars expand upwards instead of downwards" })

_, y = CreateRow(genChild, "CursiveOptAlwaysTarget", y, "Always Show Current Target", "checkbox", "alwaysshowcurrenttarget",
    { tooltipText = "Always show current target at bottom of mob list" })

_, y = CreateRow(genChild, "CursiveOptCCTransparency", y, "CC / Reflect Transparency", "checkbox", "cctransparency",
    { tooltipText = "Show CC'd (banished, polymorphed) and Spell Reflect targets as transparent. Reflect targets also show the reflected spell school (e.g. 'Reflect: Fire/Arcane')" })

_, y = CreateRow(genChild, "CursiveOptOORStripes", y, "Out-of-Range / Line-of-Sight Stripes", "checkbox", "oorstripes",
    { tooltipText = "Show diagonal stripes on health bars of targets outside cast range or not in line of sight (requires UnitXP SP3 for LoS detection)" })

-- ============================================================
-- Helper: CreateBorderDropdown (reusable pfUI-style dropdown)
-- ============================================================
local borderDropButtons = {}

local function CreateBorderDropdown(parent, globalName, labelText, configKey, yOffset, tooltipText)
    local dropOptions = { "off", "green", "red", "black", "classcolor" }
    local dropLabels = { "Off", "Green", "Red", "Black", "Classcolor" }
    local dropColors = {
        off        = { 0.65, 0.65, 0.65 },
        green      = { 0, 0.8, 0 },
        red        = { 0.8, 0, 0 },
        black      = { 0.4, 0.4, 0.4 },
        classcolor = { 1, 0.82, 0 },
    }

    local row = CreateFrame("Frame", globalName .. "Row", parent)
    row:SetWidth(CONTENT_WIDTH)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:EnableMouse(false)

    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 16, 0)
    lbl:SetText(labelText)

    local dropWidth = 100
    local dropBtn = CreateFrame("Button", globalName .. "Drop", row)
    dropBtn:SetWidth(dropWidth)
    dropBtn:SetHeight(ROW_HEIGHT - 2)
    dropBtn:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    dropBtn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dropBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    dropBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropText:SetPoint("CENTER", dropBtn, "CENTER", -6, 0)
    dropText:SetJustifyH("CENTER")

    local arrow = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.7, 0.7, 0.7)

    local menuFrame = CreateFrame("Frame", globalName .. "Menu", UIParent)
    menuFrame:SetFrameStrata("FULLSCREEN")
    menuFrame:SetWidth(dropWidth)
    menuFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    menuFrame:Hide()
    menuFrame:EnableMouse(true)

    menuFrame:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + 0.05
        if not MouseIsOver(menuFrame, 10, -10, -10, 10) and not MouseIsOver(dropBtn) then
            menuFrame:Hide()
        end
    end)

    local function GetCurrentValue()
        local val = "off"
        if Cursive and Cursive.db and Cursive.db.profile then
            val = Cursive.db.profile[configKey] or "off"
        end
        if val == true then val = "green" end
        if val == false then val = "off" end
        return val
    end

    local function UpdateDisplay()
        local val = GetCurrentValue()
        local cc = dropColors[val] or dropColors["off"]
        for i = 1, table.getn(dropOptions) do
            if dropOptions[i] == val then
                dropText:SetText(dropLabels[i])
                break
            end
        end
        dropText:SetTextColor(cc[1], cc[2], cc[3])
    end

    local entryHeight = 20
    menuFrame:SetHeight(table.getn(dropOptions) * entryHeight + 4)
    menuFrame.entries = {}

    for i = 1, table.getn(dropOptions) do
        local entry = CreateFrame("Button", nil, menuFrame)
        entry:SetHeight(entryHeight)
        entry:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 2, -((i - 1) * entryHeight) - 2)
        entry:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -2, -((i - 1) * entryHeight) - 2)

        local entryText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        entryText:SetPoint("LEFT", entry, "LEFT", 6, 0)
        entryText:SetText(dropLabels[i])
        local ec = dropColors[dropOptions[i]]
        entryText:SetTextColor(ec[1], ec[2], ec[3])

        local check = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        check:SetPoint("RIGHT", entry, "RIGHT", -6, 0)
        check:SetText("")
        entry.check = check

        local hover = entry:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints(entry)
        hover:SetTexture(1, 1, 1, 0.08)
        hover:Hide()

        entry:SetScript("OnEnter", function() hover:Show() end)
        entry:SetScript("OnLeave", function() hover:Hide() end)

        local optionValue = dropOptions[i]
        entry:SetScript("OnClick", function()
            if Cursive and Cursive.db and Cursive.db.profile then
                Cursive.db.profile[configKey] = optionValue
            end
            UpdateDisplay()
            menuFrame:Hide()
            for j = 1, table.getn(dropOptions) do
                local e = menuFrame.entries[j]
                if e and e.check then
                    e.check:SetText(dropOptions[j] == optionValue and "|cFFFFFFFF\226\156\147|r" or "")
                end
            end
            if Cursive and Cursive.UpdateFrames then Cursive:UpdateFrames() end
        end)

        menuFrame.entries[i] = entry
    end

    dropBtn:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:ClearAllPoints()
            menuFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
            menuFrame:SetPoint("TOPRIGHT", dropBtn, "BOTTOMRIGHT", 0, -2)
            local val = GetCurrentValue()
            for i = 1, table.getn(dropOptions) do
                local e = menuFrame.entries[i]
                if e and e.check then
                    e.check:SetText(dropOptions[i] == val and "|cFFFFFFFF\226\156\147|r" or "")
                end
            end
            menuFrame:Show()
        end
    end)

    dropBtn:SetScript("OnEnter", function()
        this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    dropBtn:SetScript("OnLeave", function()
        this:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    end)

    dropBtn.Refresh = UpdateDisplay
    borderDropButtons[configKey] = dropBtn

    -- v3.2.1: Add tooltip to row if provided
    if tooltipText and tooltipText ~= "" then
        row:EnableMouse(true)
        row.tooltipText = tooltipText
        row.tooltipTitle = labelText
        row:SetScript("OnEnter", function()
            CursiveTooltip_Show(this, this.tooltipTitle, this.tooltipText)
        end)
        row:SetScript("OnLeave", function()
            CursiveTooltip_Hide()
        end)
    end

    return yOffset - ROW_HEIGHT - ROW_SPACING
end

-- Header: Debuff Border
_, y = CreateRow(genChild, "CursiveGenHdrDebuffFrames", y, "Debuff Border", "header", nil, { headerIndent = 15 })

y = CreateBorderDropdown(genChild, "CursiveOptBorderOwnClass", "Own Class Debuffs", "borderownclass", y,
    "Border color for your own class debuffs (DoTs, personal spells)")
y = CreateBorderDropdown(genChild, "CursiveOptBorderOwnRaid", "Own Raid Debuffs", "borderownraid", y,
    "Border color for your own raid-relevant debuffs (Sunder, Faerie Fire, etc.)")
y = CreateBorderDropdown(genChild, "CursiveOptBorderOtherClass", "Class Debuffs", "borderotherclass", y,
    "Border color for other players' class debuffs")
y = CreateBorderDropdown(genChild, "CursiveOptBorderOtherRaid", "Raid Debuffs", "borderotherraid", y,
    "Border color for other players' raid-relevant debuffs")

-- Spacing between color dropdowns and width/opacity controls
y = y - 8

-- Frame Width dropdown (1px, 2px, 3px)
do
    local widthOptions = { 1, 2, 3 }
    local widthLabels = { "1px", "2px", "3px" }

    local row = CreateFrame("Frame", "CursiveOptBorderWidthRow", genChild)
    row:SetWidth(CONTENT_WIDTH)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", genChild, "TOPLEFT", 0, y)
    row:EnableMouse(false)

    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 16, 0)
    lbl:SetText("Frame Width")

    local dropWidth = 100
    local dropBtn = CreateFrame("Button", "CursiveOptBorderWidthDrop", row)
    dropBtn:SetWidth(dropWidth)
    dropBtn:SetHeight(ROW_HEIGHT - 2)
    dropBtn:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    dropBtn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dropBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    dropBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropText:SetPoint("CENTER", dropBtn, "CENTER", -6, 0)
    dropText:SetJustifyH("CENTER")

    local arrow = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.7, 0.7, 0.7)

    local menuFrame = CreateFrame("Frame", "CursiveOptBorderWidthMenu", UIParent)
    menuFrame:SetFrameStrata("FULLSCREEN")
    menuFrame:SetWidth(dropWidth)
    menuFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    menuFrame:Hide()
    menuFrame:EnableMouse(true)

    menuFrame:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + 0.05
        if not MouseIsOver(menuFrame, 10, -10, -10, 10) and not MouseIsOver(dropBtn) then
            menuFrame:Hide()
        end
    end)

    local function GetCurrentWidth()
        if Cursive and Cursive.db and Cursive.db.profile then
            return Cursive.db.profile.borderwidth or 2
        end
        return 2
    end

    local function UpdateWidthDisplay()
        local val = GetCurrentWidth()
        dropText:SetText(val .. "px")
        dropText:SetTextColor(1, 1, 1)
    end

    local entryHeight = 20
    menuFrame:SetHeight(table.getn(widthOptions) * entryHeight + 4)
    menuFrame.entries = {}

    for i = 1, table.getn(widthOptions) do
        local entry = CreateFrame("Button", nil, menuFrame)
        entry:SetHeight(entryHeight)
        entry:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 2, -((i - 1) * entryHeight) - 2)
        entry:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -2, -((i - 1) * entryHeight) - 2)

        local entryText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        entryText:SetPoint("LEFT", entry, "LEFT", 6, 0)
        entryText:SetText(widthLabels[i])
        entryText:SetTextColor(1, 1, 1)

        local check = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        check:SetPoint("RIGHT", entry, "RIGHT", -6, 0)
        check:SetText("")
        entry.check = check

        local hover = entry:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints(entry)
        hover:SetTexture(1, 1, 1, 0.08)
        hover:Hide()

        entry:SetScript("OnEnter", function() hover:Show() end)
        entry:SetScript("OnLeave", function() hover:Hide() end)

        local optVal = widthOptions[i]
        entry:SetScript("OnClick", function()
            if Cursive and Cursive.db and Cursive.db.profile then
                Cursive.db.profile.borderwidth = optVal
            end
            UpdateWidthDisplay()
            menuFrame:Hide()
            for j = 1, table.getn(widthOptions) do
                local e = menuFrame.entries[j]
                if e and e.check then
                    e.check:SetText(widthOptions[j] == optVal and "|cFFFFFFFF\226\156\147|r" or "")
                end
            end
            if Cursive and Cursive.UpdateFramesFromConfig then Cursive.UpdateFramesFromConfig() end
        end)

        menuFrame.entries[i] = entry
    end

    dropBtn:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:ClearAllPoints()
            menuFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
            menuFrame:SetPoint("TOPRIGHT", dropBtn, "BOTTOMRIGHT", 0, -2)
            local val = GetCurrentWidth()
            for i = 1, table.getn(widthOptions) do
                local e = menuFrame.entries[i]
                if e and e.check then
                    e.check:SetText(widthOptions[i] == val and "|cFFFFFFFF\226\156\147|r" or "")
                end
            end
            menuFrame:Show()
        end
    end)

    dropBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
    dropBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) end)

    dropBtn.Refresh = UpdateWidthDisplay
    borderDropButtons["borderwidth"] = dropBtn

    y = y - ROW_HEIGHT - ROW_SPACING
end

y = y - 6

-- Frame Opacity slider (0-100)
_, y = CreateRow(genChild, "CursiveOptBorderOpacity", y, "Frame Opacity", "slider", "borderopacity",
    { min = 0, max = 100, step = 1, fmt = "%d%%", tooltipText = "Opacity of debuff border frames (0-100%)" })

-- ============================================================
-- Debuff Timer section
-- ============================================================
_, y = CreateRow(genChild, "CursiveGenHdrDebuffTimer", y, "Debuff Timer", "header", nil, { headerIndent = 15 })

-- Helper: CreateTimerColorDropdown (White/Yellow/Classcolor)
local timerDropButtons = {}

local function CreateTimerColorDropdown(parent, globalName, labelText, configKey, yOffset, tooltipText)
    local dropOptions = { "none", "white", "yellow", "classcolor" }
    local dropLabels = { "None", "White", "Yellow", "Classcolor" }
    local dropColors = {
        none       = { 0.65, 0.65, 0.65 },
        white      = { 1, 1, 1 },
        yellow     = { 1, 1, 0 },
        classcolor = { 1, 0.82, 0 },
    }

    local row = CreateFrame("Frame", globalName .. "Row", parent)
    row:SetWidth(CONTENT_WIDTH)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    row:EnableMouse(false)

    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 16, 0)
    lbl:SetText(labelText)

    local dropWidth = 100
    local dropBtn = CreateFrame("Button", globalName .. "Drop", row)
    dropBtn:SetWidth(dropWidth)
    dropBtn:SetHeight(ROW_HEIGHT - 2)
    dropBtn:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    dropBtn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dropBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    dropBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropText:SetPoint("CENTER", dropBtn, "CENTER", -6, 0)
    dropText:SetJustifyH("CENTER")

    local arrow = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.7, 0.7, 0.7)

    local menuFrame = CreateFrame("Frame", globalName .. "Menu", UIParent)
    menuFrame:SetFrameStrata("FULLSCREEN")
    menuFrame:SetWidth(dropWidth)
    menuFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    menuFrame:Hide()
    menuFrame:EnableMouse(true)

    menuFrame:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + 0.05
        if not MouseIsOver(menuFrame, 10, -10, -10, 10) and not MouseIsOver(dropBtn) then
            menuFrame:Hide()
        end
    end)

    local function GetCurrentValue()
        local val = "white"
        if Cursive and Cursive.db and Cursive.db.profile then
            val = Cursive.db.profile[configKey] or "white"
        end
        return val
    end

    local function UpdateDisplay()
        local val = GetCurrentValue()
        local cc = dropColors[val] or dropColors["white"]
        for i = 1, table.getn(dropOptions) do
            if dropOptions[i] == val then
                dropText:SetText(dropLabels[i])
                break
            end
        end
        dropText:SetTextColor(cc[1], cc[2], cc[3])
    end

    local entryHeight = 20
    menuFrame:SetHeight(table.getn(dropOptions) * entryHeight + 4)
    menuFrame.entries = {}

    for i = 1, table.getn(dropOptions) do
        local entry = CreateFrame("Button", nil, menuFrame)
        entry:SetHeight(entryHeight)
        entry:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 2, -((i - 1) * entryHeight) - 2)
        entry:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -2, -((i - 1) * entryHeight) - 2)

        local entryText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        entryText:SetPoint("LEFT", entry, "LEFT", 6, 0)
        entryText:SetText(dropLabels[i])
        local ec = dropColors[dropOptions[i]]
        entryText:SetTextColor(ec[1], ec[2], ec[3])

        local check = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        check:SetPoint("RIGHT", entry, "RIGHT", -6, 0)
        check:SetText("")
        entry.check = check

        local hover = entry:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints(entry)
        hover:SetTexture(1, 1, 1, 0.08)
        hover:Hide()

        entry:SetScript("OnEnter", function() hover:Show() end)
        entry:SetScript("OnLeave", function() hover:Hide() end)

        local optionValue = dropOptions[i]
        entry:SetScript("OnClick", function()
            if Cursive and Cursive.db and Cursive.db.profile then
                Cursive.db.profile[configKey] = optionValue
            end
            UpdateDisplay()
            menuFrame:Hide()
            for j = 1, table.getn(dropOptions) do
                local e = menuFrame.entries[j]
                if e and e.check then
                    e.check:SetText(dropOptions[j] == optionValue and "|cFFFFFFFF\226\156\147|r" or "")
                end
            end
            if Cursive and Cursive.UpdateFrames then Cursive:UpdateFrames() end
        end)

        menuFrame.entries[i] = entry
    end

    dropBtn:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:ClearAllPoints()
            menuFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
            menuFrame:SetPoint("TOPRIGHT", dropBtn, "BOTTOMRIGHT", 0, -2)
            local val = GetCurrentValue()
            for i = 1, table.getn(dropOptions) do
                local e = menuFrame.entries[i]
                if e and e.check then
                    e.check:SetText(dropOptions[i] == val and "|cFFFFFFFF\226\156\147|r" or "")
                end
            end
            menuFrame:Show()
        end
    end)

    dropBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
    dropBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) end)

    dropBtn.Refresh = UpdateDisplay
    timerDropButtons[configKey] = dropBtn

    -- v3.2.1: Add tooltip to row if provided
    if tooltipText and tooltipText ~= "" then
        row:EnableMouse(true)
        row.tooltipText = tooltipText
        row.tooltipTitle = labelText
        row:SetScript("OnEnter", function()
            CursiveTooltip_Show(this, this.tooltipTitle, this.tooltipText)
        end)
        row:SetScript("OnLeave", function()
            CursiveTooltip_Hide()
        end)
    end

    return yOffset - ROW_HEIGHT - ROW_SPACING
end

y = CreateTimerColorDropdown(genChild, "CursiveOptDurationTimer", "Duration Timer", "durationtimercolor", y,
    "Color of the duration timer text on debuff icons")

-- Decimal Duration dropdown (None/White/Red) — between Duration Timer and Stack Counter
do
    local ddOptions = { "none", "white", "red" }
    local ddLabels = { "None", "White", "Red" }
    local ddColors = {
        none  = { 0.65, 0.65, 0.65 },
        white = { 1, 1, 1 },
        red   = { 1, 0.3, 0.3 },
    }

    local row = CreateFrame("Frame", "CursiveOptDecimalDurRow", genChild)
    row:SetWidth(CONTENT_WIDTH)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", genChild, "TOPLEFT", 0, y)
    row:EnableMouse(true)
    row.tooltipText = "Show 1 decimal place in last 3s of debuff duration"
    row.tooltipTitle = "Decimal Duration"
    row:SetScript("OnEnter", function()
        if this.tooltipText and this.tooltipText ~= "" then
            CursiveTooltip_Show(this, this.tooltipTitle, this.tooltipText)
        end
    end)
    row:SetScript("OnLeave", function() CursiveTooltip_Hide() end)

    local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 16, 0)
    lbl:SetText("Decimal Duration")

    local dropWidth = 100
    local dropBtn = CreateFrame("Button", "CursiveOptDecimalDurDrop", row)
    dropBtn:SetWidth(dropWidth)
    dropBtn:SetHeight(ROW_HEIGHT - 2)
    dropBtn:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    dropBtn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dropBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    dropBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropText:SetPoint("CENTER", dropBtn, "CENTER", -6, 0)
    dropText:SetJustifyH("CENTER")

    local arrow = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.7, 0.7, 0.7)

    local menuFrame = CreateFrame("Frame", "CursiveOptDecimalDurMenu", UIParent)
    menuFrame:SetFrameStrata("FULLSCREEN")
    menuFrame:SetWidth(dropWidth)
    menuFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    menuFrame:Hide()
    menuFrame:EnableMouse(true)
    menuFrame:SetScript("OnUpdate", function()
        if (this.tick or 0) > GetTime() then return end
        this.tick = GetTime() + 0.05
        if not MouseIsOver(menuFrame, 10, -10, -10, 10) and not MouseIsOver(dropBtn) then
            menuFrame:Hide()
        end
    end)

    -- Map config to dropdown value
    local function GetCurrentValue()
        if not Cursive or not Cursive.db or not Cursive.db.profile then return "none" end
        local p = Cursive.db.profile
        if not p.coloreddecimalduration then return "none" end
        -- coloreddecimalduration is true: check durationtimercolor for color hint
        -- Use new key decimalDurationColor if exists, else default to "red" (original behavior)
        return p.decimalDurationColor or "red"
    end

    local function UpdateDisplay()
        local val = GetCurrentValue()
        for i = 1, table.getn(ddOptions) do
            if ddOptions[i] == val then
                dropText:SetText(ddLabels[i])
                local c = ddColors[val]
                dropText:SetTextColor(c[1], c[2], c[3])
                break
            end
        end
    end

    local entryHeight = 20
    menuFrame:SetHeight(table.getn(ddOptions) * entryHeight + 4)

    for i = 1, table.getn(ddOptions) do
        local entry = CreateFrame("Button", nil, menuFrame)
        entry:SetHeight(entryHeight)
        entry:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 2, -((i - 1) * entryHeight) - 2)
        entry:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -2, -((i - 1) * entryHeight) - 2)
        local eTxt = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        eTxt:SetPoint("LEFT", entry, "LEFT", 6, 0)
        eTxt:SetText(ddLabels[i])
        local c = ddColors[ddOptions[i]]
        eTxt:SetTextColor(c[1], c[2], c[3])
        local hover = entry:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints(entry)
        hover:SetTexture(1, 1, 1, 0.08)
        hover:Hide()
        entry:SetScript("OnEnter", function() hover:Show() end)
        entry:SetScript("OnLeave", function() hover:Hide() end)
        local optVal = ddOptions[i]
        entry:SetScript("OnClick", function()
            if Cursive and Cursive.db and Cursive.db.profile then
                if optVal == "none" then
                    Cursive.db.profile.coloreddecimalduration = false
                    Cursive.db.profile.decimalDurationColor = "none"
                else
                    Cursive.db.profile.coloreddecimalduration = true
                    Cursive.db.profile.decimalDurationColor = optVal
                end
            end
            UpdateDisplay()
            menuFrame:Hide()
            if Cursive.UpdateFramesFromConfig then Cursive.UpdateFramesFromConfig() end
        end)
    end

    dropBtn:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:ClearAllPoints()
            menuFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
            menuFrame:SetPoint("TOPRIGHT", dropBtn, "BOTTOMRIGHT", 0, -2)
            menuFrame:Show()
        end
    end)
    dropBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
    dropBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) end)
    dropBtn.Refresh = UpdateDisplay
    timerDropButtons["decimalDurationColor"] = dropBtn
    y = y - ROW_HEIGHT - ROW_SPACING
end

y = CreateTimerColorDropdown(genChild, "CursiveOptStackCounter", "Stack Counter", "stackcountercolor", y,
    "Color of the stack counter text on debuff icons")

-- ============================================================
-- Debuff Order section (v3.2.1: categories as labels, positions as dropdown values)
-- ============================================================
_, y = CreateRow(genChild, "CursiveGenHdrDebuffOrder", y, "Debuff Order", "header")

do
    -- Categories (displayed as row labels)
    local categoryRows = {
        { cat = "ownclass",   label = "Own Class",  tip = "Position for your own class debuffs (DoTs, personal spells)" },
        { cat = "ownraid",    label = "Own Raid",    tip = "Position for your own raid-relevant debuffs (Sunder, Faerie Fire, etc.)" },
        { cat = "otherclass", label = "Other Class",  tip = "Position for other players' class debuffs" },
        { cat = "otherraid",  label = "Other Raid",   tip = "Position for other players' raid-relevant debuffs" },
    }

    -- Position options (displayed in dropdowns)
    local posOptions = { "orderfront", "ordermiddle", "orderback", "orderlast", "orderotherside", "ordernone" }
    local posLabels = { "Front", "Mid", "Rear", "Last", "Swap Side", "None" }

    -- Config keys (position → category mapping, unchanged)
    local orderKeys = { "orderfront", "ordermiddle", "orderback", "orderlast" }

    -- Store all order dropdown buttons for cross-refresh
    local orderDropButtons = {}

    -- Refresh all 4 dropdowns (called after swap)
    local function RefreshAllOrderDropdowns()
        for _, btn in pairs(orderDropButtons) do
            if btn and btn.Refresh then btn.Refresh() end
        end
    end

    -- Find which position key currently holds a given category
    local function FindPositionForCategory(category)
        if not Cursive or not Cursive.db or not Cursive.db.profile then return nil end
        local profile = Cursive.db.profile
        for _, key in ipairs(orderKeys) do
            if profile[key] == category then
                return key
            end
        end
        -- Check "other side"
        if profile.orderotherside == category then
            return "orderotherside"
        end
        -- Check if hidden (None)
        -- Categories set to "none" via ordernone are simply not in any slot
        return nil
    end

    -- Swap logic: when assigning a category to a new position, swap with whatever was there
    -- Other Side: multiple categories CAN be placed there
    -- None: category is completely hidden (no debuffs of this type shown)
    local function SwapCategoryPosition(category, newPosKey)
        if not Cursive or not Cursive.db or not Cursive.db.profile then return end
        local profile = Cursive.db.profile

        local oldPosKey = FindPositionForCategory(category)
        if oldPosKey == newPosKey then return end -- already there

        if newPosKey == "ordernone" then
            -- Moving TO None — free the old slot
            if oldPosKey and oldPosKey ~= "orderotherside" then
                profile[oldPosKey] = "none"
            elseif oldPosKey == "orderotherside" then
                profile.orderotherside = "none"
            end
            -- Category is simply not assigned anywhere = hidden
            return
        end

        if newPosKey == "orderotherside" then
            -- Moving TO other side
            if oldPosKey and oldPosKey ~= "orderotherside" then
                local otherSideCat = profile.orderotherside
                if otherSideCat and otherSideCat ~= "none" then
                    profile[oldPosKey] = otherSideCat
                else
                    profile[oldPosKey] = "none"
                end
            end
            profile.orderotherside = category
            return
        end

        -- Moving to a main position
        local displacedCat = profile[newPosKey]
        profile[newPosKey] = category

        if oldPosKey and oldPosKey ~= "orderotherside" then
            profile[oldPosKey] = displacedCat
        elseif oldPosKey == "orderotherside" then
            profile.orderotherside = displacedCat or "none"
        end
        -- If oldPosKey is nil (was hidden/None), displaced cat goes nowhere (also hidden)
    end

    for _, catRow in ipairs(categoryRows) do
        local category = catRow.cat
        local labelText = catRow.label

        local row = CreateFrame("Frame", "CursiveOpt_cat_" .. category .. "Row", genChild)
        row:SetWidth(CONTENT_WIDTH)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", genChild, "TOPLEFT", 0, y)
        row:EnableMouse(true)
        row.tooltipText = catRow.tip or ""
        row.tooltipTitle = labelText
        row:SetScript("OnEnter", function()
            if this.tooltipText and this.tooltipText ~= "" then
                CursiveTooltip_Show(this, this.tooltipTitle, this.tooltipText)
            end
        end)
        row:SetScript("OnLeave", function()
            CursiveTooltip_Hide()
        end)

        local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", row, "LEFT", 17, 0)
        lbl:SetText(labelText)

        local dropWidth = 120
        local dropBtn = CreateFrame("Button", "CursiveOpt_cat_" .. category .. "Drop", row)
        dropBtn:SetWidth(dropWidth)
        dropBtn:SetHeight(ROW_HEIGHT - 2)
        dropBtn:SetPoint("RIGHT", row, "RIGHT", -18, 0)
        dropBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        dropBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        dropBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

        local dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dropText:SetPoint("CENTER", dropBtn, "CENTER", -6, 0)
        dropText:SetJustifyH("CENTER")

        local arrow = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)
        arrow:SetText("v")
        arrow:SetTextColor(0.7, 0.7, 0.7)

        local menuFrame = CreateFrame("Frame", "CursiveOpt_cat_" .. category .. "Menu", UIParent)
        menuFrame:SetFrameStrata("FULLSCREEN")
        menuFrame:SetWidth(dropWidth)
        menuFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        menuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        menuFrame:Hide()
        menuFrame:EnableMouse(true)

        menuFrame:SetScript("OnUpdate", function()
            if (this.tick or 0) > GetTime() then return end
            this.tick = GetTime() + 0.05
            if not MouseIsOver(menuFrame, 10, -10, -10, 10) and not MouseIsOver(dropBtn) then
                menuFrame:Hide()
            end
        end)

        local function GetCurrentPosition()
            local posKey = FindPositionForCategory(category)
            return posKey or "ordernone"
        end

        local function UpdateDisplay()
            local posKey = GetCurrentPosition()
            for i = 1, table.getn(posOptions) do
                if posOptions[i] == posKey then
                    dropText:SetText(posLabels[i])
                    break
                end
            end
            dropText:SetTextColor(1, 1, 1)
        end

        local entryHeight = 20
        menuFrame:SetHeight(table.getn(posOptions) * entryHeight + 4)
        menuFrame.entries = {}

        for i = 1, table.getn(posOptions) do
            local entry = CreateFrame("Button", nil, menuFrame)
            entry:SetHeight(entryHeight)
            entry:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 2, -((i - 1) * entryHeight) - 2)
            entry:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -2, -((i - 1) * entryHeight) - 2)

            local entryText = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            entryText:SetPoint("LEFT", entry, "LEFT", 6, 0)
            entryText:SetText(posLabels[i])
            entryText:SetTextColor(1, 1, 1)

            local check = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            check:SetPoint("RIGHT", entry, "RIGHT", -6, 0)
            check:SetText("")
            entry.check = check

            local hover = entry:CreateTexture(nil, "BACKGROUND")
            hover:SetAllPoints(entry)
            hover:SetTexture(1, 1, 1, 0.08)
            hover:Hide()

            entry:SetScript("OnEnter", function() hover:Show() end)
            entry:SetScript("OnLeave", function() hover:Hide() end)

            local optionValue = posOptions[i]
            entry:SetScript("OnClick", function()
                SwapCategoryPosition(category, optionValue)
                RefreshAllOrderDropdowns()
                menuFrame:Hide()
                if Cursive.UpdateFramesFromConfig then Cursive.UpdateFramesFromConfig() end
            end)

            menuFrame.entries[i] = entry
        end

        dropBtn:SetScript("OnClick", function()
            if menuFrame:IsShown() then
                menuFrame:Hide()
            else
                menuFrame:ClearAllPoints()
                menuFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
                menuFrame:SetPoint("TOPRIGHT", dropBtn, "BOTTOMRIGHT", 0, -2)
                local posKey = GetCurrentPosition()
                for i = 1, table.getn(posOptions) do
                    local e = menuFrame.entries[i]
                    if e and e.check then
                        e.check:SetText(posOptions[i] == posKey and "|cFFFFFFFF\226\156\147|r" or "")
                    end
                end
                menuFrame:Show()
            end
        end)

        dropBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
        dropBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) end)

        dropBtn.Refresh = UpdateDisplay
        orderDropButtons[category] = dropBtn

        y = y - ROW_HEIGHT - ROW_SPACING
    end

    -- Other Side dropdown removed — integrated into each category's position dropdown


    -- Store refresh function globally for Initialize()
    CursiveOpts.RefreshOrderDropdowns = RefreshAllOrderDropdowns

    -- Initial refresh
    RefreshAllOrderDropdowns()
end

-- ============================================================
-- Target Armor section (General tab, after Debuff Order)
-- ============================================================
y = y - 8
_, y = CreateRow(genChild, "CursiveGenHdrTargetArmor", y, "Target Armor", "header", nil, { headerIndent = 15 })

_, y = CreateRow(genChild, "CursiveOptArmorEnabled", y, "Enable", "checkbox", "armorStatusEnabled",
    { tooltipText = "Show the current armor value on target frames." })

_, y = CreateRow(genChild, "CursiveOptArmorColor", y, "Color Indicator", "checkbox", "armorColorIndicator",
    { tooltipText = "Color-code the armor value: Green = high armor, Yellow = medium, Red = low armor." })

do
    -- v3.2.1: Helper for armor dropdowns (matches Border/Timer dropdown pattern)
    local function CreateArmorDropdown(parent, globalName, labelText, configKey, defaultVal, options, labels, yOff, tooltipText)
        local dropWidth = 130
        local entryH = 20

        local row = CreateFrame("Frame", globalName .. "Row", parent)
        row:SetWidth(CONTENT_WIDTH)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOff)
        row:EnableMouse(true)
        row.tooltipText = tooltipText or ""
        row.tooltipTitle = labelText
        row:SetScript("OnEnter", function()
            if this.tooltipText and this.tooltipText ~= "" then
                CursiveTooltip_Show(this, this.tooltipTitle, this.tooltipText)
            end
        end)
        row:SetScript("OnLeave", function() CursiveTooltip_Hide() end)

        local lbl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", row, "LEFT", 16, 0)
        lbl:SetText(labelText)

        local dropBtn = CreateFrame("Button", globalName .. "Drop", row)
        dropBtn:SetWidth(dropWidth)
        dropBtn:SetHeight(ROW_HEIGHT - 2)
        dropBtn:SetPoint("RIGHT", row, "RIGHT", -18, 0)
        dropBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        dropBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        dropBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

        local dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dropText:SetPoint("CENTER", dropBtn, "CENTER", -6, 0)
        dropText:SetJustifyH("CENTER")

        local arrow = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", dropBtn, "RIGHT", -6, 0)
        arrow:SetText("v")
        arrow:SetTextColor(0.7, 0.7, 0.7)

        local menuFrame = CreateFrame("Frame", globalName .. "Menu", UIParent)
        menuFrame:SetFrameStrata("FULLSCREEN")
        menuFrame:SetWidth(dropWidth)
        menuFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        menuFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        menuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        menuFrame:Hide()
        menuFrame:SetHeight(table.getn(options) * entryH + 4)

        local function UpdateDisplay()
            local val = Cursive and Cursive.db and Cursive.db.profile and Cursive.db.profile[configKey] or defaultVal
            for i = 1, table.getn(options) do
                if options[i] == val then
                    dropText:SetText(labels[i])
                    break
                end
            end
        end

        for i = 1, table.getn(options) do
            local idx = i  -- Lua 5.0: capture loop variable in local
            local optVal = options[idx]
            local lblVal = labels[idx]

            local entry = CreateFrame("Button", nil, menuFrame)
            entry:SetHeight(entryH)
            entry:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 2, -((idx - 1) * entryH) - 2)
            entry:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -2, -((idx - 1) * entryH) - 2)

            local check = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            check:SetPoint("LEFT", entry, "LEFT", 4, 0)
            check:SetWidth(14)
            check:SetJustifyH("CENTER")
            entry.check = check

            local eTxt = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            eTxt:SetPoint("LEFT", check, "RIGHT", 2, 0)
            eTxt:SetText(lblVal)
            entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            entry:SetScript("OnClick", function()
                if Cursive and Cursive.db and Cursive.db.profile then
                    Cursive.db.profile[configKey] = optVal
                end
                UpdateDisplay()
                menuFrame:Hide()
                if Cursive.UpdateFramesFromConfig then Cursive.UpdateFramesFromConfig() end
            end)
        end

        dropBtn:SetScript("OnClick", function()
            if menuFrame:IsShown() then
                menuFrame:Hide()
            else
                menuFrame:ClearAllPoints()
                menuFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, -2)
                menuFrame:SetPoint("TOPRIGHT", dropBtn, "BOTTOMRIGHT", 0, -2)
                -- Update checkmarks
                local val = Cursive and Cursive.db and Cursive.db.profile and Cursive.db.profile[configKey] or defaultVal
                for idx = 1, table.getn(options) do
                    local e = menuFrame.entries and menuFrame.entries[idx]
                    if not e then
                        -- Fallback: iterate children
                    end
                end
                menuFrame:Show()
            end
        end)

        dropBtn:SetScript("OnEnter", function() this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1) end)
        dropBtn:SetScript("OnLeave", function() this:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8) end)
        dropBtn.Refresh = UpdateDisplay

        return dropBtn, yOff - ROW_HEIGHT - ROW_SPACING
    end

    -- Structure dropdown
    local structBtn
    structBtn, y = CreateArmorDropdown(genChild, "CursiveOptArmorStructure", "Build", "armorDisplayStructure", "live+removed",
        { "live+total", "live+removed", "total+removed", "live", "total", "removed" },
        { "Live + Total", "Reduced + Live", "Reduced + Total", "Live", "Total", "Reduced" },
        y, "Which armor values to display. Live = current, Total = base (highest seen), Reduced = reduction from debuffs.")
    CursiveOpts = CursiveOpts or {}
    CursiveOpts.armorStructureDrop = structBtn

    -- Position dropdown
    local posBtn
    posBtn, y = CreateArmorDropdown(genChild, "CursiveOptArmorPosition", "Position", "armorPosition", "default",
        { "default", "otherside" },
        { "Default", "Other Side" },
        y, "Where the armor value is displayed. Default = near raid icon, Other Side = opposite side of the health bar.")
    CursiveOpts.armorPositionDrop = posBtn

    -- Show Icon dropdown
    local iconBtn
    iconBtn, y = CreateArmorDropdown(genChild, "CursiveOptArmorIcon", "Show Icon", "armorShowIcon", "left",
        { "left", "center", "right", "none" },
        { "Left", "Center", "Right", "None" },
        y, "Shield icon position. Center replaces the separator between values.")
    CursiveOpts.armorIconDrop = iconBtn
end

genChild:SetHeight((-y) + 20)


-- ============================================================
-- 8f. Tab 2: Display (Sliders + new positioning sliders + checkboxes)
-- ============================================================
local dispSF, dispChild = CreateScrollPanel(displayPanel, "CursiveDisplayScroll")
y = -8

-- Header: Frame
_, y = CreateRow(dispChild, "CursiveDispHdrFrame", y, "UI Frame", "header", nil, { headerIndent = SLIDER_X_OFFSET })

_, y = CreateRow(dispChild, "CursiveOptScale", y, "Scale", "slider", "scale",
    { min = 0.50, max = 2.00, step = 0.05, fmt = "%.2f", tooltipText = "Scale of the Cursive frame" })

_, y = CreateRow(dispChild, "CursiveOptOpacity", y, "Opacity", "slider", "opacity",
    { min = 0.00, max = 1.00, step = 0.05, fmt = "%.2f", tooltipText = "Opacity of the Cursive frame" })

-- Header: Layout
_, y = CreateRow(dispChild, "CursiveDispHdrLayout", y, "Layout", "header", nil, { headerIndent = SLIDER_X_OFFSET })

_, y = CreateRow(dispChild, "CursiveOptMaxCurses", y, "Max Debuffs", "slider", "maxcurses",
    { min = 0, max = 18, step = 1, fmt = "%d", tooltipText = "Maximum number of curses shown per unit (0 = name only)" })

_, y = CreateRow(dispChild, "CursiveOptMaxRows", y, "Max Targets", "slider", "maxrow",
    { min = 1, max = 12, step = 1, fmt = "%d", tooltipText = "Maximum number of rows" })

_, y = CreateRow(dispChild, "CursiveOptMaxCols", y, "Columns", "slider", "maxcol",
    { min = 1, max = 5, step = 1, fmt = "%d", tooltipText = "Maximum number of columns" })

_, y = CreateRow(dispChild, "CursiveOptSpacing", y, "Health Bar Spacing", "slider", "spacing",
    { min = 0, max = 10, step = 1, fmt = "%d", tooltipText = "Spacing between health bars" })

_, y = CreateRow(dispChild, "CursiveOptDebuffIconSpacing", y, "Debuff Icon Spacing", "slider", "debufficonspacing",
    { min = 0, max = 10, step = 1, fmt = "%d", tooltipText = "Spacing between debuff icons" })

-- Header: Sizes
_, y = CreateRow(dispChild, "CursiveDispHdrSizes", y, "Sizes", "header", nil, { headerIndent = SLIDER_X_OFFSET })

_, y = CreateRow(dispChild, "CursiveOptHealthWidth", y, "Health Bar Width", "slider", "healthwidth",
    { min = 50, max = 150, step = 5, fmt = "%d", tooltipText = "Width of the health bar" })

_, y = CreateRow(dispChild, "CursiveOptHealthHeight", y, "Health Bar Height", "slider", "height",
    { min = 10, max = 30, step = 2, fmt = "%d", tooltipText = "Height of the health bar" })

_, y = CreateRow(dispChild, "CursiveOptCurseIconSize", y, "Debuff Icon Size", "slider", "curseiconsize",
    { min = 10, max = 30, step = 1, fmt = "%d", tooltipText = "Size of debuff icons" })

_, y = CreateRow(dispChild, "CursiveOptRaidIconSize", y, "Raid Icon Size", "slider", "raidiconsize",
    { min = 10, max = 30, step = 1, fmt = "%d", tooltipText = "Size of raid target icons" })

-- Header: Text
_, y = CreateRow(dispChild, "CursiveDispHdrText", y, "Text", "header", nil, { headerIndent = SLIDER_X_OFFSET })

_, y = CreateRow(dispChild, "CursiveOptFontScale", y, "Font Scale", "slider", "fontscale",
    { min = 0.50, max = 2.00, step = 0.10, fmt = "%.2f", tooltipText = "Scale factor for all text" })

_, y = CreateRow(dispChild, "CursiveOptTextSize", y, "HP Text Size", "slider", "textsize",
    { min = 6, max = 15, step = 1, fmt = "%d", tooltipText = "Font size for HP text" })

_, y = CreateRow(dispChild, "CursiveOptNameTextSize", y, "Name Text Size", "slider", "nameTextSize",
    { min = 6, max = 15, step = 1, fmt = "%d", tooltipText = "Font size for unit name text" })

_, y = CreateRow(dispChild, "CursiveOptArmorTextSize", y, "Armor Text Size", "slider", "armorTextSize",
    { min = 6, max = 15, step = 1, fmt = "%d", tooltipText = "Font size for armor display text" })

_, y = CreateRow(dispChild, "CursiveOptNameLength", y, "Name Length", "slider", "namelength",
    { min = 30, max = 120, step = 5, fmt = "%d", tooltipText = "Maximum name display length in pixels" })

-- Header: Debuff Timer
_, y = CreateRow(dispChild, "CursiveDispHdrTimerPos", y, "Debuff Timer", "header", nil, { headerIndent = SLIDER_X_OFFSET })

_, y = CreateRow(dispChild, "CursiveOptCurseTimerSize", y, "Timer Size", "slider", "cursetimersize",
    { min = 6, max = 15, step = 1, fmt = "%d", tooltipText = "Font size for curse timer text" })

_, y = CreateRow(dispChild, "CursiveOptCurseTimeH", y, "Timer Horizontal", "slider", "cursetimeh",
    { min = 0, max = 10, step = 1, fmt = "%d", tooltipText = "Horizontal position of curse timer (0=left, 5=center, 10=right)" })

_, y = CreateRow(dispChild, "CursiveOptCurseTimeV", y, "Timer Vertical", "slider", "cursetimev",
    { min = 0, max = 10, step = 1, fmt = "%d", tooltipText = "Vertical position of curse timer (0=bottom, 5=center, 10=top)" })

-- Header: Debuff Stack
_, y = CreateRow(dispChild, "CursiveDispHdrStackCtr", y, "Debuff Stack", "header", nil, { headerIndent = SLIDER_X_OFFSET })

_, y = CreateRow(dispChild, "CursiveOptStackSize", y, "Stack Size", "slider", "cursestacksize",
    { min = 6, max = 15, step = 1, fmt = "%d", tooltipText = "Font size for stack counter text" })

_, y = CreateRow(dispChild, "CursiveOptStackH", y, "Stack Horizontal", "slider", "cursestackh",
    { min = 0, max = 10, step = 1, fmt = "%d", tooltipText = "Horizontal position of stack counter (0=left, 5=center, 10=right)" })

_, y = CreateRow(dispChild, "CursiveOptStackV", y, "Stack Vertical", "slider", "cursestackv",
    { min = 0, max = 10, step = 1, fmt = "%d", tooltipText = "Vertical position of stack counter (0=bottom, 5=center, 10=top)" })

-- Header: Target Armor
_, y = CreateRow(dispChild, "CursiveDispHdrTargetArmor", y, "Target Armor", "header", nil, { headerIndent = SLIDER_X_OFFSET })

_, y = CreateRow(dispChild, "CursiveOptArmorPositionOffset", y, "Position", "slider", "armorPositionOffset",
    { min = -30, max = 30, step = 1, fmt = "%d", tooltipText = "Vertical offset for Target Armor display (0 = centered)" })

dispChild:SetHeight((-y) + 20)


-- ============================================================
-- 8g. Tab 3: Raid (Enable/Disable All as scroll rows + debuff checkboxes)
-- ============================================================

-- Scroll area fills entire raid panel (buttons are inside scroll)
local raidSF, raidChild = CreateScrollPanel(raidPanel, "CursiveRaidScroll")

-- Build raid debuff rows (deferred to Initialize since optionsData might not be ready)
local raidRowFrames = {}

local function BuildRaidContent()
    -- Hide old rows
    for i = 1, getn(raidRowFrames) do
        raidRowFrames[i]:Hide()
    end
    raidRowFrames = {}

    local data = GetOptionsData()
    if not data then return end

    local ry = -8
    local rowFrame, idx
    idx = 0

    -- v3.2.1: Raid Debuff Order (at top of Raid tab)
    ry = CursiveOpts_BuildRaidOrder(raidChild, raidRowFrames, ry, data)

    -- Armor Reduction
    if data.raidArmorKeys then
        idx = idx + 1
        rowFrame, ry = CreateRow(raidChild, "CursiveRaidHdrArmor", ry, "Armor Reduction", "header")
        tinsert(raidRowFrames, rowFrame)
        for _, key in ipairs(data.raidArmorKeys) do
            idx = idx + 1
            local dname = (data.raidDisplayNames and data.raidDisplayNames[key]) or (data.debuffDisplayNames and data.debuffDisplayNames[key]) or key
            rowFrame, ry = CreateRow(raidChild, "CursiveRaidDebuff" .. idx, ry, dname, "debuff_checkbox", key,
                { tooltipText = GetDebuffTooltip(key) })
            tinsert(raidRowFrames, rowFrame)
        end
    end

    -- Spell Vulnerability
    if data.raidSpellVulnKeys then
        idx = idx + 1
        rowFrame, ry = CreateRow(raidChild, "CursiveRaidHdrSpell", ry, "Spell Vulnerability", "header")
        tinsert(raidRowFrames, rowFrame)
        for _, key in ipairs(data.raidSpellVulnKeys) do
            idx = idx + 1
            local dname = (data.raidDisplayNames and data.raidDisplayNames[key]) or (data.debuffDisplayNames and data.debuffDisplayNames[key]) or key
            rowFrame, ry = CreateRow(raidChild, "CursiveRaidDebuff" .. idx, ry, dname, "debuff_checkbox", key,
                { tooltipText = GetDebuffTooltip(key) })
            tinsert(raidRowFrames, rowFrame)
        end
    end

    -- Weapon Procs
    if data.raidWeaponProcKeys then
        idx = idx + 1
        rowFrame, ry = CreateRow(raidChild, "CursiveRaidHdrWeapon", ry, "Weapon Procs", "header")
        tinsert(raidRowFrames, rowFrame)
        for _, key in ipairs(data.raidWeaponProcKeys) do
            idx = idx + 1
            local dname = (data.raidDisplayNames and data.raidDisplayNames[key]) or (data.debuffDisplayNames and data.debuffDisplayNames[key]) or key
            rowFrame, ry = CreateRow(raidChild, "CursiveRaidDebuff" .. idx, ry, dname, "debuff_checkbox", key,
                { tooltipText = GetDebuffTooltip(key) })
            tinsert(raidRowFrames, rowFrame)
        end
    end

    raidChild:SetHeight((-ry) + 23)
end


-- ============================================================
-- Raid Debuff Order (extracted to avoid Lua 5.0 upvalue limit of 32)
-- ============================================================
do  -- isolated scope for upvalue budget

local ROW_HEIGHT = 22
local CONTENT_WIDTH = 308  -- must match outer CONTENT_WIDTH (FRAME_WIDTH - 30)
local ICON_SIZE = 19
local ICON_GAP = 2
local MENU_ICON_SIZE = 19
local MENU_COLS = 4

-- Shared dropdown menu frame (created once at file load)
local orderMenuFrame = CreateFrame("Frame", "CursiveRaidOrderMenu", UIParent)
orderMenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
orderMenuFrame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
orderMenuFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
orderMenuFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
orderMenuFrame:Hide()
orderMenuFrame:EnableMouse(true)

-- Backdrop overlay to catch clicks outside dropdown
local orderBackdrop = CreateFrame("Button", "CursiveRaidOrderBackdrop", UIParent)
orderBackdrop:SetFrameStrata("FULLSCREEN")
orderBackdrop:SetAllPoints(UIParent)
orderBackdrop:EnableMouse(true)
orderBackdrop:Hide()
orderBackdrop:SetScript("OnClick", function()
    orderMenuFrame:Hide()
end)

orderMenuFrame:SetScript("OnShow", function()
    orderBackdrop:Show()
end)
orderMenuFrame:SetScript("OnHide", function()
    orderBackdrop:Hide()
end)

local iconButtons = {}

local function GetEnabledRaidDebuffKeys(allRaidKeys)
    local enabled = {}
    if not Cursive or not Cursive.db or not Cursive.db.profile then return enabled end
    local sd = Cursive.db.profile.shareddebuffs
    if not sd then return enabled end
    local order = Cursive.db.profile.raidDebuffOrder
    if order and table.getn(order) > 0 then
        for i = 1, table.getn(order) do
            if sd[order[i]] then
                table.insert(enabled, order[i])
            end
        end
        if allRaidKeys then
            for _, key in ipairs(allRaidKeys) do
                if sd[key] then
                    local found = false
                    for j = 1, table.getn(enabled) do
                        if enabled[j] == key then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(enabled, key)
                    end
                end
            end
        end
    else
        if allRaidKeys then
            for _, key in ipairs(allRaidKeys) do
                if sd[key] then
                    table.insert(enabled, key)
                end
            end
        end
    end
    return enabled
end

local function GetDebuffTexture(debuffKey)
    if Cursive.curses and Cursive.curses.sharedDebuffs and Cursive.curses.sharedDebuffs[debuffKey] then
        for spellID, _ in pairs(Cursive.curses.sharedDebuffs[debuffKey]) do
            local _, _, tex = SpellInfo(spellID)
            if tex then return tex end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetDebuffNameFromData(debuffKey, data)
    if data.raidDisplayNames and data.raidDisplayNames[debuffKey] then
        return data.raidDisplayNames[debuffKey]
    end
    if data.debuffDisplayNames and data.debuffDisplayNames[debuffKey] then
        return data.debuffDisplayNames[debuffKey]
    end
    return debuffKey
end

function CursiveOpts_BuildRaidOrder(raidChild, raidRowFrames, ry, data)
    local idx = 0
    local rowFrame

    idx = idx + 1
    rowFrame, ry = CreateRow(raidChild, "CursiveRaidHdrOrder", ry, "Raid Debuffs", "header", nil, { headerIndent = 15 })
    table.insert(raidRowFrames, rowFrame)

    -- Checkboxes directly under header, before Layout
    local cbFrame
    idx = idx + 1
    cbFrame, ry = CreateRow(raidChild, "CursiveRaidShowMissing", ry, "Show Missing Debuff Icons", "checkbox", "showMissingDebuffs",
        { tooltipText = "Show inactive raid debuffs as greyed-out transparent icons on targets." })
    table.insert(raidRowFrames, cbFrame)

    idx = idx + 1
    cbFrame, ry = CreateRow(raidChild, "CursiveRaidIncludeOwn", ry, "Include Own Raid Debuffs in Order", "checkbox", "includeOwnRaidInOrder",
        { tooltipText = "If enabled, your own raid debuffs follow this order too. Default: separate (as configured in General)." })
    table.insert(raidRowFrames, cbFrame)

    -- "Layout" label (white, normal size, not a gold header)
    ry = ry - 10
    local layoutLabel = raidChild:CreateFontString("CursiveRaidLayoutLabel", "OVERLAY", "GameFontHighlightSmall")
    layoutLabel:SetPoint("TOPLEFT", raidChild, "TOPLEFT", 16, ry)
    layoutLabel:SetText("Change Order")
    layoutLabel:SetTextColor(1, 1, 1, 1)
    ry = ry - 14

    local allRaidKeys = data.allRaidKeys

    local orderContainer = getglobal("CursiveRaidOrderContainer")
    if not orderContainer then
        orderContainer = CreateFrame("Frame", "CursiveRaidOrderContainer", raidChild)
    else
        orderContainer:SetParent(raidChild)
    end
    orderContainer:SetWidth(CONTENT_WIDTH)
    orderContainer:ClearAllPoints()
    orderContainer:SetPoint("TOPLEFT", raidChild, "TOPLEFT", 0, ry)
    orderContainer:EnableMouse(false)
    orderContainer:Show()
    table.insert(raidRowFrames, orderContainer)

    local function RebuildOrderIcons()
        for i = 1, table.getn(iconButtons) do
            iconButtons[i]:SetParent(orderContainer)
            iconButtons[i]:Hide()
        end

        local enabledKeys = GetEnabledRaidDebuffKeys(allRaidKeys)
        local numEnabled = table.getn(enabledKeys)
        if numEnabled == 0 then
            orderContainer:SetHeight(ROW_HEIGHT)
            if orderContainer.labelLeft then orderContainer.labelLeft:Hide() end
            if orderContainer.labelRight then orderContainer.labelRight:Hide() end
            return
        end

        if Cursive and Cursive.db and Cursive.db.profile then
            Cursive.db.profile.raidDebuffOrder = enabledKeys
            Cursive._raidOrderDirty = true -- v4.0.4: Signal ui.lua to rebuild lookup
        end

        local inverted = Cursive.db.profile.invertbars

        -- Update First/Last labels (position + text + visibility)
        local baseOffset = 18
        -- v4.0.4: Dynamic icon scaling based on enabled count
        -- Fits all icons within CONTENT_WIDTH regardless of count
        local iconSize = ICON_SIZE
        local iconGap = ICON_GAP
        local availableWidth = CONTENT_WIDTH - baseOffset
        local neededWidth = numEnabled * (ICON_SIZE + ICON_GAP)
        if neededWidth > availableWidth and numEnabled > 0 then
            local maxSlot = math.floor(availableWidth / numEnabled)
            iconGap = math.max(1, math.min(ICON_GAP, maxSlot - ICON_SIZE))
            iconSize = math.max(12, maxSlot - iconGap)
        end

        if orderContainer.labelLeft and orderContainer.labelRight then
            if numEnabled <= 2 then
                orderContainer.labelLeft:Hide()
                orderContainer.labelRight:Hide()
            else
                orderContainer.labelLeft:SetText(inverted and "Last" or "First")
                orderContainer.labelLeft:ClearAllPoints()
                orderContainer.labelLeft:SetPoint("TOPLEFT", orderContainer, "BOTTOMLEFT", baseOffset, -2)
                orderContainer.labelLeft:Show()

                orderContainer.labelRight:SetText(inverted and "First" or "Last")
                orderContainer.labelRight:ClearAllPoints()
                local lastX = baseOffset + (numEnabled - 1) * (iconSize + iconGap)
                orderContainer.labelRight:SetPoint("TOPLEFT", orderContainer, "BOTTOMLEFT", lastX, -2)
                orderContainer.labelRight:Show()
            end
        end

        for i = 1, numEnabled do
            local debuffKey = enabledKeys[i]
            local displayIdx = inverted and (numEnabled - i + 1) or i

            local btn = iconButtons[i]
            if not btn then
                btn = CreateFrame("Button", "CursiveRaidOrderIcon" .. i, orderContainer)
                btn:SetWidth(iconSize)
                btn:SetHeight(iconSize)
                local tex = btn:CreateTexture("CursiveRaidOrderIcon" .. i .. "Tex", "ARTWORK")
                tex:SetAllPoints(btn)
                tex:SetTexCoord(0.078, 0.92, 0.079, 0.937)
                btn.iconTex = tex
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints(btn)
                hl:SetTexture(1, 1, 1, 0.3)
                iconButtons[i] = btn
            end

            btn:SetWidth(iconSize)
            btn:SetHeight(iconSize)
            local xOffset = (displayIdx - 1) * (iconSize + iconGap) + baseOffset
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", orderContainer, "TOPLEFT", xOffset, 0)
            btn.iconTex:SetTexture(GetDebuffTexture(debuffKey))
            btn.debuffKey = debuffKey
            btn.debuffName = GetDebuffNameFromData(debuffKey, data)
            btn.orderIndex = i

            btn:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:AddLine(this.debuffName, 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            btn:SetScript("OnClick", function()
                CursiveOpts_OpenOrderMenu(this, allRaidKeys, data, RebuildOrderIcons)
            end)

            btn:Show()
        end

        orderContainer:SetHeight(iconSize + 4)
    end

    -- First / Last labels — create once, reuse
    if not orderContainer.labelLeft then
        local labelLeft = orderContainer:CreateFontString("CursiveRaidOrderLabelLeft", "OVERLAY", "GameFontNormalSmall")
        labelLeft:SetTextColor(1, 1, 1, 1)
        orderContainer.labelLeft = labelLeft
    end
    if not orderContainer.labelRight then
        local labelRight = orderContainer:CreateFontString("CursiveRaidOrderLabelRight", "OVERLAY", "GameFontNormalSmall")
        labelRight:SetTextColor(1, 1, 1, 1)
        orderContainer.labelRight = labelRight
    end

    local ok, err = pcall(RebuildOrderIcons)
    if not ok and err then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[Cursive] RaidOrder: " .. tostring(err) .. "|r")
    end

    CursiveOpts = CursiveOpts or {}
    CursiveOpts.RebuildRaidOrder = RebuildOrderIcons

    -- Checkboxes below icons
    ry = ry - ICON_SIZE - 26

    return ry
end

function CursiveOpts_OpenOrderMenu(srcBtn, allRaidKeys, data, rebuildFn)
    -- Toggle: close if already open for this icon
    if orderMenuFrame:IsShown() and orderMenuFrame.currentIdx == srcBtn.orderIndex then
        orderMenuFrame:Hide()
        return
    end
    local clickedIdx = srcBtn.orderIndex
    orderMenuFrame.currentIdx = clickedIdx
    local currentKeys = GetEnabledRaidDebuffKeys(allRaidKeys)
    local numKeys = table.getn(currentKeys)

    if orderMenuFrame.entries then
        for ei = 1, table.getn(orderMenuFrame.entries) do
            orderMenuFrame.entries[ei]:Hide()
        end
    end
    orderMenuFrame.entries = {}

    local menuPad = 4
    local numRows = math.ceil(numKeys / MENU_COLS)
    local menuWidth = MENU_COLS * (MENU_ICON_SIZE + ICON_GAP) + menuPad * 2
    local menuHeight = numRows * (MENU_ICON_SIZE + ICON_GAP) + menuPad * 2
    orderMenuFrame:SetWidth(menuWidth)
    orderMenuFrame:SetHeight(menuHeight)

    for ei = 1, numKeys do
        local eKey = currentKeys[ei]
        local col = math.mod(ei - 1, MENU_COLS)
        local row = math.floor((ei - 1) / MENU_COLS)

        local entry = CreateFrame("Button", nil, orderMenuFrame)
        entry:SetWidth(MENU_ICON_SIZE)
        entry:SetHeight(MENU_ICON_SIZE)
        entry:SetPoint("TOPLEFT", orderMenuFrame, "TOPLEFT",
            menuPad + col * (MENU_ICON_SIZE + ICON_GAP),
            -(menuPad + row * (MENU_ICON_SIZE + ICON_GAP)))

        local eTex = entry:CreateTexture(nil, "ARTWORK")
        eTex:SetAllPoints(entry)
        eTex:SetTexture(GetDebuffTexture(eKey))
        eTex:SetTexCoord(0.078, 0.92, 0.079, 0.937)

        if ei == clickedIdx then
            local sel = entry:CreateTexture(nil, "OVERLAY")
            sel:SetPoint("TOPLEFT", entry, "TOPLEFT", -1, 1)
            sel:SetPoint("BOTTOMRIGHT", entry, "BOTTOMRIGHT", 1, -1)
            sel:SetTexture(1, 0.82, 0, 0.6)
            sel:SetDrawLayer("BACKGROUND")
        end

        local hover = entry:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(entry)
        hover:SetTexture(1, 1, 1, 0.3)

        entry.debuffKey = eKey
        entry.debuffName = GetDebuffNameFromData(eKey, data)
        entry:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:AddLine(this.debuffName, 1, 1, 1)
            GameTooltip:Show()
        end)
        entry:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        entry.swapFromIdx = clickedIdx
        entry.swapToIdx = ei
        entry.rebuildFn = rebuildFn
        entry:SetScript("OnClick", function()
            if Cursive and Cursive.db and Cursive.db.profile then
                local order = Cursive.db.profile.raidDebuffOrder
                if order then
                    local fromIdx = this.swapFromIdx
                    local toIdx = this.swapToIdx
                    -- v3.2.1: Insert-Shift instead of Swap
                    -- Move the popup-selected icon TO the clicked position
                    local item = table.remove(order, toIdx)
                    table.insert(order, fromIdx, item)
                end
            end
            orderMenuFrame:Hide()
            this.rebuildFn()
        end)

        orderMenuFrame.entries[ei] = entry
    end

    orderMenuFrame:ClearAllPoints()
    orderMenuFrame:SetPoint("TOPLEFT", srcBtn, "BOTTOMLEFT", 0, -2)
    orderMenuFrame:Show()
end

end  -- do scope

-- ============================================================
-- 8h. Tab 4: Class (Sub-Tabs 2x5 + ScrollPanels per class)
-- ============================================================

-- Class sub-tab buttons (2 rows x 5, full width)
local CLASS_SUBTAB_W = floor((FRAME_WIDTH - 4 * 2) / 5)
local CLASS_SUBTAB_H = 20
local classSubTabs = {}

for i = 1, getn(CLASS_ORDER) do
    local className = CLASS_ORDER[i]
    local btnName = "CursiveClassSubTab_" .. className
    local btn = CreateFrame("Button", btnName, classPanel)
    btn:SetWidth(CLASS_SUBTAB_W)
    btn:SetHeight(CLASS_SUBTAB_H)
    btn:EnableMouse(true)

    -- Position: row 1 (1-5), row 2 (6-10)
    if i <= 5 then
        btn:SetPoint("TOPLEFT", classPanel, "TOPLEFT", (i - 1) * (CLASS_SUBTAB_W + 2), 0)
    else
        btn:SetPoint("TOPLEFT", classPanel, "TOPLEFT", (i - 6) * (CLASS_SUBTAB_W + 2), 0 - CLASS_SUBTAB_H - 2)
    end

    -- Background texture
    local cc = CLASS_COLORS[className] or { 0.5, 0.5, 0.5 }
    local bg = btn:CreateTexture(btnName .. "BG", "BACKGROUND")
    bg:SetTexture(cc[1] * 0.4, cc[2] * 0.4, cc[3] * 0.4, 0.8)
    bg:SetAllPoints(btn)

    -- Text
    local btnText = btn:CreateFontString(btnName .. "Text", "ARTWORK", "GameFontNormalSmall")
    btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnText:SetText(CLASS_LABELS[className] or className)
    btnText:SetTextColor(cc[1], cc[2], cc[3])

    btn.className = className
    btn:SetScript("OnClick", function()
        CursiveOpts.SetClassTab(this.className)
    end)

    btn:SetScript("OnEnter", function()
        local c = CLASS_COLORS[this.className] or { 0.5, 0.5, 0.5 }
        local bgTex = getglobal(this:GetName() .. "BG")
        bgTex:SetTexture(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1)
    end)
    btn:SetScript("OnLeave", function()
        local c = CLASS_COLORS[this.className] or { 0.5, 0.5, 0.5 }
        local bgTex = getglobal(this:GetName() .. "BG")
        if this.className == selectedClass then
            bgTex:SetTexture(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 1)
        else
            bgTex:SetTexture(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 0.8)
        end
    end)

    classSubTabs[className] = btn
end

-- Scroll container below class sub-tab buttons (2 rows of tabs)
local classScrollContainer = CreateFrame("Frame", "CursiveClassScrollContainer", classPanel)
classScrollContainer:SetPoint("TOPLEFT", classPanel, "TOPLEFT", 10, 0 - (CLASS_SUBTAB_H + 2) * 2 - 2)
classScrollContainer:SetPoint("BOTTOMRIGHT", classPanel, "BOTTOMRIGHT", 0, 0)

-- Create one ScrollPanel per class, show/hide on tab switch
local classScrollPanels = {}  -- className -> { sf, child }
local classRowFrames = {}     -- className -> { row1, row2, ... }

for _, className in ipairs(CLASS_ORDER) do
    local panelName = "CursiveClassScroll_" .. className
    local container = CreateFrame("Frame", panelName .. "Container", classScrollContainer)
    container:SetAllPoints(classScrollContainer)
    container:Hide()

    local sf, child = CreateScrollPanel(container, panelName)
    classScrollPanels[className] = { sf = sf, child = child, container = container }
    classRowFrames[className] = {}
end

-- Build class debuff rows for a given class
local function BuildClassContent(className)
    local info = classScrollPanels[className]
    if not info then return end

    -- Hide old rows
    local oldRows = classRowFrames[className]
    if oldRows then
        for i = 1, getn(oldRows) do
            oldRows[i]:Hide()
        end
    end
    classRowFrames[className] = {}

    local data = GetOptionsData()
    if not data then return end

    -- Special case: "procs" loads raidWeaponProcKeys instead of classDebuffs
    local keys
    if className == "procs" then
        keys = data.raidWeaponProcKeys
    else
        if not data.classDebuffs then return end
        keys = data.classDebuffs[className]
    end
    if not keys then return end

    local cy = -8
    local rowFrame

    for idx = 1, getn(keys) do
        local key = keys[idx]
        local dname = (data.debuffDisplayNames and data.debuffDisplayNames[key]) or
                      (data.raidDisplayNames and data.raidDisplayNames[key]) or key
        rowFrame, cy = CreateRow(info.child, "CursiveClassDebuff_" .. className .. "_" .. idx, cy, dname, "debuff_checkbox", key,
            { tooltipText = GetDebuffTooltip(key) })
        -- Color the label in class color
        local labelFS = getglobal(rowFrame:GetName() .. "Label")
        if labelFS and className ~= "procs" then
            local cc = CLASS_COLORS[className]
            if cc then labelFS:SetTextColor(cc[1], cc[2], cc[3]) end
        end
        tinsert(classRowFrames[className], rowFrame)
    end

    info.child:SetHeight((-cy) + 20)
end

-- Build all class contents (called during Initialize)
local function BuildAllClassContent()
    for _, className in ipairs(CLASS_ORDER) do
        BuildClassContent(className)
    end
end


-- ============================================================
-- 8i. Tab 5: Filter (Checkboxes + Ignore List as dynamic rows)
-- ============================================================
local filtSF, filtChild = CreateScrollPanel(filterPanel, "CursiveFilterScroll")

-- We store references to dynamically built ignore-list rows
local ignoreListRows = {}
local filterContentBuilt = false
local classContentBuilt = false

-- Forward-declare rebuild function
local RebuildFilterContent

-- Build the entire filter tab content
RebuildFilterContent = function()
    -- If there are existing ignore rows, hide them
    for i = 1, getn(ignoreListRows) do
        ignoreListRows[i]:Hide()
    end
    ignoreListRows = {}

    -- Static rows are created once (below), ignore list rows are dynamic
    -- We calculate y offset after the static content
    local baseY = filtChild._ignoreStartY or -300
    local iy = baseY

    -- Build ignore list entries
    if Cursive and Cursive.db and Cursive.db.profile and Cursive.db.profile.ignorelist then
        local list = Cursive.db.profile.ignorelist
        for i = 1, getn(list) do
            local entryName = "CursiveIgnoreEntry" .. i
            local entry = getglobal(entryName)

            -- Create or reuse row frame
            if not entry then
                entry = CreateFrame("Frame", entryName, filtChild)
                entry:SetWidth(CONTENT_WIDTH)
                entry:SetHeight(ROW_HEIGHT)

                local entryText = entry:CreateFontString(entryName .. "Text", "ARTWORK", "GameFontHighlightSmall")
                entryText:SetPoint("LEFT", entry, "LEFT", 16, 0)
                entryText:SetJustifyH("LEFT")

                -- [X] remove button
                local removeBtn = CreateFrame("Button", entryName .. "RemoveBtn", entry)
                removeBtn:SetWidth(18)
                removeBtn:SetHeight(18)
                removeBtn:SetPoint("RIGHT", entry, "RIGHT", -16, 0)

                local removeTex = removeBtn:CreateTexture(entryName .. "RemoveTex", "ARTWORK")
                removeTex:SetTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Up")
                removeTex:SetAllPoints(removeBtn)

                removeBtn:SetScript("OnEnter", function()
                    getglobal(this:GetName() .. "Tex"):SetTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Highlight")
                end)
                removeBtn:SetScript("OnLeave", function()
                    getglobal(this:GetName() .. "Tex"):SetTexture("Interface\\BUTTONS\\UI-GroupLoot-Pass-Up")
                end)

                -- Highlight
                local hl = entry:CreateTexture(entryName .. "Highlight", "BACKGROUND")
                hl:SetTexture(1, 1, 1, 0.05)
                hl:SetAllPoints(entry)
                hl:Hide()

                entry:EnableMouse(true)
                entry:SetScript("OnEnter", function()
                    getglobal(this:GetName() .. "Highlight"):Show()
                end)
                entry:SetScript("OnLeave", function()
                    getglobal(this:GetName() .. "Highlight"):Hide()
                end)
            end

            entry:ClearAllPoints()
            entry:SetPoint("TOPLEFT", filtChild, "TOPLEFT", 0, iy)

            local entryText = getglobal(entryName .. "Text")
            if entryText then
                entryText:SetText(list[i] or "")
            end

            local removeBtn = getglobal(entryName .. "RemoveBtn")
            if removeBtn then
                removeBtn.ignoreIndex = i
                removeBtn:SetScript("OnClick", function()
                    CursiveOpts.RemoveIgnoreEntry(this.ignoreIndex)
                end)
            end

            entry:Show()
            tinsert(ignoreListRows, entry)
            iy = iy - ROW_HEIGHT - ROW_SPACING
        end
    end

    -- Update scroll child height
    filtChild:SetHeight((-iy) + 20)
end

-- Build static filter content
y = -8

-- Header: Show Only
_, y = CreateRow(filtChild, "CursiveFiltHdrShowOnly", y, "Show Only", "header")

_, y = CreateRow(filtChild, "CursiveOptFilterCombat", y, "In Combat", "checkbox", "filterincombat",
    { tooltipText = "Only show units in combat" })

_, y = CreateRow(filtChild, "CursiveOptFilterHostile", y, "Hostile", "checkbox", "filterhostile",
    { tooltipText = "Only show hostile units" })

_, y = CreateRow(filtChild, "CursiveOptFilterTarget", y, "Target", "checkbox", "filtertarget",
    { tooltipText = "Only show your current target (hides all other units)" })

_, y = CreateRow(filtChild, "CursiveOptFilterAttackable", y, "Attackable", "checkbox", "filterattackable",
    { tooltipText = "Only show attackable units" })

_, y = CreateRow(filtChild, "CursiveOptFilterPlayer", y, "Player", "checkbox", "filterplayer",
    { tooltipText = "Only show player units" })

_, y = CreateRow(filtChild, "CursiveOptFilterNotPlayer", y, "Not Player", "checkbox", "filternotplayer",
    { tooltipText = "Only show NON player units" })

_, y = CreateRow(filtChild, "CursiveOptFilterRange", y, "Within Range", "checkbox", "filterrange",
    { tooltipText = "Only show units within 120 yards (when disabled, all API-trackable units are shown)" })

_, y = CreateRow(filtChild, "CursiveOptFilterRaidMark", y, "Has Raid Mark", "checkbox", "filterraidmark",
    { tooltipText = "Only show units with raid marks" })

_, y = CreateRow(filtChild, "CursiveOptFilterCurse", y, "Has Curse", "checkbox", "filterhascurse",
    { tooltipText = "Only show units you have cursed" })

_, y = CreateRow(filtChild, "CursiveOptFilterIgnored", y, "Not Ignored", "checkbox", "filterignored",
    { tooltipText = "Filter out ignored mobs" })

_, y = CreateRow(filtChild, "CursiveOptUseRegex", y, "Use Regex", "checkbox", "ignorelistuseregex",
    { tooltipText = "Use regex patterns in the ignore list" })

-- Header: Ignore List
_, y = CreateRow(filtChild, "CursiveFiltHdrIgnore", y, "Ignore List", "header")

-- Action buttons for ignore list (Add Target, Add Name, Clear)
local ignoreButtonRow = CreateFrame("Frame", "CursiveIgnoreButtonRow", filtChild)
ignoreButtonRow:SetWidth(CONTENT_WIDTH)
ignoreButtonRow:SetHeight(24)
ignoreButtonRow:SetPoint("TOPLEFT", filtChild, "TOPLEFT", 0, y)

local ignoreAddTarget = CreateFrame("Button", "CursiveIgnoreAddTarget", ignoreButtonRow, "UIPanelButtonTemplate")
ignoreAddTarget:SetWidth(80)
ignoreAddTarget:SetHeight(20)
ignoreAddTarget:SetPoint("LEFT", ignoreButtonRow, "LEFT", 16, 0)
ignoreAddTarget:SetText("Add Target")
ignoreAddTarget:SetScript("OnClick", function() CursiveOpts.AddTargetToIgnore() end)
do local fs = ignoreAddTarget:GetFontString(); if fs then local f,s,fl = fs:GetFont(); fs:SetFont(f,s-2,fl) end end

local ignoreAddName = CreateFrame("Button", "CursiveIgnoreAddName", ignoreButtonRow, "UIPanelButtonTemplate")
ignoreAddName:SetWidth(80)
ignoreAddName:SetHeight(20)
ignoreAddName:SetPoint("LEFT", ignoreAddTarget, "RIGHT", 4, 0)
ignoreAddName:SetText("Add Name")
ignoreAddName:SetScript("OnClick", function() StaticPopup_Show("CURSIVE_ADD_IGNORE") end)
do local fs = ignoreAddName:GetFontString(); if fs then local f,s,fl = fs:GetFont(); fs:SetFont(f,s-2,fl) end end

local ignoreClear = CreateFrame("Button", "CursiveIgnoreClear", ignoreButtonRow, "UIPanelButtonTemplate")
ignoreClear:SetWidth(60)
ignoreClear:SetHeight(20)
ignoreClear:SetPoint("LEFT", ignoreAddName, "RIGHT", 4, 0)
ignoreClear:SetText("Clear")
ignoreClear:SetScript("OnClick", function() CursiveOpts.ClearIgnoreList() end)
do local fs = ignoreClear:GetFontString(); if fs then local f,s,fl = fs:GetFont(); fs:SetFont(f,s-2,fl) end end

y = y - 28

-- Store the Y offset where ignore entries begin
filtChild._ignoreStartY = y

filtChild:SetHeight((-y) + 20)


-- ############################################################
-- 9. LOGIC (options functions)
-- ############################################################

-- ============================================================
-- 9a. Tab Switching
-- ============================================================
function CursiveOpts.SelectTab(tabIndex)
    selectedTab = tabIndex

    -- Update tab visuals
    for i = 1, getn(tabButtonNames) do
        local bgTex = getglobal(tabButtonNames[i] .. "BG")
        local textObj = getglobal(tabButtonNames[i] .. "Text")
        if i == tabIndex then
            if bgTex then bgTex:SetTexture(0.25, 0.25, 0.25, 1) end
            if textObj then textObj:SetTextColor(1, 1, 1) end
        else
            if bgTex then bgTex:SetTexture(0.15, 0.15, 0.15, 0.8) end
            if textObj then textObj:SetTextColor(0.82, 0.82, 0.82) end
        end
    end

    -- Show/hide panels
    for i = 1, getn(panelFrameNames) do
        local panel = getglobal(panelFrameNames[i])
        if panel then
            if i == tabIndex then
                panel:Show()
            else
                panel:Hide()
            end
        end
    end

    -- Reset scroll to top and update scroll state after panel visibility change
    -- Tab order: 1=General, 2=Raid, 3=Class, 4=Display, 5=Filter
    local scrollNames = {
        "CursiveGeneralScroll", "CursiveRaidScroll",
        nil, "CursiveDisplayScroll", "CursiveFilterScroll"
    }
    local sfName = scrollNames[tabIndex]
    if sfName then
        local sf = getglobal(sfName)
        if sf then
            sf:SetVerticalScroll(0)
            if sf.update_scroll_state then
                sf.update_scroll_state()
            end
        end
    end

    -- Show/hide Toggle All button (only Raid + Class tabs)
    if tabIndex == 2 or tabIndex == 3 then
        toggleAllBtn:Show()
    else
        toggleAllBtn:Hide()
    end

    -- Show/hide Reset Frame button (only General tab)
    if tabIndex == 1 then
        resetFrameBtn:Show()
    else
        resetFrameBtn:Hide()
    end

    -- Tab-specific refresh (2=Raid, 3=Class, 5=Filter)
    if tabIndex == 2 then
        -- Raid tab
        BuildRaidContent()
        CursiveOpts.InitializeRaidCheckboxes()
    elseif tabIndex == 3 then
        -- Class tab
        if not classContentBuilt then
            BuildAllClassContent()
            classContentBuilt = true
        end
        CursiveOpts.SetClassTab(selectedClass)
    elseif tabIndex == 5 then
        -- Filter tab
        RebuildFilterContent()
    end
end

-- ============================================================
-- 9b. Initialize all controls from SavedVariables
-- ============================================================
function CursiveOpts.Initialize()
    if not Cursive or not Cursive.db or not Cursive.db.profile then
        return
    end

    local p = Cursive.db.profile

    -- General tab checkboxes
    CursiveOpts.SetCheckbox("CursiveOptEnabled", p.enabled)
    CursiveOpts.SetCheckbox("CursiveOptMove", not p.clickthrough)
    CursiveOpts.SetCheckbox("CursiveOptTestOverlay", CursiveTestOverlay_IsActive and CursiveTestOverlay_IsActive() or false)
    CursiveOpts.SetCheckbox("CursiveOptHealthBar", p.showhealthbar)
    CursiveOpts.SetCheckbox("CursiveOptUnitName", p.showunitname)
    CursiveOpts.SetCheckbox("CursiveOptRaidIcons", p.showraidicons)
    CursiveOpts.SetCheckbox("CursiveOptInvertBars", p.invertbars)
    CursiveOpts.SetCheckbox("CursiveOptExpandUp", p.expandupwards)
    CursiveOpts.SetCheckbox("CursiveOptAlwaysTarget", p.alwaysshowcurrenttarget)
    CursiveOpts.SetCheckbox("CursiveOptCCTransparency", p.cctransparency)
    CursiveOpts.SetCheckbox("CursiveOptOORStripes", p.oorstripes)
    CursiveOpts.SetCheckbox("CursiveRaidShowMissing", p.showMissingDebuffs)
    CursiveOpts.SetCheckbox("CursiveRaidIncludeOwn", p.includeOwnRaidInOrder)

    -- General tab: Debuff Frames dropdown refresh
    for _, key in pairs({"borderownclass", "borderownraid", "borderotherclass", "borderotherraid", "borderwidth"}) do
        if borderDropButtons[key] and borderDropButtons[key].Refresh then
            borderDropButtons[key].Refresh()
        end
    end
    CursiveOpts.SetSlider("CursiveOptBorderOpacity", p.borderopacity or 85, "%d%%", "Frame Opacity")

    -- Display tab sliders
    CursiveOpts.SetSlider("CursiveOptScale", p.scale, "%.2f", "Scale")
    CursiveOpts.SetSlider("CursiveOptOpacity", p.opacity or 1.0, "%.2f", "Opacity")
    CursiveOpts.SetSlider("CursiveOptMaxCurses", p.maxcurses, "%d", "Max Debuffs")
    CursiveOpts.SetSlider("CursiveOptMaxRows", p.maxrow, "%d", "Max Targets")
    CursiveOpts.SetSlider("CursiveOptMaxCols", p.maxcol, "%d", "Columns")
    CursiveOpts.SetSlider("CursiveOptSpacing", p.spacing, "%d", "Health Bar Spacing")
    CursiveOpts.SetSlider("CursiveOptDebuffIconSpacing", p.debufficonspacing or 1, "%d", "Debuff Icon Spacing")
    CursiveOpts.SetSlider("CursiveOptHealthWidth", p.healthwidth, "%d", "Health Bar Width")
    CursiveOpts.SetSlider("CursiveOptHealthHeight", p.height, "%d", "Health Bar Height")
    CursiveOpts.SetSlider("CursiveOptRaidIconSize", p.raidiconsize, "%d", "Raid Icon Size")
    CursiveOpts.SetSlider("CursiveOptCurseIconSize", p.curseiconsize, "%d", "Debuff Icon Size")
    CursiveOpts.SetSlider("CursiveOptFontScale", p.fontscale or 1.0, "%.2f", "Font Scale")
    CursiveOpts.SetSlider("CursiveOptTextSize", p.textsize, "%d", "HP Text Size")
    CursiveOpts.SetSlider("CursiveOptNameTextSize", p.nameTextSize or p.textsize, "%d", "Name Text Size")
    CursiveOpts.SetSlider("CursiveOptArmorTextSize", p.armorTextSize or 10, "%d", "Armor Text Size")
    CursiveOpts.SetSlider("CursiveOptNameLength", p.namelength or 80, "%d", "Name Length")
    CursiveOpts.SetSlider("CursiveOptCurseTimerSize", p.cursetimersize, "%d", "Timer Size")

    -- Display tab: Debuff Timer sliders
    CursiveOpts.SetSlider("CursiveOptCurseTimeH", p.cursetimeh or 5, "%d", "Timer Horizontal")
    CursiveOpts.SetSlider("CursiveOptCurseTimeV", p.cursetimev or 5, "%d", "Timer Vertical")

    -- Display tab: Debuff Stack sliders
    CursiveOpts.SetSlider("CursiveOptStackSize", p.cursestacksize or 10, "%d", "Stack Size")
    CursiveOpts.SetSlider("CursiveOptStackH", p.cursestackh or 9, "%d", "Stack Horizontal")
    CursiveOpts.SetSlider("CursiveOptStackV", p.cursestackv or 1, "%d", "Stack Vertical")

    -- Display tab: Target Armor
    CursiveOpts.SetSlider("CursiveOptArmorPositionOffset", p.armorPositionOffset or 0, "%d", "Position")

    -- Display tab checkboxes
    -- Debuff Timer dropdown refresh
    for _, key in pairs({"durationtimercolor", "decimalDurationColor", "stackcountercolor"}) do
        if timerDropButtons[key] and timerDropButtons[key].Refresh then
            timerDropButtons[key].Refresh()
        end
    end

    -- Debuff Order dropdown refresh
    if CursiveOpts.RefreshOrderDropdowns then
        CursiveOpts.RefreshOrderDropdowns()
    end

    -- v3.2.1: Target Armor dropdowns + checkboxes
    CursiveOpts.SetCheckbox("CursiveOptArmorEnabled", p.armorStatusEnabled)
    CursiveOpts.SetCheckbox("CursiveOptArmorColor", p.armorColorIndicator)
    if CursiveOpts.armorStructureDrop and CursiveOpts.armorStructureDrop.Refresh then
        CursiveOpts.armorStructureDrop.Refresh()
    end
    if CursiveOpts.armorPositionDrop and CursiveOpts.armorPositionDrop.Refresh then
        CursiveOpts.armorPositionDrop.Refresh()
    end
    if CursiveOpts.armorIconDrop and CursiveOpts.armorIconDrop.Refresh then
        CursiveOpts.armorIconDrop.Refresh()
    end

    -- Filters tab checkboxes
    CursiveOpts.SetCheckbox("CursiveOptFilterCombat", p.filterincombat)
    CursiveOpts.SetCheckbox("CursiveOptFilterHostile", p.filterhostile)
    CursiveOpts.SetCheckbox("CursiveOptFilterTarget", p.filtertarget)
    CursiveOpts.SetCheckbox("CursiveOptFilterAttackable", p.filterattackable)
    CursiveOpts.SetCheckbox("CursiveOptFilterPlayer", p.filterplayer)
    CursiveOpts.SetCheckbox("CursiveOptFilterNotPlayer", p.filternotplayer)
    CursiveOpts.SetCheckbox("CursiveOptFilterRange", p.filterrange)
    CursiveOpts.SetCheckbox("CursiveOptFilterRaidMark", p.filterraidmark)
    CursiveOpts.SetCheckbox("CursiveOptFilterCurse", p.filterhascurse)
    CursiveOpts.SetCheckbox("CursiveOptFilterIgnored", p.filterignored)
    CursiveOpts.SetCheckbox("CursiveOptUseRegex", p.ignorelistuseregex)

    -- Raid + Class debuff checkboxes are initialized when those tabs are shown
    initialized = true
end

-- ============================================================
-- 9c. Initialize Raid Debuff Checkboxes
-- ============================================================
function CursiveOpts.InitializeRaidCheckboxes()
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    local p = Cursive.db.profile
    local sd = p.shareddebuffs

    for i = 1, getn(raidRowFrames) do
        local row = raidRowFrames[i]
        if row and row.checkbox then
            local key = row.checkbox.configKey
            if key then
                if sd and sd[key] ~= nil then
                    -- shareddebuffs key (debuff_checkbox)
                    row.checkbox:SetChecked(sd[key] and true or false)
                elseif p[key] ~= nil then
                    -- regular config key (checkbox) — e.g. showMissingDebuffs, includeOwnRaidInOrder
                    row.checkbox:SetChecked(p[key] == true)
                end
            end
        end
    end
end

-- ============================================================
-- 9d. Initialize Class Debuff Checkboxes for a class
-- ============================================================
function CursiveOpts.InitializeClassCheckboxes(className)
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    local sd = Cursive.db.profile.shareddebuffs
    if not sd then return end

    local rows = classRowFrames[className]
    if not rows then return end

    for i = 1, getn(rows) do
        local row = rows[i]
        if row and row.checkbox then
            local key = row.checkbox.configKey
            if key and sd[key] ~= nil then
                row.checkbox:SetChecked(sd[key] and true or false)
            end
        end
    end
end

-- ============================================================
-- 9e. SetCheckbox — set checkbox state by row name
-- ============================================================
function CursiveOpts.SetCheckbox(rowName, value)
    local cb = getglobal(rowName .. "Check")
    if cb then
        cb:SetChecked(value and true or false)
    end
end

-- ============================================================
-- 9f. SetSlider — set slider value (suppresses feedback loop)
-- ============================================================
function CursiveOpts.SetSlider(rowName, value, fmt, labelBase)
    local sl = getglobal(rowName .. "Slider")
    if sl then
        sl.updating = true
        sl:SetValue(value)
        -- Update label with integrated value
        if sl.labelText and labelBase and fmt then
            sl.labelText:SetText(labelBase .. ": " .. format(fmt, value))
        end
        if labelBase then
            sl.labelBase = labelBase
        end
        sl.updating = nil
    end
end

-- ============================================================
-- 9g. ToggleOption — generic checkbox toggle (profile keys)
-- ============================================================
function CursiveOpts.ToggleOption(configKey)
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end

    local p = Cursive.db.profile

    if configKey == "move_special" then
        -- Toggle: move = NOT clickthrough
        p.clickthrough = not p.clickthrough
        p.showbackdrop = not p.clickthrough  -- backdrop on when moveable
        if Cursive.UpdateFramesFromConfig then Cursive.UpdateFramesFromConfig() end
        -- Update the checkbox visual (checked = moveable = NOT clickthrough)
        local cb = getglobal("CursiveOptMoveCheck")
        if cb then cb:SetChecked(not p.clickthrough) end
        return
    end

    if configKey == "testoverlay_special" then
        -- Toggle Test Overlay
        if CursiveTestOverlay_IsActive and CursiveTestOverlay_IsActive() then
            CursiveTestOverlay_Disable()
        else
            CursiveTestOverlay_Enable()
        end
        -- Update checkbox visual
        local cb = getglobal("CursiveOptTestOverlayCheck")
        if cb then cb:SetChecked(CursiveTestOverlay_IsActive and CursiveTestOverlay_IsActive()) end
        return
    end

    p[configKey] = not p[configKey]

    -- Special: enabled toggle
    if configKey == "enabled" then
        if p.enabled then
            if Cursive.core and Cursive.core.enable then
                Cursive.core.enable()
            end
        else
            if Cursive.core and Cursive.core.disable then
                Cursive.core.disable()
            end
        end
    end

    if Cursive.UpdateFramesFromConfig then
        Cursive.UpdateFramesFromConfig()
    end
end

-- ============================================================
-- 9h. ToggleDebuff — toggle shareddebuffs[key]
-- ============================================================
function CursiveOpts.ToggleDebuff(debuffKey)
    if not debuffKey then return end
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    if not Cursive.db.profile.shareddebuffs then return end

    Cursive.db.profile.shareddebuffs[debuffKey] = not Cursive.db.profile.shareddebuffs[debuffKey]

    -- v3.2.1: Refresh test overlay when toggling debuffs
    if CursiveTestOverlay_Refresh then
        CursiveTestOverlay_Refresh()
    end

    -- v3.2.1: Rebuild raid order icons when toggling a raid debuff
    if CursiveOpts.RebuildRaidOrder then
        CursiveOpts.RebuildRaidOrder()
    end

    if Cursive.UpdateFramesFromConfig then
        Cursive.UpdateFramesFromConfig()
    end
end

-- ============================================================
-- 9i. OnSliderChanged — generic slider change handler
-- ============================================================
function CursiveOpts.OnSliderChanged(configKey, slider, fmt)
    if slider.updating then return end
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end

    local value = slider:GetValue()

    -- Round to step precision
    local lo, hi = slider:GetMinMaxValues()
    local step = slider:GetValueStep()
    if step and step > 0 then
        value = floor(value / step + 0.5) * step
        value = floor(value * 1000 + 0.5) / 1000
    end

    local p = Cursive.db.profile
    if p[configKey] == value then return end
    p[configKey] = value

    -- Update label text with integrated value
    if slider.labelText and slider.labelBase and fmt then
        slider.labelText:SetText(slider.labelBase .. ": " .. format(fmt, value))
    end

    -- Opacity: apply directly without full rebuild (avoids 3s reset cycle)
    if configKey == "opacity" then
        if Cursive.ui and Cursive.ui.rootBarFrame then
            Cursive.ui.rootBarFrame:SetAlpha(value)
        end
        return
    end

    if Cursive.UpdateFramesFromConfig then
        Cursive.UpdateFramesFromConfig()
    end
end

-- ============================================================
-- 9j. Restore Section Settings — only resets active tab
-- ============================================================
function CursiveOpts.RestoreDefaults()
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end

    local p = Cursive.db.profile

    -- Tab order: 1=General, 2=Raid, 3=Class, 4=Display, 5=Filter
    if selectedTab == 1 then
        -- General tab
        for _, key in ipairs(GENERAL_KEYS) do
            if DEFAULTS[key] ~= nil then
                p[key] = DEFAULTS[key]
            end
        end
        -- Debuff Frames border options
        p.borderownclass = "off"
        p.borderotherclass = "off"
        p.borderownraid = "off"
        p.borderotherraid = "off"
        p.borderwidth = 2
        p.borderopacity = 85
        p.durationtimercolor = "white"
        p.stackcountercolor = "white"
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r General settings restored to defaults.")

    elseif selectedTab == 2 then
        -- Raid tab: reset shareddebuffs for raid keys
        if p.shareddebuffs then
            local data = GetOptionsData()
            if data and data.allRaidKeys then
                for _, key in ipairs(data.allRaidKeys) do
                    p.shareddebuffs[key] = false
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Raid debuff settings restored to defaults.")

    elseif selectedTab == 3 then
        -- Class tab: reset shareddebuffs for all class keys
        if p.shareddebuffs then
            local data = GetOptionsData()
            if data and data.classDebuffs then
                for _, className in ipairs(CLASS_ORDER) do
                    local keys
                    if className == "procs" then
                        keys = data.raidWeaponProcKeys
                    else
                        keys = data.classDebuffs[className]
                    end
                    if keys then
                        for _, key in ipairs(keys) do
                            p.shareddebuffs[key] = false
                        end
                    end
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Class debuff settings restored to defaults.")

    elseif selectedTab == 4 then
        -- Display tab
        for _, key in ipairs(DISPLAY_KEYS) do
            if DEFAULTS[key] ~= nil then
                p[key] = DEFAULTS[key]
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Display settings restored to defaults.")

    elseif selectedTab == 5 then
        -- Filter tab
        for _, key in ipairs(FILTER_KEYS) do
            if DEFAULTS[key] ~= nil then
                p[key] = DEFAULTS[key]
            end
        end
        p.ignorelist = {}
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Filter settings restored to defaults.")
    end

    CursiveOpts.Initialize()
    CursiveOpts.SelectTab(selectedTab)
    if Cursive.UpdateFramesFromConfig then
        Cursive.UpdateFramesFromConfig()
    end
end


-- ============================================================
-- 9k0. Toggle All (Raid or Class depending on active tab)
-- ============================================================
function CursiveOpts.ToggleAll()
    if selectedTab == 2 then
        -- Raid: check if all enabled
        local data = GetOptionsData()
        if data and data.allRaidKeys and Cursive.db.profile.shareddebuffs then
            local allOn = true
            for _, key in ipairs(data.allRaidKeys) do
                if not Cursive.db.profile.shareddebuffs[key] then
                    allOn = false
                    break
                end
            end
            if allOn then
                CursiveOpts.SetAllRaid(false)
            else
                CursiveOpts.SetAllRaid(true)
            end
        end
    elseif selectedTab == 3 then
        -- Class: check if all enabled for current class
        local data = GetOptionsData()
        if data and Cursive.db.profile.shareddebuffs then
            local keys
            if selectedClass == "procs" then
                keys = data.raidWeaponProcKeys
            else
                keys = data.classDebuffs and data.classDebuffs[selectedClass]
            end
            if keys then
                local allOn = true
                for _, key in ipairs(keys) do
                    if not Cursive.db.profile.shareddebuffs[key] then
                        allOn = false
                        break
                    end
                end
                if allOn then
                    CursiveOpts.SetAllClass(false)
                else
                    CursiveOpts.SetAllClass(true)
                end
            end
        end
    end
end

-- ============================================================
-- 9k. Enable/Disable All — Raid
-- ============================================================
function CursiveOpts.EnableAllRaid()
    CursiveOpts.SetAllRaid(true)
end

function CursiveOpts.DisableAllRaid()
    CursiveOpts.SetAllRaid(false)
end

function CursiveOpts.SetAllRaid(value)
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    if not Cursive.db.profile.shareddebuffs then return end

    local data = GetOptionsData()
    if not data or not data.allRaidKeys then return end

    for _, key in ipairs(data.allRaidKeys) do
        Cursive.db.profile.shareddebuffs[key] = value
    end

    -- Update checkboxes
    CursiveOpts.InitializeRaidCheckboxes()

    -- Update raid order icons
    if CursiveOpts.RebuildRaidOrder then
        CursiveOpts.RebuildRaidOrder()
    end

    if Cursive.UpdateFramesFromConfig then
        Cursive.UpdateFramesFromConfig()
    end
end

-- ============================================================
-- 9l. Enable/Disable All — Class
-- ============================================================
function CursiveOpts.EnableAllClass()
    CursiveOpts.SetAllClass(true)
end

function CursiveOpts.DisableAllClass()
    CursiveOpts.SetAllClass(false)
end

function CursiveOpts.SetAllClass(value)
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    if not Cursive.db.profile.shareddebuffs then return end

    local data = GetOptionsData()
    if not data then return end

    -- Special case: "procs" loads raidWeaponProcKeys
    local keys
    if selectedClass == "procs" then
        keys = data.raidWeaponProcKeys
    else
        if not data.classDebuffs then return end
        keys = data.classDebuffs[selectedClass]
    end
    if not keys then return end

    for _, key in ipairs(keys) do
        Cursive.db.profile.shareddebuffs[key] = value
    end

    -- Update checkboxes
    CursiveOpts.InitializeClassCheckboxes(selectedClass)

    if Cursive.UpdateFramesFromConfig then
        Cursive.UpdateFramesFromConfig()
    end
end

-- ============================================================
-- 9m. Class Sub-Tab Switching
-- ============================================================
function CursiveOpts.SetClassTab(className)
    selectedClass = className

    -- Update sub-tab visuals
    for _, cn in ipairs(CLASS_ORDER) do
        local btn = classSubTabs[cn]
        if btn then
            local cc = CLASS_COLORS[cn] or { 0.5, 0.5, 0.5 }
            local bgTex = getglobal(btn:GetName() .. "BG")
            if cn == className then
                bgTex:SetTexture(cc[1] * 0.5, cc[2] * 0.5, cc[3] * 0.5, 1)
            else
                bgTex:SetTexture(cc[1] * 0.4, cc[2] * 0.4, cc[3] * 0.4, 0.8)
            end
        end
    end

    -- Show/hide scroll panels
    for _, cn in ipairs(CLASS_ORDER) do
        local info = classScrollPanels[cn]
        if info and info.container then
            if cn == className then
                info.container:Show()
            else
                info.container:Hide()
            end
        end
    end

    -- Initialize checkboxes for this class
    CursiveOpts.InitializeClassCheckboxes(className)
end

-- ============================================================
-- 9n. Ignore List
-- ============================================================
function CursiveOpts.AddTargetToIgnore()
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    if not UnitExists("target") then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r No target selected.")
        return
    end

    local name = UnitName("target")
    if not name or name == "" then return end

    local list = Cursive.db.profile.ignorelist
    if not list then
        list = {}
        Cursive.db.profile.ignorelist = list
    end

    -- Check duplicates
    for i = 1, getn(list) do
        if list[i] == name then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r '" .. name .. "' is already in the ignore list.")
            return
        end
    end

    tinsert(list, name)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Added '" .. name .. "' to ignore list.")
    RebuildFilterContent()
end

function CursiveOpts.ClearIgnoreList()
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    Cursive.db.profile.ignorelist = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Ignore list cleared.")
    RebuildFilterContent()
end

function CursiveOpts.RemoveIgnoreEntry(index)
    if not Cursive or not Cursive.db or not Cursive.db.profile then return end
    local list = Cursive.db.profile.ignorelist
    if not list then return end
    if index >= 1 and index <= getn(list) then
        local name = list[index]
        tremove(list, index)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Removed '" .. (name or "?") .. "' from ignore list.")
    end
    RebuildFilterContent()
end


-- ============================================================
-- 9o. StaticPopupDialogs for Add Name
-- ============================================================
StaticPopupDialogs["CURSIVE_ADD_IGNORE"] = {
    text = "Enter name to add to ignore list:",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = 1,
    maxLetters = 64,
    OnAccept = function()
        local editBox = getglobal(this:GetParent():GetName() .. "EditBox")
        local text = editBox:GetText()
        if text and text ~= "" then
            if Cursive and Cursive.db and Cursive.db.profile then
                local list = Cursive.db.profile.ignorelist
                if not list then
                    list = {}
                    Cursive.db.profile.ignorelist = list
                end
                tinsert(list, text)
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Added '" .. text .. "' to ignore list.")
                RebuildFilterContent()
            end
        end
    end,
    EditBoxOnEnterPressed = function()
        local text = this:GetText()
        if text and text ~= "" then
            if Cursive and Cursive.db and Cursive.db.profile then
                local list = Cursive.db.profile.ignorelist
                if not list then
                    list = {}
                    Cursive.db.profile.ignorelist = list
                end
                tinsert(list, text)
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00Cursive:|r Added '" .. text .. "' to ignore list.")
                RebuildFilterContent()
            end
        end
        this:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function()
        this:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}


-- ============================================================
-- 10. Slash command integration
-- Deferred to PLAYER_LOGIN so AceConsole has registered first
-- ============================================================
local slashHookFrame = CreateFrame("Frame")
slashHookFrame:RegisterEvent("PLAYER_LOGIN")
slashHookFrame:SetScript("OnEvent", function()
    slashHookFrame:UnregisterEvent("PLAYER_LOGIN")

    local originalSlashHandler = SlashCmdList["CURSIVE"]

    SlashCmdList["CURSIVE"] = function(msg, editbox)
        if not msg or msg == "" then
            if CursiveOptionsFrame then
                if CursiveOptionsFrame:IsShown() then
                    CursiveOptionsFrame:Hide()
                else
                    CursiveOptionsFrame:Show()
                end
            end
            return
        end

        local lowerMsg = string.lower(msg)
        if lowerMsg == "options" or lowerMsg == "opt" or lowerMsg == "config" or lowerMsg == "settings" then
            if CursiveOptionsFrame then
                if CursiveOptionsFrame:IsShown() then
                    CursiveOptionsFrame:Hide()
                else
                    CursiveOptionsFrame:Show()
                end
            end
            return
        end

        -- Fall through to original handler
        if originalSlashHandler then
            originalSlashHandler(msg, editbox)
        end
    end
end)
