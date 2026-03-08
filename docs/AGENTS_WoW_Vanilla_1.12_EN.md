# Vanilla WoW 1.12 Addon Development - AGENTS.md

> **IMPORTANT:** Read this document BEFORE any addon work!
> 
> Vanilla WoW 1.12 uses **Lua 5.0** – modern Lua syntax will cause errors!

---

## Golden Rules (Read First!)

1. **Never use parameter names `event`, `arg1`, `self` in handlers** - They shadow globals!
2. **Localize event args immediately:** `local evt, a1, a2 = event, arg1, arg2`
3. **Use `this` not `self`** for frame reference in handlers
4. **Use `string.find()` with captures** - `string.match()` doesn't exist!
5. **Use `string.gfind()` for iteration** - `string.gmatch()` doesn't exist!
6. **Use `table.getn(t)`** - `#table` operator doesn't exist!
7. **Use `unpack(t)`** - `table.unpack()` doesn't exist!
8. **No C_* namespaces** - `C_Timer`, `C_Container`, etc. don't exist!
9. **Manual hooking only** - `hooksecurefunc()` doesn't exist!
10. **Use `arg` table for varargs** - `{...}` syntax does not exist in Lua 5.0!
11. **Declare ALL variables `local`** - Variables are global by default in Lua 5.0!

---

## Quick Reference - Critical Differences

### ❌ WRONG (Lua 5.1+ / WoW 1.13+) → ✅ CORRECT (Lua 5.0 / WoW 1.12)

| WRONG | CORRECT | Note |
|-------|---------|------|
| `function(self, event, ...)` | `function()` | Event handlers use globals |
| `self` | `this` | Frame reference in handlers |
| Parameters `event, arg1, ...` | Globals `event`, `arg1`-`arg9` | Automatically available |
| `#table` | `table.getn(table)` | Table length |
| `select("#", ...)` | `arg.n` | Vararg count (in vararg functions) |
| `select(n, ...)` | `arg[n]` | Vararg access (in vararg functions) |
| `{...}` | `arg` | Syntax does not exist in Lua 5.0 |
| `table.unpack(t)` | `unpack(t)` | Global function |
| `string.match(s, p)` | `string.find(s, p)` | With captures |
| `string.gmatch(s, p)` | `string.gfind(s, p)` | Iterator |
| `s:find(p)` | `string.find(s, p)` | No method syntax |
| `hooksecurefunc()` | Manual hooking | Does not exist |
| `C_Timer.After()` | OnUpdate with timer | C_* does not exist |
| `table.wipe(t)` | `for k in pairs(t) do t[k]=nil end` | Does not exist |

---

## Validation Checklist

**Check BEFORE every code output:**

- [ ] `this` instead of `self` in all handlers
- [ ] `event`, `arg1`-`arg9` as globals (no parameters)
- [ ] **Event args localized immediately** in handler
- [ ] `table.getn()` instead of `#` for table length
- [ ] `string.find()` instead of `string.match()`
- [ ] `string.gfind()` instead of `string.gmatch()`
- [ ] `unpack()` instead of `table.unpack()`
- [ ] `arg` table instead of `{...}` for varargs
- [ ] No `C_*` namespace functions
- [ ] No `function(self, event, ...)` signature
- [ ] **All variables declared `local`** (no accidental globals)
- [ ] TOC: `## Interface: 11200`
- [ ] No `hooksecurefunc()` – use manual hooking

---

## Part 1: Event Handlers (MOST COMMON ERROR!)

### Correct Structure

```lua
-- ✅ CORRECT: Vanilla 1.12 Pattern
local frame = CreateFrame("Frame", "MyAddonFrame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function()
    -- Globals available:
    -- this    = the frame
    -- event   = event name as string
    -- arg1-9  = event arguments
    
    if event == "ADDON_LOADED" and arg1 == "MyAddon" then
        this:UnregisterEvent("ADDON_LOADED")
        MyAddon_Initialize()
    elseif event == "PLAYER_LOGIN" then
        MyAddon_OnLogin()
    end
end)

-- ❌ WRONG: Classic 1.13+ Pattern (does NOT work!)
frame:SetScript("OnEvent", function(self, event, ...)
    -- This signature does not exist in 1.12!
end)
```

### ⚠️ CRITICAL: arg# Globals Are NOT Cleared!

In Vanilla 1.12 (and TurtleWoW), **event arguments are NOT reliably reset between calls**. The `arg1`-`arg9` globals may retain values from parent contexts or previous events!

**Robust Pattern - Localize args immediately:**

```lua
frame:SetScript("OnEvent", function()
    -- Copy globals to locals IMMEDIATELY at start of handler
    -- This prevents issues with nested calls or stale values
    local evt = event
    local a1, a2, a3, a4, a5 = arg1, arg2, arg3, arg4, arg5
    
    if evt == "ADDON_LOADED" and a1 == "MyAddon" then
        this:UnregisterEvent("ADDON_LOADED")
        MyAddon_Initialize()
    elseif evt == "CHAT_MSG_SAY" then
        -- a1 = message, a2 = sender
        MyAddon_ProcessChat(a1, a2)
    end
end)
```

**Why this matters:**
- `arg1`-`arg9` are **volatile global scratch variables** - never trust them to be nil/reset
- If you call another function that triggers an event, arg# may change mid-handler
- Some events like `PLAYER_TARGET_CHANGED` explicitly document: "arg1-9: Undefined. Not cleared."
- Events without payload may leave arg# **stale** from previous calls (server/fork-specific)
- **Always copy to locals at handler start** to avoid subtle, hard-to-debug issues

### OnUpdate Handler

```lua
-- ✅ CORRECT: Standard Vanilla Pattern
frame:SetScript("OnUpdate", function()
    local elapsed = arg1  -- Time since last frame
    this.timer = (this.timer or 0) + elapsed
    if this.timer >= 1 then
        this.timer = 0
        -- Action every 1 second
    end
end)

-- ✅ ROBUST: Supports both parameter and global (XML handlers may pass elapsed)
frame:SetScript("OnUpdate", function(_, elapsed)
    local dt = elapsed or arg1  -- Use parameter if available, fallback to arg1
    this.timer = (this.timer or 0) + (dt or 0)
    if this.timer >= 1 then
        this.timer = 0
        -- Action every 1 second
    end
end)
```

> **Note:** WoWWiki documents: "The local 'elapsed' (Global is arg1)". XML-based handlers often pass `elapsed` as parameter, while Lua-only handlers use `arg1`. The robust pattern handles both.

### OnClick Handler

