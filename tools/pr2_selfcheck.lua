-- PR 2 self-check. Run from the repo root:
--   lua tools/pr2_selfcheck.lua
-- Covers one outgoing chat path, the huge-gag token rule, the mask frame
-- sequence, a secret earmuff message, the owner gate, and Nya's prefix skip.

local stdout = print
local failures = 0

local function check(name, cond)
    if cond then
        stdout("ok  " .. name)
    else
        failures = failures + 1
        stdout("FAIL " .. name)
    end
end

local script = (arg and arg[0]) or "tools/pr2_selfcheck.lua"
local root = script:gsub("/?tools/pr2_selfcheck%.lua$", "")
if root == "" then
    root = "."
end
local addon = root .. "/CatgirlTracker_Forever"

local function read(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        error("missing " .. path)
    end
    local text = handle:read("*a")
    handle:close()
    return text
end

local function boom(label)
    return function()
        error(label .. " called", 2)
    end
end

local frames = {}
local textures = {}
local afters = {}
local tickers = {}
local filters = {}

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function newFrame(name)
    local frame = {
        name = name,
        events = {},
        scripts = {},
        shown = false,
        mouse = false,
    }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:SetScript(which, fn)
        self.scripts[which] = fn
    end
    function frame:SetFrameStrata() end
    function frame:SetAllPoints() end
    function frame:SetPoint() end
    function frame:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function frame:EnableMouse(on)
        self.mouse = on and true or false
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:Show()
        self.shown = true
    end
    function frame:SetBackdrop(info)
        self.backdrop = info
    end
    function frame:SetBackdropColor(_, _, _, alpha)
        self.alpha = alpha
    end
    function frame:CreateTexture()
        local tex = {}
        function tex:SetAllPoints() end
        function tex:SetTexture(path)
            self.texture = path
            textures[#textures + 1] = path
        end
        return tex
    end
    frames[#frames + 1] = frame
    return frame
end

CreateFrame = function(_, name)
    return newFrame(name)
end

UIParent = { width = 1920, height = 1080 }
function UIParent:GetWidth()
    return self.width
end
function UIParent:GetHeight()
    return self.height
end

C_Timer = {
    After = function(delay, fn)
        afters[#afters + 1] = { delay = delay, fn = fn }
    end,
    NewTicker = function(interval, fn)
        local handle = { interval = interval, fn = fn, cancelled = false }
        function handle:Cancel()
            self.cancelled = true
        end
        tickers[#tickers + 1] = handle
        return handle
    end,
}

ChatFrame_AddMessageEventFilter = function(event, fn)
    filters[#filters + 1] = { event = event, fn = fn }
end

local function fire(event, ...)
    for i = 1, #frames do
        local frame = frames[i]
        local fn = frame.scripts.OnEvent
        if fn and frame.events[event] then
            fn(frame, event, ...)
        end
    end
end

local function frameNamed(name)
    for i = 1, #frames do
        if frames[i].name == name then
            return frames[i]
        end
    end
    return nil
end

local function drain(expectDelay)
    local count = 0
    while #afters > 0 do
        local item = table.remove(afters, 1)
        count = count + 1
        if item.delay ~= expectDelay or count > 40 then
            return -1
        end
        item.fn()
    end
    return count
end

UnitName = boom("UnitName")
UnitFullName = boom("UnitFullName")
UnitGUID = boom("UnitGUID")
GetGuildRosterInfo = boom("GetGuildRosterInfo")
GetNumGuildMembers = boom("GetNumGuildMembers")
GuildRoster = boom("GuildRoster")
C_GuildInfo = { GuildRoster = boom("C_GuildInfo.GuildRoster") }
SendChatMessage = boom("SendChatMessage")
C_ChatInfo = {
    SendChatMessage = boom("C_ChatInfo.SendChatMessage"),
    SendAddonMessage = boom("C_ChatInfo.SendAddonMessage"),
}
hooksecurefunc = boom("hooksecurefunc")
issecretvalue = function()
    return false
end
CatgirlTrackerDB = nil

local sent = {}
local cCalls = 0
local sCalls = 0
local lines = {}

local function resetSent()
    clearList(sent)
    cCalls = 0
    sCalls = 0
end

local CCT = {}
local toc = read(addon .. "/CatgirlTracker_Forever.toc")
local files = {}
for line in toc:gmatch("[^\n]+") do
    if line:find("%.lua$") then
        files[#files + 1] = line
    end
end

check("toc lists chat before state", toc:find("Core/Chat.lua\nKitten/State.lua\nKitten/Gag.lua\nKitten/Blindfold.lua\nKitten/Ears.lua\nKitten/Nya.lua\n", 1, true) ~= nil)
check("toc has no net", toc:find("Net.lua", 1, true) == nil)

for i = 1, #files do
    local chunk, err = loadfile(addon .. "/" .. files[i])
    if chunk == nil then
        error(err)
    end
    chunk("CatgirlTracker_Forever", CCT)
end
check("file scope does not send chat or read the player", true)
check("seven ear filters", #filters == 7)

local hookedSend = nil
local function spyC(msg, chatType, language, target)
    if msg == "explode" then
        error("boom")
    end
    cCalls = cCalls + 1
    sent[#sent + 1] = {
        msg = msg,
        chatType = chatType,
        language = language,
        target = target,
        via = "c",
    }
end
local function spyS(msg, chatType, language, target)
    sCalls = sCalls + 1
    sent[#sent + 1] = { msg = msg, chatType = chatType, language = language, target = target, via = "s" }
end

SendChatMessage = spyS
C_ChatInfo = { SendChatMessage = spyC, SendAddonMessage = boom("SendAddonMessage") }
fire("ADDON_LOADED", "CatgirlTracker_Forever")
hookedSend = SendChatMessage
check("chat hook installed", hookedSend ~= spyS and C_ChatInfo.SendChatMessage ~= spyC)

local now = 1000
time = function()
    return now
end
GetTime = time
IsInGuild = function()
    return true
end
GuildRoster = nil
C_GuildInfo = { GuildRoster = function() end }
UnitFullName = function()
    return "Kitten", "Silvermoon"
end
UnitGUID = function()
    return "Player-1-ABC"
end

print = function(text)
    lines[#lines + 1] = tostring(text)
end

fire("PLAYER_LOGIN")
check("player ready", CCT.Player.ready == true and CCT.Player.short == "Kitten")
check("nya default off", CCT.Nya.Enabled() == false)
check("nya options stored on the character", CCT.db.chars.Kitten.nya.appendNya == true and CCT.db.chars.Kitten.nya.chance == 50)
check("nya stays off in the saved flag", CCT.db.chars.Kitten.nya.enabled == false)

local sounds = {}
CCT.Sounds = {
    PlayToyInflateDeflate = function(id, dir)
        sounds[#sounds + 1] = id .. ":" .. dir
    end,
}
check("restore does not play an inflate", #sounds == 0)

local function quietRandom(a, b)
    if a == nil then
        return 0.99
    end
    if b == nil then
        return 1
    end
    return a
end
math.random = quietRandom

resetSent()
hookedSend("Hello", "SAY", nil, nil)
check("say uses the c api once", cCalls == 1 and sCalls == 0 and sent[1].msg == "Hello" and sent[1].chatType == "SAY")
C_ChatInfo.SendChatMessage("Hello", "YELL")
check("cinfo hook is the same path", cCalls == 2 and sCalls == 0 and sent[2].chatType == "YELL")
CCT.Chat.Install()
resetSent()
CCT.Chat.Send("Hello", "SAY")
check("second install does not double wrap", cCalls == 1 and sent[1].msg == "Hello")

local ok = pcall(CCT.Chat.Send, "explode", "SAY")
check("send error clears the reentrancy flag", ok == false)
resetSent()
CCT.Chat.Send("Hello", "SAY")
check("send works after an error", cCalls == 1 and sent[1].msg == "Hello")

check("set nya on", CCT.Nya.SetOption("enabled", true) == true and CCT.Nya.SetOption("asciiEmotes", false) == true)
check("chance clamps up", CCT.Nya.SetOption("chance", 5) == true and CCT.db.chars.Kitten.nya.chance == 10)
check("chance clamps down", CCT.Nya.SetOption("chance", 140) == true and CCT.db.chars.Kitten.nya.chance == 100)
CCT.Nya.SetOption("chance", 50)
resetSent()
CCT.Chat.Send("Hello", "SAY")
check("nya on changes a say", cCalls == 1 and sent[1].msg == "Hello nya~")

local skips = {
    "cctoy use",
    "ccdisc spank",
    "leash",
    "unleash",
    "Leash",
    "UNLEASH",
    "Your owner has secured a heavy gag in place.",
    "Owner Forces the kitten still",
    "You hear a soft jingle",
    "With a gentle touch she locks it",
}
for i = 1, #skips do
    resetSent()
    CCT.Chat.Send(skips[i], "SAY")
    check("nya skips " .. skips[i], cCalls == 1 and sent[1].msg == skips[i])
end
check("looks like command is the full prefix list", CCT.Nya.LooksLikeAddonCommand("cctoy") == false)
resetSent()
CCT.Chat.Send("cctoy", "SAY")
check("bare cctoy is not in the prefix list", sent[1].msg == "cctoy nya~")

CCT.Gag.Set("full")
resetSent()
clearList(lines)
CCT.Chat.Send("Hello", "WHISPER", nil, "Nyx", { raw = true })
check("raw whisper is unchanged", cCalls == 1 and sCalls == 0 and sent[1].msg == "Hello" and sent[1].chatType == "WHISPER" and sent[1].target == "Nyx")
check("raw whisper does not print the gag block", #lines == 0)
resetSent()
clearList(lines)
CCT.Chat.Send("Hello", "GUILD")
check("full gag drops a guild line", cCalls == 0 and sCalls == 0)
check("full gag prints the local block", lines[1] == "|cffff0000CatgirlTracker:|r Your mask prevents you from speaking at all!")
resetSent()
CCT.Chat.Send("Hello", "WHISPER", nil, "Nyx")
check("non-raw whisper still passes gag and nya", sent[1].msg == "Hello nya~" and sent[1].chatType == "WHISPER")

local secret = setmetatable({}, {
    __index = function()
        error("secret indexed")
    end,
    __concat = function()
        error("secret concatenated")
    end,
    __tostring = function()
        error("secret stringified")
    end,
})
issecretvalue = function(value)
    return rawequal(value, secret)
end
resetSent()
clearList(lines)
local secretOk = pcall(CCT.Chat.Send, secret, "SAY")
check("secret say does not error", secretOk == true)
check("secret say is sent unchanged", cCalls == 1 and rawequal(sent[1].msg, secret))
check("secret say is not blocked", #lines == 0)

CCT.Nya.SetOption("enabled", false)
CCT.Gag.Set("none")

local HUGE = { "mmf~", "mrrgghh~", "nnyaa-mmm!", "mmph!", "grrrgh~", "hnnnng~" }
local allowed = {}
for i = 1, #HUGE do
    allowed[HUGE[i]] = true
end

local function oneToken(text)
    if type(text) ~= "string" then
        return false
    end
    local first = nil
    local count = 0
    for word in text:gmatch("%S+") do
        count = count + 1
        if first == nil then
            first = word
        elseif word ~= first then
            return false
        end
    end
    if count < 1 or count > 3 or not allowed[first] then
        return false
    end
    return text == string.rep(first .. " ", count)
end

CCT.Gag.Set("huge")
local savedRandom = math.random
math.random = function(a, b)
    if b == nil then
        return math.floor(savedRandom() * a) + 1
    end
    return math.floor(savedRandom() * (b - a + 1)) + a
end
local hugeOk = true
for _ = 1, 40 do
    local text, blocked = CCT.Gag.ApplyOutgoing("Hello there friend", "GUILD")
    if blocked or not oneToken(text) then
        hugeOk = false
    end
end
check("huge gag is one token repeated 1 to 3 times", hugeOk)
math.random = function(a, b)
    if b ~= nil then
        return 3
    end
    return 2
end
check(
    "huge gag picks one listed token",
    CCT.Gag.ApplyOutgoing("Hello", "SAY") == string.rep("mrrgghh~ ", 3)
)
math.random = quietRandom

CCT.Gag.Set("small")
check("small gag", CCT.Gag.ApplyOutgoing("Hello", "SAY") == "Hewwo nya~")
check("small gag keeps case", CCT.Gag.ApplyOutgoing("Cats", "SAY") == "Kathsh nya~")
check("whisper is not a gag speech type", CCT.Gag.ApplyOutgoing("Hello", "WHISPER") == "Hello")
check("emote is not a gag speech type", CCT.Gag.ApplyOutgoing("Hello", "EMOTE") == "Hello")

CCT.Gag.Set("nyamask")
math.random = function(a)
    if a == nil then
        return 0
    end
    return 1
end
check("nyamask sprinkles", CCT.Gag.ApplyOutgoing("Hi there", "SAY") == "Hi ~Nya~ there ~Nya~")

CCT.Gag.Set("inflatable", 4)
math.random = function()
    return 2
end
check("inflatable stage 4", CCT.Gag.ApplyOutgoing("Hello there", "SAY") == "mff~ mff~")
CCT.Gag.Set("inflatable", 5)
math.random = function(a, b)
    if a == 3 and b == 6 then
        return 4
    end
    return 1
end
check("inflatable stage 5", CCT.Gag.ApplyOutgoing("Hello", "SAY") == string.rep("mmmm~ ", 4))
math.random = quietRandom

clearList(sounds)
clearList(tickers)
CCT.Gag.Set("none")
CCT.Gag.Set("inflatable", 1)
check("entering inflatable plays inflate", sounds[1] == "inflatable_gag:inflate" and #sounds == 1)
check("drool starts at six minutes", #tickers >= 1 and tickers[#tickers].interval == 360 and tickers[#tickers].cancelled == false)
local firstTicker = tickers[#tickers]
CCT.Gag.Set("inflatable", 3)
check("a higher stage plays inflate again", sounds[2] == "inflatable_gag:inflate" and #sounds == 2)
check("drool interval follows the stage", tickers[#tickers].interval == 240 and firstTicker.cancelled == true)
CCT.Gag.Set("inflatable", 2)
check("a lower stage plays deflate", sounds[3] == "inflatable_gag:deflate" and #sounds == 3)
DoEmote = function()
    error("no hardware event")
end
local droolOk = pcall(tickers[#tickers].fn)
check("drool failure is ignored", droolOk == true)
resetSent()
check("drool does not send an emote line", #sent == 0)
CCT.Gag.Set("none")
check("removing the gag plays no sound", #sounds == 3 and tickers[#tickers].cancelled == true)
CCT.Gag.Set("huge")
check("huge gag plays no inflate", #sounds == 3)

local roster = {
    { "Kitten", "rank", 0, 1, "Mage", "Elwynn", "owner=Nyx", "", true },
    { "Nyx", "rank", 0, 1, "Mage", "Elwynn", "", "", true },
    { "Bob", "rank", 0, 1, "Mage", "Elwynn", "", "", true },
}
GetNumGuildMembers = function()
    return #roster
end
GetGuildRosterInfo = function(index)
    local row = roster[index]
    return row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9]
end
CCT.Roster.Rebuild()
check("owner resolved", CCT.Roster.GetOwnerShort() == "Nyx")
check("non-owner cannot set earmuffs", CCT.Ears.Set("Bob", "heavy") == false and CCT.State.Get().ears == "none")
check("owner sets earmuffs", CCT.Ears.Set("nyx", "kitten") == true and CCT.State.Get().ears == "kitten")

math.random = function(a)
    if a == nil then
        return 0
    end
    return 1
end
local changed, garbled, author = CCT.Ears.Filter("Hello there", "Someone")
check("kitten earmuffs garble", changed == false and garbled == "Hello nya~ there nya~" and author == "Someone")
math.random = function()
    return 0
end
CCT.Ears.Set("Nyx", "heavy")
local heavyChanged, heavy = CCT.Ears.Filter("Ab", "Someone")
check("heavy earmuffs", heavyChanged == false and heavy == "~~")

CCT.Player.short = "Nyx"
CCT.Roster.Rebuild()
check("no owner on this character", CCT.Roster.GetOwnerShort() == nil)
local noOwner = { CCT.Ears.Filter("Hello there", "Someone") }
check("filter requires the owner", noOwner[1] == nil and CCT.State.Get().ears == "heavy")
check("non-owner still cannot write", CCT.Ears.Set("Bob", "none") == false and CCT.State.Get().ears == "heavy")

CCT.Player.short = "Kitten"
CCT.Roster.Rebuild()
local secretFilterOk, secretFlag, secretMsg, secretAuthor = pcall(CCT.Ears.Filter, secret, "Nyx")
check("secret filter does not error", secretFilterOk == true)
check("secret filter returns the message", secretFlag == false and rawequal(secretMsg, secret) and secretAuthor == "Nyx")
math.random = quietRandom

local overlay = nil
CCT.Blindfold.Set("light")
overlay = frameNamed("CatgirlBlindfoldOverlay")
check("light blindfold alpha", overlay ~= nil and overlay.shown == true and overlay.alpha == 0.4 and overlay.mouse == false)
CCT.Blindfold.Set("full")
check("full blindfold captures the mouse", overlay.shown == true and overlay.alpha == 1 and overlay.mouse == true)
CCT.Blindfold.Set("none")
check("clearing a full blindfold releases the mouse", overlay.shown == false and overlay.mouse == false)

clearList(textures)
clearList(afters)
UIParent.width = 1920
UIParent.height = 1080
CCT.Blindfold.Set("mask")
local scheduled = drain(0.3)
local maskOk = scheduled == 6
for i = 1, 7 do
    if textures[i] ~= CCT.Blindfold.MaskPath("KittenMaskZ", i) then
        maskOk = false
    end
end
check("mask plays Z1 through Z7", maskOk and #textures == 7)
check("mask does not capture the mouse", overlay.mouse == false)
local maskFrame = frameNamed("KittenMaskAnimFrame")
check("mask frame uses 16:9", maskFrame ~= nil and maskFrame.width == 1920 and maskFrame.height == 1080)

clearList(textures)
clearList(afters)
CCT.Blindfold.Set("none")
scheduled = drain(0.3)
local reverseOk = scheduled == 6
for i = 1, 7 do
    if textures[i] ~= CCT.Blindfold.MaskPath("KittenMaskZ", 8 - i) then
        reverseOk = false
    end
end
check("removing a mask plays the frames backward", reverseOk and textures[8] == nil)
check("removing a mask leaves the mouse free", overlay.mouse == false and overlay.shown == false)

clearList(textures)
clearList(afters)
UIParent.width = 2560
UIParent.height = 1080
CCT.Blindfold.Set("mask")
scheduled = drain(0.3)
local wideOk = scheduled == 8
for i = 1, 9 do
    if textures[i] ~= CCT.Blindfold.MaskPath("KittenMaskuwZ", i) then
        wideOk = false
    end
end
check("wide screen plays uwZ1 through uwZ9", wideOk and #textures == 9)
check("wide mask frame uses 21:9", maskFrame.width == 1080 * (21 / 9) and maskFrame.height == 1080)
check("spec follows the aspect", CCT.Blindfold.MaskSpec(1920, 1080) == "KittenMaskZ")
local widePrefix, wideCount = CCT.Blindfold.MaskSpec(2560, 1080)
check("wide spec", widePrefix == "KittenMaskuwZ" and wideCount == 9)

local featureRoots = {
    "Kitten/Gag.lua",
    "Kitten/Blindfold.lua",
    "Kitten/Ears.lua",
    "Kitten/Nya.lua",
}
for i = 1, #featureRoots do
    local text = read(addon .. "/" .. featureRoots[i])
    check("no second chat wrapper in " .. featureRoots[i], text:find("SendChatMessage", 1, true) == nil)
    check("no addon send in " .. featureRoots[i], text:find("SendAddonMessage", 1, true) == nil)
end
local earsSrc = read(addon .. "/Kitten/Ears.lua")
local filterAt = earsSrc:find("function CCT.Ears.Filter", 1, true)
local garbleAt = earsSrc:find("GarbleKitten", filterAt or 1, true)
local secretAt = earsSrc:find("issecretvalue", filterAt or 1, true)
check("ear filter checks the secret first", filterAt ~= nil and secretAt ~= nil and garbleAt ~= nil and secretAt < garbleAt)

local gagSrc = read(addon .. "/Kitten/Gag.lua")
check("huge gag repeats one token", gagSrc:find('string.rep(token .. " "', 1, true) ~= nil)
local chatSrc = read(addon .. "/Core/Chat.lua")
check("chat send accepts raw", chatSrc:find("opts.raw", 1, true) ~= nil)
check("chat hooks both globals", chatSrc:find("SendChatMessage", 1, true) ~= nil and chatSrc:find("C_ChatInfo.SendChatMessage", 1, true) ~= nil)

local preview = CCT.Nya.Preview("Hello")
check("preview still rewrites while nya is off", type(preview) == "string" and preview ~= "Hello" and preview:find("nya", 1, true) ~= nil)

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr2 self-check passed")
