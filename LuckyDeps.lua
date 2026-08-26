-- LuckyDeps: Generic addon dependency checker for Lucky Phil's addons.
-- Checks whether optional dependencies are installed, loaded, and meet version requirements.

if LuckysUtilsSkipLoad then return end

LuckyDeps = LuckyDeps or {}

local function parseVersion(str)
    local parts = {}
    for n in str:gmatch("%d+") do
        parts[#parts + 1] = tonumber(n)
    end
    return parts
end

local function isAtLeast(actual, minimum)
    local a = parseVersion(actual)
    local m = parseVersion(minimum)
    for i = 1, math.max(#a, #m) do
        local av = a[i] or 0
        local mv = m[i] or 0
        if av ~= mv then return av > mv end
    end
    return true
end

--- Returns true if an addon is installed and enabled, regardless of whether it has loaded yet.
---@param addonName string
---@return boolean
function LuckyDeps:IsEnabled(addonName)
    local _, _, _, loadable = C_AddOns.GetAddOnInfo(addonName)
    return loadable == true
end

LuckyDeps.Status = {
    OK       = "ok",
    MISSING  = "missing",   -- not installed, or installed but unusable
    DISABLED = "disabled",  -- installed and switched off, so the player can fix it
    OUTDATED = "outdated",
}

--- Checks whether an addon is loaded and meets an optional minimum version.
---@param addonName string
---@param minVersion string|nil
---@return boolean ok
---@return string|nil message
---@return string status one of LuckyDeps.Status
function LuckyDeps:Check(addonName, minVersion)
    local S = LuckyUtilsStrings.deps
    local versionSuffix = minVersion and S.versionSuffix:format(minVersion) or ""
    local failMessage = S.required:format(addonName .. versionSuffix)

    if C_AddOns.IsAddOnLoaded(addonName) then
        if minVersion then
            local actual = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
            if not isAtLeast(actual, minVersion) then
                return false, failMessage, self.Status.OUTDATED
            end
        end
        return true, nil, self.Status.OK
    end

    -- Switched off is worth saying out loud, because it is the one failure the
    -- player can undo from here.
    local _, _, _, _, reason = C_AddOns.GetAddOnInfo(addonName)
    if reason == "DISABLED" or reason == "DEP_DISABLED" then
        return false, S.disabled:format(addonName),
            self.Status.DISABLED
    end

    return false, failMessage, self.Status.MISSING
end

--- Switches an addon on for this character, along with anything it declares a
--- dependency on. Takes effect on the next UI reload.
--- Only direct dependencies are followed, which covers every addon this suite
--- checks for; a dependency that is itself off and has its own would need more.
---@param addonName string
function LuckyDeps:Enable(addonName)
    C_AddOns.EnableAddOn(addonName)
    for _, dependency in ipairs({ C_AddOns.GetAddOnDependencies(addonName) }) do
        C_AddOns.EnableAddOn(dependency)
    end
end

--- True when the standalone Luckys_Utils addon is installed but everything
--- would keep working without it: an embedded copy of this library is present,
--- and no installed addon still lists Luckys_Utils as a required dependency
--- (WoW disables an addon whose required dependency is missing). Gates the
--- future "you can uninstall the standalone" nudge; nothing calls it yet.
---@return boolean
function LuckyDeps:StandaloneRemovable()
    if not C_AddOns.DoesAddOnExist("Luckys_Utils") then return false end

    local embedded = false
    for _, host in ipairs(LuckysUtilsHosts or {}) do
        if host ~= "Luckys_Utils" then
            embedded = true
            break
        end
    end
    if not embedded then return false end

    for index = 1, C_AddOns.GetNumAddOns() do
        for _, dependency in ipairs({ C_AddOns.GetAddOnDependencies(index) }) do
            if dependency == "Luckys_Utils" then return false end
        end
    end
    return true
end

-- The "you can uninstall the standalone" notice ------------------------------
-- Shown once, in a panel rather than chat, because the copy it warns about can
-- be the reason a settings panel will not open in the first place.

local NOTICE_W, NOTICE_H = 380, 210

local function buildNotice()
    local S = LuckyUtilsStrings.deps
    local c = LuckyUI.C

    local frame = LuckyUI.CreatePanel("LuckyUtilsStandaloneNotice", UIParent, NOTICE_W, NOTICE_H)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER")
    tinsert(UISpecialFrames, frame:GetName())

    LuckyUI.CreateHeader(frame, S.standaloneTitle)

    local body = frame:CreateFontString(nil, "OVERLAY")
    body:SetFont(LuckyUI.BODY_FONT, 12)
    body:SetTextColor(c.textLight[1], c.textLight[2], c.textLight[3])
    body:SetPoint("TOPLEFT", 14, -44)
    body:SetPoint("TOPRIGHT", -14, -44)
    body:SetJustifyH("LEFT")
    body:SetSpacing(3)
    body:SetText(S.standaloneNotice)

    local dismiss = LuckyUI.CreateButton(frame, S.standaloneDismiss, 90, 24, "primary")
    dismiss:SetPoint("BOTTOM", 0, 14)
    dismiss:SetScript("OnClick", function() frame:Hide() end)

    return frame
end

-- Held directly rather than read off the global, because a pre-gate copy can
-- replace the table and both this and the gate's repair answer PLAYER_LOGIN,
-- in an order nothing promises. The frame hangs off the module so a newer copy
-- taking over inherits the one already on screen instead of building a second.
local standaloneRemovable = LuckyDeps.StandaloneRemovable

local function showStandaloneNotice()
    if not standaloneRemovable(LuckyDeps) then return end

    LuckySettingsDB = LuckySettingsDB or {}
    if LuckySettingsDB.standaloneNoticeSeen then return end
    LuckySettingsDB.standaloneNoticeSeen = true

    LuckyDeps.noticeFrame = LuckyDeps.noticeFrame or buildNotice()
    LuckyDeps.noticeFrame:Show()
end

LuckyDeps.ShowStandaloneNotice = showStandaloneNotice

local noticeWatcher = LuckyDeps.noticeWatcher or CreateFrame("Frame")
LuckyDeps.noticeWatcher = noticeWatcher
noticeWatcher:UnregisterAllEvents()
noticeWatcher:RegisterEvent("PLAYER_LOGIN")
noticeWatcher:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    showStandaloneNotice()
end)
