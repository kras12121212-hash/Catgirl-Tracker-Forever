-- Addon-message sender. Callers pass a logical body. They do not split.
-- Pop only when select(-1, C_ChatInfo.SendAddonMessage(...)) is Success.
-- Nil is not success. This file does not apply kitten gameplay.
-- OwnerWeek is queued like any other snapshot. This file does not build one.

local ADDON_NAME, CCT = ...

CCT.Net = {}
CCT.Day = {}

local MAX_BYTES = 255
local RELIABLE_CAP = 72
local CHANNEL_CAP = 2
local PROX_CAP = 2
local REASSEMBLY_SECONDS = 60
local PUMP_INTERVAL = 0.2

CCT.Net.RELIABLE_CAP = RELIABLE_CAP
CCT.Net.CHANNEL_CAP = CHANNEL_CAP
CCT.Net.PROX_CAP = PROX_CAP

local WIRE_NAME = {
    state = "State",
    pos = "Pos",
    cmd = "Cmd",
    maid = "Cmd",
    maiditem = "Cmd",
    maidtext = "Cmd",
    ack = "Ack",
    prox = "Prox",
    ledger = "Ledger",
    zones = "Zones",
    pets = "Pets",
    ledgerack = "LedgerAck",
    ownerweek = "OwnerWeek",
}

local KIND_FROM_WIRE = {}
for kind, wire in pairs(WIRE_NAME) do
    if KIND_FROM_WIRE[wire] == nil then
        KIND_FROM_WIRE[wire] = kind
    end
end
KIND_FROM_WIRE.State = "state"
KIND_FROM_WIRE.Pos = "pos"
KIND_FROM_WIRE.Cmd = "cmd"
KIND_FROM_WIRE.Ack = "ack"
KIND_FROM_WIRE.Prox = "prox"
KIND_FROM_WIRE.Ledger = "ledger"
KIND_FROM_WIRE.Zones = "zones"
KIND_FROM_WIRE.Pets = "pets"
KIND_FROM_WIRE.LedgerAck = "ledgerack"
KIND_FROM_WIRE.OwnerWeek = "ownerweek"

local CLASSIC = {
    behaviorlog = true,
    guildlog = true,
    zonelog = true,
    petlog = true,
    locationlog = true,
    emotelog = true,
    bindtimer = true,
    cctoy = true,
    ccdisc = true,
    tailbelljingle = true,
    pawsqueak = true,
    pawcreak = true,
    heelsloop = true,
    maidtasksheader = true,
    master = true,
}

local KIND_RANK = {
    state = 1,
    pos = 2,
    ledger = 3,
    zones = 4,
    pets = 5,
    ownerweek = 6,
}

local HEADER_KEYS = {
    state = { "rev" },
    pos = { "t" },
    ledger = { "day", "week", "seq" },
    zones = { "day", "week", "seq" },
    pets = { "day", "week", "seq" },
    ownerweek = { "day", "week", "seq", "kitten" },
    cmd = { "op", "cid", "id", "idx" },
    maid = { "op", "cid", "id", "idx" },
    maiditem = { "op", "cid", "id", "idx" },
    maidtext = { "op", "cid", "id", "idx" },
    ack = { "op", "cid" },
    ledgerack = { "day", "week", "seq" },
    prox = {},
}

local USER_KEYS = {
    zone = true,
    leashowner = true,
    text = true,
    name = true,
    item = true,
    sender = true,
}

local MANY_KEYS = { lk = true, ty = true, z = true, p = true, h = true }
local NO_SPLIT = { prox = true, ack = true, ledgerack = true }
local WEEK_KINDS = { ledger = true, zones = true, pets = true, ownerweek = true }
local RELIABLE = {
    cmd = true,
    ack = true,
    ledgerack = true,
    maid = true,
    maiditem = true,
    maidtext = true,
}

local SUCCESS = 0
local THROTTLE = 3
local CHANNEL_THROTTLE = 8
local LOCKDOWN = 11
local TARGET_OFFLINE = 12

local snapshots = {}
local reliable = {}
local channel = {}
local prox = {}
local handlers = {}
local buffers = {}
local offline = {}
local readyAt = {}
local holdOnline = {}
local lockdownHold = false
local sessionBlocked = false
local trialNoted = false
local prefixRegistered = false
local tickerStarted = false
local pumping = false
local clockOverride = nil
local serial = 0

local function Now()
    if clockOverride ~= nil then
        return clockOverride
    end
    if type(GetTime) == "function" then
        return GetTime()
    end
    return CCT.UnixNow()
end

function CCT.Net.Clock(stamp)
    if stamp ~= nil then
        clockOverride = tonumber(stamp) or stamp
    end
    return Now()
end

function CCT.Net.RetryDelay(kind)
    if kind == "other" then
        return 5
    end
    return 1.5 + (math.random() * 0.5)
end

local function IsDayId(id)
    return type(id) == "string" and id:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

-- Noon plus half a day, so a one-hour DST step cannot turn adjacent dates into 0.
local function DayNumber(id)
    if not IsDayId(id) or type(time) ~= "function" then
        return nil
    end
    local y, m, d = id:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    local noon = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
    local epoch = time({ year = 2020, month = 1, day = 1, hour = 12 })
    if type(noon) ~= "number" or type(epoch) ~= "number" then
        return nil
    end
    return math.floor((noon - epoch) / 86400 + 0.5)
