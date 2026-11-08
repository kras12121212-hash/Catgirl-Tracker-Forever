-- Owner memory. A command counts only after Success and Ack ok:1.
-- The weekly tally stays on this client and is not sent.
-- Zeros are stored. Tasks stays at 0 until PR 8.

local ADDON_NAME, CCT = ...

CCT.Corroboration = {}

local RESTRAINTS = {
    "gag", "blind", "ears", "mittens", "heels", "bell", "tail",
    "jewel", "belt", "bra", "leash",
}
local TOY_IDS = {
    "dildo", "inflatable_butplug", "inflatable_dildo", "small_butplug",
    "large_butplug", "taill_butplug", "vibes_pussy", "vibes_nipples",
    "vibes_ears", "nipple_piercings", "ear_piercings", "pussy_lipps_piercings",
}
local STATE_OPS = { gag = true, blind = true, ears = true, mittens = true, heels = true }
local FLAG_OPS = { jewel = true, leash = true, belt = true, bra = true }
local SENT_CAP = 50

local pending = {}

local function DB()
    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    return CCT.db
end

local function EmptyWeek(id)
    local row = { week = id, seq = 1, tasks = 0, disc = 0 }
    for i = 1, #RESTRAINTS do
        row[RESTRAINTS[i] .. "On"] = 0
        row[RESTRAINTS[i] .. "Off"] = 0
    end
    for i = 1, #TOY_IDS do
        row[TOY_IDS[i] .. "On"] = 0
        row[TOY_IDS[i] .. "Off"] = 0
    end
    return row
end

local function KittenRow(name)
    local db = DB()
    if type(db) ~= "table" or type(name) ~= "string" or name == "" then
        return nil
    end
    db.owner.kitten[name] = db.owner.kitten[name] or { state = {}, trail = {}, lastRev = 0, sent = {} }
    local row = db.owner.kitten[name]
    if type(row.state) ~= "table" then
        row.state = {}
    end
    if type(row.trail) ~= "table" then
        row.trail = {}
    end
    if type(row.sent) ~= "table" then
        row.sent = {}
    end
    return row
end

local function WeekRow(name)
    local db = DB()
    if type(db) ~= "table" or type(name) ~= "string" or name == "" then
        return nil
    end
    local current = CCT.Week and CCT.Week.Id and CCT.Week.Id() or nil
    local row = db.owner.weeks[name]
    if type(row) ~= "table" or (current ~= nil and row.week ~= current) then
        row = EmptyWeek(current)
        db.owner.weeks[name] = row
    end
    return row
end

function CCT.Corroboration.Week(name)
    return WeekRow(name)
end

function CCT.Corroboration.Sent(name)
    local row = KittenRow(name)
    if row == nil then
        return {}
    end
    return row.sent
end

local function FindKitten(name)
    local db = DB()
    if type(db) ~= "table" or type(db.owner) ~= "table" or type(db.owner.kitten) ~= "table" then
        return nil, nil
    end
    if type(db.owner.kitten[name]) == "table" then
        return name, db.owner.kitten[name]
    end
    for key, row in pairs(db.owner.kitten) do
        if CCT.SameName(key, name) then
            return key, row
        end
    end
    return nil, nil
end

local function AssignedSender(sender)
    local row = CCT.Roster and CCT.Roster.GetAssignedKitten and CCT.Roster.GetAssignedKitten()
    if type(row) ~= "table" then
        return false
    end
    return CCT.SameName(row.short, sender)
end

local function Bump(week, key)
    week[key] = (tonumber(week[key]) or 0) + 1
    week.seq = (tonumber(week.seq) or 1) + 1
end

local function Remember(name, op, detail)
    local row = KittenRow(name)
    if row == nil then
        return
    end
    row.sent[#row.sent + 1] = {
        t = CCT.UnixNow(),
        op = op,
        detail = detail,
    }
    while #row.sent > SENT_CAP do
        table.remove(row.sent, 1)
    end
end

local function ApplyCount(item)
    local week = WeekRow(item.kitten)
    local fields = item.fields or {}
    local op = item.op
    if week ~= nil then
        if STATE_OPS[op] then
            if fields.state == "none" then
                Bump(week, op .. "Off")
            else
                Bump(week, op .. "On")
            end
        elseif op == "bell" then
            local name = fields.which == "tail" and "tail" or "bell"
            if tostring(fields.on) == "1" then
                Bump(week, name .. "On")
            else
                Bump(week, name .. "Off")
            end
        elseif FLAG_OPS[op] then
            if tostring(fields.on) == "1" then
                Bump(week, op .. "On")
            else
                Bump(week, op .. "Off")
            end
        elseif op == "toy" then
            local id = fields.id
            if type(id) == "string" and id ~= "" then
                if fields.action == "apply" then
                    Bump(week, id .. "On")
                elseif fields.action == "remove" then
                    Bump(week, id .. "Off")
                end
            end
        elseif op == "disc" then
            Bump(week, "disc")
        end
    end
    Remember(item.kitten, op, item.detail)
    if type(item.sentence) == "string" and item.sentence ~= "" and CCT.Chat and CCT.Chat.Send then
        CCT.Chat.Send(item.sentence, "WHISPER", nil, item.kitten, { raw = true })
    end
    item.counted = true
end

local function TryFinish(item)
    if item == nil or item.counted or item.sent ~= true or item.ack ~= true then
        return false
    end
    ApplyCount(item)
    return true
end

