-- Five advertise lines. Sending is off until this character enables it.
-- The flag lives on db.chars[short].advertise. It is not one of the five modules.
-- Lines go out through CCT.Chat.Send, so a gag still applies.

local ADDON_NAME, CCT = ...

CCT.Advertise = {}

CCT.Advertise.TIMER_TEXT = "Timer done nya want to Shutout nya !?"

local LINE_COUNT = 5
local window = nil
local ready = nil
local timerDueAt = nil

local function Blank()
    return { enabled = false, lines = { "", "", "", "", "" }, minutes = 0 }
end

function CCT.Advertise.Store()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" or CCT.Saved == nil or type(CCT.Saved.EnsureChar) ~= "function" then
        return nil
    end
    local char = CCT.Saved.EnsureChar(short)
    if type(char) ~= "table" then
        return nil
    end
    if type(char.advertise) ~= "table" then
        char.advertise = Blank()
    end
    local ad = char.advertise
    if ad.enabled == nil then
        ad.enabled = false
    end
    if type(ad.lines) ~= "table" then
        ad.lines = { "", "", "", "", "" }
    end
    for i = 1, LINE_COUNT do
        if type(ad.lines[i]) ~= "string" then
            ad.lines[i] = ""
        end
    end
    return ad
end

function CCT.Advertise.Lines()
    local ad = CCT.Advertise.Store()
    local lines = {}
    for i = 1, LINE_COUNT do
        lines[i] = ad and ad.lines[i] or ""
    end
    return lines
end

function CCT.Advertise.Enabled()
    local ad = CCT.Advertise.Store()
    return ad ~= nil and ad.enabled == true
end

function CCT.Advertise.SetEnabled(enabled)
    local ad = CCT.Advertise.Store()
    if ad == nil then
        return false
    end
    ad.enabled = enabled and true or false
    return true
end

function CCT.Advertise.SetLine(index, text)
    local ad = CCT.Advertise.Store()
    index = tonumber(index)
    if ad == nil or index == nil or index < 1 or index > LINE_COUNT then
        return false
    end
    ad.lines[index] = type(text) == "string" and text or ""
    return true
end

function CCT.Advertise.Parse(text)
    if type(text) ~= "string" then
        return nil
    end
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return nil
    end
    if trimmed:sub(1, 1) ~= "/" then
        return { chatType = "SAY", message = trimmed }
    end
    local command, rest = trimmed:match("^/(%S+)%s*(.*)$")
    if command == nil then
        return nil
    end
    local lower = command:lower()
    if lower == "y" or lower == "yell" then
        return { chatType = "YELL", message = rest }
    end
    if lower == "s" or lower == "say" then
        return { chatType = "SAY", message = rest }
    end
    if lower == "g" or lower == "guild" then
        return { chatType = "GUILD", message = rest }
    end
    if lower == "p" or lower == "party" then
        return { chatType = "PARTY", message = rest }
    end
    if lower == "ra" or lower == "raid" then
        return { chatType = "RAID", message = rest }
    end
    if lower == "rw" or lower == "raidwarning" then
        return { chatType = "RAID_WARNING", message = rest }
    end
    if lower == "i" or lower == "instance" then
        return { chatType = "INSTANCE_CHAT", message = rest }
    end
    if lower == "w" or lower == "whisper" or lower == "t" or lower == "tell" then
        local target, msg = rest:match("^(%S+)%s+(.+)$")
        if target == nil or msg == nil then
            return { error = "Whisper missing target" }
        end
        return { chatType = "WHISPER", message = msg, target = target }
    end
    if lower:match("^%d+$") then
        return { chatType = "CHANNEL", message = rest, channel = tonumber(lower) }
    end
    return { chatType = "SAY", message = rest ~= "" and rest or trimmed }
end

function CCT.Advertise.SendAll()
    if not CCT.Advertise.Enabled() then
        return 0
    end
    if CCT.Chat == nil or type(CCT.Chat.Send) ~= "function" then
        return 0
    end
    local lines = CCT.Advertise.Lines()
    local sent = 0
    for i = 1, #lines do
        local entry = CCT.Advertise.Parse(lines[i])
        if type(entry) == "table" and entry.error == nil and type(entry.message) == "string" and entry.message ~= "" then
            CCT.Chat.Send(entry.message, entry.chatType, nil, entry.target or entry.channel)
            sent = sent + 1
        end
    end
    return sent
end

function CCT.Advertise.SetTimer(minutes)
    local amount = tonumber(minutes) or 0
    local ad = CCT.Advertise.Store()
    if ad then
        ad.minutes = amount
    end
    if amount <= 0 then
        timerDueAt = nil
        return false
    end
    local now = CCT.Net and CCT.Net.Clock and CCT.Net.Clock() or CCT.UnixNow()
    timerDueAt = now + (amount * 60)
    return true
end

function CCT.Advertise.Tick(now)
    if timerDueAt == nil or (tonumber(now) or 0) < timerDueAt then
        return false
    end
    timerDueAt = nil
    if print then
        print(CCT.Advertise.TIMER_TEXT)
    end
    return true
end

local function Supports()
    if ready ~= nil then
        return ready
    end
    ready = false
    if type(CreateFrame) ~= "function" or UIParent == nil then
        return false
    end
    local probe = CreateFrame("Frame")
    if type(probe.SetClampedToScreen) ~= "function" then
        return false
    end
    local edit = CreateFrame("EditBox")
    if type(edit.SetText) ~= "function" or type(edit.GetText) ~= "function" then
        return false
    end
    ready = true
    return true
end

function CCT.Advertise.Open()
    if not Supports() then
        return nil
    end
    if window == nil then
        window = CreateFrame("Frame", "CatgirlAdvertiseFrame", UIParent)
        window:SetSize(360, 280)
        window:SetPoint("CENTER")
        window:SetClampedToScreen(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        window.boxes = {}
        for i = 1, LINE_COUNT do
            local box = CreateFrame("EditBox", nil, window)
            box:SetSize(320, 24)
            box:SetPoint("TOPLEFT", 16, -20 - ((i - 1) * 28))
            if box.SetAutoFocus then
                box:SetAutoFocus(false)
            end
            window.boxes[i] = box
        end
        window:Hide()
    end
    local lines = CCT.Advertise.Lines()
    for i = 1, LINE_COUNT do
        window.boxes[i]:SetText(lines[i] or "")
    end
    window:Show()
    return window
end

function CCT.Advertise.Toggle()
    if window and window.IsShown and window:IsShown() then
        window:Hide()
        return window
    end
    return CCT.Advertise.Open()
end

function CCT.Advertise.SaveFromWindow()
    if window == nil or type(window.boxes) ~= "table" then
        return false
    end
    for i = 1, LINE_COUNT do
        local box = window.boxes[i]
        if box and box.GetText then
            CCT.Advertise.SetLine(i, box:GetText() or "")
        end
    end
    return true
end