```lua
-- ✅ CORRECT
button:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        -- Left click
    elseif arg1 == "RightButton" then
        -- Right click
    end
end)
```

### ⚠️ Global Scope Warning (Lua 5.0 Specific)

In Lua 5.0, variables are **GLOBAL by default** unless declared `local`. Inside functions, ALWAYS use `local` for temporary variables to avoid polluting the global namespace (which causes conflicts with other addons).

```lua
-- ❌ WRONG
function MyAddon_Calc()
    temp = 5  -- Becomes a global variable "temp"!
    result = temp * 2  -- Also global!
end

-- ✅ CORRECT
function MyAddon_Calc()
    local temp = 5
    local result = temp * 2
    return result
end
```

**Best Practice:** Wrap your entire addon in a local table to prevent namespace pollution:

```lua
local MyAddon = {}
MyAddon.settings = {}
MyAddon.frames = {}

function MyAddon:Initialize()
    -- All addon code here
end
```

### ⚠️ Performance: Avoid Table Creation in Loops

The Lua 5.0 garbage collector is significantly more aggressive and slower than modern versions. Creating new tables in `OnUpdate` causes micro-stutters.

```lua
-- ❌ WRONG: Creates new table every frame (60x per second!)
frame:SetScript("OnUpdate", function()
    local pos = {x = this:GetLeft(), y = this:GetTop()}  -- GC pressure!
    ProcessPosition(pos)
end)

-- ✅ CORRECT: Reuse table
local posCache = {x = 0, y = 0}
frame:SetScript("OnUpdate", function()
    posCache.x = this:GetLeft()
    posCache.y = this:GetTop()
    ProcessPosition(posCache)
end)
```

---

## Part 2: Important Events with Arguments

### Addon Lifecycle

| Event | Description | Arguments |
|-------|-------------|-----------|
| `ADDON_LOADED` | Addon loaded; **SavedVariables for THIS addon are now available** | `arg1` = AddonName |
| `VARIABLES_LOADED` | **All** addons and SavedVariables loaded (global milestone) | - |
| `PLAYER_LOGIN` | Player logged in | - |
| `PLAYER_ENTERING_WORLD` | Zone entered/changed | - |
| `PLAYER_LOGOUT` | Logging out | - |

### Unit Events

| Event | Description | Arguments |
|-------|-------------|-----------|
| `UNIT_HEALTH` | HP changed | `arg1` = unitId |
| `UNIT_MANA` | Mana changed | `arg1` = unitId |
| `PLAYER_TARGET_CHANGED` | Target changed | **Args undefined/not cleared!** |
| `UPDATE_MOUSEOVER_UNIT` | Mouseover changed | - |
| `UNIT_AURA` | Buff/Debuff changed | `arg1` = unitId |

### Combat Events

| Event | Description | Arguments |
|-------|-------------|-----------|
| `PLAYER_REGEN_DISABLED` | Combat started | - |
| `PLAYER_REGEN_ENABLED` | Combat ended | - |
| `PLAYER_DEAD` | Player died | - |
| `SPELLCAST_START` | Cast started (cast-time spells only) | `arg1` = spellName, `arg2` = castTime |
| `SPELLCAST_STOP` | Cast ended (instant spells fire only STOP) | SpellName **not reliable** |
| `SPELLCAST_INTERRUPTED` | Cast interrupted | - |
| `SPELLCAST_FAILED` | Cast failed | - |

> ⚠️ **Note:** `SPELLCAST_*` events were removed in 2.0.1 (TBC). Arguments may vary by client. For reliable spell tracking, check success via debuff/buff presence or use timers after `SPELLCAST_STOP`.

### Chat Events

| Event | Description | Arguments |
|-------|-------------|-----------|
| `CHAT_MSG_SAY` | /say message | `arg1`=text, `arg2`=sender |
| `CHAT_MSG_YELL` | /yell message | `arg1`=text, `arg2`=sender |
| `CHAT_MSG_WHISPER` | Whisper received | `arg1`=text, `arg2`=sender |
| `CHAT_MSG_WHISPER_INFORM` | Whisper sent | `arg1`=text, `arg2`=target |
| `CHAT_MSG_PARTY` | Party chat | `arg1`=text, `arg2`=sender |
| `CHAT_MSG_RAID` | Raid chat | `arg1`=text, `arg2`=sender |
| `CHAT_MSG_GUILD` | Guild chat | `arg1`=text, `arg2`=sender |
| `CHAT_MSG_CHANNEL` | Channel chat | `arg1`=text, `arg2`=sender, `arg9`=channelName* |
| `CHAT_MSG_ADDON` | Addon message | `arg1`=prefix, `arg2`=message, `arg3`=channel, `arg4`=sender |
| `CHAT_MSG_SYSTEM` | System message | `arg1`=text |
| `CHAT_MSG_LOOT` | Loot message | `arg1`=text |

> *`CHAT_MSG_CHANNEL` has complex arg layout (channel name/number varies). Consult WoWWiki "Events/Communication" for full details.

### UI Events

| Event | Description | Arguments |
|-------|-------------|-----------|
| `BAG_UPDATE` | Bag changed | `arg1` = bagId (0-4) |
| `ACTIONBAR_SLOT_CHANGED` | Actionbar changed | `arg1` = slot |
| `MERCHANT_SHOW` | Vendor opened | - |
| `MERCHANT_CLOSED` | Vendor closed | - |
| `BANKFRAME_OPENED` | Bank opened | - |
| `BANKFRAME_CLOSED` | Bank closed | - |

---

## Part 3: String Functions & Patterns

### Functions (Avoid method syntax!)

```lua
-- ✅ CORRECT: Function syntax (always works)
local start, stop = string.find(text, "pattern")
local replaced = string.gsub(text, "old", "new")
local lower = string.lower(text)
local sub = string.sub(text, 1, 5)
local len = string.len(text)

-- WoW aliases (shorter, work in 1.12):
local start, stop = strfind(text, "pattern")
local replaced = gsub(text, "old", "new")
local lower = strlower(text)
local sub = strsub(text, 1, 5)
local len = strlen(text)

-- ⚠️ Method syntax: DO NOT rely on this in 1.12!
-- While Lua 5.1+ sets a string metatable enabling OO-style,
-- Lua 5.0 does not guarantee this behavior.
-- For maximum compatibility, ALWAYS use function syntax.
local lower = text:lower()     -- May work, but not guaranteed!
local sub = text:sub(1, 5)     -- May work, but not guaranteed!
```

### Pattern Classes

