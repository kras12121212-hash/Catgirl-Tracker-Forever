-- PR 5 self-check. Run from the repo root:
--   lua tools/pr5_selfcheck.lua
-- Heat, submissiveness, discipline, and local sounds. Nothing is whispered.

local stdout = print
local failures = 0

local function check(name, cond, detail)
    if cond then
        stdout("ok  " .. name)
    else
        failures = failures + 1
        if detail ~= nil then
            stdout("FAIL " .. name .. " :: " .. tostring(detail))
        else
            stdout("FAIL " .. name)
        end
    end
end

local script = (arg and arg[0]) or "tools/pr5_selfcheck.lua"
local root = script:gsub("/?tools/pr5_selfcheck%.lua$", "")
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

local function near(actual, expected, eps)
    return type(actual) == "number" and math.abs(actual - expected) <= (eps or 0.02)
end

local secret = setmetatable({}, {
    __tostring = function()
        error("secret string")
    end,
    __index = function()
        error("secret index")
    end,
    __sub = function()
        error("secret sub")
    end,
    __add = function()
        error("secret add")
    end,
    __eq = function()
        error("secret eq")
    end,
    __lt = function()
        error("secret lt")
    end,
    __le = function()
        error("secret le")
    end,
})

issecretvalue = function(value)
    return rawequal(value, secret)
end

local frames = {}
local tickers = {}
local afters = {}
local notices = {}
local lines = {}
local sent = {}
local played = {}
local stopped = {}
local actions = {}
local cursor = nil
local macros = {}
local macroByName = {}
local macroSerial = 0
local places = {}
local picks = {}
local roster = {}
local now = os.time()
local orgasmLoads = false
local map = { id = 10, x = 0.5, y = 0.5, inst = 7 }

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
    function font:SetTextColor() end
    return font
end

local function newTexture(frame)
    local tex = {}
    function tex:SetAllPoints() end
    function tex:SetAlpha(alpha)
        self.alpha = alpha
    end
    function tex:Hide()
        self.hidden = true
    end
    function tex:Show()
        self.hidden = false
    end
    function tex:SetTexture(path)
        self.path = path
        if type(path) == "string" and path:find("orgasm.toc", 1, true) and not orgasmLoads then
            self.loaded = nil
            return false
        end
        if type(path) == "string" and path:find("BeltShockDeny", 1, true) then
            self.loaded = nil
            return false
        end
        if path == nil then
            self.loaded = nil
            return nil
        end
        self.loaded = path
        return path
    end
    function tex:GetTexture()
        return self.loaded
    end
    frame.texture = tex
    return tex
end

