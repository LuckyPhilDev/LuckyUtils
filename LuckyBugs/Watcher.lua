-- LuckyBugs/Watcher.lua: watches for Lua errors in Lucky Phil's addons, offers
-- to report them on the Discord, and shows a copy-ready report window.
--
-- The error handler is installed as this file loads, before the rest of the
-- library, so errors raised while other addons are still loading are caught.

if LuckysUtilsSkipLoad then return end

-- Folder this copy loads from: the host addon when embedded, Luckys_Utils when
-- standalone. Nil under a plain-Lua test harness, hence the fallback.
local ADDON_NAME = ... or "Luckys_Utils"

local S = LuckyUtilsStrings.bugs

local DISCORD_URL = "https://discord.gg/ptTtYyAjdZ"

local PANEL_W, PANEL_H = 540, 420
local SAVED_LOG_SIZE   = 10

local recorder
-- The queued prompt entry lives on the global (LuckyBugs._pending) so a prompt
-- queued through an older embedded copy still fires after a newer copy's
-- handlers take over.
local window
local windowIndex = 1

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

-- SavedVariables are not loaded while the first errors can already be arriving,
-- so reads tolerate an absent DB and writes only happen after ADDON_LOADED.
local function settings()
    return LuckySettingsDB and LuckySettingsDB.bugs
end

local function promptEnabled()
    local db = settings()
    return not db or db.prompt ~= false
end

local function addonTitle(entry)
    if not entry or not entry.folder then return S.unknownAddon end
    local title = C_AddOns.GetAddOnMetadata(entry.folder, "Title") or entry.folder
    return (title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function reportText(entry)
    local version, build = GetBuildInfo()
    local folderVersion = entry.folder and C_AddOns.GetAddOnMetadata(entry.folder, "Version")
    return LuckyBugs.FormatReport(entry, {
        addon  = addonTitle(entry) .. " " .. (folderVersion or "?"),
        utils  = C_AddOns.GetAddOnMetadata("Luckys_Utils", "Version")
            or ("1.0 r" .. LibStub.minors["LuckysUtils-1.0"]),
        build  = version .. " (" .. build .. ")",
        locale = GetLocale(),
    })
end

-- ---------------------------------------------------------------------------
-- Report window
-- ---------------------------------------------------------------------------

-- The shared buttons are backdrop-drawn, so disabling one needs a visible cue.
local function setNavEnabled(button, enabled)
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or 0.35)
end