| Class | Meaning | Uppercase = Complement |
|-------|---------|------------------------|
| `%a` | Letters | `%A` = Non-letters |
| `%d` | Digits | `%D` = Non-digits |
| `%w` | Alphanumeric | `%W` = Non-alphanumeric |
| `%s` | Whitespace | `%S` = Non-whitespace |
| `%l` | Lowercase | `%L` = Non-lowercase |
| `%u` | Uppercase | `%U` = Non-uppercase |
| `%p` | Punctuation | `%P` = Non-punctuation |
| `%c` | Control chars | `%C` = Non-control chars |
| `%x` | Hexadecimal | `%X` = Non-hexadecimal |
| `.` | Any character | - |

### Pattern Modifiers

| Mod | Meaning |
|-----|---------|
| `+` | 1 or more (greedy) |
| `*` | 0 or more (greedy) |
| `-` | 0 or more (lazy/minimal) |
| `?` | 0 or 1 |

### Pattern Examples

```lua
-- Captures with string.find
local _, _, name, level = string.find(text, "(%a+) reached Level (%d+)")

-- Iterator with string.gfind (NOT gmatch!)
for word in string.gfind(text, "%w+") do
    print(word)
end

-- gsub with capture reference
local swapped = string.gsub("hello world", "(%w+) (%w+)", "%2 %1")
-- Result: "world hello"

-- Escaping magic characters: % . [ ] ^ $ ( ) * + - ?
local escaped = string.gsub(text, "%(", "%%%(")
```

### Color Codes (Escape Sequences)

Format: `|cAARRGGBB` ... `|r`
- AA = Alpha (usually FF)
- RR, GG, BB = Hex color values

```lua
local RED = "|cFFFF0000"
local GREEN = "|cFF00FF00"
local YELLOW = "|cFFFFFF00"
local WHITE = "|cFFFFFFFF"
local RESET = "|r"

-- Usage
print(RED .. "Error:" .. RESET .. " Something went wrong.")
DEFAULT_CHAT_FRAME:AddMessage(GREEN .. "[MyAddon]" .. RESET .. " Loaded!")
```

**Common WoW/TurtleWoW Colors:**

| Color | Code | Usage |
|-------|------|-------|
| System Yellow | `|cFFFFFF00` | System messages |
| Poor (Gray) | `|cFF9D9D9D` | Item quality |
| Common (White) | `|cFFFFFFFF` | Item quality |
| Uncommon (Green) | `|cFF1EFF00` | Item quality |
| Rare (Blue) | `|cFF0070DD` | Item quality |
| Epic (Purple) | `|cFFA335EE` | Item quality |
| Legendary (Orange) | `|cFFFF8000` | Item quality |
| Horde (Red) | `|cFFFF0000` | Faction |
| Alliance (Blue) | `|cFF00AEFF` | Faction |

**Item Links:** Use `|Hitem:itemId:...|h[Item Name]|h` for clickable links.

---

## Part 4: Table Functions

```lua
-- Get length
local count = table.getn(myTable)  -- or getn(myTable)

-- Insert
table.insert(t, value)           -- At end
table.insert(t, 1, value)        -- At beginning
tinsert(t, value)                -- WoW alias

-- Remove
table.remove(t)                  -- Last element
table.remove(t, 1)               -- First element
tremove(t)                       -- WoW alias

-- Sort
table.sort(t)
table.sort(t, function(a, b) return a > b end)

-- Concatenate
local str = table.concat({"a", "b", "c"}, ", ")  -- "a, b, c"

-- Unpack
local a, b, c = unpack(myTable)  -- NOT table.unpack!

-- Clear table (no table.wipe!)
for k in pairs(t) do t[k] = nil end
```

### Iteration

```lua
-- Numeric arrays
for i = 1, table.getn(t) do
    local v = t[i]
end

-- or with ipairs (works in 5.0)
for i, v in ipairs(t) do
    -- ...
end

-- Hash tables
for k, v in pairs(t) do
    -- Order NOT guaranteed!
end
```

---

## Part 4b: Compatibility Helper Functions

These helper functions provide a clean abstraction layer for common 1.12-specific patterns. Include them at the top of your addon to reduce errors:

```lua
-- Table length (replacement for #table)
local function tlen(t)
    return table.getn(t)
end

-- Table wipe (doesn't exist in 5.0)
local function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

-- String match with single capture (replacement for string.match)
local function strmatch1(s, pattern)
    local _, _, capture = string.find(s or "", pattern)
    return capture
end

-- String match with multiple captures
local function strmatch(s, pattern)
    local _, _, c1, c2, c3, c4, c5 = string.find(s or "", pattern)
    return c1, c2, c3, c4, c5
end

-- Split command string (for slash commands)
local function strsplitcmd(msg)
    local _, _, cmd, rest = string.find(msg or "", "^(%S+)%s*(.*)$")
    return cmd or msg or "", rest or ""
end

-- Pack varargs into table with count
local function pack(...)
    return arg  -- In 5.0, arg is already the packed table with .n
end

-- Safe string format for DEBUG LOGS (primarily %s formats)
-- NOTE: string.format("%d", nil) cannot be made "safe" - this helper
-- replaces nil with "nil" string, which works for %s but NOT for %d/%f.
-- For numeric formats, provide explicit defaults in your code.
local function safeformat(fmt, ...)
    local tmp = {}
    for i = 1, arg.n do
        local v = arg[i]
        if v == nil then v = "nil" end
        tmp[i] = v
    end
    return string.format(fmt, unpack(tmp))
end
```

**Usage Examples:**

```lua
-- Instead of: local len = #myTable
local len = tlen(myTable)

-- Instead of: table.wipe(myTable)
wipe(myTable)

-- Instead of: local name = string.match(text, "Hello (%w+)")
local name = strmatch1(text, "Hello (%w+)")

-- Slash command parsing
local cmd, args = strsplitcmd(msg)
```

---

## Part 5: Vararg Handling

In Lua 5.0, vararg functions use `...` in the parameter list. The extra arguments are collected in an implicit table named `arg` with `arg.n` containing the count.

```lua
-- ✅ CORRECT: Vararg function with implicit arg table
function MyFunc(...)
    -- arg contains all extra arguments
    -- arg.n = count of extra arguments
    
    for i = 1, arg.n do
        print("Argument "..i..": "..tostring(arg[i]))
    end
end

-- Mixed fixed + vararg parameters
function MyFunc2(a, b, ...)
    -- a and b are fixed parameters
    -- arg contains only the EXTRA arguments (after a and b)
    -- arg[1] is the 3rd passed argument, NOT the 1st!
    
    print("a = "..tostring(a))
    print("b = "..tostring(b))
    print("Extra args: "..arg.n)
end

-- Pass varargs to another function
function Wrapper(...)
    OtherFunction(unpack(arg))
end

-- ❌ WRONG: These patterns do NOT exist in Lua 5.0
function BadFunc(...)
    local args = {...}          -- Syntax Error in 5.0!
    local n = select("#", ...)  -- select() does not exist in 5.0!
end
```