local function newFrame(kind, name, parent, template)
    local frame = {
        kind = kind,
        name = name,
        parent = parent,
        template = template,
        events = {},
        scripts = {},
        attributes = {},
        clicks = {},
        shown = false,
        mouse = false,
    }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterEvent(event)
        self.events[event] = nil
    end
    function frame:SetScript(which, fn)
        self.scripts[which] = fn
    end
    function frame:SetFrameStrata(strata)
        self.strata = strata
    end
    function frame:SetAllPoints(other)
        self.allPoints = other
    end
    function frame:ClearAllPoints() end
    function frame:SetPoint(...)
        self.point = { ... }
    end
    function frame:GetPoint()
        if not self.point then
            return nil
        end
        return self.point[1], self.point[2], self.point[3], self.point[4], self.point[5]
    end
    function frame:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function frame:EnableMouse(on)
        self.mouse = on and true or false
    end
    function frame:SetMovable(on)
        self.movable = on and true or false
    end
    function frame:RegisterForDrag(button)
        self.drag = button
    end
    function frame:StartMoving()
        self.moving = true
    end
    function frame:StopMovingOrSizing()
        self.moving = false
    end
    function frame:RegisterForClicks(click)
        self.clicks[#self.clicks + 1] = click
    end
    function frame:SetAttribute(key, value)
        self.attributes[key] = value
    end
    function frame:GetAttribute(key)
        return self.attributes[key]
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:Show()
        self.shown = true
    end
    function frame:IsShown()
        return self.shown == true
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
        return newTexture(self)
    end
    function frame:CreateFontString()
        local font = newFont()
        self.text = font
        return font
    end
    frames[#frames + 1] = frame
    return frame
end

CreateFrame = function(kind, name, parent, template)
    return newFrame(kind, name, parent, template)
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

time = function(parts)
    if type(parts) == "table" then
        return os.time(parts)
    end
    return now
end
date = os.date
GetTime = function()
    return now
end

GetCursorPosition = function()
    return 0, 0
end
InCombatLockdown = function()
    return false
end
GetUnitSpeed = function()
    return 0
end
IsPlayerMoving = function()
    return false
end

PlaySoundFile = function(path, channel)
    played[#played + 1] = { path = path, channel = channel }
    return true, 100 + #played
end
StopSound = function(handle)
    stopped[#stopped + 1] = handle
end
DoEmote = function() end

ClearCursor = function()
    cursor = nil
end
PickupSpell = function(id)
    cursor = { type = "spell", id = id }
    picks[#picks + 1] = cursor
end
PickupMacro = function(id)
    cursor = { type = "macro", id = id }
end
PickupItem = function(id)
    cursor = { type = "item", id = id }
end
PickupAction = function(slot)
    cursor = actions[slot]
    actions[slot] = nil
end
PlaceAction = function(slot)
    places[#places + 1] = slot
    actions[slot] = cursor
end
GetActionInfo = function(slot)
    local action = actions[slot]
    if action == nil then
        return nil
    end
    return action.type, action.id, action.sub
end
GetMacroIndexByName = function(name)
    local row = macroByName[name]
    if row == nil then
        return 0
    end
    return row.index
end
CreateMacro = function(name, icon, body, perChar)
    macroSerial = macroSerial + 1
    local row = { name = name, icon = icon, body = body, perChar = perChar, index = macroSerial }
    macros[#macros + 1] = row
    macroByName[name] = row
    return row.index
end
EditMacro = function() end

math.random = function(a, b)
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
RaidNotice_Clear = function() end

C_PartyInfo = {
    InviteUnit = function() end,
    LeaveParty = function() end,
}

C_Map = {
    GetBestMapForUnit = function()
        return map.id
    end,
    GetPlayerMapPosition = function()
        if map.x == nil or map.y == nil then
            return nil
        end
        return { x = map.x, y = map.y }
    end,
}
GetInstanceInfo = function()
    return nil, nil, nil, nil, nil, nil, nil, map.inst
end

UnitName = boom("UnitName")
UnitFullName = boom("UnitFullName")
UnitGUID = boom("UnitGUID")
UnitPosition = boom("UnitPosition")
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
SlashCmdList = {}

local toc = read(addon .. "/CatgirlTracker_Forever.toc")
check(
    "toc order",
    toc:find("Kitten/Commands.lua\nKitten/HeatConfig.lua\nKitten/Heat.lua\nKitten/Submissiveness.lua\nKitten/SoundEngine.lua\nKitten/Discipline.lua", 1, true) ~= nil
)
check("toc lists net", toc:find("Core/Net.lua", 1, true) ~= nil)
check("net file exists", io.open(addon .. "/Core/Net.lua", "rb") ~= nil)
check("pictures file exists", io.open(addon .. "/Kitten/Pictures.lua", "rb") ~= nil)

local featureRoots = {
    "Kitten/HeatConfig.lua",
    "Kitten/Heat.lua",
    "Kitten/Submissiveness.lua",
    "Kitten/SoundEngine.lua",
    "Kitten/Discipline.lua",
}
local banned = {
    "SendAddonMessage",
    "C_ChatInfo",
    "UnitName",
    "UnitPosition",
    "GetGuildRosterInfo",
}
for i = 1, #featureRoots do
    local text = read(addon .. "/" .. featureRoots[i])
    check(featureRoots[i] .. " keeps the local sentence", text:find("This file does not send addon messages.", 1, true) ~= nil)
    for b = 1, #banned do
        check(featureRoots[i] .. " has no " .. banned[b], text:find(banned[b], 1, true) == nil)
    end
end

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
check("files load", CCT.Heat ~= nil and CCT.HeatConfig ~= nil and CCT.Submissiveness ~= nil and CCT.Sounds ~= nil and CCT.Discipline ~= nil)

local function spy(msg, chatType, language, target)
    sent[#sent + 1] = {
        msg = msg,
        chatType = chatType,
        language = language,
        target = target,
    }
end

SendChatMessage = spy
C_ChatInfo = {
    SendChatMessage = spy,
    SendAddonMessage = boom("SendAddonMessage"),
}
SendAddonMessage = boom("SendAddonMessage")

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

local function publishRoster(rows)
    roster = rows
    GetNumGuildMembers = function()
        return #roster
    end
    GetGuildRosterInfo = function(index)
        local row = roster[index]
        if row == nil then
            return nil
        end
        return row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9]
    end
end

fire("ADDON_LOADED", "CatgirlTracker_Forever")
local playedAtLogin = #played
local aftersAtLogin = #afters
fire("PLAYER_LOGIN")
check("player ready", CCT.Player.ready == true and CCT.Player.short == "Kitten")
check("login is quiet", #lines == 0 and #sent == 0 and #notices == 0)
check("login does not play or flash", #played == playedAtLogin and #afters == aftersAtLogin)

local function state()
    return CCT.State.Get()
end

local function char()
    return CCT.Saved.EnsureChar("Kitten")
end

local function cmd(text)
    return CCT.Commands.Receive("Nyx", text, now, false)
end

publishRoster({
    { "Kitten", "rank", 0, 1, "Mage", "Elwynn", "owner=Nyx", "", true },
    { "Nyx", "Officer", 1, 1, "Mage", "Elwynn", "", "", true },
})
CCT.Roster.Rebuild()
check("owner is nyx", CCT.Roster.GetOwnerShort() == "Nyx")
CCT.Heat.Refresh(now)
CCT.Submissiveness.Refresh(now)

local heatBar = frameNamed("CatgirlHeatBar")
local subBar = frameNamed("CatgirlSubmissivenessBar")
check("heat bar exists", heatBar ~= nil and heatBar.width == 240 and heatBar.height == 18 and heatBar.shown == true)
check("heat bar default point", heatBar.point[1] == "CENTER" and heatBar.point[4] == 0 and heatBar.point[5] == -200)
check("sub bar exists", subBar ~= nil and subBar.width == 240 and subBar.height == 18 and subBar.shown == true)
check("sub bar default point", subBar.point[1] == "CENTER" and subBar.point[5] == -230)
check("sub text", subBar.text and type(subBar.text.value) == "string" and subBar.text.value:find("Kitten Submissiveness:", 1, true) ~= nil)
check("reachable bind maximum", CCT.Submissiveness.MAX_BINDS == 20)

heatBar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -34)
heatBar.scripts.OnDragStop(heatBar)
check(
    "heat bar position is saved on the character",
    type(char().bars) == "table"
        and char().bars.heat.point == "TOPLEFT"
        and char().bars.heat.x == 12
        and char().bars.heat.y == -34
)
subBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 3, 40)
subBar.scripts.OnDragStop(subBar)
check("sub bar position is saved on the character", char().bars.sub.point == "BOTTOM" and char().bars.sub.x == 3 and char().bars.sub.y == 40)

CCT.HeatConfig.bar.locked = true
heatBar.moving = false
heatBar.scripts.OnDragStart(heatBar)
check("locked heat bar does not move", heatBar.moving ~= true)
CCT.HeatConfig.bar.locked = false
heatBar.scripts.OnDragStart(heatBar)
check("unlocked heat bar moves", heatBar.moving == true)
if heatBar.StopMovingOrSizing then
    heatBar:StopMovingOrSizing()
end

local lowR, lowG, lowB = CCT.Heat.Color(0)
local midR, midG, midB = CCT.Heat.Color(50)
local highR, highG, highB = CCT.Heat.Color(100)
check("heat color low", near(lowR, 0) and near(lowG, 0.45) and near(lowB, 1))
check("heat color mid", near(midR, 1) and near(midG, 0.35) and near(midB, 0.75))
check("heat color high", near(highR, 1) and near(highG, 0) and near(highB, 0))
check("sub bar color", near(subBar.barColor[1], 0.35) and near(subBar.barColor[2], 0.8) and near(subBar.barColor[3], 0.6))

CCT.Heat.Rebuild()
local constants = CCT.Heat.Constants()
local exponent = math.log(5) / math.log(10)
local k = 100 / (1200 * (1 - exponent))
check("decay exponent", near(constants.exponent, exponent, 1e-9))
check("decay k", near(constants.k, k, 1e-9))
check("decay at zero seconds", CCT.Heat.Decay(100, 0) == 100)
check("decay across the full window", CCT.Heat.Decay(100, 1200) == 0)
check("decay at half the window", near(CCT.Heat.Decay(100, 600), 10, 0.05))
check("decay of a dead power is zero", CCT.Heat.Decay(1, 100000) == 0)

local savedRatio = CCT.HeatConfig.decay.ratio100to10
local savedTotal = CCT.HeatConfig.decay.totalSeconds
CCT.HeatConfig.decay.ratio100to10 = 1
CCT.HeatConfig.decay.totalSeconds = 10
CCT.Heat.Rebuild()
local clamped = CCT.Heat.Constants()
local clampedExponent = math.log(1.01) / math.log(10)
check("ratio below 1.01 is clamped", near(clamped.exponent, clampedExponent, 1e-9))
check("total seconds has a one minute floor", near(clamped.k, 100 / (60 * (1 - clampedExponent)), 1e-9))
CCT.HeatConfig.decay.ratio100to10 = savedRatio
CCT.HeatConfig.decay.totalSeconds = savedTotal
CCT.Heat.Rebuild()

local sentAtPush = #sent
CCT.State.SetHeat(40)
check("push waits out the ten second gate", CCT.Heat.pending == nil)
CCT.Heat.Step(0.01, now + 9)
check("nine seconds does not push", CCT.Heat.pending == nil and #sent == sentAtPush, "pending " .. tostring(CCT.Heat.pending))
CCT.Heat.Step(0.01, now + 10)
check("ten seconds records a pending heat", CCT.Heat.pending == 40 and CCT.Heat.pendingCount == 1 and #sent == sentAtPush, "pending " .. tostring(CCT.Heat.pending))
CCT.Heat.Step(0.01, now + 10)
check("the same integer does not push again", CCT.Heat.pendingCount == 1)

CCT.State.SetHeat(100)
CCT.State.TouchClock(now)
CCT.Heat.ApplyOffline(now + 1200)
check("offline gap decays", state().heat < 1, "heat " .. tostring(state().heat))
CCT.State.SetHeat(80)
state().lastUnixUpdate = nil
CCT.Heat.ApplyOffline(now + 5000)
check("a missing stamp does not decay", state().heat == 80 and state().lastUnixUpdate == now + 5000, "heat " .. tostring(state().heat))
CCT.State.SetHeat(70)
CCT.State.TouchClock(0)
CCT.Heat.ApplyOffline(now + 8000)
check("a zero stamp does not decay", state().heat == 70, "heat " .. tostring(state().heat))

CCT.State.SetHeels("none")
CCT.State.SetHeat(10)
local beforeControls = state().heat
CCT.State.SetHeels("maid")
CCT.Heat.ApplyControls(59)
check("maid heat waits for sixty seconds", state().heat == beforeControls, "heat " .. tostring(state().heat))
CCT.Heat.ApplyControls(1)
check("maid heat adds two", near(state().heat, beforeControls + 2, 0.001), "heat " .. tostring(state().heat))
CCT.State.SetHeels("none")

CCT.State.SetHeat(15)
CCT.State.ApplyToy("dildo")
local beforeToy = state().heat
CCT.Heat.ApplyControls(89)
check("toy base waits for ninety seconds", state().heat == beforeToy, "heat " .. tostring(state().heat))
CCT.Heat.ApplyControls(1)
check("toy base adds one", near(state().heat, beforeToy + 1, 0.001), "heat " .. tostring(state().heat))
CCT.State.RemoveToy("dildo")

local function dressOff()
    CCT.State.SetGag("none")
    CCT.State.SetBlind("none")
    CCT.State.SetEars("none")
    CCT.State.SetMittens("none")
    CCT.State.SetHeels("none")
    CCT.State.SetBell(false)
    CCT.State.SetTail(false)
    CCT.State.SetJewel(false)
    CCT.State.SetLeash(false, nil)
    CCT.State.SetBelt(false)
    CCT.State.SetBra(false)
    if state().toys then
        for id in pairs(state().toys) do
            CCT.State.RemoveToy(id)
        end
    end
end

dressOff()
CCT.State.SetHeelLevel("maid", 5)
CCT.State.SetHeelLevel("high", 1)
CCT.State.SetHeelLevel("ballet", 1)
char().life.denied = 10
char().life.orgasms = {}
CCT.Submissiveness.Recompute(now)
check("submissiveness reaches seventy", state().sub == 70, "sub " .. tostring(state().sub))
CCT.State.SetHeat(50)
CCT.Heat.AddDelta(-11)
check("a matching negative delta flips", near(state().heat, 61, 0.001), "heat " .. tostring(state().heat))
CCT.Heat.AddDelta(-12)
check("a deeper negative delta stays negative", near(state().heat, 49, 0.001), "heat " .. tostring(state().heat))

local savedRecompute = CCT.Submissiveness.Recompute
CCT.Submissiveness.Recompute = nil
CCT.State.SetSub(0)
CCT.State.SetHeat(20)
CCT.Heat.AddDelta(-1)
check("sub zero does not flip", near(state().heat, 19, 0.001) and state().sub == 0, "heat " .. tostring(state().heat) .. " sub " .. tostring(state().sub))
CCT.Submissiveness.Recompute = savedRecompute

dressOff()
CCT.State.SetHeelLevel("maid", 1)
CCT.State.SetHeelLevel("high", 1)
CCT.State.SetHeelLevel("ballet", 1)
char().life.denied = 3
char().life.orgasms = {}
CCT.State.ApplyToy("vibes_ears")
CCT.State.ApplyToy("ear_piercings")
CCT.State.ApplyToy("dildo")
CCT.State.ApplyToy("small_butplug")
CCT.State.ApplyToy("inflatable_dildo")
CCT.State.SetBelt(true)
CCT.State.SetBra(true)
CCT.Submissiveness.Recompute(now)
check("worn toys and chastity reach sixty three", state().sub == 63, "sub " .. tostring(state().sub) .. " binds " .. tostring(CCT.Submissiveness.BindCount(state())))
CCT.State.SetHeat(40)
CCT.Heat.AddDelta(-10)
check("sub sixty three flips a ten point drop", near(state().heat, 50, 0.001), "heat " .. tostring(state().heat))
dressOff()
CCT.Submissiveness.Recompute(now)

char().life.denied = 0
char().life.orgasms = {}
CCT.State.SetBelt(false)
CCT.State.SetHeat(0)
local orgasmsBefore = state().counters.orgasm
local deniesBefore = state().counters.deny
local sentBeforeOrgasm = #sent
CCT.Heat.Add(100)
local flash = frameNamed("CatgirlHeatOrgasmFlash")
check("a failed orgasm texture stays hidden", flash ~= nil and flash.shown ~= true and state().heat == 0, "heat " .. tostring(state().heat))
check("orgasm records the week and the life list", state().counters.orgasm == orgasmsBefore + 1 and #char().life.orgasms == 1 and state().counters.heatPeak == 100)
check("an allowed orgasm does not whisper", #sent == sentBeforeOrgasm)
check("deny did not move", state().counters.deny == deniesBefore)

orgasmLoads = true
local aftersBefore = #afters
CCT.State.SetHeat(0)
CCT.Heat.Add(100)
check("orgasm flash shows", flash.shown == true and near(flash.alpha, 0.9) and flash.texture.path:find("orgasm.toc", 1, true) ~= nil)
check("orgasm flash lasts six tenths", #afters == aftersBefore + 1 and afters[#afters].delay == 0.6)
local firstHide = afters[#afters].fn
CCT.Heat.Add(100)
local secondHide = afters[#afters].fn
firstHide()
check("an older flash timer does not hide the new flash", flash.shown == true)
secondHide()
check("the current flash timer hides it", flash.shown ~= true)
check("orgasm list grew", #char().life.orgasms == 3 and state().counters.heatPeak == 100)

for _ = #char().life.orgasms + 1, 55 do
    CCT.State.SetHeat(0)
    CCT.Heat.Add(100)
end
check("life orgasms keep the newest fifty", #char().life.orgasms == 50)

CCT.State.SetBelt(true)
CCT.State.SetBeltMode("deny")
local denyBefore = state().counters.deny
local lifeDeniedBefore = char().life.denied
local aftersBeforeDeny = #afters
clearList(lines)
flash.shown = false
CCT.State.SetHeat(0)
CCT.Heat.Add(100)
check("a denied orgasm sets heat to seventy", state().heat == 70 and state().counters.deny == denyBefore + 1 and char().life.denied == lifeDeniedBefore + 1, "heat " .. tostring(state().heat) .. " deny " .. tostring(state().counters.deny))
check("a denied orgasm does not flash", flash.shown ~= true and #afters == aftersBeforeDeny)
check("deny is not counted twice", state().counters.deny == denyBefore + 1)
CCT.State.SetBelt(false)

local todayBefore = CCT.Submissiveness.OrgasmsToday(char().life, now)
char().life.orgasms[#char().life.orgasms + 1] = now
check("today's orgasm counts", CCT.Submissiveness.OrgasmsToday(char().life, now) == todayBefore + 1)
char().life.denied = 4
CCT.State.SetHeelLevel("maid", 1)
CCT.State.SetGag("small")
CCT.State.SetBell(true)
CCT.Submissiveness.Recompute(now)
local expectedSub = 3 * math.max(1, 4 - CCT.Submissiveness.OrgasmsToday(char().life, now)) * 2
check("submissiveness uses denies, today, and binds", state().sub == expectedSub, "sub " .. tostring(state().sub) .. " expected " .. tostring(expectedSub))
dressOff()
char().life.denied = 0
char().life.orgasms = {}

local toyIds = {}
for i = 1, #CCT.State.Toys do
    toyIds[#toyIds + 1] = CCT.State.Toys[i].id
end
for i = 1, #toyIds do
    CCT.State.ApplyToy(toyIds[i])
end
CCT.State.SetGag("small")
CCT.State.SetBlind("light")
CCT.State.SetEars("kitten")
CCT.State.SetMittens("locked")
CCT.State.SetHeels("maid")
CCT.State.SetBell(true)
CCT.State.SetTail(true)
CCT.State.SetJewel(true)
CCT.State.SetLeash(true, "Nyx")
CCT.State.SetBelt(true)
CCT.State.SetBra(true)
check("ten worn slots, nine toys, and the leash are twenty", CCT.Submissiveness.BindCount(state()) == 20, "binds " .. tostring(CCT.Submissiveness.BindCount(state())))
local plugs = 0
for i = 1, #CCT.State.Toys do
    local spec = CCT.State.Toys[i]
    local row = state().toys[spec.id]
    if spec.group == "butplug" and row and row.applied == true then
        plugs = plugs + 1
    end
end
check("only one butplug is worn", plugs == 1)
CCT.State.SetBelt(false)
CCT.State.ApplyToy("inflatable_butplug")
CCT.State.SetBelt(true)
check(
    "a fourth butplug does not raise the bind count",
    CCT.Submissiveness.BindCount(state()) == 20
        and state().toys.inflatable_butplug.applied == true
        and state().toys.taill_butplug.applied ~= true,
    "binds " .. tostring(CCT.Submissiveness.BindCount(state()))
)
dressOff()

local function disc(extra)
    return cmd("Cmd,op:disc,cid:D1,id:spank_hand,part:butt,str:1,map:10,x:0.5000,y:0.5000,inst:7" .. (extra or ""))
end

map.id = 10
map.x = 0.5
map.y = 0.5
map.inst = 7
CCT.State.SetHeat(30)
local playedBefore = #played
local sentBefore = #sent
local linesBefore = #lines
local noticesBefore = #notices
local tasksBefore = state().counters.tasks
local far = cmd("Cmd,op:disc,cid:Far,id:spank_hand,part:butt,str:1,map:10,x:0.9000,y:0.5000,inst:7")
check(
    "too far is an ack",
    far.ok == false and far.reason == "toofar" and far.op == "disc" and far.cid == "Far" and far.kind == nil and state().heat == 30,
    "reason " .. tostring(far.reason) .. " heat " .. tostring(state().heat)
)
check("too far does not play, whisper, or count", #played == playedBefore and #sent == sentBefore and #lines == linesBefore and #notices == noticesBefore and state().counters.tasks == tasksBefore)

local edge = cmd("Cmd,op:disc,cid:Edge,id:spank_hand,part:butt,str:1,map:10,x:0.5200,y:0.5000,inst:7")
check("two hundredths is close", edge.ok == true and edge.reason == nil, "reason " .. tostring(edge.reason))
CCT.State.SetHeat(30)

map.id = secret
map.inst = nil
local secretOk, secretResult = pcall(function()
    return CCT.Discipline.Close(secret, secret, secret, secret)
end)
check("a secret map is not compared", secretOk == true and secretResult == false, secretOk and "close" or secretResult)
local secretCmd = cmd("Cmd,op:disc,cid:Secret,id:spank_hand,part:butt,str:1,map:10,x:0.5000,y:0.5000,inst:7")
check("a secret kitten map is too far", secretCmd.ok == false and secretCmd.reason == "toofar" and state().heat == 30)

map.id = nil
map.x = nil
map.y = nil
map.inst = 7
local sameInst = cmd("Cmd,op:disc,cid:Inst,id:spank_hand,part:butt,str:1,map:nil,x:nil,y:nil,inst:7")
check("matching instance ids are close when coordinates are missing", sameInst.ok == true, "reason " .. tostring(sameInst.reason))
CCT.State.SetHeat(30)
map.inst = 8
local otherInst = cmd("Cmd,op:disc,cid:Inst2,id:spank_hand,part:butt,str:1,map:nil,x:nil,y:nil,inst:7")
check("a different instance is too far", otherInst.reason == "toofar" and state().heat == 30)

map.id = 10
map.x = 0.5
map.y = 0.5
map.inst = 4
local otherMap = cmd("Cmd,op:disc,cid:Map,id:spank_hand,part:butt,str:1,map:11,x:0.5000,y:0.5000,inst:4")
check("a different map with the same instance is close", otherMap.ok == true, "reason " .. tostring(otherMap.reason))
CCT.State.SetHeat(30)
local farSameInst = cmd("Cmd,op:disc,cid:FarInst,id:spank_hand,part:butt,str:1,map:10,x:0.9000,y:0.5000,inst:4")
check("the same map stays too far even in one instance", farSameInst.reason == "toofar" and state().heat == 30)

map.inst = 7
local unknown = cmd("Cmd,op:disc,cid:Bad,id:nope,part:butt,str:1,map:10,x:0.5000,y:0.5000,inst:7")
check("unknown discipline id", unknown.reason == "id" and state().heat == 30)
local unknownPart = cmd("Cmd,op:disc,cid:BadPart,id:spank_hand,part:nose,str:1,map:10,x:0.5000,y:0.5000,inst:7")
check("unknown discipline part", unknownPart.reason == "part" and state().heat == 30)

CCT.State.SetBelt(true)
playedBefore = #played
local belted = cmd("Cmd,op:disc,cid:Belt,id:shock_wand,part:pussy,str:2,map:10,x:0.5000,y:0.5000,inst:7")
check("a belt blocks before heat", belted.reason == "belt" and state().heat == 30 and #played == playedBefore, "heat " .. tostring(state().heat) .. " played " .. tostring(#played - playedBefore))
local farBelt = cmd("Cmd,op:disc,cid:FarBelt,id:shock_wand,part:pussy,str:2,map:10,x:0.9000,y:0.5000,inst:7")
check("too far wins over the belt", farBelt.reason == "toofar")
CCT.State.SetBelt(false)
CCT.State.SetBra(true)
local bra = cmd("Cmd,op:disc,cid:Bra,id:pinch,part:nipples,str:1,map:10,x:0.5000,y:0.5000,inst:7")
check("a bra blocks", bra.reason == "bra" and state().heat == 30)
CCT.State.SetBra(false)

playedBefore = #played
local unsentBefore = #CCT.Sounds.unsent
sentBefore = #sent
local icons = {}
CCT.Pictures = {
    ShowDiscipline = function(icon)
        icons[#icons + 1] = icon
    end,
}
clearList(lines)
clearList(notices)
local hit = cmd("Cmd,op:disc,cid:Hit,id:spank_hand,part:butt,str:9,map:10,x:0.5000,y:0.5000,inst:7")
check("strength clamps and heat comes from the config", hit.ok == true and near(state().heat, 35, 0.001), "heat " .. tostring(state().heat))
check("discipline plays the local file", #played == playedBefore + 1 and played[#played].path:find("spank.wav", 1, true) ~= nil and played[#played].channel == "Master")
check("discipline remembers an unsent body", CCT.Sounds.unsent[#CCT.Sounds.unsent]:find("DiscSound", 1, true) ~= nil and #CCT.Sounds.unsent == unsentBefore + 1)
check("discipline tells the kitten locally", lines[#lines]:find("Spank Hand on Butt (strength 5).", 1, true) ~= nil and notices[#notices] == "Spank Hand on Butt (strength 5).")
check("discipline icon is local", icons[1] == "Textures/Hand.tga")
check("a hit does not whisper", #sent == sentBefore)

playedBefore = #played
local crop = cmd("Cmd,op:disc,cid:Crop,id:heart_crop,part:butt,str:nil,map:10,x:0.5000,y:0.5000,inst:7")
check("heart crop has no sound file", crop.ok == true and #played == playedBefore and near(state().heat, 36, 0.001))
check("heart crop still notes a body", CCT.Sounds.unsent[#CCT.Sounds.unsent]:find("action:heart_crop", 1, true) ~= nil)
local pinch = CCT.Sounds.PlayDisciplineAction("pinch", 2)
check("pinch does not play", pinch == nil and #played == playedBefore)

local function liveTickers(interval)
    local n = 0
    local last = nil
    for i = 1, #tickers do
        if tickers[i].interval == interval and tickers[i].cancelled ~= true then
            n = n + 1
            last = tickers[i]
        end
    end
    return n, last
end

CCT.State.ApplyToy("vibes_ears")
playedBefore = #played
local loopsBefore = liveTickers(CCT.Sounds.VIBE_LOOP_INTERVAL)
local pingsBefore = liveTickers(CCT.Sounds.VIBE_PING_INTERVAL)
CCT.Toys.Handle("vibes_ears", "vibe", 2, "Nyx")
local loopsAfter, loopTicker = liveTickers(2.5)
local pingsAfter, pingTicker = liveTickers(3.0)
check("vibe loop is two and a half seconds", CCT.Sounds.VIBE_LOOP_INTERVAL == 2.5 and loopsAfter == loopsBefore + 1)
check("vibe ping is three seconds", CCT.Sounds.VIBE_PING_INTERVAL == 3 and pingsAfter == pingsBefore + 1)
check("vibe plays locally", #played == playedBefore + 1 and played[#played].path:find("Vibrate2.wav", 1, true) ~= nil)
check("vibe start is unsent", CCT.Sounds.unsent[#CCT.Sounds.unsent - 1]:find("ToyVibeLoopStart", 1, true) ~= nil)
local unsentAtPing = #CCT.Sounds.unsent
local sentAtPing = #sent
pingTicker.fn()
local pingBody = CCT.Sounds.unsent[#CCT.Sounds.unsent]
check(
    "a ping is remembered and not sent",
    type(pingBody) == "string"
        and pingBody:find("ToyVibeLoopPing", 1, true) ~= nil
        and #CCT.Sounds.unsent <= 8
        and (#CCT.Sounds.unsent == unsentAtPing + 1 or #CCT.Sounds.unsent == 8)
        and #sent == sentAtPing,
    pingBody
)
playedBefore = #played
loopTicker.fn()
check("the vibe loop plays again", #played == playedBefore + 1)
CCT.Toys.Handle("vibes_ears", "vibe", 0, "Nyx")
check("vibe one is the floor", state().toys.vibes_ears.vibe == 1)
CCT.Sounds.SetToyVibeState("vibes_ears", 0)
check("stopping the vibe cancels the loop", loopTicker.cancelled == true and CCT.Sounds.unsent[#CCT.Sounds.unsent]:find("ToyVibeLoopStop", 1, true) ~= nil)

playedBefore = #played
CCT.Gag.Set("inflatable", 1)
check("gag inflate reaches the engine", #played == playedBefore + 1 and played[#played].path:find("Inflate.wav", 1, true) ~= nil)
check("gag inflate is unsent", CCT.Sounds.unsent[#CCT.Sounds.unsent]:find("ToyInflateSound", 1, true) ~= nil and CCT.Sounds.unsent[#CCT.Sounds.unsent]:find("action:inflate", 1, true) ~= nil)
CCT.Gag.Set("none")

local savedShort = CCT.Player.short
CCT.Player.short = "Nyx"
playedBefore = #played
local heard = CCT.Sounds.Handle("DiscSound, owner:Nyx, action:crop, strength:2")
check("owner hears a discipline body", heard == true and #played == playedBefore + 1 and played[#played].path:find("Crop.wav", 1, true) ~= nil)
local ignored = CCT.Sounds.Handle("DiscSound, owner:Other, action:crop, strength:2")
check("another owner is ignored", ignored == true and #played == playedBefore + 1)
playedBefore = #played
map.id = 10
map.x = 0.4
map.y = 0.4
map.inst = 3
local shockHeard = CCT.Sounds.Handle("ToyShockSound, owner:Nyx, level:2, mapID:10, x:0.4000, y:0.4000, instanceID:3")
check("a close shock plays", shockHeard == true and #played == playedBefore + 1 and played[#played].path:find("Shock2.wav", 1, true) ~= nil)
playedBefore = #played
local shockFar = CCT.Sounds.Handle("ToyShockSound, owner:Nyx, level:2, mapID:10, x:0.9000, y:0.4000, instanceID:3")
check("a far shock stays quiet", shockFar == true and #played == playedBefore)
map.id = nil
map.x = nil
map.y = nil
map.inst = 3
playedBefore = #played
local vibeHeard = CCT.Sounds.Handle("ToyVibeLoopStart, owner:Nyx, level:3, mapID:nil, x:nil, y:nil, instanceID:3")
local _, remoteTicker = liveTickers(2.5)
check("a matching instance starts the remote vibe", vibeHeard == true and #played == playedBefore + 1 and remoteTicker ~= nil)
CCT.Sounds.Handle("ToyVibeLoopStop, owner:Nyx, level:0, mapID:nil, x:nil, y:nil, instanceID:3")
check("stop ends the remote vibe", remoteTicker.cancelled == true)
CCT.Player.short = savedShort

local cap = {}
for i = 1, 20 do
    CCT.Sounds.PlayDisciplineAction("pinch", 1)
    if #CCT.Sounds.unsent > 8 then
        cap[#cap + 1] = #CCT.Sounds.unsent
    end
end
check("unsent sounds stay bounded", #cap == 0 and #CCT.Sounds.unsent == 8)

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr5 self-check passed")
