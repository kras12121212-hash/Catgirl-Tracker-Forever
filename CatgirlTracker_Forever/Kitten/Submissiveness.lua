-- Submissiveness from heel levels, denials since local midnight, today's orgasms, and binds.
-- The reachable bind maximum is 20. The value is written with CCT.State.SetSub.
-- The bar is shown only when this character has an owner.
-- A new local day rolls the scorecard, then asks CCT.Report to send the snapshot.
-- This file does not send addon messages. It does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Submissiveness = {}

local MAX_BINDS = 20
local TICK = 2
local STAMP_CAP = 50
local BAR_NAME = "CatgirlSubmissivenessBar"
local DAY_NAME = "CatgirlDayReset"
local WIDTH = 240
local HEIGHT = 18

CCT.Submissiveness.MAX_BINDS = MAX_BINDS
CCT.Submissiveness.TICK = TICK
CCT.Submissiveness.STAMP_CAP = STAMP_CAP
CCT.Submissiveness.WIDTH = WIDTH
CCT.Submissiveness.HEIGHT = HEIGHT
CCT.Submissiveness.pending = nil

local bar = nil
local ticker = nil
local computing = false
local lastDayStart = nil

local function State()
    if CCT.State and CCT.State.Get then
        return CCT.State.Get()
    end
    return nil
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

local function Level(levels, which)
    local n = levels and tonumber(levels[which]) or 1
    if n == nil or n < 1 then
        return 1
    end
    return n
end

local function DayStart(stamp)
    if type(date) ~= "function" or type(time) ~= "function" then
        return nil
    end
    local parts = date("*t", stamp)
    if type(parts) ~= "table" then
        return nil
    end
    parts.hour = 0
    parts.min = 0
    parts.sec = 0
    local start = time(parts)
    if type(start) ~= "number" then
        return nil
    end
    return start
end

local function CountSince(list, now)
    if type(list) ~= "table" then
        return 0
    end
    local start = DayStart(tonumber(now) or CCT.UnixNow())
    if start == nil then
        return 0
    end
    local count = 0
    for i = 1, #list do
        local at = tonumber(list[i])
        if at and at >= start then
            count = count + 1
        end
    end
    return count
end

