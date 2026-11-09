-- Owner map pins for the assigned kitten's received trail.
-- The module is off until /cctmodule enables KittenMapShow.
-- The kitten keeps about 30 days: one point about every minute while the jewel is on,
-- plus a point when the map changes. The settings slider picks one of those days.
-- Hover a pin for the time. Today also draws the latest position.
-- Pins sit on the open world-map canvas. A 100 pixel box is not the map.

local ADDON_NAME, CCT = ...

CCT.Map = {}

local MARKER = "Textures\\catgirltga32.tga"
local MARKER_SIZE = 16
local pins = {}
local overlay = nil
local hooked = false
local watch = nil

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

function CCT.Map.When(point)
    if type(point) ~= "table" or type(date) ~= "function" then
        return nil
    end
    local stamp = tonumber(point.t)
    if stamp == nil then
        return nil
    end
    stamp = math.floor(stamp)
    -- A session clock formats as 1970. Show the calendar time instead.
    if stamp < 1000000000 and type(time) == "function" then
        local now = time()
        if type(now) == "number" and now >= 1000000000 then
            stamp = math.floor(now)
        else
            return nil
        end
    end
    local text = date("%Y-%m-%d %H:%M", stamp)
    if type(text) ~= "string" then
        return nil
    end
    local untilAt = tonumber(point.untilAt)
    if untilAt ~= nil then
        untilAt = math.floor(untilAt)
    end
    if untilAt ~= nil and untilAt >= stamp + 60 then
        local endText
        if date("%Y-%m-%d", stamp) == date("%Y-%m-%d", untilAt) then
            endText = date("%H:%M", untilAt)
        else
            endText = date("%Y-%m-%d %H:%M", untilAt)
        end
        if type(endText) == "string" then
            text = text .. " to " .. endText
        end
    end
    return text
end

