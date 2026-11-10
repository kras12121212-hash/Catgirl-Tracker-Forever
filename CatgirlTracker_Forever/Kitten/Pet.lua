-- Small summon window for a cat-carrier companion from the pet collection.
-- The carrier item no longer summons. The button calls the collection.
-- The summoned flag follows that cosmetic cat, not the click.
-- A hunter pet is ignored. While the player is dead the button asks to summon again.
-- Every 10 minutes, a missing cat warns once. The next check sends the forgot line.
-- That send increments petMiss once. The line itself is not a stored row.
-- Macro edits wait for PLAYER_REGEN_ENABLED.
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

local LOOKUP_NAMES = {
    "Bombay Cat",
    "Cornish Rex Cat",
    "Black Tabby Cat",
    "Orange Tabby Cat",
    "Siamese Cat",
    "Silver Tabby Cat",
    "White Kitten",
    "Bombay",
    "Cornish Rex",
    "Black Tabby",
    "Orange Tabby",
    "Siamese",
    "Silver Tabby",
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

local box = nil
local button = nil
local statusLine = nil
local summoned = false
local macroReady = false
local pendingMacro = false
local warned = false
local forgotSent = false
local checkWaiting = false
local nextAt = nil
local checkTicker = nil
local paintTicker = nil

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

local function Paint()
    local showOut = Alive() and summoned
    if button and button.SetText then
        button:SetText(showOut and OUT_TEXT or SUMMON_TEXT)
    end
    if statusLine and statusLine.SetText then
        statusLine:SetText(CCT.Pet.StatusText())
    end
end

local function ApplySummoned(on)
    summoned = on and true or false
    if CCT.State and type(CCT.State.SetPetSummoned) == "function" then
        CCT.State.SetPetSummoned(summoned)
    end
    Paint()
end

function CCT.Pet.Summoned()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) == "table" then
        return state.petSummoned == true
    end
    return summoned
end

function CCT.Pet.SecondsLeft(now)
    if nextAt == nil then
        return nil
    end
    local stamp = tonumber(now)
    if stamp == nil then
        stamp = type(time) == "function" and time() or 0
    end
    local left = nextAt - stamp
    if left < 0 then
        left = 0
    end
    return left
end

function CCT.Pet.StatusText(now)
    if Alive() and CCT.Pet.Summoned() then
        return "Cat is summoned"
    end
    local left = CCT.Pet.SecondsLeft(now)
    if left == nil then
        return "Summon your cat"
    end
    local mins = math.floor(left / 60)
    local secs = math.floor(left % 60)
    return string.format("Summon in %d:%02d", mins, secs)
end

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function OwnedCatGUID()
    local journal = C_PetJournal
    if type(journal) ~= "table" or type(journal.FindPetIDByName) ~= "function" then
        return nil
    end
    for i = 1, #LOOKUP_NAMES do
        local ok, speciesId, guid = pcall(journal.FindPetIDByName, LOOKUP_NAMES[i])
        if ok and type(speciesId) == "string" and guid == nil then
            guid = speciesId
            speciesId = nil
        end
        if ok and not Secret(guid) and type(guid) == "string" and guid ~= "" then
            if speciesId == nil or CAT_SPECIES[tonumber(speciesId) or -1] == true then
                return guid
            end
        end
    end
    return nil
end

local function CarrierCritterSlot()
    if type(GetNumCompanions) ~= "function" or type(GetCompanionInfo) ~= "function" then
        return nil, false
    end
    local countOk, count = pcall(GetNumCompanions, "CRITTER")
    if not countOk or Secret(count) then
        return nil, false
    end
    count = tonumber(count) or 0
    for i = 1, count do
        local infoOk, _, name, _, _, isSummoned = pcall(GetCompanionInfo, "CRITTER", i)
        if infoOk and not Secret(name) and not Secret(isSummoned) and CAT_NAMES[name] == true then
            return i, isSummoned == true
        end
    end
    return nil, false
end

local function Say(text)
    if print then
        print("|cffffcc00[CatgirlTracker]:|r " .. text)
    end
end

local function SummonCollected()
    local journal = C_PetJournal
    local guid = OwnedCatGUID()
    if guid and type(journal) == "table" and type(journal.SummonPetByGUID) == "function" then
        local ok = pcall(journal.SummonPetByGUID, guid)
        if ok then
            return true
        end
    end
    local slot = CarrierCritterSlot()
    if slot ~= nil and type(CallCompanion) == "function" then
        local ok = pcall(CallCompanion, "CRITTER", slot)
        if ok then
            return true
        end
    end
    Say("No cat from a cat carrier is in your collection.")
    return false
end

