-- Paw mittens. The worn state is CCT.State.
-- The cursor follows the mouse on a ticker only while the overlay is shown.
-- Action slots are edited out of combat and finished on PLAYER_REGEN_ENABLED.
-- This file does not send addon messages.

local ADDON_NAME, CCT = ...

CCT.Mittens = {}

local CURSOR_INTERVAL = 0.05
local SABOTAGE_INTERVAL = 5
local SQUEAK_WINDOW = 5
local SQUEAK_CYCLE = 30
local SOUND_COOLDOWN = 2
local CURSOR_SIZE = 72
local MACRO_NAME = "PawMittensOops"
local MACRO_ICON = "INV_Misc_QuestionMark"
local ACTION_SLOTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

CCT.Mittens.CURSOR_INTERVAL = CURSOR_INTERVAL
CCT.Mittens.SABOTAGE_INTERVAL = SABOTAGE_INTERVAL
CCT.Mittens.SQUEAK_WINDOW = SQUEAK_WINDOW
CCT.Mittens.SQUEAK_CYCLE = SQUEAK_CYCLE
CCT.Mittens.SOUND_COOLDOWN = SOUND_COOLDOWN

local mode = "off"
local cursorFrame = nil
local cursorTicker = nil
local sabotageTicker = nil
local cycleTicker = nil
local windowTimer = nil
local windowActive = false
local currentSlot = nil
local pendingRestore = nil
local pendingSabotage = false
local pendingWindow = false
local saved = {}
local lastSound = { squeak = 0, creak = 0 }

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

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

local function Worn()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return "none"
    end
    local mittens = state.mittens
    if mittens ~= "locked" and mittens ~= "heavy" and mittens ~= "squeaking" then
        return "none"
    end
    return mittens
end

function CCT.Mittens.Texture(mittens)
    if mittens == "heavy" or mittens == "squeaking" then
        return Media("Textures\\heavypawmittens.tga")
    end
    if mittens == "locked" then
        return Media("Textures\\pawmittens.tga")
    end
    return nil
end

function CCT.Mittens.CastKind(mittens)
    if mittens == "squeaking" then
        return "squeak"
    end
    if mittens == "locked" or mittens == "heavy" then
        return "creak"
    end
    return nil
end

function CCT.Mittens.Mode(mittens)
    if mittens == "squeaking" then
        return "window"
    end
    if mittens == "locked" or mittens == "heavy" then
        return "continuous"
    end
    return "off"
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

function CCT.Mittens.Set(sender, value)
    if value == "squeking" then
        value = "squeaking"
    end
    if not OwnerOk(sender) then
        return false
    end
    if value ~= "none" and value ~= "locked" and value ~= "heavy" and value ~= "squeaking" then
        return false
    end
    if not CCT.State or not CCT.State.SetMittens then
        return false
    end
    return CCT.State.SetMittens(value) == true
end

local function PositionCursor()
    if not cursorFrame or type(GetCursorPosition) ~= "function" or not UIParent then
        return
    end
    local x, y = GetCursorPosition()
    if type(issecretvalue) == "function" and (issecretvalue(x) or issecretvalue(y)) then
        return
    end
    if type(x) ~= "number" or type(y) ~= "number" then
        return
    end
    local scale = 1
    if UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale()
    end
    if type(scale) ~= "number" or scale == 0 then
        return
    end
    cursorFrame:ClearAllPoints()
    cursorFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function StopCursor()
    if cursorTicker and cursorTicker.Cancel then
        cursorTicker:Cancel()
    end
    cursorTicker = nil
    if cursorFrame then
        cursorFrame:SetScript("OnUpdate", nil)
        cursorFrame:Hide()
    end
end

local function EnsureCursor()
    if cursorFrame or not CreateFrame or not UIParent then
        return cursorFrame
    end
    cursorFrame = CreateFrame("Frame", "CatgirlPawMittensCursor", UIParent)
    cursorFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    cursorFrame:SetSize(CURSOR_SIZE, CURSOR_SIZE)
    cursorFrame:EnableMouse(false)
    cursorFrame:SetScript("OnUpdate", nil)
    cursorFrame:Hide()
    local texture = cursorFrame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetAlpha(0.95)
    cursorFrame.texture = texture
    return cursorFrame
end

local function ShowCursor(mittens)
    local frame = EnsureCursor()
    local path = CCT.Mittens.Texture(mittens)
    if frame and frame.texture and frame.texture.SetTexture then
        frame.texture:SetTexture(path)
    end
    if frame then
        frame:Show()
    end
    PositionCursor()
    if cursorTicker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    cursorTicker = C_Timer.NewTicker(CURSOR_INTERVAL, PositionCursor)