end

-- Local calendar day. date("*t") is already the machine zone. Not UTC.
function CCT.Day.Id(now)
    if type(date) ~= "function" or type(time) ~= "function" then
        return nil
    end
    local stamp = date("*t", now or time())
    if type(stamp) ~= "table" or stamp.year == nil then
        return nil
    end
    return string.format("%04d-%02d-%02d", stamp.year, stamp.month, stamp.day)
end

-- -1 if a is older, 0 if equal, 1 if a is newer. A non-day is older than a day.
function CCT.Day.Cmp(a, b)
    local an, bn = DayNumber(a), DayNumber(b)
    if an == nil and bn == nil then
        return 0
    end
    if an == nil then
        return -1
    end
    if bn == nil then
        return 1
    end
    if an == bn then
        return 0
    end
    return an < bn and -1 or 1
end

-- Nil unless both ids number. A nil is not greater than 13 and does not remove a row.
function CCT.Day.DaysBefore(todayId, rowId)
    local today = DayNumber(todayId)
    local row = DayNumber(rowId)
    if today == nil or row == nil then
        return nil
    end
    return today - row
end

local function NormKind(kind)
    if type(kind) ~= "string" then
        return ""
    end
    return kind:lower()
end

local function IsReliable(kind)
    return RELIABLE[kind] == true
end

local function ResultCode(name, fallback)
    local enum = Enum and Enum.SendAddonMessageResult
    if type(enum) == "table" and enum[name] ~= nil then
        return enum[name]
    end
    return fallback
end

local function IsSuccess(result)
    if result == nil then
        return false
    end
    if result == SUCCESS or result == ResultCode("Success", SUCCESS) then
        return true
    end
    return false
end

local function IsThrottle(result)
    return result == THROTTLE
        or result == CHANNEL_THROTTLE
        or result == ResultCode("AddonMessageThrottle", THROTTLE)
        or result == ResultCode("ChannelThrottle", CHANNEL_THROTTLE)
end

local function IsLockdown(result)
    return result == LOCKDOWN or result == ResultCode("AddOnMessageLockdown", LOCKDOWN)
end

local function IsTargetOffline(result)
    return result == TARGET_OFFLINE or result == ResultCode("TargetOffline", TARGET_OFFLINE)
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function InstanceHeld()
    if type(IsInInstance) ~= "function" then
        return false
    end
    local inside, kind = IsInInstance()
    if Secret(inside) or Secret(kind) then
        return false
    end
    if kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena" then
        return true
    end
    return false
end

local function Held()
    return lockdownHold or InstanceHeld()
end

local function EncodeUser(value)
    local text = tostring(value):gsub("\r", "")
    text = text:gsub("%%", "%%25")
    text = text:gsub(",", "%%2C")
    text = text:gsub(":", "%%3A")
    text = text:gsub(";", "%%3B")
    text = text:gsub("\n", "%%0A")
    return text
end

local function DecodeUser(value)
    local text = tostring(value)
    text = text:gsub("%%0A", "\n")
    text = text:gsub("%%3B", ";")
    text = text:gsub("%%3A", ":")
    text = text:gsub("%%2C", ",")
    text = text:gsub("%%25", "%%")
    return text
end

function CCT.Net.EncodeUser(value)
    return EncodeUser(value)
end

function CCT.Net.DecodeUser(value)
    if value == nil then
        return ""
    end
    return DecodeUser(value)
end

local function FieldText(key, value)
    if value == nil then
        return nil
    end
    local text
    if type(value) == "boolean" then
        text = value and "1" or "0"
    elseif type(value) == "number" then
        text = tostring(value)
    else
        text = tostring(value):gsub("\r", "")
    end
    if text:find("%z") then
        return nil, "nul"
    end
    local lower = type(key) == "string" and key:lower() or ""
    if USER_KEYS[lower] then
        return EncodeUser(text)
    end
    if text:find("\n") then
        return nil, "newline"
    end
    return text
end