local function DismissCollected()
    local journal = C_PetJournal
    if type(journal) == "table" and type(journal.DismissSummonedPet) == "function" then
        local ok = pcall(journal.DismissSummonedPet)
        if ok then
            return true
        end
    end
    if type(journal) == "table" and type(journal.GetSummonedPetGUID) == "function" and type(journal.SummonPetByGUID) == "function" then
        local ok, guid = pcall(journal.GetSummonedPetGUID)
        if ok and type(guid) == "string" and guid ~= "" then
            local summonedOk = pcall(journal.SummonPetByGUID, guid)
            if summonedOk then
                return true
            end
        end
    end
    local slot, active = CarrierCritterSlot()
    if active and slot ~= nil and type(CallCompanion) == "function" then
        local ok = pcall(CallCompanion, "CRITTER", slot)
        if ok then
            return true
        end
    end
    return false
end

local function KnownCat(speciesID, speciesName)
    if CAT_SPECIES[tonumber(speciesID) or -1] == true then
        return true
    end
    return type(speciesName) == "string" and CAT_NAMES[speciesName] == true
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
    if not Alive() then
        ApplySummoned(false)
        return false
    end
    local out = CCT.Pet.CatOut()
    if out == nil then
        Paint()
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

local function DragStart()
    if box and box.StartMoving then
        box:StartMoving()
    end
end

local function DragStop()
    if box and box.StopMovingOrSizing then
        box:StopMovingOrSizing()
    end
    SavePoint(box)
end

local function EnsureButton()
    if box or type(CreateFrame) ~= "function" or UIParent == nil then
        return box
    end
    box = CreateFrame("Frame", "CatgirlSummonCatBox", UIParent, "BackdropTemplate")
    box:SetSize(280, 68)
    ApplyPoint(box)
    if box.SetFrameStrata then
        box:SetFrameStrata("HIGH")
    end
    if box.SetClampedToScreen then
        box:SetClampedToScreen(true)
    end
    if box.SetMovable then
        box:SetMovable(true)
    end
    if box.EnableMouse then
        box:EnableMouse(true)
    end
    if box.RegisterForDrag then
        box:RegisterForDrag("LeftButton")
    end
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end
    if box.SetBackdropColor then
        box:SetBackdropColor(0, 0, 0, 0.85)
    end
    box:SetScript("OnDragStart", DragStart)
    box:SetScript("OnDragStop", DragStop)
    button = CreateFrame("Button", "CatgirlSummonCatButton", box, "UIPanelButtonTemplate")
    button:SetSize(256, 22)
    button:SetPoint("TOP", 0, -8)
    if button.RegisterForClicks then
        button:RegisterForClicks("LeftButtonUp")
    end
    if button.RegisterForDrag then
        button:RegisterForDrag("LeftButton")
    end
    button:SetScript("OnDragStart", DragStart)
    button:SetScript("OnDragStop", DragStop)
    button:SetScript("OnClick", function()
        CCT.Pet.Click()
    end)
    statusLine = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if statusLine.SetPoint then
        statusLine:SetPoint("BOTTOM", 0, 8)
    end
    Paint()
    return box
end

function CCT.Pet.Click()
    if InCombat() then
        Say("You cannot summon your cat in combat.")
        return false
    end
    if not Alive() then
        Say("You cannot summon your cat while dead.")
        return false
    end
    if CCT.Pet.CatOut() == true then
        return DismissCollected()
    end
    return SummonCollected()
end

function CCT.Pet.Apply()
    local frame = EnsureButton()
    if frame == nil then
        return false
    end
    CCT.Pet.Refresh()
    if Enabled() then
        frame:Show()
        if button and button.Show then
            button:Show()
        end
    else
        frame:Hide()
        if button and button.Hide then
            button:Hide()
        end
    end
    Paint()
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
        if CCT.State and type(CCT.State.AddCounter) == "function" then
            CCT.State.AddCounter("petMiss", 1)
        end
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
    if checkTicker and type(checkTicker.Cancel) == "function" then
        checkTicker:Cancel()
        checkTicker = nil
    end
    if paintTicker and type(paintTicker.Cancel) == "function" then
        paintTicker:Cancel()
        paintTicker = nil
    end
    if Enabled() and C_Timer and type(C_Timer.NewTicker) == "function" then
        checkTicker = C_Timer.NewTicker(CHECK_SECONDS, function()
            local clock = type(time) == "function" and time() or nil
            CCT.Pet.Check(clock)
        end)
        paintTicker = C_Timer.NewTicker(1, function()
            if not Enabled() then
                return
            end
            if not Alive() then
                if summoned then
                    ApplySummoned(false)
                else
                    Paint()
                end
                return
            end
            CCT.Pet.Refresh()
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
    events:RegisterEvent("COMPANION_UPDATE")
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
        if event == "COMPANION_UPDATE" then
            CCT.Pet.Refresh()
            return
        end
        if event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            CCT.Pet.Refresh()
            if checkWaiting then
                CCT.Pet.Step()
            end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_MACROS" then
            if pendingMacro then
                CCT.Pet.EnsureMacro()
            end
        end
    end)
end
