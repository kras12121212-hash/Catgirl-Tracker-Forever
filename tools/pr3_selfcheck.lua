-- PR 3 self-check. Run from the repo root:
--   lua tools/pr3_selfcheck.lua
-- Mittens, locking heels, and both bells. No addon messages.
-- Partial heel progress stays in memory and is not written to saved state.

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

local script = (arg and arg[0]) or "tools/pr3_selfcheck.lua"
local root = script:gsub("/?tools/pr3_selfcheck%.lua$", "")
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

local secret = setmetatable({}, {
    __lt = function()
        error("secret compared")
    end,
    __le = function()
        error("secret compared")
    end,
    __eq = function()
        error("secret compared")
    end,
    __add = function()
        error("secret math")
    end,
    __sub = function()
        error("secret math")
    end,
    __mul = function()
        error("secret math")
    end,
    __div = function()
        error("secret math")
    end,
    __concat = function()
        error("secret concat")
    end,
    __tostring = function()
        error("secret string")
    end,
    __index = function()
        error("secret index")
    end,
})

issecretvalue = function(value)
    return rawequal(value, secret)
end

local frames = {}
local tickers = {}
local timers = {}
local afters = {}
local played = {}
local stopped = {}
local places = {}
local picks = {}
local macros = {}
local clears = 0
local notices = {}
local lines = {}
local sent = {}
local randomArgs = {}
local actions = {}
local cursor = nil
local macroIndex = 0
local nextHandle = 100
local combat = false
local now = 1000
local cursorXY = { 200, 80 }
local nilGroupCalls = 0

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function newFont()
    local font = {}
    function font:SetText(value)
        self.value = value
    end
    function font:SetPoint(...)
        self.point = { ... }
    end
    function font:SetFont() end
    return font
end

