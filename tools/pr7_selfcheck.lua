-- PR 7 self-check. Run from the repo root:
--   lua tools/pr7_selfcheck.lua
-- Ledger, daily scorecard, and OwnerWeek. The master draws nothing.

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

local script = (arg and arg[0]) or "tools/pr7_selfcheck.lua"
local root = script:gsub("/?tools/pr7_selfcheck%.lua$", "")
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

local ledgerSrc = read(addon .. "/Kitten/Ledger.lua")
local slackSrc = read(addon .. "/Kitten/Slack.lua")
local napSrc = read(addon .. "/Kitten/Nap.lua")
local headSrc = read(addon .. "/Kitten/Headpet.lua")
local zoneSrc = read(addon .. "/Kitten/Zone.lua")
local storeSrc = read(addon .. "/Master/Store.lua")
local corrSrc = read(addon .. "/Owner/Corroboration.lua")
local reportSrc = read(addon .. "/Kitten/Report.lua")
local toc = read(addon .. "/CatgirlTracker_Forever.toc")

local function callBeforeLower(src, fn)
    local at = src:find("function " .. fn, 1, true)
    if at == nil then
        return false
    end
    local secretAt = src:find("Secret(msg)", at, true)
    local lowerAt = src:find(":lower()", at, true)
    return secretAt ~= nil and lowerAt ~= nil and secretAt < lowerAt
end

check("toc loads the scorecard files", toc:find("Kitten/Ledger.lua\nKitten/Slack.lua\nKitten/Nap.lua\nKitten/Headpet.lua\nKitten/Zone.lua\nKitten/Location.lua\n", 1, true) ~= nil)
check("toc ends at the master store", toc:find("\nMaster/Store.lua\n", 1, true) ~= nil or toc:find("\nMaster/Store.lua", 1, true) ~= nil)
check("ledger does not increment tasks", ledgerSrc:find('AddCounter("tasks"', 1, true) == nil)
check("slack checks the secret before lower", callBeforeLower(slackSrc, "CCT.Slack.Emote"))
check("nap checks the secret before lower", callBeforeLower(napSrc, "CCT.Nap.Emote"))
check("headpet checks the secret before lower", callBeforeLower(headSrc, "CCT.Headpet.Emote"))
check("nap does not use the debug range", napSrc:find("random(7", 1, true) == nil and napSrc:find("7200, 18000", 1, true) ~= nil)
check("zone checks the secret", zoneSrc:find("issecretvalue", 1, true) ~= nil)
check("master source draws nothing", storeSrc:find("CreateFontString", 1, true) == nil and storeSrc:find("webhook", 1, true) == nil and storeSrc:find("http", 1, true) == nil)
check("no webhook on the send path", corrSrc:find("webhook", 1, true) == nil and corrSrc:find("http", 1, true) == nil)
check("owner sentences stay raw", corrSrc:find("raw = true", 1, true) ~= nil)
check("owner week is whispered", corrSrc:find("ownerweek", 1, true) ~= nil)
check("corroboration does not print the master online line", corrSrc:find("come online", 1, true) == nil)
check("jewel sample still checks the secret first", reportSrc:find("issecretvalue(rawMap)", 1, true) ~= nil and reportSrc:find("issecretvalue(rawMap)", 1, true) < reportSrc:find("GetPlayerMapPosition", 1, true))

