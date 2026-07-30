-- LuckyRoster: Shared, account-wide character roster for Lucky Phil's addons.
-- Tracks identity, class, and professions for every character that has logged
-- in while any consuming addon was loaded. Persisted in LuckyRosterDB so it
-- can be read across addons without each one duplicating the bookkeeping.
--
-- Usage from a consuming addon:
--   local key   = LuckyRoster:GetKey()
--   local info  = LuckyRoster:Get(key)             -- { name, realm, class, professions, lastSeen }
--   local all   = LuckyRoster:GetAll()             -- { [charKey] = info }
--   local label = LuckyRoster:FormatName(charKey)  -- class-coloured, hides realm if local
--   LuckyRoster:RegisterCallback(function() RefreshUI() end)

LuckyRoster = LuckyRoster or {}

local Roster = LuckyRoster
local callbacks = {}

local function CharKey()
    local name, realm = UnitFullName("player")
    name  = name  or UnitName("player") or "Unknown"
    realm = realm or GetRealmName()     or "Unknown"
    return name .. "-" .. realm
end

local function FireCallbacks()
    for _, fn in ipairs(callbacks) do
        local ok, err = pcall(fn)
        if not ok then
            print("|cffff5555[LuckyRoster]|r callback error: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Internal: capture current character into the roster
-- ---------------------------------------------------------------------------

local function CaptureIdentity()
    LuckyRosterDB = LuckyRosterDB or {}
    LuckyRosterDB.characters = LuckyRosterDB.characters or {}

    local key = CharKey()
    local entry = LuckyRosterDB.characters[key] or {}

    local name, realm = UnitFullName("player")
    local _, class    = UnitClass("player")

    entry.name     = name  or UnitName("player") or entry.name
    entry.realm    = realm or GetRealmName()     or entry.realm
    entry.class    = class or entry.class
    entry.lastSeen = time()
    entry.professions = entry.professions or {}

    LuckyRosterDB.characters[key] = entry
    return entry
end

local function CaptureProfessions()
    LuckyRosterDB = LuckyRosterDB or {}
    LuckyRosterDB.characters = LuckyRosterDB.characters or {}

    local key   = CharKey()
    local entry = LuckyRosterDB.characters[key] or {}
    local list  = {}

    -- GetProfessions returns up to 5 indices: primary1, primary2, archaeology, fishing, cooking.
    local indices = { GetProfessions() }
    for _, idx in ipairs(indices) do
        if idx then
            local pname, _, _, _, _, _, skillLine = GetProfessionInfo(idx)
            if pname and skillLine then
                table.insert(list, { name = pname, skillLine = skillLine })
            end
        end
    end

    entry.professions = list
    LuckyRosterDB.characters[key] = entry
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Canonical "Name-Realm" key for the current character.
function Roster:GetKey()
    return CharKey()
end

--- Full entry for a character, or nil.
function Roster:Get(charKey)
    if not LuckyRosterDB or not LuckyRosterDB.characters then return nil end
    return LuckyRosterDB.characters[charKey]
end

--- Map of all known characters: { [charKey] = entry }.
function Roster:GetAll()
    if not LuckyRosterDB or not LuckyRosterDB.characters then return {} end
    return LuckyRosterDB.characters
end

--- Sorted list of all known charKeys (alphabetical by full key).
function Roster:GetKeys()
    local keys = {}
    for k in pairs(self:GetAll()) do table.insert(keys, k) end
    table.sort(keys)
    return keys
end

--- Class token (e.g. "MAGE") for a character, or nil.
function Roster:GetClass(charKey)
    local entry = self:Get(charKey)
    return entry and entry.class or nil
end

--- List of { name, skillLine } pairs, or empty table.
function Roster:GetProfessions(charKey)
    local entry = self:Get(charKey)
    return (entry and entry.professions) or {}
end

--- Comma-separated profession names ("Inscription, Alchemy"), or nil if none.
function Roster:GetProfessionNames(charKey)
    local list = self:GetProfessions(charKey)
    if #list == 0 then return nil end
    local names = {}
    for _, p in ipairs(list) do table.insert(names, p.name) end
    return table.concat(names, ", ")
end

--- Class-coloured display string for a character. Hides the realm when it
--- matches the current player's realm.
function Roster:FormatName(charKey)
    if not charKey then return "" end

    local name, realm = charKey:match("^(.-)%-(.-)$")
    if not name or not realm then return charKey end

    local class = self:GetClass(charKey)
    local color = { r = 0.7, g = 0.7, b = 0.7 }
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        color = RAID_CLASS_COLORS[class]
    end

    local currentRealm = GetRealmName and GetRealmName() or ""
    local display = (realm == currentRealm) and name or (name .. " - " .. realm)
    return ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, display)
end

--- Force a re-scan of the current character (identity + professions).
--- Useful after a profession is learned or unlearned mid-session.
function Roster:Refresh()
    CaptureIdentity()
    CaptureProfessions()
    FireCallbacks()
end

--- Register a function to be called whenever the roster updates.
--- Returns the function (so callers can keep a handle if they need to filter later).
function Roster:RegisterCallback(fn)
    if type(fn) == "function" then
        table.insert(callbacks, fn)
    end
    return fn
end

-- ---------------------------------------------------------------------------
-- Event wiring
-- ---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "LuckyRosterFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CaptureIdentity()
        CaptureProfessions()
        FireCallbacks()
    elseif event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE" then
        CaptureProfessions()
        FireCallbacks()
    end
end)