> **Lua 5.0 Varargs:** Always use `arg`/`arg.n`. The `{...}` and `select()` patterns are Lua 5.1+ features and are not part of the Lua 5.0 language.

---

## Part 6: Addon Structure

### Directory

```
Interface/AddOns/MyAddon/
├── MyAddon.toc          # MUST have same name as folder!
├── MyAddon.lua          # Main code
├── MyAddon.xml          # UI layout (optional)
├── Localization.lua     # Translations (optional)
└── Textures/            # Graphics (optional)
    └── icon.tga         # TGA format, size = multiple of 8!
```

### Texture Requirements

Vanilla WoW is strict about texture formats and dimensions:

**Formats:**
- `.tga` (Targa) - Recommended, easy to create
- `.blp` (Blizzard Picture) - Native format, smaller files

**Dimensions - Each side MUST be Power of 2:**
- Valid sizes: 16, 32, 64, 128, 256, 512, 1024
- **Non-square is OK!** Examples: 256x128, 512x64, 1024x256
- Invalid: 100x100, 200x150, 300x300 (will fail or display incorrectly!)

```lua
-- ✅ CORRECT: 256x128 texture (both dimensions are power of 2)
tex:SetTexture("Interface\\AddOns\\MyAddon\\Textures\\banner256x128")

-- File: banner256x128.tga (256x128 pixels, 32-bit with alpha)
```

**Creating TGA files:**
1. Use GIMP, Photoshop, or Paint.NET
2. Canvas size: Power of 2 (e.g., 64x64, 128x128)
3. Export as 32-bit TGA (with alpha channel)
4. Filename in Lua: Omit `.tga` extension

**Using Blizzard Textures:**
```lua
-- Icons from game files
tex:SetTexture("Interface\\Icons\\Spell_Nature_Heal")
tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

-- UI elements
tex:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
tex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
```

### TOC File

```toc
## Interface: 11200
## Title: My Addon
## Notes: Addon description
## Author: YourName
## Version: 1.0
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
## Dependencies: RequiredAddon
## OptionalDeps: OptionalAddon

Localization.lua
MyAddon.xml
MyAddon.lua
```

### SavedVariables Timing

```lua
-- ADDON_LOADED: Addon AND its SavedVariables are now loaded
-- VARIABLES_LOADED: All addons' SavedVariables loaded (less commonly used)
-- PLAYER_LOGIN: Player is in world, everything ready

-- Recommended pattern: Use ADDON_LOADED as primary init point
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "MyAddon" then
        -- SavedVariables ARE available now!
        MyAddonDB = MyAddonDB or {}
        MyAddon_LoadSettings()
        
        -- Unregister to avoid repeated calls
        this:UnregisterEvent("ADDON_LOADED")
    end
end)
```

**When to use which event:**
- `ADDON_LOADED` - Primary initialization, SavedVariables ready
- `PLAYER_LOGIN` - UI-dependent code, player info available
- `PLAYER_ENTERING_WORLD` - Zone-dependent initialization

---

## Part 7: Frame Creation & Widget API

### CreateFrame

```lua
local frame = CreateFrame("frameType", "GlobalName", parent)
-- frameType: "Frame", "Button", "CheckButton", "EditBox", 
--            "Slider", "StatusBar", "ScrollFrame", "GameTooltip", etc.
-- GlobalName: Optional, but needed for XML $parent references
-- parent: Usually UIParent
```

### XML vs. Pure Lua

In 1.12, XML can be more performant for complex UIs:

| Approach | Pros | Cons |
|----------|------|------|
| **Pure Lua** | Hot-reload friendly, easier debugging | More CreateFrame overhead |
| **XML Templates** | Faster loading, virtual frames, inheritance | Requires /reload for changes |

**Recommendation:** Use Lua for development, consider XML for final complex UIs.

```xml
<!-- Virtual frame template (XML) -->
<Frame name="MyAddonButtonTemplate" virtual="true">
    <Size x="100" y="24"/>
    <Backdrop bgFile="Interface\ChatFrame\ChatFrameBackground"/>
</Frame>
```

```lua
-- Create from template (Lua)
local btn = CreateFrame("Frame", "MyButton1", UIParent, "MyAddonButtonTemplate")
```

### Important Frame Methods

```lua
-- Positioning
frame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOfs, yOfs)
frame:SetAllPoints(otherFrame)
frame:ClearAllPoints()
frame:SetWidth(200)
frame:SetHeight(100)

-- Visibility
frame:Show()
frame:Hide()
frame:IsShown()
frame:IsVisible()
frame:SetAlpha(0.5)

-- Events
frame:RegisterEvent("EVENT_NAME")
frame:UnregisterEvent("EVENT_NAME")
frame:UnregisterAllEvents()

-- Scripts
frame:SetScript("OnEvent", function() end)
frame:SetScript("OnUpdate", function() end)
frame:SetScript("OnClick", function() end)
frame:SetScript("OnEnter", function() end)
frame:SetScript("OnLeave", function() end)

-- Strata & Level
frame:SetFrameStrata("BACKGROUND"|"LOW"|"MEDIUM"|"HIGH"|"DIALOG"|"TOOLTIP")
frame:SetFrameLevel(10)

-- Backdrop (NATIVE in 1.12, no Mixin needed!)
-- Note: In Shadowlands+, Backdrops require BackdropTemplateMixin
-- In 1.12, SetBackdrop is built into ALL frames
frame:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
frame:SetBackdropColor(0, 0, 0, 0.8)        -- Background RGBA
frame:SetBackdropBorderColor(1, 1, 1, 1)    -- Border RGBA
```

### Texture

```lua
local tex = frame:CreateTexture(nil, "ARTWORK")
tex:SetTexture("Interface\\Icons\\Spell_Nature_Heal")
tex:SetAllPoints(frame)
tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Icon crop
```

### FontString

```lua
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER", frame, "CENTER", 0, 0)
text:SetText("Hello World")
text:SetTextColor(1, 1, 0)  -- Yellow
```

---

## Part 8: Slash Commands