function CCT.Submissiveness.PushStamp(list, now)
    if type(list) ~= "table" then
        return false
    end
    list[#list + 1] = tonumber(now) or CCT.UnixNow()
    while #list > STAMP_CAP do
        table.remove(list, 1)
    end
    return true
end

function CCT.Submissiveness.OrgasmsToday(life, now)
    return CountSince(life and life.orgasms, now)
end

function CCT.Submissiveness.DenialsToday(life, now)
    return CountSince(life and life.denials, now)
end

function CCT.Submissiveness.NextReset(now)
    local stamp = tonumber(now) or CCT.UnixNow()
    if type(date) ~= "function" or type(time) ~= "function" then
        return nil
    end
    local parts = date("*t", stamp)
    if type(parts) ~= "table" then
        return nil
    end
    parts.hour = 0
    parts.min = 0
    parts.sec = 0
    parts.day = (tonumber(parts.day) or 1) + 1
    local resetAt = time(parts)
    if type(resetAt) ~= "number" then
        return nil
    end
    return resetAt
end

function CCT.Submissiveness.DayLine(life, now)
    local stamp = tonumber(now) or CCT.UnixNow()
    local orgasms = CCT.Submissiveness.OrgasmsToday(life, stamp)
    local denials = CCT.Submissiveness.DenialsToday(life, stamp)
    local resetAt = CCT.Submissiveness.NextReset(stamp)
    local when = "midnight"
    local remain = ""
    if type(resetAt) == "number" and type(date) == "function" then
        local clock = date("%H:%M", resetAt)
        if type(clock) == "string" and clock ~= "" then
            when = clock
        end
    end
    if type(resetAt) == "number" and type(stamp) == "number" then
        local left = math.floor(resetAt - stamp)
        if left < 0 then
            left = 0
        end
        local hours = math.floor(left / 3600)
        local mins = math.floor((left % 3600) / 60)
        remain = string.format(" (%dh %dm)", hours, mins)
    end
    return string.format("Orgasms today: %d. Denials today: %d. Resets at %s%s", orgasms, denials, when, remain)
end

function CCT.Submissiveness.BindCount(state)
    if type(state) ~= "table" then
        return 0
    end
    local count = 0
    if state.gag ~= nil and state.gag ~= "none" then
        count = count + 1
    end
    if state.blind ~= nil and state.blind ~= "none" then
        count = count + 1
    end
    if state.ears ~= nil and state.ears ~= "none" then
        count = count + 1
    end
    if state.mittens ~= nil and state.mittens ~= "none" then
        count = count + 1
    end
    if state.heels ~= nil and state.heels ~= "none" then
        count = count + 1
    end
    if state.bell == true then
        count = count + 1
    end
    if state.tail == true then
        count = count + 1
    end
    if state.jewel == true then
        count = count + 1
    end
    if state.belt == true then
        count = count + 1
    end
    if state.bra == true then
        count = count + 1
    end
    local toys = CCT.State and CCT.State.Toys
    local rows = state.toys
    if type(toys) == "table" and type(rows) == "table" then
        for i = 1, #toys do
            local row = rows[toys[i].id]
            if type(row) == "table" and row.applied == true then
                count = count + 1
            end
        end
    end
    if state.leash == true then
        count = count + 1
    end
    return count
end

function CCT.Submissiveness.Value(state, life, now)
    local levels = state and state.heelLevel
    local levelSum = Level(levels, "maid") + Level(levels, "high") + Level(levels, "ballet")
    local deniedToday = CCT.Submissiveness.DenialsToday(life, now)
    local orgasmsToday = CCT.Submissiveness.OrgasmsToday(life, now)
    local diff = deniedToday - orgasmsToday
    if diff <= 0 then
        diff = 1
    end
    local binds = CCT.Submissiveness.BindCount(state)
    if binds < 1 then
        binds = 1
    end
    local value = levelSum * diff * binds
    if value < 0 then
        value = 0
    end
    if value > 100 then
        value = 100
    end
    return math.floor(value + 0.5)
end

local function SaveBar()
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
    char.bars.sub = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function RestoreBar()
    if not bar or type(bar.ClearAllPoints) ~= "function" or type(bar.SetPoint) ~= "function" then
        return
    end
    bar:ClearAllPoints()
    local char = Char()
    local pos = char and char.bars and char.bars.sub
    if type(pos) == "table" and type(pos.point) == "string" then
        bar:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0)
        return
    end
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -230)
end

local function UpdateBar(value)
    if not bar then
        return
    end
    local shown = tonumber(value) or 0
    if shown < 0 then
        shown = 0
    end
    if shown > 100 then
        shown = 100
    end
    if bar.SetMinMaxValues then
        bar:SetMinMaxValues(0, 100)
    end
    if bar.SetValue then
        bar:SetValue(shown)
    end
    if bar.SetStatusBarColor then
        bar:SetStatusBarColor(0.35, 0.8, 0.6)
    end
    if bar.text and bar.text.SetText then
        bar.text:SetText(string.format("Kitten Submissiveness: %d / 100", shown))
    end
    local caption = bar.dayText
    if caption and caption.text and caption.text.SetText then
        caption.text:SetText(CCT.Submissiveness.DayLine(Char() and Char().life, CCT.UnixNow()))
    end
end

