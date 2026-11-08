-- Jewel samples. The map read and the secret check live in Report.Here.
-- This clock is the 20-second sample. The master does not get Pos.

local ADDON_NAME, CCT = ...

CCT.Location = {}

local GAP = 20
local due = nil

function CCT.Location.Tick(now)
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" or state.jewel ~= true then
        due = nil
        return false
    end
    local stamp = tonumber(now) or 0
    if due == nil then
        due = stamp + GAP
        return false
    end
    if stamp < due then
        return false
    end
    due = stamp + GAP
    if CCT.Report == nil or type(CCT.Report.SamplePos) ~= "function" then
        return false
    end
    return CCT.Report.SamplePos(stamp) and true or false
end

function CCT.Location.Reset(now)
    due = nil
    if now ~= nil then
        due = (tonumber(now) or 0) + GAP
    end
end
