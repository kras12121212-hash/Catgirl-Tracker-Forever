-- Heat decay, control heat, the orgasm flash, and the heat bar.
-- Writers go through CCT.State. The offline gap is state.lastUnixUpdate.
-- A due owner push is remembered and not whispered.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Heat = {}

local ORGASM_AT = 100
local FLASH_NAME = "CatgirlHeatOrgasmFlash"
local BAR_NAME = "CatgirlHeatBar"
local ORGASM_CAP = 50

local decayExponent = 0.7
local decayK = 0.2
local elapsed = {}
local wasOn = {}
local ticker = nil
local lastTickAt = nil
local offlineDone = false
local heatBar = nil
local flashFrame = nil
local flashToken = 0
local lastPushHeat = nil
local lastPushAt = nil

CCT.Heat.pending = nil
CCT.Heat.pendingCount = 0
CCT.Heat.Config = CCT.HeatConfig

local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local function Cfg()
    if type(CCT.HeatConfig) == "table" then
        CCT.Heat.Config = CCT.HeatConfig
        return CCT.HeatConfig
    end
    return nil
end

local function State()
    if CCT.State and CCT.State.Get then
        return CCT.State.Get()
    end
    return nil
end

local function ClampHeat(value)
    local heat = tonumber(value) or 0
    if heat < 0 then
        return 0
    end
    if heat > ORGASM_AT then
        return ORGASM_AT
    end
    return heat
end

local function Shown(value)
    return math.floor(ClampHeat(value) + 0.5)
end

function CCT.Heat.Rebuild()
    local cfg = Cfg()
    local decay = cfg and cfg.decay
    local ratio = tonumber(decay and decay.ratio100to10) or 5
    if ratio <= 1.01 then
        ratio = 1.01
    end
    local exponent = math.log(ratio) / math.log(10)
    if exponent >= 0.999 then
        exponent = 0.999
    end
    local totalSeconds = tonumber(decay and decay.totalSeconds) or 1200
    if totalSeconds < 60 then
        totalSeconds = 60
    end
    decayExponent = exponent
    decayK = 100 / (totalSeconds * (1 - decayExponent))
end

function CCT.Heat.Constants()
    return {
        exponent = decayExponent,
        k = decayK,
    }
end

function CCT.Heat.Decay(value, dt)
    local heat = tonumber(value) or 0
    local step = tonumber(dt) or 0
    if heat <= 0 or step <= 0 then
        return ClampHeat(heat)
    end
    local u = heat / 100
    if decayExponent == 1 then
        local decay = math.exp(-(decayK / 100) * step)
        return ClampHeat(u * decay * 100)
    end
    local power = u ^ (1 - decayExponent)
    power = power - (decayK / 100) * (1 - decayExponent) * step
    if power <= 0 then
        return 0
    end
    return ClampHeat((power ^ (1 / (1 - decayExponent))) * 100)
end

local function FlipLimit(submissiveness)
    local cfg = Cfg()
    local map = cfg and cfg.submissivenessHeatFlip
    if type(map) ~= "table" or tonumber(submissiveness) == nil then
        return nil
    end
    local bestThreshold = nil
    local bestLimit = nil
    local function Consider(threshold, limit)
        local threshNum = tonumber(threshold)
        local limitNum = tonumber(limit)
        if not threshNum or not limitNum then
            return
        end
        if limitNum > 0 then
            limitNum = -limitNum
        end
        if submissiveness >= threshNum then
            if not bestThreshold or threshNum > bestThreshold then
                bestThreshold = threshNum
                bestLimit = limitNum
            end
        end
    end
    if #map > 0 then
        for _, entry in ipairs(map) do
            if type(entry) == "table" then
                Consider(entry.submissiveness or entry.threshold or entry.level or entry[1],
                    entry.maxNegative or entry.limit or entry.value or entry[2])
            end
        end
    end
    for threshold, limit in pairs(map) do
        if type(threshold) == "number" then
            Consider(threshold, limit)
        end
    end
    return bestLimit
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