```lua
SLASH_MYADDON1 = "/myaddon"
SLASH_MYADDON2 = "/ma"

SlashCmdList["MYADDON"] = function(msg)
    -- Use string.find with captures (NOT string.match!)
    local _, _, cmd, rest = string.find(msg or "", "^(%S+)%s*(.*)$")
    cmd = string.lower(cmd or msg or "")
    rest = rest or ""
    
    if cmd == "show" then
        MyAddonFrame:Show()
    elseif cmd == "hide" then
        MyAddonFrame:Hide()
    elseif cmd == "config" then
        MyAddon_OpenConfig()
    else
        DEFAULT_CHAT_FRAME:AddMessage("MyAddon: /ma show|hide|config")
    end
end
```

---

## Part 9: Common API Functions

### Unit Functions

```lua
UnitName("unit")           -- Name
UnitClass("unit")          -- Class (localized)
UnitLevel("unit")          -- Level
UnitHealth("unit")         -- Current HP
UnitHealthMax("unit")      -- Max HP
UnitMana("unit")           -- Current Mana/Energy/Rage
UnitManaMax("unit")        -- Max Mana
UnitIsPlayer("unit")       -- Is player?
UnitIsDead("unit")         -- Is dead?
UnitExists("unit")         -- Does unit exist?
UnitAffectingCombat("unit") -- In combat?
UnitBuff("unit", index)    -- Buff info (1-indexed)
UnitDebuff("unit", index)  -- Debuff info
GetUnitName("unit")        -- Alternative
```

### Unit IDs

```
"player", "pet", "target", "targettarget",
"party1"-"party4", "partypet1"-"partypet4",
"raid1"-"raid40", "raidpet1"-"raidpet40",
"mouseover"
```

**SuperWoW-only Unit IDs:**
```lua
"focus"  -- Only works with SuperWoW installed!

-- Check if focus is available
if SUPERWOW_VERSION and UnitExists("focus") then
    -- Focus unit code
end
```

### Targeting

```lua
TargetUnit("unit")
ClearTarget()
TargetByName("Name")
TargetByName("Name", true)  -- Exact match
AssistUnit("unit")
```

### Inventory

```lua
GetContainerNumSlots(bagID)        -- 0=Backpack, 1-4=Bags
GetContainerItemInfo(bagID, slot)  -- texture, count, locked, quality
GetContainerItemLink(bagID, slot)  -- Item link
UseContainerItem(bagID, slot)      -- Use item
PickupContainerItem(bagID, slot)   -- Pick up item
```

### Chat

```lua
SendChatMessage("text", "SAY")
SendChatMessage("text", "PARTY")
SendChatMessage("text", "RAID")
SendChatMessage("text", "GUILD")
SendChatMessage("text", "WHISPER", nil, "PlayerName")
SendChatMessage("text", "CHANNEL", nil, "1")  -- Channel number

DEFAULT_CHAT_FRAME:AddMessage("text", r, g, b)
```

### Addon Communication (1.12!)

```lua
SendAddonMessage("PREFIX", "message", "PARTY")
-- PREFIX: Max 16 characters
-- chatType: "PARTY", "RAID", "GUILD", "BATTLEGROUND"

-- Receive:
frame:RegisterEvent("CHAT_MSG_ADDON")
-- arg1 = prefix, arg2 = message, arg3 = channel, arg4 = sender
```

### Automation & "Protected" Functions

**Key Difference from Retail/Classic:** Vanilla 1.12 does **not** have the same "Secure Execution" or "Taint" system that modern WoW uses. Many APIs that are protected in later versions can be called programmatically.

```lua
-- ✅ These work in 1.12 (would be protected/blocked in modern WoW):
CastSpellByName("Flash Heal")
TargetUnit("party1")
UseContainerItem(0, 1)
PickupContainerItem(0, 1)
```

**Functions that are generally open in 1.12:**
- `CastSpellByName()`, `CastSpell()`
- `UseAction()`, `UseContainerItem()`
- `TargetUnit()`, `TargetByName()`, `ClearTarget()`
- `PickupContainerItem()`, `PickupInventoryItem()`
- `AssistUnit()`, `FollowUnit()`

**However, be aware:**
1. **Some APIs may still be restricted** - TurtleWoW and other servers may mark specific APIs as `PROTECTED` for balance or anti-cheat reasons
2. **Server rules apply** - Full automation/botting is typically against ToS even if technically possible
3. **Test on your target server** - API availability can vary between vanilla servers

**Best Practice:** Write addons that assist the player, not fully automate gameplay. Check server-specific documentation for any restricted APIs.

---

## Part 10: TurtleWoW / SuperWoW Specific

### SuperWoW Events

| Event | Description | Arguments |
|-------|-------------|-----------|
| `UNIT_CASTEVENT` | Cast/Channel/Swing | `arg1`=casterGUID, `arg2`=targetGUID, `arg3`=eventType, `arg4`=spellID, `arg5`=duration |
| `RAW_COMBATLOG` | Raw combat log | `arg1`=originalEvent, `arg2`=eventText |

**UNIT_CASTEVENT arg3 Types:**
- `"START"` - Cast begins
- `"CAST"` - Cast successful
- `"FAIL"` - Cast failed
- `"CHANNEL"` - Channel begins
- `"MAINHAND"` - Mainhand swing
- `"OFFHAND"` - Offhand swing

### SuperWoW Check

```lua
local hasSuperWoW = SUPERWOW_VERSION ~= nil

if hasSuperWoW then
    frame:RegisterEvent("UNIT_CASTEVENT")
end
```

### Known TurtleWoW Custom Spell IDs

```lua
-- Dark Harvest (Warlock)
[52550] = { name = "Dark Harvest", duration = 7.52 }

-- Additional custom content IDs must be tested in-game
```

---

## Part 11: Manual Function Hooking

```lua
-- hooksecurefunc() does NOT exist in 1.12!
-- Use manual hooking instead:

-- Safe variant (original preserved):
local Original_ChatFrame_OnEvent = ChatFrame_OnEvent

function ChatFrame_OnEvent(evt)
    -- Localize args IMMEDIATELY (Golden Rule #2)
    local a1, a2, a3, a4 = arg1, arg2, arg3, arg4
    
    -- Custom code BEFORE original
    if evt == "CHAT_MSG_SAY" then
        MyAddon_ProcessSay(a1, a2)
    end
    
    -- Call original and RETURN its result (important for functions that return values)
    return Original_ChatFrame_OnEvent(evt)
end
```

> **Important:** Always `return` the original function's result. Some hooked functions return values that callers depend on.

---

## Part 12: Dropdown Menus

