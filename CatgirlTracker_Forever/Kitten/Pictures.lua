-- Pictures from current state. A popup lasts 5 seconds. Removal does not pop.
-- The popup hides itself. It does not wait on the net pump.
-- The binds strip is derived, not a growing log. The ring holds 30 entries.
-- A timed bind shows the minutes left under its icon. The icons have a gap.
-- This file does not send addon messages.

local ADDON_NAME, CCT = ...

CCT.Pictures = {}

local POPUP_SIZE = 232
local DISCIPLINE_SIZE = 64
local BIND_SIZE = 40
local BIND_GAP = 8
local LABEL_HEIGHT = 14
local SHOW_SECONDS = 5
local RING_CAP = 30

local popup = nil
local strip = nil
local ready = nil
local baseline = nil
local listening = false
local showing = nil
local hideAt = nil
local countdown = nil

local function Clock(passed)
    if type(GetTime) == "function" then
        return GetTime()
    end
    if tonumber(passed) ~= nil then
        return tonumber(passed)
    end
    return CCT.UnixNow()
end

local function Icon(fileName)
    if type(fileName) ~= "string" or fileName == "" then
        return nil
    end
    if fileName:find("[/\\]") then
        return (CCT.MEDIA or "") .. fileName:gsub("/", "\\")
    end
    return (CCT.MEDIA or "") .. "Textures\\cgcc\\" .. fileName
end

local function ToyIcon(id)
    local list = CCT.Toys and CCT.Toys.List or {}
    for i = 1, #list do
        if list[i].id == id then
            return list[i].icon
        end
    end
    return nil
end

