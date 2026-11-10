-- Guild Master scorecard. Fourteen day rows per kitten, written and not drawn.
-- No window and no copy box. tasks is stored. PR 8 is the only increment.
-- applied, previous, droppedWeek, rotatedWeek, and storedWeeks may still sit on
-- an old record. This file does not read them and does not delete them.

local ADDON_NAME, CCT = ...

CCT.Store = {}

local KITTEN_CAP = 40
local MASTER_CAP = 4 * 1024 * 1024
local STORED_CAP = 28
local DAY_CAP = 14
local MINUTE_CAP = 1440
local EVENT_CAP = 9999
local SENDER_CAP = 20

local LEDGER_FIELDS = {
    "heelsMin", "gagMin", "tasks", "heatPeak", "orgasm", "deny", "playMin", "sub",
    "pets", "hugs", "kisses", "spanks", "earPinch", "slack", "slackMin",
    "napOk", "napEarly", "napOver", "napMiss", "petMiss", "petMin",
}

local RESTRAINTS = {
    "gag", "blind", "ears", "mittens", "heels", "bell", "tail",
    "jewel", "belt", "bra", "leash",
}
local TOY_IDS = {
    "dildo", "inflatable_butplug", "inflatable_dildo", "small_butplug",
    "large_butplug", "taill_butplug", "vibes_pussy", "vibes_nipples",
    "vibes_ears", "nipple_piercings", "ear_piercings", "pussy_lipps_piercings",
}

