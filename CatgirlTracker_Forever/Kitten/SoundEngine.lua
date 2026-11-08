-- Local discipline and toy sounds. A whisper body is remembered, not sent.
-- Owner-side Handle plays only after the 0.02 map check. Nothing is whispered.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

local DIR = (CCT.MEDIA or "") .. "Sounds\\discipline-sound\\"
local CLOSE_RANGE = 0.02
local VIBE_LOOP_INTERVAL = 2.5
local VIBE_PING_INTERVAL = 3.0
local UNSENT_CAP = 8

local DISCIPLINE_SOUNDS = {
    spank_hand = DIR .. "spank.wav",
    crop = DIR .. "Crop.wav",
    paddle = DIR .. "Paddle.wav",
    whip = DIR .. "Whip.wav",
    vibrating_wand = function(level)
        return DIR .. "Vibrate" .. tostring(level) .. ".wav"
    end,
    shock_wand = function(level)
        return DIR .. "Shock" .. tostring(level) .. ".wav"
    end,
}

local TOY_VIBE_SOUNDS = {
    [1] = DIR .. "Vibrate1.wav",
    [2] = DIR .. "Vibrate2.wav",
    [3] = DIR .. "Vibrate3.wav",
    [4] = DIR .. "Vibrate4.wav",
    [5] = DIR .. "Vibrate5.wav",
}

local TOY_SHOCK_SOUNDS = {
    [1] = DIR .. "Shock1.wav",
    [2] = DIR .. "Shock2.wav",
    [3] = DIR .. "Shock3.wav",
}

local TOY_INFLATE_SOUND = DIR .. "Inflate.wav"
local TOY_DEFLATE_SOUND = DIR .. "Deflate.wav"

local TOY_INFLATE_IDS = {
    inflatable_butplug = true,
    inflatable_dildo = true,
    inflatable_gag = true,
}

local engine = {}
engine.DIR = DIR
engine.CLOSE_RANGE = CLOSE_RANGE
engine.VIBE_LOOP_INTERVAL = VIBE_LOOP_INTERVAL
engine.VIBE_PING_INTERVAL = VIBE_PING_INTERVAL
engine.unsent = {}

CCT.Sounds = engine

local toyVibeLevels = {}
local localVibeLevel = 0
local localVibeHandle = nil
local localVibeTicker = nil
local vibePingTicker = nil
local vibePingLevel = 0
local remoteVibeLevel = 0
local remoteVibeHandle = nil
local remoteVibeTicker = nil

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