function CCT.Heat.Color(value)
    local cfg = Cfg()
    local colors = (cfg and cfg.colors) or {}
    local low = colors.low or { 0.0, 0.45, 1.0 }
    local mid = colors.mid or { 1.0, 0.35, 0.75 }
    local high = colors.high or { 1.0, 0.0, 0.0 }
    local pct = ClampHeat(value) / 100
    if pct <= 0.5 then
        local t = pct / 0.5
        return Lerp(low[1], mid[1], t), Lerp(low[2], mid[2], t), Lerp(low[3], mid[3], t)
    end
    local t = (pct - 0.5) / 0.5
    return Lerp(mid[1], high[1], t), Lerp(mid[2], high[2], t), Lerp(mid[3], high[3], t)
end

local function Char()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" or not CCT.Saved or not CCT.Saved.EnsureChar then
        return nil
    end
    return CCT.Saved.EnsureChar(short)
end

local function HasOwner()
    if not CCT.Roster or not CCT.Roster.GetOwnerShort then
        return false
    end
    local owner = CCT.Roster.GetOwnerShort()
    return type(owner) == "string" and owner ~= ""
end

local function SaveBar(bar, key)
    if not bar or type(bar.GetPoint) ~= "function" then
        return
    end
    local point, _, relativePoint, x, y = bar:GetPoint(1)
    if type(point) ~= "string" then
        return
    end
    local char = Char()
    if type(char) ~= "table" then
        return
    end
    if type(char.bars) ~= "table" then
        char.bars = {}
    end
    char.bars[key] = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function RestoreBar(bar, key, fallbackX, fallbackY)
    if not bar or type(bar.ClearAllPoints) ~= "function" or type(bar.SetPoint) ~= "function" then
        return
    end
    bar:ClearAllPoints()
    local char = Char()
    local pos = char and char.bars and char.bars[key]
    if type(pos) == "table" and type(pos.point) == "string" then
        bar:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
        return
    end
    bar:SetPoint("CENTER", UIParent, "CENTER", fallbackX, fallbackY)
end

local function UpdateBar()
    if not heatBar then
        return
    end
    local value = ClampHeat(State() and State().heat)
    if heatBar.SetMinMaxValues then
        heatBar:SetMinMaxValues(0, 100)
    end
    if heatBar.SetValue then
        heatBar:SetValue(value)
    end
    if heatBar.SetStatusBarColor then
        heatBar:SetStatusBarColor(CCT.Heat.Color(value))
    end
    if heatBar.text and heatBar.text.SetText then
        heatBar.text:SetText(string.format("Kitten Heat Bar: %d", Shown(value)))
    end
end

local function EnsureBar()
    if heatBar or not CreateFrame or not UIParent then
        return heatBar
    end
    local cfg = Cfg()
    local barCfg = cfg and cfg.bar or {}
    heatBar = CreateFrame("StatusBar", BAR_NAME, UIParent, "BackdropTemplate")
    if heatBar.SetSize then
        heatBar:SetSize(barCfg.width or 240, barCfg.height or 18)
    end
    if heatBar.SetStatusBarTexture then
        heatBar:SetStatusBarTexture(barCfg.texture or "Interface\\TARGETINGFRAME\\UI-StatusBar")
    end
    if heatBar.SetMinMaxValues then
        heatBar:SetMinMaxValues(0, 100)
    end
    if heatBar.SetValue then
        heatBar:SetValue(0)
    end
    if heatBar.SetBackdrop then
        heatBar:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
    end
    if heatBar.SetBackdropColor then
        heatBar:SetBackdropColor(0, 0, 0, 0.6)
    end
    if heatBar.CreateFontString then
        heatBar.text = heatBar:CreateFontString(nil, "OVERLAY", barCfg.font or "GameFontHighlightSmall")
        if heatBar.text and heatBar.text.SetPoint then
            heatBar.text:SetPoint("CENTER")
        end
    end
    if heatBar.SetMovable then
        heatBar:SetMovable(true)
    end
    if heatBar.EnableMouse then
        heatBar:EnableMouse(true)
    end
    if heatBar.RegisterForDrag then
        heatBar:RegisterForDrag("LeftButton")
    end
    if heatBar.SetScript then
        heatBar:SetScript("OnDragStart", function(self)
            local current = Cfg()
            if current and current.bar and current.bar.locked then
                return
            end
            if self.StartMoving then
                self:StartMoving()
            end
        end)
        heatBar:SetScript("OnDragStop", function(self)
            if self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end
            SaveBar(self, "heat")
        end)
    end
    RestoreBar(heatBar, "heat", 0, -200)
    if heatBar.Hide then
        heatBar:Hide()
    end
    return heatBar
