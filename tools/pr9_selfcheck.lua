-- PR 9 self-check. Run from the repo root:
--   lua tools/pr9_selfcheck.lua
-- Local day id and a fourteen-day scorecard. No webhook and no scorecard frame.

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

local script = (arg and arg[0]) or "tools/pr9_selfcheck.lua"
local root = script:gsub("/?tools/pr9_selfcheck%.lua$", "")
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

local toc = read(addon .. "/CatgirlTracker_Forever.toc")
local ledgerSrc = read(addon .. "/Kitten/Ledger.lua")
local storeSrc = read(addon .. "/Master/Store.lua")
local corrSrc = read(addon .. "/Owner/Corroboration.lua")

check("char cap stays 262144", ledgerSrc:find("CHAR_CAP = 262144", 1, true) ~= nil)
check("no webhook and no scorecard frame", storeSrc:find("webhook", 1, true) == nil and storeSrc:find("http", 1, true) == nil and storeSrc:find("CreateFontString", 1, true) == nil and corrSrc:find("webhook", 1, true) == nil and corrSrc:find("CreateFontString", 1, true) == nil)
check("pr9 does not add pet counters", ledgerSrc:find("petMiss", 1, true) == nil and ledgerSrc:find("petMin", 1, true) == nil)

local frames = {}
local lines = {}
local sends = {}

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
SendChatMessage = function() end
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

check("files load", CCT.Day ~= nil and CCT.Ledger ~= nil and CCT.Store ~= nil and CCT.Corroboration ~= nil)

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

local function hasId(list, id)
    for i = 1, #(list or {}) do
        if list[i] == id then
            return true
        end
    end
    return false
end

local function dayCount(days)
    local n = 0
    if type(days) ~= "table" then
        return 0
    end
    for _, row in pairs(days) do
        if type(row) == "table" then
            n = n + 1
        end
    end
    return n
end

local masterOnline = true
CCT.Roster.GetMember = function(name)
    local short = CCT.ShortName(name)
    if short == nil then
        return nil
    end
    local online = true
    if CCT.db and CCT.db.settings and CCT.SameName(short, CCT.db.settings.masterName) then
        online = masterOnline
    end
    return {
        short = short,
        online = online,
        ownerShort = nil,
        publicNote = "",
        officerNote = "",
    }
end

local stamp = noon(2026, 11, 10)
check("day id is the local stamp", CCT.Day.Id(stamp) == "2026-11-10")
check("10 November is newer than 9 November", CCT.Day.Cmp("2026-11-10", "2026-11-09") == 1)
check("a week id is not a day", CCT.Day.DaysBefore("2026-W45", "2026-11-10") == nil and CCT.Day.Cmp("2026-W45", "2026-11-10") == -1)
check("days before is nil when either id does not number", CCT.Day.DaysBefore("2026-11-10", "legacy") == nil and CCT.Day.DaysBefore("legacy", "2026-11-10") == nil)
check("28 October is 13 days before 10 November", CCT.Day.DaysBefore("2026-11-10", "2026-10-28") == 13)
check("27 October is 14 days before 10 November", CCT.Day.DaysBefore("2026-11-10", "2026-10-27") == 14)

bind("Master")
CCT.db.settings.masterName = "Master"
CCT.db.master.kittens.Keep = {
    days = {
        legacy = { day = "legacy", seq = 1, at = 1, fields = { playMin = 3 }, zones = {}, senders = {} },
        ["2026-11-10"] = { day = "2026-11-10", seq = 1, at = 1, fields = {}, zones = {}, senders = {} },
    },
    storedDays = { "legacy", "2026-11-10" },
    droppedDay = nil,
    rotatedDay = nil,
}
CCT.db.master.kittens.Window = {
    days = {
        ["2026-10-27"] = { day = "2026-10-27", seq = 1, at = 1, fields = { playMin = 8 }, zones = {}, senders = {} },
        ["2026-10-28"] = { day = "2026-10-28", seq = 1, at = 1, fields = { playMin = 2 }, zones = {}, senders = {} },
    },
    storedDays = { "2026-10-27", "2026-10-28" },
    droppedDay = nil,
    rotatedDay = nil,
}
CCT.SetDebug(true)
clear(lines)
check("maintain runs", CCT.Store.Maintain(stamp) == true)
local keep = CCT.db.master.kittens.Keep
check("a nil days-before does not remove the row", keep.days.legacy ~= nil and keep.days.legacy.fields.playMin == 3 and keep.rotatedDay == nil and keep.droppedDay == nil)
local window = CCT.db.master.kittens.Window
check("28 October stays and 27 October rotates", window.days["2026-10-28"] ~= nil and window.days["2026-10-27"] == nil and window.rotatedDay == "2026-10-27" and window.droppedDay == nil)
check("the rotated id stays remembered", hasId(window.storedDays, "2026-10-27"))
check("the age-out line is debug only", said("Closed day 2026-10-27 rotated off the scorecard. It had been retained."))

