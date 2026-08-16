-- luacheck: globals StaticPopupDialogs SlashCmdList LuckyPromo

-- Settings panels take their title icon from the promo artwork, so the lookup
-- has to answer for a suite addon and stay quiet for anything else.

StaticPopupDialogs, SlashCmdList = {}, {}
loadfile("LuckyPromo.lua")("Luckys_Utils", {})

assert(LuckyPromo:GetIcon("Luckys_Wardrobe"), "a suite addon has artwork")
assert(LuckyPromo:GetIcon("Luckys_Raid_Inviter") == nil, "an unpromoted addon has none")

print("LuckyPromo tests passed")
