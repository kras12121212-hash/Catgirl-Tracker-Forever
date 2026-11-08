-- Optional stage on the one chat path. Default off.
-- Settings live on db.chars[short].nya. There is no second chat wrapper.
-- LooksLikeAddonCommand skips cctoy, ccdisc, leash, unleash, and the
-- flavor prefixes Your owner, Owner Forces, You hear a soft, With a gentle touch.
-- opts.raw on CCT.Chat.Send is the old unfiltered path.

local ADDON_NAME, CCT = ...

CCT.Nya = {}

local MAX_CHAT_BYTES = 255

local CHAT_TYPES = {
    SAY = true,
    YELL = true,
    EMOTE = true,
    PARTY = true,
    PARTY_LEADER = true,
    RAID = true,
    RAID_LEADER = true,
    RAID_WARNING = true,
    INSTANCE_CHAT = true,
    INSTANCE_CHAT_LEADER = true,
    GUILD = true,
    OFFICER = true,
    WHISPER = true,
    CHANNEL = true,
    BATTLEGROUND = true,
    BATTLEGROUND_LEADER = true,
}

local KAWAII = {
    "(=^-ω-^=)",
    "(* >ω<)",
    "UwU",
    "(=^w^=)",
    "~Nya~",
    "(=^ω^=)",
    "UwU~",
    "(*≧ω≦)",
    "(=^-^=)",
    ":3",
    "^_^",
    "owo",
    "~nya nya~",
}

local ACTIONS = {
    "*purrs*",
    "*nuzzles*",
    "*ears twitch*",
    "*tail flicks*",
    "*kneads paws*",
    "*headtilts*",
    "*soft mrrp*",
    "*wiggles*",
}

local KITTY = {
    yes = "nye",
    yeah = "nyaa",
    yup = "nya",
    no = "nyo",
    nope = "nyope",
    hi = "hai",
    hello = "hewwo",
    hey = "haii",
    please = "pwease",
    thanks = "thankies",
    thank = "thankie",
    you = "yuu",
    your = "yur",
    love = "wuv",
    cute = "kyute",
    really = "weally",
    little = "wittle",
    sorry = "sowwy",
    good = "gud",
    okay = "oki",
    ok = "oki",
    what = "wut",
    why = "wai",
    this = "dis",
    that = "dat",
    with = "wif",
    very = "vewy",
}

local DEFAULTS = {
    enabled = false,
    appendNya = true,
    cuteTilde = true,
    asciiEmotes = true,
    nyaSprinkle = false,
    uwuSpeak = false,
    kittyWords = false,
    stutter = false,
    sparklePunct = false,
    actionEmotes = false,
    softLowercase = false,
    trailingFace = false,
    chance = 50,
}

local function ClampChance(value)
    local n = tonumber(value) or DEFAULTS.chance
    if n < 10 then
        n = 10
    elseif n > 100 then
        n = 100
    end
    return math.floor(n + 0.5)
end

function CCT.Nya.GetDefaults()
    local copy = {}
    for option, value in pairs(DEFAULTS) do
        copy[option] = value
    end
    return copy
end

local function Stored()
    if not CCT.Player or not CCT.Player.ready or type(CCT.Player.short) ~= "string" then
        return nil
    end
    if not CCT.Saved or not CCT.Saved.EnsureChar then
        return nil
    end
    local char = CCT.Saved.EnsureChar(CCT.Player.short)
    if type(char) ~= "table" then
        return nil
    end
    if type(char.nya) ~= "table" then
        char.nya = {}
    end
    return char.nya
end

function CCT.Nya.GetSettings()
    local state = Stored()
    if not state then
        return CCT.Nya.GetDefaults()
    end
    for option, value in pairs(DEFAULTS) do
        if state[option] == nil then
            state[option] = value
        end
    end
    state.chance = ClampChance(state.chance)
    state.enabled = state.enabled and true or false
    return state
end

function CCT.Nya.Enabled()
    return CCT.Nya.GetSettings().enabled == true
end

function CCT.Nya.SetOption(option, value)
    if option == nil or DEFAULTS[option] == nil then
        return false
    end
    local state = Stored()
    if not state then
        return false
    end
    if option == "chance" then
        state.chance = ClampChance(value)
    elseif type(DEFAULTS[option]) == "boolean" then
        state[option] = value and true or false
    else
        state[option] = value
    end
    return true
end

local function Roll(chance, preview)
    if preview then
        return true
    end
    return (math.random() * 100) < (tonumber(chance) or 50)
end

