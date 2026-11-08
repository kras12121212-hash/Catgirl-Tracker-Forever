-- Naps. Movement comes from CCT.Move.Sample. A hidden sample does not end a nap.
-- The sleep emote calls issecretvalue before lower. Wire results are napOk,
-- napEarly, napOver, and napMiss. The window is memory only.

local ADDON_NAME, CCT = ...

CCT.Nap = {}

local NOTICE = "Good Kittens need to Nap Nya! Find a Inn to nap for 10 to 20 Minutes"
local WINDOW = 1800

local onlineTime = 0
local trigger = 7200
local inWindow = false
local deadline = nil
local active = false
local startAt = nil
local lastNow = nil

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local NAP_LOW, NAP_HIGH = 7200, 18000

local function RollTrigger()
    local n = math.random(NAP_LOW, NAP_HIGH)
    n = tonumber(n) or NAP_LOW
    if n < 7200 then
        n = 7200
    end
    if n > 18000 then
        n = 18000
    end
    return math.floor(n)
end

trigger = RollTrigger()

local function FlavorOn()
    local settings = CCT.db and CCT.db.settings
    return type(settings) == "table" and settings.flavorAnnouncements == true
end

local function Resting()
    if type(IsResting) ~= "function" then
        return nil
    end
    local value = IsResting()
    if Secret(value) then
        return nil
    end
    if value == true or value == false then
        return value
    end
    return nil
end

local function Announce(key)
    if not FlavorOn() or CCT.Chat == nil or type(CCT.Chat.Send) ~= "function" then
        return
    end
    if type(IsInGuild) ~= "function" or IsInGuild() then
        CCT.Chat.Send(CCT.Msg(key), "GUILD")
    end
end

local function RaidNotice()
    CCT.Nap.LastNotice = NOTICE
    if type(RaidNotice_AddMessage) ~= "function" or RaidWarningFrame == nil then
        return
    end
    if type(ChatTypeInfo) ~= "table" or ChatTypeInfo.RAID_WARNING == nil then
        return
    end
    RaidNotice_AddMessage(RaidWarningFrame, NOTICE, ChatTypeInfo.RAID_WARNING)
end

local function Open(now)
    inWindow = true
    deadline = now + WINDOW
    active = false
    startAt = nil
    RaidNotice()
end

local FLAVOR = {
    napOk = "NAP_SLEPT_AS_TOLD",
    napEarly = "NAP_WOKE_EARLY",
    napOver = "NAP_OVERSLEPT",
    napMiss = "NAP_DID_NOT_SLEEP",
}

local function Resolve(result, now)
    active = false
    inWindow = false
    startAt = nil
    deadline = nil
    onlineTime = 0
    trigger = RollTrigger()
    lastNow = now
    if CCT.Ledger and type(CCT.Ledger.EnsureWeek) == "function" then
        CCT.Ledger.EnsureWeek(now)
    end
    if CCT.State and type(CCT.State.AddCounter) == "function" then
        CCT.State.AddCounter(result, 1)
    end
    Announce(FLAVOR[result])
    if CCT.Ledger and type(CCT.Ledger.Flush) == "function" then
        CCT.Ledger.Flush("now", now)
    end
    return true
end

local function Score(duration)
    if duration > 1200 then
        return "napOver"
    end
    if duration < 600 then
        return "napEarly"
    end
    return "napOk"
end

function CCT.Nap.SetTrigger(seconds)
    local n = tonumber(seconds)
    if n == nil or n < 1 then
        return false
    end
    trigger = math.floor(n)
    return true
end

function CCT.Nap.Reset(now)
    onlineTime = 0
    trigger = RollTrigger()
    inWindow = false
    deadline = nil
    active = false
    startAt = nil
    lastNow = tonumber(now)
    CCT.Nap.LastNotice = nil
end

function CCT.Nap.Status()
    return {
        onlineTime = onlineTime,
        trigger = trigger,
        inWindow = inWindow,
        active = active,
        startAt = startAt,
        deadline = deadline,
    }
end

function CCT.Nap.OnZone(now)
    if not active or startAt == nil then
        return false
    end
    local stamp = tonumber(now) or startAt
    return Resolve(Score(stamp - startAt), stamp)
end

function CCT.Nap.Emote(msg, sender, now)
    if Secret(msg) or type(msg) ~= "string" then
        return false
    end
    local short = CCT.Player and CCT.Player.short
    if short == nil or not CCT.SameName(sender, short) then
        return false
    end
    local lower = msg:lower()
    if not lower:find("you fall asleep", 1, true) then
        return false
    end
    if not inWindow or active then
        return false
    end
    if Resting() ~= true then
        return false
    end
    local stamp = tonumber(now)
    if stamp == nil and type(time) == "function" then
        stamp = time()
    end
    startAt = stamp or 0
    active = true
    return true
end

function CCT.Nap.Tick(now)
    local stamp = tonumber(now)
    if stamp == nil and type(time) == "function" then
        stamp = time()
    end
    stamp = stamp or 0
    if lastNow == nil then
        lastNow = stamp
        return false
    end
    local delta = stamp - lastNow
    if delta < 0 then
        delta = 0
    end
    lastNow = stamp
    onlineTime = onlineTime + delta
    if not inWindow and onlineTime >= trigger then
        Open(stamp)
    end
    if active and startAt ~= nil then
        local duration = stamp - startAt
        if duration > 1200 then
            return Resolve("napOver", stamp)
        end
        local sample = { kind = "hidden" }
        if CCT.Move and type(CCT.Move.Sample) == "function" then
            sample = CCT.Move.Sample() or sample
        end
        local moved = (sample.kind == "speed" or sample.kind == "bool") and sample.moving == true
        if moved or Resting() == false then
            return Resolve(Score(duration), stamp)
        end
        return false
    end
    if inWindow and not active and deadline ~= nil and stamp >= deadline then
        return Resolve("napMiss", stamp)
    end
    return false
end

function CCT.Nap.OnEvent(_, _, msg, sender)
    CCT.Nap.Emote(msg, sender, type(time) == "function" and time() or nil)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    frame:SetScript("OnEvent", CCT.Nap.OnEvent)
end

if C_Timer and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(1, function()
        CCT.Nap.Tick(type(time) == "function" and time() or nil)
    end)
end