end

local function CancelWindowTimer()
    if windowTimer and windowTimer.Cancel then
        windowTimer:Cancel()
    end
    windowTimer = nil
end

local function CancelSabotageTimers()
    if sabotageTicker and sabotageTicker.Cancel then
        sabotageTicker:Cancel()
    end
    sabotageTicker = nil
    if cycleTicker and cycleTicker.Cancel then
        cycleTicker:Cancel()
    end
    cycleTicker = nil
    CancelWindowTimer()
end

local function PerformRestore(slot)
    local data = saved[slot]
    if not data then
        return
    end
    local function finish()
        if type(ClearCursor) == "function" then
            ClearCursor()
        end
    end
    if data.had then
        local ok = pcall(function()
            if data.actionType == "spell" and data.id ~= nil and type(PickupSpell) == "function" then
                PickupSpell(data.id)
            elseif data.actionType == "macro" and data.id ~= nil and type(PickupMacro) == "function" then
                PickupMacro(data.id)
            elseif data.actionType == "item" and data.id ~= nil and type(PickupItem) == "function" then
                PickupItem(data.id)
            else
                saved[slot] = nil
                finish()
                return
            end
            if type(PlaceAction) == "function" then
                PlaceAction(slot)
            end
            finish()
        end)
        if not ok then
            pcall(finish)
        end
    else
        pcall(function()
            if type(PickupAction) == "function" then
                PickupAction(slot)
            end
            finish()
        end)
    end
    saved[slot] = nil
end

local function Restore(slot)
    if not slot then
        return false
    end
    if InCombat() then
        pendingRestore = slot
        return false
    end
    pendingRestore = nil
    PerformRestore(slot)
    return true
end

local function MacroBody()
    return "/say " .. CCT.Msg("PAW_MITTENS_SAY")
end

local function EnsureMacro()
    if InCombat() then
        pendingSabotage = true
        return nil
    end
    if type(CreateMacro) ~= "function" or type(GetMacroIndexByName) ~= "function" then
        return nil
    end
    local body = MacroBody()
    local index = GetMacroIndexByName(MACRO_NAME)
    local ok = pcall(function()
        if index and index > 0 and type(EditMacro) == "function" then
            EditMacro(index, MACRO_NAME, MACRO_ICON, body, true)
            return
        end
        CreateMacro(MACRO_NAME, MACRO_ICON, body, true)
    end)
    if not ok then
        if CCT.Debug then
            CCT.Debug("mittens-macro", 5, "Paw mitten macro was not created.")
        end
        return nil
    end
    local finalIndex = GetMacroIndexByName(MACRO_NAME)
    if not finalIndex or finalIndex == 0 then
        if CCT.Debug then
            CCT.Debug("mittens-macro", 5, "Paw mitten macro was not created.")
        end
        return nil
    end
    return finalIndex
end

local function Capture(slot)
    if type(GetActionInfo) ~= "function" then
        saved[slot] = { had = false }
        return
    end
    local actionType, id, subType = GetActionInfo(slot)
    if actionType then
        saved[slot] = {
            had = true,
            actionType = actionType,
            id = id,
            subType = subType,
        }
        return
    end
    saved[slot] = { had = false }
end

local function Place(slot, macroIndex)
    if not slot or not macroIndex then
        return false
    end
    if InCombat() then
        pendingSabotage = true
        return false
    end
    if type(PickupMacro) ~= "function" or type(PlaceAction) ~= "function" then
        return false
    end
    Capture(slot)
    local ok = pcall(function()
        PickupMacro(macroIndex)
        PlaceAction(slot)
        if type(ClearCursor) == "function" then
            ClearCursor()
        end
    end)
    if not ok then
        saved[slot] = nil
        if type(ClearCursor) == "function" then
            pcall(ClearCursor)
        end
        return false
    end
    return true
end

