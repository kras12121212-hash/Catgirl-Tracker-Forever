-- PR 10 self-check. Run from the repo root:
--   lua tools/pr10_selfcheck.lua
-- petMiss, petMin, and the Worn whisper. The fourteen-day window stays.

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

local script = (arg and arg[0]) or "tools/pr10_selfcheck.lua"
local root = script:gsub("/?tools/pr10_selfcheck%.lua$", "")
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
local petSrc = read(addon .. "/Kitten/Pet.lua")
local storeSrc = read(addon .. "/Master/Store.lua")
local netSrc = read(addon .. "/Core/Net.lua")

check("the fourteen day window is unchanged", ledgerSrc:find("CLOSED_CAP = 13", 1, true) ~= nil and ledgerSrc:find("TIMER_GAP = 300", 1, true) ~= nil and storeSrc:find("DAY_CAP = 14", 1, true) ~= nil)
check("ledger does not read the pet journal", ledgerSrc:find("C_PetJournal", 1, true) == nil and ledgerSrc:find("GetCompanionInfo", 1, true) == nil and ledgerSrc:find("GetNumCompanions", 1, true) == nil and ledgerSrc:find("CCT.Pet", 1, true) == nil)
check("pet flags are not saved", petSrc:find("forgotSent", 1, true) ~= nil and petSrc:find("char.forgotSent", 1, true) == nil and petSrc:find("char.warned", 1, true) == nil and petSrc:find("warned = false", 1, true) ~= nil)
check("worn is its own snapshot kind", netSrc:find('worn = "Worn"', 1, true) ~= nil and netSrc:find("w = true", 1, true) ~= nil)

local frames = {}
local sends = {}
local chats = {}
local lines = {}

local function auto(kind)
    local obj = { kind = kind, events = {}, scripts = {} }
    frames[#frames + 1] = obj
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
                if key == "CreateFontString" or key == "CreateTexture" then
                    return auto(key)
                end
                return s
            end
        end,
    })
end

CreateFrame = function(kind)
    return auto(kind or "Frame")
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
local inGuild = true
IsInGuild = function()
    return inGuild
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

local petGuid = nil
local petInfo = nil
C_PetJournal = {
    GetSummonedPetGUID = function()
        return petGuid
    end,
    GetPetInfoTableByPetID = function()
        return petInfo
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

check("files load", CCT.Pet ~= nil and CCT.Ledger ~= nil and CCT.Store ~= nil and CCT.Net ~= nil and CCT.State ~= nil)

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

local function counters()
    return CCT.State.Get().counters
end

local function charOf(name)
    return CCT.Saved.EnsureChar(name)
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

local function firstKind(prefix, day)
    for i = 1, #sends do
        local message = sends[i].message
        if message:find(prefix, 1, true) == 1 and (day == nil or message:find("day:" .. day, 1, true) ~= nil) then
            return i, message
        end
    end
    return nil, nil
end

local function firePet(event)
    for i = 1, #frames do
        local frame = frames[i]
        if frame.events.COMPANION_UPDATE and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event)
            return true
        end
    end
    return false
end

local function missCount()
    return counters().petMiss
end

local day = noon(2026, 11, 10)
bind("Purr")
CCT.db.settings.masterName = "Nyx"
CCT.db.settings.flavorAnnouncements = true
CCT.Module.Set("PetTracker", true)
inGuild = true
petGuid = nil
petInfo = nil
check("pet login handler is present", firePet("PLAYER_LOGIN") == true)

