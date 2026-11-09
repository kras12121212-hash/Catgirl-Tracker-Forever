-- Chastity belt, bra, and the deny shock.
-- Belt mode is ignored while the belt is off. Removing the belt forces allow.
-- A denied orgasm sets heat to 70. There is no session-start log row.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Chastity = {}

local SHOCK_SECONDS = 5
local DENY_HEAT = 70
local SHOCK_FILE = "Textures\\BeltShockDeny.tga"

CCT.Chastity.SHOCK_SECONDS = SHOCK_SECONDS
CCT.Chastity.DENY_HEAT = DENY_HEAT

local shockFrame = nil
local shockToken = 0

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

local function OwnerShort()
    if CCT.Roster and CCT.Roster.GetOwnerShort then
        return CCT.Roster.GetOwnerShort()
    end
    return nil
end

local function EnsureShock()
    if shockFrame or not CreateFrame or not UIParent then
        return shockFrame
    end
    shockFrame = CreateFrame("Frame", "CatgirlChastityShockFrame", UIParent)
    shockFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    shockFrame:SetAllPoints(UIParent)
    local texture = shockFrame:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    shockFrame.texture = texture
    shockFrame:Hide()
    return shockFrame
end

local function TextureFailed(texture, path)
    if not texture or not texture.SetTexture then
        return true
    end
    local result = texture:SetTexture(path)
    if result == false then
        return true
    end
    if texture.GetTexture and texture:GetTexture() == nil then
        return true
    end
    return false
end

local function ShowShock()
    local frame = EnsureShock()
    if not frame then
        return
    end
    local path = (CCT.MEDIA or "") .. SHOCK_FILE
    if TextureFailed(frame.texture, path) then
        frame:Hide()
        return
    end
    frame:Show()
    shockToken = shockToken + 1
    local token = shockToken
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(SHOCK_SECONDS, function()
            if shockFrame and shockToken == token then
                shockFrame:Hide()
            end
        end)
    end
end

local function State()
    if CCT.State and CCT.State.Get then
        return CCT.State.Get()
    end
    return nil
end

function CCT.Chastity.SetBelt(on, sender)
    local state = State()
    if type(state) ~= "table" or not CCT.State.SetBelt then
        return false, "state"
    end
    local flag = on == true
    if on ~= true and on ~= false then
        return false, "on"
    end
    if state.belt == flag and (flag or state.beltMode == "allow") then
        return true, nil, true
    end
    if not CCT.State.SetBelt(flag) then
        return false, "state"
    end
    local key = flag and "CHASTITY_BELT_APPLY" or "CHASTITY_BELT_REMOVE"
    Whisper(sender, CCT.Msg(key))
    if flag then
        Raid("Chastity belt locked.")
    else
        Raid("Chastity belt removed.")
    end
    return true
end

function CCT.Chastity.SetBra(on, sender)
    local state = State()
    if type(state) ~= "table" or not CCT.State.SetBra then
        return false, "state"
    end
    if on ~= true and on ~= false then
        return false, "on"
    end
    local flag = on == true
    if state.bra == flag then
        return true, nil, true
    end
    if not CCT.State.SetBra(flag) then
        return false, "state"
    end
    local key = flag and "CHASTITY_BRA_APPLY" or "CHASTITY_BRA_REMOVE"
    Whisper(sender, CCT.Msg(key))
    if flag then
        Raid("Chastity bra locked.")
    else
        Raid("Chastity bra removed.")
    end
    return true
end

function CCT.Chastity.SetMode(mode, sender)
    if mode ~= "allow" and mode ~= "deny" then
        return false, "mode"
    end
    local state = State()
    if type(state) ~= "table" or state.belt ~= true then
        return false, "belt"
    end
    if state.beltMode == mode then
        return true, nil, true
    end
    if not CCT.State.SetBeltMode(mode) then
        return false, "belt"
    end
    local key = mode == "deny" and "CHASTITY_BELT_DENY" or "CHASTITY_BELT_ALLOW"
    Whisper(sender, CCT.Msg(key))
    if mode == "deny" then
        Raid("Chastity belt set to Deny Orgasm.")
    else
        Raid("Chastity belt set to Allow Orgasm.")
    end
    return true
end

local function AddDenied()
    local short = CCT.Player and CCT.Player.short
    if type(short) == "string" and CCT.Saved and CCT.Saved.EnsureChar then
        local char = CCT.Saved.EnsureChar(short)
        if type(char) == "table" then
            if type(char.life) ~= "table" then
                char.life = { denied = 0, orgasms = {}, denials = {} }
            end
            char.life.denied = (tonumber(char.life.denied) or 0) + 1
            if type(char.life.denials) ~= "table" then
                char.life.denials = {}
            end
            if CCT.Submissiveness and type(CCT.Submissiveness.PushStamp) == "function" then
                CCT.Submissiveness.PushStamp(char.life.denials, CCT.UnixNow())
            end
        end
    end
    if CCT.State and CCT.State.AddCounter then
        CCT.State.AddCounter("deny", 1)
    end
end

function CCT.Chastity.OnOrgasmAttempt()
    local state = State()
    if type(state) ~= "table" then
        return true, nil
    end
    if state.belt == true and state.beltMode == "deny" then
        ShowShock()
        AddDenied()
        if CCT.State.SetHeat then
            CCT.State.SetHeat(DENY_HEAT)
        end
        local owner = OwnerShort()
        Whisper(owner, CCT.Msg("CHASTITY_DENY_SHOCK"))
        Raid("Chastity belt denied an orgasm.")
        return false, DENY_HEAT
    end
    return true, nil
end
