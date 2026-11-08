-- Toy list, butplug exclusion, and chastity restrict flags.
-- Writers go through CCT.State. Shock heat is the classic -5 / -10 / -15 table.
-- CCT.Heat.AddDelta applies that delta once the heat module exists.
-- Until then the delta is written with CCT.State.SetHeat.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Toys = {}

local CATALOG = {
    {
        id = "dildo",
        label = "Dildo",
        icon = "Textures/Dildo.tga",
        msgKey = "DILDO",
        vibe = true,
        shock = true,
        restrict = "belt",
    },
    {
        id = "inflatable_butplug",
        label = "Inflatable Butplug",
        icon = "Textures/InflatableButplug.tga",
        msgKey = "INFLATABLE_BUTPLUG",
        inflate = true,
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "inflatable_dildo",
        label = "Inflatable Dildo",
        icon = "Textures/InflatableDildo.tga",
        msgKey = "INFLATABLE_DILDO",
        inflate = true,
        restrict = "belt",
    },
    {
        id = "small_butplug",
        label = "Small Butplug",
        icon = "Textures/SmallButplug.tga",
        msgKey = "SMALL_BUTPLUG",
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "large_butplug",
        label = "Large Butplug",
        icon = "Textures/LargeButplug.tga",
        msgKey = "LARGE_BUTPLUG",
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "taill_butplug",
        label = "Taill Butplug",
        icon = "Textures/TaillButplug.tga",
        msgKey = "TAILL_BUTPLUG",
        group = "butplug",
        restrict = "belt",
    },
    {
        id = "vibes_pussy",
        label = "Vibes Pussy",
        icon = "Textures/Vibes.tga",
        msgKey = "VIBES_PUSSY",
        vibe = true,
        restrict = "belt",
    },
    {
        id = "vibes_nipples",
        label = "Vibes Nipples",
        icon = "Textures/Vibes.tga",
        msgKey = "VIBES_NIPPLES",
        vibe = true,
        restrict = "bra",
    },
    {
        id = "vibes_ears",
        label = "Vibes Ears",
        icon = "Textures/Vibes.tga",
        msgKey = "VIBES_EARS",
        vibe = true,
        shock = true,
    },
    {
        id = "nipple_piercings",
        label = "Nipple Piercings",
        icon = "Textures/Piercings.tga",
        msgKey = "NIPPLE_PIERCINGS",
        vibe = true,
        shock = true,
        restrict = "bra",
    },
    {
        id = "ear_piercings",
        label = "Ear Piercings",
        icon = "Textures/Piercings.tga",
        msgKey = "EAR_PIERCINGS",
        vibe = true,
        shock = true,
    },
    {
        id = "pussy_lipps_piercings",
        label = "Pussy Lipps Piercings",
        icon = "Textures/Piercings.tga",
        msgKey = "PUSSY_LIPPS_PIERCINGS",
        vibe = true,
        shock = true,
        restrict = "belt",
    },
}

local FALLBACK_SHOCK = { -5, -10, -15 }

local byId = {}
for i = 1, #CATALOG do
    byId[CATALOG[i].id] = CATALOG[i]
end

CCT.Toys.List = CATALOG

local function Whisper(target, text)
    if type(target) ~= "string" or target == "" or type(text) ~= "string" or text == "" then
        return
    end
    if CCT.Chat and CCT.Chat.Send then
        CCT.Chat.Send(text, "WHISPER", nil, target, { raw = true })
    end
end

local function Raid(text)
    if type(text) ~= "string" or text == "" then
        return
    end
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo.RAID_WARNING)
    end
end

local function Say(text)
    if print and text then
        print(text)
    end
end

local function Notify(text)
    Say("|cffcc88ffCatgirlTracker:|r " .. text)
    Raid(text)
end

local function State()
    if CCT.State and CCT.State.Get then
        return CCT.State.Get()
    end
    return nil
end

local function Row(id)
    local state = State()
    if type(state) ~= "table" or type(state.toys) ~= "table" then
        return nil
    end
    return state.toys[id]
end

function CCT.Toys.Find(id)
    if type(id) ~= "string" then
        return nil
    end
    return byId[id]
end

