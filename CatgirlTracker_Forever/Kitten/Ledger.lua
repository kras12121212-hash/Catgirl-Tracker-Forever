-- Daily scorecard. One minute clock, fourteen days, absolute counters.
-- tasks is stored here and stays at 0. PR 8 is the only increment.
-- This file does not draw a scorecard and does not open a webhook.

local ADDON_NAME, CCT = ...

CCT.Ledger = {}

local MINUTE_CAP = 1440
local CHAR_CAP = 262144
local CLOSED_CAP = 13
local TIMER_GAP = 300

local COUNTERS = {
    "heelsMin", "gagMin", "tasks", "heatPeak", "orgasm", "deny", "playMin",
    "pets", "hugs", "kisses", "spanks", "earPinch", "slack", "slackMin",
    "napOk", "napEarly", "napOver", "napMiss", "petMiss", "petMin",
}

local BEFORE_SUB = { "heelsMin", "gagMin", "tasks", "heatPeak", "orgasm", "deny", "playMin" }
local AFTER_SUB = {
    "pets", "hugs", "kisses", "spanks", "earPinch", "slack", "slackMin",
    "napOk", "napEarly", "napOver", "napMiss", "petMiss", "petMin",
}

local WORN_ENUM = { "blind", "ears", "mittens" }
local WORN_FLAG = { "bell", "tail", "jewel", "belt", "bra", "leash" }
local WORN_GEAR = {
    blind = true, ears = true, mittens = true, bell = true, tail = true,
    jewel = true, belt = true, bra = true, leash = true,
}

local minuteStamp = nil
local nextMinute = nil
local lastTimer = nil
local clockNow = nil
local wasOnline = false
local heldNoted = false
local heartbeatSent = false
local rolling = false

function CCT.Ledger.Rolling()
    return rolling
end

local flushing = false
local queuedClosed = {}

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

local function DayId(now)
    if CCT.Day == nil or type(CCT.Day.Id) ~= "function" then
        return nil
    end
    return CCT.Day.Id(now)
end

local function IsDayId(id)
    return type(id) == "string" and id:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

local function IsWeekId(id)
    return type(id) == "string" and id:match("^%d%d%d%d%-W%d%d$") ~= nil
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
    if type(char.worn) ~= "table" then
        char.worn = {}
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
    elseif name ~= "heelsMin" and name ~= "gagMin" and name ~= "playMin" and name ~= "slackMin" and name ~= "petMin" then
        cap = 9999
    end
    if n > cap then
        n = cap
    end
    return n
end