local function CopyPairs(fields)
    local copy = {}
    if type(fields) ~= "table" then
        return copy
    end
    for i = 1, #fields do
        local pair = fields[i]
        if type(pair) == "table" and pair[1] ~= nil then
            copy[#copy + 1] = { pair[1], pair[2] }
        end
    end
    return copy
end

local function EnsureOp(kind, fields)
    if kind ~= "maid" and kind ~= "maiditem" and kind ~= "maidtext" then
        return fields
    end
    for i = 1, #fields do
        if tostring(fields[i][1]):lower() == "op" then
            return fields
        end
    end
    local copy = { { "op", kind } }
    for i = 1, #fields do
        copy[#copy + 1] = fields[i]
    end
    return copy
end

local function Lookup(fields, key)
    local want = key:lower()
    for i = 1, #fields do
        if tostring(fields[i][1]):lower() == want then
            return fields[i][2]
        end
    end
    return nil
end

local function Prepare(kind, fields)
    local pairs = EnsureOp(kind, CopyPairs(fields))
    local prepared = {}
    for i = 1, #pairs do
        local key = tostring(pairs[i][1])
        local text, problem = FieldText(key, pairs[i][2])
        if problem then
            return nil, problem
        end
        if text ~= nil then
            prepared[#prepared + 1] = { key, text }
        end
    end
    return prepared
end

local function SplitHeader(kind, fields)
    local wanted = HEADER_KEYS[kind] or {}
    local used = {}
    local header = {}
    for i = 1, #wanted do
        local key = wanted[i]
        for n = 1, #fields do
            if not used[n] and tostring(fields[n][1]):lower() == key then
                header[#header + 1] = fields[n]
                used[n] = true
                break
            end
        end
    end
    local body = {}
    for n = 1, #fields do
        if not used[n] then
            body[#body + 1] = fields[n]
        end
    end
    return header, body
end

local function Pack(typeName, header, body, partN, partM)
    local tokens = { typeName }
    for i = 1, #header do
        tokens[#tokens + 1] = header[i][1] .. ":" .. header[i][2]
    end
    if partM and partM > 1 then
        tokens[#tokens + 1] = "part:" .. tostring(partN) .. "/" .. tostring(partM)
    end
    for i = 1, #body do
        tokens[#tokens + 1] = body[i][1] .. ":" .. body[i][2]
    end
    return table.concat(tokens, ",")
end

local function Pieces(kind, fields)
    local typeName = WIRE_NAME[kind]
    if typeName == nil then
        return nil, "kind"
    end
    local prepared, problem = Prepare(kind, fields)
    if prepared == nil then
        return nil, problem or "fields"
    end
    local header, body = SplitHeader(kind, prepared)
    local single = Pack(typeName, header, body, nil, nil)
    if single:find("\n") or single:find("%z") then
        return nil, "newline"
    end
    if #single <= MAX_BYTES then
        return { single }
    end
    if NO_SPLIT[kind] then
        return nil, "toobig"
    end
    if #body == 0 then
        return nil, "toobig"
    end
    for i = 1, #body do
        local alone = Pack(typeName, header, { body[i] }, 1, 2)
        if #alone > MAX_BYTES then
            return nil, "toobig"
        end
    end
    for count = 2, 32 do
        local parts = {}
        local index = 1
        local fit = true
        for part = 1, count do
            local chunk = {}
            while index <= #body do
                local trial = {}
                for c = 1, #chunk do
                    trial[c] = chunk[c]
                end
                trial[#trial + 1] = body[index]
                local wire = Pack(typeName, header, trial, part, count)
                if #wire <= MAX_BYTES then
                    chunk = trial
                    index = index + 1
                else
                    break
                end
            end
            if #chunk == 0 then
                fit = false
                break
            end
            parts[part] = Pack(typeName, header, chunk, part, count)
        end
        if fit and index > #body and #parts == count then
            return parts
        end
    end
    return nil, "toobig"
end

function CCT.Net.Pieces(kind, fields)
    return Pieces(NormKind(kind), fields)
end

function CCT.Net.Wire(kind, fields)
    local parts, reason = Pieces(NormKind(kind), fields)
    if parts == nil then
        return nil, reason
    end
    if #parts ~= 1 then
        return nil, "split"
    end
    return parts[1]
end

local function NextSerial()
    serial = serial + 1
    return serial
end

local function TargetKey(name)
    local short = CCT.ShortName and CCT.ShortName(name) or name
    if type(short) ~= "string" or short == "" then
        return nil
    end
    return short
end

local function SnapshotKey(target, kind, fields)
    local period = nil
    if WEEK_KINDS[kind] then
        local raw = Lookup(fields, "day")
        if raw == nil then
            raw = Lookup(fields, "week")
        end
        period = raw ~= nil and tostring(raw) or ""
    end
    return target:lower() .. "|" .. kind .. "|" .. (period or ""), period
end

local function ProxCount()
    local count = 0
    for _, list in pairs(prox) do
        count = count + #list
    end
    return count
end

function CCT.Net.Depth()
    return {
        reliable = #reliable,
        channel = #channel,
        snapshot = #snapshots,
        prox = ProxCount(),
    }
end

local function DebugDepth(result)
    if CCT.Debug then
        local depth = CCT.Net.Depth()
        CCT.Debug(
            "net-depth",
            5,
            string.format(
                "net reliable %d channel %d snapshot %d prox %d result %s",
                depth.reliable,
                depth.channel,
                depth.snapshot,
                depth.prox,
                tostring(result)
            )
        )
    end
end

local function DropChannel()
    for i = #channel, 1, -1 do
        table.remove(channel, i)
    end
end

local function DropProx()
    prox = {}
end

local function NoteTrial()
    if trialNoted then
        return
    end
    trialNoted = true
    if CCT.Debug then
        CCT.Debug("net-trial", 0, "Addon messages are restricted for this session.")
    end
end

local function TrialNow()
    if type(IsTrialAccount) == "function" and IsTrialAccount() == true then
        return true
    end
    if type(IsVeteranTrialAccount) == "function" and IsVeteranTrialAccount() == true then
        return true
    end
    if type(AreOutgoingAddonChatMessagesRestricted) == "function" and AreOutgoingAddonChatMessagesRestricted() == true then
        return true
    end
    return false
end

local function BlockedSend(kind, onResult)
    if not sessionBlocked then
        return false
    end
    if IsReliable(kind) then
        if onResult then
            onResult(false, "restricted")
        end
    end
    return true
end

local function NewItem(target, kind, fields, wires, onResult, bucket)
    return {
        id = NextSerial(),
        target = target,
        kind = kind,
        week = select(2, SnapshotKey(target, kind, fields)),
        fields = fields,
        wires = wires,
        index = 1,
        onResult = onResult,
        bucket = bucket,
        retries = 0,
        holdOnline = false,
        at = Now(),
    }
end

local function FinishGroup(item, ok, result)
    local group = item and item.group
    if group == nil or group.done then
        return
    end
    if not ok then
        group.done = true
        if group.fn then
            group.fn(false, result)
        end
        return
    end
    group.left = group.left - 1
    if group.left <= 0 then
        group.done = true
        if group.fn then
            group.fn(true)
        end
    end
end

local function Complete(item, ok, result)
    if item.group then
        FinishGroup(item, ok, result)
        return
    end
    if item.onResult then
        item.onResult(ok, result)
    end
end

local function RemoveItem(list, item)
    for i = 1, #list do
        if list[i] == item then
            table.remove(list, i)
            return true
        end
    end
    return false
end

function CCT.Net.EnqueueSet(target, entries, onResult)
    local short = TargetKey(target)
    if short == nil or type(entries) ~= "table" then
        return "toobig"
    end
    if sessionBlocked then
        if onResult then
            onResult(false, "restricted")
        end
        return "restricted"
    end
    local built = {}
    local total = 0
    for i = 1, #entries do
        local entry = entries[i]
        local kind = NormKind(entry and entry.kind)
        if not IsReliable(kind) then
            return "toobig"
        end
        local wires, reason
        if type(entry.wires) == "table" then
            wires = {}
            for w = 1, #entry.wires do
                local text = entry.wires[w]
                if type(text) ~= "string" or text == "" or #text > MAX_BYTES then
                    return "toobig"
                end
                wires[w] = text
            end
            if #wires == 0 then
                return "toobig"
            end
        else
            wires, reason = Pieces(kind, entry.fields or {})
            if wires == nil then
                return reason == "toobig" and "toobig" or "toobig"
            end
        end
        total = total + #wires
        built[#built + 1] = { kind = kind, fields = entry.fields or {}, wires = wires }
    end
    if total > RELIABLE_CAP then
        return "toobig"
    end
    if total > (RELIABLE_CAP - #reliable) then
        return "busy"
    end
    -- One queue slot is one on-wire part. The callback fires once for the set.
    local group = { left = total, done = false, fn = onResult }
    for i = 1, #built do
        local row = built[i]
        for w = 1, #row.wires do
            local item = NewItem(short, row.kind, row.fields, { row.wires[w] }, nil, "reliable")
            item.group = group
            reliable[#reliable + 1] = item
        end
    end
    return "queued"
end

local function QueueSnapshot(short, kind, fields, wires, onResult)
    local key = SnapshotKey(short, kind, fields)
    for i = 1, #snapshots do
        local item = snapshots[i]
        if item.key == key then
            item.fields = fields
            item.wires = wires
            item.week = select(2, SnapshotKey(short, kind, fields))
            item.index = 1
            item.retries = 0
            item.holdOnline = false
            item.onResult = onResult
            return true
        end
    end
    local item = NewItem(short, kind, fields, wires, onResult, "snapshot")
    item.key = key
    snapshots[#snapshots + 1] = item
    return true
end

local function QueueReliable(short, kind, fields, wires, onResult)
    if #wires > RELIABLE_CAP then
        if onResult then
            onResult(false, "toobig")
        end
        return false
    end
    if #wires > (RELIABLE_CAP - #reliable) then
        if onResult then
            onResult(false, "full")
        end
        return false
    end
    reliable[#reliable + 1] = NewItem(short, kind, fields, wires, onResult, "reliable")
    return true
end

local function QueueProx(short, fields, wires, onResult)
    if Held() or sessionBlocked then
        return false
    end
    local list = prox[short:lower()]
    if list == nil then
        list = {}
        prox[short:lower()] = list
    end
    while #list >= PROX_CAP do
        table.remove(list, 1)
    end
    list[#list + 1] = NewItem(short, "prox", fields, wires, onResult, "prox")
    return true
end

function CCT.Net.Whisper(target, kind, fields, onResult)
    local norm = NormKind(kind)
    local short = TargetKey(target)
    if short == nil or WIRE_NAME[norm] == nil then
        if IsReliable(norm) and onResult then
            onResult(false, "kind")
        end
        return false
    end
    if BlockedSend(norm, onResult) then
        return false
    end
    if norm == "prox" and (Held() or sessionBlocked) then
        return false
    end
    local wires, reason = Pieces(norm, fields)
    if wires == nil then
        if IsReliable(norm) and onResult then
            onResult(false, reason or "toobig")
        end
        return false
    end
    if WEEK_KINDS[norm] or norm == "state" or norm == "pos" then
        return QueueSnapshot(short, norm, fields or {}, wires, onResult)
    end
    if norm == "prox" then
        return QueueProx(short, fields or {}, wires, onResult)
    end
    if IsReliable(norm) then
        return QueueReliable(short, norm, fields or {}, wires, onResult)
    end
    return false
end

local function StripCoords(fields)
    local copy = {}
    for i = 1, #fields do
        local key = tostring(fields[i][1]):lower()
        if key ~= "map" and key ~= "x" and key ~= "y" and key ~= "inst" then
            copy[#copy + 1] = fields[i]
        end
    end
    return copy
end

function CCT.Net.Send(chatType, kind, fields, onResult)
    local norm = NormKind(kind)
    if chatType ~= "PARTY" or norm ~= "prox" then
        return false
    end
    if Held() or sessionBlocked then
        return false
    end
    local stripped = StripCoords(CopyPairs(fields))
    local wires, reason = Pieces("prox", stripped)
    if wires == nil then
        return false, reason
    end
    while #channel >= CHANNEL_CAP do
        table.remove(channel, 1)
    end
    local item = NewItem("", "prox", stripped, wires, onResult, "channel")
    item.chatType = "PARTY"
    channel[#channel + 1] = item
    return true
end

local function MemberOnline(target)
    if CCT.Roster == nil or type(CCT.Roster.GetMember) ~= "function" then
        return false
    end
    local row = CCT.Roster.GetMember(target)
    return type(row) == "table" and row.online == true
end

local function MarkOffline(target)
    if type(target) == "string" and target ~= "" then
        offline[target:lower()] = true
    end
end

local function TargetReady(target, now)
    if type(target) ~= "string" or target == "" then
        return false
    end
    local key = target:lower()
    if offline[key] then
        return false
    end
    if not MemberOnline(target) then
        MarkOffline(target)
        return false
    end
    if (readyAt[key] or 0) > now then
        return false
    end
    return true
end

local function DropTargetProx(target)
    if type(target) == "string" then
        prox[target:lower()] = nil
    end
end

local function SnapshotBetter(a, b)
    local cmp = CCT.Day.Cmp(a.week, b.week)
    if cmp ~= 0 then
        return cmp < 0
    end
    local ar = KIND_RANK[a.kind] or 9
    local br = KIND_RANK[b.kind] or 9
    if ar ~= br then
        return ar < br
    end
    return a.id < b.id
end

local function PickList(list, now, continueOnly)
    local best = nil
    for i = 1, #list do
        local item = list[i]
        if item.holdOnline then
            -- wait for the roster online edge
        elseif continueOnly and item.index <= 1 then
            -- a new message waits until the open one finishes
        elseif TargetReady(item.target, now) then
            if best == nil or (continueOnly and item.index > 1) or item.id < best.id then
                if continueOnly then
                    if item.index > 1 and (best == nil or item.id < best.id) then
                        best = item
                    end
                else
                    best = item
                end
            end
        elseif item.kind == "prox" then
            RemoveItem(list, item)
        end
    end
    return best
end

local function PickSnapshot(now)
    local best = nil
    local seen = {}
    for i = 1, #snapshots do
        local item = snapshots[i]
        local key = item.target:lower()
        if item.holdOnline or seen[key] then
            -- one open snapshot family per target is chosen below
        elseif not TargetReady(item.target, now) then
            seen[key] = true
        end
    end
    for i = 1, #snapshots do
        local item = snapshots[i]
        if not item.holdOnline and TargetReady(item.target, now) then
            if best == nil or item.target:lower() ~= best.target:lower() and item.id < best.id then
                if best == nil or SnapshotBetter(item, best) then
                    if best == nil or item.target:lower() == best.target:lower() or item.id < best.id then
                        best = item
                    end
                elseif best and item.target:lower() == best.target:lower() and SnapshotBetter(item, best) then
                    best = item
                end
            end
        end
    end
    -- Prefer the oldest target that has a ready snapshot, then the sort order inside it.
    local oldestTarget = nil
    local oldestId = nil
    for i = 1, #snapshots do
        local item = snapshots[i]
        if not item.holdOnline and TargetReady(item.target, now) then
            if oldestId == nil or item.id < oldestId then
                oldestId = item.id
                oldestTarget = item.target:lower()
            end
        end
    end
    if oldestTarget == nil then
        return nil
    end
    best = nil
    for i = 1, #snapshots do
        local item = snapshots[i]
        if item.target:lower() == oldestTarget and not item.holdOnline and TargetReady(item.target, now) then
            if best == nil or SnapshotBetter(item, best) then
                best = item
            end
        end
    end
    return best
end

local function PickWhisper(now)
    local open = PickList(reliable, now, true)
    if open then
        return open
    end
    for _, list in pairs(prox) do
        local openProx = nil
        for i = 1, #list do
            if list[i].index > 1 and TargetReady(list[i].target, now) then
                openProx = list[i]
                break
            end
        end
        if openProx then
            return openProx
        end
    end
    for i = 1, #snapshots do
        if snapshots[i].index > 1 and not snapshots[i].holdOnline and TargetReady(snapshots[i].target, now) then
            return snapshots[i]
        end
    end
    local nextReliable = PickList(reliable, now, false)
    if nextReliable then
        return nextReliable
    end
    local nextProx = nil
    local dropProx = {}
    for _, list in pairs(prox) do
        for i = 1, #list do
            local item = list[i]
            if TargetReady(item.target, now) and (nextProx == nil or item.id < nextProx.id) then
                nextProx = item
            elseif not TargetReady(item.target, now) then
                dropProx[item.target:lower()] = item.target
                break
            end
        end
    end
    for _, target in pairs(dropProx) do
        DropTargetProx(target)
    end
    if nextProx then
        return nextProx
    end
    return PickSnapshot(now)
end

local function Transmit(payload, chatType, target)
    if chatType == "WHISPER" and type(CCT.LinkName) == "function" then
        target = CCT.LinkName(target) or target
    end
    if C_ChatInfo == nil or type(C_ChatInfo.SendAddonMessage) ~= "function" then
        return nil
    end
    local ok, value = pcall(function()
        return select(-1, C_ChatInfo.SendAddonMessage(CCT.PREFIX, payload, chatType, target))
    end)
    if not ok then
        return nil
    end
    return value
end

local function DelayTarget(target, seconds)
    if type(target) == "string" and target ~= "" then
        readyAt[target:lower()] = Now() + seconds
    end
end

local function PopDone(item)
    if item.bucket == "reliable" then
        RemoveItem(reliable, item)
    elseif item.bucket == "snapshot" then
        RemoveItem(snapshots, item)
    elseif item.bucket == "channel" then
        RemoveItem(channel, item)
    elseif item.bucket == "prox" then
        local list = prox[item.target:lower()]
        if list then
            RemoveItem(list, item)
        end
    end
end

local function FailOther(item, result)
    if item.bucket == "channel" or item.kind == "prox" then
        PopDone(item)
        return
    end
    if item.bucket == "snapshot" then
        item.holdOnline = true
        return
    end
    PopDone(item)
    Complete(item, false, result)
end

local function HandleResult(item, result, chatType)
    CCT.Net.LastResult = result
    DebugDepth(result)
    if IsSuccess(result) then
        item.index = item.index + 1
        item.retries = 0
        if item.index > #item.wires then
            PopDone(item)
            Complete(item, true, result)
        end
        return
    end
    if result == nil or IsThrottle(result) then
        local wait = CCT.Net.RetryDelay(result == nil and "nil" or "throttle")
        if item.bucket == "channel" then
            readyAt.channel = Now() + wait
        else
            DelayTarget(item.target, wait)
        end
        if CCT.Debug then
            CCT.Debug("net-retry", 1.5, "net retry in " .. string.format("%.1f", wait))
        end
        return
    end
    if IsLockdown(result) then
        lockdownHold = true
        return
    end
    if IsTargetOffline(result) then
        if item.kind == "prox" or item.bucket == "channel" then
            PopDone(item)
            return
        end
        MarkOffline(item.target)
        return
    end
    if item.retries < 1 then
        item.retries = item.retries + 1
        local wait = CCT.Net.RetryDelay("other")
        if item.bucket == "channel" then
            readyAt.channel = Now() + wait
        else
            DelayTarget(item.target, wait)
        end
        return
    end
    FailOther(item, result)
end

local function SendOne(item, chatType)
    if Held() and chatType == "WHISPER" then
        return false
    end
    local payload = item.wires[item.index]
    if type(payload) ~= "string" then
        PopDone(item)
        if IsReliable(item.kind) then
            Complete(item, false, "empty")
        end
        return true
    end
    local target = chatType == "WHISPER" and item.target or nil
    local result = Transmit(payload, chatType, target)
    HandleResult(item, result, chatType)
    return true
end

local function ExpireBuffers()
    local now = Now()
    for key, buffer in pairs(buffers) do
        if (now - (buffer.at or now)) >= REASSEMBLY_SECONDS then
            buffers[key] = nil
        end
    end
end

local function PumpBody()
    ExpireBuffers()
    if CCT.Report and type(CCT.Report.Tick) == "function" then
        CCT.Report.Tick(Now())
    end
    if sessionBlocked or TrialNow() then
        if TrialNow() and not sessionBlocked then
            sessionBlocked = true
            NoteTrial()
        end
        if sessionBlocked then
            DropChannel()
            DropProx()
            return
        end
    end
    if Held() then
        DropChannel()
        DropProx()
        return
    end
    local now = Now()
    local whisper = PickWhisper(now)
    if whisper then
        SendOne(whisper, "WHISPER")
    end
    if Held() then
        DropChannel()
        DropProx()
        return
    end
    if (readyAt.channel or 0) <= now and channel[1] then
        SendOne(channel[1], "PARTY")
    end
end

function CCT.Net.Pump()
    if pumping then
        return
    end
    pumping = true
    local ok, err = pcall(PumpBody)
    pumping = false
    if not ok then
        error(err, 0)
    end
end

local function ReleaseOnline()
    if CCT.Roster == nil or type(CCT.Roster.GetMember) ~= "function" then
        return
    end
    for key in pairs(offline) do
        if MemberOnline(key) then
            offline[key] = nil
            readyAt[key] = 0
        end
    end
    for i = 1, #snapshots do
        local item = snapshots[i]
        if item.holdOnline and MemberOnline(item.target) then
            item.holdOnline = false
            readyAt[item.target:lower()] = 0
        end
    end
    for i = 1, #reliable do
        local item = reliable[i]
        if MemberOnline(item.target) then
            readyAt[item.target:lower()] = readyAt[item.target:lower()] or 0
        end
    end
end

local function SplitMany(key, remainder)
    if key == "lk" then
        local bind, unlockAt = tostring(remainder):match("^([^:]+):([^:]+)$")
        return { bind = bind, unlockAt = tonumber(unlockAt), raw = remainder }
    end
    if key == "ty" then
        local id, applied, vibe, inflate = tostring(remainder):match("^([^:]+):([^:]+):([^:]+):([^:]+)$")
        return {
            id = id,
            applied = tonumber(applied),
            vibe = tonumber(vibe),
            inflate = tonumber(inflate),
            raw = remainder,
        }
    end
    if key == "z" then
        local name, minutes = tostring(remainder):match("^(.-):(.*)$")
        if name == nil then
            name = remainder
            minutes = nil
        end
        return { name = DecodeUser(name), minutes = tonumber(minutes), raw = remainder }
    end
    if key == "p" then
        local action, sender = tostring(remainder):match("^(.-):(.*)$")
        if action == nil then
            action = remainder
            sender = nil
        end
        return { action = action, sender = sender and DecodeUser(sender) or nil, raw = remainder }
    end
    if key == "h" then
        local mapID, x, y, stamp = tostring(remainder):match("^([^:]+):([^:]+):([^:]+):([^:]+)$")
        return {
            mapID = tonumber(mapID),
            x = tonumber(x),
            y = tonumber(y),
            t = tonumber(stamp),
            raw = remainder,
        }
    end
    return { raw = remainder }
end

local function ApplyToken(parsed, key, remainder)
    local lower = key:lower()
    parsed.order[#parsed.order + 1] = { key, remainder }
    if MANY_KEYS[lower] then
        parsed.many[lower] = parsed.many[lower] or {}
        local row = SplitMany(lower, remainder)
        parsed.many[lower][#parsed.many[lower] + 1] = row
        parsed.fields[lower] = remainder
        return
    end
    if lower == "part" then
        parsed.part = remainder
        return
    end
    local value = remainder
    if USER_KEYS[lower] then
        value = DecodeUser(remainder)
    end
    parsed.fields[lower] = value
end

function CCT.Net.Parse(message)
    if type(message) ~= "string" or message == "" then
        return nil
    end
    if message:find("\n") or message:find("%z") or message:find("\r") then
        return nil
    end
    local tokens = {}
    for token in message:gmatch("[^,]+") do
        if token ~= "" then
            tokens[#tokens + 1] = token
        end
    end
    if #tokens == 0 or tokens[1]:find(":", 1, true) then
        return nil
    end
    local typeName = tokens[1]
    if CLASSIC[typeName:lower()] then
        return nil
    end
    local kind = KIND_FROM_WIRE[typeName]
    if kind == nil then
        return nil
    end
    local parsed = {
        type = typeName,
        kind = kind,
        fields = {},
        many = {},
        order = {},
    }
    for i = 2, #tokens do
        local key, remainder = tokens[i]:match("^([^:]+):(.*)$")
        if key == nil or key == "" then
            return nil
        end
        ApplyToken(parsed, key, remainder)
    end
    return parsed
end

local function SenderShort(sender)
    -- Ambiguate(..., "short") strips at a hyphen. On Forever that drops the surname.
    if type(CCT.ShortName) ~= "function" then
        return nil
    end
    return CCT.ShortName(sender)
end

local function Dispatch(parsed, sender, channelName)
    local list = handlers[parsed.kind]
    if list == nil then
        return
    end
    for i = 1, #list do
        list[i](sender, parsed, channelName)
    end
end

local function PeriodField(fields)
    if type(fields) ~= "table" then
        return nil
    end
    if fields.day ~= nil and tostring(fields.day) ~= "" then
        return fields.day
    end
    return fields.week
end

local function BufferIdentity(parsed, sender)
    local fields = parsed.fields
    if parsed.kind == "state" then
        return "state|" .. sender:lower() .. "|" .. tostring(fields.rev)
    end
    if parsed.kind == "pos" then
        return "pos|" .. sender:lower() .. "|" .. tostring(fields.t)
    end
    if parsed.kind == "ledger" or parsed.kind == "zones" or parsed.kind == "pets" then
        return parsed.kind .. "|" .. sender:lower() .. "|" .. tostring(PeriodField(fields)) .. "|" .. tostring(fields.seq)
    end
    if parsed.kind == "ownerweek" then
        return "ownerweek|" .. sender:lower() .. "|" .. tostring(fields.kitten) .. "|" .. tostring(PeriodField(fields)) .. "|" .. tostring(fields.seq)
    end
    if parsed.kind == "cmd" and fields.id ~= nil and fields.idx ~= nil then
        return "cmd|" .. sender:lower() .. "|" .. tostring(fields.id) .. "|" .. tostring(fields.idx)
    end
    if parsed.kind == "cmd" then
        return "cmd|" .. sender:lower() .. "|" .. tostring(fields.op) .. "|" .. tostring(fields.cid)
    end
    return nil
end

local function DiscardOlderState(sender, rev)
    local prefix = "state|" .. sender:lower() .. "|"
    local keep = prefix .. tostring(rev)
    for key in pairs(buffers) do
        if key:sub(1, #prefix) == prefix and key ~= keep then
            buffers[key] = nil
        end
    end
end

local JOIN_KEYS = { text = true, name = true }

local function MergeToken(merged, key, remainder)
    local lower = tostring(key):lower()
    if lower == "part" then
        return
    end
    if JOIN_KEYS[lower] then
        for i = 1, #merged.order do
            if tostring(merged.order[i][1]):lower() == lower then
                merged.order[i][2] = tostring(merged.order[i][2]) .. tostring(remainder)
                merged.fields[lower] = DecodeUser(merged.order[i][2])
                return
            end
        end
    end
    ApplyToken(merged, key, remainder)
end

local function MergeParts(buffer)
    local merged = {
        type = buffer.typeName,
        kind = buffer.kind,
        fields = {},
        many = {},
        order = {},
    }
    for index = 1, buffer.total do
        local parsed = CCT.Net.Parse(buffer.parts[index])
        if parsed == nil then
            return nil
        end
        for i = 1, #parsed.order do
            MergeToken(merged, parsed.order[i][1], parsed.order[i][2])
        end
        merged.type = parsed.type
        merged.kind = parsed.kind
    end
    return merged
end

local function AcceptPart(parsed, raw, sender, channelName)
    if NO_SPLIT[parsed.kind] then
        return
    end
    local part, total = tostring(parsed.part or ""):match("^(%d+)/(%d+)$")
    part = tonumber(part)
    total = tonumber(total)
    if part == nil or total == nil or part < 1 or part > total or total < 2 then
        return
    end
    if parsed.kind == "state" then
        DiscardOlderState(sender, parsed.fields.rev)
    end
    local key = BufferIdentity(parsed, sender)
    if key == nil then
        return
    end
    local buffer = buffers[key]
    if buffer == nil or buffer.total ~= total then
        buffer = {
            parts = {},
            total = total,
            at = Now(),
            kind = parsed.kind,
            typeName = parsed.type,
        }
        buffers[key] = buffer
    end
    buffer.parts[part] = raw
    local have = 0
    for i = 1, total do
        if buffer.parts[i] ~= nil then
            have = have + 1
        end
    end
    if have < total then
        return
    end
    buffers[key] = nil
    local merged = MergeParts(buffer)
    if merged then
        Dispatch(merged, sender, channelName)
    end
end

function CCT.Net.Receive(prefix, message, channelName, sender)
    if prefix ~= CCT.PREFIX or type(message) ~= "string" then
        return
    end
    local route = type(channelName) == "string" and channelName:upper() or ""
    if route ~= "WHISPER" and route ~= "PARTY" then
        return
    end
    local short = SenderShort(sender)
    if short == nil then
        return
    end
    local parsed = CCT.Net.Parse(message)
    if parsed == nil then
        return
    end
    if route == "PARTY" and parsed.kind ~= "prox" then
        return
    end
    if parsed.part ~= nil then
        if NO_SPLIT[parsed.kind] then
            return
        end
        AcceptPart(parsed, message, short, route)
        return
    end
    if parsed.kind == "state" then
        DiscardOlderState(short, parsed.fields.rev)
    end
    Dispatch(parsed, short, route)
end

function CCT.Net.On(kind, fn)
    local norm = NormKind(kind)
    if WIRE_NAME[norm] == nil or type(fn) ~= "function" then
        return false
    end
    handlers[norm] = handlers[norm] or {}
    handlers[norm][#handlers[norm] + 1] = fn
    return true
end

function CCT.Net.Reset()
    snapshots = {}
    reliable = {}
    channel = {}
    prox = {}
    buffers = {}
    offline = {}
    readyAt = {}
    holdOnline = {}
    lockdownHold = false
    sessionBlocked = false
    trialNoted = false
    pumping = false
    CCT.Net.LastResult = nil
end

local function RegisterPrefix()
    if prefixRegistered then
        return
    end
    if C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, CCT.PREFIX)
        prefixRegistered = true
    end
end

local function StartTicker()
    if tickerStarted or C_Timer == nil or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    tickerStarted = true
    C_Timer.NewTicker(PUMP_INTERVAL, function()
        CCT.Net.Pump()
    end)
end

function CCT.Net.OnEvent(_, event)
    if event == "CHAT_MSG_ADDON" then
        return
    end
    if event == "PLAYER_LOGIN" then
        RegisterPrefix()
        if TrialNow() then
            sessionBlocked = true
            NoteTrial()
        end
        StartTicker()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if not InstanceHeld() then
            lockdownHold = false
            CCT.Net.Pump()
        end
        return
    end
    if event == "GUILD_ROSTER_UPDATE" then
        ReleaseOnline()
        CCT.Net.Pump()
    end
end

function CCT.Net.OnAddon(_, _, prefix, message, channelName, sender)
    CCT.Net.Receive(prefix, message, channelName, sender)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            CCT.Net.Receive(...)
            return
        end
        CCT.Net.OnEvent(self, event)
    end)
end