function CCT.Toys.Icon(id)
    local toy = byId[id]
    if toy == nil or type(toy.icon) ~= "string" then
        return nil
    end
    local rest = toy.icon:gsub("/", "\\")
    return (CCT.MEDIA or "") .. rest
end

local function MessageKey(toy, suffix)
    return "TOY_" .. toy.msgKey .. "_" .. suffix
end

local function WhisperKey(sender, key, fallback, ...)
    if CCT.Messages and CCT.Messages[key] then
        Whisper(sender, CCT.Msg(key))
        return
    end
    if fallback then
        Whisper(sender, CCT.Msg(fallback, ...))
    end
end

local function ClampStage(level, maxStage)
    local num = tonumber(level) or 0
    if num < 1 then
        num = 1
    elseif num > maxStage then
        num = maxStage
    end
    return math.floor(num + 0.5)
end

local function BlockReason(toy)
    local state = State()
    if type(state) ~= "table" then
        return "state"
    end
    if toy.restrict == "belt" and state.belt == true then
        return "belt"
    end
    if toy.restrict == "bra" and state.bra == true then
        return "bra"
    end
    return nil
end

local function TellBlocked(sender, toy, reason)
    local key = reason == "bra" and "TOY_BLOCKED_BRA" or "TOY_BLOCKED_BELT"
    Whisper(sender, CCT.Msg(key, toy.label))
end

function CCT.Toys.ShockHeat(id, level)
    local toys = nil
    if type(CCT.HeatConfig) == "table" and type(CCT.HeatConfig.toys) == "table" then
        toys = CCT.HeatConfig.toys
    elseif CCT.Heat and type(CCT.Heat.Config) == "table" and type(CCT.Heat.Config.toys) == "table" then
        toys = CCT.Heat.Config.toys
    end
    local row = toys and toys[id]
    local shock = row and row.shock
    local value = shock and shock[level]
    if type(value) == "table" then
        value = value.heat
    end
    if tonumber(value) then
        return tonumber(value)
    end
    return FALLBACK_SHOCK[level] or 0
end

local function AddHeat(delta)
    if delta == 0 then
        return
    end
    if CCT.Heat and type(CCT.Heat.AddDelta) == "function" then
        CCT.Heat.AddDelta(delta)
        return
    end
    local state = State()
    if type(state) ~= "table" or not CCT.State.SetHeat then
        return
    end
    CCT.State.SetHeat((tonumber(state.heat) or 0) + delta)
end

local function SoundCall(name, ...)
    local sounds = CCT.Sounds
    if type(sounds) == "table" and type(sounds[name]) == "function" then
        sounds[name](...)
    end
end

