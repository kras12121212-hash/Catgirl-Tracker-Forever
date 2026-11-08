-- Weekly ledger. One minute clock, one archive, absolute counters.
-- tasks is stored here and stays at 0. PR 8 is the only increment.
-- This file does not draw a scorecard and does not open a webhook.

local ADDON_NAME, CCT = ...

CCT.Ledger = {}

local MINUTE_CAP = 10080
local CHAR_CAP = 32768
local TIMER_GAP = 300

local COUNTERS = {
    "heelsMin", "gagMin", "tasks", "heatPeak", "orgasm", "deny", "playMin",
    "pets", "hugs", "kisses", "spanks", "earPinch", "slack", "slackMin",
    "napOk", "napEarly", "napOver", "napMiss",
}

local BEFORE_SUB = { "heelsMin", "gagMin", "tasks", "heatPeak", "orgasm", "deny", "playMin" }
local AFTER_SUB = {
    "pets", "hugs", "kisses", "spanks", "earPinch", "slack", "slackMin",
    "napOk", "napEarly", "napOver", "napMiss",
}

local minuteStamp = nil
local nextMinute = nil
local lastTimer = nil
local clockNow = nil
local wasOnline = false
local heldNoted = false
local heartbeatSent = false
local loginSent = false
local rolling = false
local flushing = false

local function Use(now)
    if now ~= nil then
        local stamp = tonumber(now)
        if stamp ~= nil then
            clockNow = stamp
        end
    end
    if clockNow ~= nil then
        return clockNow
    end
    if type(time) == "function" then
        return time()
    end
    return 0
end

function CCT.Ledger.Clock(now)
    return Use(now)
end

local function WeekId(now)
    if CCT.Week == nil or type(CCT.Week.Id) ~= "function" then
        return nil
    end
    return CCT.Week.Id(now)
end

local function MasterName()
    local settings = CCT.db and CCT.db.settings
    local name = settings and settings.masterName
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

local function MasterOnline()
    if MasterName() == nil then
        return false
    end
    return CCT.Roster ~= nil and type(CCT.Roster.IsMasterOnline) == "function" and CCT.Roster.IsMasterOnline() == true
end

local function Char()
    if CCT.Player == nil or type(CCT.Player.short) ~= "string" or CCT.Player.short == "" then
        return nil
    end
    if CCT.Saved == nil or type(CCT.Saved.EnsureChar) ~= "function" then
        return nil
    end
    local char = CCT.Saved.EnsureChar(CCT.Player.short)
    if type(char) ~= "table" then
        return nil
    end
    if type(char.zones) ~= "table" then
        char.zones = {}
    end
    if type(char.senders) ~= "table" then
        char.senders = {}
    end
    return char
end

local function State()
    if CCT.State == nil or type(CCT.State.Get) ~= "function" then
        return nil
    end
    return CCT.State.Get()
end

local function CopyMap(map)
    local out = {}
    if type(map) ~= "table" then
        return out
    end
    for key, value in pairs(map) do
        out[key] = value
    end
    return out
end

local function CopyList(list)
    local out = {}
    if type(list) ~= "table" then
        return out
    end
    for i = 1, #list do
        out[i] = list[i]
    end
    return out
end

local function CopyCounters(counters)
    local out = { seq = 1 }
    if type(counters) ~= "table" then
        return out
    end
    out.seq = tonumber(counters.seq) or 1
    for i = 1, #COUNTERS do
        out[COUNTERS[i]] = tonumber(counters[COUNTERS[i]]) or 0
    end
    return out
end

local function Bytes(value, depth, seen)
    if depth > 6 then
        return 0
    end
    local kind = type(value)
    if kind == "string" then
        return #value
    end
    if kind == "number" or kind == "boolean" then
        return 8
    end
    if kind ~= "table" then
        return 0
    end
    if seen[value] then
        return 0
    end
    seen[value] = true
    local total = 0
    for key, item in pairs(value) do
        total = total + Bytes(key, depth + 1, seen) + Bytes(item, depth + 1, seen)
    end
    return total
