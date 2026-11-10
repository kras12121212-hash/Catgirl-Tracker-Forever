-- Kitten state is this struct. Modules write it through setters.
-- Session keys (nap, slack, partial heel progress) are dropped on login,
-- reload, and logout. They are not part of the saved schema.
-- There is no ticker and no chat hook here.

local ADDON_NAME, CCT = ...

CCT.State = {}

local GAGS = { none = true, small = true, huge = true, full = true, nyamask = true, inflatable = true }
local BLINDS = { none = true, light = true, mask = true, full = true }
local EARS = { none = true, kitten = true, heavy = true }
local MITTENS = { none = true, locked = true, heavy = true, squeaking = true }
local HEELS = { none = true, maid = true, high = true, ballet = true }
local HEEL_KINDS = { "maid", "high", "ballet" }

local TOYS = {
    { id = "dildo", restrict = "belt", vibe = true },
    { id = "inflatable_butplug", restrict = "belt", inflate = true, group = "butplug" },
    { id = "inflatable_dildo", restrict = "belt", inflate = true },
    { id = "small_butplug", restrict = "belt", group = "butplug" },
    { id = "large_butplug", restrict = "belt", group = "butplug" },
    { id = "taill_butplug", restrict = "belt", group = "butplug" },
    { id = "vibes_pussy", restrict = "belt", vibe = true },
    { id = "vibes_nipples", restrict = "bra", vibe = true },
    { id = "vibes_ears", vibe = true },
    { id = "nipple_piercings", restrict = "bra", vibe = true },
    { id = "ear_piercings", vibe = true },
    { id = "pussy_lipps_piercings", restrict = "belt", vibe = true },
}

local LOCK_BINDS = {
    "gag", "earmuffs", "blindfold", "mittens", "heels",
    "bell", "tailbell", "chastitybelt", "chastitybra",
}

local SCORE_MINUTE_CAP = 1440
local LOCK_MINUTE_CAP = 10080
local EVENT_CAP = 9999
local MINUTE_COUNTERS = { heelsMin = true, gagMin = true, playMin = true, slackMin = true }
local EVENT_COUNTERS = {
    tasks = true, orgasm = true, deny = true, pets = true, hugs = true,
    kisses = true, spanks = true, earPinch = true, slack = true,
    napOk = true, napEarly = true, napOver = true, napMiss = true,
}

local PERSISTED = {
    gag = true, gagStage = true, blind = true, ears = true, mittens = true,
    heels = true, heelLevel = true, bell = true, tail = true, jewel = true,
    belt = true, beltMode = true, bra = true, leash = true, leashOwner = true,
    toys = true, locks = true, heat = true, sub = true, zone = true,
    instanceType = true, pos = true, petSummoned = true, maid = true, week = true,
    counters = true, rev = true, updatedAt = true, lastUnixUpdate = true,
}

CCT.State.Toys = TOYS
CCT.State.LockBinds = LOCK_BINDS

local toyById = {}
local lockSet = {}
for i = 1, #TOYS do
    toyById[TOYS[i].id] = TOYS[i]
end
for i = 1, #LOCK_BINDS do
    lockSet[LOCK_BINDS[i]] = true
end

local live = nil
local boundShort = nil
local listeners = {}
local counterListeners = {}
local notifying = false

local function Current()
    if not CCT.Player or not CCT.Player.ready then
        return nil
    end
    return live
end

local function Touch(counterName)
    live.rev = (tonumber(live.rev) or 0) + 1
    live.updatedAt = CCT.UnixNow()
    -- Submissiveness writes from a listener. A nested write must not replay the wave.
    if notifying then
        return
    end
    notifying = true
    if counterName ~= nil then
        local value = live.counters and live.counters[counterName]
        for i = 1, #counterListeners do
            counterListeners[i](counterName, value, live)
        end
    end
    for i = 1, #listeners do
        listeners[i](live)
    end
    notifying = false
end