local function Mark(counters, sub, zones, senders, worn)
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
    local wornNames = {}
    if type(worn) == "table" then
        for id, minutes in pairs(worn) do
            if (tonumber(minutes) or 0) > 0 then
                wornNames[#wornNames + 1] = tostring(id)
            end
        end
    end
    table.sort(wornNames)
    for i = 1, #wornNames do
        parts[#parts + 1] = "w=" .. wornNames[i] .. "#" .. tostring(worn[wornNames[i]])
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

local function DropClosed(char, untilDay)
    if type(char) ~= "table" or type(char.days) ~= "table" or #char.days < 1 then
        return false
    end
    local row = table.remove(char.days, 1)
    local id = type(row) == "table" and row.day or nil
    if type(id) ~= "string" or id == "" then
        return false
    end
    char.droppedDay = id
    char.dropSend = id
    char.dropUntil = untilDay
    Say("|cffffff00CatgirlTracker:|r Unacked day " .. id .. " was dropped before it was retained.")
    return true
end

function CCT.Ledger.Guard()
    local char = Char()
    if char == nil or type(char.days) ~= "table" or #char.days == 0 then
        return false
    end
    if Bytes(char, 0, {}) <= CHAR_CAP then
        return false
    end
    local state = State()
    return DropClosed(char, state and state.week or nil)
end

local function PlanSeq(char, state)
    local day = state.week
    local mark = Mark(state.counters, state.sub, char.zones, char.senders, char.worn)
    local sent = char.sent
    local seq = tonumber(state.counters and state.counters.seq) or 1
    if type(sent) == "table" and sent.day == day and sent.mark ~= mark then
        seq = (tonumber(sent.seq) or seq) + 1
        if seq < 1 then
            seq = 1
        end
    end
    return seq, mark
end

local function ShownHeat(state)
    return math.floor(((tonumber(state and state.heat) or 0) + 0.5))
end

local function WeekPeriod(state, char)
    if state ~= nil and IsWeekId(state.week) then
        return true
    end
    if state ~= nil and type(state.counters) == "table" and IsWeekId(state.counters.week) then
        return true
    end
    if char ~= nil and type(char.archive) == "table" and IsWeekId(char.archive.week) then
        return true
    end
    if char ~= nil and IsWeekId(char.droppedWeek) then
        return true
    end
    return false
end

local function ClearWeekDrops(char)
    if type(char) ~= "table" then
        return
    end
    if type(char.archive) == "table" and IsWeekId(char.archive.week) then
        char.archive = nil
    end
    if IsWeekId(char.droppedWeek) then
        char.droppedWeek = nil
    end
    if IsWeekId(char.dropSend) then
        char.dropSend = nil
    end
    if IsWeekId(char.dropUntil) then
        char.dropUntil = nil
    end
end

local function ZeroScorecard(state, char, id)
    for i = 1, #COUNTERS do
        CCT.State.SetCounter(COUNTERS[i], 0)
    end
    CCT.State.SetSeq(1)
    if char ~= nil then
        char.zones = {}
        char.senders = {}
        char.worn = {}
    end
    CCT.State.SetWeek(id)
    local shown = ShownHeat(State() or state)
    if shown > 0 then
        CCT.State.SetCounter("heatPeak", shown)
    end
end

function CCT.Ledger.EnsureWeek(now)
    if rolling then
        return false
    end
    local stamp = Use(now)
    local id = DayId(stamp)
    local state = State()
    if id == nil or state == nil then
        return false
    end
    local char = Char()
    if char == nil then
        return false
    end
    rolling = true
    local retire = WeekPeriod(state, char)
    ClearWeekDrops(char)
    if retire then
        ZeroScorecard(state, char, id)
        Say("|cffffff00CatgirlTracker:|r The weekly scorecard was retired and today starts at zero.")
        rolling = false
        CCT.Ledger.Guard()
        return false
    end
    state = State()
    if state == nil or state.week == id then
        rolling = false
        return false
    end
    if IsDayId(state.week) then
        if type(char.days) ~= "table" then
            char.days = {}
        end
        if #char.days >= CLOSED_CAP then
            DropClosed(char, id)
        end
        local seq = PlanSeq(char, state)
        local counters = CopyCounters(state.counters)
        counters.seq = seq
        char.days[#char.days + 1] = {
            day = state.week,
            seq = seq,
            counters = counters,
            sub = tonumber(state.sub) or 0,
            zones = CopyMap(char.zones),
            senders = CopyList(char.senders),
            worn = CopyMap(char.worn),
        }
        char.sent = nil
    end
    ZeroScorecard(state, char, id)
    rolling = false
    CCT.Ledger.Guard()
    return true
end

function CCT.Ledger.Stamp(now)
    minuteStamp = Use(now)
    nextMinute = minuteStamp + 60
    return minuteStamp
end

local function AddWornMinutes(char, id, whole)
    if type(char.worn) ~= "table" then
        char.worn = {}
    end
    local nextValue = (tonumber(char.worn[id]) or 0) + whole
    if nextValue < 0 then
        nextValue = 0
    end
    if nextValue > MINUTE_CAP then
        nextValue = MINUTE_CAP
    end
    if nextValue > 0 then
        char.worn[id] = nextValue
    end
end

local function WornAllowed(id)
    if WORN_GEAR[id] then
        return true
    end
    local toys = CCT.State and CCT.State.Toys
    if type(toys) ~= "table" then
        return false
    end
    for i = 1, #toys do
        if toys[i].id == id then
            return true
        end
    end
    return false
end

-- Worn minutes follow the same whole-minute clock. The pet journal is not read.
local function AddWorn(char, state, whole)
    for i = 1, #WORN_ENUM do
        local id = WORN_ENUM[i]
        local value = state[id]
        if type(value) == "string" and value ~= "none" then
            AddWornMinutes(char, id, whole)
        end
    end
    for i = 1, #WORN_FLAG do
        local id = WORN_FLAG[i]
        if state[id] == true then
            AddWornMinutes(char, id, whole)
        end
    end
    local toys = state.toys
    local specs = CCT.State and CCT.State.Toys
    if type(toys) ~= "table" or type(specs) ~= "table" then
        return
    end
    for i = 1, #specs do
        local id = specs[i].id
        local toy = toys[id]
        if type(toy) == "table" and toy.applied == true then
            AddWornMinutes(char, id, whole)
        end
    end
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
    if state.petSummoned == true and CCT.Module and type(CCT.Module.Enabled) == "function" and CCT.Module.Enabled("PetTracker") == true then
        CCT.State.AddCounter("petMin", whole)
    end
    AddWorn(char, state, whole)
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

local function LedgerFields(day, seq, counters, sub, dropped)
    local fields = {
        { "day", day },
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

local function ZoneFields(day, seq, zones)
    local fields = {
        { "day", day },
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

local function WornFields(day, seq, worn)
    local fields = {
        { "day", day },
        { "seq", seq },
    }
    local names = SortedNames(worn)
    local any = false
    for i = 1, #names do
        if WornAllowed(names[i]) then
            local minutes = ClampCounter("petMin", worn[names[i]])
            if minutes > 0 then
                fields[#fields + 1] = { "w", Encode(names[i]) .. ":" .. tostring(minutes) }
                any = true
            end
        end
    end
    if not any then
        return nil
    end
    return fields
end

local function PetFields(day, seq, senders)
    if type(senders) ~= "table" or #senders == 0 then
        return nil
    end
    local fields = {
        { "day", day },
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

local function SendDay(target, day, seq, counters, sub, zones, senders, worn, dropped)
    if not IsDayId(day) then
        return false
    end
    local ledgerOk = Whisper(target, "ledger", LedgerFields(day, seq, counters, sub, dropped))
    local zonesFields = ZoneFields(day, seq, zones)
    if zonesFields ~= nil then
        Whisper(target, "zones", zonesFields)
    end
    local petBody = PetFields(day, seq, senders)
    if petBody ~= nil then
        Whisper(target, "pets", petBody)
    end
    local wornBody = WornFields(day, seq, worn)
    if wornBody ~= nil then
        Whisper(target, "worn", wornBody)
    end
    return ledgerOk and true or false
end

local function Dirty(char, state)
    local sent = char.sent
    if type(sent) ~= "table" or sent.day ~= state.week then
        return true
    end
    return sent.mark ~= Mark(state.counters, state.sub, char.zones, char.senders, char.worn)
end

local function DroppedToken(char)
    if type(char.dropSend) == "string" and char.dropSend ~= "" and type(char.dropUntil) == "string" then
        return char.dropSend
    end
    return nil
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
    if reason == "timer" then
        local dirty = Dirty(char, state)
        if not dirty and heartbeatSent then
            flushing = false
            return false
        end
    end
    if not MasterOnline() then
        if not heldNoted then
            heldNoted = true
            Say("|cffffff00CatgirlTracker:|r Master is offline. The daily report is held.")
        end
    else
        heldNoted = false
    end
    local target = MasterName()
    local dropped = DroppedToken(char)
    local any = false
    if reason == "edge" then
        queuedClosed = {}
        local closed = char.days
        if type(closed) == "table" then
            for i = 1, #closed do
                local row = closed[i]
                if type(row) == "table" and IsDayId(row.day) and queuedClosed[row.day] ~= true then
                    local queued = SendDay(
                        target,
                        row.day,
                        row.seq or 1,
                        row.counters,
                        row.sub,
                        row.zones,
                        row.senders,
                        row.worn,
                        dropped
                    )
                    if queued then
                        queuedClosed[row.day] = true
                        any = true
                    end
                end
            end
        end
    end
    local seq, mark = PlanSeq(char, state)
    local currentSent = SendDay(target, state.week, seq, state.counters, state.sub, char.zones, char.senders, char.worn, dropped)
    if currentSent then
        if seq ~= (tonumber(state.counters and state.counters.seq) or 1) then
            CCT.State.SetSeq(seq)
        end
        char.sent = { day = state.week, seq = seq, mark = mark }
        heartbeatSent = true
        any = true
    end
    flushing = false
    if any then
        CCT.Debug("ledger", 5, string.format("Ledger flush %s seq %s.", tostring(state.week), tostring(seq)))
    end
    return any
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
    local day = parsed.fields.day
    if type(day) ~= "string" or day == "" then
        return false
    end
    local seq = tonumber(parsed.fields.seq) or 0
    local char = Char()
    if char == nil then
        return false
    end
    local removed = false
    if type(char.days) == "table" then
        for i = 1, #char.days do
            local row = char.days[i]
            if type(row) == "table" and row.day == day and seq >= (tonumber(row.seq) or 1) then
                table.remove(char.days, i)
                removed = true
                break
            end
        end
    end
    if char.dropUntil ~= nil and day == char.dropUntil then
        char.dropSend = nil
        char.dropUntil = nil
    end
    return removed
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

function CCT.Ledger.Days()
    local char = Char()
    if char == nil or type(char.days) ~= "table" then
        return {}
    end
    return char.days
end

function CCT.Ledger.Dropped()
    local char = Char()
    if char == nil then
        return nil
    end
    return char.droppedDay
end

-- Not the store. An old call does not throw.
function CCT.Ledger.Archive()
    return nil
end

function CCT.Ledger.OnLogin(now)
    local stamp = Use(now)
    queuedClosed = {}
    CCT.Ledger.EnsureWeek(stamp)
    minuteStamp = stamp
    nextMinute = stamp + 60
    lastTimer = stamp
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
