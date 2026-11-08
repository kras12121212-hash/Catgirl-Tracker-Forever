-- Gag transforms and the inflatable drool timer.
-- The worn gag is CCT.State. This file does not keep a second copy.
-- A huge gag is one token, repeated 1 to 3 times. It is not a mix of tokens.
-- There is no chat-global wrapper here. CCT.Chat is the only send path.

local ADDON_NAME, CCT = ...

CCT.Gag = {}

local HUGE = { "mmf~", "mrrgghh~", "nnyaa-mmm!", "mmph!", "grrrgh~", "hnnnng~" }

local CUTE = {
    "(=^-ω-^=)", "(* >ω<)", "UwU", "⁄•⁄ω⁄•⁄ ⁄)", "(=^w^=)", "~Nya~",
    "(=^ω^=)", "UwU~", "(*≧ω≦)", "(=^-^=)", "~(=^・ω・^)", ":3", "^_^", "owo", "~nya nya~",
}

local SPEECH = {
    SAY = true,
    YELL = true,
    PARTY = true,
    PARTY_LEADER = true,
    RAID = true,
    RAID_LEADER = true,
    INSTANCE_CHAT = true,
    INSTANCE_CHAT_LEADER = true,
    GUILD = true,
    OFFICER = true,
}

local seen = false
local prevGag = "none"
local prevStage = 0
local ticker = nil
local tickerStage = nil

local function ChatKey(chatType)
    if type(chatType) ~= "string" then
        return nil
    end
    return chatType:upper()
end

local function Worn()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return "none", 0
    end
    return state.gag or "none", tonumber(state.gagStage) or 0
end

local function Light(msg)
    local repl = { s = "sh", r = "h", l = "w", b = "bh", t = "th", c = "k" }
    return msg:gsub(".", function(char)
        local lower = char:lower()
        local nextChar = repl[lower]
        if not nextChar then
            return char
        end
        if char:match("%u") then
            return nextChar:upper()
        end
        return nextChar
    end) .. " nya~"
end

local function Huge()
    local token = HUGE[math.random(#HUGE)]
    return string.rep(token .. " ", math.random(1, 3))
end

local function CuteNya(msg)
    local words = {}
    for word in msg:gmatch("%S+") do
        words[#words + 1] = word
        if math.random() < 0.3 then
            words[#words + 1] = "~Nya~"
        end
    end
    local joined = table.concat(words, " ")
    return joined:gsub("([%.%!%?])", function(punct)
        return punct .. " " .. CUTE[math.random(#CUTE)]
    end)
end

local function HeavyMff(text)
    return text:gsub("%S+", function()
        return "m" .. ("f"):rep(math.random(2, 4)) .. "~"
    end)
end

local function Inflatable(msg, stage)
    if stage <= 1 then
        if math.random() < 0.3 then
            return msg .. " mmf~"
        end
        return msg
    end
    if stage == 2 then
        return Light(msg)
    end
    if stage == 3 then
        local words = {}
        for word in msg:gmatch("%S+") do
            if math.random() < 0.4 then
                words[#words + 1] = "mmf~"
            else
                words[#words + 1] = word
            end
        end
        return Light(table.concat(words, " "))
    end
    if stage == 4 then
        return HeavyMff(msg)
    end
    return string.rep("mmmm~ ", math.random(3, 6))
end

function CCT.Gag.ApplyOutgoing(msg, chatType)
    if type(issecretvalue) == "function" and issecretvalue(msg) then
        return msg, false
    end
    if type(msg) ~= "string" then
        return msg, false
    end
    local key = ChatKey(chatType)
    if not key or not SPEECH[key] then
        return msg, false
    end

    local gag, stage = Worn()
    if gag == "full" then
        if print then
            print("|cffff0000CatgirlTracker:|r Your mask prevents you from speaking at all!")
        end
        return nil, true
    end
    if gag == "none" then
        return msg, false
    end
    if gag == "huge" then
        return Huge(), false
    end
    if gag == "small" then
        return Light(msg), false
    end
    if gag == "nyamask" then
        return CuteNya(msg), false
    end
    if gag == "inflatable" then
        if stage < 1 then
            stage = 1
        end
        return Inflatable(msg, stage), false
    end
    return msg, false
end

function CCT.Gag.Set(value, stage)
    if not CCT.State or not CCT.State.SetGag then
        return false
    end
    return CCT.State.SetGag(value, stage) == true
end

local function StopDrool()
    if ticker and ticker.Cancel then
        ticker:Cancel()
    end
    ticker = nil
    tickerStage = nil
end

local function StartDrool(stage)
    if ticker and tickerStage == stage then
        return
    end
    StopDrool()
    if stage < 1 or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    local interval = math.max(2, 7 - stage) * 60
    tickerStage = stage
    ticker = C_Timer.NewTicker(interval, function()
        local gag, nowStage = Worn()
        if gag ~= "inflatable" or nowStage < 1 then
            StopDrool()
            return
        end
        if type(DoEmote) == "function" then
            pcall(DoEmote, "DROOL")
        end
    end)
end

local function PlayStage(dir)
    local sounds = CCT.Sounds
    if type(sounds) ~= "table" or type(sounds.PlayToyInflateDeflate) ~= "function" then
        return
    end
    sounds.PlayToyInflateDeflate("inflatable_gag", dir)
end

local function Sync()
    local gag, stage = Worn()
    if seen and gag == "inflatable" and (prevGag ~= "inflatable" or stage ~= prevStage) then
        if prevGag == "inflatable" and stage < prevStage then
            PlayStage("deflate")
        else
            PlayStage("inflate")
        end
    end
    if gag == "inflatable" and stage >= 1 then
        StartDrool(stage)
    else
        StopDrool()
    end
    prevGag = gag
    prevStage = stage
    seen = true
end

function CCT.Gag.OnEvent(_, event, arg1)
    if event == "UNIT_NAME_UPDATE" and arg1 ~= "player" then
        return
    end
    Sync()
end

if CCT.State and CCT.State.Listen then
    CCT.State.Listen(Sync)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    frame:SetScript("OnEvent", CCT.Gag.OnEvent)
end