local function Pick(list, preview, indexHint)
    if preview then
        return list[indexHint or 1] or list[1]
    end
    return list[math.random(#list)]
end

local function Truncate(msg)
    if type(msg) ~= "string" or #msg <= MAX_CHAT_BYTES then
        return msg
    end
    local cut = msg:sub(1, MAX_CHAT_BYTES)
    cut = cut:gsub("[\192-\255][\128-\191]*$", "")
    return cut
end

local function EndsWithNya(msg)
    return msg:lower():find("nya[~!%.%s]*$") ~= nil
end

local function EndsWithTilde(msg)
    return msg:find("~%s*$") ~= nil
end

local function MapOutsideLinks(text, fn)
    if type(text) ~= "string" or text == "" then
        return text
    end
    local result = {}
    local last = 1
    local pos = 1
    local len = #text
    while pos <= len do
        local startAt, endAt = text:find("|c%x+|H.-|h.-|h|r", pos)
        if not startAt then
            startAt, endAt = text:find("|H.-|h.-|h", pos)
        end
        if not startAt then
            result[#result + 1] = fn(text:sub(last))
            break
        end
        if startAt > last then
            result[#result + 1] = fn(text:sub(last, startAt - 1))
        end
        result[#result + 1] = text:sub(startAt, endAt)
        last = endAt + 1
        pos = endAt + 1
    end
    return table.concat(result)
end

local function ReplaceKitty(chunk)
    return chunk:gsub("(%a+)", function(word)
        local rep = KITTY[word:lower()]
        if not rep then
            return word
        end
        if word:match("^%u") and word:match("%l") then
            return rep:sub(1, 1):upper() .. rep:sub(2)
        end
        if word:match("^%u+$") then
            return rep:upper()
        end
        return rep
    end)
end

local function Uwuify(chunk)
    chunk = chunk:gsub("r", "w"):gsub("R", "W"):gsub("l", "w"):gsub("L", "W")
    chunk = chunk:gsub("n([aeiouAEIOU])", "ny%1")
    chunk = chunk:gsub("N([aeiouAEIOU])", "Ny%1")
    return chunk
end

local function SoftLower(chunk)
    if #chunk >= 4 and chunk:find("%u") and not chunk:find("%l") then
        return chunk:lower()
    end
    return chunk
end

local function Sparkle(chunk)
    chunk = chunk:gsub("!+", "!!")
    chunk = chunk:gsub("%?+", "?~")
    chunk = chunk:gsub("%.+", "~")
    return chunk
end

local function Stutter(chunk, preview, chance)
    if not Roll(chance, preview) then
        return chunk
    end
    return chunk:gsub("(%s*)(%a)", function(space, letter)
        return space .. letter:lower() .. "-" .. letter
    end, 1)
end

local function Sprinkle(chunk, preview, chance)
    local words = {}
    for word in chunk:gmatch("%S+") do
        words[#words + 1] = word
        if Roll(math.max(15, chance * 0.45), preview) then
            words[#words + 1] = "nya"
        end
    end
    if #words == 0 then
        return chunk
    end
    return table.concat(words, " ")
end

function CCT.Nya.LooksLikeAddonCommand(msg)
    if type(msg) ~= "string" or msg == "" then
        return true
    end
    local trimmed = msg:match("^%s*(.-)%s*$") or msg
    local lower = trimmed:lower()
    if lower:find("^cctoy%s") or lower:find("^ccdisc%s") then
        return true
    end
    if lower == "leash" or lower == "unleash" then
        return true
    end
    if trimmed:find("^Your owner") or trimmed:find("^Owner Forces") then
        return true
    end
    if trimmed:find("^You hear a soft") or trimmed:find("^With a gentle touch") then
        return true
    end
    return false
end

local function IsNyaType(chatType)
    if type(chatType) ~= "string" or chatType == "" then
        return false
    end
    return CHAT_TYPES[chatType:upper()] == true
end

local function ApplyText(msg, preview)
    if type(msg) ~= "string" or msg == "" then
        return msg
    end
    local state = CCT.Nya.GetSettings()
    if not preview and not state.enabled then
        return msg
    end

    local chance = ClampChance(state.chance)
    local text = msg

    if state.softLowercase then
        text = MapOutsideLinks(text, SoftLower)
    end
    if state.kittyWords then
        text = MapOutsideLinks(text, ReplaceKitty)
    end
    if state.uwuSpeak then
        text = MapOutsideLinks(text, Uwuify)
    end
    if state.stutter then
        text = MapOutsideLinks(text, function(chunk)
            return Stutter(chunk, preview, chance)
        end)
    end
    if state.nyaSprinkle then
        text = MapOutsideLinks(text, function(chunk)
            return Sprinkle(chunk, preview, chance)
        end)
    end
    if state.sparklePunct then
        text = MapOutsideLinks(text, Sparkle)
    end

    if state.actionEmotes and Roll(chance, preview) then
        local action = Pick(ACTIONS, preview, 1)
        if preview or math.random() < 0.5 then
            text = action .. " " .. text
        else
            text = text .. " " .. action
        end
    end

    if state.appendNya and not EndsWithNya(text) then
        if state.cuteTilde then
            text = text .. " nya~"
        else
            text = text .. " nya"
        end
    elseif state.cuteTilde and not EndsWithTilde(text) then
        text = text .. "~"
    end

    if state.trailingFace and Roll(chance, preview) then
        local faces = { " :3", " UwU", " ^_^", " <3" }
        text = text .. Pick(faces, preview, 1)
    end

    if state.asciiEmotes and Roll(math.max(25, chance), preview) then
        text = text .. " " .. Pick(KAWAII, preview, 1)
    end

    return Truncate(text)
end

function CCT.Nya.ApplyOutgoing(msg, chatType)
    if type(issecretvalue) == "function" and issecretvalue(msg) then
        return msg
    end
    if not CCT.Nya.Enabled() then
        return msg
    end
    if not IsNyaType(chatType) then
        return msg
    end
    if CCT.Nya.LooksLikeAddonCommand(msg) then
        return msg
    end
    return ApplyText(msg, false)
end

function CCT.Nya.Preview(sample)
    if sample == nil then
        sample = "Hello, I am going to the inn!"
    end
    return ApplyText(sample, true)
end
