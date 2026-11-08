-- CatNya macro and the draggable pet button.
-- The button toggles petSummoned. It does not know whether a battle pet is out.
-- Five minutes after login, one guild flavor line fires if the module is on
-- and the player is alive. That line is not a ledger row.
-- Macro edits wait for PLAYER_REGEN_ENABLED. This file does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Pet = {}

local MACRO_NAME = "CatNya"
local MACRO_ICON = "INV_Misc_QuestionMark"
local REMIND_SECONDS = 300
local SUMMON_TEXT = "Summon your cat Nya !"
local OUT_TEXT = "Good Kitten!, You Cat is Summoned"

CCT.Pet.MACRO_NAME = MACRO_NAME
CCT.Pet.REMIND_SECONDS = REMIND_SECONDS

local CARRIERS = {
    "Cat Carrier (Cornish Rex)",
    "Cat Carrier (Siamese)",
    "Cat Carrier (Orange Tabby)",
    "Cat Carrier (Silver Tabby)",
    "Cat Carrier (Black Tabby)",
    "Cat Carrier (Bombay)",
    "Cat Carrier (White Kitten)",
}

CCT.Pet.CARRIERS = CARRIERS

local button = nil
local summoned = false
local macroReady = false
local pendingMacro = false
local reminded = false
local remindWaiting = false
local loginAt = nil

local function Enabled()
    if CCT.Module and type(CCT.Module.Enabled) == "function" then
        return CCT.Module.Enabled("PetTracker") == true
    end
    return true
end

local function InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local function Alive()
    if type(UnitIsDeadOrGhost) ~= "function" then
        return true
    end
    return UnitIsDeadOrGhost("player") ~= true
end

local function FlavorOn()
    local settings = CCT.db and CCT.db.settings
    return type(settings) == "table" and settings.flavorAnnouncements ~= false
end

local function Char()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" or CCT.Saved == nil or type(CCT.Saved.EnsureChar) ~= "function" then
        return nil
    end
    return CCT.Saved.EnsureChar(short)
end

function CCT.Pet.MacroBody()
    local lines = {}
    for i = 1, #CARRIERS do
        lines[#lines + 1] = "/use " .. CARRIERS[i]
    end
    return table.concat(lines, "\n")
end

local function ApplySummoned(on)
    summoned = on and true or false
    if CCT.State and type(CCT.State.SetPetSummoned) == "function" then
        CCT.State.SetPetSummoned(summoned)
    end
    if button and button.SetText then
        button:SetText(summoned and OUT_TEXT or SUMMON_TEXT)
    end
end

function CCT.Pet.Summoned()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) == "table" then
        return state.petSummoned == true
    end
    return summoned
end

function CCT.Pet.Toggle()
    ApplySummoned(not CCT.Pet.Summoned())
    return CCT.Pet.Summoned()
end

local function SavePoint(frame)
    if frame == nil or type(frame.GetPoint) ~= "function" then
        return
    end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then
        return
    end
    local char = Char()
    if char == nil then
        return
    end
    char.petButton = {
        point = point,
        relativePoint = type(relativePoint) == "string" and relativePoint or point,
        x = tonumber(x) or 0,
        y = tonumber(y) or -180,
    }
end

local function ApplyPoint(frame)
    if frame == nil or type(frame.SetPoint) ~= "function" then
        return
    end
    local char = Char()
    local saved = char and char.petButton
    if type(saved) ~= "table" or type(saved.point) ~= "string" then
        frame:SetPoint("TOP", 0, -180)
        return
    end
    if frame.ClearAllPoints then
        frame:ClearAllPoints()
    end
    frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or -180)
end

function CCT.Pet.EnsureMacro()
    if InCombat() then
        pendingMacro = true
        return false
    end
    if type(CreateMacro) ~= "function" and type(EditMacro) ~= "function" then
        return false
    end
    local body = CCT.Pet.MacroBody()
    local index = 0
    if type(GetMacroIndexByName) == "function" then
        index = tonumber(GetMacroIndexByName(MACRO_NAME)) or 0
    end
    local ok = pcall(function()
        if index > 0 and type(EditMacro) == "function" then
            EditMacro(index, MACRO_NAME, MACRO_ICON, body)
            return
        end
        if type(CreateMacro) == "function" then
            CreateMacro(MACRO_NAME, MACRO_ICON, body, nil)
        end
    end)
    pendingMacro = not ok
    if type(GetMacroIndexByName) == "function" then
        macroReady = (tonumber(GetMacroIndexByName(MACRO_NAME)) or 0) > 0
    else
        macroReady = ok
    end
    if macroReady then
        pendingMacro = false
    end
    return macroReady
