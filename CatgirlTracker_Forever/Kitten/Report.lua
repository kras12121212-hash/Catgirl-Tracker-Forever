-- Kitten reports. State, Pos, Ack, and Prox leave through CCT.Net.
-- Jewel samples call CCT.State.SetPos. This file does not move other feature state.
-- The live pin updates every 20 seconds. Walk history is one point about every
-- minute, plus a point when the map changes, kept for 30 days.
-- Unsent history rides along in Pos and catches up after the owner was offline.
-- Ledger bodies are not built here. OwnerWeek is not sent.

local ADDON_NAME, CCT = ...

CCT.Report = {}

local HEEL_RANGE = 0.005
local NEAR_RANGE = 0.02
local HEAT_GAP = 10
local SAMPLE_GAP = 20
local HISTORY_GAP = 60
local TRAIL_SECONDS = 30 * 24 * 60 * 60
local TRAIL_CAP = 45000
local PING_GAP = 1

local loginArmed = false
local loginSealed = false
local sawRoster = false
local listening = false
local lastFingerprint = nil
local lastShown = nil
local lastPosKey = nil
local heatDueAt = nil
local lastHeatSentAt = 0
local nextSampleAt = nil
local pendingOwner = nil
local trailQueued = nil
local lastPing = { maid = 0, high = 0, ballet = 0 }
local proxHandles = {}

local HEEL_FILE = {
    maid = "HighHeels3.ogg",
    high = "HighHeels8.ogg",
    ballet = "HighHeels12.ogg",
}
local BELL_FILE = {
    bell = "Bell.ogg",
    tail = "sbell4seconds.ogg",
}

local function Clock()
    if CCT.Net and CCT.Net.Clock then
        return CCT.Net.Clock()
    end
    return CCT.UnixNow()
end

-- Net.Clock is seconds since the client started. A saved walk time has to be time().
local UNIX_FLOOR = 1000000000

local function Wall(now)
    local stamp = tonumber(now)
    if stamp ~= nil and stamp >= UNIX_FLOOR then
        return math.floor(stamp)
    end
    local unix = tonumber(CCT.UnixNow and CCT.UnixNow())
    if unix ~= nil and unix >= UNIX_FLOOR then
        return math.floor(unix)
    end
    if stamp ~= nil then
        return math.floor(stamp)
    end
    return math.floor(unix or 0)
end

local function OwnerShort()
    if CCT.Roster and CCT.Roster.GetOwnerShort then
        return CCT.Roster.GetOwnerShort()
    end
    return nil
end

local function State()
    if CCT.State and CCT.State.Get then
        return CCT.State.Get()
    end
    return nil
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Round4(value)
    local number = tonumber(value)
    if number == nil then
        return nil
    end
    if number >= 0 then
        return math.floor(number * 10000 + 0.5) / 10000
    end
    return math.ceil(number * 10000 - 0.5) / 10000
end

function CCT.Report.Here()
    local mapID, x, y, instanceID
    if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
        local rawMap = C_Map.GetBestMapForUnit("player")
        if type(issecretvalue) == "function" and issecretvalue(rawMap) then
            return nil
        end
        if type(rawMap) ~= "number" then
            return nil
        end
        mapID = rawMap
        if type(C_Map.GetPlayerMapPosition) == "function" then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if type(issecretvalue) == "function" and issecretvalue(pos) then
                return nil
            end
            if type(pos) ~= "table" then
                return nil
            end
            local rawX, rawY = pos.x, pos.y
            if type(pos.GetXY) == "function" then
                rawX, rawY = pos:GetXY()
            end
            if type(issecretvalue) == "function" and (issecretvalue(rawX) or issecretvalue(rawY)) then
                return nil
            end
            x = Round4(rawX)
            y = Round4(rawY)
            if x == nil or y == nil then
                return nil
            end
        end
    end
    if (x == nil or y == nil) and type(GetPlayerMapPosition) == "function" then
        local rawX, rawY = GetPlayerMapPosition("player")
        if type(issecretvalue) == "function" and (issecretvalue(rawX) or issecretvalue(rawY)) then
            return nil
        end
        x = Round4(rawX)
        y = Round4(rawY)
    end
    if type(GetInstanceInfo) == "function" then
        local rawInst = select(8, GetInstanceInfo())
        if type(issecretvalue) == "function" and issecretvalue(rawInst) then
            rawInst = nil
        end
        if type(rawInst) == "number" and rawInst > 0 then
            instanceID = rawInst
        end
    end
    if mapID == nil or x == nil or y == nil then
        return {
            mapID = mapID,
            x = x,
            y = y,
            instanceID = instanceID,
            t = Clock(),
        }
    end
    return {
        mapID = mapID,
        x = x,
        y = y,
        instanceID = instanceID,
        t = Clock(),
    }
end

local function Media(path)
    return (CCT.MEDIA or "") .. path
end

