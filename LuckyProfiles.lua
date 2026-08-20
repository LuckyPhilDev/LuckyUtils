-- LuckyProfiles: shared profile export/import for Lucky Phil's addons.
--
-- Turns any config table into a single copy-paste share string and reads it
-- back, with a format-version stamp and an Adler-32 checksum so corrupted or
-- truncated strings fail cleanly instead of loading garbage.
--
-- The string never contains executable Lua: encoding serialises to a private
-- length-prefixed format and decoding parses that format by hand, so importing
-- a malicious string can never run code (unlike load()-based serializers).
--
-- Public API:
--   LuckyProfiles:Encode(table)            -> shareString
--   LuckyProfiles:Decode(shareString)      -> table | nil, errorMessage
--   LuckyProfiles:ShowExport(title, table) -> opens a copyable share panel
--   LuckyProfiles:ShowImport(title, onAccept) -> opens an import panel;
--       onAccept(decodedTable) is called when the user imports a valid string.

if LuckysUtilsSkipLoad then return end

LuckyProfiles = LuckyProfiles or {}

local S = LuckyUtilsStrings.profiles

local PREFIX = "LP1"  -- bump if the wire format ever changes incompatibly

-- ---------------------------------------------------------------------------
-- Base64 (standard alphabet, with padding)
-- ---------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

-- Reverse lookup: byte value of a base64 char -> its 6-bit value.
local B64_DEC = {}
for i = 1, #B64 do
    B64_DEC[B64:byte(i)] = i - 1
end

local floor  = math.floor
local schar  = string.char
local sbyte  = string.byte
local ssub   = string.sub
local tconcat = table.concat

local function base64Encode(data)
    local out, n = {}, 0
    local len = #data
    for i = 1, len, 3 do
        local b1 = sbyte(data, i)
        local b2 = sbyte(data, i + 1)
        local b3 = sbyte(data, i + 2)
        local triple = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1 = floor(triple / 262144) % 64
        local c2 = floor(triple / 4096) % 64
        local c3 = floor(triple / 64) % 64
        local c4 = triple % 64
        n = n + 1
        if not b2 then
            out[n] = ssub(B64, c1 + 1, c1 + 1) .. ssub(B64, c2 + 1, c2 + 1) .. "=="
        elseif not b3 then
            out[n] = ssub(B64, c1 + 1, c1 + 1) .. ssub(B64, c2 + 1, c2 + 1)
                  .. ssub(B64, c3 + 1, c3 + 1) .. "="
        else
            out[n] = ssub(B64, c1 + 1, c1 + 1) .. ssub(B64, c2 + 1, c2 + 1)
                  .. ssub(B64, c3 + 1, c3 + 1) .. ssub(B64, c4 + 1, c4 + 1)
        end
    end
    return tconcat(out)
end

-- Decode base64, ignoring any whitespace the user may have pasted in. Returns
-- nil on an invalid character so a mistyped string is rejected, not guessed at.
local function base64Decode(str)
    str = str:gsub("%s", "")
    local out, n = {}, 0
    local acc, bits = 0, 0
    for i = 1, #str do
        local ch = sbyte(str, i)
        if ch == 61 then break end  -- "=" padding: nothing more to read
        local val = B64_DEC[ch]
        if not val then return nil end
        acc = acc * 64 + val
        bits = bits + 6
        if bits >= 8 then
            bits = bits - 8
            local byteVal = floor(acc / (2 ^ bits)) % 256
            n = n + 1
            out[n] = schar(byteVal)
            -- Keep only the still-unconsumed low bits. Without this reset the
            -- accumulator grows past 2^53 on long strings and loses precision.
            acc = acc % (2 ^ bits)
        end
    end
    return tconcat(out)
end

-- ---------------------------------------------------------------------------
-- Checksum (Adler-32) — cheap and good enough to catch paste corruption.
-- ---------------------------------------------------------------------------