end

local function ClampCounter(name, value)
    local n = math.floor(tonumber(value) or 0)
    if n < 0 then
        n = 0
    end
    local cap = MINUTE_CAP
    if name == "heatPeak" or name == "sub" then
        cap = 100
    elseif name ~= "heelsMin" and name ~= "gagMin" and name ~= "playMin" and name ~= "slackMin" then
        cap = 9999
    end
    if n > cap then
        n = cap
    end
    return n
end

local function Mark(counters, sub, zones, senders)
    local parts = {}
    for i = 1, #COUNTERS do
        local name = COUNTERS[i]
        parts[#parts + 1] = name .. "=" .. tostring(tonumber(counters and counters[name]) or 0)
    end
    parts[#parts + 1] = "sub=" .. tostring(tonumber(sub) or 0)
    local names = {}
    if type(zones) == "table" then
        for zone in pairs(zones) do
            names[#names + 1] = tostring(zone)
        end
    end
    table.sort(names)
    for i = 1, #names do
        parts[#parts + 1] = names[i] .. "#" .. tostring(zones[names[i]])
    end
    if type(senders) == "table" then
        for i = 1, #senders do
            parts[#parts + 1] = "p=" .. tostring(senders[i])
        end
    end
    return table.concat(parts, ";")
end

local function Encode(value)
    local text = tostring(value):gsub("\r", "")
    text = text:gsub("%%", "%%25")
    text = text:gsub(",", "%%2C")
    text = text:gsub(":", "%%3A")
    text = text:gsub(";", "%%3B")
    text = text:gsub("\n", "%%0A")
    return text
end

local function Say(text)
    if type(print) == "function" then
        print(text)
    end
end

local function DropArchive(char, untilWeek)
    if type(char) ~= "table" or type(char.archive) ~= "table" then
        return false
    end
    local id = char.archive.week
    char.archive = nil
    if type(id) ~= "string" or id == "" then
        return false
    end
    char.droppedWeek = id
    char.dropSend = id
    char.dropUntil = untilWeek
    Say("|cffffff00CatgirlTracker:|r Unacked week " .. id .. " was dropped before it was retained.")
    return true
end

function CCT.Ledger.Guard()
    local char = Char()
    if char == nil or type(char.archive) ~= "table" then
        return false
    end
    if Bytes(char, 0, {}) <= CHAR_CAP then
        return false
    end
    local state = State()
    return DropArchive(char, state and state.week or nil)
end

local function PlanSeq(char, state)
    local week = state.week
    local mark = Mark(state.counters, state.sub, char.zones, char.senders)
    local sent = char.sent
    local seq = tonumber(state.counters and state.counters.seq) or 1
    if type(sent) == "table" and sent.week == week and sent.mark ~= mark then
        seq = (tonumber(sent.seq) or seq) + 1
        if seq < 1 then
            seq = 1
        end
    end
    return seq, mark
end

local function SyncSeq(char, state)
    local seq, mark = PlanSeq(char, state)
    if seq ~= (tonumber(state.counters and state.counters.seq) or 1) then
        CCT.State.SetSeq(seq)
    end
    return seq, mark
end

local function ShownHeat(state)
    return math.floor(((tonumber(state and state.heat) or 0) + 0.5))
end

function CCT.Ledger.EnsureWeek(now)
    if rolling then
        return false
    end
    local stamp = Use(now)
    local id = WeekId(stamp)
    local state = State()
    if id == nil or state == nil then
        return false
    end
    local current = state.week
    if current == id then
        return false
    end
    local char = Char()
    if char == nil then
        return false
    end
    rolling = true
    if type(current) == "string" and current ~= "" then
        if type(char.archive) == "table" then
            DropArchive(char, id)
        end
        local seq = SyncSeq(char, state)
        local counters = CopyCounters(state.counters)
        counters.seq = seq
        char.archive = {
            week = current,
            seq = seq,
            counters = counters,
            sub = tonumber(state.sub) or 0,
            zones = CopyMap(char.zones),
            senders = CopyList(char.senders),
        }
        char.sent = nil
    end
    for i = 1, #COUNTERS do
        CCT.State.SetCounter(COUNTERS[i], 0)
    end
    CCT.State.SetSeq(1)
    CCT.State.SetWeek(id)
    char.zones = {}
    char.senders = {}
    local shown = ShownHeat(state)
    if shown > 0 then
        CCT.State.SetCounter("heatPeak", shown)
    end
    rolling = false
    CCT.Ledger.Guard()
    return true
end

function CCT.Ledger.Stamp(now)
    minuteStamp = Use(now)
    nextMinute = minuteStamp + 60
    return minuteStamp
end

local function AddZone(char, zone, whole)
    if type(zone) ~= "string" or zone == "" or whole <= 0 then
        return
    end
    local nextValue = (tonumber(char.zones[zone]) or 0) + whole
    if nextValue < 0 then
        nextValue = 0
    end
    if nextValue > MINUTE_CAP then
        nextValue = MINUTE_CAP
    end
    char.zones[zone] = nextValue
end

function CCT.Ledger.AddMinutes(now, zoneName)
    local stamp = Use(now)
    CCT.Ledger.EnsureWeek(stamp)
    if minuteStamp == nil then
        minuteStamp = stamp
        return 0
    end
    local whole = math.floor((stamp - minuteStamp) / 60)
    if whole < 0 then
        whole = 0
    end
    minuteStamp = stamp
    if whole <= 0 then
        return 0
    end
    local state = State()
    local char = Char()
    if state == nil or char == nil then
        return whole
    end
    CCT.State.AddCounter("playMin", whole)
    if type(state.gag) == "string" and state.gag ~= "none" then
        CCT.State.AddCounter("gagMin", whole)
    end
    if type(state.heels) == "string" and state.heels ~= "none" then
        CCT.State.AddCounter("heelsMin", whole)
    end
    AddZone(char, zoneName, whole)
    CCT.Ledger.Guard()
    return whole
end

function CCT.Ledger.MinuteTick(now)
    local stamp = Use(now)
    if nextMinute == nil then
        nextMinute = stamp + 60
        if minuteStamp == nil then
            minuteStamp = stamp
        end
        return 0
    end
    if stamp < nextMinute then
        return 0
    end
    nextMinute = stamp + 60
    local zone = nil
    if CCT.Zone and type(CCT.Zone.Text) == "function" then
        zone = CCT.Zone.Text()
    end
    local state = State()
    if type(zone) ~= "string" or zone == "" then
        zone = state and state.zone or nil
    end
    return CCT.Ledger.AddMinutes(stamp, zone)
end

local function SortedNames(map)
    local names = {}
    if type(map) ~= "table" then
        return names
    end
    for name in pairs(map) do
        names[#names + 1] = tostring(name)
    end
    table.sort(names)
    return names
end

local function LedgerFields(week, seq, counters, sub, dropped)
    local fields = {
        { "week", week },
        { "seq", seq },
    }
    for i = 1, #BEFORE_SUB do
        local name = BEFORE_SUB[i]
        fields[#fields + 1] = { name, ClampCounter(name, counters and counters[name]) }
    end
    fields[#fields + 1] = { "sub", ClampCounter("sub", sub) }
    for i = 1, #AFTER_SUB do
        local name = AFTER_SUB[i]
        fields[#fields + 1] = { name, ClampCounter(name, counters and counters[name]) }
    end
    if type(dropped) == "string" and dropped ~= "" then
        fields[#fields + 1] = { "dropped", dropped }
    end
    return fields
end

local function ZoneFields(week, seq, zones)
    local fields = {
        { "week", week },
        { "seq", seq },
    }
    local names = SortedNames(zones)
    local any = false
    for i = 1, #names do
        local minutes = ClampCounter("playMin", zones[names[i]])
        if minutes > 0 then
            fields[#fields + 1] = { "z", Encode(names[i]) .. ":" .. tostring(minutes) }
            any = true
        end
    end
    if not any then
        return nil
    end
    return fields
end

local function PetFields(week, seq, senders)
    if type(senders) ~= "table" or #senders == 0 then
        return nil
    end
    local fields = {
        { "week", week },
        { "seq", seq },
    }
    for i = 1, #senders do
        local pair = tostring(senders[i])
        local action, sender = pair:match("^([^:]+):(.*)$")
        if action ~= nil and sender ~= nil and sender ~= "" then
            fields[#fields + 1] = { "p", action .. ":" .. Encode(sender) }
        end
    end
    if #fields <= 2 then
        return nil
    end
    return fields
end

local function Whisper(target, kind, fields)
    if target == nil or fields == nil or CCT.Net == nil or type(CCT.Net.Whisper) ~= "function" then
        return false
    end
    return CCT.Net.Whisper(target, kind, fields) and true or false
end

local function SendWeek(target, week, seq, counters, sub, zones, senders, dropped)
    if type(week) ~= "string" or week == "" then
        return false
    end
    local sent = Whisper(target, "ledger", LedgerFields(week, seq, counters, sub, dropped))
    local zonesFields = ZoneFields(week, seq, zones)
    if zonesFields ~= nil then
        sent = Whisper(target, "zones", zonesFields) or sent
    end
    local petBody = PetFields(week, seq, senders)
    if petBody ~= nil then
        sent = Whisper(target, "pets", petBody) or sent
    end
    return sent
end

local function Dirty(char, state)
    local sent = char.sent
    if type(sent) ~= "table" or sent.week ~= state.week then
        return true
    end
    return sent.mark ~= Mark(state.counters, state.sub, char.zones, char.senders)
end

function CCT.Ledger.Flush(reason, now)
    if flushing or rolling then
        return false
    end
    local stamp = Use(now)
    local state = State()
    local char = Char()
    if state == nil or char == nil then
        return false
    end
    flushing = true
    CCT.Ledger.EnsureWeek(stamp)
    state = State()
    char = Char()
    if state == nil or char == nil or MasterName() == nil then
        flushing = false
        return false
    end
    local dirty = Dirty(char, state)
    if reason == "timer" and not dirty and heartbeatSent then
        flushing = false
        return false
    end
    if not MasterOnline() then
        if not heldNoted then
            heldNoted = true
            Say("|cffffff00CatgirlTracker:|r Master is offline. The weekly report is held.")
        end
    else
        heldNoted = false
    end
    local target = MasterName()
    local dropped = nil
    if type(char.dropSend) == "string" and char.dropSend ~= "" and type(char.dropUntil) == "string" then
        dropped = char.dropSend
    end
    local archiveOk = true
    if type(char.archive) == "table" and type(char.archive.week) == "string" then
        archiveOk = SendWeek(
            target,
            char.archive.week,
            char.archive.seq or 1,
            char.archive.counters,
            char.archive.sub,
            char.archive.zones,
            char.archive.senders,
            dropped
        ) and true or false
    end
    local seq, mark = PlanSeq(char, state)
    local currentSent = SendWeek(target, state.week, seq, state.counters, state.sub, char.zones, char.senders, dropped) and true or false
    if currentSent then
        if seq ~= (tonumber(state.counters and state.counters.seq) or 1) then
            CCT.State.SetSeq(seq)
        end
        char.sent = { week = state.week, seq = seq, mark = mark }
        heartbeatSent = archiveOk
    end
    flushing = false
    if currentSent or (archiveOk and type(char.archive) == "table") then
        CCT.Debug("ledger", 5, string.format("Ledger flush %s seq %s.", tostring(state.week), tostring(seq)))
    end
    return currentSent or (type(char.archive) == "table" and archiveOk)
end

function CCT.Ledger.NoteMaster()
    local online = MasterOnline()
    if online and not wasOnline then
        wasOnline = true
        heldNoted = false
        heartbeatSent = false
        local name = MasterName() or ""
        Say("|cffffff00CatgirlTracker:|r Master has come online nya your report will be compiled !! " .. name)
        CCT.Ledger.Flush("edge")
        return true
    end
    if not online and wasOnline then
        wasOnline = false
        heartbeatSent = false
    end
    return false
end

function CCT.Ledger.LoginFlush()
    CCT.Ledger.NoteMaster()
    if not loginSent and MasterName() ~= nil and not wasOnline then
        CCT.Ledger.Flush("edge")
    end
    loginSent = true
    return true
end

function CCT.Ledger.Tick(now)
    local stamp = Use(now)
    CCT.Ledger.MinuteTick(stamp)
    if lastTimer == nil then
        lastTimer = stamp
        return false
    end
    if stamp - lastTimer < TIMER_GAP then
        return false
    end
    lastTimer = stamp
    return CCT.Ledger.Flush("timer", stamp)
end

function CCT.Ledger.OnAck(sender, parsed)
    if type(parsed) ~= "table" or type(parsed.fields) ~= "table" then
        return false
    end
    local master = MasterName()
    if master == nil or not CCT.SameName(sender, master) then
        return false
    end
    local week = parsed.fields.week
    local seq = tonumber(parsed.fields.seq) or 0
    if type(week) ~= "string" or week == "" then
        return false
    end
    local char = Char()
    if char == nil then
        return false
    end
    local dropped = false
    if type(char.archive) == "table" and char.archive.week == week and seq >= (tonumber(char.archive.seq) or 1) then
        char.archive = nil
        dropped = true
    end
    if char.dropUntil ~= nil and week == char.dropUntil then
        char.dropSend = nil
        char.dropUntil = nil
    end
    return dropped
end

function CCT.Ledger.PushSender(pair)
    local char = Char()
    if char == nil or type(pair) ~= "string" or pair == "" then
        return nil
    end
    local list = char.senders
    for i = #list, 1, -1 do
        if list[i] == pair then
            table.remove(list, i)
        end
    end
    list[#list + 1] = pair
    while #list > 20 do
        table.remove(list, 1)
    end
    CCT.Ledger.Guard()
    return list
end

function CCT.Ledger.Zones()
    local char = Char()
    if char == nil then
        return {}
    end
    return char.zones
end

function CCT.Ledger.Senders()
    local char = Char()
    if char == nil then
        return {}
    end
    return char.senders
end

function CCT.Ledger.Archive()
    local char = Char()
    if char == nil then
        return nil
    end
    return char.archive
end

function CCT.Ledger.Dropped()
    local char = Char()
    if char == nil then
        return nil
    end
    return char.droppedWeek
end

function CCT.Ledger.OnLogin(now)
    local stamp = Use(now)
    CCT.Ledger.EnsureWeek(stamp)
    minuteStamp = stamp
    nextMinute = stamp + 60
    lastTimer = stamp
    loginSent = false
    wasOnline = false
    heartbeatSent = false
    heldNoted = false
end

function CCT.Ledger.OnEvent(_, event)
    if event == "PLAYER_LOGIN" then
        CCT.Ledger.OnLogin(type(time) == "function" and time() or nil)
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then
        CCT.Ledger.LoginFlush()
    end
end

if CCT.Net and type(CCT.Net.On) == "function" then
    CCT.Net.On("ledgerack", function(sender, parsed, channel)
        if channel ~= "WHISPER" then
            return
        end
        CCT.Ledger.OnAck(sender, parsed)
    end)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:SetScript("OnEvent", CCT.Ledger.OnEvent)
end

if C_Timer and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(1, function()
        CCT.Ledger.Tick(type(time) == "function" and time() or nil)
    end)
end
