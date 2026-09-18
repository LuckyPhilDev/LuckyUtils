-- LuckyBankRun: runs every Lucky addon's bank jobs one at a time, so two addons
-- never fight over the cursor, and lists the items still to move in a window
-- beside the bank.
--
-- A job is a table of two functions and the way its items go:
--
--   plan()           returns its moves, { { itemID = n }, ... } in run order
--   run(job, moves)  makes them, calling job:Tick() as each finishes and
--                    job:Done() once, at the end, even when there was nothing
--   direction        "deposit" or "withdraw", drawn as an arrow on each row
--
--   LuckyBankRun:OnBankOpen(20, { direction = "deposit", plan = PlanDeposits, run = RunDeposits })
--
-- Every bank-open job is planned before any of them runs, so the window lists
-- the whole run from the start and its count never grows. In Manual mode that
-- list opens with a Start button, and nothing runs until it is pressed. Each
-- job's run re-checks the bags and bank as it goes, since the jobs before it
-- move things. Queue runs a one-off job after whatever is already running.
-- Closing the bank drops everything still waiting; a late Tick or Done from a
-- job that was dropped is ignored.

if LuckysUtilsSkipLoad then return end

LuckyBankRun = LuckyBankRun or {}

local Run = LuckyBankRun
local S = LuckyUtilsStrings.bankRun

-- Bank tab IDs are not ready on BANKFRAME_OPENED itself.
local OPEN_DELAY = 0.2
-- Lets the last placement of one job settle before the next job scans the bags.
local JOB_GAP = 0.25
local MAX_ROWS = 10
local ROW_H = 22
local HEADER_H = 36
local START_H = 20
local DONE_LINGER = 3

local DIRECTIONS = {
    deposit  = { icon = "arrow-down-to-line", title = S.deposit,    desc = S.depositDesc },
    withdraw = { icon = "arrow-up-from-line", title = S.withdrawal, desc = S.withdrawalDesc },
}

-- Both bank windows hang their tab buttons off their right edge, so the window
-- clears that strip.
local BLIZZARD_TAB_STRIP = 50
local BAGANATOR_TAB_STRIP = 35

-- State lives on the global so a newer library copy inherits it.
Run.bankJobs = Run.bankJobs or {}
Run.pending = Run.pending or {}
-- queue holds the rows still to move; moved and total count single moves
-- across the whole run, for the title count and the bar along the foot.
Run.progress = Run.progress or { queue = {}, moved = 0, total = 0 }

local function IsManual()
    return LuckySettingsDB and LuckySettingsDB.bankQueueMode == "manual"
end

-- Manual mode needs the window for its Start button, so it always shows there.
local function IsHidden()
    return not IsManual() and LuckySettingsDB and LuckySettingsDB.hideBankQueue == true
end

local function ResetProgress()
    Run.progress = { queue = {}, moved = 0, total = 0 }
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

local function Frame()
    if Run.frame then return Run.frame end
    local f = LuckyUI.CreatePanel("LuckyBankRunFrame", UIParent, 300, 64)
    LuckyUI.CreateHeader(f, S.title)
    f:SetFrameStrata("MEDIUM")
    f:SetScript("OnDragStart", nil)
    LuckyUI.EnableAutoHide(f, DONE_LINGER)
    local gold = LuckyUI.C.goldAccent
    f.progressBar = f:CreateTexture(nil, "OVERLAY")
    f.progressBar:SetPoint("BOTTOMLEFT", 1, 1)
    f.progressBar:SetHeight(3)
    f.progressBar:SetColorTexture(gold[1], gold[2], gold[3], 0.8)
    f.startButton = LuckySettings.Rich.IconTextButton(f, S.start, "play")
    f.startButton:SetPoint("TOPLEFT", 10, -(HEADER_H + 4))
    f.startButton:SetScript("OnClick", function() Run:StartBankJobs() end)
    f.startButton:Hide()
    f.rows = {}
    Run.frame = f
    return f