local function CollectRows(state)
    local rows = {}
    if type(state) ~= "table" then
        return rows
    end
    local function add(fileName, bind)
        local path = Icon(fileName)
        if path then
            rows[#rows + 1] = { icon = path, bind = bind }
        end
    end
    if state.gag == "huge" then
        add("Heavy-gag-232-with-bg_ergebnis.tga", "gag")
    elseif state.gag == "small" then
        add("small-gag-232-with-bg_ergebnis.tga", "gag")
    elseif state.gag == "full" then
        add("kitty-mask-with-gag-232-with-bg_ergebnis.tga", "gag")
    elseif state.gag == "nyamask" then
        add("cute-kitty-mask-232-with-bg_ergebnis.tga", "gag")
    elseif state.gag == "inflatable" then
        add("Inflatable-gag-232-with-bg_ergebnis.tga", "gag")
    end
    if state.blind == "light" then
        add("Light-Blindfold-232-with-bg_ergebnis.tga", "blindfold")
    elseif state.blind == "mask" then
        add("Cute-Kitty-Blindfold-232-with-bg_ergebnis.tga", "blindfold")
    elseif state.blind == "full" then
        add("Heavy-Blindfold-232-with-bg_ergebnis.tga", "blindfold")
    end
    if state.ears == "kitten" then
        add("Kitten-Earmuffs-bg_ergebnis.tga", "earmuffs")
    elseif state.ears == "heavy" then
        add("Heav-Earmuffs-bg_ergebnis.tga", "earmuffs")
    end
    if state.mittens == "locked" or state.mittens == "heavy" then
        add("locking-paw-mitten-232-with-bg_ergebnis.tga", "mittens")
    elseif state.mittens == "squeaking" then
        add("paw-mitten-232-with-bg_ergebnis.tga", "mittens")
    end
    if state.heels == "maid" then
        add("maid-heell-232-with-bg_ergebnis.tga", "heels")
    elseif state.heels == "high" then
        add("heell-232-with-bg_ergebnis.tga", "heels")
    elseif state.heels == "ballet" then
        add("balletheel-232-with-bg_ergebnis.tga", "heels")
    end
    if state.bell == true then
        add("bell-232-with-bg_ergebnis.tga", "bell")
    end
    if state.tail == true then
        add("tail-bell-232-with-bg_ergebnis.tga", "tailbell")
    end
    if state.jewel == true then
        add("jewel-232-with-bg_ergebnis.tga", nil)
    end
    if state.belt == true then
        add("Chastitybelt.tga", "chastitybelt")
    end
    if state.bra == true then
        add("chastitybra.tga", "chastitybra")
    end
    local toys = state.toys or {}
    local list = CCT.State and CCT.State.Toys or {}
    for i = 1, #list do
        local row = toys[list[i].id]
        if type(row) == "table" and row.applied == true then
            add(ToyIcon(list[i].id), nil)
        end
    end
    if state.leash == true then
        add("leash-232-with-gb_ergebnis.tga", nil)
    end
    return rows
end

local function RowIcons(rows)
    local icons = {}
    for i = 1, #rows do
        icons[i] = rows[i].icon
    end
    return icons
end

local function Now()
    if CCT.UnixNow then
        return CCT.UnixNow()
    end
    if type(time) == "function" then
        return time()
    end
    return 0
end

local function Remaining(state, bind)
    if type(bind) ~= "string" or type(state) ~= "table" or type(state.locks) ~= "table" then
        return nil
    end
    local lock = state.locks[bind]
    local unlockAt = type(lock) == "table" and tonumber(lock.unlockAt) or nil
    if unlockAt == nil then
        return nil
    end
    local left = math.floor(unlockAt - Now())
    if left < 1 then
        return nil
    end
    return left
end

local function TimeText(state, bind)
    local left = Remaining(state, bind)
    if left == nil then
        return nil
    end
    local minutes = math.floor(left / 60)
    local hours = math.floor(minutes / 60)
    if hours > 0 then
        return string.format("%dh%dm", hours, minutes % 60)
    end
    if minutes > 0 then
        return string.format("%dm", minutes)
    end
    return string.format("%ds", left)
end

function CCT.Pictures.Icons(state)
    return RowIcons(CollectRows(state))
end

function CCT.Pictures.Times(state)
    state = state or (CCT.State and CCT.State.Get and CCT.State.Get())
    local rows = CollectRows(state)
    local labels = {}
    for i = 1, #rows do
        labels[i] = TimeText(state, rows[i].bind)
    end
    return labels
end

function CCT.Pictures.IconStep()
    return BIND_SIZE + BIND_GAP
end

function CCT.Pictures.Binds(state)
    return CCT.Pictures.Icons(state or (CCT.State and CCT.State.Get and CCT.State.Get()))
end

local function Supports()
    if ready ~= nil then
        return ready
    end
    ready = false
    if type(CreateFrame) ~= "function" or UIParent == nil then
        return false
    end
    local probe = CreateFrame("Frame")
    if type(probe.CreateTexture) ~= "function" or type(probe.SetMovable) ~= "function" then
        return false
    end
    local tex = probe:CreateTexture()
    if type(tex) ~= "table" or type(tex.SetSize) ~= "function" or type(tex.SetPoint) ~= "function" then
        return false
    end
    ready = true
    return true
end

local function Char()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or CCT.Saved == nil or type(CCT.Saved.EnsureChar) ~= "function" then
        return nil
    end
    return CCT.Saved.EnsureChar(short)
end

local function Ring()
    local char = Char()
    if type(char) ~= "table" then
        return nil
    end
    if type(char.pictures) ~= "table" then
        char.pictures = {}
    end
    return char.pictures
end

local function Remember(icon, now)
    if type(icon) ~= "string" or icon == "" then
        return false
    end
    local list = Ring()
    if list == nil then
        return false
    end
    list[#list + 1] = { t = tonumber(now) or CCT.UnixNow(), icon = icon }
    while #list > RING_CAP do
        table.remove(list, 1)
    end
    return true
end

function CCT.Pictures.Note(icon, now)
    return Remember(icon, now)
end

local function EnsurePopup()
    if popup or not Supports() then
        return popup
    end
    popup = CreateFrame("Frame", "CatgirlPicturePopup", UIParent)
    popup:SetSize(POPUP_SIZE, POPUP_SIZE)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    if popup.EnableMouse then
        popup:EnableMouse(false)
    end
    popup:Hide()
    local tex = popup:CreateTexture(nil, "OVERLAY")
    tex:SetSize(POPUP_SIZE, POPUP_SIZE)
    tex:SetPoint("CENTER")
    if tex.Hide then
        tex:Hide()
    end
    popup.texture = tex
    if popup.SetScript then
        popup:SetScript("OnUpdate", function()
            CCT.Pictures.Tick()
        end)
    end
    return popup
end

local function EnsureStrip()
    if strip or not Supports() then
        return strip
    end
    strip = CreateFrame("Frame", "CatgirlBindsStrip", UIParent)
    strip:SetSize(BIND_SIZE, BIND_SIZE + LABEL_HEIGHT)
    strip:SetPoint("TOP", UIParent, "TOP", 0, -40)
    strip:SetMovable(true)
    strip:EnableMouse(true)
    if strip.RegisterForDrag then
        strip:RegisterForDrag("LeftButton")
    end
    if strip.SetClampedToScreen then
        strip:SetClampedToScreen(true)
    end
    strip.icons = {}
    strip.times = {}
    strip.rows = {}
    strip:Hide()
    return strip
end

local function HidePopup()
    showing = nil
    hideAt = nil
    if popup == nil then
        return
    end
    if popup.texture and popup.texture.Hide then
        popup.texture:Hide()
    end
    if popup.Hide then
        popup:Hide()
    end
end

local function ShowIcon(icon, size, now)
    local same = showing ~= nil and showing.icon == icon and hideAt ~= nil
    showing = { icon = icon, size = size }
    if not same then
        hideAt = Clock(now) + SHOW_SECONDS
    end
    local frame = EnsurePopup()
    if frame == nil then
        return
    end
    frame:SetSize(size, size)
    if frame.texture then
        frame.texture:SetSize(size, size)
        if frame.texture.SetTexture then
            frame.texture:SetTexture(icon)
        end
        if frame.texture.Show then
            frame.texture:Show()
        end
    end
    frame:Show()
end

local function Popup(icon, now)
    if type(icon) ~= "string" or icon == "" then
        return false
    end
    Remember(icon, now)
    ShowIcon(icon, POPUP_SIZE, now)
    return true
end

function CCT.Pictures.Show(icon, now)
    return Popup(icon, now)
end

function CCT.Pictures.ShowDiscipline(icon)
    local path = Icon(icon)
    if path == nil then
        return false
    end
    Remember(path)
    ShowIcon(path, DISCIPLINE_SIZE)
    return true
end

function CCT.Pictures.Tick(now)
    if hideAt == nil or showing == nil then
        return
    end
    if Clock(now) < hideAt then
        return
    end
    HidePopup()
end

local function StopCountdown()
    if countdown and countdown.Cancel then
        countdown:Cancel()
    end
    countdown = nil
end

local function AnyTimer(rows, state)
    for i = 1, #rows do
        if TimeText(state, rows[i].bind) ~= nil then
            return true
        end
    end
    return false
end

local function PaintTimes(frame, state)
    local rows = frame.rows or {}
    for i = 1, #rows do
        local label = frame.times and frame.times[i]
        if label then
            local text = TimeText(state, rows[i].bind)
            if text then
                if label.SetText then
                    label:SetText(text)
                end
                if label.Show then
                    label:Show()
                end
            else
                if label.SetText then
                    label:SetText("")
                end
                if label.Hide then
                    label:Hide()
                end
            end
        end
    end
end

local function RefreshCountdowns()
    if strip == nil or type(strip.rows) ~= "table" then
        StopCountdown()
        return
    end
    if strip.IsShown and strip:IsShown() ~= true then
        StopCountdown()
        return
    end
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    PaintTimes(strip, state)
    if not AnyTimer(strip.rows, state) then
        StopCountdown()
    end
end

local function EnsureCountdown()
    if countdown ~= nil or C_Timer == nil or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    countdown = C_Timer.NewTicker(1, RefreshCountdowns)
end

local function MakeLabel(frame, tex)
    if type(frame.CreateFontString) ~= "function" then
        return nil
    end
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if type(label) ~= "table" then
        return nil
    end
    if label.SetFont then
        label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    end
    if label.SetJustifyH then
        label:SetJustifyH("CENTER")
    end
    if label.SetWidth then
        label:SetWidth(BIND_SIZE + BIND_GAP)
    end
    if label.SetTextColor then
        label:SetTextColor(1, 0.85, 0.2)
    end
    if label.SetPoint then
        label:SetPoint("TOP", tex, "BOTTOM", 0, -1)
    end
    if label.Hide then
        label:Hide()
    end
    return label
end

local function DrawStrip(rows, state)
    local frame = EnsureStrip()
    if frame == nil then
        return
    end
    if type(rows) ~= "table" or #rows == 0 then
        frame.rows = {}
        frame:Hide()
        StopCountdown()
        return
    end
    frame.rows = rows
    local width = #rows * BIND_SIZE + (#rows - 1) * BIND_GAP
    frame:SetSize(width, BIND_SIZE + LABEL_HEIGHT)
    frame:Show()
    if type(frame.CreateTexture) ~= "function" then
        return
    end
    for i = 1, #rows do
        local tex = frame.icons[i]
        if tex == nil then
            tex = frame:CreateTexture(nil, "ARTWORK")
            tex:SetSize(BIND_SIZE, BIND_SIZE)
            frame.icons[i] = tex
        end
        if tex.ClearAllPoints then
            tex:ClearAllPoints()
        end
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * (BIND_SIZE + BIND_GAP), 0)
        if tex.SetTexture then
            tex:SetTexture(rows[i].icon)
        end
        if tex.Show then
            tex:Show()
        end
        if frame.times[i] == nil then
            frame.times[i] = MakeLabel(frame, tex)
        end
    end
    for i = #rows + 1, #frame.icons do
        if frame.icons[i].Hide then
            frame.icons[i]:Hide()
        end
        if frame.times[i] and frame.times[i].Hide then
            frame.times[i]:Hide()
        end
    end
    PaintTimes(frame, state)
    if AnyTimer(rows, state) then
        EnsureCountdown()
    else
        StopCountdown()
    end
end

local function Seen(list, icon)
    for i = 1, #list do
        if list[i] == icon then
            return true
        end
    end
    return false
end

local function OnState(state)
    local rows = CollectRows(state)
    local icons = RowIcons(rows)
    if baseline == nil then
        baseline = icons
        DrawStrip(rows, state)
        return
    end
    for i = 1, #icons do
        if not Seen(baseline, icons[i]) then
            Popup(icons[i])
        end
    end
    baseline = icons
    DrawStrip(rows, state)
end

function CCT.Pictures.Replay(now)
    local list = Ring()
    if type(list) ~= "table" or #list == 0 then
        return false
    end
    local last = list[#list]
    if type(last) ~= "table" or type(last.icon) ~= "string" then
        return false
    end
    ShowIcon(last.icon, POPUP_SIZE, now)
    return true
end

function CCT.Pictures.Current()
    return showing
end

function CCT.Pictures.OnEvent(_, event)
    if event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ENTERING_WORLD" then
        return
    end
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    local rows = CollectRows(state)
    baseline = RowIcons(rows)
    DrawStrip(rows, state)
    if not listening and CCT.State and type(CCT.State.Listen) == "function" then
        CCT.State.Listen(OnState)
        listening = true
    end
    if event == "PLAYER_LOGIN" then
        CCT.Pictures.Replay()
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", CCT.Pictures.OnEvent)
end
