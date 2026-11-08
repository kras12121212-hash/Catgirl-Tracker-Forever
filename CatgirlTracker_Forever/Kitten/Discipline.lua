-- Discipline actions. Too far is an Ack with ok 0, not a Prox.
-- Heat is written through CCT.Heat and CCT.State. Nothing is whispered.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Discipline = {}

local CLOSE_RANGE = 0.02

CCT.Discipline.CLOSE_RANGE = CLOSE_RANGE

local ACTIONS = {
    {
        id = "spank_hand",
        label = "Spank Hand",
        icon = "Textures/Hand.tga",
        msgKey = "SPANK_HAND",
        maxStrength = 5,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
        },
    },
    {
        id = "pinch",
        label = "Pinch",
        icon = "Textures/Hand.tga",
        msgKey = "PINCH",
        maxStrength = 3,
        parts = {
            { id = "ears", label = "Ears" },
            { id = "nipples", label = "Nipples", restrict = "bra" },
        },
    },
    {
        id = "vibrating_wand",
        label = "Vibrating Wand",
        icon = "Textures/VibratingWand.tga",
        msgKey = "VIBRATING_WAND",
        maxStrength = 3,
        parts = {
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "pussy", label = "Pussy", restrict = "belt" },
            { id = "ears", label = "Ears" },
        },
    },
    {
        id = "shock_wand",
        label = "Shock Wand",
        icon = "Textures/ShockWand.tga",
        msgKey = "SHOCK_WAND",
        maxStrength = 5,
        parts = {
            { id = "thighs", label = "Thighs" },
            { id = "paws", label = "Paws" },
            { id = "pussy", label = "Pussy", restrict = "belt" },
            { id = "belly", label = "Belly" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "nipples", label = "Nipples", restrict = "bra" },
            { id = "neck", label = "Neck" },
            { id = "ass", label = "Ass", restrict = "belt" },
        },
    },
    {
        id = "crop",
        label = "Crop",
        icon = "Textures/Crop.tga",
        msgKey = "CROP",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
        },
    },
    {
        id = "paddle",
        label = "Paddle",
        icon = "Textures/Paddle.tga",
        msgKey = "PADDLE",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "paws", label = "Paws" },
        },
    },
    {
        id = "heart_crop",
        label = "Heart Crop",
        icon = "Textures/HeartCrop.tga",
        msgKey = "HEART_CROP",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "paws", label = "Paws" },
        },
    },
    {
        id = "whip",
        label = "Whip",
        icon = "Textures/Whip.tga",
        msgKey = "WHIP",
        maxStrength = 3,
        parts = {
            { id = "butt", label = "Butt" },
            { id = "thighs", label = "Thighs" },
            { id = "tits", label = "Tits", restrict = "bra" },
            { id = "paws", label = "Paws" },
        },
    },
}

local index = {}
for i = 1, #ACTIONS do
    local action = ACTIONS[i]
    index[action.id] = action
    action.partsIndex = {}
    for j = 1, #action.parts do
        local part = action.parts[j]
        action.partsIndex[part.id] = part
    end
end

CCT.Discipline.Actions = ACTIONS

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function ParseNumber(value)
    if Secret(value) then
        return nil
    end
    if type(value) == "number" then
        return value
    end
    if type(value) ~= "string" or value == "" or value == "nil" then
        return nil
    end
    return tonumber(value)
end

local function Round4(value)
    local n = ParseNumber(value)
    if n == nil then
        return nil
    end
    return math.floor(n * 10000 + 0.5) / 10000
end

local function InstanceId()
    if type(GetInstanceInfo) ~= "function" then
        return nil
    end
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    if Secret(instanceID) then
        return nil
    end
    if type(instanceID) ~= "number" or instanceID <= 0 then
        return nil
    end
    return instanceID
end

local function Here()
    local instanceID = InstanceId()
    local mapID, x, y
    if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
        local rawMap = C_Map.GetBestMapForUnit("player")
        mapID = ParseNumber(rawMap)
        if mapID and type(C_Map.GetPlayerMapPosition) == "function" then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if Secret(pos) then
                pos = nil
            end
            if type(pos) == "table" then
                local rawX, rawY = pos.x, pos.y
                if type(pos.GetXY) == "function" then
                    rawX, rawY = pos:GetXY()
                end
                x = Round4(rawX)
                y = Round4(rawY)
            end
        end
    end
    if (x == nil or y == nil) and type(GetPlayerMapPosition) == "function" then
        local rawX, rawY = GetPlayerMapPosition("player")
        if not Secret(rawX) and not Secret(rawY) then
            local nextX = Round4(rawX)
            local nextY = Round4(rawY)
            if nextX and nextY then
                x = nextX
                y = nextY
            end
        end
    end
    return mapID, x, y, instanceID
end