local skewDays = {}
local skewOrder = {}
local skewStart = noon(2026, 10, 28)
for i = 0, 12 do
    local id = CCT.Day.Id(skewStart + i * 86400)
    skewDays[id] = { day = id, seq = 1, at = 1, fields = { playMin = 1 }, zones = {}, senders = {} }
    skewOrder[#skewOrder + 1] = id
end
skewDays.legacy = { day = "legacy", seq = 1, at = 1, fields = { playMin = 4 }, zones = {}, senders = {} }
local skewStored = { "2026-11-09" }
for i = 1, #skewOrder - 1 do
    skewStored[#skewStored + 1] = skewOrder[i]
end
skewStored[#skewStored + 1] = "legacy"
CCT.db.master.kittens.Skew = {
    days = skewDays,
    storedDays = skewStored,
    droppedDay = nil,
    rotatedDay = nil,
}
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
check("today evicts the oldest live key", CCT.Store.Accept("ledger", "Skew", ledger("2026-11-10", 1, { playMin = 1 }), stamp) == true)
local skew = CCT.db.master.kittens.Skew
check("eviction uses day compare, not storedDays[1]", skew.days.legacy == nil and skew.days["2026-11-09"] ~= nil and skew.days["2026-11-10"] ~= nil and skew.rotatedDay == "legacy" and skew.droppedDay == nil)
check("the evicted id stays in stored days", hasId(skew.storedDays, "legacy") and hasId(skew.storedDays, "2026-11-09") and hasId(skew.storedDays, "2026-11-10") and skew.storedDays[1] == "2026-11-09")

CCT.db.master.kittens.Noted = {
    days = {
        ["2026-10-27"] = { day = "2026-10-27", seq = 1, at = 1, fields = { playMin = 6 }, zones = {}, senders = {} },
    },
    storedDays = { "2026-10-27" },
    droppedDay = nil,
    rotatedDay = nil,
}
CCT.Store.Maintain(stamp)
local noted = CCT.db.master.kittens.Noted
check("an aged id is still remembered", noted.days["2026-10-27"] == nil and noted.rotatedDay == "2026-10-27" and hasId(noted.storedDays, "2026-10-27") and noted.droppedDay == nil)
check("a dropped id that was stored does not set droppedDay", CCT.Store.Accept("ledger", "Noted", ledger("2026-11-10", 1, { playMin = 1 }, "2026-10-27"), stamp) == true and noted.droppedDay == nil)
check("a dropped id that was never stored does", CCT.Store.Accept("ledger", "Noted", ledger("2026-11-10", 2, { playMin = 1 }, "2026-09-01"), stamp) == true and noted.droppedDay == "2026-09-01")
check("the never-stored line is debug only", said("Unacked 2026-09-01 was dropped before it was retained."))
CCT.Net.Reset()
clear(sends)
check("a refuse does not set droppedDay", CCT.Store.Accept("ledger", "OldSend", ledger("2026-10-01", 1, { playMin = 9 }), stamp) == false and CCT.db.master.kittens.OldSend == nil and noted.droppedDay == "2026-09-01")
local refusedAck = false
for i = 1, #sends do
    if sends[i].message:find("LedgerAck,", 1, true) == 1 then
        refusedAck = true
    end
end
check("a refuse sends no ack", refusedAck == false)
check("a week id ledger is ignored", CCT.Store.Accept("ledger", "Weeked", { kind = "ledger", fields = { week = "2026-W45", seq = "1", playmin = "4" }, many = {} }, stamp) == false and CCT.db.master.kittens.Weeked == nil)

bind("SeqRoll")
CCT.db.settings.masterName = "Nyx"
masterOnline = true
local day0 = noon(2026, 11, 1)
local day1 = noon(2026, 11, 2)
CCT.Ledger.OnLogin(day0)
CCT.State.SetCounter("playMin", 1)
CCT.Net.Reset()
check("the open day is sent once", CCT.Ledger.Flush("timer", day0) == true)
CCT.State.SetCounter("playMin", 2)
CCT.Ledger.EnsureWeek(day1)
local copied = CCT.Ledger.Days()[1]
check("the closed row copies the would-send seq", copied ~= nil and copied.day == "2026-11-01" and copied.seq == 2 and copied.counters.playMin == 2)

bind("Dropper")
CCT.db.settings.masterName = nil
clear(lines)
local start = noon(2026, 11, 1)
CCT.Ledger.OnLogin(start)
CCT.State.SetCounter("playMin", 42)
for i = 1, 13 do
    CCT.Ledger.EnsureWeek(start + i * 86400)
end
check("thirteen closed days do not drop", #CCT.Ledger.Days() == 13 and CCT.Ledger.Dropped() == nil and said("Unacked day") == false)
CCT.Ledger.EnsureWeek(start + 14 * 86400)
local droppedPlay = false
local closedDays = CCT.Ledger.Days()
for i = 1, #closedDays do
    if closedDays[i].counters ~= nil and closedDays[i].counters.playMin == 42 then
        droppedPlay = true
    end
end
check("the 15th day drops the oldest", CCT.Ledger.Dropped() == "2026-11-01" and #closedDays == 13 and closedDays[1].day == "2026-11-02" and droppedPlay == false)
check("the 15th-day drop is printed", said("Unacked day 2026-11-01 was dropped before it was retained."))

bind("AckKit")
CCT.db.settings.masterName = "Nyx"
CCT.Ledger.OnLogin(noon(2026, 11, 8))
CCT.State.SetCounter("playMin", 3)
CCT.Ledger.EnsureWeek(noon(2026, 11, 9))
CCT.Ledger.EnsureWeek(noon(2026, 11, 10))
check("an ack from a non master does nothing", CCT.Ledger.OnAck("Other", { fields = { day = "2026-11-08", seq = "1" } }) == false and #CCT.Ledger.Days() == 2)
check("an ack of another day does nothing", CCT.Ledger.OnAck("Nyx", { fields = { day = "2026-01-01", seq = "9" } }) == false and #CCT.Ledger.Days() == 2)
check("a low seq does not remove the closed day", CCT.Ledger.OnAck("Nyx", { fields = { day = "2026-11-09", seq = "0" } }) == false and #CCT.Ledger.Days() == 2)
check("an ack removes only that closed day", CCT.Ledger.OnAck("Nyx", { fields = { day = "2026-11-09", seq = "1" } }) == true and #CCT.Ledger.Days() == 1 and CCT.Ledger.Days()[1].day == "2026-11-08")
check("the open day survives an ack of its own id", CCT.Ledger.OnAck("Nyx", { fields = { day = "2026-11-10", seq = "5" } }) == false and CCT.State.Get().week == "2026-11-10" and #CCT.Ledger.Days() == 1)

bind("Retired")
local retired = CCT.Saved.EnsureChar("Retired")
CCT.State.SetWeek("2026-W45")
retired.archive = { week = "2026-W45" }
retired.life.denied = 7
CCT.State.SetLock("earmuffs", 10080)
CCT.State.SetHeelLevel("high", 4)
CCT.State.SetHeels("high")
CCT.State.SetCounter("playMin", 9)
clear(lines)
CCT.Ledger.EnsureWeek(stamp)
CCT.Ledger.EnsureWeek(stamp)
local weekRow = false
local retiredDays = CCT.Ledger.Days()
for i = 1, #retiredDays do
    if retiredDays[i].day == "2026-W45" then
        weekRow = true
    end
end
check("a week id starts today at zero", CCT.State.Get().week == "2026-11-10" and CCT.State.Get().counters.playMin == 0 and CCT.State.Get().counters.seq == 1 and #retiredDays == 0 and weekRow == false)
check("the retirement line prints once", countSaid("The weekly scorecard was retired and today starts at zero.") == 1)
check("life, the lock, and the heel stay", retired.life.denied == 7 and CCT.State.Get().locks.earmuffs.minutes == 10080 and CCT.State.Get().heelLevel.high == 4 and CCT.State.Get().heels == "high")

bind("Walker")
CCT.db.settings.masterName = nil
CCT.Ledger.OnLogin(noon(2026, 11, 8))
CCT.State.SetHeels("maid")
local walker = CCT.Saved.EnsureChar("Walker")
walker.life.denied = 4
CCT.State.SetCounter("playMin", 1)
CCT.Ledger.EnsureWeek(noon(2026, 11, 9))
CCT.Ledger.EnsureWeek(noon(2026, 11, 10))
check("the walk fixture starts with closed days", #CCT.Ledger.Days() == 2)
local trail = {}
for i = 1, 8000 do
    trail[i] = { mapID = 12, x = 0.25, y = 0.5, t = 1700000000 + i }
end
walker.trail = trail
local spins = 0
while CCT.Ledger.Guard() and spins < 20 do
    spins = spins + 1
end
check("repeated guard empties closed days and keeps the walk", spins >= 2 and #CCT.Ledger.Days() == 0 and #walker.trail == 8000 and CCT.State.Get().week == "2026-11-10" and CCT.State.Get().heels == "maid" and walker.life.denied == 4)
check("guard stops when no closed day remains", CCT.Ledger.Guard() == false and #walker.trail == 8000)

local savedTime = time
local function atDay(day)
    time = function()
        return os.time({ year = 2026, month = 11, day = day, hour = 12 })
    end
end
bind("OwnerNine")
clear(lines)
atDay(1)
local first = CCT.Corroboration.Week("Mina")
first.tasks = 9
for day = 2, 15 do
    atDay(day)
    CCT.Corroboration.Week("Mina")
end
time = savedTime
local ownerDays = CCT.db.owner.days.Mina
check("the owner tally keeps 14 days and drops the oldest quietly", #ownerDays == 14 and ownerDays[1].day == "2026-11-02" and ownerDays[#ownerDays].day == "2026-11-15" and CCT.db.owner.droppedDay.Mina == "2026-11-01" and ownerDays[1].tasks == 0 and said("Unacked day") == false)

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr9 self-check passed")