function CCT.Corroboration.Begin(kitten, cid, meta)
    if kitten == nil or cid == nil then
        return false
    end
    meta = type(meta) == "table" and meta or {}
    WeekRow(kitten)
    pending[tostring(cid)] = {
        kitten = kitten,
        cid = tostring(cid),
        op = meta.op,
        fields = meta.fields or {},
        sentence = meta.sentence,
        detail = meta.detail or meta.op,
    }
    return true
end

function CCT.Corroboration.OnResult(cid, ok, result)
    local item = pending[tostring(cid)]
    if item == nil or item.counted then
        return false
    end
    item.sent = ok and true or false
    item.result = result
    if not ok then
        return false
    end
    return TryFinish(item)
end

function CCT.Corroboration.OnAck(sender, parsed)
    if type(parsed) ~= "table" or type(parsed.fields) ~= "table" then
        return false
    end
    local cid = parsed.fields.cid
    local item = pending[tostring(cid)]
    if item == nil or item.counted then
        return false
    end
    if sender ~= nil and not CCT.SameName(sender, item.kitten) then
        return false
    end
    item.ack = tostring(parsed.fields.ok) == "1"
    if not item.ack then
        return false
    end
    return TryFinish(item)
end

local function ToyTable(many)
    local toys = {}
    local list = CCT.State and CCT.State.Toys or {}
    for i = 1, #list do
        toys[list[i].id] = { applied = false, vibe = 0, inflate = 0 }
    end
    local rows = type(many) == "table" and many.ty or nil
    if type(rows) == "table" then
        for i = 1, #rows do
            local row = rows[i]
            if type(row) == "table" and type(row.id) == "string" and toys[row.id] then
                toys[row.id] = {
                    applied = row.applied == 1,
                    vibe = tonumber(row.vibe) or 0,
                    inflate = tonumber(row.inflate) or 0,
                }
            end
        end
    end
    return toys
end

local function LockTable(many)
    local locks = {}
    local rows = type(many) == "table" and many.lk or nil
    if type(rows) ~= "table" then
        return locks
    end
    for i = 1, #rows do
        local row = rows[i]
        if type(row) == "table" and type(row.bind) == "string" and row.unlockAt ~= nil then
            locks[row.bind] = { unlockAt = row.unlockAt }
        end
    end
    return locks
end

function CCT.Corroboration.ApplyState(sender, parsed)
    if not AssignedSender(sender) or type(parsed) ~= "table" or type(parsed.fields) ~= "table" then
        return false
    end
    local rev = tonumber(parsed.fields.rev) or 0
    local key, row = FindKitten(sender)
    if row == nil then
        row = KittenRow(CCT.ShortName(sender) or sender)
        key = CCT.ShortName(sender) or sender
    end
    if row == nil then
        return false
    end
    if type(row.lastRev) == "number" and rev <= row.lastRev then
        return false
    end
    local fields = parsed.fields
    local heel = {
        maid = tonumber(fields.hmaid) or 1,
        high = tonumber(fields.hhigh) or 1,
        ballet = tonumber(fields.hballet) or 1,
    }
    row.state = {
        rev = rev,
        week = fields.week,
        gag = fields.gag or "none",
        gagStage = fields.gag == "inflatable" and (tonumber(fields.gagstage) or 0) or 0,
        blind = fields.blind or "none",
        ears = fields.ears or "none",
        mittens = fields.mittens or "none",
        heels = fields.heels or "none",
        heelLevel = heel,
        bell = fields.bell == "1",
        tail = fields.tail == "1",
        jewel = fields.jewel == "1",
        belt = fields.belt == "1",
        beltMode = fields.beltmode or "allow",
        bra = fields.bra == "1",
        leash = fields.leash == "1",
        leashOwner = fields.leash == "1" and fields.leashowner or nil,
        zone = fields.zone or "",
        instanceType = fields.inst or "",
        heat = tonumber(fields.heat) or 0,
        sub = tonumber(fields.sub) or 0,
        locks = LockTable(parsed.many),
        toys = ToyTable(parsed.many),
        pos = row.state and row.state.pos or nil,
    }
    row.lastRev = rev
    return true
end

function CCT.Corroboration.ApplyPos(sender, parsed)
    if not AssignedSender(sender) or type(parsed) ~= "table" or type(parsed.fields) ~= "table" then
        return false
    end
    local fields = parsed.fields
    local mapID = tonumber(fields.map)
    local x = tonumber(fields.x)
    local y = tonumber(fields.y)
    if mapID == nil or x == nil or y == nil then
        return false
    end
    local key = select(1, FindKitten(sender))
    local row = select(2, FindKitten(sender))
    if row == nil then
        local name = CCT.ShortName(sender) or sender
        row = KittenRow(name)
        key = name
    end
    if row == nil then
        return false
    end
    local point = {
        mapID = mapID,
        x = x,
        y = y,
        instanceID = tonumber(fields.inst),
        t = tonumber(fields.t) or CCT.UnixNow(),
    }
    if type(row.state) ~= "table" then
        row.state = {}
    end
    row.state.pos = point
    if CCT.Report and CCT.Report.AppendTrail then
        CCT.Report.AppendTrail(row.trail, point, point.t)
    end
    return true
end

function CCT.Corroboration.Reset()
    pending = {}
end

if CCT.Net and type(CCT.Net.On) == "function" then
    CCT.Net.On("state", function(sender, parsed)
        CCT.Corroboration.ApplyState(sender, parsed)
    end)
    CCT.Net.On("pos", function(sender, parsed)
        CCT.Corroboration.ApplyPos(sender, parsed)
    end)
    CCT.Net.On("ack", function(sender, parsed)
        CCT.Corroboration.OnAck(sender, parsed)
    end)
end
