-- Pictures from current state. A popup lasts 5 seconds. Removal does not pop.
-- The binds strip is derived, not a growing log. The ring holds 30 entries.
-- This file does not send addon messages.

local ADDON_NAME, CCT = ...

CCT.Pictures = {}

local POPUP_SIZE = 232
local DISCIPLINE_SIZE = 64
local BIND_SIZE = 40
local SHOW_SECONDS = 5
local RING_CAP = 30

local popup = nil
local strip = nil
local ready = nil
local baseline = nil
local listening = false
local showing = nil
local hideAt = nil

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

local function CollectIcons(state)
    local icons = {}
    if type(state) ~= "table" then
        return icons
    end
    local function add(fileName)
        local path = Icon(fileName)
        if path then
            icons[#icons + 1] = path
        end
    end
    if state.gag == "huge" then
        add("Heavy-gag-232-with-bg_ergebnis.tga")
    elseif state.gag == "small" then
        add("small-gag-232-with-bg_ergebnis.tga")
    elseif state.gag == "full" then
        add("kitty-mask-with-gag-232-with-bg_ergebnis.tga")
    elseif state.gag == "nyamask" then
        add("cute-kitty-mask-232-with-bg_ergebnis.tga")
    elseif state.gag == "inflatable" then
        add("Inflatable-gag-232-with-bg_ergebnis.tga")
    end
    if state.blind == "light" then
        add("Light-Blindfold-232-with-bg_ergebnis.tga")
    elseif state.blind == "mask" then
        add("Cute-Kitty-Blindfold-232-with-bg_ergebnis.tga")
    elseif state.blind == "full" then
        add("Heavy-Blindfold-232-with-bg_ergebnis.tga")
    end
    if state.ears == "kitten" then
        add("Kitten-Earmuffs-bg_ergebnis.tga")
    elseif state.ears == "heavy" then
        add("Heav-Earmuffs-bg_ergebnis.tga")
    end
    if state.mittens == "locked" or state.mittens == "heavy" then
        add("locking-paw-mitten-232-with-bg_ergebnis.tga")
    elseif state.mittens == "squeaking" then
        add("paw-mitten-232-with-bg_ergebnis.tga")
    end
    if state.heels == "maid" then
        add("maid-heell-232-with-bg_ergebnis.tga")
    elseif state.heels == "high" then
        add("heell-232-with-bg_ergebnis.tga")
    elseif state.heels == "ballet" then
        add("balletheel-232-with-bg_ergebnis.tga")
    end
    if state.bell == true then
        add("bell-232-with-bg_ergebnis.tga")
    end
    if state.tail == true then
        add("tail-bell-232-with-bg_ergebnis.tga")
    end
    if state.jewel == true then
        add("jewel-232-with-bg_ergebnis.tga")
    end
    if state.belt == true then
        add("Chastitybelt.tga")
    end
    if state.bra == true then
        add("chastitybra.tga")
    end
    local toys = state.toys or {}
    local list = CCT.State and CCT.State.Toys or {}
    for i = 1, #list do
        local row = toys[list[i].id]
        if type(row) == "table" and row.applied == true then
            add(ToyIcon(list[i].id))
        end
    end
    if state.leash == true then
        add("leash-232-with-gb_ergebnis.tga")
    end
    return icons
end

function CCT.Pictures.Icons(state)
    return CollectIcons(state)
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
    popup:Hide()
    local tex = popup:CreateTexture(nil, "OVERLAY")
    tex:SetSize(POPUP_SIZE, POPUP_SIZE)
    tex:SetPoint("CENTER")
    popup.texture = tex
    return popup
end

local function EnsureStrip()
    if strip or not Supports() then
        return strip
    end
    strip = CreateFrame("Frame", "CatgirlBindsStrip", UIParent)
    strip:SetSize(BIND_SIZE * 8, BIND_SIZE)
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
    strip:Hide()
    return strip
end

local function ShowIcon(icon, size, now)
    showing = { icon = icon, size = size }
    hideAt = (tonumber(now) or CCT.UnixNow()) + SHOW_SECONDS
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
    if (tonumber(now) or CCT.UnixNow()) < hideAt then
        return
    end
    showing = nil
    hideAt = nil
    if popup and popup.Hide then
        popup:Hide()
    end
end

local function DrawStrip(icons)
    local frame = EnsureStrip()
    if frame == nil then
        return
    end
    if type(icons) ~= "table" or #icons == 0 then
        frame:Hide()
        return
    end
    frame:Show()
    if type(frame.CreateTexture) ~= "function" then
        return
    end
    for i = 1, #icons do
        local tex = frame.icons[i]
        if tex == nil then
            tex = frame:CreateTexture(nil, "ARTWORK")
            tex:SetSize(BIND_SIZE, BIND_SIZE)
            tex:SetPoint("LEFT", frame, "LEFT", (i - 1) * BIND_SIZE, 0)
            frame.icons[i] = tex
        end
        if tex.SetTexture then
            tex:SetTexture(icons[i])
        end
        if tex.Show then
            tex:Show()
        end
    end
    for i = #icons + 1, #frame.icons do
        if frame.icons[i].Hide then
            frame.icons[i]:Hide()
        end
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
    local icons = CollectIcons(state)
    if baseline == nil then
        baseline = icons
        DrawStrip(icons)
        return
    end
    for i = 1, #icons do
        if not Seen(baseline, icons[i]) then
            Popup(icons[i])
        end
    end
    baseline = icons
    DrawStrip(icons)
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
    baseline = CollectIcons(state)
    DrawStrip(baseline)
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
