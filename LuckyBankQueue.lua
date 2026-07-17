-- LuckyBankQueue: Sequential, cursor-aware container item transfers.

LuckyBankQueue = LuckyBankQueue or {}

local Queue = {}
Queue.__index = Queue

local DEFAULT_POLL_DELAY = 0.05
local DEFAULT_MAX_POLLS = 100

local function defaultGetContainerItemInfo(bag, slot)
    return C_Container.GetContainerItemInfo(bag, slot)
end

local function defaultPickupContainerItem(bag, slot)
    C_Container.PickupContainerItem(bag, slot)
end

local function defaultSplitContainerItem(bag, slot, amount)
    C_Container.SplitContainerItem(bag, slot, amount)
end

local function defaultSchedule(delay, callback)
    C_Timer.After(delay, callback)
end

local function destinationKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

function LuckyBankQueue:New(options)
    options = options or {}

    local queue = setmetatable({}, Queue)
    queue.getContainerItemInfo = options.getContainerItemInfo or defaultGetContainerItemInfo
    queue.pickupContainerItem = options.pickupContainerItem or defaultPickupContainerItem
    queue.splitContainerItem = options.splitContainerItem or defaultSplitContainerItem
    queue.getCursorInfo = options.getCursorInfo or GetCursorInfo
    queue.schedule = options.schedule or defaultSchedule
    queue.findDestination = options.findDestination
    queue.onStepComplete = options.onStepComplete
    queue.onError = options.onError
    queue.pollDelay = options.pollDelay or DEFAULT_POLL_DELAY
    queue.maxPolls = options.maxPolls or DEFAULT_MAX_POLLS
    queue.steps = {}
    queue.nextStep = 1
    queue.running = false
    queue.cancelled = false
    queue.ownsCursor = false
    queue.polls = 0

    return queue
end

function Queue:Enqueue(step)
    if type(step) ~= "table"
        or type(step.sourceBag) ~= "number"
        or type(step.sourceSlot) ~= "number"
        or type(step.itemID) ~= "number"
        or (step.amount ~= nil and (
            type(step.amount) ~= "number"
            or step.amount <= 0
            or step.amount % 1 ~= 0
        ))
    then
        return nil, "invalid_step"
    end

    self.steps[#self.steps + 1] = step
    return step
end

function Queue:IsRunning()
    return self.running
end

function Queue:GetPendingCount()
    return math.max(0, #self.steps - self.nextStep + 1)
end

function Queue:Cancel()
    if not self.running then
        return false
    end

    self.cancelled = true
    return true
end

function Queue:_schedule(callback)
    self.schedule(self.pollDelay, callback)
end

function Queue:_restoreSource(step)
    if not self.ownsCursor then return end

    local cursorType = self.getCursorInfo()
    if cursorType == "item" then
        self.pickupContainerItem(step.sourceBag, step.sourceSlot)
    end
    self.ownsCursor = false
end

function Queue:_finish()
    self.running = false
    self.cancelled = false
    self.ownsCursor = false

    local callback = self.completionCallback
    self.completionCallback = nil
    if callback then
        callback(self)
    end
end

function Queue:_fail(step, code)
    self:_restoreSource(step)
    self.running = false
    self.cancelled = false
    self.completionCallback = nil

    if self.onError then
        self.onError(self, step, code)
    end
end

function Queue:_poll(step, callback, timeoutCode)
    if self.cancelled then
        self:_fail(step, "cancelled")
        return
    end

    if callback() then
        self.polls = 0
        return
    end

    self.polls = self.polls + 1
    if self.polls > self.maxPolls then
        self:_fail(step, timeoutCode)
        return
    end

    self:_schedule(function()
        self:_poll(step, callback, timeoutCode)
    end)
end

function Queue:_completeStep(step)
    self.ownsCursor = false
    if self.onStepComplete then
        self.onStepComplete(self, step)
    end

    self.nextStep = self.nextStep + 1
    self:_processNext()
end

function Queue:_placeCursor(step, excluded)
    local destinationBag, destinationSlot
    if self.findDestination then
        destinationBag, destinationSlot = self.findDestination(step.itemID, excluded, step)
    end

    if destinationBag == nil or destinationSlot == nil then
        self:_fail(step, "destination_missing")
        return
    end

    local key = destinationKey(destinationBag, destinationSlot)
    local function tryDestination()
        local destinationInfo = self.getContainerItemInfo(destinationBag, destinationSlot)
        if destinationInfo and destinationInfo.isLocked then
            return false
        end
        if destinationInfo and destinationInfo.itemID ~= step.itemID then
            excluded[key] = true
            self:_placeCursor(step, excluded)
            return true
        end

        self.pickupContainerItem(destinationBag, destinationSlot)
        self:_schedule(function()
            local cursorType = self.getCursorInfo()
            if cursorType == nil then
                self:_completeStep(step)
                return
            end
            if cursorType ~= "item" then
                self:_fail(step, "unexpected_cursor")
                return
            end

            excluded[key] = true
            self:_placeCursor(step, excluded)
        end)
        return true
    end

    self:_poll(step, tryDestination, "destination_locked")
end

function Queue:_pickUp(step, sourceInfo)
    local amount = step.amount
    local stackCount = sourceInfo.stackCount or sourceInfo.count or 1
    self.ownsCursor = true
    if amount and amount < stackCount then
        self.splitContainerItem(step.sourceBag, step.sourceSlot, amount)
    else
        self.pickupContainerItem(step.sourceBag, step.sourceSlot)
    end

    local function waitForCursor()
        local cursorType, cursorItemID = self.getCursorInfo()
        if cursorType == nil then
            return false
        end
        if cursorType ~= "item" then
            self:_fail(step, "unexpected_cursor")
            return true
        end
        if cursorItemID and cursorItemID ~= step.itemID then
            self:_fail(step, "cursor_item_mismatch")
            return true
        end

        self:_placeCursor(step, {})
        return true
    end

    self:_poll(step, waitForCursor, "pickup_timeout")
end

function Queue:_prepareStep(step)
    local cursorType = self.getCursorInfo()
    if cursorType ~= nil then
        self:_fail(step, "cursor_busy")
        return
    end

    local function waitForSource()
        local sourceInfo = self.getContainerItemInfo(step.sourceBag, step.sourceSlot)
        if not sourceInfo then
            self:_fail(step, "source_missing")
            return true
        end
        if sourceInfo.isLocked then
            return false
        end
        if sourceInfo.itemID and sourceInfo.itemID ~= step.itemID then
            self:_fail(step, "source_item_mismatch")
            return true
        end

        self:_pickUp(step, sourceInfo)
        return true
    end

    self:_poll(step, waitForSource, "source_locked")
end

function Queue:_processNext()
    if self.cancelled then
        local step = self.steps[self.nextStep]
        if step then
            self:_fail(step, "cancelled")
        else
            self:_finish()
        end
        return
    end

    local step = self.steps[self.nextStep]
    if not step then
        self:_finish()
        return
    end

    self:_prepareStep(step)
end

function Queue:Start(onComplete)
    if self.running then
        return nil, "already_running"
    end

    self.running = true
    self.cancelled = false
    self.ownsCursor = false
    self.completionCallback = onComplete
    self:_processNext()
    return true
end