local function CoordText(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

function engine.Close(mapID, x, y, instanceID)
    local hereMap, hereX, hereY, hereInst = Here()
    local theirMap = ParseNumber(mapID)
    local theirX = Round4(x)
    local theirY = Round4(y)
    local theirInst = ParseNumber(instanceID)
    if theirInst ~= nil and theirInst <= 0 then
        theirInst = nil
    end
    if hereMap and hereX and hereY and theirMap and theirX and theirY and hereMap == theirMap then
        local dx = hereX - theirX
        local dy = hereY - theirY
        local dist = math.sqrt(dx * dx + dy * dy)
        local rounded = math.floor(dist * 10000 + 0.5) / 10000
        return rounded <= CLOSE_RANGE, dist
    end
    if theirInst and hereInst and theirInst == hereInst then
        return true, nil
    end
    return false, nil
end

local function Note(body)
    if type(body) ~= "string" or body == "" then
        return
    end
    local list = engine.unsent
    list[#list + 1] = body
    while #list > UNSENT_CAP do
        table.remove(list, 1)
    end
end

local function OwnerShort()
    if CCT.Roster and type(CCT.Roster.GetOwnerShort) == "function" then
        local owner = CCT.Roster.GetOwnerShort()
        if type(owner) == "string" then
            return owner
        end
    end
    return ""
end

local function PlayHandle(path)
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
    return nil
end

local function StopHandle(handle)
    if type(handle) == "number" and type(StopSound) == "function" then
        StopSound(handle)
    end
end

local function Clamp(value, minValue, maxValue)
    local num = ParseNumber(value)
    if num == nil then
        num = minValue
    end
    if num < minValue then
        num = minValue
    elseif num > maxValue then
        num = maxValue
    end
    return math.floor(num + 0.5)
end

local function DisciplinePath(actionId, strength)
    local entry = DISCIPLINE_SOUNDS[actionId]
    if entry == nil then
        return nil
    end
    if type(entry) == "function" then
        if actionId == "vibrating_wand" then
            return entry(Clamp(strength, 1, 3))
        end
        return entry(Clamp(strength, 1, 5))
    end
    return entry
end

local function PlayDisciplineLocal(actionId, strength)
    local path = DisciplinePath(actionId, strength)
    if path == nil then
        return
    end
    PlayHandle(path)
end

local function NoteDiscipline(actionId, strength)
    Note(string.format(
        "DiscSound, owner:%s, action:%s, strength:%s",
        OwnerShort(),
        tostring(actionId or ""),
        tostring(strength or 1)
    ))
end

local function NoteVibe(kind, level)
    local mapID, x, y, instanceID = Here()
    Note(string.format(
        "ToyVibeLoop%s, owner:%s, level:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
        tostring(kind),
        OwnerShort(),
        tostring(level or 0),
        CoordText(mapID),
        CoordText(x),
        CoordText(y),
        CoordText(instanceID)
    ))
end

local function NoteInflate(action)
    local mapID, x, y, instanceID = Here()
    Note(string.format(
        "ToyInflateSound, owner:%s, action:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
        OwnerShort(),
        tostring(action or ""),
        CoordText(mapID),
        CoordText(x),
        CoordText(y),
        CoordText(instanceID)
    ))
end

local function NoteShock(level)
    local mapID, x, y, instanceID = Here()
    Note(string.format(
        "ToyShockSound, owner:%s, level:%s, mapID:%s, x:%s, y:%s, instanceID:%s",
        OwnerShort(),
        tostring(level or 1),
        CoordText(mapID),
        CoordText(x),
        CoordText(y),
        CoordText(instanceID)
    ))
end

local function PlayLocalVibe()
    if localVibeLevel <= 0 then
        return
    end
    StopHandle(localVibeHandle)
    localVibeHandle = PlayHandle(TOY_VIBE_SOUNDS[localVibeLevel])
end

local function StopLocalVibe()
    if localVibeTicker and localVibeTicker.Cancel then
        localVibeTicker:Cancel()
    end
    localVibeTicker = nil
    StopHandle(localVibeHandle)
    localVibeHandle = nil
end

local function StopVibePing()
    vibePingLevel = 0
    if vibePingTicker and vibePingTicker.Cancel then
        vibePingTicker:Cancel()
    end
    vibePingTicker = nil
end

local function StartVibePing(level)
    vibePingLevel = level
    if vibePingTicker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    vibePingTicker = C_Timer.NewTicker(VIBE_PING_INTERVAL, function()
        if vibePingLevel <= 0 then
            StopVibePing()
            return
        end
        NoteVibe("Ping", vibePingLevel)
    end)
end

local function UpdateLocalVibe(level)
    if level <= 0 then
        localVibeLevel = 0
        StopLocalVibe()
        StopVibePing()
        NoteVibe("Stop", 0)
        return
    end
    localVibeLevel = level
    PlayLocalVibe()
    if not localVibeTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
        localVibeTicker = C_Timer.NewTicker(VIBE_LOOP_INTERVAL, function()
            if localVibeLevel <= 0 then
                StopLocalVibe()
                return
            end
            PlayLocalVibe()
        end)
    end
    NoteVibe("Start", localVibeLevel)
    NoteVibe("Ping", localVibeLevel)
    StartVibePing(localVibeLevel)
end

local function RecomputeLocalVibe()
    local maxLevel = 0
    for _, level in pairs(toyVibeLevels) do
        if type(level) == "number" and level > maxLevel then
            maxLevel = level
        end
    end
    if maxLevel == localVibeLevel then
        return
    end
    UpdateLocalVibe(maxLevel)
end

local function PlayRemoteVibe()
    if remoteVibeLevel <= 0 then
        return
    end
    StopHandle(remoteVibeHandle)
    remoteVibeHandle = PlayHandle(TOY_VIBE_SOUNDS[remoteVibeLevel])
end

local function StopRemoteVibe()
    if remoteVibeTicker and remoteVibeTicker.Cancel then
        remoteVibeTicker:Cancel()
    end
    remoteVibeTicker = nil
    StopHandle(remoteVibeHandle)
    remoteVibeHandle = nil
end

local function StartRemoteVibe(level)
    if level <= 0 then
        remoteVibeLevel = 0
        StopRemoteVibe()
        return
    end
    remoteVibeLevel = level
    PlayRemoteVibe()
    if not remoteVibeTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
        remoteVibeTicker = C_Timer.NewTicker(VIBE_LOOP_INTERVAL, function()
            if remoteVibeLevel <= 0 then
                StopRemoteVibe()
                return
            end
            PlayRemoteVibe()
        end)
    end
end

function engine.PlayDisciplineAction(actionId, strength)
    local stage = ParseNumber(strength) or 1
    PlayDisciplineLocal(actionId, stage)
    NoteDiscipline(actionId, stage)
end

function engine.SetToyVibeState(toyId, level)
    if type(toyId) ~= "string" or toyId == "" then
        return
    end
    toyVibeLevels[toyId] = ParseNumber(level) or 0
    RecomputeLocalVibe()
end

function engine.SyncToyVibes(states)
    if type(states) ~= "table" then
        return
    end
    for id, row in pairs(states) do
        local level = 0
        if type(row) == "table" then
            level = ParseNumber(row.vibe) or 0
        end
        toyVibeLevels[id] = level
    end
    RecomputeLocalVibe()
end

function engine.PlayToyShock(level)
    local stage = Clamp(level, 1, 3)
    PlayHandle(TOY_SHOCK_SOUNDS[stage])
    NoteShock(stage)
end

function engine.PlayToyInflateDeflate(sourceId, action)
    if not TOY_INFLATE_IDS[sourceId] then
        return
    end
    if action ~= "inflate" and action ~= "deflate" then
        return
    end
    if action == "inflate" then
        PlayHandle(TOY_INFLATE_SOUND)
    else
        PlayHandle(TOY_DEFLATE_SOUND)
    end
    NoteInflate(action)
end

local function LocalShort()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" then
        return nil
    end
    return short
end

local function ForMe(ownerField)
    local mine = LocalShort()
    if type(ownerField) ~= "string" or mine == nil then
        return false
    end
    local left = CCT.ShortName and CCT.ShortName(ownerField) or ownerField
    local right = CCT.ShortName and CCT.ShortName(mine) or mine
    if type(left) ~= "string" or type(right) ~= "string" then
        return false
    end
    return left:lower() == right:lower()
end

local function HandleDiscSound(msg)
    local owner, action, strength = msg:match("^DiscSound, owner:([^,]+), action:([^,]+), strength:([^,]+)")
    if not owner then
        return false
    end
    if not ForMe(owner) then
        return true
    end
    PlayDisciplineLocal(action, ParseNumber(strength) or 1)
    return true
end

local function HandleToyInflate(msg)
    local owner, action, mapID, x, y, instanceID = msg:match(
        "^ToyInflateSound, owner:([^,]+), action:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if not owner then
        owner, action, mapID, x, y = msg:match(
            "^ToyInflateSound, owner:([^,]+), action:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
    end
    if not owner then
        return false
    end
    if not ForMe(owner) then
        return true
    end
    local close = engine.Close(mapID, x, y, instanceID)
    if close then
        if action == "inflate" then
            PlayHandle(TOY_INFLATE_SOUND)
        elseif action == "deflate" then
            PlayHandle(TOY_DEFLATE_SOUND)
        end
    end
    return true
end

local function HandleToyShock(msg)
    local owner, level, mapID, x, y, instanceID = msg:match(
        "^ToyShockSound, owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if not owner then
        owner, level, mapID, x, y = msg:match(
            "^ToyShockSound, owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
    end
    if not owner then
        return false
    end
    if not ForMe(owner) then
        return true
    end
    local close = engine.Close(mapID, x, y, instanceID)
    if close then
        PlayHandle(TOY_SHOCK_SOUNDS[Clamp(level, 1, 3)])
    end
    return true
end

local function HandleToyVibe(msg)
    local action, owner, level, mapID, x, y, instanceID = msg:match(
        "^ToyVibeLoop(%a+), owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+), instanceID:([^,]+)"
    )
    if not owner then
        action, owner, level, mapID, x, y = msg:match(
            "^ToyVibeLoop(%a+), owner:([^,]+), level:([^,]+), mapID:([^,]+), x:([^,]+), y:([^,]+)"
        )
    end
    if not owner then
        return false
    end
    if not ForMe(owner) then
        return true
    end
    if action == "Stop" then
        remoteVibeLevel = 0
        StopRemoteVibe()
        return true
    end
    local stage = Clamp(level, 1, 5)
    local close = engine.Close(mapID, x, y, instanceID)
    if close then
        StartRemoteVibe(stage)
    else
        remoteVibeLevel = 0
        StopRemoteVibe()
    end
    return true
end

function engine.Handle(msg)
    if type(msg) ~= "string" or msg == "" then
        return false
    end
    if HandleDiscSound(msg) then
        return true
    end
    if HandleToyInflate(msg) then
        return true
    end
    if HandleToyShock(msg) then
        return true
    end
    if HandleToyVibe(msg) then
        return true
    end
    return false
end

local function SyncFromState()
    if CCT.Sounds ~= engine then
        return
    end
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return
    end
    engine.SyncToyVibes(state.toys)
end

local function OnEvent(_, event)
    if event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ENTERING_WORLD" then
        return
    end
    SyncFromState()
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", OnEvent)
end