end

local function TextureFailed(texture, path)
    if not texture or type(texture.SetTexture) ~= "function" then
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

local function MediaPath(relative)
    local text = tostring(relative or "Textures/orgasm.toc")
    if text:find("Interface\\", 1, true) or text:find("Interface/", 1, true) then
        return text
    end
    return (CCT.MEDIA or "") .. text:gsub("/", "\\")
end

local function EnsureFlash()
    if flashFrame or not CreateFrame or not UIParent then
        return flashFrame
    end
    flashFrame = CreateFrame("Frame", FLASH_NAME, UIParent)
    if flashFrame.SetFrameStrata then
        flashFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    if flashFrame.SetAllPoints then
        flashFrame:SetAllPoints(UIParent)
    end
    if flashFrame.CreateTexture then
        local texture = flashFrame:CreateTexture(nil, "OVERLAY")
        if texture.SetAllPoints then
            texture:SetAllPoints()
        end
        flashFrame.texture = texture
    end
    if flashFrame.Hide then
        flashFrame:Hide()
    end
    return flashFrame
end

local function ShowFlash()
    local frame = EnsureFlash()
    if not frame then
        return
    end
    local cfg = Cfg()
    local orgasm = cfg and cfg.orgasm or {}
    local alpha = tonumber(orgasm.alpha) or 0.9
    local duration = tonumber(orgasm.flashDuration) or 0.6
    if frame.SetAlpha then
        frame:SetAlpha(alpha)
    end
    if TextureFailed(frame.texture, MediaPath(orgasm.texture)) then
        if frame.Hide then
            frame:Hide()
        end
        return
    end
    if frame.Show then
        frame:Show()
    end
    flashToken = flashToken + 1
    local token = flashToken
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(duration, function()
            if flashFrame and flashToken == token and flashFrame.Hide then
                flashFrame:Hide()
            end
        end)
    end
end

