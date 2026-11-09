-- Owner map pins for the assigned kitten's received trail.
-- The module is off until /cctmodule enables KittenMapShow.
-- The settings slider picks a calendar day. The stored trail is still the short cap.
-- Nothing is drawn without a Pos. Today also draws the latest position.

local ADDON_NAME, CCT = ...

CCT.Map = {}

local MARKER = "Textures\\catgirltga32.tga"
local MARKER_SIZE = 16
local pins = {}
local hooked = false

local function RowForAssigned()
    local assigned = CCT.Roster and CCT.Roster.GetAssignedKitten and CCT.Roster.GetAssignedKitten()
    if type(assigned) ~= "table" or type(assigned.short) ~= "string" then
        return nil
    end
    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    local db = CCT.db
    if type(db) ~= "table" or type(db.owner) ~= "table" or type(db.owner.kitten) ~= "table" then
        return nil
    end
    local row = db.owner.kitten[assigned.short]
    if type(row) == "table" then
        return row
    end
    for key, candidate in pairs(db.owner.kitten) do
        if CCT.SameName(key, assigned.short) then
            return candidate
        end
    end
    return nil
end

local function Enabled()
    return CCT.Module and CCT.Module.Enabled and CCT.Module.Enabled("KittenMapShow") == true
end

local function OwnerChar(create)
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" or CCT.Saved == nil then
        return nil
    end
    if create and type(CCT.Saved.EnsureChar) == "function" then
        return CCT.Saved.EnsureChar(short)
    end
    local db = CCT.db
    if type(db) ~= "table" or type(db.chars) ~= "table" then
        return nil
    end
    return db.chars[short]
end

function CCT.Map.HistoryOffset()
    local char = OwnerChar(false)
    local value = char and tonumber(char.mapHistoryOffsetDays) or 0
    if value == nil or value < 0 then
        value = 0
    end
    if value > 30 then
        value = 30
    end
    return math.floor(value + 0.5)
end

function CCT.Map.SetHistoryOffset(days)
    local value = tonumber(days) or 0
    if value < 0 then
        value = 0
    end
    if value > 30 then
        value = 30
    end
    value = math.floor(value + 0.5)
    local char = OwnerChar(true)
    if type(char) == "table" then
        char.mapHistoryOffsetDays = value
    end
    return value
end

local function DayWindow(offset)
    if type(time) ~= "function" or type(date) ~= "function" then
        return nil, nil
    end
    local now = time()
    if type(now) ~= "number" then
        return nil, nil
    end
    local day = date("*t", now - (offset * 24 * 60 * 60))
    if type(day) ~= "table" then
        return nil, nil
    end
    day.hour = 0
    day.min = 0
    day.sec = 0
    local startTime = time(day)
    if type(startTime) ~= "number" then
        return nil, nil
    end
    return startTime, startTime + (24 * 60 * 60)
end

local function OnSelectedDay(point, offset)
    local startTime, endTime = DayWindow(offset)
    if startTime == nil then
        return true
    end
    local stamp = type(point) == "table" and tonumber(point.t) or nil
    if stamp == nil then
        return offset == 0
    end
    return stamp >= startTime and stamp < endTime
end

function CCT.Map.Points(mapID)
    if not Enabled() then
        return {}
    end
    local row = RowForAssigned()
    if type(row) ~= "table" or type(row.state) ~= "table" or type(row.state.pos) ~= "table" then
        return {}
    end
    local want = tonumber(mapID)
    local offset = CCT.Map.HistoryOffset()
    local points = {}
    local trail = row.trail or {}
    for i = 1, #trail do
        local point = trail[i]
        if type(point) == "table" and (want == nil or point.mapID == want) and OnSelectedDay(point, offset) then
            points[#points + 1] = point
        end
    end
    local pos = row.state.pos
    if type(pos) == "table" and (want == nil or pos.mapID == want) and (offset == 0 or OnSelectedDay(pos, offset)) then
        points[#points + 1] = pos
    end
    return points
end

local function Supports()
    if type(CreateFrame) ~= "function" then
        return false
    end
    local probe = CreateFrame("Frame")
    if type(probe.CreateTexture) ~= "function" then
        return false
    end
    local tex = probe:CreateTexture()
    if type(tex) ~= "table" or type(tex.SetSize) ~= "function" or type(tex.SetPoint) ~= "function" then
        return false
    end
    return true
end

function CCT.Map.Marker()
    return (CCT.MEDIA or "") .. MARKER, MARKER_SIZE
end

function CCT.Map.Refresh(mapID)
    if not Supports() or WorldMapFrame == nil then
        return 0
    end
    for i = 1, #pins do
        if pins[i].Hide then
            pins[i]:Hide()
        end
    end
    local points = CCT.Map.Points(mapID)
    for i = 1, #points do
        local pin = pins[i]
        if pin == nil then
            pin = CreateFrame("Frame", nil, WorldMapFrame)
            pin:SetSize(MARKER_SIZE, MARKER_SIZE)
            local tex = pin:CreateTexture(nil, "OVERLAY")
            tex:SetSize(MARKER_SIZE, MARKER_SIZE)
            tex:SetPoint("CENTER")
            tex:SetTexture((CCT.MEDIA or "") .. MARKER)
            pin.texture = tex
            pins[i] = pin
        end
        local point = points[i]
        if pin.SetPoint then
            pin:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", (point.x or 0) * 100, -(point.y or 0) * 100)
        end
        if pin.Show then
            pin:Show()
        end
    end
    return #points
end

function CCT.Map.Hook()
    if hooked or type(hooksecurefunc) ~= "function" then
        return false
    end
    hooked = true
    return true
end