```lua
-- Create dropdown (XML or Lua)
local dropdown = CreateFrame("Frame", "MyDropdown", UIParent, "UIDropDownMenuTemplate")

-- Initialize
UIDropDownMenu_Initialize(dropdown, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    
    info.text = "Option 1"
    info.value = 1
    info.func = function() print("Option 1 selected") end
    UIDropDownMenu_AddButton(info, level)
    
    info.text = "Option 2"
    info.value = 2
    info.func = function() print("Option 2 selected") end
    UIDropDownMenu_AddButton(info, level)
end)

UIDropDownMenu_SetWidth(dropdown, 150)
UIDropDownMenu_SetText(dropdown, "Select...")
```

---

## Part 13: In-Game Testing (Chat & Macros)

### When to Use Which Method?

| Method | Character Limit | Usage |
|--------|-----------------|-------|
| `/run` or `/script` | 255 characters | Quick one-liner tests |
| Macro | 255 characters (511 with SuperWoW) | Repeatable tests, keybinds |
| WowLua Addon | Unlimited | Complex multi-line tests |
| Custom Addon | Unlimited | Final implementation |

### Chat Commands for Testing

```lua
-- Simple output
/run print("Test")
/run DEFAULT_CHAT_FRAME:AddMessage("Test", 1, 1, 0)

-- Check variable
/run print(tostring(MyAddonDB))

-- Test function
/run MyAddon_DoSomething()

-- Show table contents (first level)
/run for k,v in pairs(MyTable) do print(k..": "..tostring(v)) end

-- Frame info
/run local f=GetMouseFocus() print(f and f:GetName() or "nil")

-- Simulate event
/run MyAddonFrame_OnEvent("PLAYER_LOGIN")
```

### Macro Creation

```lua
-- Create macro: ESC → Macros → New
-- Name: Test1
-- Icon: Any

-- Example macro for DoT check:
/run local i=1 while UnitDebuff("target",i) do print(UnitDebuff("target",i)) i=i+1 end

-- Multi-line macros (each line max 255 characters):
/run local a="test"
/run print(a)  -- CAUTION: 'a' is no longer available here!
```

### Important: Variable Scope in Macros

```lua
-- ❌ WRONG: Variables don't survive line breaks
/run local x = 5
/run print(x)  -- ERROR: x is nil!

-- ✅ CORRECT: Everything in one line
/run local x=5 print(x)

-- ✅ CORRECT: Global variable (for testing)
/run TEST_VAR = 5
/run print(TEST_VAR)  -- Works!

-- ✅ CORRECT: Semicolon-separated in one line
/run local a=1; local b=2; print(a+b)
```

### Working Around Character Limit

```lua
-- Method 1: Use short forms
-- Instead of: DEFAULT_CHAT_FRAME:AddMessage("text")
-- Use: print("text")

-- Method 2: Shorten variable names
/run local f=CreateFrame local p=print local g=GetSpellInfo

-- Method 3: Pre-define functions (in addon or WowLua)
-- Then in chat just:
/run MyShortcut()

-- Method 4: SuperWoW (511 characters)
-- Automatically active when SuperWoW is installed
```

### Recommended Test Workflow

```
1. IDEA
   ↓
2. /run one-liner in chat to test
   - Works? → Continue
   - Too long? → WowLua or Macro
   ↓
3. Create macro for repeatable tests
   - Assign hotkey (e.g., F12)
   - Iterate quickly
   ↓
4. WowLua for complex tests
   - /wowlua to open
   - Write multi-line code
   - Save & Execute
   ↓
5. Create addon when stable
   - .toc + .lua files
   - /reload to test
```

### Common Test Snippets

```lua
-- List all player buffs
/run local i=1 while UnitBuff("player",i) do print(i..": "..tostring(UnitBuff("player",i))) i=i+1 end

-- Current target info
/run local n,c,l=UnitName("target"),UnitClass("target"),UnitLevel("target") print((n or "nil").." - "..(c or "?").." Lvl "..(l or "?"))

-- Identify frame under mouse
/run local f=GetMouseFocus() if f then print("Name: "..(f:GetName() or "anon").." Strata: "..f:GetFrameStrata()) end

-- Event test (simulates ADDON_LOADED)
/run arg1="MyAddon" event="ADDON_LOADED" MyAddonFrame:GetScript("OnEvent")()

-- Reset addon variables
/run MyAddonDB = nil ReloadUI()

-- Check SavedVariables
/run for k,v in pairs(MyAddonDB or {}) do print(k..": "..tostring(v)) end

-- Global search for addon functions
/run for k,v in pairs(_G) do if type(k)=="string" and strfind(k,"MyAddon") then print(k..": "..type(v)) end end
```

### Collecting Test Commands in Files

**Important:** When multiple test commands need to be executed sequentially, save them in a **plain text file** – one command per line, **without descriptions or comments**.

```
DEBUG_COMMANDS.txt
──────────────────
/run for k,v in pairs(MyAddonDB or {}) do print(k..": "..tostring(v)) end
/run print("Zone: "..GetZoneText())
/run local f=GetMouseFocus() print(f and f:GetName() or "nil")
/run MyAddon_TestFunction()
```

**Why?**
- Easy copy from file directly into game chat window
- No tedious typing from terminal
- Commands can be transferred line by line with Ctrl+C / Ctrl+V
- Fast iteration during testing

**Workflow:**
1. Claude creates debug commands in a `.txt` file
2. Open file in editor (Notepad, VS Code, etc.)
3. Select line → Ctrl+C
4. In WoW chat window → Ctrl+V → Enter
5. Test next line

**Example output from Claude:**

```
/mnt/user-data/outputs/debug_commands.txt
─────────────────────────────────────────
/run print("=== MyAddon Debug ===")
/run for k,v in pairs(MyAddonDB or {}) do print(k..": "..tostring(v)) end
/run print("Frame visible: "..tostring(MyAddonFrame:IsVisible()))
/run print("Event registered: "..tostring(MyAddonFrame:IsEventRegistered("PLAYER_LOGIN")))
```

---

### Debug Output in Code

```lua
-- Simple debug flag
MyAddon_Debug = true

local function Debug(msg)
    if MyAddon_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[MyAddon]|r "..msg)
    end
end

-- Usage:
Debug("Function called with: "..tostring(arg1))

-- Colored output
-- |cFFRRGGBB = Color code (Hex)
-- |r = Reset to default
/run DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000RED|r Normal |cFF00FF00GREEN|r")
```

### Reload vs. Logout

| Action | SavedVariables | Addon Code |
|--------|----------------|------------|
| `/reload` or `/rl` | Saved | Reloaded |
| `/logout` | Saved | - |
| Alt+F4 / Crash | NOT saved! | - |
| `/console reloadui` | Saved | Reloaded |