end

local function ArmButton()
    if button == nil or InCombat() then
        if InCombat() then
            pendingMacro = true
        end
        return
    end
    CCT.Pet.EnsureMacro()
    local body = nil
    if macroReady and type(GetMacroIndexByName) == "function" and type(GetMacroInfo) == "function" then
        local index = tonumber(GetMacroIndexByName(MACRO_NAME)) or 0
        if index > 0 then
            local _, _, read = GetMacroInfo(index)
            if type(read) == "string" and read ~= "" then
                body = read
            end
        end
    end
    if body == nil then
        body = CCT.Pet.MacroBody()
    end
    if button.SetAttribute then
        button:SetAttribute("type", "macro")
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext", nil)
        button:SetAttribute("macrotext1", body)
        button:SetAttribute("macro", nil)
        button:SetAttribute("macro1", nil)
    end
end

local function EnsureButton()
    if button or type(CreateFrame) ~= "function" or UIParent == nil then
        return button
    end
    button = CreateFrame("Button", "CatgirlSummonCatButton", UIParent, "UIPanelButtonTemplate,SecureActionButtonTemplate")
    button:SetSize(260, 24)
    ApplyPoint(button)
    if button.RegisterForClicks then
        button:RegisterForClicks("LeftButtonDown")
    end
    if button.SetMovable then
        button:SetMovable(true)
    end
    if button.EnableMouse then
        button:EnableMouse(true)
    end
    if button.RegisterForDrag then
        button:RegisterForDrag("LeftButton")
    end
    button:SetScript("OnDragStart", function(self)
        if self.StartMoving then
            self:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function(self)
        if self.StopMovingOrSizing then
            self:StopMovingOrSizing()
        end
        SavePoint(self)
    end)
    button:SetScript("PostClick", function()
        CCT.Pet.Click()
    end)
    if button.SetText then
        button:SetText(SUMMON_TEXT)
    end
    ArmButton()
    return button
end

function CCT.Pet.Click()
    if not macroReady then
        CCT.Pet.EnsureMacro()
    end
    if not macroReady then
        if print then
            print("|cffffcc00[CatgirlTracker]:|r Macro 'CatNya' not found.")
        end
        return false
    end
    return CCT.Pet.Toggle()
end

function CCT.Pet.Apply()
    local frame = EnsureButton()
    if frame == nil then
        return false
    end
    if Enabled() then
        ArmButton()
        frame:Show()
        if frame.SetText then
            frame:SetText(CCT.Pet.Summoned() and OUT_TEXT or SUMMON_TEXT)
        end
    else
        frame:Hide()
    end
    return true
end

local function Announce(key)
    if not FlavorOn() or CCT.Chat == nil or type(CCT.Chat.Send) ~= "function" then
        return false
    end
    if type(IsInGuild) == "function" and IsInGuild() ~= true then
        return false
    end
    CCT.Chat.Send(CCT.Msg(key), "GUILD")
    return true
end

function CCT.Pet.Remind()
    if reminded or not Enabled() then
        return false
    end
    if not Alive() then
        remindWaiting = true
        return false
    end
    reminded = true
    remindWaiting = false
    if CCT.Pet.Summoned() then
        return Announce("PET_SUMMON_GOOD")
    end
    return Announce("PET_SUMMON_BAD")
end

function CCT.Pet.Check(now)
    local stamp = tonumber(now)
    if loginAt == nil or stamp == nil then
        return false
    end
    if stamp - loginAt < REMIND_SECONDS then
        return false
    end
    return CCT.Pet.Remind()
end

local function OnLogin()
    ApplySummoned(false)
    loginAt = type(time) == "function" and time() or 0
    reminded = false
    remindWaiting = false
    CCT.Pet.EnsureMacro()
    CCT.Pet.Apply()
    if Enabled() and C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(REMIND_SECONDS, function()
            CCT.Pet.Remind()
        end)
    end
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_DEAD")
    events:RegisterEvent("PLAYER_ALIVE")
    events:RegisterEvent("PLAYER_UNGHOST")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("UPDATE_MACROS")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            OnLogin()
            return
        end
        if not Enabled() then
            return
        end
        if event == "PLAYER_DEAD" then
            ApplySummoned(false)
            return
        end
        if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            if remindWaiting then
                CCT.Pet.Remind()
            end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_MACROS" then
            if pendingMacro or event == "UPDATE_MACROS" then
                ArmButton()
            end
        end
    end)
end
