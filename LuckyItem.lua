-- LuckyItem: reliable asynchronous item and spell loading for Lucky Phil's
-- addons.
--
-- Item and spell data is not always available the instant an addon asks for it
-- (name, icon, quality and links arrive from the server a moment later). Code
-- that renders a row immediately ends up showing blanks that fill in on the
-- next frame. This module hands you a callback that only fires once the data is
-- actually present, and caches the result for the session so the second lookup
-- is free.
--
-- Public API:
--   LuckyItem:Get(itemID, function(info) ... end)   -- info has name/link/icon/...
--   LuckyItem:GetMany(ids, function(resultsById) ... end)
--   LuckyItem:GetCached(itemID)        -- resolved info or nil, never loads
--   LuckyItem:IsCached(itemID)         -- boolean
--   LuckyItem:GetSpell(spellID, function(info) ... end)
--
-- The callback receives a normalised table, or nil if the id could not load.

if LuckysUtilsSkipLoad then return end

LuckyItem = LuckyItem or {}

local tinsert = table.insert

-- ---------------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------------

-- Caches live on the global so a newer embedded copy inherits resolved items
-- and in-flight callback queues instead of starting cold.
LuckyItem._itemCache   = LuckyItem._itemCache or {}
LuckyItem._itemPending = LuckyItem._itemPending or {}
local itemCache   = LuckyItem._itemCache    -- itemID -> resolved info table (session lifetime)
local itemPending = LuckyItem._itemPending  -- itemID -> { callback, ... } while a load is in flight

-- Read every field we expose from the now-loaded item.
local function buildItemInfo(itemID)
    local name, link, quality, itemLevel, minLevel, itemType, itemSubType,
          _, equipLoc, icon, sellPrice, classID, subclassID, _, _, _,
          isReagent = GetItemInfo(itemID)
    return {
        id         = itemID,
        name       = name,
        link       = link,
        quality    = quality,
        icon       = icon,
        itemLevel  = itemLevel,
        minLevel   = minLevel,
        type       = itemType,
        subType    = itemSubType,
        equipLoc   = equipLoc,
        classID    = classID,
        subclassID = subclassID,
        sellPrice  = sellPrice,
        isReagent  = isReagent,
    }
end

-- Fire every queued callback for an id, then clear the queue.
local function resolveItem(itemID, info)
    local cbs = itemPending[itemID]
    itemPending[itemID] = nil
    if cbs then
        for i = 1, #cbs do
            cbs[i](info)
        end
    end
end

--- Resolve an item's data, calling `callback(info)` once name, icon, quality
--- and link are guaranteed available. Resolves immediately from cache.
---@param itemID number|string
---@param callback fun(info: table|nil)|nil
---@return table|nil cachedInfo  Non-nil only on an immediate cache hit.
function LuckyItem:Get(itemID, callback)
    itemID = tonumber(itemID)
    if not itemID then
        if callback then callback(nil) end
        return nil
    end

    local cached = itemCache[itemID]
    if cached then
        if callback then callback(cached) end
        return cached
    end

    -- A load is already in flight for this id: just join the queue.
    if itemPending[itemID] then
        if callback then tinsert(itemPending[itemID], callback) end
        return nil
    end
    itemPending[itemID] = callback and { callback } or {}

    local item = Item:CreateFromItemID(itemID)
    if item:IsItemEmpty() then
        resolveItem(itemID, nil)  -- not a real item id; don't cache, let retries happen
        return nil
    end

    item:ContinueOnItemLoad(function()
        local info = buildItemInfo(itemID)
        -- Only cache a genuine hit. If the name is still missing the load
        -- failed, so leave it uncached and a later Get will try again.
        if info.name then
            itemCache[itemID] = info
        end
        resolveItem(itemID, info)
    end)
    return nil
end

--- Load many items at once and call `onAllReady(resultsById)` after the last
--- one resolves. `resultsById[itemID]` is the info table (or nil if it failed).
--- Ideal for rendering a list without per-row flicker.
---@param ids table  Array of item ids.
---@param onAllReady fun(resultsById: table)|nil
---@return table resultsById  The same table that will be populated.
function LuckyItem:GetMany(ids, onAllReady)
    local results = {}

    local valid = {}
    for i = 1, #ids do
        local n = tonumber(ids[i])
        if n then valid[#valid + 1] = n end
    end

    local remaining = #valid
    if remaining == 0 then
        if onAllReady then onAllReady(results) end
        return results
    end

    for i = 1, #valid do
        self:Get(valid[i], function(info)
            results[valid[i]] = info
            remaining = remaining - 1
            if remaining == 0 and onAllReady then
                onAllReady(results)
            end
        end)
    end
    return results
end

--- Return an item's cached info without ever triggering a load. Use on a
--- synchronous render path; pair with Get to warm the cache first.
---@param itemID number|string
---@return table|nil
function LuckyItem:GetCached(itemID)
    return itemCache[tonumber(itemID) or 0]
end

--- True if the item's data is already resolved and cached this session.
---@param itemID number|string
---@return boolean
function LuckyItem:IsCached(itemID)
    return itemCache[tonumber(itemID) or 0] ~= nil
end

-- ---------------------------------------------------------------------------
-- Spells
-- ---------------------------------------------------------------------------

LuckyItem._spellCache   = LuckyItem._spellCache or {}
LuckyItem._spellPending = LuckyItem._spellPending or {}
local spellCache   = LuckyItem._spellCache
local spellPending = LuckyItem._spellPending

local function buildSpellInfo(spellID)
    local data = C_Spell.GetSpellInfo(spellID)
    if not data then return nil end
    return {
        id       = spellID,
        name     = data.name,
        icon     = data.iconID,
        castTime = data.castTime,
    }
end

local function resolveSpell(spellID, info)
    local cbs = spellPending[spellID]
    spellPending[spellID] = nil
    if cbs then
        for i = 1, #cbs do
            cbs[i](info)
        end
    end
end

--- Resolve a spell's data, calling `callback(info)` once name and icon are
--- available. Mirrors Get for items.
---@param spellID number|string
---@param callback fun(info: table|nil)|nil
---@return table|nil cachedInfo
function LuckyItem:GetSpell(spellID, callback)
    spellID = tonumber(spellID)
    if not spellID then
        if callback then callback(nil) end
        return nil
    end

    local cached = spellCache[spellID]
    if cached then
        if callback then callback(cached) end
        return cached
    end

    if spellPending[spellID] then
        if callback then tinsert(spellPending[spellID], callback) end
        return nil
    end
    spellPending[spellID] = callback and { callback } or {}

    local spell = Spell:CreateFromSpellID(spellID)
    if spell:IsSpellEmpty() then
        resolveSpell(spellID, nil)
        return nil
    end

    spell:ContinueOnSpellLoad(function()
        local info = buildSpellInfo(spellID)
        if info and info.name then
            spellCache[spellID] = info
        end
        resolveSpell(spellID, info)
    end)
    return nil
end