local function PlayFile(path)
    if type(path) ~= "string" or path == "" or type(PlaySoundFile) ~= "function" then
        return nil
    end
    local first, second = PlaySoundFile(path, "Master")
    if type(first) == "number" then
        return first
    end
    if type(second) == "number" then
        return second
    end
    return true
end

local function StopHandle(key)
    local handle = proxHandles[key]
    proxHandles[key] = nil
    if type(handle) == "number" and type(StopSound) == "function" then
        StopSound(handle)
    end
end

local function KittenChar()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" or CCT.Saved == nil or type(CCT.Saved.EnsureChar) ~= "function" then
        return nil
    end
    return CCT.Saved.EnsureChar(short)
end

local function TrailSent(char)
    local sent = char and tonumber(char.trailSent) or 0
    if sent < 0 then
        sent = 0
    end
    return sent
end

local function TrailFresh(stamp, at)
    return (stamp - at) <= TRAIL_SECONDS and (at - stamp) <= TRAIL_SECONDS
end

function CCT.Report.AppendTrail(list, point, now)
    if type(list) ~= "table" or type(point) ~= "table" then
        return list
    end
    local stamp = tonumber(now) or tonumber(point.t) or Clock()
    local at = math.floor(tonumber(point.t) or stamp)
    local mapID = tonumber(point.mapID)
    local x = tonumber(point.x)
    local y = tonumber(point.y)
    if mapID == nil or x == nil or y == nil then
        return list
    end
    local fresh = TrailFresh(stamp, at)
    local function prune()
        local guard = 0
        while #list > 0 and guard < 100000 do
            guard = guard + 1
            local rowAt = type(list[1]) == "table" and tonumber(list[1].t) or nil
            local tooOld = rowAt == nil or not TrailFresh(stamp, rowAt)
            if tooOld or #list > TRAIL_CAP then
                table.remove(list, 1)
            else
                break
            end
        end
    end
    local lastRow = list[#list]
    local lastAt = type(lastRow) == "table" and tonumber(lastRow.t) or nil
    if fresh and (lastAt == nil or at > lastAt) then
        list[#list + 1] = {
            mapID = mapID,
            x = x,
            y = y,
            instanceID = type(point.instanceID) == "number" and point.instanceID or nil,
            t = at,
        }
        prune()
        return list
    end
    for i = #list, 1, -1 do
        local row = list[i]
        if type(row) == "table" and tonumber(row.t) == at then
            if fresh then
                row.mapID = mapID
                row.x = x
                row.y = y
                row.t = at
                if type(point.instanceID) == "number" then
                    row.instanceID = point.instanceID
                end
            else
                table.remove(list, i)
            end
            prune()
            return list
        end
    end
    if fresh then
        local row = {
            mapID = mapID,
            x = x,
            y = y,
            instanceID = type(point.instanceID) == "number" and point.instanceID or nil,
            t = at,
        }
        local lastAt = type(list[#list]) == "table" and tonumber(list[#list].t) or nil
        if lastAt == nil or at > lastAt then
            list[#list + 1] = row
        else
            local placed = false
            for i = 1, #list do
                local rowAt = type(list[i]) == "table" and tonumber(list[i].t) or 0
                if at < rowAt then
                    table.insert(list, i, row)
                    placed = true
                    break
                end
            end
            if not placed then
                list[#list + 1] = row
            end
        end
    end
    prune()
    return list
end

function CCT.Report.NoteHistory(point)
    local state = State()
    if type(state) ~= "table" or state.jewel ~= true or type(point) ~= "table" then
        return false
    end
    if tonumber(point.mapID) == nil or tonumber(point.x) == nil or tonumber(point.y) == nil then
        return false
    end
    local char = KittenChar()
    if type(char) ~= "table" then
        return false
    end
    char.trail = char.trail or {}
    local trail = char.trail
    local last = trail[#trail]
    local stamp = math.floor(tonumber(point.t) or Clock())
    local lastAt = type(last) == "table" and tonumber(last.t) or nil
    local mapChanged = type(last) == "table" and tonumber(last.mapID) ~= tonumber(point.mapID)
    if lastAt ~= nil and not mapChanged and (stamp - lastAt) < HISTORY_GAP then
        return false
    end
    if lastAt ~= nil and stamp <= lastAt then
        stamp = math.floor(lastAt) + 1
    end
    local sent = TrailSent(char)
    if stamp <= sent then
        stamp = sent + 1
    end
    CCT.Report.AppendTrail(trail, {
        mapID = point.mapID,
        x = point.x,
        y = point.y,
        instanceID = point.instanceID,
        t = stamp,
    }, stamp)
    return true
end

local function ShownHeat(state)
    return math.floor(((tonumber(state and state.heat) or 0) + 0.5))
end

local function Whole(value)
    local n = math.floor(tonumber(value) or 0)
    if n < 0 then
        n = 0
    end
    return n
end

local function KittenLife()
    local short = CCT.Player and CCT.Player.short
    local chars = CCT.db and CCT.db.chars
    if type(short) ~= "string" or type(chars) ~= "table" or type(chars[short]) ~= "table" then
        return nil
    end
    local life = chars[short].life
    if type(life) ~= "table" then
        return nil
    end
    return life
end

-- Counts for the owner stats. The timestamp list stays on the kitten.
-- orgWeek is the scorecard week counter, which survives the fifty-stamp cap.
local function OrgasmWire(state)
    local life = KittenLife()
    local list = type(life) == "table" and life.orgasms or nil
    local total = 0
    local last = nil
    if type(life) == "table" then
        total = Whole(life.total)
        local seen = type(list) == "table" and #list or 0
        if total < seen then
            total = seen
        end
    end
    if type(list) == "table" then
        for i = 1, #list do
            local at = tonumber(list[i])
            if at ~= nil and (last == nil or at >= last) then
                last = at
            end
        end
    end
    local today = 0
    if CCT.Submissiveness and type(CCT.Submissiveness.OrgasmsToday) == "function" then
        today = Whole(CCT.Submissiveness.OrgasmsToday(life, CCT.UnixNow()))
    end
    local week = Whole(type(state.counters) == "table" and state.counters.orgasm or 0)
    local denied = Whole(type(life) == "table" and life.denied or 0)
    return total, today, week, denied, last
end

local function PosKey(pos)
    if type(pos) ~= "table" then
        return ""
    end
    return table.concat({
        tostring(pos.mapID),
        tostring(pos.x),
        tostring(pos.y),
        tostring(pos.instanceID),
        tostring(pos.t),
    }, "|")
end

local function Fingerprint(state)
    if type(state) ~= "table" then
        return ""
    end
    local bits = {
        tostring(state.gag),
        tostring(state.gagStage),
        tostring(state.blind),
        tostring(state.ears),
        tostring(state.mittens),
        tostring(state.heels),
        tostring(state.bell),
        tostring(state.tail),
        tostring(state.jewel),
        tostring(state.belt),
        tostring(state.beltMode),
        tostring(state.bra),
        tostring(state.leash),
        tostring(state.leashOwner),
        tostring(state.zone),
        tostring(state.instanceType),
        tostring(state.sub),
        tostring(state.week),
    }
    local levels = state.heelLevel or {}
    bits[#bits + 1] = tostring(levels.maid)
    bits[#bits + 1] = tostring(levels.high)
    bits[#bits + 1] = tostring(levels.ballet)
    local toys = state.toys or {}
    local toyList = CCT.State and CCT.State.Toys or {}
    for i = 1, #toyList do
        local row = toys[toyList[i].id] or {}
        bits[#bits + 1] = table.concat({
            toyList[i].id,
            row.applied and "1" or "0",
            tostring(row.vibe or 0),
            tostring(row.inflate or 0),
        }, ":")
    end
    local locks = state.locks or {}
    local binds = CCT.State and CCT.State.LockBinds or {}
    for i = 1, #binds do
        local row = locks[binds[i]]
        bits[#bits + 1] = binds[i] .. "=" .. tostring(type(row) == "table" and row.unlockAt or "")
    end
    local counters = state.counters or {}
    local names = {
        "seq", "heelsMin", "gagMin", "tasks", "orgasm", "deny", "playMin",
        "pets", "hugs", "kisses", "spanks", "earPinch", "slack", "slackMin",
        "napOk", "napEarly", "napOver", "napMiss",
    }
    for i = 1, #names do
        bits[#bits + 1] = names[i] .. "=" .. tostring(counters[names[i]] or 0)
    end
    return table.concat(bits, ";")
end

local function Flag(value)
    return value and "1" or "0"
end

local function Add(fields, key, value)
    if value ~= nil then
        fields[#fields + 1] = { key, value }
    end
end

function CCT.Report.StateFields(state)
    state = state or State()
    local fields = {}
    if type(state) ~= "table" then
        return fields
    end
    local week = state.week
    if (type(week) ~= "string" or week == "") and CCT.Week and CCT.Week.Id then
        week = CCT.Week.Id()
    end
    Add(fields, "rev", tonumber(state.rev) or 0)
    Add(fields, "week", week or "")
    Add(fields, "gag", state.gag or "none")
    if state.gag == "inflatable" then
        Add(fields, "gagStage", tonumber(state.gagStage) or 0)
    end
    if state.blind and state.blind ~= "none" then
        Add(fields, "blind", state.blind)
    end
    if state.ears and state.ears ~= "none" then
        Add(fields, "ears", state.ears)
    end
    if state.mittens and state.mittens ~= "none" then
        Add(fields, "mittens", state.mittens)
    end
    if state.heels and state.heels ~= "none" then
        Add(fields, "heels", state.heels)
    end
    local levels = state.heelLevel or {}
    Add(fields, "hMaid", tonumber(levels.maid) or 1)
    Add(fields, "hHigh", tonumber(levels.high) or 1)
    Add(fields, "hBallet", tonumber(levels.ballet) or 1)
    if state.bell == true then
        Add(fields, "bell", "1")
    end
    if state.tail == true then
        Add(fields, "tail", "1")
    end
    if state.jewel == true then
        Add(fields, "jewel", "1")
    end
    if state.belt == true then
        Add(fields, "belt", "1")
    end
    if state.bra == true then
        Add(fields, "bra", "1")
    end
    if state.leash == true then
        Add(fields, "leash", "1")
        if state.leashOwner ~= nil then
            Add(fields, "leashOwner", state.leashOwner)
        end
    end
    if state.beltMode and state.beltMode ~= "allow" then
        Add(fields, "beltMode", state.beltMode)
    end
    Add(fields, "zone", state.zone or "")
    Add(fields, "inst", state.instanceType or "")
    Add(fields, "heat", ShownHeat(state))
    Add(fields, "sub", tonumber(state.sub) or 0)
    local orgTotal, orgDay, orgWeek, orgDeny, orgLast = OrgasmWire(state)
    Add(fields, "orgTotal", orgTotal)
    Add(fields, "orgDay", orgDay)
    Add(fields, "orgWeek", orgWeek)
    Add(fields, "orgDeny", orgDeny)
    if orgLast ~= nil then
        Add(fields, "orgLast", math.floor(orgLast))
    end
    local locks = state.locks or {}
    local binds = CCT.State and CCT.State.LockBinds or {}
    for i = 1, #binds do
        local row = locks[binds[i]]
        if type(row) == "table" and tonumber(row.unlockAt) then
            Add(fields, "lk", binds[i] .. ":" .. tostring(math.floor(row.unlockAt)))
        end
    end
    local toys = state.toys or {}
    local toyList = CCT.State and CCT.State.Toys or {}
    for i = 1, #toyList do
        local row = toys[toyList[i].id]
        if type(row) == "table" and (row.applied == true or (tonumber(row.vibe) or 0) ~= 0 or (tonumber(row.inflate) or 0) ~= 0) then
            Add(fields, "ty", string.format(
                "%s:%d:%d:%d",
                toyList[i].id,
                row.applied and 1 or 0,
                tonumber(row.vibe) or 0,
                tonumber(row.inflate) or 0
            ))
        end
    end
    return fields
end

local function HistoryToken(point)
    local mapID = tonumber(point and point.mapID)
    local x = tonumber(point and point.x)
    local y = tonumber(point and point.y)
    local stamp = tonumber(point and point.t)
    if mapID == nil or x == nil or y == nil or stamp == nil then
        return nil
    end
    return string.format("%d:%.4f:%.4f:%d", math.floor(mapID), x, y, math.floor(stamp))
end

function CCT.Report.PosFields(pos, history)
    local fields = {}
    if type(pos) ~= "table" then
        return fields
    end
    Add(fields, "map", pos.mapID)
    if type(pos.x) == "number" then
        Add(fields, "x", string.format("%.4f", pos.x))
    end
    if type(pos.y) == "number" then
        Add(fields, "y", string.format("%.4f", pos.y))
    end
    if type(pos.instanceID) == "number" then
        Add(fields, "inst", pos.instanceID)
    end
    Add(fields, "t", pos.t or Clock())
    if type(history) == "table" then
        for i = 1, #history do
            local token = HistoryToken(history[i])
            if token ~= nil then
                Add(fields, "h", token)
            end
        end
    end
    return fields
end

local function PendingHistory(char)
    local sent = TrailSent(char)
    local trail = char and char.trail or {}
    local rows = {}
    for i = 1, #trail do
        local row = trail[i]
        local at = type(row) == "table" and tonumber(row.t) or nil
        if at ~= nil and at > sent then
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b)
        return (tonumber(a.t) or 0) < (tonumber(b.t) or 0)
    end)
    return rows
end

local function HistoryFits(pos, rows)
    if CCT.Net == nil or type(CCT.Net.Pieces) ~= "function" then
        return false
    end
    local parts = CCT.Net.Pieces("pos", CCT.Report.PosFields(pos, rows))
    return type(parts) == "table" and #parts == 1
end

local function FitHistory(pos, rows)
    local chosen = {}
    if not HistoryFits(pos, chosen) then
        return chosen
    end
    for i = 1, #rows do
        chosen[#chosen + 1] = rows[i]
        if not HistoryFits(pos, chosen) then
            chosen[#chosen] = nil
            break
        end
    end
    return chosen
end

local function HasUnacked(char)
    if type(char) ~= "table" or type(char.trail) ~= "table" then
        return false
    end
    local last = char.trail[#char.trail]
    local at = type(last) == "table" and tonumber(last.t) or nil
    return at ~= nil and at > TrailSent(char)
end

function CCT.Report.FlushTrail(forceLive)
    if trailQueued ~= nil then
        return true
    end
    local owner = OwnerShort()
    local state = State()
    if owner == nil or CCT.Net == nil or type(CCT.Net.Whisper) ~= "function" then
        return false
    end
    if type(state) ~= "table" or type(state.pos) ~= "table" then
        return false
    end
    local char = KittenChar()
    local pending = PendingHistory(char)
    if forceLive ~= true and #pending == 0 then
        return false
    end
    if #pending > 0 and not HistoryFits(state.pos, {}) then
        return false
    end
    local batch = FitHistory(state.pos, pending)
    if #pending > 0 and #batch == 0 then
        return false
    end
    local ackThrough = nil
    if #batch > 0 then
        ackThrough = tonumber(batch[#batch].t)
    end
    local fields = CCT.Report.PosFields(state.pos, batch)
    if ackThrough == nil then
        return CCT.Net.Whisper(owner, "pos", fields) and true or false
    end
    local function done(ok)
        if trailQueued ~= ackThrough then
            return
        end
        trailQueued = nil
        if ok ~= true then
            return
        end
        local saved = KittenChar()
        if type(saved) == "table" then
            local previous = tonumber(saved.trailSent) or 0
            if ackThrough > previous then
                saved.trailSent = ackThrough
            end
        end
        CCT.Report.FlushTrail(false)
    end
    trailQueued = ackThrough
    local queued = CCT.Net.Whisper(owner, "pos", fields, done) and true or false
    if not queued then
        trailQueued = nil
        return false
    end
    return true
end

function CCT.Report.SendState()
    local owner = OwnerShort()
    local state = State()
    if owner == nil or type(state) ~= "table" or CCT.Net == nil then
        return false
    end
    return CCT.Net.Whisper(owner, "state", CCT.Report.StateFields(state)) and true or false
end

function CCT.Report.SendPos()
    return CCT.Report.FlushTrail(true)
end

local function RememberBaseline(state)
    lastFingerprint = Fingerprint(state)
    lastShown = ShownHeat(state)
    lastPosKey = PosKey(state and state.pos)
end

local function OnState(state)
    if type(state) ~= "table" then
        return
    end
    local fingerprint = Fingerprint(state)
    local shown = ShownHeat(state)
    local posKey = PosKey(state.pos)
    local fingerprintChanged = fingerprint ~= lastFingerprint
    local heatChanged = shown ~= lastShown
    local posChanged = posKey ~= lastPosKey
    lastFingerprint = fingerprint
    lastShown = shown
    lastPosKey = posKey
    if fingerprintChanged then
        heatDueAt = nil
        CCT.Report.SendState()
    elseif heatChanged then
        local now = Clock()
        local earliest = lastHeatSentAt + HEAT_GAP
        if now >= earliest then
            lastHeatSentAt = now
            heatDueAt = nil
            CCT.Report.SendState()
        else
            heatDueAt = earliest
        end
    end
    if posChanged and state.jewel == true then
        CCT.Report.SendPos()
    end
end

function CCT.Report.Arm()
    RememberBaseline(State())
    if not listening and CCT.State and type(CCT.State.Listen) == "function" then
        CCT.State.Listen(OnState)
        listening = true
    end
end

function CCT.Report.TryLoginFlush()
    if loginSealed or not sawRoster then
        return false
    end
    if CCT.Ledger and type(CCT.Ledger.LoginFlush) == "function" then
        CCT.Ledger.LoginFlush()
    end
    local owner = OwnerShort()
    if owner == nil then
        loginSealed = true
        return true
    end
    local queued = CCT.Report.SendState()
    local state = State()
    if state and state.jewel == true then
        queued = CCT.Report.SendPos() or queued
    end
    if queued then
        loginSealed = true
        return true
    end
    return false
end

function CCT.Report.SamplePos(now)
    local state = State()
    if type(state) ~= "table" or state.jewel ~= true then
        return false
    end
    local here = CCT.Report.Here()
    if type(here) ~= "table" or type(here.mapID) ~= "number" or type(here.x) ~= "number" or type(here.y) ~= "number" then
        return false
    end
    here.t = Wall(now)
    if not (CCT.State and CCT.State.SetPos and CCT.State.SetPos(here)) then
        return false
    end
    if CCT.Report.NoteHistory(here) then
        CCT.Report.FlushTrail(false)
    end
    return true
end

function CCT.Report.Tick(now)
    local stamp = tonumber(now) or Clock()
    if loginArmed and sawRoster and not loginSealed then
        CCT.Report.TryLoginFlush()
    end
    if heatDueAt ~= nil and stamp >= heatDueAt then
        heatDueAt = nil
        lastHeatSentAt = stamp
        CCT.Report.SendState()
    end
    local state = State()
    if type(state) == "table" and state.jewel == true then
        if CCT.Location and type(CCT.Location.Tick) == "function" then
            CCT.Location.Tick(stamp)
        elseif nextSampleAt ~= nil and stamp >= nextSampleAt then
            nextSampleAt = stamp + SAMPLE_GAP
            CCT.Report.SamplePos(stamp)
        end
    end
    local char = KittenChar()
    if char ~= nil and trailQueued == nil and HasUnacked(char) then
        CCT.Report.FlushTrail(false)
    end
    if CCT.Pictures and type(CCT.Pictures.Tick) == "function" then
        CCT.Pictures.Tick(stamp)
    end
    if CCT.Advertise and type(CCT.Advertise.Tick) == "function" then
        CCT.Advertise.Tick(stamp)
    end
end

local function AckFields(result)
    local fields = {
        { "op", result.op or "" },
        { "cid", result.cid },
        { "ok", result.ok and "1" or "0" },
    }
    if not result.ok and result.reason then
        fields[#fields + 1] = { "reason", result.reason }
    end
    if result.id ~= nil then
        fields[#fields + 1] = { "id", result.id }
    end
    return fields
end

function CCT.Report.OnCommand(sender, result)
    if type(result) ~= "table" or result.held then
        return
    end
    if result.cid == nil or result.cid == "" then
        return
    end
    local owner = OwnerShort()
    if owner == nil or CCT.Net == nil or type(CCT.Net.Whisper) ~= "function" then
        return
    end
    CCT.Net.Whisper(owner, "ack", AckFields(result))
end

local function InGroup()
    if type(IsInRaid) == "function" and IsInRaid() then
        return true
    end
    if type(IsInGroup) == "function" and IsInGroup() then
        return true
    end
    return false
end

local partyKnown = false
local partyRaid = false
local partyGroup = false

local function RememberParty()
    partyRaid = type(IsInRaid) == "function" and IsInRaid() == true
    partyGroup = type(IsInGroup) == "function" and IsInGroup() == true
    partyKnown = true
end

local function InviteName(owner)
    if type(CCT.LinkName) == "function" then
        return CCT.LinkName(owner) or owner
    end
    return owner
end

function CCT.Report.FinishGroup()
    if pendingOwner == nil or InGroup() then
        return false
    end
    local invite = C_PartyInfo and C_PartyInfo.InviteUnit
    if type(invite) ~= "function" then
        pendingOwner = nil
        return false
    end
    local owner = pendingOwner
    pendingOwner = nil
    invite(InviteName(owner))
    return true
end

function CCT.Report.ApplyGroup(sender, fields)
    local cid = type(fields) == "table" and fields.cid or nil
    local invite = C_PartyInfo and C_PartyInfo.InviteUnit
    if type(invite) ~= "function" then
        return { ok = false, reason = "party", op = "group", cid = cid }
    end
    local owner = type(sender) == "string" and sender ~= "" and sender or OwnerShort()
    if owner == nil then
        return { ok = false, reason = "party", op = "group", cid = cid }
    end
    if InGroup() then
        pendingOwner = owner
        local leave = C_PartyInfo and C_PartyInfo.LeaveParty
        if type(leave) == "function" then
            leave()
        end
        if not InGroup() then
            CCT.Report.FinishGroup()
        end
    else
        invite(InviteName(owner))
    end
    return { ok = true, reason = nil, op = "group", cid = cid }
end

local function GroupedParty()
    if not partyKnown then
        return false
    end
    if partyRaid then
        return false
    end
    return partyGroup
end

local function CoordFields(fields)
    local here = CCT.Report.Here()
    if type(here) ~= "table" then
        return fields
    end
    if type(here.mapID) == "number" then
        Add(fields, "map", here.mapID)
    end
    if type(here.x) == "number" then
        Add(fields, "x", string.format("%.4f", here.x))
    end
    if type(here.y) == "number" then
        Add(fields, "y", string.format("%.4f", here.y))
    end
    if type(here.instanceID) == "number" then
        Add(fields, "inst", here.instanceID)
    end
    return fields
end

local function SendProx(fields, party)
    local owner = OwnerShort()
    if owner and CCT.Net and CCT.Net.Whisper then
        CCT.Net.Whisper(owner, "prox", fields)
    end
    if party and GroupedParty() and CCT.Net and CCT.Net.Send then
        local token = {}
        for i = 1, #fields do
            local key = tostring(fields[i][1]):lower()
            if key == "kind" or key == "snd" or key == "heel" or key == "action" then
                token[#token + 1] = fields[i]
            end
        end
        CCT.Net.Send("PARTY", "prox", token)
    end
end

function CCT.Report.BellProx(which, action)
    local kind = which == "tail" and "tail" or "bell"
    local fields = {
        { "kind", kind },
        { "snd", kind },
        { "action", action or "play" },
    }
    SendProx(CoordFields(fields), true)
end

function CCT.Report.HeelProx(kind, action)
    if kind ~= "maid" and kind ~= "high" and kind ~= "ballet" then
        return
    end
    if action == "ping" then
        local now = Clock()
        if (now - (lastPing[kind] or 0)) < PING_GAP then
            return
        end
        lastPing[kind] = now
    end
    local fields = {
        { "kind", "heel" },
        { "snd", "heel" },
        { "heel", kind },
        { "action", action or "ping" },
    }
    SendProx(CoordFields(fields), true)
end

function CCT.Report.MittenProx(kind)
    local name = kind == "creak" and "creak" or "squeak"
    local fields = {
        { "kind", name },
        { "snd", name },
        { "action", "play" },
    }
    SendProx(CoordFields(fields), true)
end

function CCT.Report.SoundNote(body)
    if type(body) ~= "string" or body == "" then
        return
    end
    local owner = OwnerShort()
    if owner == nil or CCT.Net == nil then
        return
    end
    local fields
    local action, strength = body:match("^DiscSound, owner:[^,]+, action:([^,]+), strength:([^,]+)")
    if action then
        fields = {
            { "kind", "disc" },
            { "action", action },
            { "level", strength },
        }
        CCT.Net.Whisper(owner, "prox", fields)
        return
    end
    local vibe, level, mapID, x, y, instanceID = body:match(
        "^ToyVibeLoop(%a+), owner:[^,]+, level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if vibe then
        local act = vibe:lower()
        fields = {
            { "kind", "vibe" },
            { "action", act },
            { "level", level },
        }
        if mapID ~= "nil" then
            Add(fields, "map", mapID)
        end
        if x ~= "nil" then
            Add(fields, "x", x)
        end
        if y ~= "nil" then
            Add(fields, "y", y)
        end
        if instanceID ~= "nil" then
            Add(fields, "inst", instanceID)
        end
        CCT.Net.Whisper(owner, "prox", fields)
        return
    end
    local shock, shockMap, shockX, shockY, shockInst = body:match(
        "^ToyShockSound, owner:[^,]+, level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if shock then
        fields = { { "kind", "shock" }, { "level", shock } }
        if shockMap ~= "nil" then
            Add(fields, "map", shockMap)
        end
        if shockX ~= "nil" then
            Add(fields, "x", shockX)
        end
        if shockY ~= "nil" then
            Add(fields, "y", shockY)
        end
        if shockInst ~= "nil" then
            Add(fields, "inst", shockInst)
        end
        CCT.Net.Whisper(owner, "prox", fields)
        return
    end
    local inflate, infMap, infX, infY, infInst = body:match(
        "^ToyInflateSound, owner:[^,]+, action:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if inflate then
        fields = { { "kind", "inflate" }, { "action", inflate } }
        if infMap ~= "nil" then
            Add(fields, "map", infMap)
        end
        if infX ~= "nil" then
            Add(fields, "x", infX)
        end
        if infY ~= "nil" then
            Add(fields, "y", infY)
        end
        if infInst ~= "nil" then
            Add(fields, "inst", infInst)
        end
        CCT.Net.Whisper(owner, "prox", fields)
    end
end

local function Assigned(sender)
    local row = CCT.Roster and CCT.Roster.GetAssignedKitten and CCT.Roster.GetAssignedKitten()
    if type(row) ~= "table" then
        return false
    end
    return CCT.SameName(row.short, sender)
end

local function NumberField(fields, key)
    if type(fields) ~= "table" then
        return nil
    end
    return tonumber(fields[key])
end

function CCT.Report.Near(fields, range, allowInstance)
    local here = CCT.Report.Here()
    local mapID = NumberField(fields, "map")
    local x = NumberField(fields, "x")
    local y = NumberField(fields, "y")
    local inst = NumberField(fields, "inst")
    if here and type(here.mapID) == "number" and type(here.x) == "number" and type(here.y) == "number" and mapID and x and y and here.mapID == mapID then
        local dx = here.x - x
        local dy = here.y - y
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist <= range, dist
    end
    if allowInstance and (mapID == nil or x == nil or y == nil) then
        if here and type(here.instanceID) == "number" and inst ~= nil and here.instanceID == inst then
            return true, nil
        end
    end
    return false, nil
end

local function PlayKind(kind, heel)
    if kind == "bell" then
        return PlayFile(Media("Sounds\\Bell.ogg"))
    end
    if kind == "tail" then
        return PlayFile(Media("Sounds\\sbell4seconds.ogg"))
    end
    if kind == "squeak" then
        return PlayFile(Media("Sounds\\pawsqueak" .. math.random(5) .. ".ogg"))
    end
    if kind == "creak" then
        return PlayFile(Media("Sounds\\creak-" .. math.random(3) .. ".ogg"))
    end
    if kind == "heel" then
        local file = HEEL_FILE[heel or ""]
        if file then
            return PlayFile(Media("Sounds\\" .. file))
        end
    end
    return nil
end

local function LocalOwner()
    local short = CCT.Player and CCT.Player.short
    if type(short) == "string" and short ~= "" then
        return short
    end
    return "owner"
end

local function HandleRemote(kind, fields)
    if CCT.Sounds == nil or type(CCT.Sounds.Handle) ~= "function" then
        return
    end
    local mine = LocalOwner()
    if kind == "disc" then
        CCT.Sounds.Handle(string.format(
            "DiscSound, owner:%s, action:%s, strength:%s",
            mine,
            tostring(fields.action or ""),
            tostring(fields.level or 1)
        ))
        return
    end
    local mapID = fields.map or "nil"
    local x = fields.x or "nil"
    local y = fields.y or "nil"
    local inst = fields.inst or "nil"
    if kind == "vibe" then
        local action = tostring(fields.action or "ping")
        action = action:sub(1, 1):upper() .. action:sub(2)
        CCT.Sounds.Handle(string.format(
            "ToyVibeLoop%s, owner:%s, level:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
            action,
            mine,
            tostring(fields.level or 0),
            tostring(mapID),
            tostring(x),
            tostring(y),
            tostring(inst)
        ))
        return
    end
    if kind == "shock" then
        CCT.Sounds.Handle(string.format(
            "ToyShockSound, owner:%s, level:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
            mine,
            tostring(fields.level or 1),
            tostring(mapID),
            tostring(x),
            tostring(y),
            tostring(inst)
        ))
        return
    end
    if kind == "inflate" then
        CCT.Sounds.Handle(string.format(
            "ToyInflateSound, owner:%s, action:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
            mine,
            tostring(fields.action or ""),
            tostring(mapID),
            tostring(x),
            tostring(y),
            tostring(inst)
        ))
    end
end

function CCT.Report.OnProx(sender, parsed, channel)
    if type(parsed) ~= "table" or type(parsed.fields) ~= "table" then
        return
    end
    local fields = parsed.fields
    local kind = tostring(fields.kind or fields.snd or "")
    local action = tostring(fields.action or "play")
    if channel == "PARTY" then
        if action == "stop" then
            StopHandle(kind == "heel" and "heel" or kind)
            return
        end
        local handle = PlayKind(kind, fields.heel)
        if kind == "heel" or kind == "bell" or kind == "tail" then
            proxHandles[kind == "heel" and "heel" or kind] = handle
        end
        return
    end
    if channel ~= "WHISPER" or not Assigned(sender) then
        return
    end
    if action == "stop" then
        StopHandle(kind == "heel" and "heel" or kind)
        return
    end
    if kind == "disc" then
        HandleRemote(kind, fields)
        return
    end
    if kind == "vibe" or kind == "shock" or kind == "inflate" then
        local close = CCT.Report.Near(fields, NEAR_RANGE, true)
        if close then
            HandleRemote(kind, fields)
        end
        return
    end
    local range = kind == "heel" and HEEL_RANGE or NEAR_RANGE
    local allowInstance = kind ~= "heel"
    local close = CCT.Report.Near(fields, range, allowInstance)
    if not close then
        return
    end
    local handle = PlayKind(kind, fields.heel)
    if kind == "heel" or kind == "bell" or kind == "tail" then
        proxHandles[kind == "heel" and "heel" or kind] = handle
    end
end

function CCT.Report.Reset()
    loginArmed = false
    loginSealed = false
    sawRoster = false
    heatDueAt = nil
    lastHeatSentAt = 0
    nextSampleAt = nil
    pendingOwner = nil
    trailQueued = nil
    lastPing = { maid = 0, high = 0, ballet = 0 }
    RememberBaseline(State())
end

function CCT.Report.OnEvent(_, event)
    if event == "PLAYER_LOGIN" then
        CCT.Report.Arm()
        loginArmed = true
        loginSealed = false
        sawRoster = false
        nextSampleAt = Clock() + SAMPLE_GAP
        RememberParty()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        RememberParty()
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then
        sawRoster = true
        CCT.Report.TryLoginFlush()
        CCT.Report.FinishGroup()
        return
    end
    if event == "GROUP_ROSTER_UPDATE" then
        RememberParty()
        CCT.Report.FinishGroup()
    end
end

if CCT.Commands and type(CCT.Commands.Register) == "function" then
    CCT.Commands.Register("group", function(sender, fields)
        return CCT.Report.ApplyGroup(sender, fields)
    end)
end

if CCT.Net and type(CCT.Net.On) == "function" then
    CCT.Net.On("cmd", function(sender, parsed, channel)
        if channel ~= "WHISPER" or CCT.Commands == nil or type(parsed) ~= "table" then
            return
        end
        local tokens = { "Cmd" }
        local order = parsed.order or {}
        for i = 1, #order do
            local key = tostring(order[i][1])
            if key:lower() ~= "part" then
                tokens[#tokens + 1] = key .. ":" .. tostring(order[i][2])
            end
        end
        CCT.Commands.Receive(sender, table.concat(tokens, ","))
    end)
    CCT.Net.On("prox", function(sender, parsed, channel)
        CCT.Report.OnProx(sender, parsed, channel)
    end)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:SetScript("OnEvent", CCT.Report.OnEvent)
end
