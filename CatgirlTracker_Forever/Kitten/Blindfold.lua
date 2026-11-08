-- Fullscreen blindfold and the kitten-mask frame sequence.
-- The worn blindfold is CCT.State. Removing a mask does not capture the mouse.
-- Wide screens (UIParent width / height > 2.3) play KittenMaskuwZ1-Z9.
-- Other screens play KittenMaskZ1-Z7, at 0.3 seconds per frame.

local ADDON_NAME, CCT = ...

CCT.Blindfold = {}

local FRAME_SECONDS = 0.3
local WIDE_ASPECT = 2.3

local shown = "none"
local generation = 0
local blindFrame = nil
local maskFrame = nil
local maskTexture = nil

function CCT.Blindfold.MaskSpec(width, height)
    if type(width) ~= "number" or type(height) ~= "number" or height == 0 then
        return "KittenMaskZ", 7
    end
    if (width / height) > WIDE_ASPECT then
        return "KittenMaskuwZ", 9
    end
    return "KittenMaskZ", 7
end

function CCT.Blindfold.MaskPath(prefix, index)
    return CCT.MEDIA .. "Textures\\masks\\" .. prefix .. index .. ".tga"
end

local function EnsureFrames()
    if blindFrame or not CreateFrame or not UIParent then
        return
    end

    blindFrame = CreateFrame("Frame", "CatgirlBlindfoldOverlay", UIParent, "BackdropTemplate")
    blindFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    blindFrame:SetAllPoints(UIParent)
    blindFrame:EnableMouse(false)
    blindFrame:Hide()

    maskFrame = CreateFrame("Frame", "KittenMaskAnimFrame", UIParent)
    maskFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    maskFrame:SetPoint("CENTER")
    maskTexture = maskFrame:CreateTexture(nil, "BACKGROUND")
    maskTexture:SetAllPoints(maskFrame)
    maskFrame:Hide()
end

local function Screen()
    if UIParent and UIParent.GetWidth and UIParent.GetHeight then
        return UIParent:GetWidth(), UIParent:GetHeight()
    end
    return nil, nil
end

local function ScaleMask(width, height)
    if not maskFrame or type(width) ~= "number" or type(height) ~= "number" or height == 0 then
        return
    end
    local aspect = width / height
    local targetW
    if aspect > WIDE_ASPECT then
        targetW = height * (21 / 9)
    else
        targetW = height * (16 / 9)
    end
    maskFrame:SetSize(targetW, height)
end

local function ReleaseMouse()
    if blindFrame then
        blindFrame:EnableMouse(false)
    end
end

local function HideBackdrop()
    if not blindFrame then
        return
    end
    if blindFrame.SetBackdrop then
        blindFrame:SetBackdrop(nil)
    end
    blindFrame:Hide()
end

local function ShowBackdrop(alpha, capture)
    if not blindFrame then
        return
    end
    if blindFrame.SetBackdrop then
        blindFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    end
    if blindFrame.SetBackdropColor then
        blindFrame:SetBackdropColor(0, 0, 0, alpha)
    end
    blindFrame:EnableMouse(capture and true or false)
    blindFrame:Show()
end

local function HideMask()
    if maskTexture then
        maskTexture:SetTexture(nil)
    end
    if maskFrame then
        maskFrame:Hide()
    end
end

local function After(seconds, fn)
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(seconds, fn)
    end
end

local function PlayMask(forward, gen)
    local width, height = Screen()
    local prefix, count = CCT.Blindfold.MaskSpec(width, height)
    ScaleMask(width, height)
    if maskFrame then
        maskFrame:Show()
    end

    local index = forward and 1 or count
    local function step()
        if gen ~= generation then
            return
        end
        if maskTexture then
            maskTexture:SetTexture(CCT.Blindfold.MaskPath(prefix, index))
        end
        if forward then
            index = index + 1
            if index <= count then
                After(FRAME_SECONDS, step)
            end
        else
            index = index - 1
            if index >= 1 then
                After(FRAME_SECONDS, step)
            else
                HideMask()
            end
        end
    end

    step()
end

local function Apply(state)
    local previous = shown
    shown = state
    generation = generation + 1
    local gen = generation
    EnsureFrames()
    ReleaseMouse()

    if state == "light" then
        HideMask()
        ShowBackdrop(0.4, false)
    elseif state == "full" then
        HideMask()
        ShowBackdrop(1, true)
    elseif state == "mask" then
        HideBackdrop()
        PlayMask(true, gen)
    else
        HideBackdrop()
        if previous == "mask" then
            PlayMask(false, gen)
        else
            HideMask()
        end
    end
end

local function Read()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return "none"
    end
    local blind = state.blind
    if blind ~= "light" and blind ~= "mask" and blind ~= "full" then
        return "none"
    end
    return blind
end

local function Sync()
    local blind = Read()
    if blind == shown then
        return
    end
    Apply(blind)
end

function CCT.Blindfold.Set(value)
    if not CCT.State or not CCT.State.SetBlind then
        return false
    end
    return CCT.State.SetBlind(value) == true
end

function CCT.Blindfold.OnEvent(_, event, arg1)
    if event == "UNIT_NAME_UPDATE" and arg1 ~= "player" then
        return
    end
    Sync()
end

if CCT.State and CCT.State.Listen then
    CCT.State.Listen(Sync)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    frame:SetScript("OnEvent", CCT.Blindfold.OnEvent)
end
