-- CatNya macro and the draggable pet button.
-- The summoned flag follows the cosmetic cat-carrier companion, not the button.
-- A hunter pet is ignored, and this file does not ask whether a pet is dead.
-- Every 10 minutes, a missing cat warns once. The next check sends the forgot line.
-- That line is not a ledger row. Macro edits wait for PLAYER_REGEN_ENABLED.
-- This file does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Pet = {}

local MACRO_NAME = "CatNya"
local MACRO_ICON = "INV_Misc_QuestionMark"
local CHECK_SECONDS = 600
local SUMMON_TEXT = "Summon your cat Nya !"
local OUT_TEXT = "Good Kitten!, You Cat is Summoned"

CCT.Pet.MACRO_NAME = MACRO_NAME
CCT.Pet.CHECK_SECONDS = CHECK_SECONDS

local CARRIERS = {
    "Cat Carrier (Cornish Rex)",
    "Cat Carrier (Siamese)",
    "Cat Carrier (Orange Tabby)",
    "Cat Carrier (Silver Tabby)",
    "Cat Carrier (Black Tabby)",
    "Cat Carrier (Bombay)",
    "Cat Carrier (White Kitten)",
}

-- Retail journal species ids for those seven carriers. A renamed pet still matches.
-- Forever's companion list also uses the shorter critter names.
local CAT_SPECIES = {
    [40] = true, -- Bombay Cat
    [41] = true, -- Cornish Rex Cat
    [42] = true, -- Black Tabby Cat
    [43] = true, -- Orange Tabby Cat
    [44] = true, -- Siamese Cat
    [45] = true, -- Silver Tabby Cat
    [46] = true, -- White Kitten
}

local CAT_NAMES = {
    ["Bombay Cat"] = true,
    ["Bombay"] = true,
    ["Cornish Rex Cat"] = true,
    ["Cornish Rex"] = true,
    ["Black Tabby Cat"] = true,
    ["Black Tabby"] = true,
    ["Orange Tabby Cat"] = true,
    ["Orange Tabby"] = true,
    ["Siamese Cat"] = true,
    ["Siamese"] = true,
    ["Silver Tabby Cat"] = true,
    ["Silver Tabby"] = true,
    ["White Kitten"] = true,
}

CCT.Pet.CARRIERS = CARRIERS
CCT.Pet.CAT_SPECIES = CAT_SPECIES

local button = nil
local summoned = false
local macroReady = false
local pendingMacro = false
local warned = false
local forgotSent = false
local checkWaiting = false
local nextAt = nil
local ticker = nil

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

local function KnownCat(speciesID, speciesName)
    if CAT_SPECIES[tonumber(speciesID) or -1] == true then
        return true
    end
    return type(speciesName) == "string" and CAT_NAMES[speciesName] == true
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- "cat", "other", "none", or "unknown". Cosmetic journal only.
local function JournalCat()
    local journal = C_PetJournal
    if type(journal) ~= "table" or type(journal.GetSummonedPetGUID) ~= "function" then
        return "unknown"
    end
    local ok, guid = pcall(journal.GetSummonedPetGUID)
    if not ok or Secret(guid) then
        return "unknown"
    end
    if type(guid) ~= "string" or guid == "" then
        return "none"
    end
    local speciesID, speciesName = nil, nil
    if type(journal.GetPetInfoTableByPetID) == "function" then
        local infoOk, info = pcall(journal.GetPetInfoTableByPetID, guid)
        if infoOk and type(info) == "table" and not Secret(info) then
            speciesID = info.speciesID
            speciesName = info.name
        end
    end
    if speciesID == nil and speciesName == nil and type(journal.GetPetInfoByPetID) == "function" then
        local infoOk, id, _, _, _, _, _, _, name = pcall(journal.GetPetInfoByPetID, guid)
        if infoOk and not Secret(id) and not Secret(name) then
            speciesID = id
            speciesName = name
        end
    end
    if Secret(speciesID) or Secret(speciesName) then
        return "unknown"
    end
    if speciesID == nil and type(speciesName) ~= "string" then
        return "unknown"
    end
    if KnownCat(speciesID, speciesName) then
        return "cat"
    end
    return "other"
