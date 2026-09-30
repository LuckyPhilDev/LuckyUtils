-- LuckyInstance: one answer to "what content is the player in?" for every
-- Lucky addon, so a delve or a keystone is recognised the same way everywhere.

if LuckysUtilsSkipLoad then return end

LuckyInstance = LuckyInstance or {}

LuckyInstance.MYTHIC_KEYSTONE_DIFFICULTY = 8

-- Delves are known by difficulty, not C_PartyInfo.IsDelveInProgress: that also
-- reports true in delve-like scenarios such as Tidebound Grotto.
LuckyInstance.DELVE_DIFFICULTY_IDS = {
    [208] = true, [215] = true, [216] = true, [217] = true,
    [218] = true, [219] = true, [220] = true,
}

local KIND_BY_TYPE = {
    raid = "raid", party = "dungeon", pvp = "battleground", arena = "arena", scenario = "scenario",
}

--- Level of the running keystone, or 0 outside one.
---@return number
function LuckyInstance.KeystoneLevel()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo) then return 0 end
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    return type(level) == "number" and level > 0 and level or 0
end

---@param difficultyID number|nil  Defaults to the current instance's difficulty.
---@return boolean
function LuckyInstance.IsDelve(difficultyID)
    difficultyID = difficultyID or select(3, GetInstanceInfo())
    return LuckyInstance.DELVE_DIFFICULTY_IDS[difficultyID] == true
end

--- Classify where the player is.
---
--- kind is "openworld", "raid", "mythicplus", "dungeon", "delve",
--- "battleground", "arena" or "scenario", or nil when the game cannot say yet
--- (mid loading screen) or the content is a hybrid. GetInstanceInfo and
--- IsInInstance disagree on hybrids, such as a housing Decor Duel reporting
--- "pvp" from one and "scenario" from the other, so both must agree.
---
--- info carries name, instanceType, difficultyID and instanceID when inside.
---@return string|nil kind, table|nil info
function LuckyInstance.Current()
    local inInstance, inInstanceType = IsInInstance()
    if inInstance == nil then return nil end
    if not inInstance then return "openworld" end

    local name, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if type(name) ~= "string" or name == "" or type(instanceID) ~= "number" then return nil end
    if instanceType ~= inInstanceType then return nil end
    local info = { name = name, instanceType = instanceType, difficultyID = difficultyID, instanceID = instanceID }

    if LuckyInstance.IsDelve(difficultyID) then return "delve", info end
    if instanceType == "party" and (difficultyID == LuckyInstance.MYTHIC_KEYSTONE_DIFFICULTY
            or LuckyInstance.KeystoneLevel() > 0) then
        return "mythicplus", info
    end
    return KIND_BY_TYPE[instanceType], info
end
