-- Locking heels. Worn style and level go through CCT.State.
-- The speed ring, the 30-boolean window, the walk tenths, and the counted
-- chunk seconds stay in memory. A reload drops them. Levels stay on state.
-- Movement comes from CCT.Move.Sample. A secret sample is hidden and is not compared.
-- This file does not send addon messages.

local ADDON_NAME, CCT = ...

CCT.Heels = {}

local SAMPLE_COUNT = 12
local WINDOW = 30
local TICK = 0.1
local CHUNK_SECONDS = 5
-- Integer tenths avoid a missed 5-second chunk when 0.1 does not add cleanly.
local CHUNK_TENTHS = 50
local MIN_RATIO = 0.45
local RESET_RATIO = 1
local MAX_LEVEL = 20
local PER_LEVEL = 0.05
local SOUND_INTERVAL = 7.0
local WARNING_COOLDOWN = 1.2
local OVERLAY_SECONDS = 5
local WARNING = "Kitten is Wearing High Heels you Cant Run or you will Fall !\n(Use Slow walk)"

local BASE = { maid = 3.5, high = 2.0, ballet = 1.4 }
local DISPLAY = { maid = "Maid Heels", high = "High Heels", ballet = "Ballet Boots" }
local SOUND_FILE = {
    maid = "HighHeels3.wav",
    high = "HighHeels8.wav",
    ballet = "HighHeels12.wav",
}
local FAIL_FILE = {
    maid = "Textures\\heels\\maid-heels.tga",
    high = "Textures\\heels\\high-heels.tga",
    ballet = "Textures\\heels\\ballet-boots.tga",
}
local KINDS = { "maid", "high", "ballet" }

CCT.Heels.SAMPLE_COUNT = SAMPLE_COUNT
CCT.Heels.WINDOW = WINDOW
CCT.Heels.TICK = TICK
CCT.Heels.CHUNK = CHUNK_SECONDS
CCT.Heels.MIN_RATIO = MIN_RATIO
CCT.Heels.SOUND_INTERVAL = SOUND_INTERVAL

local memory = {}
local ring = { values = {}, sum = 0 }
local active = "none"
local failActive = false
local expireAt = nil
local lastWarningAt = 0
local warningActive = false
local warningTicker = nil
local soundTicker = nil
local soundActive = false
local soundHandle = nil
local speedBar = nil
local progressBar = nil
local failureOverlay = nil

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

function CCT.Heels.NewProgress()
    return { seconds = 0, window = {}, trues = 0, walk = 0 }
end

for i = 1, #KINDS do
    memory[KINDS[i]] = CCT.Heels.NewProgress()
end

function CCT.Heels.Progress(kind)
    return memory[kind]
end

function CCT.Heels.FailureExpire()
    return expireAt
end

function CCT.Heels.Allowed(kind, level)
    local base = BASE[kind]
    if base == nil then
        return nil
    end
    local n = math.floor(tonumber(level) or 1)
    if n < 1 then
        n = 1
    end
    if n > MAX_LEVEL then
        n = MAX_LEVEL
    end
    return base + (n - 1) * PER_LEVEL
end

function CCT.Heels.LevelSeconds(level)
    local n = math.floor(tonumber(level) or 1)
    if n < 1 then
        n = 1
    end
    return 180 + n * 60
end

function CCT.Heels.ClearProgress(progress)
    progress.seconds = 0
    progress.window = {}
    progress.trues = 0
    progress.walk = 0
end

function CCT.Heels.ResetWindow(progress)
    progress.window = {}
    progress.trues = 0
    progress.walk = 0
end