function CCT.Map.Grouped(points)
    local groups = {}
    local order = {}
    if type(points) ~= "table" then
        return order
    end
    for i = 1, #points do
        local point = points[i]
        local x = type(point) == "table" and tonumber(point.x) or nil
        local y = type(point) == "table" and tonumber(point.y) or nil
        if x ~= nil and y ~= nil then
            local key = string.format("%.4f:%.4f", x, y)
            local group = groups[key]
            local stamp = tonumber(point.t)
            if group == nil then
                group = {
                    mapID = point.mapID,
                    x = x,
                    y = y,
                    t = stamp,
                    untilAt = stamp,
                }
                groups[key] = group
                order[#order + 1] = group
            elseif stamp ~= nil then
                if group.t == nil or stamp < group.t then
                    group.t = stamp
                end
                if group.untilAt == nil or stamp > group.untilAt then
                    group.untilAt = stamp
                end
            end
        end
    end
    return order
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

local function PlainNumber(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then
        return nil
    end
    if type(value) ~= "number" then
        return nil
    end
    return value
end

function CCT.Map.Marker()
    return (CCT.MEDIA or "") .. MARKER, MARKER_SIZE
end

function CCT.Map.PinOffset(x, y, width, height)
    local px = tonumber(x) or 0
    local py = tonumber(y) or 0
    local wide = tonumber(width) or 0
    local high = tonumber(height) or 0
    return px * wide, -(py * high)
end

local function VecXY(value)
    if value == nil or (type(issecretvalue) == "function" and issecretvalue(value)) then
        return nil
    end
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return nil
    end
    local x, y = value.x, value.y
    if type(value.GetXY) == "function" then
        x, y = value:GetXY()
    end
    x = PlainNumber(x)
    y = PlainNumber(y)
    if x == nil or y == nil then
        return nil
    end
    return x, y
end

local function Project(point, mapID)
    local x = tonumber(point.x)
    local y = tonumber(point.y)
    if x == nil or y == nil or x < 0 or x > 1 or y < 0 or y > 1 then
        return nil
    end
    if mapID == nil or point.mapID == nil or point.mapID == mapID then
        return x, y
    end
    if C_Map == nil or type(C_Map.GetWorldPosFromMapPos) ~= "function" or type(C_Map.GetMapPosFromWorldPos) ~= "function" or type(CreateVector2D) ~= "function" then
        return nil
    end
    local ok, first, second = pcall(C_Map.GetWorldPosFromMapPos, point.mapID, CreateVector2D(x, y))
    if not ok or (first == nil and second == nil) then
        return nil
    end
    local worldPos = first
    local continentID = second
    if type(first) == "number" then
        continentID = first
        worldPos = second
    end
    if worldPos == nil then
        return nil
    end
    local placed, third, fourth = pcall(C_Map.GetMapPosFromWorldPos, continentID or mapID, worldPos, mapID)
    if not placed then
        return nil
    end
    local mapPos = fourth or third
    if type(third) == "number" then
        mapPos = fourth
    end
    local px, py = VecXY(mapPos)
    if px == nil or py == nil or px < 0 or px > 1 or py < 0 or py > 1 then
        return nil
    end
    return px, py
end

local function Canvas()
    if WorldMapFrame == nil then
        return nil
    end
    local scroll = WorldMapFrame.ScrollContainer
    if type(scroll) == "table" then
        if scroll.Child ~= nil then
            return scroll.Child
        end
        if type(scroll.GetCanvas) == "function" then
            local canvas = scroll:GetCanvas()
            if canvas ~= nil then
                return canvas
            end
        end
    end
    return WorldMapFrame
end

local function CurrentMap()
    if WorldMapFrame == nil then
        return nil
    end
    if type(WorldMapFrame.GetMapID) == "function" then
        local id = PlainNumber(WorldMapFrame:GetMapID())
        if id ~= nil then
            return id
        end
    end
    return PlainNumber(WorldMapFrame.mapID)
end

local function MapShown()
    return WorldMapFrame ~= nil and type(WorldMapFrame.IsShown) == "function" and WorldMapFrame:IsShown() == true
end

local function SamePlace(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end
    return a.mapID == b.mapID and tonumber(a.x) == tonumber(b.x) and tonumber(a.y) == tonumber(b.y)
end

local function ShowWhen(pin)
    local text = pin and pin.when
    if type(text) ~= "string" or text == "" or GameTooltip == nil then
        return
    end
    if GameTooltip.SetOwner then
        GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    end
    if GameTooltip.ClearLines then
        GameTooltip:ClearLines()
    end
    if GameTooltip.AddLine then
        GameTooltip:AddLine(text, 1, 0.82, 0)
    end
    if GameTooltip.Show then
        GameTooltip:Show()
    end
end

local function HideWhen()
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

local function BindPin(pin)
    if pin == nil or pin.bound or type(pin.SetScript) ~= "function" then
        return
    end
    pin.bound = true
    if pin.EnableMouse then
        pin:EnableMouse(true)
    end
    pin:SetScript("OnEnter", function(self)
        ShowWhen(self)
    end)
    pin:SetScript("OnLeave", function()
        HideWhen()
    end)
end

local function HidePins()
    for i = 1, #pins do
        if pins[i].Hide then
            pins[i]:Hide()
        end
    end
    if overlay and overlay.Hide then
        overlay:Hide()
    end
end

local function EnsureOverlay(canvas)
    if overlay and overlay.GetParent and overlay:GetParent() == canvas then
        return overlay
    end
    if overlay and overlay.Hide then
        overlay:Hide()
    end
    overlay = CreateFrame("Frame", nil, canvas)
    pins = {}
    if overlay.SetAllPoints then
        overlay:SetAllPoints(canvas)
    end
    if overlay.EnableMouse then
        overlay:EnableMouse(false)
    end
    if overlay.SetFrameStrata then
        overlay:SetFrameStrata("HIGH")
    end
    if overlay.SetFrameLevel and type(canvas.GetFrameLevel) == "function" then
        local level = PlainNumber(canvas:GetFrameLevel())
        if level ~= nil then
            overlay:SetFrameLevel(level + 5)
        end
    end
    return overlay
end

local function StopWatch()
    if watch and watch.Cancel then
        watch:Cancel()
    end
    watch = nil
end

function CCT.Map.Refresh(mapID)
    if not Supports() or not MapShown() then
        HidePins()
        return 0
    end
    local canvas = Canvas()
    if canvas == nil or type(canvas.GetWidth) ~= "function" or type(canvas.GetHeight) ~= "function" then
        HidePins()
        return 0
    end
    local width = PlainNumber(canvas:GetWidth())
    local height = PlainNumber(canvas:GetHeight())
    if width == nil or height == nil or width <= 0 or height <= 0 then
        HidePins()
        return 0
    end
    local openID = CurrentMap()
    if openID ~= nil then
        mapID = openID
    end
    if mapID == nil then
        HidePins()
        return 0
    end
    local layer = EnsureOverlay(canvas)
    if layer == nil then
        return 0
    end
    if layer.Show then
        layer:Show()
    end
    for i = 1, #pins do
        if pins[i].Hide then
            pins[i]:Hide()
        end
    end
    local points = CCT.Map.Grouped(CCT.Map.Points(mapID))
    local live = nil
    local row = RowForAssigned()
    if type(row) == "table" and type(row.state) == "table" then
        live = row.state.pos
    end
    local drawn = 0
    for i = 1, #points do
        local point = points[i]
        local x, y = Project(point, mapID)
        if x ~= nil then
            drawn = drawn + 1
            local pin = pins[drawn]
            if pin == nil then
                pin = CreateFrame("Frame", nil, layer)
                pin:SetSize(MARKER_SIZE, MARKER_SIZE)
                local tex = pin:CreateTexture(nil, "OVERLAY")
                tex:SetSize(MARKER_SIZE, MARKER_SIZE)
                tex:SetPoint("CENTER")
                tex:SetTexture((CCT.MEDIA or "") .. MARKER)
                pin.texture = tex
                pins[drawn] = pin
                BindPin(pin)
            end
            pin.when = CCT.Map.When(point) or ""
            local bright = CCT.Map.HistoryOffset() == 0 and SamePlace(point, live)
            if pin.texture and pin.texture.SetAlpha then
                pin.texture:SetAlpha(bright and 0.95 or 0.55)
            end
            if pin.ClearAllPoints then
                pin:ClearAllPoints()
            end
            local ox, oy = CCT.Map.PinOffset(x, y, width, height)
            if pin.SetPoint then
                pin:SetPoint("CENTER", layer, "TOPLEFT", ox, oy)
            end
            if pin.Show then
                pin:Show()
            end
        end
    end
    if drawn == 0 and layer.Hide then
        layer:Hide()
    end
    return drawn
end

local function StartWatch()
    if watch or C_Timer == nil or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    watch = C_Timer.NewTicker(1, function()
        if not MapShown() then
            StopWatch()
            HidePins()
            return
        end
        CCT.Map.Refresh()
    end)
end

function CCT.Map.Hook()
    if hooked or WorldMapFrame == nil or type(WorldMapFrame.HookScript) ~= "function" then
        return false
    end
    hooked = true
    WorldMapFrame:HookScript("OnShow", function()
        StartWatch()
        CCT.Map.Refresh()
    end)
    WorldMapFrame:HookScript("OnHide", function()
        StopWatch()
        HidePins()
    end)
    if MapShown() then
        StartWatch()
        CCT.Map.Refresh()
    end
    return true
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, event, name)
        if event == "ADDON_LOADED" and name ~= "Blizzard_WorldMap" then
            return
        end
        CCT.Map.Hook()
    end)
end