function CCT.Discipline.Close(ownerMap, ownerX, ownerY, ownerInst)
    local mapID, x, y, instanceID = Here()
    local theirMap = ParseNumber(ownerMap)
    local theirX = Round4(ownerX)
    local theirY = Round4(ownerY)
    local theirInst = ParseNumber(ownerInst)
    if theirInst ~= nil and theirInst <= 0 then
        theirInst = nil
    end
    if mapID and x and y and theirMap and theirX and theirY and mapID == theirMap then
        local dx = x - theirX
        local dy = y - theirY
        local dist = math.sqrt(dx * dx + dy * dy)
        local rounded = math.floor(dist * 10000 + 0.5) / 10000
        return rounded <= CLOSE_RANGE, dist
    end
    if theirInst and instanceID and theirInst == instanceID then
        return true, nil
    end
    return false, nil
end

local function State()
    if CCT.State and CCT.State.Get then
        return CCT.State.Get()
    end
    return nil
end

local function Ack(ok, reason, fields)
    local op = "disc"
    local cid = nil
    if type(fields) == "table" then
        if type(fields.op) == "string" and fields.op ~= "" then
            op = fields.op
        end
        cid = fields.cid
    end
    return {
        ok = ok and true or false,
        reason = ok and nil or reason,
        op = op,
        cid = cid,
    }
end

local function ClampStrength(level, maxStrength)
    local cap = tonumber(maxStrength) or 1
    if cap < 1 then
        cap = 1
    end
    local num = ParseNumber(level)
    if num == nil or num < 1 then
        num = 1
    elseif num > cap then
        num = cap
    end
    return math.floor(num + 0.5)
end

local function HeatFor(actionId, strength)
    local cfg = CCT.HeatConfig
    local row = cfg and cfg.discipline and cfg.discipline[actionId]
    if type(row) ~= "table" then
        return 0
    end
    local heatTable = row.heat or row
    local value = heatTable[strength]
    if type(value) == "table" then
        value = value.heat
    end
    return tonumber(value) or 0
end

local function AddHeat(delta)
    if delta == 0 then
        return
    end
    if CCT.Heat and type(CCT.Heat.AddDelta) == "function" then
        CCT.Heat.AddDelta(delta)
        return
    end
    if CCT.State and CCT.State.SetHeat and CCT.State.Get then
        local state = CCT.State.Get()
        local heat = 0
        if type(state) == "table" then
            heat = tonumber(state.heat) or 0
        end
        CCT.State.SetHeat(heat + delta)
    end
end

local function Line(action, part, stage, blocked)
    local key
    if blocked then
        key = "DISCIPLINE_" .. action.msgKey .. "_BLOCKED_" .. blocked
    else
        key = "DISCIPLINE_" .. action.msgKey .. "_" .. tostring(stage)
    end
    if not (CCT.Messages and CCT.Messages[key]) then
        if blocked then
            key = "DISCIPLINE_BLOCKED_" .. blocked
        else
            key = "DISCIPLINE_ACTION"
        end
    end
    return CCT.Msg(key, action.label, part.label, stage)
end

local function Notify(text)
    if type(text) ~= "string" or text == "" then
        return
    end
    if print then
        print("|cffcc88ffCatgirlTracker:|r " .. text)
    end
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo.RAID_WARNING)
    end
end

function CCT.Discipline.Apply(sender, fields)
    if type(fields) ~= "table" then
        fields = {}
    end
    local id = type(fields.id) == "string" and fields.id:lower() or ""
    local action = index[id]
    if not action then
        return Ack(false, "id", fields)
    end
    local partId = type(fields.part) == "string" and fields.part:lower() or ""
    local part = action.partsIndex[partId]
    if not part then
        return Ack(false, "part", fields)
    end
    local close = CCT.Discipline.Close(fields.map, fields.x, fields.y, fields.inst)
    if not close then
        return Ack(false, "toofar", fields)
    end
    local state = State()
    if part.restrict == "belt" and type(state) == "table" and state.belt == true then
        Notify(Line(action, part, 1, "BELT"))
        return Ack(false, "belt", fields)
    end
    if part.restrict == "bra" and type(state) == "table" and state.bra == true then
        Notify(Line(action, part, 1, "BRA"))
        return Ack(false, "bra", fields)
    end
    local stage = ClampStrength(fields.str, action.maxStrength)
    AddHeat(HeatFor(action.id, stage))
    Notify(Line(action, part, stage, nil))
    if CCT.Pictures and type(CCT.Pictures.ShowDiscipline) == "function" then
        CCT.Pictures.ShowDiscipline(action.icon)
    end
    if CCT.Sounds and type(CCT.Sounds.PlayDisciplineAction) == "function" then
        CCT.Sounds.PlayDisciplineAction(action.id, stage)
    end
    return Ack(true, nil, fields)
end

if CCT.Commands and type(CCT.Commands.Register) == "function" then
    CCT.Commands.Register("disc", function(sender, fields)
        return CCT.Discipline.Apply(sender, fields)
    end)
end
