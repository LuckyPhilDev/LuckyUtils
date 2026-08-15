-- LuckyPromo: "More from Lucky Phil" cross-promotion section for settings panels.
-- Lists Lucky Phil addons the user does not have installed, with a click-to-copy
-- CurseForge link. Addons already installed (or the addon hosting the section)
-- are never shown, so only the Discord link remains once everything is
-- installed.

LuckyPromo = LuckyPromo or {}

local SECTION_TITLE = "More from Lucky Phil"

-- Always first in the icon row, whatever else is shown.
local DISCORD = {
    name = "Discord",
    desc = "Get support, report a bug or suggest a feature.",
    icon = "Interface\\AddOns\\Luckys_Utils\\Media\\discord.tga",
    url  = "https://discord.gg/ptTtYyAjdZ",
}

-- Published addons, promoted everywhere they are not installed.
local ADDONS = {
    {
        folder = "Luckys_Grab_Bag",
        name   = "Lucky's Grab-bag",
        desc   = "A collection of small quality-of-life features.",
        icon   = "Interface\\AddOns\\Luckys_Utils\\Media\\promo-grab-bag.tga",
        url    = "https://www.curseforge.com/wow/addons/luckys-grab-bag",
    },
    {
        folder = "Luckys_Loot_Wishlist",
        name   = "Lucky's Loot Wishlist",
        desc   = "Track loot from the Adventure Guide and manage a per-character wishlist.",
        icon   = "Interface\\AddOns\\Luckys_Utils\\Media\\promo-loot-wishlist.tga",
        url    = "https://www.curseforge.com/wow/addons/luckys-loot-wishlist",
    },
    {
        folder = "Luckys_Warbank_Stockist",
        name   = "Lucky's Warbank Stockist",
        desc   = "Automatically manages item quantities between your bags and the Warband Bank.",
        icon   = "Interface\\AddOns\\Luckys_Utils\\Media\\promo-warbank-stockist.tga",
        url    = "https://www.curseforge.com/wow/addons/luckys-warbank-stockist",
    },
    {
        folder = "Luckys_Character_Mount",
        name   = "Lucky's Character Mount",
        desc   = "Summons a random racial or class mount. Per-character list, auto-populated.",
        icon   = "Interface\\AddOns\\Luckys_Utils\\Media\\promo-character-mount.tga",
        url    = "https://www.curseforge.com/wow/addons/luckys-character-mount",
    },
    {
        folder = "Luckys_Wardrobe",
        name   = "Lucky's Wardrobe",
        desc   = "Find the sets you can still finish, and hear about it the moment a piece drops.",
        icon   = "Interface\\AddOns\\Luckys_Utils\\Media\\promo-wardrobe.tga",
        url    = "https://www.curseforge.com/wow/addons/luckys-wardrobe",
    },
}

StaticPopupDialogs["LUCKY_PROMO_COPY_URL"] = {
    text         = "Copy the link:",
    button1      = CLOSE,
    hasEditBox   = 1,
    editBoxWidth = 280,
    OnShow = function(self)
        local editBox = self.editBox or _G[self:GetName() .. "EditBox"]
        editBox:SetMaxLetters(0)
        editBox:SetText(self.data or "")
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    OnHide = function(self)
        local editBox = self.editBox or _G[self:GetName() .. "EditBox"]
        editBox:SetText("")
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

--- Addons from the promo list that are not installed, excluding the caller.
---@param selfFolder string  The hosting addon's folder name
---@return table
function LuckyPromo:Missing(selfFolder)
    local showAll = LuckySettingsDB and LuckySettingsDB.promoShowAll
    local out = {}
    for _, addon in ipairs(ADDONS) do
        if addon.folder ~= selfFolder and (showAll or not LuckyDeps:IsEnabled(addon.folder)) then
            out[#out + 1] = addon
        end
    end
    return out
end

-- Dev toggle: show every addon regardless of install state, for layout testing.
SLASH_LUCKYPROMO1 = "/luckypromo"
SlashCmdList.LUCKYPROMO = function()
    LuckySettingsDB = LuckySettingsDB or {}
    LuckySettingsDB.promoShowAll = not LuckySettingsDB.promoShowAll or nil
    print("LuckyPromo: show all " .. (LuckySettingsDB.promoShowAll and "ON" or "OFF") .. ". /reload to apply.")
end

function LuckyPromo:ShowCopyPopup(url)
    StaticPopup_Show("LUCKY_PROMO_COPY_URL", nil, nil, url)
end

local CARD_W   = 460
local CARD_H   = 52
local CARD_GAP = 8

-- One clickable promo card: gold accent bar, name, wrapped description, and a
-- copy-link hint. Highlights on hover. Anchored below `anchor`.
-- LuckyUI is referenced at call time only (it may load after this file).
local function CreateCard(parent, addon, anchor)
    local C = LuckyUI.C

    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -CARD_GAP)
    card:SetBackdrop(LuckyUI.Backdrop)
    card:SetBackdropColor(C.bgInput[1], C.bgInput[2], C.bgInput[3], 0.6)
    card:SetBackdropBorderColor(C.borderDark[1], C.borderDark[2], C.borderDark[3])

    local hl = card:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3], 0.08)

    local bar = card:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMLEFT", 1, 1)
    bar:SetWidth(3)
    bar:SetColorTexture(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3], 0.9)

    local name = card:CreateFontString(nil, "OVERLAY")
    name:SetFont(LuckyUI.BODY_FONT, 13)
    name:SetPoint("TOPLEFT", 14, -9)
    name:SetTextColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3])
    name:SetText(addon.name)

    local desc = card:CreateFontString(nil, "OVERLAY")
    desc:SetFont(LuckyUI.BODY_FONT, 11)
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(CARD_W - 130)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3])
    desc:SetText(addon.desc)

    local hint = card:CreateFontString(nil, "OVERLAY")
    hint:SetFont(LuckyUI.BODY_FONT, 11)
    hint:SetPoint("RIGHT", -12, 0)
    hint:SetText("|A:chatframe-button-copy:14:14|a " .. LuckyUI.WC.goldAccent .. "Get link" .. LuckyUI.WC.reset)

    card:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3])
    end)
    card:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.borderDark[1], C.borderDark[2], C.borderDark[3])
    end)
    card:SetScript("OnClick", function() LuckyPromo:ShowCopyPopup(addon.url) end)

    return card