end

-- Classic critter companions. "CRITTER" is not a hunter pet.
local function CritterCat()
    if type(GetNumCompanions) ~= "function" or type(GetCompanionInfo) ~= "function" then
        return "unknown"
    end
    local countOk, count = pcall(GetNumCompanions, "CRITTER")
    if not countOk or Secret(count) then
        return "unknown"
    end
    count = tonumber(count) or 0
    local saw = false
    for i = 1, count do
        local infoOk, _, name, _, _, isSummoned = pcall(GetCompanionInfo, "CRITTER", i)
        if not infoOk or Secret(name) or Secret(isSummoned) then
            return "unknown"
        end
        saw = true
        if isSummoned == true and CAT_NAMES[name] == true then
            return "cat"
        end
    end
    if count == 0 or saw then
        return "none"
    end
    return "unknown"
end

function CCT.Pet.CatOut()
    local journal = JournalCat()
    if journal == "cat" then
        return true
    end
    if journal == "other" then
        return false
    end
    local critter = CritterCat()
    if critter == "cat" then
        return true
    end
    if journal == "unknown" and critter == "unknown" then
        return nil
    end
    return false
end

function CCT.Pet.Refresh()
    local out = CCT.Pet.CatOut()
    if out == nil then
        return nil
    end
    ApplySummoned(out)
    if out then
        warned = false
        forgotSent = false
    end
    return out
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
    return true
end

function CCT.Pet.Apply()
    local frame = EnsureButton()
    if frame == nil then
        return false
    end
    CCT.Pet.Refresh()
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
    CCT.Chat.Send(CCT.Msg(key), "GUILD", nil, nil, { raw = true })
    return true
end

local function Warn()
    if print then
        print("|cffffcc00[CatgirlTracker]:|r " .. CCT.Msg("PET_SUMMON_WARN"))
    end
    return true
end

function CCT.Pet.Step()
    if not Enabled() then
        return false
    end
    if not Alive() then
        checkWaiting = true
        return false
    end
    checkWaiting = false
    local out = CCT.Pet.Refresh()
    if out == nil or out == true then
        return false
    end
    if not warned then
        warned = true
        return Warn()
    end
    if forgotSent then
        return false
    end
    local sent = Announce("PET_SUMMON_BAD")
    if sent then
        forgotSent = true
    end
    return sent
end

function CCT.Pet.Check(now)
    if not Enabled() then
        return false
    end
    local stamp = tonumber(now)
    if nextAt == nil or stamp == nil then
        return false
    end
    if stamp < nextAt then
        return false
    end
    nextAt = stamp + CHECK_SECONDS
    return CCT.Pet.Step()
end

local function OnLogin()
    local stamp = type(time) == "function" and time() or 0
    nextAt = stamp + CHECK_SECONDS
    warned = false
    forgotSent = false
    checkWaiting = false
    CCT.Pet.EnsureMacro()
    CCT.Pet.Apply()
    if ticker and type(ticker.Cancel) == "function" then
        ticker:Cancel()
        ticker = nil
    end
    if Enabled() and C_Timer and type(C_Timer.NewTicker) == "function" then
        ticker = C_Timer.NewTicker(CHECK_SECONDS, function()
            local clock = type(time) == "function" and time() or nil
            CCT.Pet.Check(clock)
        end)
    end
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ALIVE")
    events:RegisterEvent("PLAYER_UNGHOST")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("UPDATE_MACROS")
    events:RegisterEvent("COMPANION_UPDATE")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            OnLogin()
            return
        end
        if not Enabled() then
            return
        end
        if event == "COMPANION_UPDATE" then
            CCT.Pet.Refresh()
            if button and button.SetText and button.shown ~= false then
                button:SetText(CCT.Pet.Summoned() and OUT_TEXT or SUMMON_TEXT)
            end
            return
        end
        if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            if checkWaiting then
                CCT.Pet.Step()
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