**Important:** After code changes always `/reload` – logging out is not necessary!

---

## Part 14: Reference Addon Analysis

> **When to use?** When a feature is unclear, API behavior unknown, or complex UI is needed.

### Phase 1: Define the Problem

**BEFORE analyzing code, clarify:**

```
┌─────────────────────────────────────────┐
│ 1. What exactly do I want to achieve?   │
│ 2. What inputs/outputs do I expect?     │
│ 3. Which events/APIs are involved?      │
│ 4. What have I already tried?           │
└─────────────────────────────────────────┘
```

**Example:**
- **Goal:** Dropdown menu with dynamic entries
- **Input:** List of sounds
- **Output:** Selected sound is played
- **Suspected APIs:** UIDropDownMenu_*, PlaySound

---

### Phase 2: Select Reference Addon

**Selection Criteria:**

- ✓ Has the feature I need
- ✓ Proven to work in 1.12/TurtleWoW
- ✓ Code is readable (not obfuscated)
- ✓ Minimal external dependencies
- ✓ Actively maintained or known stable

| Feature Category | Recommended Reference |
|------------------|----------------------|
| UI/Frames/General | pfUI |
| Unit Scanning | ShaguScan, Cursive |
| Inventory/Items | aux-addon |
| Map/Coordinates | Yatlas, Carbonite |
| Combat Log Parsing | DPSMate, KLHThreatMeter |
| Buff/Debuff Tracking | DoTimer, Cursive |

---

### Phase 3: Top-Down Analysis

**Coarse → Fine (not the other way around!)**

```
Step 1: Understand STRUCTURE
├── Read .toc → File order, dependencies
├── Identify main file
└── Recognize rough module layout

Step 2: Find ENTRY POINT
├── Slash commands → Search SlashCmdList
├── Events → RegisterEvent / SetScript("OnEvent")
├── Frames → CreateFrame calls
└── Initialization → ADDON_LOADED handler

Step 3: ISOLATE relevant code
├── Identify feature-specific functions
├── Follow call hierarchy
└── Ignore irrelevant parts
```

**Search Terms for Common Features:**

| Feature | Search for |
|---------|------------|
| Movable Frames | `SetMovable`, `StartMoving`, `OnDragStart` |
| Dropdowns | `UIDropDownMenu_Initialize`, `AddButton` |
| Scroll Frames | `FauxScrollFrame`, `ScrollFrame` |
| Tooltips | `GameTooltip`, `SetOwner`, `AddLine` |
| Slash Commands | `SlashCmdList`, `SLASH_` |
| SavedVariables | `ADDON_LOADED`, `VARIABLES_LOADED` |

---

### Phase 4: Pattern Extraction (Trace & Simplify)

**1. TRACE: Follow data flow**

```
Input → Processing → Output

Example Dropdown:
Trigger: Click on button
   ↓
UIDropDownMenu_Initialize() called
   ↓
Callback fills info table
   ↓
UIDropDownMenu_AddButton() per entry
   ↓
On selection: info.func() called
```

**2. SIMPLIFY: Reduce to core**

Remove:
- Localization (`L["text"]` → `"text"`)
- Error handling (for now)
- Optional features
- Addon-specific dependencies

**Extraction Template:**

```lua
--[[
PATTERN: [Pattern name]
SOURCE: [Addon/File/Line]
PURPOSE: [What it solves]
DEPENDENCIES: [Required APIs/Frames]
]]

-- Minimal working example:
[Code here]
```

---

### Phase 5: Adaptation

**Original Pattern → Your Context**

1. Rename variables (`MyAddon_*`)
2. Hardcoded values → Parameters/Config
3. Replace or include dependencies
4. Adjust scope (global vs local)
5. Add error handling

**Checklist Before Adaptation:**

- [ ] Do I understand WHY each line exists?
- [ ] Are there hidden dependencies?
- [ ] Which parts are optional?
- [ ] Which parts are workarounds for bugs?

---

### Phase 6: Implementation & Test

**Proceed incrementally!**

```
Step 1: Implement minimal pattern
          ↓
Step 2: Test in-game (/run or macro)
          ↓
Step 3: Works? 
          ├─ Yes → Next feature
          └─ No → Debug, back to Phase 3
          ↓
Step 4: Integrate pattern into own code
          ↓
Step 5: Test edge cases
```

---

### Example: Complete Walkthrough

**Problem:** How do I create a movable frame?

```
Phase 1 - Problem:
  → Frame should be movable with mouse
  → Position should be saved

Phase 2 - Reference:
  → pfUI does this everywhere → pfUI/modules/panel.lua

Phase 3 - Analysis:
  → Search for "Movable" or "StartMoving"
  → Find: SetMovable, RegisterForDrag, OnDragStart/Stop

Phase 4 - Extraction:
```

```lua
-- PATTERN: Movable Frame
-- SOURCE: pfUI/modules/panel.lua
-- PURPOSE: Move frame via drag

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function()
    this:StartMoving()
end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    -- Save position
    local point, _, relPoint, x, y = this:GetPoint()
    MyAddonDB.position = {point, relPoint, x, y}
end)
```

```
Phase 5 - Adaptation:
  → Keep "this" (correct for 1.12)
  → Replace MyAddonDB with own SavedVariable
  → Optional: Add modifier key (Shift+Drag)

Phase 6 - Test:
  → /reload, move frame, /reload
  → Position preserved? ✓
```

---

### Avoid Anti-Patterns

| ❌ Wrong | ✅ Correct |
|----------|------------|
| Copy entire file | Extract only relevant pattern |
| Blindly adopt without understanding | Understand every line |
| All features at once | Incrementally, one feature at a time |
| Add more code when errors occur | Return to minimal example |
| Copy reference code 1:1 | Adapt to own naming conventions |

---

### Analysis Workflow Summary

```
┌──────────────────────┐
│ 1. Define problem    │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 2. Choose reference  │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 3. Top-down analysis │
│    .toc → Events →   │
│    Functions         │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 4. Extract pattern   │
│    Trace & Simplify  │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 5. Adapt             │
│    Rename,           │
│    Dependencies      │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ 6. Implement & test  │
│    incrementally     │
└──────────────────────┘
```

---

## Part 15: Debug Tools for TurtleWoW

### Recommended Addons

| Addon | Function | Download |
|-------|----------|----------|
| **BugSack + !BugGrabber** | Collect Lua errors | github.com/McPewPew/BugSack |
| **WowLua** | In-game Lua IDE | github.com/laytya/WowLuaVanilla |
| **DevTools** | Frame Inspector (TurtleWoW) | Built-in |