local function adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + sbyte(s, i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

-- ---------------------------------------------------------------------------
-- Serialisation — a private length-prefixed format, never executable Lua.
--
--   z              nil
--   t / f          boolean true / false
--   n<number>;     number (decimal, terminated by ';')
--   s<len>:<bytes> string (byte length, ':', then the raw bytes)
--   {<pairs>}      table: a flat run of encoded key, value, key, value, ...
-- ---------------------------------------------------------------------------

local MAX_DEPTH = 32  -- guards against pathological / hostile nesting

local encodeValue

encodeValue = function(buf, v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "nil" then
        buf[#buf + 1] = "z"
    elseif t == "boolean" then
        buf[#buf + 1] = v and "t" or "f"
    elseif t == "number" then
        -- %.17g round-trips any double exactly; tostring would lose precision.
        buf[#buf + 1] = "n" .. string.format("%.17g", v) .. ";"
    elseif t == "string" then
        buf[#buf + 1] = "s" .. #v .. ":" .. v
    elseif t == "table" then
        if depth >= MAX_DEPTH then
            error("table nested too deeply to encode")
        end
        buf[#buf + 1] = "{"
        for key, val in pairs(v) do
            local kt = type(key)
            local vt = type(val)
            -- Only portable, serialisable key/value types are emitted; anything
            -- else (functions, userdata) is silently skipped so a stray frame
            -- reference in a config table can't break the whole export.
            if (kt == "string" or kt == "number" or kt == "boolean")
            and (vt == "string" or vt == "number" or vt == "boolean" or vt == "table") then
                encodeValue(buf, key, depth + 1)
                encodeValue(buf, val, depth + 1)
            end
        end
        buf[#buf + 1] = "}"
    else
        error("cannot encode value of type " .. t)
    end
end

-- Recursive-descent parser for the format above. `pos` is a 1-based cursor into
-- `s`; each parse function returns the decoded value and the next position.
local parseValue

local function parseNumber(s, pos)
    local stop = s:find(";", pos, true)
    if not stop then error("malformed number") end
    local num = tonumber(ssub(s, pos, stop - 1))
    if not num then error("invalid number") end
    return num, stop + 1
end

local function parseString(s, pos)
    local colon = s:find(":", pos, true)
    if not colon then error("malformed string") end
    local len = tonumber(ssub(s, pos, colon - 1))
    if not len or len < 0 then error("invalid string length") end
    local start = colon + 1
    local stop = start + len - 1
    if stop > #s then error("string runs past end of data") end
    return ssub(s, start, stop), stop + 1
end

local function parseTable(s, pos, depth)
    if depth >= MAX_DEPTH then error("table nested too deeply to decode") end
    local out = {}
    while true do
        local ch = ssub(s, pos, pos)
        if ch == "" then error("unterminated table") end
        if ch == "}" then
            return out, pos + 1
        end
        local key
        key, pos = parseValue(s, pos, depth + 1)
        local val
        val, pos = parseValue(s, pos, depth + 1)
        out[key] = val
    end
end

parseValue = function(s, pos, depth)
    depth = depth or 0
    local ch = ssub(s, pos, pos)
    if ch == "z" then
        return nil, pos + 1
    elseif ch == "t" then
        return true, pos + 1
    elseif ch == "f" then
        return false, pos + 1
    elseif ch == "n" then
        return parseNumber(s, pos + 1)
    elseif ch == "s" then
        return parseString(s, pos + 1)
    elseif ch == "{" then
        return parseTable(s, pos + 1, depth)
    end
    error("unexpected token '" .. ch .. "' at position " .. pos)
end

-- ---------------------------------------------------------------------------
-- Public encode / decode
-- ---------------------------------------------------------------------------

--- Serialise a config table into a single-line share string.
---@param tbl table  The portable subset of a SavedVariables table.
---@return string  e.g. "LP1:1a2b3c4d:eyJ..."
function LuckyProfiles:Encode(tbl)
    assert(type(tbl) == "table", "LuckyProfiles:Encode expects a table")
    local buf = {}
    encodeValue(buf, tbl, 0)
    local body = tconcat(buf)
    local sum = string.format("%08x", adler32(body))
    return PREFIX .. ":" .. sum .. ":" .. base64Encode(body)
end

--- Decode a share string back into a table.
--- Returns nil plus a human-readable reason on any failure (wrong format,
--- corrupted payload, checksum mismatch, malformed data) so callers can show
--- the user a clear message rather than erroring.
---@param str string
---@return table|nil decoded, string|nil errorMessage
function LuckyProfiles:Decode(str)
    if type(str) ~= "string" then
        return nil, S.nothingToImport
    end
    str = strtrim(str)
    if str == "" then
        return nil, S.nothingToImport
    end

    local prefix, sum, payload = str:match("^(LP%d+):(%x+):(.+)$")
    if not prefix then
        return nil, S.notAShareString
    end
    if prefix ~= PREFIX then
        return nil, S.newerVersion
    end

    local body = base64Decode(payload)
    if not body or body == "" then
        return nil, S.corrupted
    end
    if string.format("%08x", adler32(body)) ~= sum then
        return nil, S.incomplete
    end

    local ok, result, finalPos = pcall(parseValue, body, 1, 0)
    if not ok then
        return nil, S.corrupted
    end
    if type(result) ~= "table" then
        return nil, S.noProfile
    end
    -- Reject trailing junk after a valid table: a well-formed string is fully
    -- consumed, so leftover bytes mean tampering or truncation.
    if finalPos ~= #body + 1 then
        return nil, S.corrupted
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Share-string panels
-- ---------------------------------------------------------------------------

local PANEL_W, PANEL_H = 460, 320

-- Build (once) and return a reusable panel with a scrollable multiline edit box.
-- `kind` is "export" or "import"; the two panels are cached separately so an
-- open export window and import window don't fight over one frame.
local panels = {}

local function buildPanel(kind, onPrimary, primaryLabel)
    local c = LuckyUI.C
    local frame = LuckyUI.CreatePanel("LuckyProfiles" .. kind .. "Panel", UIParent, PANEL_W, PANEL_H)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER")
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())  -- closable with Escape

    LuckyUI.CreateHeader(frame, "")  -- title set per-show

    -- Instruction line under the header.
    local hint = frame:CreateFontString(nil, "OVERLAY")
    hint:SetFont(LuckyUI.BODY_FONT, 12)
    hint:SetTextColor(c.textMuted[1], c.textMuted[2], c.textMuted[3])
    hint:SetPoint("TOPLEFT", 14, -40)
    hint:SetPoint("TOPRIGHT", -14, -40)
    hint:SetJustifyH("LEFT")
    frame.hint = hint

    -- Scrollable multiline edit box for the share string.
    local scrollBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    scrollBg:SetBackdrop(LuckyUI.Backdrop)
    scrollBg:SetBackdropColor(c.bgInput[1], c.bgInput[2], c.bgInput[3], c.bgInput[4])
    scrollBg:SetBackdropBorderColor(c.borderDark[1], c.borderDark[2], c.borderDark[3])
    scrollBg:SetPoint("TOPLEFT", 14, -62)
    scrollBg:SetPoint("BOTTOMRIGHT", -14, 52)

    local scroll = CreateFrame("ScrollFrame", nil, scrollBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(LuckyUI.BODY_FONT, 12, "")
    edit:SetTextColor(c.textLight[1], c.textLight[2], c.textLight[3])
    edit:SetWidth(PANEL_W - 60)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    scroll:SetScrollChild(edit)
    frame.edit = edit

    -- Status / error line above the buttons.
    local status = frame:CreateFontString(nil, "OVERLAY")
    status:SetFont(LuckyUI.BODY_FONT, 12)
    status:SetPoint("BOTTOMLEFT", 14, 18)
    status:SetPoint("BOTTOMRIGHT", -120, 18)
    status:SetJustifyH("LEFT")
    frame.status = status

    -- Primary action button (Copy hint / Import) and a Close button.
    local primary = LuckyUI.CreateButton(frame, primaryLabel, 100, 26, "primary")
    primary:SetPoint("BOTTOMRIGHT", -14, 12)
    primary:SetScript("OnClick", function() onPrimary(frame) end)
    frame.primary = primary

    local close = LuckyUI.CreateButton(frame, "Close", 80, 26, "secondary")
    close:SetPoint("RIGHT", primary, "LEFT", -8, 0)
    close:SetScript("OnClick", function() frame:Hide() end)

    return frame
end

--- Open a panel showing the encoded share string for `tbl`, pre-selected and
--- ready to copy.
---@param title string
---@param tbl table
function LuckyProfiles:ShowExport(title, tbl)
    local str = self:Encode(tbl)
    if not panels.export then
        panels.export = buildPanel(S.exportTitle, function(frame)
            -- "Select All" convenience: re-highlight so the user can Ctrl+C.
            frame.edit:SetFocus()
            frame.edit:HighlightText()
        end, S.selectAll)
    end
    local frame = panels.export
    frame.titleText:SetText(title or S.exportTitle)
    frame.hint:SetText(S.exportHint)
    frame.status:SetText("")
    frame.edit:SetText(str)
    frame.edit:SetCursorPosition(0)
    frame:Show()
    frame.edit:SetFocus()
    frame.edit:HighlightText()
end

--- Open a panel for the user to paste a share string into. On a successful
--- import the panel closes and `onAccept(decodedTable)` is called.
---@param title string
---@param onAccept fun(decoded: table)
function LuckyProfiles:ShowImport(title, onAccept)
    if not panels.import then
        panels.import = buildPanel(S.importTitle, function(frame)
            local decoded, err = LuckyProfiles:Decode(frame.edit:GetText())
            if not decoded then
                local c = LuckyUI.C
                frame.status:SetTextColor(c.danger[1], c.danger[2], c.danger[3])
                frame.status:SetText(err or S.readFailed)
                return
            end
            frame:Hide()
            if frame.onAccept then frame.onAccept(decoded) end
        end, S.importTitle)
    end
    local frame = panels.import
    frame.onAccept = onAccept
    frame.titleText:SetText(title or S.importTitle)
    frame.hint:SetText(S.importHint)
    frame.status:SetText("")
    frame.edit:SetText("")
    frame:Show()
    frame.edit:SetFocus()
end