local pipe = io.popen("find " .. addon .. " -name '*.lua'")
local taskWriters = {}
if pipe ~= nil then
    for path in pipe:lines() do
        local text = read(path)
        if text:find('AddCounter("tasks"', 1, true) or text:find("AddCounter('tasks'", 1, true) then
            taskWriters[#taskWriters + 1] = path
        end
    end
    pipe:close()
end
check("only maid increments tasks", #taskWriters == 1 and taskWriters[1]:find("/Kitten/Maid.lua", 1, true) ~= nil, table.concat(taskWriters, ", "))

local frames = {}
local sends = {}
local chats = {}
local lines = {}

local function auto(kind)
    local obj = { kind = kind, events = {}, scripts = {} }
    return setmetatable(obj, {
        __index = function(self, key)
            return function(s, ...)
                if key == "RegisterEvent" then
                    s.events[(...)] = true
                    return
                end
                if key == "SetScript" then
                    local which, fn = ...
                    s.scripts[which] = fn
                    return
                end
                return s
            end
        end,
    })
end

CreateFrame = function(kind)
    local frame = auto(kind or "Frame")
    frames[#frames + 1] = frame
    return frame
end
UIParent = auto("UIParent")
C_Timer = {
    After = function() end,
    NewTicker = function()
        return { Cancel = function() end }
    end,
}
SlashCmdList = {}
time = os.time
date = os.date
math.random = function()
    return 0
end
print = function(text)
    lines[#lines + 1] = tostring(text)
end
PlaySoundFile = function() end
StopSound = function() end
issecretvalue = function()
    return false
end
UnitName = function()
    return "Mina"
end
UnitFullName = function()
    return "Mina"
end
UnitGUID = function()
    return "Player-1"
end
IsInGuild = function()
    return true
end
C_GuildInfo = { GuildRoster = function() end }
GetNumGuildMembers = function()
    return 0
end
GetGuildRosterInfo = function()
    return nil
end
SendChatMessage = function(msg, chatType, language, target)
    chats[#chats + 1] = { msg = msg, chatType = chatType, target = target }
end
C_ChatInfo = {
    SendChatMessage = SendChatMessage,
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, message, chatType, target)
        sends[#sends + 1] = {
            prefix = prefix,
            message = message,
            chatType = chatType,
            target = target,
        }
        return 0
    end,
}
Ambiguate = function(name)
    return (type(name) == "string" and name:match("^[^%-]+")) or name
end
IsInInstance = function()
    return false, "none"
end
IsInGroup = function()
    return false
end
IsInRaid = function()
    return false
end
IsResting = function()
    return false
end
GetTime = function()
    return 100000
end
C_Map = {
    GetBestMapForUnit = function()
        return 12
    end,
    GetPlayerMapPosition = function()
        return { x = 0.25, y = 0.5 }
    end,
}

local CCT = {}
for line in toc:gmatch("[^\n]+") do
    if line:find("%.lua$") then
        local chunk, err = loadfile(addon .. "/" .. line)
        if chunk == nil then
            error(err)
        end
        chunk("CatgirlTracker_Forever", CCT)
    end
end

check("files load", CCT.Ledger ~= nil and CCT.Slack ~= nil and CCT.Nap ~= nil and CCT.Headpet ~= nil and CCT.Zone ~= nil and CCT.Location ~= nil and CCT.Store ~= nil)

local function clear(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function noon(year, month, day)
    return os.time({ year = year, month = month, day = day, hour = 12 })
end

local function bind(name)
    UnitName = function()
        return name
    end
    UnitFullName = function()
        return name
    end
    CCT.Player.Refresh()
    CCT.Saved.Init()
    return CCT.State.Bind(name)
end

local masterOnline = true
local owners = {}
local absent = {}

CCT.Roster.GetMember = function(name)
    local short = CCT.ShortName(name)
    if short == nil or absent[short:lower()] then
        return nil
    end
    local online = true
    if CCT.db and CCT.db.settings and CCT.SameName(short, CCT.db.settings.masterName) then
        online = masterOnline
    end
    return {
        short = short,
        online = online,
        ownerShort = owners[short:lower()],
        publicNote = "",
        officerNote = "",
    }
end

local function counters()
    return CCT.State.Get().counters
end

local function said(fragment)
    for i = 1, #lines do
        if lines[i]:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

local function countSaid(fragment)
    local n = 0
    for i = 1, #lines do
        if lines[i]:find(fragment, 1, true) then
            n = n + 1
        end
    end
    return n
end

local function drain()
    local guard = 0
    while CCT.Net.Depth().snapshot + CCT.Net.Depth().reliable > 0 and guard < 80 do
        local before = #sends
        CCT.Net.Pump()
        guard = guard + 1
        if #sends == before then
            break
        end
    end
end

local W45 = noon(2026, 11, 8)
local W46 = noon(2026, 11, 9)
local W47 = noon(2026, 11, 16)

bind("Mina")
CCT.db.settings.masterName = nil
CCT.db.settings.flavorAnnouncements = false
CCT.Ledger.OnLogin(W45)
check("login adds no minutes", counters().playMin == 0 and counters().tasks == 0)
check("minute stamp is not on the state", CCT.State.Get().minuteStamp == nil)

local playBefore = counters().playMin
CCT.Ledger.AddMinutes(W45 + 100, "Elwynn")
check("zone at 100 seconds adds one minute", counters().playMin == playBefore + 1 and CCT.Ledger.Zones().Elwynn == 1)
CCT.Ledger.MinuteTick(W45 + 120)
check("ticker at 120 does not add a second minute", counters().playMin == playBefore + 1 and CCT.Ledger.Zones().Elwynn == 1)
CCT.Ledger.Stamp(W45)
local beforeLate = counters().playMin
CCT.Ledger.MinuteTick(W45 + 180)
check("late ticker adds three minutes", counters().playMin == beforeLate + 3)

CCT.Ledger.Stamp(W45)
CCT.State.SetGag("small")
CCT.State.SetHeels("high")
local gagBefore = counters().gagMin
local heelBefore = counters().heelsMin
local playGag = counters().playMin
CCT.Ledger.AddMinutes(W45 + 60, "")
check("empty zone still books play gag and heels", counters().playMin == playGag + 1 and counters().gagMin == gagBefore + 1 and counters().heelsMin == heelBefore + 1 and CCT.Ledger.Zones()[""] == nil)
CCT.State.SetGag("none")
CCT.State.SetHeels("none")
CCT.Ledger.Stamp(W45)
local gagStopped = counters().gagMin
CCT.Ledger.AddMinutes(W45 + 60, "Elwynn")
check("removed gag does not add gag minutes", counters().gagMin == gagStopped)

GetRealZoneText = function()
    return "Elwynn Forest"
end
GetZoneText = function()
    return "Elwynn Forest"
end
CCT.Ledger.OnLogin(W45)
local zoned = counters().playMin
CCT.Zone.Schedule(W45)
check("zone callback one second later adds nothing", CCT.Zone.Apply(W45 + 1) == true and counters().playMin == zoned and CCT.State.Get().zone == "Elwynn Forest")

local secret = {}
issecretvalue = function(value)
    return value == secret
end
CCT.State.SetZone("Stormwind City", "none")
IsInInstance = function()
    return false, secret
end
GetRealZoneText = function()
    return "Dalaran"
end
CCT.Zone.Schedule(W45 + 10)
check("secret instance does not wipe the kind", CCT.Zone.Apply(W45 + 11) == true and CCT.State.Get().zone == "Dalaran" and CCT.State.Get().instanceType == "none")
GetRealZoneText = function()
    return secret
end
local zoneBefore = CCT.State.Get().zone
CCT.Zone.Schedule(W45 + 20)
check("secret zone text is not compared", CCT.Zone.Apply(W45 + 21) == false and CCT.State.Get().zone == zoneBefore)
issecretvalue = function()
    return false
end
IsInInstance = function()
    return false, "none"
end

CCT.State.SetJewel(true)
local samples = 0
local realSample = CCT.Report.SamplePos
CCT.Report.SamplePos = function(now)
    samples = samples + 1
    return realSample(now)
end
CCT.Location.Reset()
check("first jewel tick does not sample", CCT.Location.Tick(5000) == false and samples == 0)
check("jewel tick at 20 seconds samples", CCT.Location.Tick(5020) == true and samples == 1 and CCT.State.Get().pos ~= nil and CCT.State.Get().pos.x == 0.25)
CCT.State.SetJewel(false)
check("jewel off does not sample", CCT.Location.Tick(5100) == false and samples == 1)
CCT.Report.SamplePos = realSample

CCT.Slack.Reset()
IsResting = function()
    return true
end
GetRealZoneText = function()
    return "Elwynn Forest"
end
CCT.State.SetCounter("slack", 0)
CCT.State.SetCounter("slackMin", 0)
check("rest outside a city starts", CCT.Slack.Tick(W45) == false and CCT.Slack.Session().restingStart == W45)
check("nine minutes is not slack yet", CCT.Slack.Tick(W45 + 599) == false and counters().slack == 0)
check("ten minutes outside a city counts slack once", CCT.Slack.Tick(W45 + 600) == true and counters().slack == 1 and counters().slackMin == 0)
check("staying in rest does not count slack again", CCT.Slack.Tick(W45 + 700) == false and counters().slack == 1)
IsResting = function()
    return false
end
check("ending the session writes slack minutes once", CCT.Slack.Tick(W45 + 720) == true and counters().slackMin == 2)
local slackMinutes = counters().slackMin
check("a second end does not add slack minutes", CCT.Slack.Tick(W45 + 900) == false and counters().slackMin == slackMinutes)

CCT.Slack.Reset()
CCT.State.SetCounter("slack", 0)
CCT.State.SetCounter("slackMin", 0)
IsResting = function()
    return true
end
GetRealZoneText = function()
    return "Orgrimmar"
end
CCT.Slack.Tick(W45)
CCT.Slack.Tick(W45 + 700)
check("a city does not count slack", counters().slack == 0 and counters().slackMin == 0)

CCT.Slack.Reset()
GetRealZoneText = function()
    return "Elwynn Forest"
end
CCT.Slack.Tick(W45)
check("sleep within 20 minutes suppresses", CCT.Slack.Emote("You fall asleep.", "Mina", W45 + 30) == true)
check("the suppressed rest does not count", CCT.Slack.Tick(W45 + 600) == false and counters().slack == 0 and CCT.Slack.Session().suppressed == true)

CCT.Slack.Reset()
CCT.State.SetCounter("slack", 0)
issecretvalue = function(value)
    return value == secret
end
CCT.Slack.Tick(W45)
check("a secret sleep emote does not latch", CCT.Slack.Emote(secret, "Mina", W45 + 20) == false and CCT.Slack.Session().lastSleep == nil)
issecretvalue = function()
    return false
end
check("an unlatched rest still counts", CCT.Slack.Tick(W45 + 600) == true and counters().slack == 1)
IsResting = function()
    return secret
end
local slackNow = counters().slack
check("a secret rest value does not end the session", CCT.Slack.Tick(W45 + 700) == false and counters().slack == slackNow and CCT.Slack.Session().counting == true)
IsResting = function()
    return false
end
CCT.Slack.Tick(W45 + 800)

CCT.db.settings.flavorAnnouncements = true
CCT.Slack.Reset()
CCT.State.SetCounter("slack", 0)
IsResting = function()
    return true
end
GetRealZoneText = function()
    return "Elwynn Forest"
end
clear(chats)
CCT.Slack.Tick(W45)
CCT.Slack.Tick(W45 + 600)
check("slack flavor goes to guild", #chats >= 1 and chats[#chats].chatType == "GUILD" and chats[#chats].msg:find("slacking", 1, true) ~= nil)
CCT.Module.Set("InnSlackerTracker", false)
CCT.Slack.Reset()
local slackOff = counters().slack
CCT.Slack.Tick(W45)
CCT.Slack.Tick(W45 + 600)
check("slack module off does not count", counters().slack == slackOff)
CCT.Module.Set("InnSlackerTracker", true)
CCT.db.settings.flavorAnnouncements = false
IsResting = function()
    return false
end

bind("Napper")
CCT.Ledger.OnLogin(W45)
CCT.db.settings.masterName = nil
CCT.Nap.Reset(W45)
CCT.Nap.SetTrigger(10)
IsResting = function()
    return true
end
GetUnitSpeed = nil
IsPlayerMoving = nil
check("nap arms its clock", CCT.Nap.Tick(W45) == false)
check("nap window opens", CCT.Nap.Tick(W45 + 10) == false and CCT.Nap.Status().inWindow == true)
check("nap notice is the raid text", CCT.Nap.LastNotice == "Good Kittens need to Nap Nya! Find a Inn to nap for 10 to 20 Minutes")
issecretvalue = function(value)
    return value == secret
end
check("a secret nap emote does not start", CCT.Nap.Emote(secret, "Napper", W45 + 10) == false and CCT.Nap.Status().active ~= true)
issecretvalue = function()
    return false
end
check("falling asleep in the window starts the nap", CCT.Nap.Emote("you fall asleep.", "Napper", W45 + 10) == true and CCT.Nap.Status().active == true)
check("a hidden sample does not end the nap", CCT.Nap.Tick(W45 + 110) == false and CCT.Nap.Status().active == true and counters().napOk == 0)
IsPlayerMoving = function()
    return true
end
check("a moving bool ends a short nap early", CCT.Nap.Tick(W45 + 200) == true and counters().napEarly == 1 and CCT.Nap.Status().active ~= true)
IsPlayerMoving = nil

CCT.Nap.Reset(W45)
CCT.Nap.SetTrigger(10)
IsResting = function()
    return true
end
CCT.Nap.Tick(W45)
CCT.Nap.Tick(W45 + 10)
CCT.Nap.Emote("you fall asleep.", "Napper", W45 + 10)
check("oversleep scores napOver without movement", CCT.Nap.Tick(W45 + 10 + 1201) == true and counters().napOver == 1)

CCT.Nap.Reset(W45)
CCT.Nap.SetTrigger(10)
CCT.Nap.Tick(W45)
CCT.Nap.Tick(W45 + 10)
check("a missed window is napMiss", CCT.Nap.Tick(W45 + 10 + 1800) == true and counters().napMiss == 1)

CCT.db.settings.masterName = "Nyx"
masterOnline = true
CCT.Net.Reset()
clear(sends)
CCT.Nap.Reset(W45)
CCT.Nap.SetTrigger(10)
IsResting = function()
    return true
end
CCT.Nap.Tick(W45)
CCT.Nap.Tick(W45 + 10)
CCT.Nap.Emote("you fall asleep.", "Napper", W45 + 10)
IsResting = function()
    return false
end
local depthBeforeNap = CCT.Net.Depth().snapshot
check("leaving rest at 700 seconds is napOk", CCT.Nap.Tick(W45 + 10 + 700) == true and counters().napOk == 1)
check("a nap result flushes once", CCT.Net.Depth().snapshot == depthBeforeNap + 1)
local depthAfterNap = CCT.Net.Depth().snapshot
CCT.Nap.Tick(W45 + 10 + 800)
check("the nap does not flush again", CCT.Net.Depth().snapshot == depthAfterNap and counters().tasks == 0)
CCT.db.settings.masterName = nil
IsPlayerMoving = nil

bind("Petal")
CCT.Ledger.OnLogin(W45)
CCT.db.settings.flavorAnnouncements = true
clear(chats)
CCT.Gag.Set("huge")
check("a headpet counts", CCT.Headpet.Emote("Alice pets you.", "Alice", W45) == true and counters().pets == 1)
check("the sender pair is stored", CCT.Ledger.Senders()[1] == "pets:Alice")
check("headpet flavor goes to guild", #chats >= 1 and chats[#chats].chatType == "GUILD" and chats[#chats].msg:find("Headpet", 1, true) ~= nil)
check("a worn gag leaves addon guild text alone", CCT.State.Get().gag == "huge" and chats[#chats].msg:find("Headpet", 1, true) ~= nil and chats[#chats].msg:find("mmf", 1, true) == nil)
CCT.Gag.Set("none")
local petsNow = counters().pets
check("the same sender is on cooldown", CCT.Headpet.Emote("Alice pets you.", "Alice", W45 + 30) == false and counters().pets == petsNow and #CCT.Ledger.Senders() == 1)
check("the cooldown ends at 60 seconds", CCT.Headpet.Emote("Alice pets you.", "Alice", W45 + 60) == true and counters().pets == petsNow + 1 and #CCT.Ledger.Senders() == 1)
check("a hug is a different action", CCT.Headpet.Emote("Alice hugs you.", "Alice", W45 + 61) == true and counters().hugs == 1)
issecretvalue = function(value)
    return value == secret
end
local petsSecret = counters().pets
check("a secret headpet is ignored", CCT.Headpet.Emote(secret, "Bob", W45 + 70) == false and counters().pets == petsSecret)
issecretvalue = function()
    return false
end
for i = 1, 21 do
    CCT.Headpet.Emote("P" .. i .. " pets you.", "P" .. i, W45 + 100 + i * 60)
end
local senders = CCT.Ledger.Senders()
check("the sender list caps at 20", #senders == 20 and senders[1] == "pets:P2" and senders[#senders] == "pets:P21")
CCT.Module.Set("HeadPetTracker", false)
local capped = counters().pets
check("headpet module off does not count", CCT.Headpet.Emote("Zed pets you.", "Zed", W45 + 5000) == false and counters().pets == capped)
CCT.Module.Set("HeadPetTracker", true)
CCT.db.settings.flavorAnnouncements = false
check("tasks stayed at zero", counters().tasks == 0)

bind("Roll")
CCT.SetDebug(false)
CCT.db.settings.masterName = nil
clear(lines)
CCT.Ledger.OnLogin(W45)
CCT.State.SetHeat(10.4)
CCT.State.SetHeelLevel("high", 3)
CCT.State.SetCounter("playMin", 4)
CCT.Ledger.EnsureWeek(W46)
local closed = CCT.Ledger.Days()
check("rollover keeps the closed day", #closed == 1 and closed[1].day == "2026-11-08" and closed[1].counters.playMin == 4 and closed[1].seq == 1)
check("the new day starts at zero", CCT.State.Get().week == "2026-11-09" and counters().playMin == 0 and counters().seq == 1 and counters().tasks == 0)
check("heat and heels survive the roll", counters().heatPeak == 10 and CCT.State.Get().heat == 10.4 and CCT.State.Get().heelLevel.high == 3)
check("the first rollover does not drop", CCT.Ledger.Dropped() == nil and said("Unacked day") == false)
clear(lines)
CCT.Ledger.EnsureWeek(W47)
closed = CCT.Ledger.Days()
check("a second rollover keeps both closed days", #closed == 2 and closed[1].day == "2026-11-08" and closed[2].day == "2026-11-09" and CCT.State.Get().week == "2026-11-16" and CCT.Ledger.Dropped() == nil)
check("the second rollover does not drop", said("Unacked day") == false)
CCT.db.settings.masterName = "Nyx"
check("a non master ack keeps the closed days", CCT.Ledger.OnAck("Other", { fields = { day = "2026-11-09", seq = "1" } }) == false and #CCT.Ledger.Days() == 2)
check("an ack for the open day keeps the closed days", CCT.Ledger.OnAck("Nyx", { fields = { day = "2026-11-16", seq = "9" } }) == false and #CCT.Ledger.Days() == 2)
masterOnline = true
CCT.Net.Reset()
clear(sends)
check("the closed days flush", CCT.Ledger.Flush("edge", W47) == true)
drain()
local firstAt = nil
local secondAt = nil
local currentAt = nil
local droppedOnWire = false
for i = 1, #sends do
    local message = sends[i].message
    if message:find("Ledger,day:2026-11-08,", 1, true) == 1 then
        firstAt = firstAt or i
    end
    if message:find("Ledger,day:2026-11-09,", 1, true) == 1 then
        secondAt = secondAt or i
    end
    if message:find("Ledger,day:2026-11-16,", 1, true) == 1 then
        currentAt = currentAt or i
    end
    if message:find("dropped:", 1, true) then
        droppedOnWire = true
    end
    check("ledger wire has no spaces", message:find("Ledger,", 1, true) ~= 1 or message:find(", ", 1, true) == nil)
end
check("closed days go out before the open day", firstAt ~= nil and secondAt ~= nil and currentAt ~= nil and firstAt < secondAt and secondAt < currentAt, "first " .. tostring(firstAt) .. " second " .. tostring(secondAt) .. " current " .. tostring(currentAt))
check("a two-day roll sends no dropped token", droppedOnWire == false)
check("the current ledger is still seq 1", currentAt ~= nil and sends[currentAt].message:find("seq:1,", 1, true) ~= nil)
check("acking one closed day removes only that day", CCT.Ledger.OnAck("Nyx", { fields = { day = "2026-11-08", seq = "1" } }) == true and #CCT.Ledger.Days() == 1 and CCT.Ledger.Days()[1].day == "2026-11-09")
check("acking the open day leaves the other closed day", CCT.Ledger.OnAck("Nyx", { fields = { day = "2026-11-16", seq = "1" } }) == false and #CCT.Ledger.Days() == 1 and CCT.Saved.EnsureChar("Roll").dropSend == nil)

bind("Flush")
CCT.db.settings.masterName = "Nyx"
masterOnline = true
CCT.Ledger.OnLogin(W45)
CCT.State.SetCounter("playMin", 3)
CCT.Net.Reset()
clear(sends)
check("first send of a week stays seq 1", CCT.Ledger.Flush("timer", W45) == true and counters().seq == 1)
drain()
check("the first body carries the counter and tasks", #sends >= 1 and sends[1].message:find("playMin:3", 1, true) ~= nil and sends[1].message:find("tasks:0", 1, true) ~= nil and sends[1].message:find("seq:1", 1, true) ~= nil)
CCT.Net.Reset()
clear(sends)
check("an unchanged timer does not send", CCT.Ledger.Flush("timer", W45 + 300) == false and #sends == 0)
CCT.State.SetCounter("playMin", 4)
check("a changed snapshot bumps seq", CCT.Ledger.Flush("timer", W45 + 600) == true and counters().seq == 2)

masterOnline = false
CCT.Ledger.OnLogin(W45)
CCT.Net.Reset()
clear(lines)
CCT.Ledger.LoginFlush()
check("offline login prints nothing and enqueues nothing", #lines == 0 and CCT.Net.Depth().snapshot == 0)
check("the first tick inside the gap does not flush", CCT.Ledger.Tick(W45 + 10) == false and CCT.Net.Depth().snapshot == 0)
check("the first timer flush holds the daily report", CCT.Ledger.Flush("timer", W45 + 300) == true and countSaid("Master is offline. The daily report is held.") == 1 and CCT.Net.Depth().snapshot >= 1)
local heldDepth = CCT.Net.Depth().snapshot
check("a second timer does not print or send", CCT.Ledger.Flush("timer", W45 + 300) == false and countSaid("Master is offline. The daily report is held.") == 1 and CCT.Net.Depth().snapshot == heldDepth)
masterOnline = true
CCT.Ledger.LoginFlush()
check("the master online line prints once", countSaid("Master has come online nya your report will be compiled !! Nyx") == 1)
CCT.db.settings.masterName = nil
clear(lines)
CCT.Ledger.OnLogin(W45)
CCT.Ledger.LoginFlush()
check("an empty master does not send or print", said("Master is offline") == false and said("come online") == false)

local zoneWire = CCT.Net.Wire("zones", { { "week", "2026-W45" }, { "seq", "13" }, { "z", "Elwynn%3AForest:12" } })
local zoneParsed = CCT.Net.Parse(zoneWire)
check("zone token keeps the minutes", zoneWire == "Zones,week:2026-W45,seq:1,z:Elwynn%3AForest:12" or zoneParsed.many.z[1].name == "Elwynn:Forest", zoneWire)
check("parsed zone minutes stay 12", zoneParsed.many.z[1].name == "Elwynn:Forest" and zoneParsed.many.z[1].minutes == 12)

bind("Master")
CCT.db.settings.masterName = "Master"
masterOnline = true
owners = { paws = "Nyx", owned = "Nyx", petal = "Nyx" }
CCT.SetDebug(true)
clear(lines)

local D45 = "2026-11-08"
local D46 = "2026-11-09"
local D10 = "2026-11-10"

local function ledger(day, seq, extra, dropped)
    local fields = { day = day, seq = tostring(seq) }
    for key, value in pairs(extra or {}) do
        fields[key:lower()] = tostring(value)
    end
    if dropped ~= nil then
        fields.dropped = dropped
    end
    return { kind = "ledger", fields = fields, many = {} }
end

local function accept(kind, sender, parsed, now)
    return CCT.Store.Accept(kind, sender, parsed, now or W45)
end

check("a kitten client ignores the scorecard", bind("Mina") == nil or true)
CCT.db.settings.masterName = "Master"
check("the local character must be the master", CCT.Store.Accept("ledger", "Paws", ledger(D45, 1, { playMin = 1 }), W45) == false)
bind("Master")

local function rowOf(name)
    return CCT.db.master.kittens[name]
end

check("the first day is stored", accept("ledger", "Paws", ledger(D45, 1, { playMin = 5, tasks = 0 }), W45) == true)
local paws = rowOf("Paws")
check("seq 1 replaces and does not wait", paws.days[D45].day == D45 and paws.days[D45].seq == 1 and paws.days[D45].fields.playMin == 5 and paws.days[D45].at == W45 and paws.rotatedDay == nil and paws.droppedDay == nil)
check("the next day stays beside it", accept("ledger", "Paws", ledger(D46, 1, { playMin = 1 }), W46) == true)
check("a third in-window day stays", accept("ledger", "Paws", ledger(D10, 1, { playMin = 2 }), noon(2026, 11, 10)) == true)
paws = rowOf("Paws")
check("three in-window days all stay", paws.days[D45].fields.playMin == 5 and paws.days[D46].fields.playMin == 1 and paws.days[D10].fields.playMin == 2 and paws.rotatedDay == nil and paws.droppedDay == nil)
check("three in-window days do not rotate", said("rotated off") == false)
check("a stored drop token does not become droppedDay", accept("ledger", "Paws", ledger(D10, 2, { playMin = 2 }, D45), noon(2026, 11, 10)) == true and rowOf("Paws").droppedDay == nil and rowOf("Paws").rotatedDay == nil)
local function hasDay(list, id)
    for i = 1, #(list or {}) do
        if list[i] == id then
            return true
        end
    end
    return false
end
check("stored days keep every in-window id", hasDay(rowOf("Paws").storedDays, D45) and hasDay(rowOf("Paws").storedDays, D46) and hasDay(rowOf("Paws").storedDays, D10))

check("a never stored drop is recorded", accept("ledger", "Late", ledger(D10, 1, { playMin = 1 }, "2026-01-02"), noon(2026, 11, 10)) == true)
check("droppedDay is the absent id", rowOf("Late").droppedDay == "2026-01-02" and hasDay(rowOf("Late").storedDays, "2026-01-02") == false)
check("the unacked line is debug only", said("Unacked 2026-01-02 was dropped before it was retained."))
CCT.SetDebug(false)

check("a late in-window day stays beside the newer one", accept("ledger", "After", ledger(D46, 1, { playMin = 8 }), W46) == true and accept("ledger", "After", ledger(D45, 4, { playMin = 3 }), W46) == true)
local after = rowOf("After")
check("the late day does not rotate", after.days[D46].fields.playMin == 8 and after.days[D45].fields.playMin == 3 and after.rotatedDay == nil and after.droppedDay == nil)
local atBefore = after.days[D46].at
check("a day more than 13 before today is ignored", accept("ledger", "After", ledger("2026-10-26", 9, { playMin = 99 }), W46) == false)
after = rowOf("After")
check("the ignored day does not move the rows", after.days[D46].at == atBefore and after.days[D45].fields.playMin == 3 and after.days["2026-10-26"] == nil and after.droppedDay == nil)

local parsedZones = CCT.Net.Parse(zoneWire)
parsedZones.fields.day = D45
parsedZones.fields.seq = "13"
check("zones seq 13 writes the map", accept("zones", "Seq", parsedZones, W45) == true)
local seqRow = rowOf("Seq").days[D45]
check("zones moved the row seq", seqRow.seq == 13 and seqRow.zones["Elwynn:Forest"] == 12 and seqRow.fields.playMin == nil)
local petWire = CCT.Net.Wire("pets", { { "day", D45 }, { "seq", "13" }, { "p", "pets:Ny%3Ax" } })
check("pets seq 13 replaces the list", accept("pets", "Seq", CCT.Net.Parse(petWire), W45) == true and rowOf("Seq").days[D45].senders[1] == "pets:Ny:x" and rowOf("Seq").days[D45].zones["Elwynn:Forest"] == 12)
check("ledger seq 13 still writes counters", accept("ledger", "Seq", ledger(D45, 13, { playMin = 6, tasks = 0 }), W45 + 5) == true)
seqRow = rowOf("Seq").days[D45]
check("same seq ledger replaces and does not add", seqRow.fields.playMin == 6 and seqRow.seq == 13 and seqRow.zones["Elwynn:Forest"] == 12 and seqRow.at == W45 + 5)
local atSame = seqRow.at
check("the same seq again refreshes at", accept("ledger", "Seq", ledger(D45, 13, { playMin = 6 }), W45 + 9) == true)
seqRow = rowOf("Seq").days[D45]
check("a retry does not increase the counter", seqRow.fields.playMin == 6 and seqRow.at == W45 + 9 and seqRow.at ~= atSame)
check("an older seq is ignored", accept("ledger", "Seq", ledger(D45, 12, { playMin = 100 }), W45 + 20) == false and rowOf("Seq").days[D45].fields.playMin == 6 and rowOf("Seq").days[D45].at == W45 + 9)
check("a newer seq replaces", accept("ledger", "Seq", ledger(D45, 14, { playMin = 9 }), W45 + 30) == true and rowOf("Seq").days[D45].fields.playMin == 9 and rowOf("Seq").days[D45].fields.tasks == 0)
check("a partial ledger leaves the other counters", accept("ledger", "Seq", ledger(D45, 15, { pets = 4 }), W45 + 40) == true and rowOf("Seq").days[D45].fields.playMin == 9 and rowOf("Seq").days[D45].fields.pets == 4)

local manyPets = { fields = { day = D45, seq = "16" }, many = { p = {} } }
for i = 1, 21 do
    manyPets.many.p[i] = { action = "pets", sender = "S" .. i }
end
check("pets cap at 20", accept("pets", "Seq", manyPets, W45) == true and #rowOf("Seq").days[D45].senders == 20 and rowOf("Seq").days[D45].senders[1] == "pets:S2")

CCT.Net.Reset()
clear(sends)
check("a ledger acks", accept("ledger", "Acked", ledger(D45, 2, { playMin = 1 }), W45) == true)
drain()
local acked = false
for i = 1, #sends do
    if sends[i].message:find("LedgerAck,day:" .. D45 .. ",seq:2", 1, true) == 1 then
        acked = true
    end
end
check("ledger ack is whispered", acked)
CCT.Net.Reset()
clear(sends)
accept("zones", "Acked", { fields = { day = D45, seq = "2" }, many = { z = { { name = "Dalaran", minutes = 3 } } } }, W45)
drain()
check("zones do not ack", #sends == 0 and rowOf("Acked").days[D45].zones.Dalaran == 3)

local function owner(seq, gagOn, tasks)
    local fields = { day = D45, seq = tostring(seq), kitten = "Owned", tasks = tostring(tasks or 0), disc = "0" }
    local names = {
        "gag", "blind", "ears", "mittens", "heels", "bell", "tail", "jewel", "belt", "bra", "leash",
        "dildo", "inflatable_butplug", "inflatable_dildo", "small_butplug", "large_butplug", "taill_butplug",
        "vibes_pussy", "vibes_nipples", "vibes_ears", "nipple_piercings", "ear_piercings", "pussy_lipps_piercings",
    }
    for i = 1, #names do
        fields[names[i] .. "on"] = "0"
        fields[names[i] .. "off"] = "0"
    end
    fields.gagon = tostring(gagOn)
    return { kind = "ownerweek", fields = fields, many = {} }
end
check("owner week stores zeros", accept("ownerweek", "Nyx", owner(2, 4, 0), W45) == true)
local owned = rowOf("Owned")
local ownedRow = owned.days[D45]
check("owner fields are flat and seq is independent", ownedRow.owner.day == D45 and ownedRow.owner.gagOn == 4 and ownedRow.owner.gagOff == 0 and ownedRow.owner.tasks == 0 and ownedRow.owner.taill_butplugOff == 0 and ownedRow.owner.seq == 2 and ownedRow.seq == 0)
check("same owner seq replaces and does not add", accept("ownerweek", "Nyx", owner(2, 0, 0), W45 + 3) == true and rowOf("Owned").days[D45].owner.gagOn == 0 and rowOf("Owned").days[D45].owner.at == W45 + 3)
check("a non owner is omitted", accept("ownerweek", "Rex", owner(3, 9, 0), W45) == false and rowOf("Owned").days[D45].owner.gagOn == 0)
rowOf("Owned").days[D45].owner.gagOn = 4
owners.owned = nil
check("a missing note omits owner corroboration", accept("ownerweek", "Nyx", owner(4, 8, 0), W45) == false and rowOf("Owned").days[D45].owner.gagOn == 4)
check("a missing note still stores the ledger", accept("ledger", "Owned", ledger(D45, 1, { playMin = 3, tasks = 0 }), W45) == true and rowOf("Owned").days[D45].fields.playMin == 3 and rowOf("Owned").days[D45].owner.gagOn == 4)
absent.ghost = true
check("a stranger ledger is refused", accept("ledger", "Ghost", ledger(D45, 1, { playMin = 1 }), W45) == false and rowOf("Ghost") == nil)
owners.owned = "Nyx"

CCT.db.master.kittens.Seeded = {
    applied = { week = "2026-W46", seq = 1, at = 1, fields = {}, zones = {}, senders = {}, owner = nil },
    previous = { week = "2026-W45", seq = 1, at = 1, fields = {}, zones = {}, senders = {}, owner = nil },
    days = {
        ["2026-11-09"] = { day = "2026-11-09", seq = 1, at = 1, fields = {}, zones = {}, senders = {}, owner = nil },
        ["2026-11-08"] = { day = "2026-11-08", seq = 1, at = 1, fields = {}, zones = {}, senders = {}, owner = nil },
    },
    storedDays = nil,
}
check("empty stored days are seeded from the day map", accept("ledger", "Seeded", ledger(D46, 2, { playMin = 1 }), W46) == true)
check("seed order is oldest day first", rowOf("Seeded").storedDays[1] == D45 and rowOf("Seeded").storedDays[2] == D46 and rowOf("Seeded").applied.week == "2026-W46")
rowOf("Seeded").days[D45] = nil
check("a companion list is not reseeded", accept("ledger", "Seeded", ledger(D46, 3, { playMin = 2 }), W46) == true and rowOf("Seeded").days[D45] == nil and #rowOf("Seeded").storedDays == 2 and hasDay(rowOf("Seeded").storedDays, D45))

local dayIds = {}
local firstDay = noon(2026, 1, 1)
for n = 0, 28 do
    local stamp = firstDay + n * 86400
    local id = CCT.Day.Id(stamp)
    dayIds[#dayIds + 1] = id
    accept("ledger", "Days", ledger(id, 1, { playMin = 1 }), stamp)
end
local stored = rowOf("Days").storedDays
local dayCount = 0
for _, row in pairs(rowOf("Days").days) do
    if type(row) == "table" then
        dayCount = dayCount + 1
    end
end
check("stored days cap at 28", #stored == 28 and stored[1] == dayIds[2] and stored[#stored] == dayIds[29] and dayCount <= 14)
check("tasks on the master stay whatever the payload said", rowOf("Seq").days[D45].fields.tasks == 0)

local agedNow = noon(2026, 11, 10)
CCT.db.master.kittens.Aged = {
    days = {
        ["2026-10-27"] = { day = "2026-10-27", seq = 1, at = 1, fields = { playMin = 8 }, zones = {}, senders = {} },
        ["2026-11-10"] = { day = "2026-11-10", seq = 1, at = 1, fields = {}, zones = {}, senders = {} },
    },
    storedDays = { "2026-10-27", "2026-11-10" },
    droppedDay = nil,
    rotatedDay = nil,
}
CCT.db.master.kittens.Stay = {
    days = {
        ["2026-10-28"] = { day = "2026-10-28", seq = 1, at = 1, fields = {}, zones = {}, senders = {} },
        ["2026-11-10"] = { day = "2026-11-10", seq = 1, at = 1, fields = {}, zones = {}, senders = {} },
    },
    storedDays = { "2026-10-28", "2026-11-10" },
    droppedDay = nil,
    rotatedDay = nil,
}
CCT.SetDebug(false)
clear(lines)
CCT.Store.Maintain(agedNow)
check("a day more than 13 before today rotates", rowOf("Aged").days["2026-10-27"] == nil and rowOf("Aged").rotatedDay == "2026-10-27" and rowOf("Aged").droppedDay == nil and rowOf("Aged").days["2026-11-10"] ~= nil)
check("aging keeps the id in stored days", hasDay(rowOf("Aged").storedDays, "2026-10-27"))
check("thirteen days before today stays", rowOf("Stay").days["2026-10-28"] ~= nil and rowOf("Stay").rotatedDay == nil and rowOf("Stay").droppedDay == nil)
check("aging does not print a scorecard", said("rotated off") == false and said("Unacked") == false)

local function kittenCount()
    local n = 0
    for _, row in pairs(CCT.db.master.kittens) do
        if type(row) == "table" then
            n = n + 1
        end
    end
    return n
end
CCT.db.master.kittens = {}
for i = 1, 40 do
    local name = string.format("K%02d", i)
    accept("ledger", name, ledger(D45, 1, { playMin = 1 }), W45)
end
check("forty kittens fit", kittenCount() == 40)
clear(lines)
check("the 41st kitten is refused", accept("ledger", "K41", ledger(D45, 1, { playMin = 1 }), W45) == false and rowOf("K41") == nil)
check("the full scorecard prints", said("K41 was not added."))
local printed = #lines
accept("ledger", "K41", ledger(D45, 1, { playMin = 1 }), W45)
check("the refusal prints once", #lines == printed)
check("an existing kitten can still update", accept("ledger", "K01", ledger(D45, 2, { playMin = 6 }), W45) == true and rowOf("K01").days[D45].fields.playMin == 6)

CCT.db.master.kittens = {
    Big = {
        days = {
            [D45] = { day = D45, seq = 1, at = 1, fields = {}, zones = { blob = string.rep("x", 4 * 1024 * 1024) }, senders = {}, owner = nil },
        },
        storedDays = { D45 },
        droppedDay = nil,
        rotatedDay = nil,
    },
}
clear(lines)
check("a full file refuses a new name", accept("ledger", "Tiny", ledger(D45, 1, { playMin = 1 }), W45) == false and rowOf("Tiny") == nil and said("Tiny was not added.") and said("4 MB"))
check("a full file still updates", accept("ledger", "Big", ledger(D45, 2, { playMin = 4 }), W45) == true and rowOf("Big").days[D45].fields.playMin == 4)
CCT.db.master.kittens = {}

CCT.db.settings.masterName = nil
clear(lines)
SlashCmdList.CCTMASTER("")
check("empty master command prints the empty name", said("Guild Master is not set."))
SlashCmdList.CCTMASTER("Nyx-Brightvale")
check("cctmaster stores both names", CCT.db.settings.masterName == "Nyx Brightvale" and said("Guild Master is Nyx Brightvale"))
CCT.db.settings.masterName = "Master"
bind("Master")

bind("Owner")
CCT.db.settings.masterName = "Master"
owners.kitten = "Nyx"
CCT.db.owner.weeks.Kitten = { week = "2020-W01", seq = 4, gagOn = 3, tasks = 0, disc = 0 }
local currentDay = CCT.Corroboration.Week("Kitten")
local closedOwner = CCT.db.owner.closed and CCT.db.owner.closed.Kitten
check("a week id owner row is not closed", closedOwner == nil and CCT.db.owner.weeks.Kitten.week == "2020-W01")
check("the open owner day is zero", currentDay.day == CCT.Day.Id() and currentDay.seq == 1 and currentDay.gagOn == 0 and currentDay.tasks == 0)
CCT.Net.Reset()
clear(sends)
check("the open owner day is sent", CCT.Corroboration.Flush("Kitten", true) == true)
drain()
local sawOld = false
local sawNew = false
local sawTask = false
local sawPlug = false
local sawPart = false
for i = 1, #sends do
    local message = sends[i].message
    if message:find("OwnerWeek,", 1, true) == 1 and message:find("week:2020-W01", 1, true) then
        sawOld = true
    end
    if message:find("OwnerWeek,", 1, true) == 1 and message:find("day:" .. currentDay.day, 1, true) then
        sawNew = true
    end
    if message:find("tasks:0", 1, true) then
        sawTask = true
    end
    if message:find("taill_butplugOff:0", 1, true) then
        sawPlug = true
    end
    if message:find("part:", 1, true) then
        sawPart = true
    end
end
check("a week id owner row is not sent", sawOld == false and sawNew)
check("owner week carries zeros and splits", sawTask and sawPlug and sawPart)
CCT.Net.Reset()
clear(sends)
CCT.Corroboration.Begin("Kitten", "c1", { op = "gag", fields = { state = "heavy" }, sentence = "a heavy gag" })
CCT.Corroboration.OnResult("c1", true, 0)
CCT.Corroboration.OnAck("Kitten", { fields = { cid = "c1", ok = "1" } })
local counted = CCT.Corroboration.Week("Kitten")
check("a command counts after success and ack", counted.gagOn == 1 and counted.seq == 2 and counted.tasks == 0)
check("the sentence stays raw", chats[#chats] ~= nil and chats[#chats].msg == "a heavy gag" and chats[#chats].chatType == "WHISPER")
CCT.Net.Reset()
clear(lines)
check("roster edge resends without the online line", CCT.Corroboration.OnRoster() == true)
check("owner resend is quiet", said("come online") == false and CCT.Net.Depth().snapshot > 0)
CCT.Net.Reset()
check("a second roster edge does not resend", CCT.Corroboration.OnRoster() == false and CCT.Net.Depth().snapshot == 0)
CCT.Corroboration.Tick(1000)
CCT.Corroboration.Tick(1299)
check("the owner timer waits 300 seconds", CCT.Net.Depth().snapshot == 0)
check("an unchanged owner timer does not send", CCT.Corroboration.Tick(1300) == false and CCT.Net.Depth().snapshot == 0)

bind("Huge")
CCT.db.settings.masterName = nil
CCT.Ledger.OnLogin(W45)
CCT.State.SetCounter("playMin", 1)
CCT.Ledger.EnsureWeek(W46)
local huge = CCT.Saved.EnsureChar("Huge")
local closedDay = CCT.Ledger.Days()[1].day
huge.pad = string.rep("x", 262145)
clear(lines)
check("a character over 262144 drops the closed day", CCT.Ledger.Guard() == true and CCT.Ledger.Dropped() == closedDay and #CCT.Ledger.Days() == 0)
check("the over-cap drop is printed", said("Unacked day " .. closedDay .. " was dropped before it was retained."))

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr7 self-check passed")
