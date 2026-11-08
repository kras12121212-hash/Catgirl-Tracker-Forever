-- PR 6 self-check. Run from the repo root:
--   lua tools/pr6_selfcheck.lua
-- Net, owner control center, pictures, advertise, proximity, and corroboration.

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

local script = (arg and arg[0]) or "tools/pr6_selfcheck.lua"
local root = script:gsub("/?tools/pr6_selfcheck%.lua$", "")
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

local netSrc = read(addon .. "/Core/Net.lua")
local reportSrc = read(addon .. "/Kitten/Report.lua")
local commandsSrc = read(addon .. "/Kitten/Commands.lua")
local corrSrc = read(addon .. "/Owner/Corroboration.lua")
local controlSrc = read(addon .. "/Owner/ControlCenter.lua")
local picturesSrc = read(addon .. "/Kitten/Pictures.lua")
local advertiseSrc = read(addon .. "/Owner/Advertise.lua")
local namespaceSrc = read(addon .. "/Core/Namespace.lua")
local toc = read(addon .. "/CatgirlTracker_Forever.toc")

check("prefix length", netSrc:find('CCT.PREFIX', 1, true) ~= nil)
check("pops on select -1", netSrc:find("select(-1, C_ChatInfo.SendAddonMessage", 1, true) ~= nil)
check("no NotAllowed enum", netSrc:find("NotAllowed", 1, true) == nil)
check("cctcmd is gone", commandsSrc:find("SLASH_CCTCMD1", 1, true) == nil)
check("cgcc is registered in source", controlSrc:find('SLASH_CGCC1 = "/cgcc"', 1, true) ~= nil)
check("report writes pos through state", reportSrc:find("CCT.State.SetPos", 1, true) ~= nil)
check("jewel sample checks the secret first", reportSrc:find("issecretvalue(rawMap)", 1, true) ~= nil and reportSrc:find("issecretvalue(rawMap)", 1, true) < reportSrc:find("GetPlayerMapPosition", 1, true))
check("sentences stay raw", corrSrc:find("raw = true", 1, true) ~= nil)
check("kitten tasks are not counted here", corrSrc:find('AddCounter("tasks"', 1, true) == nil and corrSrc:find("function CCT.Corroboration.CountTasks", 1, true) ~= nil)
check("owner tasks bump once", select(2, corrSrc:gsub('Bump%(week, "tasks"%)', "")) == 1)
check("force group comment", controlSrc:find("KittyLayerGroup.lua layer list, linv, and the NWB read do not ship.", 1, true) ~= nil)
check("maid shell is the editor", controlSrc:find("Nothing is sent yet.", 1, true) == nil and controlSrc:find("CCT.Maid.Summary", 1, true) ~= nil)
check("advertise is not a module flag", namespaceSrc:find("ChatAdvertise", 1, true) == nil)
check("toc order", toc:find("Core/Chat.lua\nCore/Net.lua\nKitten/State.lua", 1, true) ~= nil)
check("toc ends with the master store", toc:find("Kitten/Location.lua\nKitten/Maid.lua\nKitten/Pet.lua\nOwner/Corroboration.lua\nOwner/Map.lua\nOwner/Advertise.lua\nOwner/NyaOptions.lua\nOwner/ControlCenter.lua\nMaster/Store.lua", 1, true) ~= nil)
check("no confirm frame", reportSrc:find("StaticPopup", 1, true) == nil)

local frames = {}
local sends = {}
local chats = {}
local played = {}
local lines = {}
local addonResult = 0

local function auto(kind)
    local obj = { kind = kind, events = {}, scripts = {}, shown = false, text = "" }
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
                if key == "SetText" then
                    s.text = (...) or ""
                    return
                end
                if key == "GetText" then
                    return s.text or ""
                end
                if key == "Show" then
                    s.shown = true
                    return
                end
                if key == "Hide" then
                    s.shown = false
                    return
                end
                if key == "IsShown" then
                    return s.shown == true
                end
                if key == "CreateTexture" or key == "CreateFontString" then
                    local child = auto(key)
                    s.texture = child
                    return child
                end
                if key == "GetPoint" then
                    return "CENTER", nil, "CENTER", 0, 0
                end
                if key == "SetPoint" or key == "SetSize" or key == "SetTexture" or key == "SetAllPoints" then
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
PlaySoundFile = function(path)
    played[#played + 1] = path
    return 100 + #played
end
StopSound = function() end
issecretvalue = function()
    return false
end
UnitName = function()
    return "Kitten"
end
UnitFullName = function()
    return "Kitten"
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
        if addonResult == "nil" then
            return nil
        end
        if addonResult == "multi" then
            return "accepted", 0
        end
        return addonResult
    end,
}
Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, AddOnMessageLockdown = 11, TargetOffline = 12 } }
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
C_PartyInfo = { InviteUnit = function() end, LeaveParty = function() end }
C_Map = {
    GetBestMapForUnit = function()
        return 12
    end,
    GetPlayerMapPosition = function()
        return { x = 0.40, y = 0.50 }
    end,
}
GetInstanceInfo = function()
    return nil, nil, nil, nil, nil, nil, nil, 9