local OWNER_FIELDS = {}
for i = 1, #RESTRAINTS do
    OWNER_FIELDS[#OWNER_FIELDS + 1] = RESTRAINTS[i] .. "On"
    OWNER_FIELDS[#OWNER_FIELDS + 1] = RESTRAINTS[i] .. "Off"
end
for i = 1, #TOY_IDS do
    OWNER_FIELDS[#OWNER_FIELDS + 1] = TOY_IDS[i] .. "On"
    OWNER_FIELDS[#OWNER_FIELDS + 1] = TOY_IDS[i] .. "Off"
end
OWNER_FIELDS[#OWNER_FIELDS + 1] = "tasks"
OWNER_FIELDS[#OWNER_FIELDS + 1] = "disc"

local WORN_SET = {
    blind = true, ears = true, mittens = true, bell = true, tail = true,
    jewel = true, belt = true, bra = true, leash = true,
}
if CCT.State and type(CCT.State.Toys) == "table" then
    for i = 1, #CCT.State.Toys do
        local id = CCT.State.Toys[i].id
        if type(id) == "string" then
            WORN_SET[id] = true
        end
    end
end

local LEDGER_BY_LOWER = {}
for i = 1, #LEDGER_FIELDS do
    LEDGER_BY_LOWER[LEDGER_FIELDS[i]:lower()] = LEDGER_FIELDS[i]
end
local OWNER_BY_LOWER = {}
for i = 1, #OWNER_FIELDS do
    OWNER_BY_LOWER[OWNER_FIELDS[i]:lower()] = OWNER_FIELDS[i]
end

local warned = {}

local function Say(text)
    if type(print) == "function" then
        print(text)
    end
end

local function DB()
    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    return CCT.db
end

local function Stamp(now)
    local n = tonumber(now)
    if n ~= nil then
        return n
    end
    if type(time) == "function" then
        return tonumber(time()) or 0
    end
    return 0
end

local function IsDayId(id)
    return type(id) == "string" and id:match("^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

local function IsWeekId(id)
    return type(id) == "string" and id:match("^%d%d%d%d%-W%d%d$") ~= nil
end

local function LocalMaster()
    local db = DB()
    local settings = db and db.settings
    local master = settings and settings.masterName
    local short = CCT.Player and CCT.Player.short
    if type(master) ~= "string" or master == "" or type(short) ~= "string" then
        return false
    end
    return CCT.SameName(short, master)
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

local function ClampLedger(name, value)
    local n = math.floor(tonumber(value) or 0)
    if n < 0 then
        n = 0
    end
    local cap = EVENT_CAP
    if name == "heatPeak" or name == "sub" then
        cap = 100
    elseif name == "heelsMin" or name == "gagMin" or name == "playMin" or name == "slackMin" or name == "petMin" then
        cap = MINUTE_CAP
    end
    if n > cap then
        n = cap
    end
    return n
end

local function ClampOwner(value)
    local n = math.floor(tonumber(value) or 0)
    if n < 0 then
        n = 0
    end
    if n > EVENT_CAP then
        n = EVENT_CAP
    end
    return n
end

local function ClampMinute(value)
    return ClampLedger("playMin", value)
end

local function CountKittens(kittens)
    local count = 0
    for _, row in pairs(kittens) do
        if type(row) == "table" then
            count = count + 1
        end
    end
    return count
end

local function WarnOnce(name, text)
    local key = type(name) == "string" and name:lower() or ""
    if key == "" or warned[key] then
        return
    end
    warned[key] = true
    Say(text)
end

local function FindRecord(kittens, name)
    if type(name) ~= "string" or name == "" then
        return nil, nil
    end
    if type(kittens[name]) == "table" then
        return name, kittens[name]
    end
    local want = CCT.ShortName(name)
    if want == nil then
        return nil, nil
    end
    for key, row in pairs(kittens) do
        if type(key) == "string" and type(row) == "table" and CCT.SameName(key, want) then
            return key, row
        end
    end
    return nil, nil
end

local function Fresh(day, now)
    return {
        day = day,
        seq = 0,
        at = now,
        fields = {},
        zones = {},
        senders = {},
        owner = nil,
    }
end

local function DayCmp(a, b)
    if CCT.Day == nil or type(CCT.Day.Cmp) ~= "function" then
        return 0
    end
    return CCT.Day.Cmp(a, b)
end

local function Remember(record, id)
    if type(id) ~= "string" or id == "" or IsWeekId(id) then
        return
    end
    if type(record.storedDays) ~= "table" then
        record.storedDays = {}
    end
    local list = record.storedDays
    for i = 1, #list do
        if list[i] == id then
            return
        end
    end
    list[#list + 1] = id
    while #list > STORED_CAP do
        table.remove(list, 1)
    end
end

local function Seed(record)
    if type(record.storedDays) == "table" and #record.storedDays > 0 then
        return
    end
    if type(record.days) ~= "table" then
        record.days = {}
    end
    local ids = {}
    for key, row in pairs(record.days) do
        if type(row) == "table" then
            local id = nil
            if type(row.day) == "string" and row.day ~= "" then
                id = row.day
            elseif type(key) == "string" then
                id = key
            end
            if id ~= nil and not IsWeekId(id) then
                ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids, function(a, b)
        return DayCmp(a, b) < 0
    end)
    record.storedDays = ids
end

local function Stored(record, id)
    local list = record.storedDays
    if type(list) ~= "table" then
        return false
    end
    for i = 1, #list do
        if list[i] == id then
            return true
        end
    end
    return false
end

local function NoteRotated(record, id)
    if type(id) ~= "string" or id == "" then
        return
    end
    record.rotatedDay = id
    if CCT.Debug then
        CCT.Debug(
            "scorecard-rotate",
            0,
            "Closed day " .. id .. " rotated off the scorecard. It had been retained."
        )
    end
end

local function OldestKey(days)
    local best = nil
    for key, row in pairs(days) do
        if type(row) == "table" and type(key) == "string" then
            if best == nil or DayCmp(key, best) < 0 then
                best = key
            end
        end
    end
    return best
end

local function RowId(key, row)
    if type(row) == "table" and type(row.day) == "string" and row.day ~= "" then
        return row.day
    end
    if type(key) == "string" then
        return key
    end
    return nil
end

-- A nil DaysBefore skips that id. One bad id does not abort the kitten.
local function Sweep(record, now)
    if type(record.days) ~= "table" then
        record.days = {}
        return
    end
    if CCT.Day == nil or type(CCT.Day.Id) ~= "function" or type(CCT.Day.DaysBefore) ~= "function" then
        return
    end
    local today = CCT.Day.Id(now)
    if not IsDayId(today) then
        return
    end
    local remove = {}
    for key, row in pairs(record.days) do
        if type(row) == "table" then
            local id = RowId(key, row)
            local before = id ~= nil and CCT.Day.DaysBefore(today, id) or nil
            if type(before) == "number" and before > 13 then
                remove[#remove + 1] = key
            end
        end
    end
    for i = 1, #remove do
        local key = remove[i]
        local row = record.days[key]
        local id = RowId(key, row) or key
        record.days[key] = nil
        NoteRotated(record, id)
    end
end

local function Choose(record, day, now)
    if type(record.days) ~= "table" then
        record.days = {}
    end
    local days = record.days
    if type(days[day]) == "table" then
        return days[day]
    end
    local count = 0
    for _, row in pairs(days) do
        if type(row) == "table" then
            count = count + 1
        end
    end
    if count >= DAY_CAP then
        local oldest = OldestKey(days)
        if oldest ~= nil then
            days[oldest] = nil
            NoteRotated(record, oldest)
        end
    end
    days[day] = Fresh(day, now)
    Remember(record, day)
    return days[day]
end

local function NoteDropped(record, parsed)
    local fields = parsed and parsed.fields
    local id = fields and fields.dropped
    if not IsDayId(id) then
        return
    end
    if Stored(record, id) then
        return
    end
    record.droppedDay = id
    if CCT.Debug then
        CCT.Debug("scorecard-drop", 0, "Unacked " .. id .. " was dropped before it was retained.")
    end
end

local function TooOld(day, now)
    if CCT.Day == nil or type(CCT.Day.Id) ~= "function" or type(CCT.Day.DaysBefore) ~= "function" then
        return false
    end
    local today = CCT.Day.Id(now)
    local before = CCT.Day.DaysBefore(today, day)
    return type(before) == "number" and before > 13
end

local function Field(parsed, name)
    local fields = parsed and parsed.fields
    if type(fields) ~= "table" or type(name) ~= "string" then
        return nil
    end
    if fields[name] ~= nil then
        return fields[name]
    end
    local lower = name:lower()
    if fields[lower] ~= nil then
        return fields[lower]
    end
    local canon = LEDGER_BY_LOWER[lower] or OWNER_BY_LOWER[lower]
    if canon ~= nil and fields[canon] ~= nil then
        return fields[canon]
    end
    return nil
end

local function TakeSeq(row, parsed)
    local seq = tonumber(Field(parsed, "seq")) or 0
    if seq < (tonumber(row.seq) or 0) then
        return nil
    end
    return seq
end

local function ApplyLedger(row, parsed, now)
    local seq = TakeSeq(row, parsed)
    if seq == nil then
        return false
    end
    if type(row.fields) ~= "table" then
        row.fields = {}
    end
    for i = 1, #LEDGER_FIELDS do
        local name = LEDGER_FIELDS[i]
        local value = Field(parsed, name)
        if value ~= nil then
            row.fields[name] = ClampLedger(name, value)
        end
    end
    row.seq = seq
    row.at = now
    return true
end

local function ApplyZones(row, parsed, now)
    local seq = TakeSeq(row, parsed)
    if seq == nil then
        return false
    end
    local zones = {}
    local rows = parsed.many and parsed.many.z or nil
    if type(rows) == "table" then
        for i = 1, #rows do
            local item = rows[i]
            if type(item) == "table" and type(item.name) == "string" and item.name ~= "" then
                local minutes = ClampMinute(item.minutes)
                if minutes > 0 then
                    zones[item.name] = minutes
                end
            end
        end
    end
    row.zones = zones
    row.seq = seq
    row.at = now
    return true
end

local function ApplyPets(row, parsed, now)
    local seq = TakeSeq(row, parsed)
    if seq == nil then
        return false
    end
    local list = {}
    local function push(pair)
        for i = #list, 1, -1 do
            if list[i] == pair then
                table.remove(list, i)
            end
        end
        list[#list + 1] = pair
        while #list > SENDER_CAP do
            table.remove(list, 1)
        end
    end
    local rows = parsed.many and parsed.many.p or nil
    if type(rows) == "table" then
        for i = 1, #rows do
            local item = rows[i]
            if type(item) == "table" and type(item.action) == "string" and item.action ~= "" and type(item.sender) == "string" and item.sender ~= "" then
                push(item.action .. ":" .. item.sender)
            end
        end
    end
    row.senders = list
    row.seq = seq
    row.at = now
    return true
end

local function ApplyWorn(row, parsed, now)
    local seq = TakeSeq(row, parsed)
    if seq == nil then
        return false
    end
    local worn = {}
    local rows = parsed.many and parsed.many.w or nil
    if type(rows) == "table" then
        for i = 1, #rows do
            local item = rows[i]
            if type(item) == "table" and type(item.id) == "string" and WORN_SET[item.id] then
                local minutes = ClampMinute(item.minutes)
                if minutes > 0 then
                    worn[item.id] = minutes
                end
            end
        end
    end
    row.worn = worn
    row.seq = seq
    row.at = now
    return true
end

local function ApplyOwner(row, parsed, now)
    if type(row.owner) ~= "table" or row.owner.day ~= row.day then
        row.owner = { day = row.day, seq = 0, at = now }
    end
    local owner = row.owner
    local seq = tonumber(Field(parsed, "seq")) or 0
    if seq < (tonumber(owner.seq) or 0) then
        return false
    end
    for _, name in pairs(OWNER_BY_LOWER) do
        local value = Field(parsed, name)
        if value ~= nil then
            owner[name] = ClampOwner(value)
        end
    end
    owner.day = row.day
    owner.seq = seq
    owner.at = now
    row.at = now
    return true
end

local function Ack(sender, row)
    if sender == nil or CCT.Net == nil or type(CCT.Net.Whisper) ~= "function" then
        return false
    end
    return CCT.Net.Whisper(sender, "ledgerack", {
        { "day", row.day },
        { "seq", tostring(row.seq) },
    }) and true or false
end

local function BlankRecord()
    return {
        days = {},
        droppedDay = nil,
        rotatedDay = nil,
        storedDays = {},
    }
end

local function MaintainOne(record, stamp)
    Seed(record)
    Sweep(record, stamp)
end

function CCT.Store.Maintain(now)
    if not LocalMaster() then
        return false
    end
    local db = DB()
    local kittens = db and db.master and db.master.kittens
    if type(kittens) ~= "table" then
        return false
    end
    local stamp = Stamp(now)
    for _, record in pairs(kittens) do
        if type(record) == "table" then
            pcall(MaintainOne, record, stamp)
        end
    end
    return true
end

function CCT.Store.Accept(kind, sender, parsed, now)
    if not LocalMaster() or type(parsed) ~= "table" or type(parsed.fields) ~= "table" then
        return false
    end
    local norm = type(kind) == "string" and kind:lower() or ""
    if norm ~= "ledger" and norm ~= "zones" and norm ~= "pets" and norm ~= "worn" and norm ~= "ownerweek" then
        return false
    end
    local day = Field(parsed, "day")
    if not IsDayId(day) then
        return false
    end
    local kitten = sender
    if norm == "ownerweek" then
        kitten = Field(parsed, "kitten")
    end
    kitten = CCT.ShortName(kitten)
    if kitten == nil then
        return false
    end
    if CCT.Roster == nil or type(CCT.Roster.GetMember) ~= "function" then
        return false
    end
    local member = CCT.Roster.GetMember(norm == "ownerweek" and kitten or sender)
    if type(member) ~= "table" then
        return false
    end
    if norm == "ownerweek" then
        if type(member.ownerShort) ~= "string" or not CCT.SameName(member.ownerShort, sender) then
            return false
        end
    end
    local db = DB()
    if type(db) ~= "table" or type(db.master) ~= "table" or type(db.master.kittens) ~= "table" then
        return false
    end
    local kittens = db.master.kittens
    local key, record = FindRecord(kittens, kitten)
    local stamp = Stamp(now)
    local fresh = false
    if record == nil then
        if CountKittens(kittens) >= KITTEN_CAP then
            WarnOnce(kitten, "|cffffff00CatgirlTracker:|r The scorecard already has 40 kittens. " .. kitten .. " was not added.")
            return false
        end
        if Bytes(db.master, 0, {}) >= MASTER_CAP then
            WarnOnce(kitten, "|cffffff00CatgirlTracker:|r The scorecard file is over 4 MB. " .. kitten .. " was not added.")
            return false
        end
        record = BlankRecord()
        key = kitten
        fresh = true
    end
    Seed(record)
    Sweep(record, stamp)
    if TooOld(day, stamp) then
        return false
    end
    local row = Choose(record, day, stamp)
    if row == nil then
        return false
    end
    local applied = false
    if norm == "ledger" then
        applied = ApplyLedger(row, parsed, stamp)
    elseif norm == "zones" then
        applied = ApplyZones(row, parsed, stamp)
    elseif norm == "pets" then
        applied = ApplyPets(row, parsed, stamp)
    elseif norm == "worn" then
        applied = ApplyWorn(row, parsed, stamp)
    else
        applied = ApplyOwner(row, parsed, stamp)
    end
    if not applied then
        return false
    end
    if fresh then
        kittens[key] = record
    end
    if norm == "ledger" then
        NoteDropped(record, parsed)
        Ack(sender, row)
    end
    return true
end

function CCT.Store.Command(msg)
    local db = DB()
    local settings = db and db.settings
    if type(settings) ~= "table" then
        return false
    end
    local text = ""
    if type(msg) == "string" then
        text = msg:match("^%s*(.-)%s*$") or ""
    end
    if text == "" then
        local name = settings.masterName
        if type(name) == "string" and name ~= "" then
            Say("Guild Master is " .. name)
        else
            Say("Guild Master is not set.")
        end
        return true
    end
    local short = CCT.ShortName(text)
    if short == nil then
        return false
    end
    settings.masterName = short
    Say("Guild Master is " .. short)
    return true
end

function CCT.Store.OnEvent(_, event)
    if event == "PLAYER_LOGIN" then
        CCT.Store.Maintain(type(time) == "function" and time() or nil)
    end
end

local function OnPart(kind)
    return function(sender, parsed, channel)
        if channel ~= "WHISPER" then
            return
        end
        CCT.Store.Accept(kind, sender, parsed, type(time) == "function" and time() or nil)
    end
end

if CCT.Net and type(CCT.Net.On) == "function" then
    CCT.Net.On("ledger", OnPart("ledger"))
    CCT.Net.On("zones", OnPart("zones"))
    CCT.Net.On("pets", OnPart("pets"))
    CCT.Net.On("worn", OnPart("worn"))
    CCT.Net.On("ownerweek", OnPart("ownerweek"))
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", CCT.Store.OnEvent)
end

SLASH_CCTMASTER1 = "/cctmaster"
if SlashCmdList then
    SlashCmdList.CCTMASTER = function(msg)
        CCT.Store.Command(msg)
    end
end
