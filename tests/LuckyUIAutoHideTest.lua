-- luacheck: ignore 111 113 121

LuckyUI = nil
LuckysUtilsSkipLoad = nil
STANDARD_TEXT_FONT = "font"
function GetLocale() return "enUS" end

-- A frame stubbed only as far as EnableAutoHide reaches into it: real Show,
-- Hide, width and script storage, everything else a no-op.
local function newFrame(width)
    local frame = { width = width, shown = true, alpha = 1, scripts = {}, textures = {} }
    function frame:GetWidth() return self.width end
    function frame:SetWidth(w) self.width = w end
    function frame:GetAlpha() return self.alpha end
    function frame:SetAlpha(a) self.alpha = a end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:GetScript(name) return self.scripts[name] end
    function frame:HookScript(name, fn)
        local prior = self.scripts[name]
        self.scripts[name] = function(...)
            if prior then prior(...) end
            fn(...)
        end
    end
    function frame:CreateTexture()
        local t = { shown = false }
        function t:SetPoint() end
        function t:SetHeight(h) self.height = h end
        function t:SetWidth(w) self.width = w end
        function t:SetColorTexture() end
        function t:Show() self.shown = true end
        function t:Hide() self.shown = false end
        table.insert(self.textures, t)
        return t
    end
    function frame:Fire(name, ...)
        local fn = self.scripts[name]
        if fn then fn(self, ...) end
    end
    return frame
end

dofile("LuckyUI.lua")

local passed = 0

local function check(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
    passed = passed + 1
end

-- Nothing happens until it is started ----------------------------------------
local f = LuckyUI.EnableAutoHide(newFrame(102), 10)
check(f.autoHideBar.shown, false, "no bar before starting")
check(f:GetScript("OnUpdate"), nil, "no OnUpdate before starting")

check(LuckyUI.EnableAutoHide(f, 10), f, "attaching twice is a no-op")
check(#f.textures, 1, "and builds no second bar")

-- The bar drains and the frame hides -----------------------------------------
f:StartAutoHide()
check(f.autoHideBar.shown, true, "the bar shows")
check(f.autoHideBar.width, 100, "full width, inside the border")

f:Fire("OnUpdate", 5)
check(f.autoHideBar.width, 50, "half spent, half a bar")
check(f.shown, true, "and still up")
check(f.alpha, 1, "at full alpha until the wait is out")

-- The wait ends where the fade begins, so the bar empties as it starts going.
f:Fire("OnUpdate", 5)
check(f.autoHideBar.width, 1, "the bar is spent")
check(f.shown, true, "but the frame is still there, fading")

f:Fire("OnUpdate", 0.375)
check(f.alpha, 0.5, "half faded")
check(f.shown, true, "and not gone yet")

f:Fire("OnUpdate", 0.375)
check(f.shown, false, "faded out, so the frame hides itself")
check(f.autoHideBar.shown, false, "and the bar goes with it")
check(f.alpha, 1, "leaving the alpha as it found it")
check(f:GetScript("OnUpdate"), nil, "and no OnUpdate running")

-- Hovering puts the wait back to full ----------------------------------------
f:Show()
f:StartAutoHide()
f:Fire("OnUpdate", 4)
check(f.autoHideBar.width, 60, "six seconds left")

f:Fire("OnEnter")
check(f:GetScript("OnUpdate"), nil, "the mouse stops the clock")
check(f.autoHideBar.width, 100, "and winds it back to full")

f:Fire("OnLeave")
f:Fire("OnUpdate", 1)
check(f.autoHideBar.width, 90, "so leaving gives the whole wait again")

-- The same reprieve reaches one already fading.
f:Fire("OnUpdate", 9.3)
check(f.shown, true, "still there, part faded")
check(f.alpha < 1, true, "and visibly on its way out")
f:Fire("OnEnter")
check(f.alpha, 1, "the mouse brings it back to full")
check(f.autoHideBar.width, 100, "with the whole wait to run again")

-- A frame stopped by hand stays put ------------------------------------------
f:StopAutoHide()
check(f.autoHideBar.shown, false, "stopping clears the bar")
f:Fire("OnLeave")
check(f:GetScript("OnUpdate"), nil, "and hovering off cannot restart it")
check(f.shown, true, "the frame stays up")

-- A frame that resizes keeps a bar its own width -----------------------------
f:StartAutoHide()
f:SetWidth(202)
f:Fire("OnUpdate", 5)
check(f.autoHideBar.width, 100, "half of the width it has now")

-- Each start buys the full time again ----------------------------------------
f:StartAutoHide()
check(f.autoHideBar.width, 200, "back to full")
f:StartAutoHide(2)
f:Fire("OnUpdate", 1)
check(f.autoHideBar.width, 100, "and an override sets a new duration")

print(passed .. " LuckyUI auto-hide tests passed")