local beforeMiss = missCount()
check("the warning does not count a miss", CCT.Pet.Step() == true and missCount() == beforeMiss and #chats == 0)
local chatsAtBad = #chats
check(
    "the forgot line counts one miss",
    CCT.Pet.Step() == true
        and missCount() == beforeMiss + 1
        and #chats == chatsAtBad + 1
        and chats[#chats].chatType == "GUILD"
        and chats[#chats].msg == CCT.Msg("PET_SUMMON_BAD")
)
check("the same streak does not count again", CCT.Pet.Step() == false and missCount() == beforeMiss + 1 and #chats == chatsAtBad + 1)

petGuid = "BattlePet-1"
petInfo = { speciesID = 40, name = "Bombay Cat" }
check("a summoned carrier clears the streak", CCT.Pet.Refresh() == true and CCT.Pet.Step() == false and missCount() == beforeMiss + 1)
petGuid = nil
petInfo = nil
check("losing the cat warns before the next miss", CCT.Pet.Step() == true and missCount() == beforeMiss + 1 and #chats == chatsAtBad + 1)
check("the next forgot line counts again", CCT.Pet.Step() == true and missCount() == beforeMiss + 2 and #chats == chatsAtBad + 2)

check("login resets the in-memory flags", firePet("PLAYER_LOGIN") == true)
check("login does not persist the sent flag", CCT.Pet.Step() == true and missCount() == beforeMiss + 2 and #chats == chatsAtBad + 2)
check("a reload can count another miss", CCT.Pet.Step() == true and missCount() == beforeMiss + 3)

firePet("PLAYER_LOGIN")
CCT.db.settings.flavorAnnouncements = false
local held = missCount()
check("flavor off still warns", CCT.Pet.Step() == true and missCount() == held)
check("flavor off does not count or latch the miss", CCT.Pet.Step() == false and missCount() == held and #chats == chatsAtBad + 3)
CCT.db.settings.flavorAnnouncements = true
check("the miss counts once flavor is on", CCT.Pet.Step() == true and missCount() == held + 1)

firePet("PLAYER_LOGIN")
inGuild = false
held = missCount()
CCT.Pet.Step()
check("no guild does not count or latch the miss", CCT.Pet.Step() == false and missCount() == held)
inGuild = true
check("the miss counts once she is in a guild", CCT.Pet.Step() == true and missCount() == held + 1)

firePet("PLAYER_LOGIN")
CCT.Module.Set("PetTracker", false)
held = missCount()
check("pet tracker off does not count a miss", CCT.Pet.Step() == false and missCount() == held)
CCT.Module.Set("PetTracker", true)

bind("Minute")
CCT.db.settings.masterName = "Nyx"
CCT.Module.Set("PetTracker", true)
CCT.Ledger.OnLogin(day)
CCT.State.SetPetSummoned(true)
check("summoned minutes count while the module is on", CCT.Ledger.AddMinutes(day + 120, "Elwynn") == 2 and counters().petMin == 2 and counters().playMin == 2)
CCT.Module.Set("PetTracker", false)
check("the module off adds no pet minutes", CCT.Ledger.AddMinutes(day + 240, "Elwynn") == 2 and counters().petMin == 2 and counters().playMin == 4)
CCT.Module.Set("PetTracker", true)
CCT.State.SetPetSummoned(false)
check("a dismissed cat adds no pet minutes", CCT.Ledger.AddMinutes(day + 360, "Elwynn") == 2 and counters().petMin == 2 and counters().playMin == 6)

local journalCalls = 0
local savedJournal = C_PetJournal
C_PetJournal = setmetatable({}, {
    __index = function()
        journalCalls = journalCalls + 1
        error("journal")
    end,
})
GetNumCompanions = function()
    journalCalls = journalCalls + 1
    error("journal")
end
GetCompanionInfo = function()
    journalCalls = journalCalls + 1
    error("journal")
end
local journalOk = pcall(CCT.Ledger.AddMinutes, day + 420, "Elwynn")
check("adding minutes does not call the journal", journalOk == true and journalCalls == 0 and counters().petMin == 2)
C_PetJournal = savedJournal
GetNumCompanions = nil
GetCompanionInfo = nil

CCT.State.SetPetSummoned(true)
CCT.State.SetBell(true)
check("pet minutes and worn minutes clamp at 1440", CCT.Ledger.AddMinutes(day + 420 + 2000 * 60, "Elwynn") == 2000 and counters().petMin == 1440 and charOf("Minute").worn.bell == 1440)
CCT.State.SetCounter("petMiss", 9998)
check("pet misses clamp at 9999", CCT.State.AddCounter("petMiss", 5) == true and counters().petMiss == 9999)

bind("Bare")
CCT.db.settings.masterName = "Nyx"
masterOnline = true
CCT.Ledger.OnLogin(day)
CCT.State.SetGag("small")
CCT.State.SetHeels("high")
CCT.Ledger.AddMinutes(day + 60, "Elwynn")
CCT.Net.Reset()
clear(sends)
check("gag and heel minutes flush", CCT.Ledger.Flush("timer", day + 60) == true)
drain()
local bareLedger = select(2, firstKind("Ledger,", "2026-11-10"))
local bareWorn = firstKind("Worn,", "2026-11-10")
check(
    "zeros stay on the ledger and an all-zero worn map is not whispered",
    bareWorn == nil
        and bareLedger ~= nil
        and bareLedger:find("gagMin:1", 1, true) ~= nil
        and bareLedger:find("heelsMin:1", 1, true) ~= nil
        and bareLedger:find("petMiss:0", 1, true) ~= nil
        and bareLedger:find("petMin:0", 1, true) ~= nil
        and charOf("Bare").worn.gag == nil
        and charOf("Bare").worn.heels == nil,
    bareLedger
)
local napAt = bareLedger and bareLedger:find("napMiss:", 1, true)
local missAt = bareLedger and bareLedger:find("petMiss:", 1, true)
local minAt = bareLedger and bareLedger:find("petMin:", 1, true)
check("pet counters follow napMiss", napAt ~= nil and missAt ~= nil and minAt ~= nil and napAt < missAt and missAt < minAt)

charOf("Bare").dropSend = "2026-11-01"
charOf("Bare").dropUntil = "2026-11-10"
CCT.State.SetCounter("playMin", counters().playMin + 1)
CCT.Net.Reset()
clear(sends)
CCT.Ledger.Flush("timer", day + 300)
drain()
local droppedLedger = select(2, firstKind("Ledger,", "2026-11-10"))
local droppedMin = droppedLedger and droppedLedger:find("petMin:", 1, true)
local droppedAt = droppedLedger and droppedLedger:find("dropped:", 1, true)
check(
    "dropped follows petMin",
    droppedLedger ~= nil and droppedMin ~= nil and droppedAt ~= nil and droppedMin < droppedAt and droppedLedger:find("petMin:0,dropped:2026-11-01", 1, true) ~= nil,
    droppedLedger
)

bind("Worn")
CCT.db.settings.masterName = "Nyx"
CCT.Ledger.OnLogin(day)
CCT.State.SetBlind("light")
CCT.State.SetBell(true)
CCT.State.ApplyToy("taill_butplug")
CCT.State.SetGag("huge")
CCT.State.SetHeels("ballet")
check("worn minutes follow the minute clock", CCT.Ledger.AddMinutes(day + 15 * 60, "Elwynn") == 15)
local wornMap = charOf("Worn").worn
check(
    "a positive id is stored and a zero id is absent",
    wornMap.blind == 15
        and wornMap.bell == 15
        and wornMap.taill_butplug == 15
        and wornMap.ears == nil
        and wornMap.gag == nil
        and wornMap.heels == nil
        and counters().gagMin == 15
        and counters().heelsMin == 15
        and counters().petMin == 0
)
CCT.Ledger.PushSender("pets:Nyx")
CCT.Net.Reset()
clear(sends)
check("the open day flushes", CCT.Ledger.Flush("edge", day + 15 * 60) == true)
drain()
local wornWire = select(2, firstKind("Worn,", "2026-11-10"))
check(
    "the worn whisper names the positive ids",
    wornWire ~= nil
        and wornWire:find("w:bell:15", 1, true) ~= nil
        and wornWire:find("w:blind:15", 1, true) ~= nil
        and wornWire:find("w:taill_butplug:15", 1, true) ~= nil
        and wornWire:find("w:ears:", 1, true) == nil
        and wornWire:find("w:gag:", 1, true) == nil
        and wornWire:find("w:heels:", 1, true) == nil
        and wornWire:find("seq:1", 1, true) ~= nil,
    wornWire
)
local ledgerAt, ledgerWire = firstKind("Ledger,", "2026-11-10")
local zonesAt = firstKind("Zones,", "2026-11-10")
local petsAt = firstKind("Pets,", "2026-11-10")
local wornAt = firstKind("Worn,", "2026-11-10")
check(
    "catch-up order is ledger, zones, pets, worn",
    ledgerAt ~= nil and zonesAt ~= nil and petsAt ~= nil and wornAt ~= nil and ledgerAt < zonesAt and zonesAt < petsAt and petsAt < wornAt,
    "ledger " .. tostring(ledgerAt) .. " zones " .. tostring(zonesAt) .. " pets " .. tostring(petsAt) .. " worn " .. tostring(wornAt)
)
check("the ledger and the worn body share the seq", ledgerWire ~= nil and ledgerWire:find("seq:1", 1, true) ~= nil and wornWire:find("seq:1", 1, true) ~= nil)

CCT.State.SetLeash(true, "Nyx")
CCT.Ledger.AddMinutes(day + 16 * 60, "Elwynn")
CCT.Net.Reset()
clear(sends)
check("a worn change bumps the seq", CCT.Ledger.Flush("timer", day + 16 * 60) == true and counters().seq == 2)
drain()
local nextWorn = select(2, firstKind("Worn,", "2026-11-10"))
local nextLedger = select(2, firstKind("Ledger,", "2026-11-10"))
check(
    "the new seq carries the ledger and the full worn map",
    nextLedger ~= nil
        and nextWorn ~= nil
        and nextLedger:find("seq:2", 1, true) ~= nil
        and nextWorn:find("seq:2", 1, true) ~= nil
        and nextWorn:find("w:leash:1", 1, true) ~= nil
        and nextWorn:find("w:blind:16", 1, true) ~= nil
        and nextWorn:find("w:taill_butplug:16", 1, true) ~= nil,
    nextWorn
)

check("the next day keeps the closed worn map", CCT.Ledger.EnsureWeek(noon(2026, 11, 11)) == true)
local closed = CCT.Ledger.Days()
check(
    "the roll copies worn and starts the open map empty",
    #closed == 1
        and closed[1].day == "2026-11-10"
        and closed[1].worn.blind == 16
        and closed[1].worn.taill_butplug == 16
        and closed[1].worn.leash == 1
        and charOf("Worn").worn.blind == nil
        and counters().playMin == 0
        and counters().petMin == 0
)

CCT.Net.Reset()
clear(sends)
CCT.Ledger.Flush("edge", noon(2026, 11, 11))
drain()
local closedWornAt = firstKind("Worn,", "2026-11-10")
local openLedgerAt = firstKind("Ledger,", "2026-11-11")
local openWornAt = firstKind("Worn,", "2026-11-11")
check("the closed worn body goes out and the empty day does not", closedWornAt ~= nil and openLedgerAt ~= nil and openWornAt == nil and closedWornAt < openLedgerAt)

local parsedColon = CCT.Net.Parse("Worn,day:2026-11-10,seq:1,w:a%3Ab:9,w:tail%25bell:2,w:taill_butplug:10")
check(
    "the worn colon is structural and the id is decoded",
    parsedColon ~= nil
        and parsedColon.kind == "worn"
        and parsedColon.many.w[1].id == "a:b"
        and parsedColon.many.w[1].minutes == 9
        and parsedColon.many.w[2].id == "tail%bell"
        and parsedColon.many.w[2].minutes == 2
        and parsedColon.many.w[3].id == "taill_butplug"
        and parsedColon.many.w[3].minutes == 10
)

bind("Master")
CCT.db.settings.masterName = "Master"
local D10 = "2026-11-10"

local function accept(kind, sender, parsed, now)
    return CCT.Store.Accept(kind, sender, parsed, now or day)
end

local function wornBody(seq, rows)
    return { fields = { day = D10, seq = tostring(seq) }, many = { w = rows } }
end

local function ledger(seq, extra)
    local fields = { day = D10, seq = tostring(seq) }
    for key, value in pairs(extra or {}) do
        fields[key:lower()] = tostring(value)
    end
    return { kind = "ledger", fields = fields, many = {} }
end

check(
    "a worn row keeps positive minutes and drops a zero",
    accept("worn", "Kitten", wornBody(4, { { id = "blind", minutes = 0 }, { id = "bell", minutes = 9 }, { id = "heels", minutes = 4 }, { id = "a:b", minutes = 3 } }), day) == true
)
local wornRow = CCT.db.master.kittens.Kitten.days[D10]
check("unknown and zero ids are absent", wornRow.worn.bell == 9 and wornRow.worn.blind == nil and wornRow.worn.heels == nil and wornRow.worn["a:b"] == nil and wornRow.seq == 4)

check(
    "the same seq replaces the worn map and does not add",
    accept("worn", "Kitten", wornBody(4, { { id = "taill_butplug", minutes = 4 } }), day + 5) == true
)
wornRow = CCT.db.master.kittens.Kitten.days[D10]
check("the replaced map drops the old id", wornRow.worn.taill_butplug == 4 and wornRow.worn.bell == nil and wornRow.seq == 4 and wornRow.at == day + 5)

check(
    "a same-seq ledger still writes counters",
    accept("ledger", "Kitten", ledger(4, { playMin = 6, petMiss = 10000, petMin = 5000 }), day + 9) == true
)
wornRow = CCT.db.master.kittens.Kitten.days[D10]
check(
    "ledger clamps pet counters and leaves worn",
    wornRow.fields.playMin == 6
        and wornRow.fields.petMiss == 9999
        and wornRow.fields.petMin == 1440
        and wornRow.worn.taill_butplug == 4
        and wornRow.seq == 4
        and wornRow.at == day + 9
)
check("an older worn seq is ignored", accept("worn", "Kitten", wornBody(3, { { id = "blind", minutes = 8 } }), day + 12) == false and wornRow.worn.blind == nil and wornRow.worn.taill_butplug == 4 and wornRow.at == day + 9)
check("a newer worn seq replaces the map", accept("worn", "Kitten", wornBody(5, { { id = "blind", minutes = 1 } }), day + 15) == true)
wornRow = CCT.db.master.kittens.Kitten.days[D10]
check("the newer map is only the new id", wornRow.worn.blind == 1 and wornRow.worn.taill_butplug == nil and wornRow.seq == 5 and wornRow.fields.playMin == 6)

CCT.Net.Reset()
clear(sends)
check("worn does not ack", accept("worn", "Kitten", wornBody(6, { { id = "bell", minutes = 2 } }), day + 20) == true)
drain()
local acked = false
for i = 1, #sends do
    if sends[i].message:find("LedgerAck,", 1, true) == 1 then
        acked = true
    end
end
check("a worn whisper has no ledger ack", acked == false and #sends == 0)

local wornIds = {
    "blind", "ears", "mittens", "bell", "tail", "jewel", "belt", "bra", "leash",
    "dildo", "inflatable_butplug", "inflatable_dildo", "small_butplug",
    "large_butplug", "taill_butplug", "vibes_pussy", "vibes_nipples",
    "vibes_ears", "nipple_piercings", "ear_piercings", "pussy_lipps_piercings",
}
local splitFields = { { "day", D10 }, { "seq", "8" } }
for i = 1, #wornIds do
    splitFields[#splitFields + 1] = { "w", wornIds[i] .. ":1440" }
end
local parts = CCT.Net.Pieces("worn", splitFields)
check("a full worn body splits", type(parts) == "table" and #parts >= 2, type(parts) == "table" and #parts or "nil")
if type(parts) == "table" then
    for i = 1, #parts do
        CCT.Net.Receive(CCT.PREFIX, parts[i], "WHISPER", "Split")
    end
end
local splitRow = CCT.db.master.kittens.Split and CCT.db.master.kittens.Split.days[D10]
local splitCount = 0
if type(splitRow) == "table" and type(splitRow.worn) == "table" then
    for _ in pairs(splitRow.worn) do
        splitCount = splitCount + 1
    end
end
check(
    "reassembled worn replaces with every id",
    splitRow ~= nil and splitRow.seq == 8 and splitCount == #wornIds and splitRow.worn.taill_butplug == 1440 and splitRow.worn.pussy_lipps_piercings == 1440,
    "count " .. tostring(splitCount)
)

bind("Maxed")
CCT.db.settings.masterName = "Nyx"
CCT.Ledger.OnLogin(day)
local maxedNames = {
    "heelsMin", "gagMin", "tasks", "heatPeak", "orgasm", "deny", "playMin",
    "pets", "hugs", "kisses", "spanks", "earPinch", "slack", "slackMin",
    "napOk", "napEarly", "napOver", "napMiss", "petMiss", "petMin",
}
for i = 1, #maxedNames do
    local name = maxedNames[i]
    local cap = 9999
    if name == "heelsMin" or name == "gagMin" or name == "playMin" or name == "slackMin" or name == "petMin" then
        cap = 1440
    elseif name == "heatPeak" then
        cap = 100
    end
    CCT.State.SetCounter(name, cap)
end
CCT.State.SetSub(100)
CCT.State.SetSeq(999999)
charOf("Maxed").dropSend = "2026-11-09"
charOf("Maxed").dropUntil = "2026-11-10"
CCT.Net.Reset()
clear(sends)
CCT.Ledger.Flush("timer", day)
drain()
local partCount = 0
local sawMiss = false
local sawMin = false
local sawDropped = false
for i = 1, #sends do
    local message = sends[i].message
    if message:find("Ledger,", 1, true) == 1 then
        partCount = partCount + 1
        if message:find("petMiss:9999", 1, true) then
            sawMiss = true
        end
        if message:find("petMin:1440", 1, true) then
            sawMin = true
        end
        if message:find("dropped:2026-11-09", 1, true) then
            sawDropped = true
        end
    end
end
check("a maxed ledger still splits and carries the pet fields", partCount >= 2 and sawMiss and sawMin and sawDropped, "parts " .. tostring(partCount))

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr10 self-check passed")
