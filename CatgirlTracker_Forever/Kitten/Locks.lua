-- Lock timers. A bind key expires through CCT.State.ExpireLock.
-- The 1-second ticker and the login pass both use that setter.
-- Turning the bind off clears its lock without these expiry lines.
-- Offline time does not add worn minutes. An expired lock is removed once.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Locks = {}

local TICK = 1

CCT.Locks.TICK = TICK

-- Same player-facing lines the classic removal and the lock ticker printed.
-- The blindfold system line was a placeholder and is not repeated.
local LINES = {
    gag = {
        system = "|cffffff00[System]:|r Your gag has been automatically removed nya~",
        lock = "|cffffff00[System]:|r Your gag lock has expired!",
        raid = "Gag removed (timer expired).",
    },
    earmuffs = {
        system = "Earmuffs removed",
        lock = "|cff88ccff[System]:|r Your earmuffs were removed as the timer expired.",
        raid = "Earmuffs removed (timer expired).",
    },
    blindfold = {
        lock = "|cffff99ff[System]:|r The blindfold timer ended. You can see again!",
        raid = "Blindfold removed (timer expired).",
    },
    bell = {
        system = "|cffffff00[System]:|r Your bell has been automatically removed nya~",
        lock = "|cffffcc00[System]:|r The bell fell off as the time ran out.",
        raid = "Bell removed (timer expired).",
    },
    tailbell = {
        system = "|cffffff00[System]:|r Your tail bell has been automatically removed nya~",
        lock = "|cffffcc00[System]:|r The tail bell fell off as the time ran out.",
        raid = "Tail bell removed (timer expired).",
    },
    mittens = {
        system = "|cffffff00[System]:|r Your paw mittens lock has expired!",
        lock = "|cffffff00[System]:|r The paw mittens lock timer ended.",
        raid = "Paw mittens removed (timer expired).",
    },
    heels = {
        system = "|cffffff00[System]:|r Your heel lock has expired!",
        lock = "|cffffff00[System]:|r The heel lock timer ended.",
        raid = "Heels removed (timer expired).",
    },
    chastitybelt = {
        system = "|cffffff00[System]:|r Your chastity belt has been automatically removed nya~",
        lock = "|cffffff00[System]:|r The chastity belt timer ended.",
        raid = "Chastity belt removed (timer expired).",
    },
    chastitybra = {
        system = "|cffffff00[System]:|r Your chastity bra has been automatically removed nya~",
        lock = "|cffffff00[System]:|r The chastity bra timer ended.",
        raid = "Chastity bra removed (timer expired).",
    },
}

local function Say(text)
    if print and text then
        print(text)
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

local function Known(bind)
    local list = CCT.State and CCT.State.LockBinds
    if type(bind) ~= "string" or type(list) ~= "table" then
        return false
    end
    for i = 1, #list do
        if list[i] == bind then
            return true
        end
    end
    return false
end

function CCT.Locks.Set(bind, minutes)
    if not Known(bind) then
        return false, "bind"
    end
    if not CCT.State or not CCT.State.SetLock then
        return false, "state"
    end
    if not CCT.State.SetLock(bind, minutes) then
        return false, "minutes"
    end
    return true
end

function CCT.Locks.Expire(bind)
    if not Known(bind) then
        return false
    end
    if not CCT.State or not CCT.State.ExpireLock then
        return false
    end
    if not CCT.State.ExpireLock(bind) then
        return false
    end
    local lines = LINES[bind]
    if lines then
        Say(lines.system)
        Raid(lines.raid)
        Say(lines.lock)
    end
    return true
end

function CCT.Locks.Sweep(now)
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" or type(state.locks) ~= "table" then
        return 0
    end
    local stamp = tonumber(now) or CCT.UnixNow()
    local due = {}
    for bind, lock in pairs(state.locks) do
        local unlockAt = type(lock) == "table" and tonumber(lock.unlockAt) or nil
        if unlockAt ~= nil and unlockAt <= stamp then
            due[#due + 1] = bind
        end
    end
    table.sort(due)
    local fired = 0
    for i = 1, #due do
        if CCT.Locks.Expire(due[i]) then
            fired = fired + 1
        end
    end
    return fired
end

local function Tick()
    CCT.Locks.Sweep(CCT.UnixNow())
    if CCT.Commands and CCT.Commands.Flush then
        CCT.Commands.Flush(CCT.UnixNow())
    end
end

function CCT.Locks.OnEvent(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CCT.Locks.Sweep(CCT.UnixNow())
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", CCT.Locks.OnEvent)
end

if C_Timer and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(TICK, Tick)
end