end

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

check("files load", CCT.Net ~= nil and CCT.Report ~= nil and CCT.Control ~= nil and CCT.Pictures ~= nil and CCT.Advertise ~= nil and CCT.Corroboration ~= nil and CCT.Map ~= nil)
check("slash is cgcc", SLASH_CGCC1 == "/cgcc" and type(SlashCmdList.CGCC) == "function")
check("cctcmd slash is absent", SLASH_CCTCMD1 == nil and SlashCmdList.CCTCMD == nil)
check("reliable cap is 72", CCT.Net.RELIABLE_CAP == 72 and CCT.Net.CHANNEL_CAP == 2 and CCT.Net.PROX_CAP == 2)

local function clear(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local online = true
CCT.Roster.GetMember = function(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return { short = name, online = online }
end
CCT.Roster.GetOwnerShort = function()
    return "Nyx"
end
CCT.Roster.GetAssignedKitten = function()
    return { short = "Kitten", online = true }
end

local function bind(name)
    UnitFullName = function()
        return name
    end
    CCT.Player.Refresh()
    CCT.Saved.Init()
    return CCT.State.Bind(name)
end

bind("Kitten")
CCT.Net.Reset()
CCT.Report.Reset()
CCT.Corroboration.Reset()
CCT.Net.Clock(1000)
addonResult = 0

local function whisper(kind, fields, target)
    local results = {}
    local ok = CCT.Net.Whisper(target or "Nyx", kind, fields, function(success, result)
        results[#results + 1] = { success = success, result = result }
    end)
    return ok, results
end

clear(sends)
local queued, results = whisper("state", { { "rev", "1" }, { "week", "2026-W45" }, { "gag", "none" } })
check("state queues", queued == true and CCT.Net.Depth().snapshot == 1)
addonResult = "nil"
CCT.Net.Pump()
check("nil does not pop", #sends == 1 and CCT.Net.Depth().snapshot == 1 and #results == 0)
CCT.Net.Clock(1001.4)
addonResult = 0
CCT.Net.Pump()
check("nil waits out the backoff", #sends == 1 and CCT.Net.Depth().snapshot == 1)
CCT.Net.Clock(1001.5)
CCT.Net.Pump()
check("success pops", #sends == 2 and CCT.Net.Depth().snapshot == 0 and results[1].success == true)

CCT.Net.Reset()
clear(sends)
addonResult = "multi"
queued, results = whisper("ack", { { "op", "gag" }, { "cid", "4" }, { "ok", "1" } })
CCT.Net.Pump()
check("select -1 reads the last return", queued == true and #sends == 1 and results[1].success == true and CCT.Net.Depth().reliable == 0)

CCT.Net.Reset()
clear(sends)
addonResult = 3
queued, results = whisper("cmd", { { "op", "gag" }, { "cid", "8" }, { "state", "huge" } })
CCT.Net.Clock(2000)
CCT.Net.Pump()
check("throttle stays queued", #sends == 1 and CCT.Net.Depth().reliable == 1 and #results == 0)
CCT.Net.Clock(2001.4)
CCT.Net.Pump()
check("throttle waits about 1.5 seconds", #sends == 1 and CCT.Net.Depth().reliable == 1)
addonResult = 0
CCT.Net.Clock(2001.5)
CCT.Net.Pump()
check("throttle retry then pops", #sends == 2 and results[1].success == true)

CCT.Net.Reset()
clear(sends)
addonResult = 11
results = {}
whisper("state", { { "rev", "2" }, { "gag", "small" } })
whisper("cmd", { { "op", "bell" }, { "cid", "2" }, { "which", "collar" }, { "on", "1" } })
CCT.Net.Clock(3000)
CCT.Net.Pump()
check("lockdown holds without a failure", #sends == 1 and CCT.Net.Depth().snapshot == 1 and CCT.Net.Depth().reliable == 1 and #results == 0)
local sentAtHold = #sends
CCT.Net.Pump()
check("lockdown does not send again", #sends == sentAtHold)
IsInInstance = function()
    return false, "none"
end
addonResult = 0
CCT.Net.OnEvent(nil, "PLAYER_ENTERING_WORLD")
check("outdoor entry resumes", #sends > sentAtHold)

CCT.Net.Reset()
clear(sends)
IsInInstance = function()
    return true, "party"
end
whisper("state", { { "rev", "3" }, { "gag", "huge" } })
whisper("cmd", { { "op", "gag" }, { "cid", "3" }, { "state", "huge" } })
local beforeHold = #sends
CCT.Net.Pump()
check("instance party does not call send", #sends == beforeHold and CCT.Net.Depth().snapshot == 1 and CCT.Net.Depth().reliable == 1)
IsInInstance = function()
    return false, "none"
end

CCT.Net.Reset()
clear(sends)
addonResult = 12
results = {}
whisper("cmd", { { "op", "gag" }, { "cid", "12" }, { "state", "small" } })
whisper("state", { { "rev", "4" }, { "gag", "small" } })
CCT.Net.Clock(4000)
CCT.Net.Pump()
check("target offline keeps both", #results == 0 and CCT.Net.Depth().reliable == 1 and CCT.Net.Depth().snapshot == 1)
local offlineSends = #sends
CCT.Net.Pump()
check("offline does not retry immediately", #sends == offlineSends)
online = true
addonResult = 0
CCT.Net.OnEvent(nil, "GUILD_ROSTER_UPDATE")
check("roster online releases", #sends > offlineSends)

CCT.Net.Reset()
clear(sends)
addonResult = 0
for i = 1, 3 do
    CCT.Net.Send("PARTY", "prox", {
        { "kind", "bell" },
        { "snd", "bell" },
        { "map", tostring(i) },
        { "x", "0.1000" },
        { "y", "0.2000" },
        { "inst", "9" },
    })
end
check("party cap is 2", CCT.Net.Depth().channel == 2)
CCT.Net.Pump()
CCT.Net.Pump()
check("party prox has no coordinates", #sends == 2 and sends[1].message:find("map:", 1, true) == nil and sends[1].message:find("inst:", 1, true) == nil and sends[1].chatType == "PARTY")

CCT.Net.Reset()
local entries = {}
for i = 1, 73 do
    entries[i] = { kind = "maiditem", fields = { { "id", "9" }, { "idx", tostring(i) }, { "name", "bell" } } }
end
local callbacks = 0
local status = CCT.Net.EnqueueSet("Kitten", entries, function()
    callbacks = callbacks + 1
end)
check("73 part set is toobig", status == "toobig" and callbacks == 0 and CCT.Net.Depth().reliable == 0)
entries = {}
for i = 1, 62 do
    entries[i] = { kind = "maid", fields = { { "id", "9" }, { "idx", tostring(i) }, { "text", "sit" } } }
end
status = CCT.Net.EnqueueSet("Kitten", entries, function() end)
check("62 part set fits", status == "queued" and CCT.Net.Depth().reliable == 62)

CCT.Net.Reset()
for i = 1, 72 do
    CCT.Net.Whisper("Nyx", "cmd", { { "op", "gag" }, { "cid", tostring(i) }, { "state", "huge" } })
end
local fullResults = {}
local fullOk = CCT.Net.Whisper("Nyx", "cmd", { { "op", "bell" }, { "cid", "73" }, { "which", "collar" }, { "on", "1" } }, function(ok, result)
    fullResults[#fullResults + 1] = { ok = ok, result = result }
end)
check("full queue fails at once", fullOk == false and fullResults[1].result == "full" and CCT.Net.Depth().reliable == 72)

local fields = { { "rev", "9" }, { "week", "2026-W45" }, { "gag", "none" } }
for i = 1, 6 do
    fields[#fields + 1] = { "pad" .. i, string.rep("a", 50) }
end
local pieces = CCT.Net.Pieces("state", fields)
check("state over 255 splits", type(pieces) == "table" and #pieces >= 2)
local splitOk = true
for i = 1, #pieces do
    if pieces[i]:find("rev:9", 1, true) == nil or pieces[i]:find("part:" .. i .. "/" .. #pieces, 1, true) == nil or #pieces[i] > 255 then
        splitOk = false
    end
end
check("each state part repeats rev", splitOk, pieces and pieces[1])

local zoneWire = CCT.Net.Wire("zones", { { "week", "2026-W45" }, { "seq", "1" }, { "z", "Elwynn%3AForest:12" } })
local zoneParsed = CCT.Net.Parse(zoneWire)
check("zone token keeps the minute", zoneWire == "Zones,week:2026-W45,seq:1,z:Elwynn%3AForest:12" and zoneParsed.many.z[1].name == "Elwynn:Forest" and zoneParsed.many.z[1].minutes == 12, zoneWire)

local applied = {}
CCT.Net.On("state", function(_, parsed)
    applied[#applied + 1] = parsed.fields.rev
end)
CCT.Net.Receive("CatgirlTracker", "State,rev:1,part:1/2,gag:huge", "WHISPER", "Kitten-Realm")
check("incomplete state is not applied", #applied == 0)
CCT.Net.Receive("CatgirlTracker", "State,rev:2,gag:small,heat:4", "WHISPER", "Kitten-Realm")
CCT.Net.Receive("CatgirlTracker", "State,rev:1,part:2/2,heat:1", "WHISPER", "Kitten")
check("newer rev discards the old buffer", #applied == 1 and applied[1] == "2")
CCT.Net.Receive("CatgirlTracker", "State,rev:3,part:1/2,gag:full", "WHISPER", "Kitten")
CCT.Net.Receive("CatgirlTracker", "State,rev:3,part:2/2,heat:8", "WHISPER", "Kitten")
check("complete parts apply", applied[#applied] == "3")
CCT.Net.Receive("OtherPrefix", "State,rev:4,gag:none", "WHISPER", "Kitten")
CCT.Net.Receive("CatgirlTracker", "BehaviorLog,rev:1", "WHISPER", "Kitten")
CCT.Net.Receive("CatgirlTracker", "State,rev:5,gag:none", "RAID", "Kitten")
check("foreign prefix classic and raid are ignored", applied[#applied] == "3")

local function count(name)
    local week = CCT.Corroboration.Week("Kitten")
    return week and week[name] or -1
end

CCT.Corroboration.Reset()
local sentBefore = #chats
CCT.Control.Press("gag-heavy")
check("button does not count at click", count("gagOn") == 0 and #chats == sentBefore)
addonResult = 0
CCT.Net.Reset()
clear(sends)
CCT.Corroboration.Reset()
local _, heavyCid = CCT.Control.Press("gag-heavy")
CCT.Net.Clock(5000)
CCT.Net.Pump()
check("success alone does not count", count("gagOn") == 0)
CCT.Net.Receive("CatgirlTracker", "Ack,op:gag,cid:" .. heavyCid .. ",ok:1", "WHISPER", "Kitten")
check("ack after success counts and whispers", count("gagOn") == 1 and chats[#chats].msg:find("heavy gag", 1, true) ~= nil and chats[#chats].chatType == "WHISPER")

CCT.Net.Reset()
CCT.Corroboration.Reset()
clear(chats)
local _, smallCid = CCT.Control.Press("gag-small")
CCT.Net.Receive("CatgirlTracker", "Ack,op:gag,cid:" .. smallCid .. ",ok:1", "WHISPER", "Kitten")
check("ack first waits for success", count("gagOn") == 1 and #chats == 0)
CCT.Net.Pump()
check("either order counts", count("gagOn") == 2 and #chats == 1)

CCT.Net.Reset()
CCT.Corroboration.Reset()
clear(chats)
CCT.Corroboration.Begin("Kitten", "9", { op = "disc", fields = { id = "spank_hand" }, sentence = "no" })
CCT.Corroboration.OnResult("9", true, 0)
CCT.Corroboration.OnAck("Kitten", { fields = { cid = "9", ok = "0", op = "disc" } })
check("ack ok 0 does not count disc", count("disc") == 0 and #chats == 0)

local grouped = true
local left = 0
local invited = {}
IsInGroup = function()
    return grouped
end
IsInRaid = function()
    return false
end
C_PartyInfo = {
    LeaveParty = function()
        left = left + 1
        grouped = false
    end,
    InviteUnit = function(name)
        invited[#invited + 1] = name
    end,
}
local groupResult = CCT.Report.ApplyGroup("Nyx", { op = "group", cid = "g1" })
check("grouped kitten leaves then invites", groupResult.ok == true and left == 1 and invited[1] == "Nyx")
grouped = false
left = 0
invited = {}
CCT.Report.ApplyGroup("Nyx", { op = "group", cid = "g2" })
check("ungrouped kitten only invites", left == 0 and invited[1] == "Nyx")

local title, body = CCT.Control.MaidShell()
check("maid editor summarizes the list", title == "Maid editor" and body == "0 items, 0 instructions")
local minutes = CCT.Control.LockMinutes("1.5")
check("hour box is ninety minutes", minutes == 90)
check("zero hours do not lock", CCT.Control.LockMinutes("0") == nil)
local heavy = false
for i = 1, #CCT.Control.Buttons do
    local spec = CCT.Control.Buttons[i]
    if spec.label and spec.label:find("Squeking", 1, true) then
        heavy = true
    end
    if spec.fields and spec.fields.op == "mittens" and spec.fields.state == "heavy" then
        heavy = false
    end
end
check("squeking mittens are present and heavy is not a button", heavy == true)

CCT.Pictures.OnEvent(nil, "PLAYER_LOGIN")
local beforePics = #(CCT.Saved.EnsureChar("Kitten").pictures)
CCT.State.SetGag("huge")
local pics = CCT.Saved.EnsureChar("Kitten").pictures
check("gag popup is recorded", #pics == beforePics + 1 and pics[#pics].icon:find("Heavy-gag", 1, true) ~= nil)
local afterOn = #pics
CCT.State.SetGag("none")
check("removal does not pop", #CCT.Saved.EnsureChar("Kitten").pictures == afterOn)
for i = 1, 40 do
    CCT.Pictures.Note("icon-" .. i, 6000 + i)
end
check("picture ring caps at 30", #CCT.Saved.EnsureChar("Kitten").pictures == 30)

check("map draws nothing while off", #CCT.Map.Points(12) == 0)
CCT.Module.Set("KittenMapShow", true)
check("map draws nothing without a pos", #CCT.Map.Points(12) == 0)
local ownerRow = CCT.db.owner.kitten.Kitten or { state = {}, trail = {} }
CCT.db.owner.kitten.Kitten = ownerRow
ownerRow.state = { rev = 1, pos = { mapID = 12, x = 0.2, y = 0.3, t = 7000 }, jewel = true }
ownerRow.trail = {}
CCT.Report.AppendTrail(ownerRow.trail, { mapID = 12, x = 0.2, y = 0.3, t = 7000 }, 7000)
check("map draws the received pos", #CCT.Map.Points(12) >= 1 and #CCT.Map.Points(99) == 0)
local trail = {}
for i = 1, 101 do
    CCT.Report.AppendTrail(trail, { mapID = 1, x = 0.1, y = 0.1, t = 8000 + i }, 8101)
end
check("trail caps at 100", #trail == 100)
CCT.Report.AppendTrail(trail, { mapID = 1, x = 0.1, y = 0.1, t = 100 }, 8000 + 3601)
check("trail drops an hour old point", trail[1].t ~= 100)

local secret = {}
issecretvalue = function(value)
    return value == secret
end
C_Map.GetBestMapForUnit = function()
    return secret
end
local sampled = false
C_Map.GetPlayerMapPosition = function()
    sampled = true
    return { x = 0.1, y = 0.1 }
end
CCT.State.SetJewel(true)
local sample = CCT.Report.SamplePos(9000)
check("secret map is not sampled", sample == false and sampled == false)
issecretvalue = function()
    return false
end
C_Map.GetBestMapForUnit = function()
    return 12
end
C_Map.GetPlayerMapPosition = function()
    return { x = 0.25, y = 0.75 }
end
CCT.Net.Reset()
clear(sends)
check("sample writes through setpos", CCT.Report.SamplePos(9100) == true and CCT.State.Get().pos.x == 0.25)

CCT.Report.Reset()
CCT.Report.Arm()
CCT.Net.Reset()
CCT.Net.Clock(10000)
clear(sends)
local depthBefore = CCT.Net.Depth().snapshot
CCT.State.SetHeat(10.2)
CCT.Net.Pump()
local firstHeat = #sends
CCT.Net.Reset()
CCT.State.SetHeat(10.6)
local sameShown = CCT.Net.Depth().snapshot
CCT.State.SetHeat(11.4)
local scheduled = CCT.Net.Depth().snapshot
clear(sends)
CCT.Net.Clock(10009)
CCT.Net.Pump()
local early = #sends
CCT.Net.Clock(10010)
addonResult = 0
CCT.Net.Pump()
check("heat integer is rate limited", firstHeat >= 1 and sameShown == depthBefore and scheduled == depthBefore and early == 0 and #sends >= 1, "first " .. firstHeat .. " same " .. tostring(sameShown) .. " early " .. early .. " later " .. #sends)

CCT.Advertise.SetEnabled(false)
local adLines = CCT.Advertise.Lines()
check("advertise defaults off with five lines", CCT.Advertise.Enabled() == false and #adLines == 5)
clear(chats)
check("disabled advertise does not send", CCT.Advertise.SendAll() == 0 and #chats == 0)
CCT.Advertise.SetLine(1, "/s hello nya")
CCT.Advertise.SetEnabled(true)
check("enabled advertise uses chat", CCT.Advertise.SendAll() == 1 and chats[#chats].msg == "hello nya" and chats[#chats].chatType == "SAY")
check("timer reminder text", CCT.Advertise.TIMER_TEXT == "Timer done nya want to Shutout nya !?")
local moduleNames = {}
for i = 1, #CCT.MODULES do
    moduleNames[#moduleNames + 1] = CCT.MODULES[i].name
end
check("advertise is not listed", table.concat(moduleNames, ",") :find("Advertise", 1, true) == nil and table.concat(moduleNames, ","):find("ChatAdvertise", 1, true) == nil)

local far = CCT.Control.Press("disc-spank_hand-butt")
check("discipline without a jewel does not send", far == false and lines[#lines] == CCT.Msg("DISCIPLINE_TOO_FAR"))

local assignedKitten = CCT.Roster.GetAssignedKitten
CCT.Roster.GetAssignedKitten = function()
    return nil
end
local sendsBeforeBrowse = #sends
local browse = CCT.Control.Open()
local function controlRow(id)
    local rows = browse and browse.rows or {}
    for i = 1, #rows do
        if rows[i].id == id then
            return rows[i]
        end
    end
    return nil
end
local gagRow = controlRow("gag-heavy")
local adRow = controlRow("advertise")
check(
    "control center opens with no kitten",
    browse ~= nil
        and browse.status
        and browse.status:GetText() == "Kitten: None assigned"
        and browse.statsText
        and browse.statsText:GetText():find("most Functions not avilable", 1, true) ~= nil
        and browse.selectedTab == "Stats"
        and browse.tabs.Stats:IsShown() == true
        and browse.tabs.Control:IsShown() == false
        and browse.tabs.Toys:IsShown() == false
        and browse.tabs.Discipline:IsShown() == false
        and browse.tabs.Settings:IsShown() == false
        and browse.tabButtons.Control:GetText() == "Control"
        and gagRow ~= nil
        and gagRow.button.cctEnabled == false
        and browse.hours.cctEnabled == false
        and adRow ~= nil
        and adRow.button.cctEnabled == true
        and adRow.button:GetText() == "Advertise"
)
if browse.ShowTab then
    browse.ShowTab("Toys")
end
check("toys tab is its own page", browse.tabs.Toys:IsShown() == true and browse.tabs.Stats:IsShown() == false)
browse.ShowTab("Stats")
local gagClick = gagRow and gagRow.button.scripts and gagRow.button.scripts.OnClick
if gagClick then
    gagClick()
end
check("disabled control does not send", #sends == sendsBeforeBrowse and CCT.Control.Press("gag-heavy") == false)
CCT.Roster.GetAssignedKitten = assignedKitten
CCT.Control.Open()
check(
    "assigned kitten enables controls",
    controlRow("gag-heavy").button.cctEnabled == true
        and browse.hours.cctEnabled == true
        and browse.status:GetText():find("Kitten: Kitten", 1, true) == 1
)
local launcher = CCT.Control.Launcher()
check("cgcc button is shown", launcher ~= nil and launcher:GetText() == "cgcc" and launcher:IsShown() == true)
if launcher and launcher.scripts and launcher.scripts.OnClick then
    launcher.scripts.OnClick()
    check("cgcc button hides the open window", browse:IsShown() == false)
    launcher.scripts.OnClick()
    check("cgcc button shows the window again", browse:IsShown() == true)
end

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr6 self-check passed")
