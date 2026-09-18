-- luacheck: ignore 111 113 121 122

LuckyBankRun = nil
LuckysUtilsSkipLoad = nil
LuckyUtilsStrings = { bankRun = {
    title = "Bank Queue", titleCount = "%d / %d", more = "+%d", done = "All done",
    nothing = "Nothing to move", itemFallback = "Item %d",
} }
LuckyUI = { BODY_FONT = "font", C = { goldAccent = { 1, 1, 1 } } }
function LuckyIcon(name) return name end
C_Item = { GetItemIconByID = function() end, GetItemInfo = function() end }
GameTooltip = { IsOwned = function() return false end }
LuckySettingsDB = {}

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flushTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end

local reported = {}
function geterrorhandler() return function(err) reported[#reported + 1] = err end end

-- Any widget method answers with another widget, so the window builds without
-- a client; the tests read the few fields they care about directly.
local function widget()
    return setmetatable({}, { __index = function(_, key)
        if key == "GetWidth" then return function() return 300 end end
        if key == "IsShown" then return function(self) return self.shown ~= false end end
        if key == "Show" then return function(self) self.shown = true end end
        if key == "Hide" then return function(self) self.shown = false end end
        if key == "SetShown" then return function(self, shown) self.shown = shown end end
        return function() return widget() end
    end })
end

local events = {}
function CreateFrame()
    local frame = widget()
    frame.SetScript = function(_, name, fn) if name == "OnEvent" then events.handler = fn end end
    return frame
end

dofile("LuckyBankRun.lua")

local window = widget()
window.rows, window.startButton, window.titleText, window.progressBar = {}, widget(), widget(), widget()
window.startButton.shown = false
LuckyBankRun.frame = window

local function fire(event)
    events.handler(nil, event)
    flushTimers()
end

local passed = 0
local function check(cond, label)
    if not cond then error(label, 2) end
    passed = passed + 1
end

local function moves(...)
    local list = {}
    for i, id in ipairs({ ... }) do list[i] = { itemID = id } end
    return list
end

local function progress() return LuckyBankRun.progress end

-- A job that records when it plans and runs, and holds on to its handle so the
-- test can tick it and finish it.
local log, held = {}, {}
local function spec(name, planned, direction)
    return {
        direction = direction,
        plan = function() log[#log + 1] = "plan " .. name; return planned end,
        run = function(job) log[#log + 1] = "run " .. name; held[name] = job end,
    }
end

-- Every bank-open job is planned before the first one runs.
LuckyBankRun:OnBankOpen(50, spec("restock", moves(3), "withdraw"))
LuckyBankRun:OnBankOpen(10, spec("deposit", moves(1, 1, 2), "deposit"))
fire("BANKFRAME_OPENED")
check(log[1] == "plan deposit" and log[2] == "plan restock" and log[3] == "run deposit",
    "every job plans, lowest order first, before any job runs")
check(#log == 3, "only the first job runs")
check(progress().total == 4, "the whole run is counted up front")
check(#progress().queue == 3, "consecutive moves of one item share a row")

held.deposit:Tick()
check(progress().queue[1].moves == 1, "tick takes one move off the front row")
held.deposit:Done()
check(log[4] == nil, "next job waits for the gap after a job that moved items")
flushTimers()
check(log[4] == "run restock", "next job starts after the gap")
check(progress().moved == 3, "unticked moves count as passed when a job finishes")
check(progress().queue[1].itemID == 3, "a finished job's rows are dropped")

-- A late call from a finished job is ignored.
held.deposit:Tick()
check(progress().moved == 3, "a finished job cannot tick")

held.restock:Done()
flushTimers()
check(LuckyBankRun.current == nil and progress().total == 0, "the run resets once every job is done")
fire("BANKFRAME_CLOSED")

-- A job whose plan or run errors is reported and the run carries on.
log = {}
LuckyBankRun:Queue({ plan = function() error("plan boom") end, run = function(job) job:Done() end })
LuckyBankRun:Queue({ plan = function() return {} end, run = function() error("run boom") end })
LuckyBankRun:Queue({ plan = function() return {} end, run = function(job) log[#log + 1] = "after"; job:Done() end })
check(#reported == 2, "both errors reach the error handler")
check(log[1] == "after", "the job after an erroring one still runs")

-- Closing the bank drops everything still waiting, and the dropped job's late
-- calls do nothing.
log = {}
LuckyBankRun:Queue({ plan = function() return moves(5) end, run = function(job) held.dropped = job end })
LuckyBankRun:Queue(spec("never", {}))
events.handler(nil, "BANKFRAME_CLOSED")
held.dropped:Done()
flushTimers()
check(#log == 1 and log[1] == "plan never", "jobs queued before the bank closed never run")
check(LuckyBankRun.current == nil and progress().total == 0, "closing resets the run")

-- Jobs are not started when the bank closes inside the open delay.
log = {}
events.handler(nil, "BANKFRAME_OPENED")
events.handler(nil, "BANKFRAME_CLOSED")
flushTimers()
check(#log == 0, "a bank closed before the delay plans and runs nothing")

-- Manual mode lists the whole plan under a Start button and runs nothing.
LuckySettingsDB.bankQueueMode = "manual"
LuckySettingsDB.hideBankQueue = true
log = {}
fire("BANKFRAME_OPENED")
check(log[1] == "plan deposit" and log[2] == "plan restock" and #log == 2, "manual mode plans but runs nothing")
check(progress().total == 4 and #progress().queue == 3, "the preview lists every planned item")
check(progress().queue[1].direction == "deposit" and progress().queue[3].direction == "withdraw",
    "each preview row carries its job's direction")
check(window.startButton.shown == true, "manual mode shows Start, even with the window hidden")

-- A slash command before Start runs, then the window goes back to the preview.
LuckyBankRun:Queue({ plan = function() return moves(7) end, run = function(job) job:Tick(); job:Done() end })
check(window.startButton.shown == false, "a running job takes the preview's place")
flushTimers()
check(window.startButton.shown == true and progress().total == 4, "the preview comes back once that job is done")

log = {}
LuckyBankRun:StartBankJobs()
check(log[1] == "plan deposit" and log[3] == "run deposit", "Start plans afresh and runs the first job")
check(window.startButton.shown == false and progress().total == 4, "the run replaces the preview")
held.deposit:Done()
flushTimers()
held.restock:Done()
flushTimers()
check(LuckyBankRun.current == nil and window.shown == true, "a started run ends on All done")

fire("BANKFRAME_CLOSED")
LuckySettingsDB = {}

print(string.format("%d LuckyBankRun tests passed", passed))
