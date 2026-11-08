-- Inn slacking. slackMin is written once, when a counting session ends.
-- A secret /sleep is not lowered and does not latch the session.
-- The in-progress session is memory only and does not survive reload.

local ADDON_NAME, CCT = ...

CCT.Slack = {}

local CITIES = {
    ["Orgrimmar"] = true,
    ["Stormwind City"] = true,
    ["Ironforge"] = true,
    ["Darnassus"] = true,
    ["Undercity"] = true,
    ["Thunder Bluff"] = true,
    ["Shattrath City"] = true,
    ["Silvermoon City"] = true,
    ["The Exodar"] = true,
}

local restingStart = nil
local counting = false
local suppressed = false
local lastSleep = nil

local function Enabled()
    if CCT.Module and type(CCT.Module.Enabled) == "function" then
        return CCT.Module.Enabled("InnSlackerTracker") == true
    end
    return true
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Clean(value)
    if Secret(value) then
        return nil
    end
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function ZoneText()
    local zone = nil
    if type(GetRealZoneText) == "function" then
        zone = Clean(GetRealZoneText())
    end
    if zone == nil and type(GetZoneText) == "function" then
        zone = Clean(GetZoneText())
    end
    return zone or ""
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

local function FlavorOn()
    local settings = CCT.db and CCT.db.settings
    return type(settings) == "table" and settings.flavorAnnouncements == true
end

local function Clear()
    restingStart = nil
    counting = false
    suppressed = false
end

local function EndSession(now)
    local wasCounting = counting
    local start = restingStart
    Clear()
    if not wasCounting or start == nil then
        return false
    end
    local after = (tonumber(now) or 0) - start - 600
    local minutes = math.floor(after / 60)
    if minutes < 0 then
        minutes = 0
    end
    if minutes > 0 and CCT.State and type(CCT.State.AddCounter) == "function" then
        CCT.State.AddCounter("slackMin", minutes)
    end
    if CCT.Ledger and type(CCT.Ledger.Flush) == "function" then
        CCT.Ledger.Flush("now", now)
    end
    return true
end

function CCT.Slack.Tick(now)
    if not Enabled() then
        return false
    end
    local stamp = tonumber(now)
    if stamp == nil and type(time) == "function" then
        stamp = time()
    end
    stamp = stamp or 0
    if CCT.Ledger and type(CCT.Ledger.EnsureWeek) == "function" then
        CCT.Ledger.EnsureWeek(stamp)
    end
    local resting = Resting()
    if resting == nil then
        return false
    end
    local city = CITIES[ZoneText()] == true
    if not resting or city then
        return EndSession(stamp)
    end
    if restingStart == nil then
        restingStart = stamp
        counting = false
        suppressed = false
        return false
    end
    if counting or suppressed or (stamp - restingStart) < 600 then
        return false
    end
    local recentSleep = lastSleep ~= nil and (stamp - lastSleep) < 1200
    if recentSleep then
        suppressed = true
        return false
    end
    counting = true
    if CCT.State and type(CCT.State.AddCounter) == "function" then
        CCT.State.AddCounter("slack", 1)
    end
    if FlavorOn() and CCT.Chat and type(CCT.Chat.Send) == "function" then
        if type(IsInGuild) ~= "function" or IsInGuild() then
            CCT.Chat.Send(CCT.Msg("INN_SLACKING"), "GUILD")
        end
    end
    return true
end

function CCT.Slack.Emote(msg, sender, now)
    if not Enabled() then
        return false
    end
    if Secret(msg) or type(msg) ~= "string" then
        return false
    end
    local short = CCT.Player and CCT.Player.short
    if short == nil or not CCT.SameName(sender, short) then
        return false
    end
    local lower = msg:lower()
    if not lower:find("fall asleep", 1, true) then
        return false
    end
    local stamp = tonumber(now)
    if stamp == nil and type(time) == "function" then
        stamp = time()
    end
    lastSleep = stamp or 0
    return true
end

function CCT.Slack.Session()
    return {
        restingStart = restingStart,
        counting = counting,
        suppressed = suppressed,
        lastSleep = lastSleep,
    }
end

function CCT.Slack.Reset()
    Clear()
    lastSleep = nil
end

function CCT.Slack.OnEvent(_, _, msg, sender)
    CCT.Slack.Emote(msg, sender, type(time) == "function" and time() or nil)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    frame:SetScript("OnEvent", CCT.Slack.OnEvent)
end

if C_Timer and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(10, function()
        CCT.Slack.Tick(type(time) == "function" and time() or nil)
    end)
end