function CCT.State.Listen(fn)
    if type(fn) ~= "function" then
        return nil
    end
    listeners[#listeners + 1] = fn
    return fn
end

function CCT.State.ListenCounter(fn)
    if type(fn) ~= "function" then
        return nil
    end
    counterListeners[#counterListeners + 1] = fn
    return fn
end

local function EmptyCounters()
    return {
        seq = 1,
        heelsMin = 0,
        gagMin = 0,
        tasks = 0,
        heatPeak = 0,
        orgasm = 0,
        deny = 0,
        playMin = 0,
        pets = 0,
        hugs = 0,
        kisses = 0,
        spanks = 0,
        earPinch = 0,
        slack = 0,
        slackMin = 0,
        napOk = 0,
        napEarly = 0,
        napOver = 0,
        napMiss = 0,
    }
end

local function EmptyToy()
    return { applied = false, vibe = 0, inflate = 0 }
end

local function EmptyToys()
    local toys = {}
    for i = 1, #TOYS do
        toys[TOYS[i].id] = EmptyToy()
    end
    return toys
end

function CCT.State.New()
    return {
        gag = "none",
        gagStage = 0,
        blind = "none",
        ears = "none",
        mittens = "none",
        heels = "none",
        heelLevel = { maid = 1, high = 1, ballet = 1 },
        bell = false,
        tail = false,
        jewel = false,
        belt = false,
        beltMode = "allow",
        bra = false,
        leash = false,
        leashOwner = nil,
        toys = EmptyToys(),
        locks = {},
        heat = 0,
        sub = 0,
        zone = "",
        instanceType = "none",
        pos = nil,
        petSummoned = false,
        week = nil,
        counters = EmptyCounters(),
        rev = 0,
        updatedAt = 0,
        lastUnixUpdate = 0,
    }
end

function CCT.State.Get()
    return Current()
end

local function ClampInt(value, low, high)
    local n = math.floor(tonumber(value) or 0)
    if n < low then
        return low
    end
    if n > high then
        return high
    end
    return n
end

local function CounterCap(name)
    if MINUTE_COUNTERS[name] then
        return SCORE_MINUTE_CAP
    end
    if name == "heatPeak" then
        return 100
    end
    if EVENT_COUNTERS[name] then
        return EVENT_CAP
    end
    return nil
end

local function IsCounter(name)
    return CounterCap(name) ~= nil
end

local function Round4(n)
    if n >= 0 then
        return math.floor(n * 10000 + 0.5) / 10000
    end
    return math.ceil(n * 10000 - 0.5) / 10000
end

local function DropUnknown(state)
    local changed = false
    for key in pairs(state) do
        if not PERSISTED[key] then
            state[key] = nil
            changed = true
        end
    end
    return changed
end

function CCT.State.DropSession()
    if type(live) ~= "table" then
        return
    end
    DropUnknown(live)
end

local function CopyMaidItem(item)
    if type(item) ~= "table" then
        return nil
    end
    local name = type(item.name) == "string" and item.name or ""
    return {
        itemID = tonumber(item.itemID),
        name = name,
        count = tonumber(item.count) or 0,
    }
end

local function NormalizeMaid(state)
    if state.maid == nil then
        return false
    end
    if type(state.maid) ~= "table" then
        state.maid = nil
        return true
    end
    local changed = false
    local source = state.maid
    local items = {}
    local rawItems = type(source.items) == "table" and source.items or {}
    for i = 1, math.min(20, #rawItems) do
        local copy = CopyMaidItem(rawItems[i])
        if copy ~= nil then
            items[#items + 1] = copy
        end
    end
    local instructions = {}
    local rawText = type(source.instructions) == "table" and source.instructions or {}
    for i = 1, math.min(20, #rawText) do
        if type(rawText[i]) == "string" then
            instructions[#instructions + 1] = rawText[i]
        end
    end
    local id = source.id
    if id ~= nil then
        id = tostring(id)
    end
    if source.id ~= id or type(source.items) ~= "table" or type(source.instructions) ~= "table" or #rawItems ~= #items or #rawText ~= #instructions then
        changed = true
    end
    state.maid = { id = id, items = items, instructions = instructions }
    return changed
end

local function NormalizeCounters(state)
    local changed = false
    if type(state.counters) ~= "table" then
        state.counters = EmptyCounters()
        return true
    end
    local counters = state.counters
    for key in pairs(counters) do
        if key ~= "week" and key ~= "seq" and not IsCounter(key) then
            counters[key] = nil
            changed = true
        end
    end
    if counters.week ~= nil and type(counters.week) ~= "string" then
        counters.week = nil
        changed = true
    end
    local seq = tonumber(counters.seq)
    if seq == nil or seq < 1 then
        counters.seq = 1
        changed = true
    else
        seq = math.floor(seq)
        if counters.seq ~= seq then
            counters.seq = seq
            changed = true
        end
    end
    local fresh = EmptyCounters()
    for name in pairs(fresh) do
        if name ~= "seq" then
            local cap = CounterCap(name)
            local n = ClampInt(counters[name], 0, cap)
            if counters[name] ~= n then
                counters[name] = n
                changed = true
            end
        end
    end
    return changed
end

local function NormalizeToys(state)
    local changed = false
    if type(state.toys) ~= "table" then
        state.toys = EmptyToys()
        return true
    end
    for key in pairs(state.toys) do
        if toyById[key] == nil then
            state.toys[key] = nil
            changed = true
        end
    end
    for i = 1, #TOYS do
        local id = TOYS[i].id
        local toy = state.toys[id]
        if type(toy) ~= "table" then
            state.toys[id] = EmptyToy()
            changed = true
        else
            local spec = TOYS[i]
            local applied = toy.applied == true
            local vibe = 0
            local inflate = 0
            if applied and spec.vibe then
                vibe = ClampInt(toy.vibe, 0, 5)
            end
            if applied and spec.inflate then
                inflate = ClampInt(toy.inflate, 0, 5)
            end
            if toy.applied ~= applied or toy.vibe ~= vibe or toy.inflate ~= inflate then
                toy.applied = applied
                toy.vibe = vibe
                toy.inflate = inflate
                changed = true
            end
            for field in pairs(toy) do
                if field ~= "applied" and field ~= "vibe" and field ~= "inflate" then
                    toy[field] = nil
                    changed = true
                end
            end
        end
    end
    local keeper = nil
    for i = 1, #TOYS do
        local spec = TOYS[i]
        if spec.group == "butplug" and state.toys[spec.id].applied then
            if keeper == nil then
                keeper = spec.id
            else
                local other = state.toys[spec.id]
                other.applied = false
                other.vibe = 0
                other.inflate = 0
                changed = true
            end
        end
    end
    return changed
end

local function NormalizeLocks(state)
    local changed = false
    if type(state.locks) ~= "table" then
        state.locks = {}
        return true
    end
    for key, lock in pairs(state.locks) do
        local unlockAt = type(lock) == "table" and tonumber(lock.unlockAt) or nil
        local minutes = type(lock) == "table" and tonumber(lock.minutes) or nil
        if not lockSet[key] or unlockAt == nil or minutes == nil or minutes < 1 then
            state.locks[key] = nil
            changed = true
        else
            minutes = ClampInt(minutes, 1, LOCK_MINUTE_CAP)
            unlockAt = math.floor(unlockAt)
            if lock.unlockAt ~= unlockAt or lock.minutes ~= minutes then
                lock.unlockAt = unlockAt
                lock.minutes = minutes
                changed = true
            end
            for field in pairs(lock) do
                if field ~= "unlockAt" and field ~= "minutes" then
                    lock[field] = nil
                    changed = true
                end
            end
        end
    end
    return changed
end

local function NormalizePos(state)
    local pos = state.pos
    if pos == nil then
        return false
    end
    if type(pos) ~= "table" or type(pos.mapID) ~= "number" or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
        state.pos = nil
        return true
    end
    local changed = false
    local x = Round4(pos.x)
    local y = Round4(pos.y)
    if pos.x ~= x or pos.y ~= y then
        pos.x = x
        pos.y = y
        changed = true
    end
    if pos.t ~= nil and type(pos.t) ~= "number" then
        pos.t = nil
        changed = true
    end
    if pos.instanceID ~= nil and type(pos.instanceID) ~= "number" then
        pos.instanceID = nil
        changed = true
    end
    for field in pairs(pos) do
        if field ~= "mapID" and field ~= "x" and field ~= "y" and field ~= "instanceID" and field ~= "t" then
            pos[field] = nil
            changed = true
        end
    end
    return changed
end

local function PutEnum(state, field, value, allowed, fallback)
    if value == "squeking" and field == "mittens" then
        value = "squeaking"
    end
    if not allowed[value] then
        value = fallback
    end
    if state[field] ~= value then
        state[field] = value
        return true
    end
    return false
end

function CCT.State.Normalize(state, strip)
    if type(state) ~= "table" then
        return CCT.State.New(), false
    end
    local changed = false
    if strip then
        changed = DropUnknown(state) or changed
    end
    changed = PutEnum(state, "gag", state.gag, GAGS, "none") or changed
    local stage = 0
    if state.gag == "inflatable" then
        if tonumber(state.gagStage) == nil then
            stage = 1
        else
            stage = ClampInt(state.gagStage, 1, 5)
        end
    end
    if state.gagStage ~= stage then
        state.gagStage = stage
        changed = true
    end
    changed = PutEnum(state, "blind", state.blind, BLINDS, "none") or changed
    changed = PutEnum(state, "ears", state.ears, EARS, "none") or changed
    changed = PutEnum(state, "mittens", state.mittens, MITTENS, "none") or changed
    changed = PutEnum(state, "heels", state.heels, HEELS, "none") or changed

    if type(state.heelLevel) ~= "table" then
        state.heelLevel = { maid = 1, high = 1, ballet = 1 }
        changed = true
    else
        for i = 1, #HEEL_KINDS do
            local which = HEEL_KINDS[i]
            local n = ClampInt(state.heelLevel[which], 1, 20)
            if tonumber(state.heelLevel[which]) == nil then
                n = 1
            end
            if state.heelLevel[which] ~= n then
                state.heelLevel[which] = n
                changed = true
            end
        end
        for key in pairs(state.heelLevel) do
            if key ~= "maid" and key ~= "high" and key ~= "ballet" then
                state.heelLevel[key] = nil
                changed = true
            end
        end
    end

    local function PutBool(field)
        local flag = state[field] == true
        if state[field] ~= flag then
            state[field] = flag
            changed = true
        end
    end
    PutBool("bell")
    PutBool("tail")
    PutBool("jewel")
    PutBool("belt")
    PutBool("bra")
    PutBool("leash")
    PutBool("petSummoned")

    if state.belt ~= true then
        if state.beltMode ~= "allow" then
            state.beltMode = "allow"
            changed = true
        end
    elseif state.beltMode ~= "allow" and state.beltMode ~= "deny" then
        state.beltMode = "allow"
        changed = true
    end

    if state.leash == true then
        local short = CCT.ShortName(state.leashOwner)
        if state.leashOwner ~= short then
            state.leashOwner = short
            changed = true
        end
    elseif state.leashOwner ~= nil then
        state.leashOwner = nil
        changed = true
    end

    local heat = tonumber(state.heat) or 0
    if heat < 0 then heat = 0 end
    if heat > 100 then heat = 100 end
    if state.heat ~= heat then
        state.heat = heat
        changed = true
    end
    local sub = ClampInt(state.sub, 0, 100)
    if state.sub ~= sub then
        state.sub = sub
        changed = true
    end

    if type(state.zone) ~= "string" then
        state.zone = ""
        changed = true
    end
    if type(state.instanceType) ~= "string" or state.instanceType == "" then
        if state.instanceType ~= "none" then
            state.instanceType = "none"
            changed = true
        end
    end
    if state.week ~= nil and type(state.week) ~= "string" then
        state.week = nil
        changed = true
    end
    if type(state.rev) ~= "number" or state.rev < 0 then
        state.rev = 0
        changed = true
    end
    if type(state.updatedAt) ~= "number" then
        state.updatedAt = 0
        changed = true
    end
    if state.lastUnixUpdate ~= nil and type(state.lastUnixUpdate) ~= "number" then
        state.lastUnixUpdate = nil
        changed = true
    end

    changed = NormalizePos(state) or changed
    changed = NormalizeToys(state) or changed
    changed = NormalizeLocks(state) or changed
    changed = NormalizeCounters(state) or changed
    changed = NormalizeMaid(state) or changed
    local shown = ClampInt((tonumber(state.heat) or 0) + 0.5, 0, 100)
    if (state.counters.heatPeak or 0) < shown then
        state.counters.heatPeak = shown
        changed = true
    end
    return state, changed
end

function CCT.State.Bind(short)
    if not CCT.Saved or not CCT.Saved.EnsureChar then
        return nil
    end
    local char = CCT.Saved.EnsureChar(short)
    if char == nil then
        return nil
    end
    local strip = boundShort ~= short
    local state, changed = CCT.State.Normalize(char.state, strip)
    char.state = state
    live = state
    boundShort = short
    if changed then
        Touch()
    end
    return live
end

-- A manual off cancels that bind's deadline. It does not print the expiry lines.
-- Swapping to another worn value keeps the same unlockAt.
-- ExpireLock is the only path that removes the bind because the clock ran out.
local ENUM_LOCK = {
    blind = "blindfold",
    ears = "earmuffs",
    mittens = "mittens",
    heels = "heels",
}

local function DropLock(state, bind)
    if type(bind) ~= "string" or type(state.locks) ~= "table" or state.locks[bind] == nil then
        return false
    end
    state.locks[bind] = nil
    return true
end

local function SetEnum(field, value, allowed)
    local state = Current()
    if state == nil or not allowed[value] then
        return false
    end
    local dropped = false
    if value == "none" then
        dropped = DropLock(state, ENUM_LOCK[field])
    end
    if state[field] == value and not dropped then
        return true
    end
    state[field] = value
    Touch()
    return true
end

function CCT.State.SetGag(value, stage)
    local state = Current()
    if state == nil or not GAGS[value] then
        return false
    end
    local nextStage = 0
    if value == "inflatable" then
        nextStage = ClampInt(stage, 1, 5)
        if tonumber(stage) == nil then
            nextStage = 1
        end
    end
    local dropped = false
    if value == "none" then
        dropped = DropLock(state, "gag")
    end
    if state.gag == value and state.gagStage == nextStage and not dropped then
        return true
    end
    state.gag = value
    state.gagStage = nextStage
    Touch()
    return true
end

function CCT.State.SetBlind(value)
    return SetEnum("blind", value, BLINDS)
end

function CCT.State.SetEars(value)
    return SetEnum("ears", value, EARS)
end

function CCT.State.SetMittens(value)
    if value == "squeking" then
        value = "squeaking"
    end
    return SetEnum("mittens", value, MITTENS)
end

function CCT.State.SetHeels(value)
    return SetEnum("heels", value, HEELS)
end

function CCT.State.SetHeelLevel(which, level)
    local state = Current()
    if state == nil or (which ~= "maid" and which ~= "high" and which ~= "ballet") then
        return false
    end
    if tonumber(level) == nil then
        return false
    end
    local n = ClampInt(level, 1, 20)
    if state.heelLevel[which] == n then
        return true
    end
    state.heelLevel[which] = n
    Touch()
    return true
end

local function SetFlag(field, value, lockBind)
    local state = Current()
    if state == nil then
        return false
    end
    local flag = value and true or false
    local dropped = false
    if not flag then
        dropped = DropLock(state, lockBind)
    end
    if state[field] == flag and not dropped then
        return true
    end
    state[field] = flag
    Touch()
    return true
end

function CCT.State.SetBell(on)
    return SetFlag("bell", on, "bell")
end

function CCT.State.SetTail(on)
    return SetFlag("tail", on, "tailbell")
end

function CCT.State.SetJewel(on)
    return SetFlag("jewel", on)
end

function CCT.State.SetBra(on)
    return SetFlag("bra", on, "chastitybra")
end

function CCT.State.SetPetSummoned(on)
    return SetFlag("petSummoned", on)
end

function CCT.State.SetMaid(list)
    local state = Current()
    if state == nil or type(list) ~= "table" then
        return false
    end
    local items = {}
    local source = type(list.items) == "table" and list.items or {}
    for i = 1, math.min(20, #source) do
        local copy = CopyMaidItem(source[i])
        if copy ~= nil then
            items[#items + 1] = copy
        end
    end
    local instructions = {}
    local texts = type(list.instructions) == "table" and list.instructions or {}
    for i = 1, math.min(20, #texts) do
        if type(texts[i]) == "string" then
            instructions[#instructions + 1] = texts[i]
        end
    end
    state.maid = {
        id = list.id ~= nil and tostring(list.id) or nil,
        items = items,
        instructions = instructions,
    }
    Touch()
    return true
end

function CCT.State.Maid()
    local state = Current()
    if type(state) ~= "table" or type(state.maid) ~= "table" then
        return nil
    end
    return state.maid
end

function CCT.State.SetBelt(on)
    local state = Current()
    if state == nil then
        return false
    end
    local flag = on and true or false
    local dropped = false
    if not flag then
        dropped = DropLock(state, "chastitybelt")
    end
    if state.belt == flag and (flag or state.beltMode == "allow") and not dropped then
        return true
    end
    state.belt = flag
    if not flag then
        state.beltMode = "allow"
    end
    Touch()
    return true
end

function CCT.State.SetBeltMode(mode)
    local state = Current()
    if state == nil or state.belt ~= true then
        return false
    end
    if mode ~= "allow" and mode ~= "deny" then
        return false
    end
    if state.beltMode == mode then
        return true
    end
    state.beltMode = mode
    Touch()
    return true
end

function CCT.State.SetLeash(on, owner)
    local state = Current()
    if state == nil then
        return false
    end
    local flag = on and true or false
    local short = nil
    if flag then
        short = CCT.ShortName(owner)
    end
    if state.leash == flag and state.leashOwner == short then
        return true
    end
    state.leash = flag
    state.leashOwner = short
    Touch()
    return true
end

local function ToyBlocked(state, spec)
    if spec.restrict == "belt" and state.belt == true then
        return true
    end
    if spec.restrict == "bra" and state.bra == true then
        return true
    end
    return false
end

local function ClearButplugsExcept(state, keepId)
    local changed = false
    for i = 1, #TOYS do
        local spec = TOYS[i]
        if spec.group == "butplug" and spec.id ~= keepId then
            local other = state.toys[spec.id]
            if other.applied or other.vibe ~= 0 or other.inflate ~= 0 then
                other.applied = false
                other.vibe = 0
                other.inflate = 0
                changed = true
            end
        end
    end
    return changed
end

function CCT.State.ApplyToy(id)
    local state = Current()
    local spec = toyById[id]
    if state == nil or spec == nil or ToyBlocked(state, spec) then
        return false
    end
    local changed = false
    if spec.group == "butplug" then
        changed = ClearButplugsExcept(state, id)
    end
    local toy = state.toys[id]
    if toy.applied ~= true then
        toy.applied = true
        changed = true
    end
    if not changed then
        return true
    end
    Touch()
    return true
end

function CCT.State.RemoveToy(id)
    local state = Current()
    local spec = toyById[id]
    if state == nil or spec == nil or ToyBlocked(state, spec) then
        return false
    end
    local toy = state.toys[id]
    if toy.applied ~= true and toy.vibe == 0 and toy.inflate == 0 then
        return true
    end
    toy.applied = false
    toy.vibe = 0
    toy.inflate = 0
    Touch()
    return true
end

function CCT.State.SetToyVibe(id, level)
    local state = Current()
    local spec = toyById[id]
    if state == nil or spec == nil or not spec.vibe then
        return false
    end
    if tonumber(level) == nil then
        return false
    end
    local toy = state.toys[id]
    if toy.applied ~= true then
        return false
    end
    local n = ClampInt(level, 0, 5)
    if toy.vibe == n then
        return true
    end
    toy.vibe = n
    Touch()
    return true
end

function CCT.State.SetToyInflate(id, level)
    local state = Current()
    local spec = toyById[id]
    if state == nil or spec == nil or not spec.inflate then
        return false
    end
    if tonumber(level) == nil then
        return false
    end
    local toy = state.toys[id]
    if toy.applied ~= true then
        return false
    end
    local n = ClampInt(level, 0, 5)
    if toy.inflate == n then
        return true
    end
    toy.inflate = n
    Touch()
    return true
end

function CCT.State.SetLock(bind, minutes)
    local state = Current()
    if state == nil or not lockSet[bind] then
        return false
    end
    if minutes == nil then
        if state.locks[bind] == nil then
            return true
        end
        state.locks[bind] = nil
        Touch()
        return true
    end
    if tonumber(minutes) == nil or tonumber(minutes) < 1 then
        return false
    end
    local stored = ClampInt(minutes, 1, LOCK_MINUTE_CAP)
    state.locks[bind] = {
        unlockAt = CCT.UnixNow() + stored * 60,
        minutes = stored,
    }
    Touch()
    return true
end

local function ClearWorn(state, bind)
    if bind == "gag" then
        state.gag = "none"
        state.gagStage = 0
    elseif bind == "earmuffs" then
        state.ears = "none"
    elseif bind == "blindfold" then
        state.blind = "none"
    elseif bind == "mittens" then
        state.mittens = "none"
    elseif bind == "heels" then
        state.heels = "none"
    elseif bind == "bell" then
        state.bell = false
    elseif bind == "tailbell" then
        state.tail = false
    elseif bind == "chastitybelt" then
        state.belt = false
        state.beltMode = "allow"
    elseif bind == "chastitybra" then
        state.bra = false
    end
end

function CCT.State.ExpireLock(bind)
    local state = Current()
    if state == nil or not lockSet[bind] then
        return false
    end
    if state.locks[bind] == nil then
        return false
    end
    state.locks[bind] = nil
    ClearWorn(state, bind)
    Touch()
    return true
end

function CCT.State.SetHeat(value)
    local state = Current()
    if state == nil or tonumber(value) == nil then
        return false
    end
    local heat = tonumber(value)
    if heat < 0 then heat = 0 end
    if heat > 100 then heat = 100 end
    local shown = ClampInt(heat + 0.5, 0, 100)
    local peak = state.counters.heatPeak or 0
    local peakChanged = shown > peak
    if state.heat == heat and not peakChanged then
        return true
    end
    state.heat = heat
    if peakChanged then
        state.counters.heatPeak = shown
    end
    Touch(peakChanged and "heatPeak" or nil)
    return true
end

function CCT.State.SetSub(value)
    local state = Current()
    if state == nil or tonumber(value) == nil then
        return false
    end
    local n = ClampInt((tonumber(value) or 0) + 0.5, 0, 100)
    if state.sub == n then
        return true
    end
    state.sub = n
    Touch()
    return true
end

function CCT.State.SetZone(zone, instanceType)
    local state = Current()
    if state == nil then
        return false
    end
    local nextZone = type(zone) == "string" and zone or ""
    local nextInst = type(instanceType) == "string" and instanceType ~= "" and instanceType or "none"
    if state.zone == nextZone and state.instanceType == nextInst then
        return true
    end
    state.zone = nextZone
    state.instanceType = nextInst
    Touch()
    return true
end

function CCT.State.SetPos(pos)
    local state = Current()
    if state == nil then
        return false
    end
    if pos == nil then
        if state.pos == nil then
            return true
        end
        state.pos = nil
        Touch()
        return true
    end
    if type(pos) ~= "table" or type(pos.mapID) ~= "number" or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
        return false
    end
    local nextPos = {
        mapID = pos.mapID,
        x = Round4(pos.x),
        y = Round4(pos.y),
        instanceID = type(pos.instanceID) == "number" and pos.instanceID or nil,
        t = type(pos.t) == "number" and pos.t or CCT.UnixNow(),
    }
    local cur = state.pos
    if type(cur) == "table"
        and cur.mapID == nextPos.mapID
        and cur.x == nextPos.x
        and cur.y == nextPos.y
        and cur.instanceID == nextPos.instanceID
        and cur.t == nextPos.t then
        return true
    end
    state.pos = nextPos
    Touch()
    return true
end

function CCT.State.SetWeek(id)
    local state = Current()
    if state == nil or type(id) ~= "string" or id == "" then
        return false
    end
    if state.week == id and state.counters.week == id then
        return true
    end
    state.week = id
    state.counters.week = id
    Touch()
    return true
end

function CCT.State.SetSeq(seq)
    local state = Current()
    if state == nil or tonumber(seq) == nil or tonumber(seq) < 1 then
        return false
    end
    local n = math.floor(tonumber(seq))
    if state.counters.seq == n then
        return true
    end
    state.counters.seq = n
    Touch()
    return true
end

function CCT.State.SetCounter(name, value)
    local state = Current()
    local cap = CounterCap(name)
    if state == nil or cap == nil or tonumber(value) == nil then
        return false
    end
    local n = ClampInt(value, 0, cap)
    if state.counters[name] == n then
        return true
    end
    state.counters[name] = n
    Touch(name)
    return true
end

function CCT.State.AddCounter(name, delta)
    local state = Current()
    if state == nil or CounterCap(name) == nil or tonumber(delta) == nil then
        return false
    end
    local current = tonumber(state.counters[name]) or 0
    return CCT.State.SetCounter(name, current + tonumber(delta))
end

function CCT.State.TouchClock(now)
    local state = Current()
    if state == nil then
        return false
    end
    local stamp = tonumber(now) or CCT.UnixNow()
    state.lastUnixUpdate = stamp
    return true
end

function CCT.State.OnEvent(_, event)
    if event == "PLAYER_LOGOUT" then
        CCT.State.DropSession()
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", CCT.State.OnEvent)
end