end

-- The rows sit under the Start button while it shows.
local function RowsTop(f)
    return HEADER_H + (f.startButton:IsShown() and (START_H + 8) or 0)
end

-- The rows move up under a still mouse as items finish, so a row redrawn
-- while its tooltip is up puts its new item in it.
local function ShowItemTip(row)
    if not row.itemID then
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(row.itemID)
    GameTooltip:Show()
end

local function ShowDirectionTip(hit)
    local d = DIRECTIONS[hit:GetParent().directionKey]
    if not d then return end
    GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")
    GameTooltip:SetText(d.title, 1, 1, 1)
    GameTooltip:AddLine(d.desc, nil, nil, nil, true)
    GameTooltip:Show()
end

-- direction is nil on rows that are not items, which keep the arrow's space
-- so their text still lines up with the item names.
local function SetRow(f, i, itemID, text, direction)
    local row = f.rows[i]
    if not row then
        row = CreateFrame("Frame", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("RIGHT", -10, 0)
        row:EnableMouse(true)
        row:SetScript("OnEnter", ShowItemTip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        local gold = LuckyUI.C.goldAccent
        row.direction = row:CreateTexture(nil, "ARTWORK")
        row.direction:SetSize(14, 14)
        row.direction:SetPoint("LEFT")
        row.direction:SetVertexColor(gold[1], gold[2], gold[3])
        -- A texture takes no mouse, so the arrow's tooltip sits on a frame over it.
        local hit = CreateFrame("Frame", nil, row)
        hit:SetAllPoints(row.direction)
        hit:EnableMouse(true)
        hit:SetScript("OnEnter", ShowDirectionTip)
        hit:SetScript("OnLeave", GameTooltip_Hide)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", row.direction, "RIGHT", 6, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFont(LuckyUI.BODY_FONT, 12, "")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT")
        row.name:SetJustifyH("LEFT")
        f.rows[i] = row
    end
    row:SetPoint("TOPLEFT", 10, -RowsTop(f) - (i - 1) * ROW_H)
    row.itemID, row.directionKey = itemID, direction
    row.direction:SetTexture(DIRECTIONS[direction] and LuckyIcon(DIRECTIONS[direction].icon))
    row.icon:SetTexture(itemID and (C_Item.GetItemIconByID(itemID) or 134400))
    row.name:SetText(text)
    row:Show()
    if GameTooltip:IsOwned(row) then ShowItemTip(row) end
end

-- Baganator hides BankFrame under a hidden parent, which IsShown misses, and
-- names its own bank window after the view type and skin.
local function ShownBankWindow()
    if BankFrame and BankFrame:IsVisible() then return BankFrame, BLIZZARD_TAB_STRIP end
    local skin = Baganator and Baganator.API.Skins and Baganator.API.Skins.GetCurrentSkin()
    if not skin then return nil end
    for _, view in ipairs({ "Single", "Category" }) do
        local frame = _G["Baganator_" .. view .. "ViewBankViewFrame" .. skin]
        if frame and frame:IsVisible() then return frame, BAGANATOR_TAB_STRIP end
    end
end

-- Any other bag addon falls back to the top of the screen.
local function AnchorToBank(f)
    f:ClearAllPoints()
    local bank, tabStrip = ShownBankWindow()
    if bank then
        f:SetPoint("TOPLEFT", bank, "TOPRIGHT", tabStrip, 0)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end
end

local function ShowRows(f, count)
    for i, row in ipairs(f.rows) do row:SetShown(i <= count) end
    f:SetHeight(RowsTop(f) + count * ROW_H + 10)
    AnchorToBank(f)
    f:Show()
end

-- Draws the queue. In Manual mode, before Start, the same list sits under the
-- Start button as a preview of what the run will move.
local function Render()
    if IsHidden() then
        if Run.frame then Run.frame:Hide() end
        return
    end
    local f, p = Frame(), Run.progress
    f:StopAutoHide()
    f.startButton:SetShown(Run.previewing == true)
    local shown = math.min(#p.queue, MAX_ROWS)
    for i = 1, shown do
        local entry = p.queue[i]
        local name = select(2, C_Item.GetItemInfo(entry.itemID)) or S.itemFallback:format(entry.itemID)
        SetRow(f, i, entry.itemID, name, entry.direction)
    end
    if #p.queue > MAX_ROWS then
        shown = shown + 1
        SetRow(f, shown, nil, S.more:format(#p.queue - MAX_ROWS))
    elseif shown == 0 and Run.previewing then
        shown = 1
        SetRow(f, 1, nil, S.nothing)
    end
    ShowRows(f, shown)
    f.titleText:SetText(S.titleCount:format(p.moved, p.total))
    f.progressBar:SetWidth(math.max(1, (f:GetWidth() - 2) * p.moved / math.max(1, p.total)))
    f.progressBar:SetShown(p.total > 0)
end

local function ShowDone()
    local f = Run.frame
    if IsHidden() or not (f and f:IsShown()) then return end
    f.startButton:Hide()
    SetRow(f, 1, nil, S.done)
    ShowRows(f, 1)
    f.titleText:SetText(S.title)
    f.progressBar:Hide()
    f:StartAutoHide()
end

-- ---------------------------------------------------------------------------
-- Jobs
-- ---------------------------------------------------------------------------

local Job = {}
Job.__index = Job

local function IsLive(job)
    return Run.current == job and not job.finished
end

-- A plan that errors is reported and treated as having nothing to move.
local function PlanOf(spec)
    local ok, moves = xpcall(spec.plan, geterrorhandler())
    return ok and moves or {}
end

-- Consecutive moves of the same item from the same job share a row. A preview
-- has no job yet, so the direction comes with the moves.
local function AddRows(moves, direction, job)
    local p = Run.progress
    p.total = p.total + #moves
    for _, move in ipairs(moves) do
        local last = p.queue[#p.queue]
        if last and last.job == job and last.direction == direction and last.itemID == move.itemID then
            last.moves = last.moves + 1
        else
            p.queue[#p.queue + 1] = { job = job, direction = direction, itemID = move.itemID, moves = 1 }
        end
    end
end

-- One planned move finished or was skipped.
function Job:Tick()
    if not IsLive(self) then return end
    local p = Run.progress
    local front = p.queue[1]
    if not front or front.job ~= self then return end
    p.moved = p.moved + 1
    front.moves = front.moves - 1
    if front.moves == 0 then table.remove(p.queue, 1) end
    Render()
end

local StartNext

-- Moves the job planned but never ticked count as passed, so the next job's
-- ticks start on its own rows and the bar still reaches the end. A job that
-- moved nothing has nothing to settle, so the next one starts straight away.
function Job:Done()
    if not IsLive(self) then return end
    self.finished = true
    if not self.planned then
        Run.current = nil
        StartNext()
        return
    end
    local p = Run.progress
    while p.queue[1] and p.queue[1].job == self do
        p.moved = p.moved + table.remove(p.queue, 1).moves
    end
    C_Timer.After(JOB_GAP, function()
        if Run.current ~= self then return end
        Run.current = nil
        StartNext()
    end)
end

local function ShowPreview()
    ResetProgress()
    for _, entry in ipairs(Run.bankJobs) do AddRows(PlanOf(entry.spec), entry.spec.direction) end
    Run.previewing = true
    Render()
end

-- A run someone started by hand says it finished even when it moved nothing.
-- In Manual mode a one-off job, such as a slash command, can finish before
-- Start is pressed; the window then goes back to the preview.
local function Finish()
    local movedAny = Run.progress.total > 0
    ResetProgress()
    if IsManual() and Run.bankOpen and not Run.started then
        ShowPreview()
    elseif movedAny or Run.started then
        ShowDone()
    end
end

StartNext = function()
    if Run.current then return end
    local entry = table.remove(Run.pending, 1)
    if not entry then
        Finish()
        return
    end
    Run.current = entry.job
    -- A job that errors is reported and treated as done, so the run carries on.
    if not xpcall(entry.spec.run, geterrorhandler(), entry.job, entry.moves) then entry.job:Done() end
end

-- Plans a job now and puts it at the back of the line without starting it.
local function Enqueue(spec)
    if Run.previewing then
        Run.previewing = false
        ResetProgress()
    end
    local job = setmetatable({}, Job)
    local moves = PlanOf(spec)
    job.planned = #moves > 0
    AddRows(moves, spec.direction, job)
    table.insert(Run.pending, { spec = spec, job = job, moves = moves })
end

-- showEmpty draws the window even when nothing is planned, so a run started
-- by hand replaces the preview rather than leaving it up.
local function BeginBankRun(showEmpty)
    for _, entry in ipairs(Run.bankJobs) do Enqueue(entry.spec) end
    if Run.progress.total > 0 or showEmpty then Render() end
    StartNext()
end

--- Run a job after whatever is already running.
function Run:Queue(spec)
    Enqueue(spec)
    if Run.progress.total > 0 then Render() end
    StartNext()
end

--- Run a job every time the bank opens, or on Start in Manual mode. Lower
--- order runs first; deposits go before withdrawals so the bags have room.
function Run:OnBankOpen(order, spec)
    table.insert(self.bankJobs, { order = order, spec = spec })
    table.sort(self.bankJobs, function(a, b) return a.order < b.order end)
end

--- Plan and run every bank-open job now. The Start button calls this.
function Run:StartBankJobs()
    self.started = true
    BeginBankRun(true)
end

--- The Auto or Manual choice, for any Lucky addon's rich settings group. Every
--- addon's copy reads and writes the same account-wide value. ownedBy names
--- another installed addon that holds the setting instead; the row then locks
--- and says where to change it.
function Run:AddModeSetting(group, opts)
    opts = opts or {}
    group:Select({
        label    = S.mode,
        desc     = S.modeDesc,
        note     = opts.ownedBy and S.modeOwned:format(opts.ownedBy),
        since    = opts.since,
        disabled = opts.ownedBy ~= nil,
        options  = { { key = "auto", label = S.modeAuto }, { key = "manual", label = S.modeManual } },
        value    = function() return IsManual() and "manual" or "auto" end,
        onSelect = function(key)
            LuckySettingsDB = LuckySettingsDB or {}
            LuckySettingsDB.bankQueueMode = key == "manual" and "manual" or nil
        end,
    })
end

--- The Hide Bank Queue toggle, for any Lucky addon's rich settings group. Every
--- addon's toggle reads and writes the same account-wide flag.
function Run:AddSettingsToggle(group, since)
    group:Toggle({
        label    = S.hide,
        desc     = S.hideTooltip,
        since    = since,
        checked  = IsHidden,
        onToggle = function(checked)
            LuckySettingsDB = LuckySettingsDB or {}
            LuckySettingsDB.hideBankQueue = checked or nil
            if checked and Run.frame then Run.frame:Hide() end
        end,
    })
end

local function OnBankClosed()
    Run.bankOpen = false
    Run.started = nil
    Run.previewing = false
    Run.current = nil
    Run.pending = {}
    ResetProgress()
    if Run.frame then Run.frame:Hide() end
end

-- Kept across a takeover so a newer copy re-points the one listener rather
-- than adding a second.
Run.events = Run.events or CreateFrame("Frame")
Run.events:RegisterEvent("BANKFRAME_OPENED")
Run.events:RegisterEvent("BANKFRAME_CLOSED")
Run.events:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_CLOSED" then
        OnBankClosed()
        return
    end
    Run.bankOpen = true
    C_Timer.After(OPEN_DELAY, function()
        if not Run.bankOpen or #Run.bankJobs == 0 then return end
        if IsManual() then
            ShowPreview()
        else
            BeginBankRun()
        end
    end)
end)