local function newFrame(name)
    local frame = {
        name = name,
        events = {},
        scripts = {},
        shown = false,
        mouse = false,
        fonts = {},
    }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:SetScript(which, fn)
        self.scripts[which] = fn
    end
    function frame:SetFrameStrata(strata)
        self.strata = strata
    end
    function frame:SetAllPoints(parent)
        self.allPoints = parent
    end
    function frame:ClearAllPoints() end
    function frame:SetPoint(...)
        self.point = { ... }
    end
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
    function frame:SetBackdropColor(...)
        self.backdropColor = { ... }
    end
    function frame:SetAlpha(alpha)
        self.alpha = alpha
    end
    function frame:SetStatusBarTexture(path)
        self.barTexture = path
    end
    function frame:SetMinMaxValues(low, high)
        self.minValue = low
        self.maxValue = high
    end
    function frame:SetValue(value)
        self.value = value
    end
    function frame:SetStatusBarColor(...)
        self.barColor = { ... }
    end
    function frame:CreateTexture()
        local tex = {}
        function tex:SetAllPoints() end
        function tex:SetTexture(path)
            self.path = path
        end
        function tex:SetAlpha(alpha)
            self.alpha = alpha
        end
        function tex:SetPoint() end
        frame.texture = tex
        return tex
    end
    function frame:CreateFontString()
        local font = newFont()
        self.fonts[#self.fonts + 1] = font
        return font
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
function UIParent:GetEffectiveScale()
    return 2
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
    NewTimer = function(delay, fn)
        local handle = { delay = delay, fn = fn, cancelled = false }
        function handle:Cancel()
            self.cancelled = true
        end
        timers[#timers + 1] = handle
        return handle
    end,
}

ChatFrame_AddMessageEventFilter = function() end

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

local function activeWhere(list, interval)
    local found = {}
    for i = 1, #list do
        local item = list[i]
        if not item.cancelled and (interval == nil or item.interval == interval or item.delay == interval) then
            found[#found + 1] = item
        end
    end
    return found
end

time = function()
    return now
end
GetTime = time

GetCursorPosition = function()
    return cursorXY[1], cursorXY[2]
end

InCombatLockdown = function()
    return combat
end

PlaySoundFile = function(path, channel)
    nextHandle = nextHandle + 1
    played[#played + 1] = { path = path, channel = channel, handle = nextHandle }
    return true, nextHandle
end

StopSound = function(handle)
    stopped[#stopped + 1] = handle
end

ClearCursor = function()
    clears = clears + 1
    cursor = nil
end

local function remember(kind, id)
    cursor = { type = kind, id = id }
    picks[#picks + 1] = { kind, id }
end

PickupSpell = function(id)
    remember("spell", id)
end
PickupMacro = function(id)
    remember("macro", id)
end
PickupItem = function(id)
    remember("item", id)
end
PickupAction = function(slot)
    cursor = actions[slot]
    actions[slot] = nil
    picks[#picks + 1] = { "action", slot }
end
PlaceAction = function(slot)
    places[#places + 1] = {
        slot = slot,
        cursor = cursor and { type = cursor.type, id = cursor.id } or nil,
    }
    actions[slot] = cursor
end

GetActionInfo = function(slot)
    local action = actions[slot]
    if action == nil then
        return nil
    end
    return action.type, action.id, action.sub
end

GetMacroIndexByName = function()
    return macroIndex
end

CreateMacro = function(name, icon, body, perChar)
    macros[#macros + 1] = {
        op = "create",
        name = name,
        icon = icon,
        body = body,
        perChar = perChar,
    }
    macroIndex = 7
    return macroIndex
end

EditMacro = function(index, name, icon, body, perChar)
    macros[#macros + 1] = {
        op = "edit",
        index = index,
        name = name,
        icon = icon,
        body = body,
        perChar = perChar,
    }
end

math.random = function(a, b)
    randomArgs[#randomArgs + 1] = { a, b }
    if a == 120 and b == 300 then
        return 180
    end
    if b == nil then
        return 1
    end
    return a
end

RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = { r = 1 } }
RaidNotice_AddMessage = function(_, text)
    notices[#notices + 1] = text
end
local warningClears = 0
RaidNotice_Clear = function()
    warningClears = warningClears + 1
end

LE_PARTY_CATEGORY_INSTANCE = nil
IsInRaid = function()
    return false
end
IsInGroup = function(cat)
    if cat == nil then
        nilGroupCalls = nilGroupCalls + 1
    end
    return true
end

UnitName = boom("UnitName")
UnitFullName = boom("UnitFullName")
UnitGUID = boom("UnitGUID")
GetGuildRosterInfo = boom("GetGuildRosterInfo")
GetNumGuildMembers = boom("GetNumGuildMembers")
GuildRoster = boom("GuildRoster")
C_GuildInfo = { GuildRoster = boom("C_GuildInfo.GuildRoster") }
SendChatMessage = boom("SendChatMessage")
SendAddonMessage = boom("SendAddonMessage")
C_ChatInfo = {
    SendChatMessage = boom("C_ChatInfo.SendChatMessage"),
    SendAddonMessage = boom("C_ChatInfo.SendAddonMessage"),
}
hooksecurefunc = boom("hooksecurefunc")
CatgirlTrackerDB = nil

local function spy(msg, chatType, language, target)
    sent[#sent + 1] = {
        msg = msg,
        chatType = chatType,
        language = language,
        target = target,
    }
end

local toc = read(addon .. "/CatgirlTracker_Forever.toc")
local mittensSrc = read(addon .. "/Kitten/Mittens.lua")
local heelsSrc = read(addon .. "/Kitten/Heels.lua")
local bellsSrc = read(addon .. "/Kitten/Bells.lua")
local stateSrc = read(addon .. "/Kitten/State.lua")

check(
    "toc loads mittens heels bells after nya",
    toc:find("Kitten/Nya.lua\nKitten/Mittens.lua\nKitten/Heels.lua\nKitten/Bells.lua", 1, true) ~= nil
)
check("toc has no net", toc:find("Net.lua", 1, true) == nil)

local function bans(label, text)
    local words = {
        "SendAddonMessage",
        "C_ChatInfo",
        "GetUnitSpeed",
        "IsPlayerMoving",
        "UnitPosition",
        "CatgirlBehaviorDB",
        "skillProgress",
        "state.progress",
        "speed or 0",
    }
    for i = 1, #words do
        check(label .. " has no " .. words[i], text:find(words[i], 1, true) == nil)
    end
    check(label .. " does not print", text:find("print(", 1, true) == nil)
    check(
        label .. " does not send addon messages",
        text:find("This file does not send addon messages.", 1, true) ~= nil
    )
end

bans("mittens", mittensSrc)
bans("heels", heelsSrc)
bans("bells", bellsSrc)
check("heels names the secret rule", heelsSrc:find("A secret sample is hidden and is not compared.", 1, true) ~= nil)
check("heels names movement sampling", heelsSrc:find("CCT.Move.Sample", 1, true) ~= nil)
check("heel sound interval is 7.0", heelsSrc:find("7.0", 1, true) ~= nil and heelsSrc:find("0.8", 1, true) == nil)
check("bell wait is 120 to 300", bellsSrc:find("math.random(120, 300)", 1, true) ~= nil)
check("bell has no 5 to 6 debug wait", bellsSrc:find("math.random(5, 6)", 1, true) == nil)
check("mittens writes state", mittensSrc:find("CCT.State.SetMittens", 1, true) ~= nil)
check(
    "heels writes state",
    heelsSrc:find("CCT.State.SetHeels", 1, true) ~= nil and heelsSrc:find("CCT.State.SetHeelLevel", 1, true) ~= nil
)
check(
    "bells writes state",
    bellsSrc:find("CCT.State.SetBell", 1, true) ~= nil and bellsSrc:find("CCT.State.SetTail", 1, true) ~= nil
)
check("character macro only", mittensSrc:find("CreateMacro(MACRO_NAME, MACRO_ICON, body, true)", 1, true) ~= nil)
local persisted = stateSrc:match("local PERSISTED = %{(.-)%}")
check("persisted state keeps heel levels", persisted ~= nil and persisted:find("heelLevel", 1, true) ~= nil)
check("persisted state drops heel practice", persisted ~= nil and persisted:find("skillProgress", 1, true) == nil)

local files = {}
for line in toc:gmatch("[^\n]+") do
    if line:find("%.lua$") then
        files[#files + 1] = line
    end
end

local CCT = {}
for i = 1, #files do
    local chunk, err = loadfile(addon .. "/" .. files[i])
    if chunk == nil then
        error(err)
    end
    chunk("CatgirlTracker_Forever", CCT)
end
check("files load", true)

SendChatMessage = spy
C_ChatInfo = {
    SendChatMessage = spy,
    SendAddonMessage = boom("SendAddonMessage"),
}
SendAddonMessage = boom("SendAddonMessage")
fire("ADDON_LOADED", "CatgirlTracker_Forever")

print = function(text)
    lines[#lines + 1] = tostring(text)
end

UnitFullName = function()
    return "Kitten", "Silvermoon"
end
UnitGUID = function()
    return "Player-1-ABC"
end
IsInGuild = function()
    return true
end
C_GuildInfo = { GuildRoster = function() end }
GuildRoster = nil

fire("PLAYER_LOGIN")
check("player ready", CCT.Player.ready == true and CCT.Player.short == "Kitten")
check("flavor defaults on", CCT.db.settings.flavorAnnouncements == true)
check("gag is none", CCT.State.Get().gag == "none")
check("nya is off", CCT.Nya.Enabled() == false)
check("lazy mitten cursor", frameNamed("CatgirlPawMittensCursor") == nil)
check("lazy heel overlay", frameNamed("CatgirlHeelsFailureOverlay") == nil)
check("lazy heel bars", frameNamed("CatgirlHeelsSpeedBar") == nil)
check("lazy collar reminder", frameNamed("CatgirlBellReminder") == nil)
check("lazy tail reminder", frameNamed("CatgirlTailBellReminder") == nil)
check("login did not jingle", #afters == 0 and #played == 0)

local roster = {
    { "Kitten", "rank", 0, 1, "Mage", "Elwynn", "owner=Nyx", "", true },
    { "Nyx", "rank", 0, 1, "Mage", "Elwynn", "", "", true },
}
GetNumGuildMembers = function()
    return #roster
end
GetGuildRosterInfo = function(index)
    local row = roster[index]
    return row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9]
end
CCT.Roster.Rebuild()
check("owner is nyx", CCT.Roster.GetOwnerShort() == "Nyx")
check("saved state is the live state", rawequal(CCT.db.chars.Kitten.state, CCT.State.Get()))

local function speedOf(yards)
    GetUnitSpeed = function()
        return yards
    end
    IsPlayerMoving = function()
        error("IsPlayerMoving ran")
    end
end

local function hiddenMove()
    GetUnitSpeed = function()
        return secret
    end
    IsPlayerMoving = function()
        error("IsPlayerMoving ran")
    end
end

local ring = { values = {}, sum = 0 }
local average
for i = 1, 12 do
    average = CCT.Heels.PushSample(ring, i)
end
check("twelve samples average 6.5", average == 6.5 and ring.sum == 78)
average = CCT.Heels.PushSample(ring, 13)
check("thirteenth sample drops the first", average == 7.5 and ring.sum == 90 and ring.values[1] == 2)

local practice = CCT.Heels.NewProgress()
for _ = 1, 29 do
    CCT.Heels.Advance(practice, 2, 3.5, true)
end
check(
    "twenty nine true steps have no chunk",
    practice.seconds == 0 and practice.walk == 29 and practice.trues == 29 and #practice.window == 29
)
for _ = 1, 21 do
    CCT.Heels.Advance(practice, 2, 3.5, true)
end
check("chunk lands at fifty tenths", practice.seconds == 5 and practice.walk == 0 and practice.trues == 30)

local blocked = CCT.Heels.NewProgress()
for _ = 1, 29 do
    CCT.Heels.Advance(blocked, 2, 3.5, true)
end
CCT.Heels.Advance(blocked, 1, 3.5, true)
for _ = 1, 20 do
    CCT.Heels.Advance(blocked, 2, 3.5, true)
end
check("a false in the window blocks the chunk", blocked.seconds == 0 and blocked.trues == 29)

local slow = { values = {}, sum = 0 }
for _ = 1, 12 do
    CCT.Heels.PushSample(slow, 2)
end
local oneFast = CCT.Heels.PushSample(slow, 10)
local crossed = CCT.Heels.NewProgress()
crossed.seconds = 15
local crossedStep = CCT.Heels.Advance(crossed, oneFast, 3.5, true)
check("one fast sample does not reset the average", crossedStep == nil and crossed.seconds == 15)

local wiped = CCT.Heels.NewProgress()
wiped.seconds = 40
for _ = 1, 5 do
    CCT.Heels.Advance(wiped, 2, 3.5, true)
end
local resetStep = CCT.Heels.Advance(wiped, 10, 3.5, true)
check(
    "average 10 above 3.5 clears practice",
    resetStep == "reset" and wiped.seconds == 0 and #wiped.window == 0 and wiped.walk == 0 and wiped.trues == 0
)

check("maid level 1 allows 3.5", CCT.Heels.Allowed("maid", 1) == 3.5)
check("high level 1 allows 2", CCT.Heels.Allowed("high", 1) == 2.0)
check("ballet level 20 allows 2.35", math.abs(CCT.Heels.Allowed("ballet", 20) - 2.35) < 1e-9)
check("level 1 needs 240 seconds", CCT.Heels.LevelSeconds(1) == 240)
check("level 20 needs 1380 seconds", CCT.Heels.LevelSeconds(20) == 1380)
check("heel module interval is 7", CCT.Heels.SOUND_INTERVAL == 7)

check("other cannot set heels", CCT.Heels.Set("Other", "maid") == false and CCT.State.Get().heels == "none")
check("bad heel style is refused", CCT.Heels.Set("Nyx", "stairs") == false)
check("idle tick does nothing", CCT.Heels.Tick() == nil)

check("direct state sets maid", CCT.State.SetHeels("maid") == true and CCT.State.Get().heels == "maid")
local movingCalls = 0
hiddenMove()
local secretOk, secretResult = pcall(CCT.Heels.Tick)
local maidPractice = CCT.Heels.Progress("maid")
check("secret speed does not lua-error", secretOk == true)
check(
    "secret speed holds sound and practice",
    secretResult ~= nil
        and secretResult.sound == "hold"
        and secretResult.advanced == false
        and maidPractice.seconds == 0
        and maidPractice.walk == 0
        and #maidPractice.window == 0
)
check("secret speed does not ask if moving", movingCalls == 0)
check("no step loop yet", #activeWhere(tickers, 7) == 0)

speedOf(2)
movingCalls = 0
IsPlayerMoving = function()
    movingCalls = movingCalls + 1
    error("IsPlayerMoving ran")
end
GetUnitSpeed = function()
    return 2
end
local numberOk, numberResult = pcall(CCT.Heels.Tick)
check("numeric speed does not ask if moving", numberOk == true and movingCalls == 0 and numberResult.advanced == true)
local speedBar = frameNamed("CatgirlHeelsSpeedBar")
local progressBar = frameNamed("CatgirlHeelsProgressBar")
check("speed bar size", speedBar ~= nil and speedBar.width == 240 and speedBar.height == 16 and speedBar.shown == true)
check("progress bar size", progressBar ~= nil and progressBar.width == 240 and progressBar.height == 14)
check("balance text", speedBar.text ~= nil and speedBar.text.value == "Balance bar 2.00 / 3.50")
check("level text", progressBar.text ~= nil and progressBar.text.value == "Level 1: 0 / 240s")

local warningTicker = activeWhere(tickers, 0.1)[1]
local stepTicker = activeWhere(tickers, 7)[1]
check("warning ticker is 0.1", warningTicker ~= nil)
check("step ticker is 7 not 0.8", stepTicker ~= nil and stepTicker.interval == 7)
check("under the limit has no overlay", frameNamed("CatgirlHeelsFailureOverlay") == nil and CCT.Heels.FailureExpire() == nil)

clearList(sent)
for n = 2, 2400 do
    CCT.Heels.Tick()
    if n == 29 then
        check(
            "walk hits 29 with no seconds",
            maidPractice.walk == 29 and maidPractice.seconds == 0 and maidPractice.trues == 29
        )
    elseif n == 30 then
        check("window fills at 30", #maidPractice.window == 30 and maidPractice.trues == 30 and maidPractice.seconds == 0)
    elseif n == 50 then
        check("first chunk is five seconds", maidPractice.seconds == 5 and maidPractice.walk == 0)
        fire("PLAYER_ENTERING_WORLD")
        check("zoning keeps counted seconds", maidPractice.seconds == 5 and #maidPractice.window == 30)
    elseif n == 2399 then
        check("one chunk short of level 2", maidPractice.seconds == 235 and CCT.State.Get().heelLevel.maid == 1)
    end
end
local progressText = CCT.Msg("HEELS_PROGRESS", "Kitten", "Maid Heels", 2)
if #sent ~= 1 or sent[1].msg ~= progressText or sent[1].chatType ~= "GUILD" then
    for i = 1, #sent do
        stdout("level sent " .. tostring(sent[i].chatType) .. " :: " .. tostring(sent[i].msg))
    end
end
check(
    "level up sends one guild progress line",
    #sent == 1 and sent[1].msg == progressText and sent[1].chatType == "GUILD"
)
check("maid level is 2", CCT.State.Get().heelLevel.maid == 2)
check("level up clears counted seconds", maidPractice.seconds == 0)
check("practice is not on the saved state", CCT.State.Get().skillProgress == nil and CCT.State.Get().heelProgress == nil and CCT.State.Get().progress == nil)
check("level up does not restart the warning ticker", warningTicker.cancelled == false and #activeWhere(tickers, 0.1) == 1)
check("step file is the maid clip", played[#played].path:find("HighHeels3.wav", 1, true) ~= nil)

local WARNING = "Kitten is Wearing High Heels you Cant Run or you will Fall !\n(Use Slow walk)"
local failText = CCT.Msg("HEELS_FAIL", "Kitten", "High Heels", 1)
CCT.State.SetHeels("high")
check("kind change keeps the same warning ticker", warningTicker.cancelled == false)
clearList(sent)
clearList(notices)
nilGroupCalls = 0
now = 1000
speedOf(10)
CCT.Heels.Tick()
local overlay = frameNamed("CatgirlHeelsFailureOverlay")
check("overlay frame", overlay ~= nil and overlay.shown == true and overlay.mouse == false and overlay.strata == "FULLSCREEN_DIALOG")
check("overlay texture", overlay.texture ~= nil and overlay.texture.path:find("high%-heels%.tga") ~= nil)
check("overlay expires five seconds out", CCT.Heels.FailureExpire() == 1005 and overlay.expireAt == 1005)
check("first fail is guild and party", #sent == 2 and sent[1].msg == failText and sent[1].chatType == "GUILD" and sent[2].msg == failText and sent[2].chatType == "PARTY")
check("instance probe was not called with nil", nilGroupCalls == 1)
check("raid warning text", #notices == 1 and notices[1] == WARNING)

now = 1001
CCT.Heels.Tick()
check("second over tick is quiet", #sent == 2 and #notices == 1 and CCT.Heels.FailureExpire() == 1006)
local highStep = activeWhere(tickers, 7)[1]
local stopsAtHiddenFall = #stopped
hiddenMove()
local hiddenOk, hiddenResult = pcall(CCT.Heels.Tick)
check("hidden sample during a fall does not error", hiddenOk == true and hiddenResult.sound == "hold")
check("hidden sample does not refresh or clear the overlay", CCT.Heels.FailureExpire() == 1006 and overlay.shown == true)
check("hidden sample does not release the fail latch", #sent == 2)
check("hidden sample does not stop the step loop", highStep.cancelled == false and #stopped == stopsAtHiddenFall)

now = 1002
speedOf(10)
CCT.Heels.Tick()
check("overlay refresh follows the clock", CCT.Heels.FailureExpire() == 1007)
check("warning cooldown is 1.2 seconds", #notices == 2 and notices[2] == WARNING)

speedOf(0)
for _ = 1, 12 do
    CCT.Heels.Tick()
end
check("dropped average keeps the overlay until the timer", overlay.shown == true and CCT.Heels.FailureExpire() == 1007)
check("dropped average clears the warning", warningClears >= 1)
now = 1007
speedOf(0)
CCT.Heels.Tick()
check("overlay hides when the timer is due", overlay.shown == false and CCT.Heels.FailureExpire() == nil)

clearList(sent)
speedOf(10)
for _ = 1, 12 do
    CCT.Heels.Tick()
end
check("fail can fire again after the average drops", #sent == 2 and sent[1].chatType == "GUILD" and sent[2].chatType == "PARTY")

speedOf(0)
for _ = 1, 12 do
    CCT.Heels.Tick()
end
CCT.db.settings.flavorAnnouncements = false
now = now + 2
local noticesBefore = #notices
local sentBefore = #sent
speedOf(10)
for _ = 1, 12 do
    CCT.Heels.Tick()
end
check("flavor off sends no fail line", #sent == sentBefore)
check("raid warning is not flavor gated", #notices > noticesBefore)

speedOf(0)
for _ = 1, 12 do
    CCT.Heels.Tick()
end
CCT.db.settings.flavorAnnouncements = true
LE_PARTY_CATEGORY_INSTANCE = 2
IsInGroup = function(cat)
    return cat == LE_PARTY_CATEGORY_INSTANCE
end
clearList(sent)
speedOf(10)
for _ = 1, 12 do
    CCT.Heels.Tick()
end
check(
    "instance group gets the fail line",
    #sent == 2 and sent[1].chatType == "GUILD" and sent[2].chatType == "INSTANCE_CHAT"
)
check("high level did not change", CCT.State.Get().heelLevel.high == 1)
check("high practice is not saved", CCT.State.Get().skillProgress == nil)

local textBeforeBool = speedBar.text.value
GetUnitSpeed = nil
IsPlayerMoving = function()
    return true
end
CCT.State.SetHeels("ballet")
local boolOn = CCT.Heels.Tick()
local balletStep = activeWhere(tickers, 7)[1]
local balletPractice = CCT.Heels.Progress("ballet")
check("bool moving plays the step loop", boolOn.sound == "play" and balletStep ~= nil and balletStep.interval == 7)
check("bool moving does not train", balletPractice.seconds == 0 and balletPractice.walk == 0 and #balletPractice.window == 0)
check("bool moving does not rewrite the bars", speedBar.text.value == textBeforeBool)
check("ballet clip", played[#played].path:find("HighHeels12.wav", 1, true) ~= nil and played[#played].channel == "Master")
local stopsBeforeHidden = #stopped
hiddenMove()
local boolHidden = CCT.Heels.Tick()
check("hidden sample does not stop a playing step", boolHidden.sound == "hold" and balletStep.cancelled == false and #stopped == stopsBeforeHidden)
IsPlayerMoving = function()
    return false
end
GetUnitSpeed = nil
local boolOff = CCT.Heels.Tick()
check("bool still stops the step loop", boolOff.sound == "stop" and balletStep.cancelled == true and #stopped == stopsBeforeHidden + 1)

speedOf(1)
for _ = 1, 50 do
    CCT.Heels.Tick()
end
check("ballet chunk survives in memory", balletPractice.seconds == 5 and balletPractice.walk == 0)
CCT.State.SetHeels("none")
check("removing heels clears the window and keeps seconds", balletPractice.seconds == 5 and #balletPractice.window == 0 and balletPractice.walk == 0)
check("removing heels hides the bars", speedBar.shown == false and progressBar.shown == false)
check("removing heels stops the warning ticker", warningTicker.cancelled == true)
fire("PLAYER_ENTERING_WORLD")
check("entering the world does not wipe memory", balletPractice.seconds == 5 and #balletPractice.window == 0)
CCT.State.SetHeels("ballet")
check("equipping again keeps counted seconds", balletPractice.seconds == 5 and #balletPractice.window == 0 and balletPractice.walk == 0)
CCT.State.SetHeels("none")

local function activeTickers(interval)
    return activeWhere(tickers, interval)
end

check("other cannot set mittens", CCT.Mittens.Set("Other", "locked") == false and CCT.State.Get().mittens == "none")
check("bad mitten mode is refused", CCT.Mittens.Set("Nyx", "nope") == false and CCT.State.Get().mittens == "none")
check("locked texture", CCT.Mittens.Texture("locked"):find("pawmittens.tga", 1, true) ~= nil and CCT.Mittens.Texture("locked"):find("heavypawmittens", 1, true) == nil)
check("heavy texture", CCT.Mittens.Texture("heavy"):find("heavypawmittens.tga", 1, true) ~= nil)
check("squeaking texture", CCT.Mittens.Texture("squeaking"):find("heavypawmittens.tga", 1, true) ~= nil)

check("empty bar lock", CCT.Mittens.Set("Nyx", "locked") == true)
local cursorFrame = frameNamed("CatgirlPawMittensCursor")
local cursorTicker = activeTickers(0.05)[1]
check("cursor frame", cursorFrame ~= nil and cursorFrame.shown == true and cursorFrame.width == 72 and cursorFrame.height == 72)
check("cursor strata and alpha", cursorFrame.strata == "FULLSCREEN_DIALOG" and cursorFrame.texture.alpha == 0.95)
check("cursor has no OnUpdate", cursorFrame.scripts.OnUpdate == nil)
check("cursor ticker is 0.05", cursorTicker ~= nil and cursorTicker.interval == 0.05)
check("empty bar does not create a macro", #macros == 0)
check("locked cursor art", cursorFrame.texture.path:find("heavypawmittens", 1, true) == nil and cursorFrame.texture.path:find("pawmittens.tga", 1, true) ~= nil)
cursorTicker.fn()
check(
    "cursor point uses scale",
    cursorFrame.point[1] == "CENTER"
        and cursorFrame.point[2] == UIParent
        and cursorFrame.point[3] == "BOTTOMLEFT"
        and cursorFrame.point[4] == 100
        and cursorFrame.point[5] == 40
)
local secretPoints = #frames
cursorXY[1] = secret
cursorXY[2] = secret
local pointOk = pcall(cursorTicker.fn)
check("secret cursor is not compared", pointOk == true)
cursorXY[1] = 200
cursorXY[2] = 80
check("mittens off", CCT.Mittens.Set("Nyx", "none") == true and CCT.State.Get().mittens == "none")
check("cursor ticker cancelled", cursorTicker.cancelled == true and cursorFrame.shown == false and cursorFrame.scripts.OnUpdate == nil)
check("secret cursor did not add a frame", #frames == secretPoints)

actions[1] = { type = "spell", id = 100 }
clearList(macros)
clearList(places)
check("occupied lock", CCT.Mittens.Set("Nyx", "locked") == true)
local body = "/say " .. CCT.Msg("PAW_MITTENS_SAY")
check(
    "character macro body",
    #macros == 1
        and macros[1].op == "create"
        and macros[1].name == "PawMittensOops"
        and macros[1].icon == "INV_Misc_QuestionMark"
        and macros[1].body == body
        and macros[1].perChar == true
)
check("sabotage ticker is 5", #activeTickers(5) == 1)
check("one macro place", #places == 1 and places[1].slot == 1 and places[1].cursor.type == "macro" and places[1].cursor.id == 7)
check("cursor stays on a 0.05 ticker", #activeTickers(0.05) == 1)

local fiveTicker = activeTickers(5)[1]
CCT.Mittens.Set("Nyx", "heavy")
check("heavy keeps one five second ticker", fiveTicker.cancelled == false and #activeTickers(5) == 1)
check("heavy cursor art", cursorFrame.texture.path:find("heavypawmittens.tga", 1, true) ~= nil)
CCT.Mittens.Set("Nyx", "none")
check("heavy off restores the spell", actions[1] ~= nil and actions[1].type == "spell" and actions[1].id == 100)

clearList(macros)
macroIndex = 0
combat = true
check("combat defers the macro", CCT.Mittens.Set("Nyx", "locked") == true and #macros == 0)
combat = false
fire("PLAYER_REGEN_ENABLED")
check("regen creates the macro", #macros == 1 and macros[1].op == "create" and macros[1].perChar == true)
CCT.Mittens.Set("Nyx", "none")

macroIndex = 4
clearList(macros)
clearList(places)
CCT.Mittens.Set("Nyx", "locked")
check("existing macro is edited", #macros == 1 and macros[1].op == "edit" and macros[1].index == 4 and macros[1].perChar == true and macros[1].body == body)
CCT.Mittens.Set("Nyx", "none")

actions[1] = { type = "flyout", id = 9 }
macroIndex = 0
clearList(picks)
clearList(places)
CCT.Mittens.Set("Nyx", "locked")
local picksBefore = #picks
fiveTicker = activeTickers(5)[1]
fiveTicker.fn()
local restoredSpell = false
for i = picksBefore + 1, #picks do
    if picks[i][1] == "spell" then
        restoredSpell = true
    end
end
check("unknown action is not restored", restoredSpell == false and actions[1].type == "macro")
CCT.Mittens.Set("Nyx", "none")

actions[1] = { type = "spell", id = 100 }
macroIndex = 0
clearList(places)
clearList(timers)
clearList(macros)
check("squeaking typo", CCT.Mittens.Set("Nyx", "squeking") == true and CCT.State.Get().mittens == "squeaking")
check("squeaking art", cursorFrame.texture.path:find("heavypawmittens.tga", 1, true) ~= nil)
check("squeak cycle is 30", #activeTickers(30) == 1)
check("squeak has no standing five second ticker", #activeTickers(5) == 0)
check("squeak window is a five second timer", #timers == 1 and timers[1].delay == 5 and timers[1].cancelled == false)
check("squeak places once at the start", #places == 1 and places[1].cursor.type == "macro")
check("squeak cursor ticker", #activeTickers(0.05) == 1 and activeTickers(0.05)[1].interval == 0.05)
timers[1].fn()
check("window end restores the spell", actions[1].type == "spell" and actions[1].id == 100 and timers[1].cancelled == false)
check("window end placed the spell back", places[#places].cursor.type == "spell" and places[#places].cursor.id == 100)

now = 10
clearList(played)
fire("UNIT_SPELLCAST_SUCCEEDED", "player")
check("squeak cast", #played == 1 and played[1].path:find("pawsqueak1.wav", 1, true) ~= nil and played[1].channel == "Master")
now = 11
fire("UNIT_SPELLCAST_SUCCEEDED", "player")
check("squeak cooldown", #played == 1)
now = 12
fire("UNIT_SPELLCAST_SUCCEEDED", "target")
check("other unit is silent", #played == 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player")
check("squeak plays after two seconds", #played == 2)
CCT.Mittens.Set("Nyx", "locked")
clearList(played)
now = 20
fire("UNIT_SPELLCAST_SUCCEEDED", "player")
check("locked cast creaks", #played == 1 and played[1].path:find("creak%-1%.wav") ~= nil)
now = 21
fire("UNIT_SPELLCAST_SUCCEEDED", "player")
check("creak cooldown", #played == 1)
CCT.Mittens.Set("Nyx", "none")

local oldCreate = CreateMacro
CreateMacro = function()
    error("macro failed")
end
macroIndex = 0
clearList(lines)
CCT.SetDebug(false)
local failOk = pcall(function()
    CCT.Mittens.Set("Nyx", "locked")
end)
check("macro failure stays inside the addon", failOk == true and #lines == 0 and #places == #places)
CCT.SetDebug(true)
clearList(lines)
local sabotage = activeTickers(5)[1]
sabotage.fn()
check("macro failure uses the debug channel", #lines == 1 and lines[1]:find("Paw mitten macro", 1, true) ~= nil)
CCT.SetDebug(false)
CreateMacro = oldCreate
CCT.Mittens.Set("Nyx", "none")

check("react hidden", CCT.Bells.React({ kind = "hidden", moving = true }) == "hold")
check("react missing", CCT.Bells.React(nil) == "hold" and CCT.Bells.React("nope") == "hold")
local movingSecret = setmetatable({}, {
    __eq = function()
        error("compared moving")
    end,
})
local reactOk, reactValue = pcall(CCT.Bells.React, { kind = "hidden", moving = movingSecret })
check("hidden does not inspect moving", reactOk == true and reactValue == "hold")
check("react play", CCT.Bells.React({ kind = "speed", moving = true }) == "play" and CCT.Bells.React({ kind = "bool", moving = true }) == "play")
check("react skip", CCT.Bells.React({ kind = "speed", moving = false }) == "skip" and CCT.Bells.React({ kind = "bool", moving = false }) == "skip")
check("react hold without a flag", CCT.Bells.React({ kind = "speed" }) == "hold")
check("delay is the stubbed wait", CCT.Bells.Delay() == 180)

check("other cannot set a bell", CCT.Bells.Set("Other", "bell", true) == false and CCT.State.Get().bell ~= true)
local randomBefore = #randomArgs
local afterBefore = #afters
check("owner sets the collar", CCT.Bells.Set("Nyx", "bell", true) == true and CCT.State.Get().bell == true)
check("collar schedules 180", #afters == afterBefore + 1 and afters[#afters].delay == 180)
check("collar rolled 120 to 300", randomArgs[#randomArgs][1] == 120 and randomArgs[#randomArgs][2] == 300 and #randomArgs == randomBefore + 1)
local collar = frameNamed("CatgirlBellReminder")
check(
    "collar reminder",
    collar ~= nil
        and collar.shown == true
        and collar.point[1] == "TOP"
        and collar.point[5] == -50
        and collar.fonts[1].value == "Kitten is wearing a bell... it might ring at the wrong moment nya."
)
check("owner sets the tail", CCT.Bells.Set("Nyx", "tailbell", true) == true and CCT.State.Get().tail == true)
local tail = frameNamed("CatgirlTailBellReminder")
check(
    "tail reminder",
    tail ~= nil
        and tail.shown == true
        and tail.point[5] == -84
        and tail.fonts[1].value == "Kitten is wearing a tail bell; it will ring with every step."
)
check("two bell timers", #afters == afterBefore + 2 and afters[#afters].delay == 180)
local collarFn = afters[afterBefore + 1].fn
local tailFn = afters[afterBefore + 2].fn
local aftersAtArm = #afters
CCT.State.SetGag("small")
check("another state change does not rearm", #afters == aftersAtArm)
CCT.State.SetGag("none")

now = 5000
speedOf(1)
local playedBefore = #played
collarFn()
check("moving collar plays bell", #played == playedBefore + 1 and played[#played].path:find("Bell.ogg", 1, true) ~= nil and played[#played].channel == "Master")
check("collar rearms after it plays", #afters == aftersAtArm + 1 and afters[#afters].delay == 180)
tailFn()
check("moving tail plays the tail bell", played[#played].path:find("sbell4seconds.ogg", 1, true) ~= nil)
check("tail rearms on its own", #afters == aftersAtArm + 2)
local watch = activeWhere(tickers, 0.1)[1]
check("bell watch is 0.1", watch ~= nil and watch.interval == 0.1)

local nextCollar = afters[aftersAtArm + 1].fn
hiddenMove()
local stopsAtHidden = #stopped
local playedAtHidden = #played
nextCollar()
check("hidden timer does not play or stop", #played == playedAtHidden and #stopped == stopsAtHidden)
check("hidden timer still rearms", #afters == aftersAtArm + 3)
watch.fn()
check("hidden watch does not stop a jingle", #stopped == stopsAtHidden and watch.cancelled == false)
now = 5006
watch.fn()
check("a finished jingle is dropped without stopping it", #stopped == stopsAtHidden and watch.cancelled == true)

local replay = afters[#afters].fn
speedOf(1)
replay()
local liveWatch = activeWhere(tickers, 0.1)[1]
local stopsAtSkip = #stopped
speedOf(0)
liveWatch.fn()
check("standing still stops the jingle", #stopped == stopsAtSkip + 1 and liveWatch.cancelled == true)
local playedAtSkip = #played
local skipFn = afters[#afters].fn
skipFn()
check("standing still does not start a jingle", #played == playedAtSkip)

local pending = afters[#afters].fn
CCT.Bells.Set("Nyx", "bell", false)
local playedAtRemove = #played
pending()
check("unequip cancels a pending collar jingle", CCT.State.Get().bell == false and collar.shown == false and #played == playedAtRemove)
CCT.Bells.Set("Nyx", "tail", false)
check("tail reminder hides", CCT.State.Get().tail == false and tail.shown == false)

local fast = false
for i = 1, #afters do
    if afters[i].delay == 5 or afters[i].delay == 6 then
        fast = true
    end
end
for i = 1, #tickers do
    if tickers[i].interval == 0.8 then
        fast = true
    end
end
check("no short bell or heel loop", fast == false)
check("addon messages stayed unused", true)

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr3 self-check passed")