local function AppliedButplugsExcept(id)
    local list = {}
    local state = State()
    if type(state) ~= "table" or type(state.toys) ~= "table" then
        return list
    end
    for i = 1, #CATALOG do
        local other = CATALOG[i]
        if other.group == "butplug" and other.id ~= id then
            local row = state.toys[other.id]
            if type(row) == "table" and row.applied == true then
                list[#list + 1] = other
            end
        end
    end
    return list
end

local function RequireApplied(toy, sender)
    local row = Row(toy.id)
    if type(row) == "table" and row.applied == true then
        return true
    end
    Whisper(sender, CCT.Msg("TOY_NOT_APPLIED", toy.label))
    return false
end

local function Apply(toy, sender)
    local reason = BlockReason(toy)
    if reason then
        if reason == "belt" or reason == "bra" then
            TellBlocked(sender, toy, reason)
        end
        return false, reason
    end
    local cleared = {}
    if toy.group == "butplug" then
        cleared = AppliedButplugsExcept(toy.id)
    end
    local before = Row(toy.id)
    local wasApplied = type(before) == "table" and before.applied == true
    if not CCT.State.ApplyToy(toy.id) then
        return false, BlockReason(toy) or "state"
    end
    local inflated = false
    if toy.inflate then
        local row = Row(toy.id)
        if type(row) == "table" and (tonumber(row.inflate) or 0) < 1 then
            CCT.State.SetToyInflate(toy.id, 1)
            SoundCall("PlayToyInflateDeflate", toy.id, "inflate")
            inflated = true
        end
    end
    if wasApplied and #cleared == 0 and not inflated then
        return true, nil, true
    end
    for i = 1, #cleared do
        local other = cleared[i]
        if other.vibe then
            SoundCall("SetToyVibeState", other.id, 0)
        end
        Notify("Toy removed: " .. other.label .. ".")
    end
    WhisperKey(sender, MessageKey(toy, "APPLY"), "TOY_APPLY", toy.label)
    Notify("Toy applied: " .. toy.label .. ".")
    return true
end

local function Remove(toy, sender)
    local reason = BlockReason(toy)
    if reason then
        if reason == "belt" or reason == "bra" then
            TellBlocked(sender, toy, reason)
        end
        return false, reason
    end
    local row = Row(toy.id)
    if type(row) ~= "table" then
        return false, "state"
    end
    if row.applied ~= true and (tonumber(row.vibe) or 0) == 0 and (tonumber(row.inflate) or 0) == 0 then
        return true, nil, true
    end
    if not CCT.State.RemoveToy(toy.id) then
        return false, BlockReason(toy) or "state"
    end
    if toy.vibe then
        SoundCall("SetToyVibeState", toy.id, 0)
    end
    WhisperKey(sender, MessageKey(toy, "REMOVE"), "TOY_REMOVE", toy.label)
    Notify("Toy removed: " .. toy.label .. ".")
    return true
end

local function Vibe(toy, level, sender)
    if not toy.vibe then
        return false, "vibe"
    end
    if not RequireApplied(toy, sender) then
        return false, "applied"
    end
    local stage = ClampStage(level, 5)
    local row = Row(toy.id)
    if type(row) == "table" and row.vibe == stage then
        return true, nil, true
    end
    if not CCT.State.SetToyVibe(toy.id, stage) then
        return false, "vibe"
    end
    SoundCall("SetToyVibeState", toy.id, stage)
    WhisperKey(sender, MessageKey(toy, "VIBE_" .. stage), "TOY_VIBE_SET", toy.label, stage)
    Notify(string.format("%s vibration set to %d.", toy.label, stage))
    return true
end

local function Inflate(toy, sender, direction)
    if not toy.inflate then
        return false, "inflate"
    end
    if not RequireApplied(toy, sender) then
        return false, "applied"
    end
    local row = Row(toy.id)
    if type(row) ~= "table" then
        return false, "state"
    end
    local current = tonumber(row.inflate) or 0
    local nextStage = current + (direction == "deflate" and -1 or 1)
    nextStage = ClampStage(nextStage, 5)
    if nextStage == current then
        return true, nil, true
    end
    if not CCT.State.SetToyInflate(toy.id, nextStage) then
        return false, "inflate"
    end
    local soundDir = nextStage > current and "inflate" or "deflate"
    SoundCall("PlayToyInflateDeflate", toy.id, soundDir)
    local suffix = (direction == "deflate" and "DEFLATE_" or "INFLATE_") .. nextStage
    local fallback = direction == "deflate" and "TOY_DEFLATE_SET" or "TOY_INFLATE_SET"
    WhisperKey(sender, MessageKey(toy, suffix), fallback, toy.label, nextStage)
    Notify(string.format("%s inflation stage %d.", toy.label, nextStage))
    return true
end

local function Shock(toy, level, sender)
    if not toy.shock then
        return false, "shock"
    end
    if not RequireApplied(toy, sender) then
        return false, "applied"
    end
    local stage = ClampStage(level, 3)
    AddHeat(CCT.Toys.ShockHeat(toy.id, stage))
    SoundCall("PlayToyShock", stage)
    WhisperKey(sender, MessageKey(toy, "SHOCK_" .. stage), "TOY_SHOCK", toy.label, stage)
    Notify(string.format("%s shock intensity %d.", toy.label, stage))
    return true
end

function CCT.Toys.Handle(id, action, level, sender)
    local toy = byId[id]
    if toy == nil then
        return false, "id"
    end
    if action == "apply" then
        return Apply(toy, sender)
    end
    if action == "remove" then
        return Remove(toy, sender)
    end
    if action == "vibe" then
        return Vibe(toy, level, sender)
    end
    if action == "inflate" then
        return Inflate(toy, sender, "inflate")
    end
    if action == "deflate" then
        return Inflate(toy, sender, "deflate")
    end
    if action == "shock" then
        return Shock(toy, level, sender)
    end
    return false, "action"
end