### Debug Commands

```lua
-- Chat output
DEFAULT_CHAT_FRAME:AddMessage("Debug: "..tostring(variable), 1, 0, 0)

-- Dump table
for k, v in pairs(myTable) do
    DEFAULT_CHAT_FRAME:AddMessage(k..": "..tostring(v))
end

-- DevTools (TurtleWoW)
/dteval <lua code>
/dtframestack
/dtchatevent
```

---

## Part 16: Reference Resources (Curated)

> **Goal:** Reliable primary and de-facto standards for **Lua 5.0** and **Vanilla WoW 1.12**, including TurtleWoW/SuperWoW specifics.

### A) Primary Specs (Lua – Authoritative)

| Resource | Use For | URL |
|----------|---------|-----|
| **Lua 5.0 Reference Manual** | `arg`/varargs, `table.getn`, `string.find`/`gfind`, `unpack`, missing `string.match` | https://www.lua.org/manual/5.0/manual.html |
| **Lua 5.0 PDF** | Offline reference | https://www.lua.org/ftp/refman-5.0.pdf |
| **Lua 5.1 Manual (Contrast)** | Identify "modern Lua" traps (`string.match`, `#t`, `table.unpack`) | https://www.lua.org/manual/5.1/manual.html |

### B) Vanilla UI / FrameXML (1.12.1 – Primary WoW Implementation)

| Resource | Description | URL |
|----------|-------------|-----|
| **Blizzard Default UI Source** | FrameXML as "Source of Truth" for dropdowns, templates, UI patterns | https://github.com/MOUZU/Blizzard-WoW-Interface |

### C) WoW API & Events (Vanilla-Era Documentation)

| Topic | URL |
|-------|-----|
| **Event Handling Basics** (this/event/arg1..arg9) | https://wowwiki-archive.fandom.com/wiki/Handling_events |
| **AddOn Loading & SavedVariables Timing** | https://wowwiki-archive.fandom.com/wiki/AddOn_loading_process |
| **Saving Variables Between Sessions** | https://wowwiki-archive.fandom.com/wiki/Saving_variables_between_game_sessions |
| **ADDON_LOADED vs VARIABLES_LOADED Discussion** | https://www.wowinterface.com/forums/showthread.php?t=39536 |
| **Patch 1.12.0 API Changes** | https://wowwiki-archive.fandom.com/wiki/Patch_1.12.0/API_changes |
| **UIDropDownMenu Template** | https://wowwiki-archive.fandom.com/wiki/UI_Object_UIDropDownMenu |
| **Texture SetTexture** (Formats, Power-of-Two) | https://wowwiki-archive.fandom.com/wiki/API_Texture_SetTexture |

### D) TurtleWoW-Specific (Server Fork Reality)

| Resource | Note | URL |
|----------|------|-----|
| **TurtleWoW API Events** | Documents that `arg1-arg9` are NOT reliably cleared! | https://turtle-wow.fandom.com/wiki/API_Events |
| **TurtleWoW API Functions** | Server-specific additions, `PROTECTED` markers | https://turtle-wow.fandom.com/wiki/API_Functions |

### E) SuperWoW / Client Mods

| Resource | URL |
|----------|-----|
| **SuperWoW GitHub** | https://github.com/balakethelock/SuperWoW |
| **SuperWoW Features Wiki** | https://github.com/balakethelock/SuperWoW/wiki/Features |
| **SuperAPI Companion** | https://github.com/balakethelock/SuperAPI |

### F) High-Quality Reference Addons (Living Patterns)

| Addon | Why | URL |
|-------|-----|-----|
| **pfUI** | Modern, clean vanilla architecture & UI patterns | https://github.com/shagu/pfUI |
| **aux-addon-vanilla** | Complex UI/data logic (AH) within 1.12 limits | https://github.com/shirsig/aux-addon-vanilla |
| **ShaguTweaks** | Simple, readable utility patterns | https://github.com/shagu/ShaguTweaks |

### G) Tooling & Debugging (Vanilla 1.12 Versions!)

| Tool | Description | URL |
|------|-------------|-----|
| **WowLuaVanilla** | In-game Lua IDE (multi-line tests) | https://github.com/laytya/WowLuaVanilla |
| **BugSack + !BugGrabber (1.12)** | Error capture & display (install both!) | https://github.com/McPewPew/BugSack |
| **DevTools** | Frame Inspector (built into TurtleWoW) | In-game: `/dtframestack` |

> ⚠️ **Note:** Many addons on CurseForge/WoWInterface are for Retail/Classic. Always verify compatibility with 1.12.1 / Interface: 11200!

---

## Part 17: Project-Specific Insights

### Cursive (Warlock DoT Manager)

```lua
-- Cursive API examples:
Cursive:Curse("Corruption", "target", {refreshtime=2})
Cursive:Multicurse("Corruption", "HIGHEST_HP", {minhp=5000})
Cursive:Target("Corruption", "RAID_MARK", {})

-- Priorities: "HIGHEST_HP", "LOWEST_HP", "RAID_MARK"
-- Options: refreshtime, ignoretarget, minhp, maxhpperc, name, resistsound
```

### YatlasWorldMap (HD Maps)

```lua
-- Zone index problem: WoW API ≠ Yatlas Index
-- Mapping via zone names required!

-- WoW API:
local contID = GetCurrentMapContinent()  -- 1=Kalimdor, 2=Azeroth
local zoneID = GetCurrentMapZone()       -- WoW zone index

-- Yatlas uses own indices in:
-- Yatlas_ZoneIds["Azeroth"][yatlasIdx] = areaID
-- Yatlas_mapareas["Azeroth"][areaID] = {y1, y2, x1, x2}

-- Tile coordinate formula:
local tileX = math.floor(32 - (worldY / 533.33333))
local tileY = math.floor(32 - (worldX / 533.33333))
```

---

## Appendix: Quick Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| `attempt to call field 'match'` | `string.match()` does not exist | `string.find()` with captures |
| `attempt to call field 'gmatch'` | `string.gmatch()` does not exist | `string.gfind()` |
| `unexpected symbol near '#'` | `#table` syntax invalid | `table.getn(table)` |
| `attempt to index local 'self'` | `self` is nil in handler | `this` instead of `self` |
| `'arg1' is nil` | Wrong event handler signature | No parameters, use globals |
| `attempt to call 'hooksecurefunc'` | Function does not exist | Manual hooking |
| Addon doesn't load | Interface number wrong | `## Interface: 11200` |
| SavedVariables empty | Wrong initialization timing | Initialize in `ADDON_LOADED` handler |