local function RecordOrgasm(now)
    local char = Char()
    if type(char) == "table" then
        if type(char.life) ~= "table" then
            char.life = { denied = 0, orgasms = {} }
        end
        if type(char.life.orgasms) ~= "table" then
            char.life.orgasms = {}
        end
        local list = char.life.orgasms
        local total = tonumber(char.life.total) or #list
        char.life.total = total + 1
        list[#list + 1] = tonumber(now) or CCT.UnixNow()
        while #list > ORGASM_CAP do
            table.remove(list, 1)
        end
    end
    if CCT.State and CCT.State.AddCounter then
        CCT.State.AddCounter("orgasm", 1)
    end
end

function CCT.Heat.Add(amount)
    local gain = tonumber(amount) or 0
    if gain <= 0 then
        return
    end
    local state = State()
    if type(state) ~= "table" or not CCT.State.SetHeat then
        return
    end
    local heat = (tonumber(state.heat) or 0) + gain
    if heat >= ORGASM_AT then
        CCT.State.SetHeat(ORGASM_AT)
        local allowed = true
        if CCT.Chastity and type(CCT.Chastity.OnOrgasmAttempt) == "function" then
            allowed = CCT.Chastity.OnOrgasmAttempt()
        end
        if allowed == false then
            UpdateBar()
            return
        end
        RecordOrgasm(CCT.UnixNow())
        ShowFlash()
        CCT.State.SetHeat(0)
        UpdateBar()
        return
    end
    CCT.State.SetHeat(heat)
    UpdateBar()
end

function CCT.Heat.AddDelta(amount)
    local delta = tonumber(amount)
    if not delta or delta == 0 then
        return
    end
    if delta > 0 then
        CCT.Heat.Add(delta)
        return
    end
    local state = State()
    if type(state) ~= "table" or not CCT.State.SetHeat then
        return
    end
    local submissiveness = tonumber(state.sub)
    if submissiveness then
        local limit = FlipLimit(submissiveness)
        if limit and delta >= limit then
            CCT.Heat.Add(-delta)
            return
        end
    end
    CCT.State.SetHeat((tonumber(state.heat) or 0) + delta)
    UpdateBar()
end

function CCT.Heat.Get()
    local state = State()
    if type(state) ~= "table" then
        return 0
    end
    return tonumber(state.heat) or 0
end

local function ToyRow(state, id)
    local toys = state.toys
    if type(toys) ~= "table" then
        return nil
    end
    local row = toys[id]
    if type(row) ~= "table" or row.applied ~= true then
        return nil
    end
    return row
end

local function ControlOn(key, state)
    if key == "heels_maid" then
        return state.heels == "maid"
    end
    if key == "heels_high" then
        return state.heels == "high"
    end
    if key == "heels_ballet" then
        return state.heels == "ballet"
    end
    if key == "mittens" then
        return state.mittens ~= nil and state.mittens ~= "none"
    end
    if key == "gag" then
        return state.gag ~= nil and state.gag ~= "none"
    end
    if key == "blindfold" then
        return state.blind ~= nil and state.blind ~= "none"
    end
    if key == "earmuffs_kitten" then
        return state.ears == "kitten"
    end
    if key == "earmuffs_heavy" then
        return state.ears == "heavy"
    end
    if key == "bell" then
        return state.bell == true
    end
    if key == "tailbell" then
        return state.tail == true
    end
    if key == "leash" then
        return state.leash == true
    end
    local id, stage = key:match("^toy_(.+)_vibe_(%d+)$")
    if id then
        local row = ToyRow(state, id)
        return row ~= nil and tonumber(row.vibe) == tonumber(stage)
    end
    id, stage = key:match("^toy_(.+)_inflate_(%d+)$")
    if id then
        local row = ToyRow(state, id)
        return row ~= nil and tonumber(row.inflate) == tonumber(stage)
    end
    id = key:match("^toy_(.+)_base$")
    if id then
        return ToyRow(state, id) ~= nil
    end
    return false
end

function CCT.Heat.ApplyControls(dt)
    local state = State()
    if type(state) ~= "table" then
        return
    end
    local cfg = Cfg()
    local list = cfg and cfg.controls
    if type(list) ~= "table" then
        return
    end
    local step = tonumber(dt) or 0
    if step <= 0 then
        return
    end
    for i = 1, #list do
        local control = list[i]
        if type(control) == "table" and control.enabled ~= false then
            local key = control.key or tostring(i)
            local on = ControlOn(key, state) == true
            if wasOn[key] ~= on then
                wasOn[key] = on
                elapsed[key] = 0
            end
            if on then
                local interval = tonumber(control.intervalSeconds) or 0
                local heat = tonumber(control.heat) or 0
                if interval > 0 and heat ~= 0 then
                    elapsed[key] = (elapsed[key] or 0) + step
                    local guard = 0
                    while elapsed[key] >= interval and guard < 10000 do
                        elapsed[key] = elapsed[key] - interval
                        guard = guard + 1
                        CCT.Heat.Add(heat)
                        state = State() or state
                    end
                end
            end
        end
    end
end

local function NotePush(now)
    local state = State()
    if type(state) ~= "table" then
        return
    end
    local cfg = Cfg()
    local interval = tonumber(cfg and cfg.syncIntervalSeconds) or 10
    local minDelta = tonumber(cfg and cfg.syncMinDelta) or 1
    if interval < 0 then
        interval = 0
    end
    local shown = Shown(state.heat)
    local stamp = tonumber(now) or CCT.UnixNow()
    if lastPushHeat == nil then
        lastPushHeat = shown
        lastPushAt = stamp
        return
    end
    if math.abs(shown - lastPushHeat) < minDelta then
        return
    end
    if stamp - (lastPushAt or 0) < interval then
        return
    end
    lastPushHeat = shown
    lastPushAt = stamp
    CCT.Heat.pending = shown
    CCT.Heat.pendingCount = (CCT.Heat.pendingCount or 0) + 1
end

function CCT.Heat.ApplyOffline(now)
    local state = State()
    if type(state) ~= "table" or not CCT.State.SetHeat or not CCT.State.TouchClock then
        return false
    end
    CCT.Heat.Rebuild()
    local stamp = state.lastUnixUpdate
    local unix = tonumber(now) or CCT.UnixNow()
    if type(stamp) == "number" and stamp > 0 then
        local gap = unix - stamp
        if gap > 0 then
            CCT.State.SetHeat(CCT.Heat.Decay(state.heat, gap))
        end
    end
    CCT.State.TouchClock(unix)
    NotePush(unix)
    UpdateBar()
    return true
end

function CCT.Heat.Step(dt, now)
    local step = tonumber(dt) or 0
    if step <= 0 or type(State()) ~= "table" then
        return false
    end
    CCT.Heat.Rebuild()
    CCT.Heat.ApplyControls(step)
    local state = State()
    if type(state) ~= "table" then
        return false
    end
    local decayed = CCT.Heat.Decay(state.heat, step)
    if decayed ~= state.heat then
        CCT.State.SetHeat(decayed)
    end
    if CCT.State.TouchClock then
        CCT.State.TouchClock(now)
    end
    NotePush(now)
    UpdateBar()
    return true
end

local function Clock()
    if GetTime then
        local stamp = GetTime()
        if Secret(stamp) or type(stamp) ~= "number" then
            return nil
        end
        return stamp
    end
    return CCT.UnixNow()
end

local function Interval()
    local cfg = Cfg()
    local interval = tonumber(cfg and cfg.updateInterval) or 0.25
    if interval < 0.05 then
        interval = 0.05
    end
    return interval
end

local function EnsureTicker()
    if ticker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    lastTickAt = Clock()
    ticker = C_Timer.NewTicker(Interval(), function()
        if type(CCT.Heat) ~= "table" or type(CCT.Heat.Step) ~= "function" then
            return
        end
        local now = Clock()
        if now == nil or lastTickAt == nil then
            lastTickAt = now
            return
        end
        local dt = now - lastTickAt
        lastTickAt = now
        if dt > 0 then
            CCT.Heat.Step(dt, CCT.UnixNow())
        end
    end)
end

local function StopTicker()
    if ticker and ticker.Cancel then
        ticker:Cancel()
    end
    ticker = nil
    lastTickAt = nil
end

local function ShowHeat(show)
    local bar = EnsureBar()
    if not bar then
        return
    end
    if show then
        UpdateBar()
        if bar.Show then
            bar:Show()
        end
        return
    end
    if bar.Hide then
        bar:Hide()
    end
end

function CCT.Heat.Refresh(now)
    if type(State()) ~= "table" then
        ShowHeat(false)
        return
    end
    if not offlineDone then
        offlineDone = true
        CCT.Heat.ApplyOffline(now or CCT.UnixNow())
    end
    local owned = HasOwner()
    ShowHeat(owned)
    if not owned and flashFrame and flashFrame.Hide then
        flashFrame:Hide()
    end
    if CCT.Player and CCT.Player.ready then
        EnsureTicker()
    end
end

function CCT.Heat.OnEvent(_, event)
    if event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ENTERING_WORLD" and event ~= "GUILD_ROSTER_UPDATE" then
        return
    end
    if type(CCT.Heat) ~= "table" or type(CCT.Heat.Refresh) ~= "function" then
        return
    end
    CCT.Heat.Refresh(CCT.UnixNow())
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:SetScript("OnEvent", CCT.Heat.OnEvent)
end
