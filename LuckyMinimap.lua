-- LuckyMinimap: Shared minimap button factory for Lucky Phil's addons.
-- Creates draggable minimap buttons without external library dependencies.

LuckyMinimap = {}

local math_sqrt = math.sqrt
local math_atan2 = math.atan2
local math_sin = math.sin
local math_cos = math.cos
local math_deg = math.deg
local math_rad = math.rad

local MINIMAP_RADIUS = 80

--- Convert a cursor position relative to Minimap centre into an angle in degrees.
local function GetMinimapAngle()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale  = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    return math_deg(math_atan2(cy - my, cx - mx))
end

--- Position a button around the Minimap at the given angle (degrees).
local function SetButtonPosition(button, angle)
    local rad = math_rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math_cos(rad) * MINIMAP_RADIUS, math_sin(rad) * MINIMAP_RADIUS)
end

--- Create a minimap button.
---@param opts table
---   opts.name        (string)        Global frame name (must be unique per addon)
---   opts.icon        (string|number) Texture path or fileID for the button icon
---   opts.dbKey       (string)        Key within the addon's SavedVariables for minimap state
---   opts.db          (table)         Reference to the addon's SavedVariables table
---   opts.onClick     (function)      Called with (button, mouseButton) on click
---   opts.tooltip     (function)      Called with (tooltip) to populate tooltip lines
---@return Button
function LuckyMinimap:Create(opts)
    -- Ensure db sub-table exists
    opts.db[opts.dbKey] = opts.db[opts.dbKey] or { minimapPos = 220, hide = false }
    local state = opts.db[opts.dbKey]

    local btn = CreateFrame("Button", opts.name, Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")

    -- Background circle
    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(22, 22)
    bg:SetPoint("CENTER", 0, 1)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(opts.icon)
    btn.icon = icon

    -- Highlight
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(24, 24)
    hl:SetPoint("CENTER", 0, 1)
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Drag behaviour
    local isDragging = false

    btn:SetScript("OnMouseDown", function(self, mouseBtn)
        if mouseBtn == "LeftButton" and IsShiftKeyDown() then
            isDragging = true
            self:SetScript("OnUpdate", function()
                local angle = GetMinimapAngle()
                state.minimapPos = angle
                SetButtonPosition(self, angle)
            end)
        end
    end)

    btn:SetScript("OnMouseUp", function(self)
        if isDragging then
            isDragging = false
            self:SetScript("OnUpdate", nil)
        end
    end)

    -- Click handler
    btn:SetScript("OnClick", function(self, mouseBtn)
        if isDragging then return end
        if opts.onClick then
            opts.onClick(self, mouseBtn)
        end
    end)

    -- Tooltip
    if opts.tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            opts.tooltip(GameTooltip)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    -- Initial position
    SetButtonPosition(btn, state.minimapPos)

    -- Show/Hide based on saved state
    if state.hide then
        btn:Hide()
    else
        btn:Show()
    end

    --- Toggle visibility and persist the choice.
    function btn:SetShown_Persisted(show)
        state.hide = not show
        self:SetShown(show)
    end

    return btn
end
