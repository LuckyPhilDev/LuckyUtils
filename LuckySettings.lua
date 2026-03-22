-- LuckySettings: Shared settings registration helper for Lucky Phil's addons.
-- Wraps the modern Settings API for registering and opening addon settings panels.

LuckySettings = {}

--- Register a canvas settings panel with the game's Interface Options.
---@param canvas Frame  The settings panel frame to register
---@param displayName string  The name shown in the settings list
---@return table|nil  category  The registered category object (nil if API unavailable)
function LuckySettings:Register(canvas, displayName)
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return nil end
    local category = Settings.RegisterCanvasLayoutCategory(canvas, displayName)
    if category then
        Settings.RegisterAddOnCategory(category)
    end
    return category
end

--- Open the settings panel for a previously registered category.
---@param category table  The category object returned by Register()
function LuckySettings:Open(category)
    if not category then
        print("Settings panel not registered.")
        return
    end
    if not Settings or not Settings.OpenToCategory then return end
    local id = (type(category.GetID) == "function" and category:GetID()) or category.ID
    if id then
        Settings.OpenToCategory(id)
    end
end
