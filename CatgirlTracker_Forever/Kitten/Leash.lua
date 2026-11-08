-- Secure leash button. Worn state goes through CCT.State.
-- The button runs a character macro. This file never clicks a protected frame.
-- Attribute changes and macro edits wait for PLAYER_REGEN_ENABLED.
-- Unleash is only from the character who applied the leash.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Leash = {}

local MACRO_NAME = "FollowLeashMacro"
local MACRO_ICON = "INV_MISC_QUESTIONMARK"
local SLOT_COUNT = 120
local FOLLOW_TEXT = "Press 1 follow your Master nya~"
local STOP_TEXT = "Click to stop following nya~"

CCT.Leash.MACRO_NAME = MACRO_NAME
CCT.Leash.FOLLOW_TEXT = FOLLOW_TEXT
CCT.Leash.STOP_TEXT = STOP_TEXT

local button = nil
local eventFrame = nil
local pending = nil
local followTarget = nil
local shownTarget = nil
local awaitingStop = false
local armMode = nil

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function KittenName()
    if CCT.Player and type(CCT.Player.short) == "string" and CCT.Player.short ~= "" then
        return CCT.Player.short
    end
    return "Kitten"
end

local function Char()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" then
        return nil
    end
    if not CCT.Saved or not CCT.Saved.EnsureChar then
        return nil
    end
    return CCT.Saved.EnsureChar(short)
end

local function Whisper(target, text)
    if type(target) ~= "string" or target == "" or type(text) ~= "string" or text == "" then
        return
    end
    if CCT.Chat and CCT.Chat.Send then
        CCT.Chat.Send(text, "WHISPER", nil, target, { raw = true })
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

local function Say(text)
    if print and text then
        print(text)
    end
end

local function MacroTarget(name)
    local short = CCT.LinkName and CCT.LinkName(name) or nil
    if short == nil or short:find("[%c]") then
        return nil
    end
    return short
end

local function ButtonShown()
    return button ~= nil and button.IsShown and button:IsShown() == true
end

local function WatchRegen()
    if eventFrame and eventFrame.RegisterEvent then
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function ClearRegen()
    if eventFrame and eventFrame.UnregisterEvent then
        eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function EnsureButton()
    if button or not CreateFrame or not UIParent then
        return button
    end
    if InCombat() then
        return nil
    end
    button = CreateFrame("Button", "CatgirlLeashButton", UIParent, "SecureActionButtonTemplate")
    button:SetPoint("CENTER")
    if UIParent.GetWidth and UIParent.GetHeight then
        button:SetSize(UIParent:GetWidth(), UIParent:GetHeight())
    end
    button:SetFrameStrata("FULLSCREEN_DIALOG")
    button:EnableMouse(true)
    if button.RegisterForClicks then
        button:RegisterForClicks("AnyUp")
    end
    button:Hide()

    local texture = button:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    if texture.SetColorTexture then
        texture:SetColorTexture(0, 0, 0, 0.3)
    end
    button.texture = texture

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    button.text = text
    return button
end

local function SetMacroAttributes(targetButton, body, macroId)
    targetButton:SetAttribute("type", "macro")
    targetButton:SetAttribute("type1", "macro")
    targetButton:SetAttribute("clickbutton", nil)
    targetButton:SetAttribute("clickbutton1", nil)
    if macroId and macroId > 0 then
        targetButton:SetAttribute("macro", macroId)
        targetButton:SetAttribute("macro1", macroId)
        targetButton:SetAttribute("macroname", MACRO_NAME)
        targetButton:SetAttribute("macroname1", MACRO_NAME)
        targetButton:SetAttribute("macrotext", nil)
        targetButton:SetAttribute("macrotext1", nil)
        return
    end
    targetButton:SetAttribute("macro", nil)
    targetButton:SetAttribute("macro1", nil)
    targetButton:SetAttribute("macroname", nil)
    targetButton:SetAttribute("macroname1", nil)
    targetButton:SetAttribute("macrotext", body)
    targetButton:SetAttribute("macrotext1", body)
end

local function HideButton()
    shownTarget = nil
    if not button then
        return
    end
    button:Hide()
    button:SetScript("PostClick", nil)
end

local function Capture()
    local char = Char()
    if char == nil then
        return false
    end
    local slots = {}
    for slot = 1, SLOT_COUNT do
        if type(GetActionInfo) == "function" then
            local actionType, id, subType = GetActionInfo(slot)
            if actionType then
                slots[slot] = { actionType = actionType, id = id, subType = subType }
            else
                slots[slot] = false
            end
        else
            slots[slot] = false
        end
    end
    char.leashSlots = slots
    return true
end

local function HaveBackup()
    local char = Char()
    return char ~= nil and type(char.leashSlots) == "table"
end

local function WriteMacro(target)
    local body = "/target " .. target .. "\n/follow"
    if InCombat() then
        return nil, body
    end
    if type(GetMacroIndexByName) ~= "function" or type(CreateMacro) ~= "function" then
        return nil, body
    end
    local index = GetMacroIndexByName(MACRO_NAME)
    local ok = pcall(function()
        if index and index > 0 and type(EditMacro) == "function" then
            EditMacro(index, MACRO_NAME, MACRO_ICON, body, true)
            return
        end
        CreateMacro(MACRO_NAME, MACRO_ICON, body, true)
    end)
    if not ok then
        return nil, body
    end
    local finalIndex = GetMacroIndexByName(MACRO_NAME)
    if not finalIndex or finalIndex == 0 then
        return nil, body
    end
    return finalIndex, body