local function EnsureBar()
    if bar or not CreateFrame or not UIParent then
        return bar
    end
    bar = CreateFrame("StatusBar", BAR_NAME, UIParent, "BackdropTemplate")
    if bar.SetSize then
        bar:SetSize(WIDTH, HEIGHT)
    end
    if bar.SetStatusBarTexture then
        bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    end
    if bar.SetMinMaxValues then
        bar:SetMinMaxValues(0, 100)
    end
    if bar.SetValue then
        bar:SetValue(0)
    end
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
    if bar.CreateFontString then
        bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if bar.text.SetPoint then
            bar.text:SetPoint("CENTER")
        end
        if bar.text.SetText then
            bar.text:SetText("Kitten Submissiveness: 0 / 100")
        end
    end
    if CreateFrame then
        local caption = CreateFrame("Frame", DAY_NAME, bar)
        if caption.SetSize then
            caption:SetSize(420, 16)
        end
        if caption.SetPoint then
            caption:SetPoint("TOP", bar, "BOTTOM", 0, -2)
        end
        if caption.CreateFontString then
            caption.text = caption:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            if caption.text and caption.text.SetPoint then
                caption.text:SetPoint("TOP", caption, "TOP", 0, 0)
            end
            if caption.text and caption.text.SetJustifyH then
                caption.text:SetJustifyH("CENTER")
            end
            if caption.text and caption.text.SetText then
                caption.text:SetText(CCT.Submissiveness.DayLine(nil, CCT.UnixNow()))
            end
        end
        if caption.Hide then
            caption:Hide()
        end
        bar.dayText = caption
    end
    if bar.SetMovable then
        bar:SetMovable(true)
    end
    if bar.EnableMouse then
        bar:EnableMouse(true)
    end
    if bar.RegisterForDrag then
        bar:RegisterForDrag("LeftButton")
    end
    if bar.SetScript then
        bar:SetScript("OnDragStart", function(self)
            if self.StartMoving then
                self:StartMoving()
            end
        end)
        bar:SetScript("OnDragStop", function(self)
            if self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end
            SaveBar()
        end)
    end
    RestoreBar()
    if bar.Hide then
        bar:Hide()
    end
    return bar
end

function CCT.Submissiveness.Recompute(now)
    if computing then
        return nil
    end
    local state = State()
    if type(state) ~= "table" or not CCT.State.SetSub then
        return nil
    end
    computing = true
    local before = tonumber(state.sub) or 0
    local life = Char() and Char().life
    local value = CCT.Submissiveness.Value(state, life, now)
    CCT.State.SetSub(value)
    state = State() or state
    local written = tonumber(state.sub) or value
    if written ~= before then
        CCT.Submissiveness.pending = written
    end
    local dayStart = DayStart(tonumber(now) or CCT.UnixNow())
    local rolled = lastDayStart ~= nil and dayStart ~= nil and dayStart > lastDayStart
    if dayStart ~= nil then
        lastDayStart = dayStart
    end
    UpdateBar(written)
    computing = false
    if rolled then
        if CCT.Ledger and type(CCT.Ledger.EnsureWeek) == "function" then
            CCT.Ledger.EnsureWeek(now)
        end
        if CCT.Report and type(CCT.Report.SendState) == "function" then
            CCT.Report.SendState()
        end
    end
    return written
end

local function ShowBar(show)
    local frame = EnsureBar()
    if not frame then
        return
    end
    if show then
        UpdateBar(State() and State().sub)
        if frame.Show then
            frame:Show()
        end
        if frame.dayText and frame.dayText.Show then
            frame.dayText:Show()
        end
        return
    end
    if frame.dayText and frame.dayText.Hide then
        frame.dayText:Hide()
    end
    if frame.Hide then
        frame:Hide()
    end
end

local function EnsureTicker()
    if ticker or not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    ticker = C_Timer.NewTicker(TICK, function()
        if type(CCT.Submissiveness) ~= "table" or type(CCT.Submissiveness.Recompute) ~= "function" then
            return
        end
        CCT.Submissiveness.Recompute(CCT.UnixNow())
    end)
end

function CCT.Submissiveness.Refresh(now)
    if type(State()) ~= "table" then
        ShowBar(false)
        return
    end
    CCT.Submissiveness.Recompute(now or CCT.UnixNow())
    ShowBar(HasOwner())
    if CCT.Player and CCT.Player.ready then
        EnsureTicker()
    end
end

function CCT.Submissiveness.OnEvent(_, event)
    if event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ENTERING_WORLD" and event ~= "GUILD_ROSTER_UPDATE" then
        return
    end
    if type(CCT.Submissiveness) ~= "table" or type(CCT.Submissiveness.Refresh) ~= "function" then
        return
    end
    CCT.Submissiveness.Refresh(CCT.UnixNow())
end

if CCT.State and CCT.State.Listen then
    CCT.State.Listen(function()
        if type(CCT.Submissiveness) == "table" and type(CCT.Submissiveness.Recompute) == "function" then
            CCT.Submissiveness.Recompute(CCT.UnixNow())
        end
    end)
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:SetScript("OnEvent", CCT.Submissiveness.OnEvent)
end
