-- Headpets, hugs, kisses, spanks, and ear pinches.
-- One count per sender per action per 60 seconds. The week keeps 20 pairs.
-- Flavor lines are not ledger input. A secret emote is not lowered.

local ADDON_NAME, CCT = ...

CCT.Headpet = {}

local COOLDOWN = 60
local MATCHES = {
    { text = "pets you", counter = "pets", flavor = "HEADPET_GOOD", word = "Headpet" },
    { text = "hugs you", counter = "hugs", flavor = "HEADPET_GOOD", word = "Hug" },
    { text = "blows you a kiss", counter = "kisses", flavor = "HEADPET_GOOD", word = "kiss" },
    { text = "spanks you", counter = "spanks", flavor = "HEADPET_SPANKED" },
    { text = "pinches your ear", counter = "earPinch", flavor = "HEADPET_EARPINCH" },
}

local recent = {}

local function Enabled()
    if CCT.Module and type(CCT.Module.Enabled) == "function" then
        return CCT.Module.Enabled("HeadPetTracker") == true
    end
    return true
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function FlavorOn()
    local settings = CCT.db and CCT.db.settings
    return type(settings) == "table" and settings.flavorAnnouncements == true
end

local function GroupChannel()
    if type(IsInRaid) == "function" and IsInRaid() then
        return "RAID"
    end
    if type(IsInGroup) == "function" and IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function Announce(text)
    if not FlavorOn() or type(text) ~= "string" or text == "" then
        return
    end
    if CCT.Chat == nil or type(CCT.Chat.Send) ~= "function" then
        return
    end
    if type(IsInGuild) ~= "function" or IsInGuild() then
        CCT.Chat.Send(text, "GUILD", nil, nil, { raw = true })
    end
    local channel = GroupChannel()
    if channel ~= nil then
        CCT.Chat.Send(text, channel, nil, nil, { raw = true })
    end
end

function CCT.Headpet.Emote(msg, sender, now)
    if not Enabled() then
        return false
    end
    if Secret(msg) or type(msg) ~= "string" then
        return false
    end
    local lower = msg:lower()
    local found = nil
    for i = 1, #MATCHES do
        if lower:find(MATCHES[i].text, 1, true) then
            found = MATCHES[i]
            break
        end
    end
    if found == nil then
        return false
    end
    local short = CCT.ShortName(sender) or sender
    if type(short) ~= "string" or short == "" then
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
    local key = found.counter .. "\0" .. short:lower()
    local seen = recent[key]
    if seen ~= nil and (stamp - seen) < COOLDOWN then
        return false
    end
    recent[key] = stamp
    if CCT.State and type(CCT.State.AddCounter) == "function" then
        CCT.State.AddCounter(found.counter, 1)
    end
    if CCT.Ledger and type(CCT.Ledger.PushSender) == "function" then
        CCT.Ledger.PushSender(found.counter .. ":" .. short)
    end
    local line
    if found.flavor == "HEADPET_GOOD" then
        line = CCT.Msg(found.flavor, found.word, short)
    else
        line = CCT.Msg(found.flavor, short)
    end
    Announce(line)
    return true
end

function CCT.Headpet.OnEvent(_, _, msg, sender)
    CCT.Headpet.Emote(msg, sender, type(time) == "function" and time() or nil)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    frame:RegisterEvent("CHAT_MSG_EMOTE")
    frame:SetScript("OnEvent", CCT.Headpet.OnEvent)
end
