-- luacheck: globals LuckyInstance IsInInstance GetInstanceInfo C_ChallengeMode

LuckyInstance = nil
dofile("LuckyInstance.lua")

local function at(inInstance, isType, infoType, difficultyID, name)
    IsInInstance = function() return inInstance, isType end
    GetInstanceInfo = function() return name or "Somewhere", infoType, difficultyID, "", 5, 0, false, 100 end
end

at(false, "none", "none", 0)
assert(LuckyInstance.Current() == "openworld", "outside an instance is open world")

at(nil)
assert(LuckyInstance.Current() == nil, "a loading screen has no answer yet")

at(true, "scenario", "scenario", 208)
assert(LuckyInstance.Current() == "delve", "the Delves difficulty is a delve")

at(true, "scenario", "scenario", 1, "Tidebound Grotto")
assert(LuckyInstance.Current() == "scenario", "a scenario on another difficulty is not a delve")
assert(not LuckyInstance.IsDelve(216) and not LuckyInstance.IsDelve(220), "Quest and Story raid are not delves")

at(true, "party", "party", 8)
assert(LuckyInstance.Current() == "mythicplus", "the keystone difficulty is Mythic+")

at(true, "party", "party", 23)
C_ChallengeMode = { GetActiveKeystoneInfo = function() return 12 end }
assert(LuckyInstance.Current() == "mythicplus", "a running keystone is Mythic+")
C_ChallengeMode = nil
assert(LuckyInstance.Current() == "dungeon", "a dungeon without a keystone is a dungeon")

at(true, "raid", "raid", 16)
local kind, info = LuckyInstance.Current()
assert(kind == "raid" and info.difficultyID == 16 and info.instanceID == 100, "a raid carries its details")

at(true, "scenario", "pvp", 0)
assert(LuckyInstance.Current() == nil, "a hybrid where the two APIs disagree is not classified")

print("LuckyInstanceTest: ok")