local function OccupiedSlots()
    if type(GetActionInfo) ~= "function" then
        return nil
    end
    local list = {}
    for i = 1, #ACTION_SLOTS do
        local actionType = GetActionInfo(ACTION_SLOTS[i])
        if actionType then
            list[#list + 1] = ACTION_SLOTS[i]
        end
    end
    return list
end

local function ChooseSlot(previous)
    local list = OccupiedSlots()
    if list == nil or #list == 0 then
        return nil
    end
    if #list == 1 then
        return list[1]
    end
    local slot = previous
    local tries = 0
    while slot == previous and tries < 20 do
        slot = list[math.random(#list)]
        tries = tries + 1
    end
    return slot or list[1]
end

local function SabotageTick()
    if CCT.Mittens.Mode(Worn()) == "off" then
        return
    end
    if mode == "window" and not windowActive then
        return
    end
    if InCombat() then
        pendingSabotage = true
        return
    end
    if type(GetActionInfo) ~= "function" then
        return
    end
    if currentSlot == nil then
        local occupied = OccupiedSlots()
        if occupied == nil or #occupied == 0 then
            return
        end
    end
    local macroIndex = EnsureMacro()
    if not macroIndex then
        return
    end
    local previous = currentSlot
    if currentSlot then
        if not Restore(currentSlot) then
            return
        end
        currentSlot = nil
    end
    local nextSlot = ChooseSlot(previous)
    if not nextSlot then
        return
    end
    if Place(nextSlot, macroIndex) then
        currentSlot = nextSlot
    end
end

local function EndWindow()
    windowActive = false
    windowTimer = nil
    if currentSlot and Restore(currentSlot) then
        currentSlot = nil
    end
end

local function After(seconds, fn)
    if C_Timer and type(C_Timer.NewTimer) == "function" then
        return C_Timer.NewTimer(seconds, fn)
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(seconds, fn)
    end
    return nil
end

local function BeginWindow()
    if Worn() ~= "squeaking" then
        return
    end
    if pendingRestore or InCombat() then
        pendingWindow = true
        return
    end
    pendingWindow = false
    windowActive = true
    SabotageTick()
    if not currentSlot then
        windowActive = false
        return
    end
    CancelWindowTimer()
    windowTimer = After(SQUEAK_WINDOW, EndWindow)
end

local function StartContinuous()
    CancelSabotageTimers()
    windowActive = false
    SabotageTick()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        sabotageTicker = C_Timer.NewTicker(SABOTAGE_INTERVAL, SabotageTick)
    end
end

local function StartWindowMode()
    CancelSabotageTimers()
    windowActive = false
    BeginWindow()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        cycleTicker = C_Timer.NewTicker(SQUEAK_CYCLE, BeginWindow)
    end
end

local function StopSabotage()
    CancelSabotageTimers()
    windowActive = false
    pendingWindow = false
    pendingSabotage = false
    if currentSlot and Restore(currentSlot) then
        currentSlot = nil
    end
    mode = "off"
end

local function ApplyWorn(mittens)
    local nextMode = CCT.Mittens.Mode(mittens)
    if nextMode == "off" then
        StopCursor()
        StopSabotage()
        return
    end
    ShowCursor(mittens)
    if nextMode == mode then
        return
    end
    StopSabotage()
    mode = nextMode
    if nextMode == "continuous" then
        StartContinuous()
    elseif nextMode == "window" then
        StartWindowMode()
    end
end

local function Sync()
    ApplyWorn(Worn())
end

local function FinishCombat()
    if pendingRestore then
        local slot = pendingRestore
        pendingRestore = nil
        PerformRestore(slot)
        if slot == currentSlot then
            currentSlot = nil
        end
    end
    local mittens = Worn()
    if pendingWindow and mittens == "squeaking" then
        pendingWindow = false
        BeginWindow()
    end
    if pendingSabotage and CCT.Mittens.Mode(mittens) ~= "off" then
        pendingSabotage = false
        if mode == "continuous" or windowActive then
            SabotageTick()
        end
    end
end

local function SoundPath(kind)
    if kind == "squeak" then
        return Media("Sounds\\pawsqueak" .. math.random(5) .. ".wav")
    end
    return Media("Sounds\\creak-" .. math.random(3) .. ".wav")
end

function CCT.Mittens.OnSpell()
    local kind = CCT.Mittens.CastKind(Worn())
    if kind == nil then
        return
    end
    local now = Now()
    if now - (lastSound[kind] or 0) < SOUND_COOLDOWN then
        return
    end
    lastSound[kind] = now
    if type(PlaySoundFile) == "function" then
        PlaySoundFile(SoundPath(kind), "Master")
    end
    if CCT.Report and type(CCT.Report.MittenProx) == "function" then
        CCT.Report.MittenProx(kind)
    end
end

function CCT.Mittens.OnEvent(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        FinishCombat()
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 == "player" then
            CCT.Mittens.OnSpell()
        end
        return
    end
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
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:SetScript("OnEvent", CCT.Mittens.OnEvent)
end
