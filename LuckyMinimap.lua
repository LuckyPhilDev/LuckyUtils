-- LuckyMinimap: Shared minimap button factory for Lucky Phil's addons.
-- Creates draggable minimap buttons without external library dependencies.

LuckyMinimap = LuckyMinimap or {}

local math_sqrt = math.sqrt
local math_atan2 = math.atan2
local math_sin = math.sin
local math_cos = math.cos
local math_deg = math.deg
local math_rad = math.rad
local math_max = math.max
local math_min = math.min

-- Extra distance (px) the button sits beyond the minimap edge.
local EDGE_OFFSET = 8

-- Which quadrants of each minimap shape are rounded. Mirrors LibDBIcon so the
-- button hugs the edge correctly whether the user's minimap is round, square,
-- or a clipped variant from another addon. Index order: {q1, q2, q3, q4}.
local minimapShapes = {
    ["ROUND"]                 = { true,  true,  true,  true  },
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { false, false, false, true  },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { true,  false, false, false },
    ["SIDE-LEFT"]             = { false, true,  false, true  },
    ["SIDE-RIGHT"]            = { true,  false, true,  false },
    ["SIDE-TOP"]              = { false, false, true,  true  },
    ["SIDE-BOTTOM"]           = { true,  true,  false, false },
    ["TRICORNER-TOPLEFT"]     = { false, true,  true,  true  },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true  },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true  },
    ["TRICORNER-BOTTOMRIGHT"] = { true,  true,  true,  false },
}

--- Convert a cursor position relative to Minimap centre into an angle in degrees.
local function GetMinimapAngle()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale  = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    return math_deg(math_atan2(cy - my, cx - mx)) % 360
end

--- Position a button around the Minimap at the given angle (degrees).
--- Radius is derived from the live minimap size so the button always sits on
--- the edge regardless of how large the player has scaled their minimap.
local function SetButtonPosition(button, angle)
    local rad = math_rad(angle)
    local x, y, q = math_cos(rad), math_sin(rad), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end

    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local quad  = minimapShapes[shape] or minimapShapes["ROUND"]
    local w = (Minimap:GetWidth()  / 2) + EDGE_OFFSET
    local h = (Minimap:GetHeight() / 2) + EDGE_OFFSET

    if quad[q] then
        -- Rounded quadrant: place on the ellipse.
        x, y = x * w, y * h
    else
        -- Square quadrant: clamp to the straight edge.
        local diagW = math_sqrt(2 * (w ^ 2)) - 10
        local diagH = math_sqrt(2 * (h ^ 2)) - 10
        x = math_max(-w, math_min(x * diagW, w))
        y = math_max(-h, math_min(y * diagH, h))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--- Create a minimap button.
---@param opts table
---   opts.name         (string)        Global frame name (must be unique per addon)
---   opts.icon         (string|number) Texture path or fileID for the button icon
---   opts.dbKey        (string)        Key within the addon's SavedVariables for minimap state
---   opts.db           (table)         Reference to the addon's SavedVariables table
---   opts.defaultAngle (number)        Initial angle in degrees (default 220). Give each
---                                     addon a distinct value so buttons don't stack.
---   opts.onClick      (function)      Called with (button, mouseButton) on click
---   opts.tooltip      (function)      Called with (tooltip) to populate tooltip lines
---@return Button
function LuckyMinimap:Create(opts)
    -- Ensure db sub-table exists with per-field defaults (callers may pre-seed
    -- an empty table via their own defaults merge, so `or` on the whole table
    -- isn't enough).
    opts.db[opts.dbKey] = opts.db[opts.dbKey] or {}
    local state = opts.db[opts.dbKey]
    if state.minimapPos == nil then state.minimapPos = opts.defaultAngle or 220 end
    if state.hide == nil then state.hide = false end

    local btn = CreateFrame("Button", opts.name, Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

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

    -- Highlight. Use the button's native highlight (as LibDBIcon/Dominos do)
    -- rather than a manual HIGHLIGHT-layer texture. The ZoomButton-Highlight is
    -- an additive glow; drawn plainly its black backing shows as an opaque
    -- square on hover, so force ADD blending.
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local hl = btn:GetHighlightTexture()
    if hl then
        hl:SetBlendMode("ADD")
    end

    -- Drag behaviour. RegisterForDrag means OnDragStart only fires once the
    -- cursor actually moves, so a normal click still routes to OnClick.
    local function trackCursor()
        local angle = GetMinimapAngle()
        state.minimapPos = angle
        SetButtonPosition(btn, angle)
    end

    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", trackCursor)
    end)

    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    -- Click handler
    btn:SetScript("OnClick", function(self, mouseBtn)
        if self.isDragging then return end
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
        if show then self:Show() else self:Hide() end
    end

    --- Re-run positioning. Call after the minimap may have changed size/shape.
    function btn:Reposition()
        SetButtonPosition(self, state.minimapPos)
    end

    return btn
end

-- The compartment passes the clicked mouse button and the menu line frame to
-- its callback, but their argument positions have shifted across game patches.
-- Rather than hardcode an order that breaks on the next change, pick them out
-- of the argument list by shape.
local function findMouseButton(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" and v:match("Button$") then
            return v
        end
    end
    return "LeftButton"
end

local function findFrame(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "table" and v.GetObjectType then
            return v
        end
    end
    return nil
end

--- Register the addon in Blizzard's AddOn Compartment (the collapsible button
--- list at the top of the minimap). This is an alternative or companion to the
--- per-addon minimap button: a user running several Lucky addons can collapse
--- the cluster of minimap buttons into one native menu.
---
--- It mirrors the click/tooltip contract of Create, so the same `onClick` and
--- `tooltip` functions drive both surfaces from one shared config.
---@param opts table
---   opts.text    (string)        Label shown in the compartment (fallback: opts.name)
---   opts.name    (string)        Stable registration id, used if text is absent
---   opts.icon    (string|number) Texture path or fileID for the menu icon
---   opts.onClick (function)      Called with (frame, mouseButton) on click
---   opts.tooltip (function)      Called with (tooltip) to populate tooltip lines
---@return boolean registered  False if the compartment is unavailable on this client.
function LuckyMinimap:RegisterCompartment(opts)
    if not AddonCompartmentFrame or not AddonCompartmentFrame.RegisterAddon then
        return false
    end

    AddonCompartmentFrame:RegisterAddon({
        text                = opts.text or opts.name,
        icon                = opts.icon,
        notCheckable        = true,
        registerForAnyClick = true,
        func = function(...)
            if opts.onClick then
                opts.onClick(findFrame(...), findMouseButton(...))
            end
        end,
        funcOnEnter = opts.tooltip and function(...)
            GameTooltip:SetOwner(findFrame(...) or UIParent, "ANCHOR_LEFT")
            opts.tooltip(GameTooltip)
            GameTooltip:Show()
        end or nil,
        funcOnLeave = opts.tooltip and function()
            GameTooltip:Hide()
        end or nil,
    })
    return true
end