local function refreshWindow()
    local entries = recorder:Entries()
    local entry = entries[windowIndex]
    if not entry then return end

    window.counter:SetText(S.counter:format(
        windowIndex, #entries, entry.previousSession and S.earlierSession or ""))
    setNavEnabled(window.prev, windowIndex < #entries)
    setNavEnabled(window.next, windowIndex > 1)

    window.edit:SetText(reportText(entry))
    window.edit:SetCursorPosition(0)
    window.edit:HighlightText()
    window.edit:SetFocus()
end

local function buildWindow()
    local c = LuckyUI.C

    local frame = LuckyUI.CreatePanel("LuckyBugsReport", UIParent, PANEL_W, PANEL_H)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER")
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())  -- closable with Escape

    LuckyUI.CreateHeader(frame, S.windowTitle)

    local hint = frame:CreateFontString(nil, "OVERLAY")
    hint:SetFont(LuckyUI.BODY_FONT, 12)
    hint:SetTextColor(c.textMuted[1], c.textMuted[2], c.textMuted[3])
    hint:SetPoint("TOPLEFT", 14, -42)
    hint:SetPoint("TOPRIGHT", -14, -42)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(3)
    hint:SetText(S.windowHint)

    -- Discord link, in its own box so it can be selected and copied separately.
    local linkLabel = frame:CreateFontString(nil, "OVERLAY")
    linkLabel:SetFont(LuckyUI.BODY_FONT, 12)
    linkLabel:SetTextColor(c.goldAccent[1], c.goldAccent[2], c.goldAccent[3])
    linkLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    linkLabel:SetText(S.discordLabel)

    local linkBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    linkBg:SetBackdrop(LuckyUI.Backdrop)
    linkBg:SetBackdropColor(c.bgInput[1], c.bgInput[2], c.bgInput[3], c.bgInput[4])
    linkBg:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
    linkBg:SetHeight(22)
    linkBg:SetPoint("TOPLEFT", linkLabel, "TOPRIGHT", 10, 4)
    linkBg:SetPoint("RIGHT", frame, "RIGHT", -14, 0)

    local link = CreateFrame("EditBox", nil, linkBg)
    link:SetPoint("TOPLEFT", 6, -3)
    link:SetPoint("BOTTOMRIGHT", -6, 3)
    link:SetAutoFocus(false)
    link:SetFont(LuckyUI.BODY_FONT, 12, "")
    link:SetTextColor(c.textLight[1], c.textLight[2], c.textLight[3])
    link:SetText(DISCORD_URL)
    link:SetScript("OnEscapePressed", function() frame:Hide() end)
    link:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- The link never changes, so typing in it can only lose it.
    link:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(DISCORD_URL) end
    end)
    link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local scrollBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    scrollBg:SetBackdrop(LuckyUI.Backdrop)
    scrollBg:SetBackdropColor(c.bgInput[1], c.bgInput[2], c.bgInput[3], c.bgInput[4])
    scrollBg:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
    scrollBg:SetPoint("TOPLEFT", linkLabel, "BOTTOMLEFT", 0, -12)
    scrollBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 52)

    local scroll = CreateFrame("ScrollFrame", nil, scrollBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(LuckyUI.BODY_FONT, 12, "")
    edit:SetTextColor(c.textLight[1], c.textLight[2], c.textLight[3])
    edit:SetWidth(PANEL_W - 60)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    scroll:SetScrollChild(edit)
    frame.edit = edit

    local counter = frame:CreateFontString(nil, "OVERLAY")
    counter:SetFont(LuckyUI.BODY_FONT, 12)
    counter:SetTextColor(c.textMuted[1], c.textMuted[2], c.textMuted[3])
    counter:SetPoint("BOTTOMLEFT", 14, 20)
    frame.counter = counter

    local close = LuckyUI.CreateButton(frame, S.close, 80, 26, "secondary")
    close:SetPoint("BOTTOMRIGHT", -14, 12)
    close:SetScript("OnClick", function() frame:Hide() end)

    local selectAll = LuckyUI.CreateButton(frame, S.selectAll, 100, 26, "primary")
    selectAll:SetPoint("RIGHT", close, "LEFT", -8, 0)
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    local nextBtn = LuckyUI.CreateButton(frame, S.newer, 70, 26, "secondary")
    nextBtn:SetPoint("RIGHT", selectAll, "LEFT", -16, 0)
    nextBtn:SetScript("OnClick", function()
        windowIndex = windowIndex - 1
        refreshWindow()
    end)
    frame.next = nextBtn

    local prevBtn = LuckyUI.CreateButton(frame, S.older, 70, 26, "secondary")
    prevBtn:SetPoint("RIGHT", nextBtn, "LEFT", -6, 0)
    prevBtn:SetScript("OnClick", function()
        windowIndex = windowIndex + 1
        refreshWindow()
    end)
    frame.prev = prevBtn

    return frame
end

--- Open the report window on a captured error (the newest one by default).
---@param index number|nil
function LuckyBugs:Show(index)
    local entries = recorder:Entries()
    if #entries == 0 then
        print(LuckyUI.WC.goldAccent .. S.prefix .. LuckyUI.WC.reset .. S.noneCaptured)
        return
    end

    window = window or buildWindow()
    windowIndex = math.min(math.max(index or 1, 1), #entries)
    window:Show()
    refreshWindow()
end

-- ---------------------------------------------------------------------------
-- Prompt
-- ---------------------------------------------------------------------------

StaticPopupDialogs["LUCKY_BUGS_REPORT"] = {
    text           = S.promptText,
    button1        = S.promptShow,
    button2        = S.promptNotNow,
    button3        = S.promptStop,
    OnAccept       = function() LuckyBugs:Show() end,
    OnAlt          = function()
        local db = settings()
        if db then db.prompt = false end
        print(LuckyUI.WC.goldAccent .. S.prefix .. LuckyUI.WC.reset .. S.promptsOff)
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

local function showPrompt()
    local entry = LuckyBugs._pending
    if not entry then return end
    if InCombatLockdown() then return end  -- retried on PLAYER_REGEN_ENABLED
    LuckyBugs._pending = nil
    StaticPopup_Show("LUCKY_BUGS_REPORT", addonTitle(entry))
end

local function queuePrompt(entry)
    LuckyBugs._pending = entry
    C_Timer.After(0, showPrompt)  -- out of the error handler before touching the UI
end

-- ---------------------------------------------------------------------------
-- Error capture
-- ---------------------------------------------------------------------------

-- The recorder survives upgrades so errors captured while addons were still
-- loading are not lost when a newer embedded copy takes over. Its closures
-- only touch globals, so an old instance stays valid under new handlers.
LuckyBugs._recorder = LuckyBugs._recorder or LuckyBugs:NewRecorder({
    now             = function() return date("%d/%m/%y %H:%M:%S") end,
    isPromptEnabled = promptEnabled,
    onPrompt        = queuePrompt,
})
recorder = LuckyBugs._recorder

-- The pre-Lucky handler this copy chains to. An upgrade replaces our own
-- installed handler outright instead of chaining to it, so one error is
-- captured once however many copies loaded.
LuckyBugs._previousHandler = LuckyBugs._previousHandler or geterrorhandler()

local handling = false

local function onError(err, ...)
    -- An error thrown while recording would land straight back here.
    if not handling then
        handling = true
        pcall(recorder.Capture, recorder, tostring(err), debugstack(2))
        handling = false
    end
    return LuckyBugs._previousHandler(err, ...)
end

if geterrorhandler() ~= LuckyBugs._installedHandler then
    -- Someone else claimed the handler since our last copy installed; chain them.
    LuckyBugs._previousHandler = geterrorhandler()
end
seterrorhandler(onError)
LuckyBugs._installedHandler = onError

-- BugGrabber (BugSack) claims the error handler for itself and does not chain,
-- so where it is installed we take its errors from its own callback instead.
local bugGrabberListener = {}
local function adoptBugGrabber()
    if geterrorhandler() == onError then return end
    if not BugGrabber or not BugGrabber.RegisterCallback then return end
    pcall(BugGrabber.RegisterCallback, bugGrabberListener, "BugGrabber_BugGrabbed", function(_, err)
        recorder:Capture(tostring(err.message or ""), err.stack)
    end)
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

LuckyBugs._frame = LuckyBugs._frame or CreateFrame("Frame")
local frame = LuckyBugs._frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon ~= ADDON_NAME then return end
        LuckySettingsDB = LuckySettingsDB or {}
        LuckySettingsDB.bugs = LuckySettingsDB.bugs or { prompt = true, log = {} }
        -- Seed appends, and with embedded copies each host's ADDON_LOADED
        -- lands here, so only the first may seed the shared recorder.
        if not LuckyBugs._seeded then
            LuckyBugs._seeded = true
            recorder:Seed(LuckySettingsDB.bugs.log)
        end
    elseif event == "PLAYER_LOGIN" then
        adoptBugGrabber()
    elseif event == "PLAYER_REGEN_ENABLED" then
        showPrompt()
    elseif event == "PLAYER_LOGOUT" then
        local db = settings()
        if db then db.log = recorder:Recent(SAVED_LOG_SIZE) end
    end
end)

-- ---------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------

SLASH_LUCKYBUGS1 = "/luckybugs"
SlashCmdList["LUCKYBUGS"] = function(msg)
    local prefix = LuckyUI.WC.goldAccent .. S.prefix .. LuckyUI.WC.reset
    local arg = msg:lower():match("^%s*(%a*)")
    local db = settings()

    if arg == "on" or arg == "off" then
        if db then db.prompt = (arg == "on") end
        print(prefix .. S.promptsToggled:format(arg == "on" and S.on or S.off))
        return
    end

    if arg == "" then
        LuckyBugs:Show()
        return
    end

    print(prefix .. S.usage)
end