end

local function StampBar(macroId)
    if not macroId or InCombat() then
        return
    end
    if type(PickupMacro) ~= "function" or type(PlaceAction) ~= "function" then
        return
    end
    for slot = 1, SLOT_COUNT do
        PickupMacro(macroId)
        PlaceAction(slot)
        if type(ClearCursor) == "function" then
            ClearCursor()
        end
    end
end

local function RestoreSlots()
    if InCombat() then
        return false
    end
    local char = Char()
    if char == nil or type(char.leashSlots) ~= "table" then
        return false
    end
    local slots = char.leashSlots
    for slot = 1, SLOT_COUNT do
        local data = slots[slot]
        if type(data) == "table" and data.actionType then
            if data.actionType == "spell" and type(PickupSpell) == "function" then
                PickupSpell(data.id)
            elseif data.actionType == "macro" and type(PickupMacro) == "function" then
                PickupMacro(data.id)
            elseif data.actionType == "item" and type(PickupItem) == "function" then
                PickupItem(data.id)
            end
            if type(PlaceAction) == "function" then
                PlaceAction(slot)
            end
        elseif type(PickupAction) == "function" then
            PickupAction(slot)
        end
        if type(ClearCursor) == "function" then
            ClearCursor()
        end
    end
    char.leashSlots = nil
    return true
end

local function ConfigureFollow(macroId, body, target)
    local targetButton = EnsureButton()
    if not targetButton then
        return false
    end
    targetButton:SetScript("PostClick", nil)
    SetMacroAttributes(targetButton, body, macroId)
    if targetButton.text and targetButton.text.SetText then
        targetButton.text:SetText(FOLLOW_TEXT)
    end
    targetButton:Show()
    shownTarget = target
    return true
end

local function ConfigureStop()
    local targetButton = EnsureButton()
    if not targetButton then
        return false
    end
    SetMacroAttributes(targetButton, "/stopfollow", nil)
    if targetButton.text and targetButton.text.SetText then
        targetButton.text:SetText(STOP_TEXT)
    end
    targetButton:SetScript("PostClick", function()
        awaitingStop = false
        shownTarget = nil
        targetButton:Hide()
        targetButton:SetScript("PostClick", nil)
    end)
    targetButton:Show()
    shownTarget = nil
    return true
end

local function ArmFollow(target, syncOnly)
    if type(target) ~= "string" or target == "" then
        return
    end
    followTarget = target
    if syncOnly and pending ~= "follow" and shownTarget == target and ButtonShown() then
        return
    end
    if InCombat() then
        if not syncOnly and not HaveBackup() then
            Capture()
        end
        pending = "follow"
        shownTarget = nil
        if button then
            button:Hide()
        end
        WatchRegen()
        return
    end
    if not HaveBackup() and not syncOnly then
        Capture()
    end
    local macroId, body = WriteMacro(target)
    if HaveBackup() then
        StampBar(macroId)
    end
    ConfigureFollow(macroId, body, target)
    pending = nil
    ClearRegen()
end

local function ArmStop()
    if InCombat() then
        pending = "stop"
        if button then
            button:Hide()
        end
        WatchRegen()
        return
    end
    ConfigureStop()
    RestoreSlots()
    pending = nil
    ClearRegen()
end

local function FinishPending()
    local kind = pending
    pending = nil
    ClearRegen()
    if kind == "follow" then
        ArmFollow(followTarget, true)
    elseif kind == "stop" then
        ArmStop()
    elseif kind == "restore" then
        RestoreSlots()
    end
end

local function Sync()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return
    end
    if awaitingStop then
        return
    end
    if state.leash == true then
        ArmFollow(state.leashOwner, armMode ~= "apply")
        return
    end
    if ButtonShown() then
        HideButton()
    end
end

function CCT.Leash.Recover()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) == "table" and state.leash == true then
        ArmFollow(state.leashOwner, true)
        return
    end
    awaitingStop = false
    if ButtonShown() then
        HideButton()
    end
    if not HaveBackup() then
        return
    end
    if InCombat() then
        pending = "restore"
        WatchRegen()
        return
    end
    RestoreSlots()
end

function CCT.Leash.Apply(on, sender)
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" or not CCT.State.SetLeash then
        return false, "state"
    end
    if on == true then
        if state.leash == true then
            return false, "leashed"
        end
        awaitingStop = false
        local target = MacroTarget(sender)
        if target == nil then
            return false, "owner"
        end
        armMode = "apply"
        CCT.State.SetLeash(true, target)
        armMode = nil
        Whisper(target, CCT.Msg("LEASH_APPLY", KittenName()))
        Say("|cffffff00CatgirlTracker:|r Leashed by " .. target .. " nya~")
        Raid("Leash applied.")
        return true
    end
    if on ~= false then
        return false, "on"
    end
    if state.leash ~= true then
        return false, "free"
    end
    if not CCT.SameName(sender, state.leashOwner) then
        return false, "leasher"
    end
    local target = state.leashOwner
    awaitingStop = true
    CCT.State.SetLeash(false, nil)
    ArmStop()
    Whisper(target, CCT.Msg("LEASH_REMOVE", KittenName()))
    Say("|cffffff00CatgirlTracker:|r Unleashed nya~")
    Raid("Leash removed.")
    return true
end

function CCT.Leash.OnEvent(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        FinishPending()
        return
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CCT.Leash.Recover()
    end
end

if CCT.State and CCT.State.Listen then
    CCT.State.Listen(Sync)
end

if CreateFrame then
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", CCT.Leash.OnEvent)
end
