-- LuckySound: Shared sound utilities for Lucky Phil's addons.
-- Provides helpers for playing addon sounds and WoW built-in sounds.

LuckySound = {}

--- Build the WoW-style Interface path for a sound file inside an addon folder.
---@param addonName string    The addon folder name (e.g. "Luckys Grab-bag")
---@param relativePath string Path relative to the addon root (e.g. "sounds\\alert.ogg")
---@return string
function LuckySound:Path(addonName, relativePath)
    return "Interface\\AddOns\\" .. addonName .. "\\" .. relativePath
end

--- Play a sound file.
---@param path string       Full Interface path, or build one with LuckySound:Path()
---@param channel string|nil "SFX" (default), "Master", "Ambience", or "Music"
---@return boolean, number|nil  willPlay, soundHandle
function LuckySound:Play(path, channel)
    return PlaySoundFile(path, channel or "SFX")
end

--- Play a WoW built-in sound by SoundKit ID or SOUNDKIT constant.
---@param soundKit number    Sound kit ID (e.g. 888) or a SOUNDKIT.* constant
---@param channel string|nil "SFX" (default), "Master", "Ambience", or "Music"
---@return boolean, number|nil  willPlay, soundHandle
function LuckySound:PlayKit(soundKit, channel)
    return PlaySound(soundKit, channel or "SFX")
end

--- Stop a currently playing sound.
---@param handle number  The sound handle returned by Play or PlayKit
function LuckySound:Stop(handle)
    if handle then
        StopSound(handle)
    end
end
