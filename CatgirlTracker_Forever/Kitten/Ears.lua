-- Incoming say, yell, party, raid, and guild filter.
-- issecretvalue runs before any string use. A secret is returned untouched.
-- Garbling requires an owner. A non-owner cannot write the earmuff state.

local ADDON_NAME, CCT = ...

CCT.Ears = {}

local EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_GUILD",
}

local NYAS = { "nya~", "nyan~", "*nya*", "<3 nya" }
local installed = false

local function Worn()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return "none"
    end
    return state.ears or "none"
end

local function OwnerShort()
    if not CCT.Roster or not CCT.Roster.GetOwnerShort then
        return nil
    end
    return CCT.Roster.GetOwnerShort()
end

local function GarbleKitten(msg)
    local words = {}
    for word in msg:gmatch("%S+") do
        words[#words + 1] = word
        if math.random() < 0.5 then
            words[#words + 1] = NYAS[math.random(#NYAS)]
        end
    end
    return table.concat(words, " ")
end

local function GarbleHeavy(msg)
    return msg:gsub(".", function()
        if math.random(0, 1) == 1 then
            return "*"
        end
        return "~"
    end)
end

function CCT.Ears.Filter(msg, ...)
    if type(issecretvalue) == "function" and issecretvalue(msg) then
        return false, msg, ...
    end
    if OwnerShort() == nil then
        return
    end
    if type(msg) ~= "string" then
        return
    end

    local ears = Worn()
    if ears == "kitten" then
        return false, GarbleKitten(msg), ...
    end
    if ears == "heavy" then
        return false, GarbleHeavy(msg), ...
    end
end

function CCT.Ears.Set(sender, value)
    if OwnerShort() == nil or not CCT.SameName(sender, OwnerShort()) then
        return false
    end
    if value ~= "none" and value ~= "kitten" and value ~= "heavy" then
        return false
    end
    if not CCT.State or not CCT.State.SetEars then
        return false
    end
    return CCT.State.SetEars(value) == true
end

function CCT.Ears.Install()
    if installed or type(ChatFrame_AddMessageEventFilter) ~= "function" then
        return
    end
    installed = true
    for i = 1, #EVENTS do
        ChatFrame_AddMessageEventFilter(EVENTS[i], function(_, _, msg, ...)
            return CCT.Ears.Filter(msg, ...)
        end)
    end
end

function CCT.Ears.OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        CCT.Ears.Install()
    end
end

if type(ChatFrame_AddMessageEventFilter) == "function" then
    CCT.Ears.Install()
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", CCT.Ears.OnEvent)
end
