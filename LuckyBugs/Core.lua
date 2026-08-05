-- LuckyBugs/Core.lua: captures, de-duplicates and formats Lua errors raised by
-- Lucky Phil's addons. Errors from anything else are ignored outright, so no
-- other author's data ever reaches the log or the SavedVariables.
--
-- Pure Lua, no WoW APIs, so it can be unit tested. Watcher.lua installs the
-- error handler and owns the prompt and the report window.

LuckyBugs = LuckyBugs or {}

local MAX_LOG              = 25
local MAX_PROMPTS          = 3     -- per session, so a repeating bug can't nag
local MAX_REPORT_CHARS     = 1600  -- Discord caps a message at 2000

-- Table addresses differ on every occurrence of the same bug, so they are
-- collapsed before the message is used as a de-duplication key.
local function dedupeKey(message)
    return (message:gsub("0[xX]%x+", "0x?"))
end

--- True when an error came from one of Lucky Phil's addons.
--- Every addon folder in the suite is prefixed "Luckys_", so the file paths in
--- the message and stack are the signal.
---@param text string  message and stack, concatenated
---@return boolean
function LuckyBugs.IsLuckyError(text)
    return text:lower():find("lucky", 1, true) ~= nil
end

--- The addon folder an error came from.
--- Prefers the first Lucky folder that isn't the shared library, because a
--- Luckys_Utils frame is usually one layer below the addon that actually broke.
---@param text string  message and stack, concatenated
---@return string|nil
function LuckyBugs.AddonFolder(text)
    local library
    for folder in text:gmatch("[Aa]dd[Oo]ns[\\/]([%w_%-']+)") do
        if folder:lower():find("lucky", 1, true) then
            if folder ~= "Luckys_Utils" then return folder end
            library = library or folder
        end
    end
    return library
end

local function truncate(text, limit)
    if #text <= limit then return text end
    return text:sub(1, limit) .. "\n... (truncated)"
end

--- Build the copy-ready text a user pastes into the Discord.
---@param entry table  an entry from Recorder:Capture
---@param context table  { addon, utils, build, locale }
---@return string
function LuckyBugs.FormatReport(entry, context)
    context = context or {}
    local lines = {
        context.addon or "Unknown addon",
        string.format("Lucky's Utils %s | WoW %s | %s",
            context.utils or "?", context.build or "?", context.locale or "?"),
        string.format("%s | seen %dx", entry.when or "?", entry.count or 1),
        "",
        entry.message or "",
        "",
        entry.stack or "",
    }
    return truncate(table.concat(lines, "\n"), MAX_REPORT_CHARS)
end

-- ---------------------------------------------------------------------------
-- Recorder
-- ---------------------------------------------------------------------------

local Recorder = {}
Recorder.__index = Recorder

--- Create an error recorder.
---@param options table  {
---   now: fun():string,               -- timestamp for a new entry
---   isPromptEnabled: fun():boolean,  -- has the user asked to be left alone?
---   onPrompt: fun(entry)|nil,        -- called when an error deserves a prompt
---   maxLog: number|nil, maxPrompts: number|nil }
---@return table recorder
function LuckyBugs:NewRecorder(options)
    return setmetatable({
        entries         = {},
        seen            = {},
        prompts         = 0,
        now             = options.now,
        isPromptEnabled = options.isPromptEnabled,
        onPrompt        = options.onPrompt,
        maxLog          = options.maxLog or MAX_LOG,
        maxPrompts      = options.maxPrompts or MAX_PROMPTS,
    }, Recorder)
end

--- Record one error. Repeats of an error already seen this session bump its
--- count instead of adding a second entry, and never prompt again.
---@param message string
---@param stack string|nil
---@return table|nil entry  nil when the error wasn't ours
---@return boolean prompted
function Recorder:Capture(message, stack)
    local text = message .. "\n" .. (stack or "")
    if not LuckyBugs.IsLuckyError(text) then return nil, false end

    local key   = dedupeKey(message)
    local known = self.seen[key]
    if known then
        known.count = known.count + 1
        return known, false
    end

    local entry = {
        message = message,
        stack   = stack,
        folder  = LuckyBugs.AddonFolder(text),
        when    = self.now(),
        count   = 1,
    }
    self.seen[key] = entry
    table.insert(self.entries, 1, entry)
    while #self.entries > self.maxLog do
        table.remove(self.entries)
    end

    if self.prompts >= self.maxPrompts or not self.isPromptEnabled() then
        return entry, false
    end

    self.prompts = self.prompts + 1
    if self.onPrompt then self.onPrompt(entry) end
    return entry, true
end

--- Append errors kept from an earlier session, which are older than anything
--- captured so far. They are shown in the report window but never prompt.
---@param saved table|nil
function Recorder:Seed(saved)
    for _, entry in ipairs(saved or {}) do
        if #self.entries >= self.maxLog then return end
        entry.previousSession = true
        self.entries[#self.entries + 1] = entry
    end
end

--- Captured errors, newest first.
---@return table
function Recorder:Entries()
    return self.entries
end

--- The newest `count` entries, for writing back to SavedVariables.
---@param count number
---@return table
function Recorder:Recent(count)
    local out = {}
    for i = 1, math.min(count, #self.entries) do
        out[i] = self.entries[i]
    end
    return out
end
