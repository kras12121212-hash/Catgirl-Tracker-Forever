-- Collar and tail bells. Worn flags go through CCT.State.
-- A jingle waits math.random(120, 300) seconds.
-- A hidden movement sample does not start a jingle and does not stop one.
-- A non-secret sample that is not moving skips the jingle and stops one that is playing.
-- This file does not send addon messages.

local ADDON_NAME, CCT = ...

CCT.Bells = {}

local MIN_WAIT = 120
local MAX_WAIT = 300
local WATCH_INTERVAL = 0.1
local WATCH_SECONDS = 6

CCT.Bells.MIN_WAIT = MIN_WAIT
CCT.Bells.MAX_WAIT = MAX_WAIT
CCT.Bells.WATCH_INTERVAL = WATCH_INTERVAL
CCT.Bells.WATCH_SECONDS = WATCH_SECONDS

local COLLAR_TEXT = "Kitten is wearing a bell... it might ring at the wrong moment nya."
local TAIL_TEXT = "Kitten is wearing a tail bell; it will ring with every step."
local SOUND_FILE = { bell = "Bell.ogg", tail = "sbell4seconds.ogg" }
local FRAME_NAME = { bell = "CatgirlBellReminder", tail = "CatgirlTailBellReminder" }
local FRAME_OFFSET = { bell = -50, tail = -84 }

local on = { bell = false, tail = false }
local armed = { bell = false, tail = false }
local generation = { bell = 0, tail = 0 }
local handles = { bell = nil, tail = nil }
local playingUntil = { bell = 0, tail = 0 }
local reminders = { bell = nil, tail = nil }
local watchTicker = nil

local function Media(rest)
    return (CCT.MEDIA or "") .. rest
end

local function Now()
    if GetTime then
        return GetTime()
    end
    if time then
        return time()
    end
    return 0
end

function CCT.Bells.Delay()
    return math.random(120, 300)
end

function CCT.Bells.React(sample)
    if type(sample) ~= "table" or sample.kind == "hidden" then
        return "hold"
    end
    if sample.moving == true then
        return "play"
    end
    if sample.moving == false then
        return "skip"
    end
    return "hold"
end

local function Worn(which)
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return false
    end
    if which == "bell" then
        return state.bell == true
    end
    if which == "tail" then
        return state.tail == true
    end
    return false
end

local function AnyPlaying()
    return handles.bell ~= nil or handles.tail ~= nil
end

local function StopWatch()
    if watchTicker and watchTicker.Cancel then
        watchTicker:Cancel()
    end
    watchTicker = nil
end

local function StopPlaying(which)
    local handle = handles[which]
    handles[which] = nil
    playingUntil[which] = 0
    if type(handle) == "number" and type(StopSound) == "function" then
        StopSound(handle)
    end
    if not AnyPlaying() then
        StopWatch()
    end
end

local function EnsureWatch()
    if watchTicker or not AnyPlaying() then
        return
    end
    if not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    watchTicker = C_Timer.NewTicker(WATCH_INTERVAL, function()
        if not AnyPlaying() then
            StopWatch()
            return
        end
        local sample = { kind = "hidden" }
        if CCT.Move and CCT.Move.Sample then
            sample = CCT.Move.Sample()
        end
        if CCT.Bells.React(sample) == "skip" then
            StopPlaying("bell")
            StopPlaying("tail")
            return
        end
        local now = Now()
        if handles.bell ~= nil and now >= playingUntil.bell then
            handles.bell = nil
            playingUntil.bell = 0
        end
        if handles.tail ~= nil and now >= playingUntil.tail then
            handles.tail = nil
            playingUntil.tail = 0
        end
        if not AnyPlaying() then
            StopWatch()
        end
    end)
end

local function Play(which)
    local file = SOUND_FILE[which]
    if file == nil then
        return
    end
    StopPlaying(which)
    local handle = true
    if type(PlaySoundFile) == "function" then
        local first, second = PlaySoundFile(Media("Sounds\\" .. file), "Master")
        if type(first) == "number" then
            handle = first
        elseif type(second) == "number" then
            handle = second
        end
    end
    handles[which] = handle
    playingUntil[which] = Now() + WATCH_SECONDS
    EnsureWatch()
end

local function Arm(which)
    local gen = generation[which]
    if not C_Timer or type(C_Timer.After) ~= "function" then
        return
    end
    C_Timer.After(CCT.Bells.Delay(), function()
        if gen ~= generation[which] or not Worn(which) then
            return
        end
        local sample = { kind = "hidden" }
        if CCT.Move and CCT.Move.Sample then
            sample = CCT.Move.Sample()
        end
        local react = CCT.Bells.React(sample)
        if react == "play" then
            Play(which)
        elseif react == "skip" then
            StopPlaying(which)
        end
        if gen == generation[which] and Worn(which) then
            Arm(which)
        end
    end)
end

local function StartBell(which)
    if armed[which] then
        return
    end
    armed[which] = true
    generation[which] = generation[which] + 1
    Arm(which)
end

local function StopBell(which)
    generation[which] = generation[which] + 1
    armed[which] = false
    StopPlaying(which)
end

local function EnsureReminder(which)
    if reminders[which] or not CreateFrame or not UIParent then
        return reminders[which]
    end
    local frame = CreateFrame("Frame", FRAME_NAME[which], UIParent)
    frame:SetSize(400, 30)
    frame:SetPoint("TOP", UIParent, "TOP", 0, FRAME_OFFSET[which])
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    if which == "tail" then
        text:SetText(TAIL_TEXT)
    else
        text:SetText(COLLAR_TEXT)
    end
    text:SetPoint("CENTER")
    frame.text = text
    frame:Hide()
    reminders[which] = frame
    return frame
end

local function ShowReminder(which)
    local frame = EnsureReminder(which)
    if frame then
        frame:Show()
    end
end

local function HideReminder(which)
    local frame = reminders[which]
    if frame then
        frame:Hide()
    end
end

local function SyncOne(which, worn)
    if worn == on[which] then
        return
    end
    on[which] = worn
    if worn then
        ShowReminder(which)
        StartBell(which)
    else
        HideReminder(which)
        StopBell(which)
    end
end

local function Sync()
    SyncOne("bell", Worn("bell"))
    SyncOne("tail", Worn("tail"))
end

local function OwnerOk(sender)
    if not CCT.Roster or not CCT.Roster.GetOwnerShort then
        return false
    end
    local owner = CCT.Roster.GetOwnerShort()
    if owner == nil or not CCT.SameName(sender, owner) then
        return false
    end
    return true
end

function CCT.Bells.Set(sender, which, enabled)
    if not OwnerOk(sender) then
        return false
    end
    if which == "bell" or which == "collar" then
        if not CCT.State or not CCT.State.SetBell then
            return false
        end
        return CCT.State.SetBell(enabled) == true
    end
    if which == "tail" or which == "tailbell" then
        if not CCT.State or not CCT.State.SetTail then
            return false
        end
        return CCT.State.SetTail(enabled) == true
    end
    return false
end

function CCT.Bells.OnEvent(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Sync()
    end
end

if CCT.State and CCT.State.Listen then
    CCT.State.Listen(Sync)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", CCT.Bells.OnEvent)
end
