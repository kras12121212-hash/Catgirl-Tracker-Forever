-- Zone minutes use the ledger minute clock. The raw zone log is not stored.
-- A reload sets the stamp elsewhere and this delay adds nothing for that gap.

local ADDON_NAME, CCT = ...

CCT.Zone = {}

local due = nil
local token = 0

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Clean(value)
    if Secret(value) then
        return nil
    end
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

function CCT.Zone.Read()
    local zone = nil
    local blocked = false
    if type(GetRealZoneText) == "function" then
        local raw = GetRealZoneText()
        if Secret(raw) then
            blocked = true
        else
            zone = Clean(raw)
        end
    end
    if zone == nil and not blocked and type(GetZoneText) == "function" then
        local raw = GetZoneText()
        if Secret(raw) then
            blocked = true
        else
            zone = Clean(raw)
        end
    end
    local inst = nil
    if type(IsInInstance) == "function" then
        local _, kind = IsInInstance()
        if Secret(kind) then
            inst = nil
        else
            inst = Clean(kind)
        end
    end
    return zone, inst, blocked
end

function CCT.Zone.Text()
    return CCT.Zone.Read()
end

function CCT.Zone.Apply(now)
    local stamp = tonumber(now)
    if stamp == nil and type(time) == "function" then
        stamp = time()
    end
    stamp = stamp or 0
    if due == nil or stamp < due then
        return false
    end
    local zone, inst, blocked = CCT.Zone.Read()
    if blocked then
        return false
    end
    due = nil
    if zone == nil then
        return false
    end
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    local previous = ""
    if type(state) == "table" and type(state.zone) == "string" then
        previous = state.zone
    end
    if zone == previous then
        return false
    end
    if CCT.Nap and type(CCT.Nap.OnZone) == "function" then
        CCT.Nap.OnZone(stamp)
    end
    if CCT.Ledger and type(CCT.Ledger.AddMinutes) == "function" then
        CCT.Ledger.AddMinutes(stamp, previous)
    end
    if CCT.State and type(CCT.State.SetZone) == "function" then
        local nextInst = inst
        if nextInst == nil and type(state) == "table" then
            nextInst = state.instanceType
        end
        CCT.State.SetZone(zone, nextInst)
    end
    return true
end

function CCT.Zone.Schedule(now)
    token = token + 1
    local mine = token
    local stamp = tonumber(now)
    if stamp == nil and type(time) == "function" then
        stamp = time()
    end
    due = (stamp or 0) + 1
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1, function()
            if mine ~= token then
                return
            end
            local at = type(time) == "function" and time() or due
            CCT.Zone.Apply(at)
        end)
    end
    return true
end

function CCT.Zone.OnEvent(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        CCT.Zone.Schedule(type(time) == "function" and time() or nil)
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", CCT.Zone.OnEvent)
end

if C_Timer and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(1, function()
        if due ~= nil then
            CCT.Zone.Apply(type(time) == "function" and time() or nil)
        end
    end)
end