end

--- Append the section to a LuckySettings:NewPanel() builder. No-op when
--- everything is already installed.
---@param builder table  The builder returned by NewPanel
---@param selfFolder string
function LuckyPromo:AddToBuilder(builder, selfFolder)
    local missing = self:Missing(selfFolder)
    if #missing == 0 then return end

    builder:Section(SECTION_TITLE)
    local anchor = builder.lastAnchor
    for _, addon in ipairs(missing) do
        anchor = CreateCard(builder.content, addon, anchor)
    end
    builder.lastAnchor = anchor  -- keep the builder's anchor chain intact
end

local ICON_SIZE = 34
local ICON_GAP  = 8
local ICON_ROW_H = ICON_SIZE + 12

-- One icon button in the promo row. Name and description live in the tooltip;
-- clicking opens the copy-link popup.
local function CreateIconButton(parent, entry, index)
    local C = LuckyUI.C

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetPoint("LEFT", parent, "LEFT", 14 + (index - 1) * (ICON_SIZE + ICON_GAP), 0)
    btn:SetBackdrop(LuckyUI.Backdrop)
    btn:SetBackdropColor(C.bgInput[1], C.bgInput[2], C.bgInput[3], 0.6)
    btn:SetBackdropBorderColor(C.borderDark[1], C.borderDark[2], C.borderDark[3])

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetTexture(entry.icon)
    -- Interface\Icons art carries a baked-in border; the Discord tile does not.
    if type(entry.icon) ~= "string" or entry.icon:find("Icons\\") then
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3])
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(entry.name, C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3])
        GameTooltip:AddLine(entry.desc, 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click for the link", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.borderDark[1], C.borderDark[2], C.borderDark[3])
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function() LuckyPromo:ShowCopyPopup(entry.url) end)

    return btn
end

--- Append the section to a LuckyRichSettings group as a single row of icons:
--- Discord first, then every promoted addon that is not installed.
---@param group table  A RichGroup from NewRichPanel
---@param selfFolder string
function LuckyPromo:AddToRichGroup(group, selfFolder)
    local entries = { DISCORD }
    for _, addon in ipairs(self:Missing(selfFolder)) do
        entries[#entries + 1] = addon
    end

    group:BottomSection(SECTION_TITLE)
    local row = group:BottomFrame(ICON_ROW_H)
    for i, entry in ipairs(entries) do
        CreateIconButton(row, entry, i)
    end
end

--- Render the section into an arbitrary frame for custom-built panels.
--- Anchored below `anchor`, or to the parent's top-left when anchor is nil.
---@param parent Frame  Frame to create the widgets in
---@param anchor Region|nil  Region to anchor below
---@param selfFolder string
---@return Region|nil last  Bottom-most created region, nil when nothing to show
---@return number height  Estimated pixel height of the section
function LuckyPromo:CreateSection(parent, anchor, selfFolder)
    local missing = self:Missing(selfFolder)
    if #missing == 0 then return nil, 0 end

    local C = LuckyUI.C
    local heading = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    if anchor then
        heading:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
    else
        heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -16)
    end
    heading:SetTextColor(C.goldAccent[1], C.goldAccent[2], C.goldAccent[3])
    heading:SetText(SECTION_TITLE)

    local last = heading
    for _, addon in ipairs(missing) do
        last = CreateCard(parent, addon, last)
    end

    -- ponytail: fixed card estimate; measure real string heights if it ever clips
    return last, 30 + #missing * (CARD_H + CARD_GAP)
end