function CCT.Heels.PushSample(target, yards)
    local values = target.values
    values[#values + 1] = yards
    target.sum = target.sum + yards
    if #values > SAMPLE_COUNT then
        target.sum = target.sum - table.remove(values, 1)
    end
    return target.sum / #values
end

function CCT.Heels.Advance(progress, avg, allowed, moving)
    local above = avg >= (allowed * MIN_RATIO)
    local samples = progress.window
    samples[#samples + 1] = above
    if above then
        progress.trues = progress.trues + 1
    end
    if #samples > WINDOW then
        local removed = table.remove(samples, 1)
        if removed then
            progress.trues = progress.trues - 1
        end
    end
    if avg > (allowed * RESET_RATIO) then
        CCT.Heels.ClearProgress(progress)
        return "reset"
    end
    if moving then
        progress.walk = progress.walk + 1
        while progress.walk >= CHUNK_TENTHS do
            if #progress.window >= WINDOW and progress.trues == WINDOW then
                progress.seconds = progress.seconds + CHUNK_SECONDS
            end
            progress.walk = progress.walk - CHUNK_TENTHS
        end
    end
    return nil
end

function CCT.Heels.TakeLevel(progress, level)
    if level >= MAX_LEVEL or progress.seconds < CCT.Heels.LevelSeconds(level) then
        return false
    end
    CCT.Heels.ClearProgress(progress)
    return true
end

local function ResetRing()
    ring.values = {}
    ring.sum = 0
end

local function Worn()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return "none", 1
    end
    local kind = state.heels
    if kind ~= "maid" and kind ~= "high" and kind ~= "ballet" then
        return "none", 1
    end
    local level = 1
    if type(state.heelLevel) == "table" then
        level = tonumber(state.heelLevel[kind]) or 1
    end
    return kind, level
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

function CCT.Heels.Set(sender, value)
    if not OwnerOk(sender) then
        return false
    end
    if value ~= "none" and value ~= "maid" and value ~= "high" and value ~= "ballet" then
        return false
    end
    if not CCT.State or not CCT.State.SetHeels then
        return false
    end
    return CCT.State.SetHeels(value) == true
end

local function FlavorOn()
    local settings = CCT.db and CCT.db.settings
    return settings ~= nil and settings.flavorAnnouncements == true
end

local function Say(chatType, text)
    if not FlavorOn() or chatType == nil or text == nil then
        return
    end
    if CCT.Chat and CCT.Chat.Send then
        CCT.Chat.Send(text, chatType)
    end
end

local function GroupChannel()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE ~= nil and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function KittenName()
    if CCT.Player and type(CCT.Player.short) == "string" and CCT.Player.short ~= "" then
        return CCT.Player.short
    end
    return "Kitten"
end

local function SendFail(kind, level)
    local text = CCT.Msg("HEELS_FAIL", KittenName(), DISPLAY[kind] or "Heels", level)
    Say("GUILD", text)
    local group = GroupChannel()
    if group ~= nil then
        Say(group, text)
    end
end

local function SendProgress(kind, level)
    Say("GUILD", CCT.Msg("HEELS_PROGRESS", KittenName(), DISPLAY[kind] or "Heels", level))
end

local function StopHeelSound()
    soundActive = false
    if soundTicker and soundTicker.Cancel then
        soundTicker:Cancel()
    end
    soundTicker = nil
    if type(soundHandle) == "number" and type(StopSound) == "function" then
        StopSound(soundHandle)
    end
    soundHandle = nil
end

local function PlayFile()
    local file = SOUND_FILE[active]
    if file == nil or type(PlaySoundFile) ~= "function" then
        return
    end
    if type(soundHandle) == "number" and type(StopSound) == "function" then
        StopSound(soundHandle)
    end
    local first, second = PlaySoundFile(Media("Sounds\\" .. file), "Master")
    if type(first) == "number" then
        soundHandle = first
    elseif type(second) == "number" then
        soundHandle = second
    else
        soundHandle = nil
    end
end

local function StartSound()
    if soundActive then
        return
    end
    soundActive = true
    PlayFile()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        soundTicker = C_Timer.NewTicker(SOUND_INTERVAL, function()
            if not soundActive or active == "none" then
                return
            end
            PlayFile()
        end)
    end
end

local function DriveSound(action)
    if action == "play" then
        local started = not soundActive
        StartSound()
        if CCT.Report and type(CCT.Report.HeelProx) == "function" then
            if started then
                CCT.Report.HeelProx(active, "start")
            end
            CCT.Report.HeelProx(active, "ping")
        end
    elseif action == "stop" then
        local wasPlaying = soundActive
        StopHeelSound()
        if wasPlaying and CCT.Report and type(CCT.Report.HeelProx) == "function" then
            CCT.Report.HeelProx(active, "stop")
        end
    end
end

local function EnsureOverlay()
    if failureOverlay or not CreateFrame or not UIParent then
        return failureOverlay
    end
    failureOverlay = CreateFrame("Frame", "CatgirlHeelsFailureOverlay", UIParent)
    failureOverlay:SetAllPoints(UIParent)
    failureOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
    failureOverlay:EnableMouse(false)
    failureOverlay:Hide()
    local texture = failureOverlay:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetAlpha(1)
    failureOverlay.texture = texture
    return failureOverlay
end

local function HideOverlay()
    expireAt = nil
    if failureOverlay then
        failureOverlay.expireAt = nil
        failureOverlay:Hide()
    end
end

local function ShowOverlay(kind, now)
    local frame = EnsureOverlay()
    expireAt = now + OVERLAY_SECONDS
    if not frame then
        return
    end
    frame.expireAt = expireAt
    local file = FAIL_FILE[kind]
    if frame.texture and frame.texture.SetTexture and file then
        frame.texture:SetTexture(Media(file))
    end
    frame:Show()
end

local function ExpireOverlay(now)
    if expireAt == nil or now < expireAt then
        return
    end
    HideOverlay()
end

local function BarBackdrop(bar)
    if bar.SetBackdrop then
        bar:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
    end
    if bar.SetBackdropColor then
        bar:SetBackdropColor(0, 0, 0, 0.6)
    end
end

local function EnsureBars()
    if speedBar or not CreateFrame or not UIParent then
        return
    end
    speedBar = CreateFrame("StatusBar", "CatgirlHeelsSpeedBar", UIParent, "BackdropTemplate")
    speedBar:SetSize(240, 16)
    speedBar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    speedBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    speedBar:SetMinMaxValues(0, 1)
    speedBar:SetValue(0)
    speedBar:SetStatusBarColor(0.2, 0.75, 0.2)
    BarBackdrop(speedBar)
    speedBar:Hide()
    speedBar.text = speedBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    speedBar.text:SetPoint("CENTER")

    progressBar = CreateFrame("StatusBar", "CatgirlHeelsProgressBar", UIParent, "BackdropTemplate")
    progressBar:SetSize(240, 14)
    progressBar:SetPoint("TOP", speedBar, "BOTTOM", 0, -6)
    progressBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(0)
    progressBar:SetStatusBarColor(0.4, 0.6, 1)
    BarBackdrop(progressBar)
    progressBar:Hide()
    progressBar.text = progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressBar.text:SetPoint("CENTER")
end

local function HideBars()
    if speedBar then
        speedBar:Hide()
    end
    if progressBar then
        progressBar:Hide()
    end
end

local function UpdateBars(avg, allowed, progress, level)
    EnsureBars()
    if not speedBar or not progressBar or allowed == nil then
        return
    end
    speedBar:Show()
    speedBar:SetMinMaxValues(0, allowed)
    local value = avg
    if value < 0 then
        value = 0
    end
    if value > allowed then
        value = allowed
    end
    speedBar:SetValue(value)
    if avg >= allowed then
        speedBar:SetStatusBarColor(1, 0.2, 0.2)
    else
        local ratio = 0
        if allowed > 0 then
            ratio = avg / allowed
        end
        speedBar:SetStatusBarColor(math.min(1, ratio * 1.2), math.min(1, 1 - ratio * 0.5), 0.2)
    end
    if speedBar.text and speedBar.text.SetText then
        speedBar.text:SetText(string.format("Balance bar %.2f / %.2f", avg, allowed))
    end

    local required = CCT.Heels.LevelSeconds(level)
    progressBar:Show()
    progressBar:SetMinMaxValues(0, required)
    local seconds = progress.seconds or 0
    if seconds < 0 then
        seconds = 0
    end
    if seconds > required then
        seconds = required
    end
    progressBar:SetValue(seconds)
    if progressBar.text and progressBar.text.SetText then
        progressBar.text:SetText(string.format("Level %d: %.0f / %.0fs", level, progress.seconds or 0, required))
    end
end

local function ShowWarning(now)
    if now - lastWarningAt < WARNING_COOLDOWN then
        return
    end
    lastWarningAt = now
    warningActive = true
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, WARNING, ChatTypeInfo.RAID_WARNING)
    end
end

local function ClearWarning()
    if not warningActive then
        return
    end
    warningActive = false
    if RaidNotice_Clear and RaidWarningFrame then
        RaidNotice_Clear(RaidWarningFrame)
    elseif RaidWarningFrame and RaidWarningFrame.Hide then
        RaidWarningFrame:Hide()
    end
end

function CCT.Heels.ApplySample(sample, now)
    local result = {
        sound = "hold",
        advanced = false,
        over = false,
        failed = false,
        reset = false,
        levelUp = false,
    }
    if active == "none" then
        return result
    end
    if type(sample) ~= "table" or sample.kind == "hidden" then
        return result
    end
    if sample.kind == "bool" then
        if sample.moving == true then
            result.sound = "play"
        elseif sample.moving == false then
            result.sound = "stop"
        end
        DriveSound(result.sound)
        return result
    end
    if sample.kind ~= "speed" or type(sample.yards) ~= "number" then
        return result
    end

    local _, level = Worn()
    local allowed = CCT.Heels.Allowed(active, level)
    local avg = CCT.Heels.PushSample(ring, sample.yards)
    local moving = sample.yards > 0
    result.sound = moving and "play" or "stop"
    result.average = avg
    result.allowed = allowed
    DriveSound(result.sound)
    if allowed == nil then
        return result
    end

    local progress = memory[active]
    local step = CCT.Heels.Advance(progress, avg, allowed, moving)
    result.advanced = true
    result.reset = step == "reset"
    result.over = avg > allowed
    UpdateBars(avg, allowed, progress, level)

    if result.over then
        if not failActive then
            failActive = true
            result.failed = true
            SendFail(active, level)
        end
        ShowWarning(now)
        ShowOverlay(active, now)
        return result
    end

    failActive = false
    ClearWarning()
    if CCT.Heels.TakeLevel(progress, level) then
        local newLevel = level + 1
        result.levelUp = true
        if CCT.State and CCT.State.SetHeelLevel then
            CCT.State.SetHeelLevel(active, newLevel)
        end
        SendProgress(active, newLevel)
        UpdateBars(avg, CCT.Heels.Allowed(active, newLevel), progress, newLevel)
    end
    return result
end

function CCT.Heels.Tick()
    if active == "none" then
        return nil
    end
    local now = Now()
    ExpireOverlay(now)
    local sample = { kind = "hidden" }
    if CCT.Move and CCT.Move.Sample then
        sample = CCT.Move.Sample()
    end
    return CCT.Heels.ApplySample(sample, now)
end

local function StopWarning()
    if warningTicker and warningTicker.Cancel then
        warningTicker:Cancel()
    end
    warningTicker = nil
    ClearWarning()
end

local function StartWarning()
    if warningTicker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    warningTicker = C_Timer.NewTicker(TICK, CCT.Heels.Tick)
end

local function Sync()
    local kind = Worn()
    if kind == active then
        return
    end
    local previous = active
    active = kind
    failActive = false
    lastWarningAt = 0
    StopHeelSound()
    HideOverlay()
    ResetRing()
    if kind == "none" then
        if memory[previous] then
            CCT.Heels.ResetWindow(memory[previous])
        end
        StopWarning()
        HideBars()
        return
    end
    if previous ~= kind and memory[kind] then
        CCT.Heels.ResetWindow(memory[kind])
    end
    StartWarning()
end

function CCT.Heels.OnEvent(_, event)
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
    frame:SetScript("OnEvent", CCT.Heels.OnEvent)
end
