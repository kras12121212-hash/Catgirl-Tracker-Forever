-- Owner map pins for the assigned kitten's received trail.
-- The module is off until /cctmodule enables KittenMapShow.
-- No day-offset history control. Nothing is drawn without a Pos.

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

function CCT.Map.Points(mapID)
    if not Enabled() then
        return {}
    end
    local row = RowForAssigned()
    if type(row) ~= "table" or type(row.state) ~= "table" or type(row.state.pos) ~= "table" then
        return {}
    end
    local want = tonumber(mapID)
    local points = {}
    local trail = row.trail or {}
    for i = 1, #trail do
        local point = trail[i]
        if type(point) == "table" and (want == nil or point.mapID == want) then
            points[#points + 1] = point
        end
    end
    local pos = row.state.pos
    if want == nil or pos.mapID == want then
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
