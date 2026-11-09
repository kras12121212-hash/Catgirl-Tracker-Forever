-- PR 4 self-check. Run from the repo root:
--   lua tools/pr4_selfcheck.lua
-- Leash, chastity, toys, locks, and local commands. No addon messages.
-- /cctcmd is temporary. It runs a Cmd on this client.

local stdout = print
local failures = 0

local function check(name, cond, detail)
    if cond then
        stdout("ok  " .. name)
    else
        failures = failures + 1
        if detail ~= nil then
            stdout("FAIL " .. name .. " :: " .. tostring(detail))
        else
            stdout("FAIL " .. name)
        end
    end
end

local script = (arg and arg[0]) or "tools/pr4_selfcheck.lua"
local root = script:gsub("/?tools/pr4_selfcheck%.lua$", "")
if root == "" then
    root = "."
end
local addon = root .. "/CatgirlTracker_Forever"

local function read(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        error("missing " .. path)
    end
    local text = handle:read("*a")
    handle:close()
    return text
end

local function boom(label)
    return function()
        error(label .. " called", 2)
    end
end

local secret = setmetatable({}, {
    __tostring = function()
        error("secret string")
    end,
    __index = function()
        error("secret index")
    end,
})

issecretvalue = function(value)
    return rawequal(value, secret)
end

local frames = {}
local tickers = {}
local timers = {}
local afters = {}
local places = {}
local picks = {}
local macros = {}
local macroByName = {}
local notices = {}
local lines = {}
local sent = {}
local sounds = {}
local actions = {}
local cursor = nil
local macroSerial = 0
local combat = false
local now = 5000
local shockLoads = false
local invites = 0
local leaves = 0
local roster = {}

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function newFont()
    local font = {}
    function font:SetText(value)
        self.value = value
    end
    function font:SetPoint(...)
        self.point = { ... }
    end
    function font:SetFont() end
    function font:SetTextColor() end
    return font
end

local function newTexture(frame)
    local tex = {}
    function tex:SetAllPoints() end
    function tex:SetPoint() end
    function tex:SetTexCoord() end
    function tex:SetAlpha(alpha)
        self.alpha = alpha
    end
    function tex:SetColorTexture(r, g, b, a)
        self.color = { r, g, b, a }
    end
    function tex:Hide()
        self.hidden = true
    end
    function tex:Show()
        self.hidden = false
    end
    function tex:SetTexture(path)
        self.path = path
        if type(path) == "string" and path:find("BeltShockDeny", 1, true) and not shockLoads then
            self.loaded = nil
            return false
        end
        if path == nil then
            self.loaded = nil
            return nil
        end
        self.loaded = path
        return path
    end
    function tex:GetTexture()
        return self.loaded
    end
    frame.texture = tex
    return tex
end

local function newFrame(kind, name, parent, template)
    local frame = {
        kind = kind,
        name = name,
        parent = parent,
        template = template,
        events = {},
        scripts = {},
        attributes = {},
        clicks = {},
        shown = false,
        mouse = false,
        fonts = {},
    }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:UnregisterEvent(event)
        self.events[event] = nil
    end
    function frame:SetScript(which, fn)
        self.scripts[which] = fn
    end
    function frame:SetFrameStrata(strata)
        self.strata = strata
    end
    function frame:SetAllPoints(other)
        self.allPoints = other
    end
    function frame:ClearAllPoints() end
    function frame:SetPoint(...)
        self.point = { ... }
    end
    function frame:SetSize(width, height)
        self.width = width
        self.height = height
    end
    function frame:EnableMouse(on)
        self.mouse = on and true or false
    end
    function frame:RegisterForClicks(click)
        self.clicks[#self.clicks + 1] = click
    end
    function frame:SetAttribute(key, value)
        self.attributes[key] = value
    end
    function frame:GetAttribute(key)
        return self.attributes[key]
    end
    function frame:Hide()
        self.shown = false
    end
    function frame:Show()
        self.shown = true
    end
    function frame:IsShown()
        return self.shown == true
    end
    function frame:SetBackdrop(info)
        self.backdrop = info
    end
    function frame:SetBackdropColor(...)
        self.backdropColor = { ... }
    end
    function frame:SetAlpha(alpha)
        self.alpha = alpha
    end
    function frame:SetStatusBarTexture(path)
        self.barTexture = path
    end
    function frame:SetMinMaxValues(low, high)
        self.minValue = low
        self.maxValue = high
    end
    function frame:SetValue(value)
        self.value = value
    end
    function frame:SetStatusBarColor(...)
        self.barColor = { ... }
    end
    function frame:CreateTexture()
        return newTexture(self)
    end
    function frame:CreateFontString()
        local font = newFont()
        self.fonts[#self.fonts + 1] = font
        self.text = font
        return font
    end
    frames[#frames + 1] = frame
    return frame
end

CreateFrame = function(kind, name, parent, template)
    return newFrame(kind, name, parent, template)
end

UIParent = { width = 1920, height = 1080 }
function UIParent:GetWidth()
    return self.width
end
function UIParent:GetHeight()
    return self.height
end
function UIParent:GetEffectiveScale()
    return 2
end

C_Timer = {
    After = function(delay, fn)
        afters[#afters + 1] = { delay = delay, fn = fn }
    end,
    NewTicker = function(interval, fn)
        local handle = { interval = interval, fn = fn, cancelled = false }
        function handle:Cancel()
            self.cancelled = true
        end
        tickers[#tickers + 1] = handle
        return handle
    end,
    NewTimer = function(delay, fn)
        local handle = { delay = delay, fn = fn, cancelled = false }
        function handle:Cancel()
            self.cancelled = true
        end
        timers[#timers + 1] = handle
        return handle
    end,
}

ChatFrame_AddMessageEventFilter = function() end

local function fire(event, ...)
    for i = 1, #frames do
        local frame = frames[i]
        local fn = frame.scripts.OnEvent
        if fn and frame.events[event] then
            fn(frame, event, ...)
        end
    end
end

local function frameNamed(name)
    for i = 1, #frames do
        if frames[i].name == name then
            return frames[i]
        end
    end
    return nil
end

time = function()
    return now
end
date = os.date
GetTime = time

GetCursorPosition = function()
    return 0, 0
end

InCombatLockdown = function()
    return combat
end

GetUnitSpeed = function()
    return 0
end
IsPlayerMoving = function()
    return false
end

PlaySoundFile = function()
    return true, 1
end
StopSound = function() end
DoEmote = function() end

ClearCursor = function()
    cursor = nil
end

local function remember(kind, id)
    cursor = { type = kind, id = id }
    picks[#picks + 1] = { kind, id }
end

PickupSpell = function(id)
    remember("spell", id)
end
PickupMacro = function(id)
    remember("macro", id)
end
PickupItem = function(id)
    remember("item", id)
end
PickupAction = function(slot)
    cursor = actions[slot]
    actions[slot] = nil
    picks[#picks + 1] = { "action", slot }
end
PlaceAction = function(slot)
    places[#places + 1] = {
        slot = slot,
        cursor = cursor and { type = cursor.type, id = cursor.id } or nil,
    }
    actions[slot] = cursor
end

GetActionInfo = function(slot)
    local action = actions[slot]
    if action == nil then
        return nil
    end
    return action.type, action.id, action.sub
end

GetMacroIndexByName = function(name)
    local row = macroByName[name]
    if row == nil then
        return 0
    end
    return row.index
end

CreateMacro = function(name, icon, body, perChar)
    macroSerial = macroSerial + 1
    local row = {
        op = "create",
        name = name,
        icon = icon,
        body = body,
        perChar = perChar,
        index = macroSerial,
    }
    macros[#macros + 1] = row
    macroByName[name] = row
    return row.index
end

EditMacro = function(index, name, icon, body, perChar)
    macros[#macros + 1] = {
        op = "edit",
        index = index,
        name = name,
        icon = icon,
        body = body,
        perChar = perChar,
    }
    local row = macroByName[name]
    if row then
        row.body = body
        row.icon = icon
        row.perChar = perChar
    end
end

math.random = function(a, b)
    if a == 120 and b == 300 then
        return 180
    end
    if b == nil then
        return 1
    end
    return a
end

RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = { r = 1 } }
RaidNotice_AddMessage = function(_, text)
    notices[#notices + 1] = text
end
RaidNotice_Clear = function() end

C_PartyInfo = {
    InviteUnit = function()
        invites = invites + 1
    end,
    LeaveParty = function()
        leaves = leaves + 1
    end,
}

UnitName = boom("UnitName")
UnitFullName = boom("UnitFullName")
UnitGUID = boom("UnitGUID")
UnitPosition = boom("UnitPosition")
GetGuildRosterInfo = boom("GetGuildRosterInfo")
GetNumGuildMembers = boom("GetNumGuildMembers")
GuildRoster = boom("GuildRoster")
C_GuildInfo = { GuildRoster = boom("C_GuildInfo.GuildRoster") }
SendChatMessage = boom("SendChatMessage")
SendAddonMessage = boom("SendAddonMessage")
C_ChatInfo = {
    SendChatMessage = boom("C_ChatInfo.SendChatMessage"),
    SendAddonMessage = boom("C_ChatInfo.SendAddonMessage"),
}
hooksecurefunc = boom("hooksecurefunc")
CatgirlTrackerDB = nil
SlashCmdList = {}

local function spy(msg, chatType, language, target)
    sent[#sent + 1] = {
        msg = msg,
        chatType = chatType,
        language = language,
        target = target,
    }
end

local toc = read(addon .. "/CatgirlTracker_Forever.toc")
local sources = {
    leash = read(addon .. "/Kitten/Leash.lua"),
    chastity = read(addon .. "/Kitten/Chastity.lua"),
    toys = read(addon .. "/Kitten/Toys.lua"),
    locks = read(addon .. "/Kitten/Locks.lua"),
    commands = read(addon .. "/Kitten/Commands.lua"),
}

check(
    "toc order",
    toc:find("Kitten/Bells.lua\nKitten/Leash.lua\nKitten/Chastity.lua\nKitten/Toys.lua\nKitten/Locks.lua\nKitten/Commands.lua\nKitten/HeatConfig.lua\nKitten/Heat.lua\nKitten/Submissiveness.lua\nKitten/SoundEngine.lua\nKitten/Discipline.lua", 1, true) ~= nil
)
check("toc lists net", toc:find("Core/Net.lua", 1, true) ~= nil)
check("net file exists", io.open(addon .. "/Core/Net.lua", "rb") ~= nil)
check("heat follows commands", toc:find("Kitten/Commands.lua\nKitten/HeatConfig.lua", 1, true) ~= nil)

local banned = {
    "SendAddonMessage",
    "C_ChatInfo",
    "UnitName",
    "GetGuildRosterInfo",
    "UnitPosition",
    "CatgirlBehaviorDB",
    "FindLastEvent",
    "CHAT_MSG_WHISPER",
}

for label, text in pairs(sources) do
    for i = 1, #banned do
        check(label .. " has no " .. banned[i], text:find(banned[i], 1, true) == nil)
    end
    check(
        label .. " does not send addon messages",
        text:find("This file does not send addon messages.", 1, true) ~= nil
    )
end

check("leash never clicks", sources.leash:find(":Click", 1, true) == nil)
check("leash names the follow button", sources.leash:find("Press 1 follow your Master nya~", 1, true) ~= nil)
check("leash names the stop button", sources.leash:find("Click to stop following nya~", 1, true) ~= nil)
check("leash targets then follows", sources.leash:find('"/target " .. target .. "\\n/follow"', 1, true) ~= nil)
check("leash stop body", sources.leash:find('"/stopfollow"', 1, true) ~= nil)
check("leash clears clickbutton", sources.leash:find('SetAttribute("clickbutton", nil)', 1, true) ~= nil)
check("leash macro name", sources.leash:find("FollowLeashMacro", 1, true) ~= nil)
check("leash question mark", sources.leash:find("INV_MISC_QUESTIONMARK", 1, true) ~= nil)
check("chastity heat is 70", sources.chastity:find("local DENY_HEAT = 70", 1, true) ~= nil)
check("chastity shock art", sources.chastity:find("Textures\\\\BeltShockDeny.tga", 1, true) ~= nil)
check("toy shock table", sources.toys:find("-5", 1, true) ~= nil and sources.toys:find("-10", 1, true) ~= nil and sources.toys:find("-15", 1, true) ~= nil)
check("toy taill spelling", sources.toys:find("taill_butplug", 1, true) ~= nil)
check("locks skip the blindfold debug line", sources.locks:find("ttttttttt", 1, true) == nil)
check("commands hold for 10 seconds", sources.commands:find("local HOLD_SECONDS = 10", 1, true) ~= nil)
check("commands do not register a slash", sources.commands:find("SLASH_CCTCMD1", 1, true) == nil)
check("commands do not call mitten setter", sources.commands:find("Mittens.Set", 1, true) == nil)
check("commands do not call heel setter", sources.commands:find("Heels.Set", 1, true) == nil)
check("commands do not call bell setter", sources.commands:find("Bells.Set", 1, true) == nil)
check("commands do not call ear setter", sources.commands:find("Ears.Set", 1, true) == nil)
check("commands do not invite", sources.commands:find("InviteUnit", 1, true) == nil)
check("commands write gag through state", sources.commands:find("CCT.State.SetGag", 1, true) ~= nil)
check("held slash sentence", sources.commands:find("command held until the owner note is known.", 1, true) ~= nil)

local files = {}
for line in toc:gmatch("[^\n]+") do
    if line:find("%.lua$") then
        files[#files + 1] = line
    end
end

local CCT = {}
for i = 1, #files do
    local chunk, err = loadfile(addon .. "/" .. files[i])
    if chunk == nil then
        error(err)
    end
    chunk("CatgirlTracker_Forever", CCT)
end
check("files load", CCT.Commands ~= nil and CCT.Leash ~= nil and CCT.Locks ~= nil)

local lockTicker = nil
for i = 1, #tickers do
    if tickers[i].interval == 1 then
        lockTicker = tickers[i]
        break
    end
end
check("lock ticker is one second", lockTicker ~= nil and lockTicker.interval == 1)

SendChatMessage = spy
C_ChatInfo = {
    SendChatMessage = spy,
    SendAddonMessage = boom("SendAddonMessage"),
}
SendAddonMessage = boom("SendAddonMessage")
fire("ADDON_LOADED", "CatgirlTracker_Forever")

print = function(text)
    lines[#lines + 1] = tostring(text)
end

UnitFullName = function()
    return "Kitten"
end
UnitGUID = function()
    return "Player-1-ABC"
end
IsInGuild = function()
    return true
end
C_GuildInfo = { GuildRoster = function() end }
GuildRoster = nil

local function publishRoster(rows)
    roster = rows
    GetNumGuildMembers = function()
        return #roster
    end
    GetGuildRosterInfo = function(index)
        local row = roster[index]
        if row == nil then
            return nil
        end
        return row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9]
    end
end

local function ownerRows()
    return {
        { "Kitten", "rank", 0, 1, "Mage", "Elwynn", "owner=Nyx", "", true },
        { "Nyx", "Officer", 1, 1, "Mage", "Elwynn", "", "", true },
        { "Guildmaster", "Guild Master", 0, 1, "Mage", "Elwynn", "owner=Guildmaster", "", true },
    }
end

local function noOwnerRows()
    return {
        { "Kitten", "rank", 0, 1, "Mage", "Elwynn", "", "", true },
        { "Nyx", "Officer", 1, 1, "Mage", "Elwynn", "", "", true },
    }
end

fire("PLAYER_LOGIN")
check("player ready", CCT.Player.ready == true and CCT.Player.short == "Kitten")
check("login is quiet", #lines == 0 and #sent == 0 and #notices == 0)
check("slash is not registered", SLASH_CCTCMD1 == nil and SlashCmdList.CCTCMD == nil)

local quietLines = #lines
local quietNotices = #notices
lockTicker.fn()
check("idle lock tick is silent", #lines == quietLines and #notices == quietNotices)

publishRoster(ownerRows())
CCT.Roster.Rebuild()
check("owner is nyx", CCT.Roster.GetOwnerShort() == "Nyx")
check("cache is ready", CCT.Roster.GetSelf() ~= nil)

local function state()
    return CCT.State.Get()
end

local function char()
    return CCT.Saved.EnsureChar("Kitten")
end

local function cmd(text, sender, stamp)
    return CCT.Commands.Receive(sender or "Nyx", text, stamp or now, false)
end

local function countWhere(list, field, value)
    local n = 0
    for i = 1, #list do
        if list[i][field] == value then
            n = n + 1
        end
    end
    return n
end

local function hasLine(text)
    for i = 1, #lines do
        if lines[i] == text then
            return true
        end
    end
    return false
end

local function hasNotice(text)
    for i = 1, #notices do
        if notices[i] == text then
            return true
        end
    end
    return false
end

local function hasWhisper(text, target)
    for i = 1, #sent do
        local row = sent[i]
        if row.msg == text and row.chatType == "WHISPER" and (target == nil or row.target == target) then
            return true
        end
    end
    return false
end

check("belt starts off", state().belt == false and state().beltMode == "allow" and state().bra == false)
check("gag starts none", state().gag == "none")
check("tasks start at zero", state().counters.tasks == 0 and state().counters.orgasm == 0 and state().counters.deny == 0)

local gagCalls = 0
local originalGag = CCT.Gag.ApplyOutgoing
CCT.Gag.ApplyOutgoing = function(...)
    gagCalls = gagCalls + 1
    return originalGag(...)
end

local pendingBefore = CCT.Commands.Pending()
local parsed = CCT.Commands.Receive("Nyx", "Hello there", now, false)
check("chat is not a command", parsed.ok == false and parsed.reason == "parse" and CCT.Commands.Pending() == pendingBefore)
parsed = CCT.Commands.Receive("Nyx", "Cmd,op:gag\nstate:huge", now, false)
check("newline is rejected", parsed.reason == "parse")
parsed = CCT.Commands.Receive("Nyx", "Please,op:gag,state:huge", now, false)
check("a bare word is rejected", parsed.reason == "parse")
parsed = CCT.Commands.Parse("Cmd")
check("cmd alone does not parse", parsed == nil)

fire("CHAT_MSG_WHISPER", "Cmd,op:gag,state:huge", "Nyx")
check("a whisper event does not apply", state().gag == "none")

local mismatched = cmd("Cmd,op:gag,state:huge", "Other")
check("other owner is ignored", mismatched.ok == false and mismatched.reason == "owner" and state().gag == "none")
local gm = cmd("Cmd,op:gag,state:full", "Guildmaster")
check("guild master is ignored", gm.ok == false and gm.reason == "owner" and state().gag == "none" and gm.held == nil)

publishRoster(noOwnerRows())
CCT.Roster.Rebuild()
check("self without an owner note", CCT.Roster.GetSelf() ~= nil and CCT.Roster.GetOwnerShort() == nil)
local missingOwner = cmd("Cmd,op:gag,state:huge")
check("known cache and unknown owner drops", missingOwner.reason == "owner" and missingOwner.held == nil and state().gag == "none")

publishRoster({})
CCT.Roster.Rebuild()
check("empty cache", CCT.Roster.GetSelf() == nil and CCT.Roster.GetOwnerShort() == nil)
local heldSmall = CCT.Commands.Receive("Nyx", "Cmd,op:gag,state:small", now, false)
check("empty cache holds", heldSmall.reason == "hold" and heldSmall.held == true and heldSmall.op == "gag" and CCT.Commands.Pending() == 1)
check("held gag is not worn", state().gag == "none")
CCT.Commands.Flush(now + 9)
check("nine seconds keeps the hold", CCT.Commands.Pending() == 1 and state().gag == "none")
CCT.Commands.Flush(now + 10)
check("ten seconds drops an unknown owner", CCT.Commands.Pending() == 0 and state().gag == "none")

local parseWhileHeld = CCT.Commands.Receive("Nyx", "Hello there", now, false)
check("a bad parse does not hold", parseWhileHeld.reason == "parse" and CCT.Commands.Pending() == 0)

local heldGm = CCT.Commands.Receive("Guildmaster", "Cmd,op:gag,state:huge", now, false)
check("guild master is held with the cache", heldGm.reason == "hold" and CCT.Commands.Pending() == 1)
publishRoster(ownerRows())
fire("GUILD_ROSTER_UPDATE")
check("guild master hold is dropped", CCT.Commands.Pending() == 0 and state().gag == "none" and CCT.Roster.GetOwnerShort() == "Nyx")

publishRoster({})
CCT.Roster.Rebuild()
local heldOther = CCT.Commands.Receive("Nyx-Silvermoon", "Cmd,op:gag,state:huge", now, false)
check("a hyphen surname is held", heldOther.reason == "hold" and state().gag == "none")
local heldEars = CCT.Commands.Receive("nyx", "Cmd,op:ears,state:kitten", now, false)
check("case folded owner is held", heldEars.reason == "hold" and state().ears == "none")
publishRoster(ownerRows())
fire("GUILD_ROSTER_UPDATE")
check("a surname is not the owner", state().gag == "none" and state().ears == "kitten" and CCT.Commands.Pending() == 0)
check("earmuffs announce", hasLine("Kitten earmuffs applied. Words sound cuter now nya~") and hasNotice("Earmuffs applied: kitten."))
publishRoster({
    { "Kitten", "rank", 0, 1, "Mage", "Elwynn", "owner=Nyx Brightvale", "", true },
    { "Nyx Brightvale", "Officer", 1, 1, "Mage", "Elwynn", "", "", true },
})
CCT.Roster.Rebuild()
local named = CCT.Commands.Receive("nyx-brightvale", "Cmd,op:leash,on:2", now, false)
local spaced = CCT.Commands.Receive("Nyx Brightvale", "Cmd,op:leash,on:2", now, false)
local givenOnly = CCT.Commands.Receive("Nyx", "Cmd,op:leash,on:2", now, false)
check("hyphen surname matches the note", named.reason == "on" and spaced.reason == "on" and state().leash ~= true)
check("first name is not the two part owner", givenOnly.reason == "owner")
publishRoster(ownerRows())
CCT.Roster.Rebuild()

local tasksBefore = state().counters.tasks
for _, op in ipairs({ "maid", "maiditem", "maidtext" }) do
    local result = cmd("Cmd,op:" .. op .. ",cid:Later1")
    check(
        op .. " waits",
        result.ok == false and result.reason == "later" and result.cid == "Later1" and state().counters.tasks == tasksBefore and invites == 0 and leaves == 0
    )
end

local badOn = cmd("Cmd,op:leash,on:2")
check("leash flag must be zero or one", badOn.reason == "on" and state().leash ~= true)
local injected = CCT.Leash.Apply(true, "Nyx\n")
check("control characters are not a macro target", injected == false or (injected == false))
check("control character reason", select(2, CCT.Leash.Apply(true, "Nyx\n")) == "owner" and state().leash ~= true)

actions[1] = { type = "spell", id = 100 }
actions[120] = { type = "spell", id = 55 }
clearList(places)
clearList(macros)
combat = true
clearList(sent)
clearList(lines)
clearList(notices)
local leashed = cmd("Cmd,op:leash,on:1,cid:Leash9")
local button = frameNamed("CatgirlLeashButton")
local backup = char().leashSlots
check("combat leash applies", leashed.ok == true and leashed.cid == "Leash9" and state().leash == true and state().leashOwner == "Nyx")
check("combat leash does not build the button", button == nil)
check("combat leash does not write a macro", #macros == 0)
check("combat leash does not stamp", #places == 0)
check("combat leash captures the bar", type(backup) == "table" and backup[1].actionType == "spell" and backup[1].id == 100 and backup[2] == false and backup[120].id == 55)
check("backup stays off the state struct", state().leashSlots == nil)
check("live bar is untouched in combat", actions[1].id == 100 and actions[120].id == 55)
check(
    "leash whisper stays raw",
    hasWhisper(CCT.Msg("LEASH_APPLY", "Kitten"), "Nyx") and gagCalls == 0
)
check("leash local line", hasLine("|cffffff00CatgirlTracker:|r Leashed by Nyx nya~") and hasNotice("Leash applied."))

local again = cmd("Cmd,op:leash,on:1")
check("second leash is refused", again.ok == false and again.reason == "leashed" and rawequal(char().leashSlots, backup) and #macros == 0)

combat = false
local placesBefore = #places
fire("PLAYER_REGEN_ENABLED")
button = frameNamed("CatgirlLeashButton")
local macroRow = macroByName.FollowLeashMacro
check("regen writes the character macro", macroRow ~= nil and macroRow.op == "create" and macroRow.perChar == true and macroRow.icon == "INV_MISC_QUESTIONMARK" and macroRow.body == "/target Nyx\n/follow")
check("regen stamps all 120 slots", #places == placesBefore + 120 and places[placesBefore + 1].slot == 1 and places[#places].slot == 120 and places[#places].cursor.type == "macro" and places[#places].cursor.id == macroRow.index)
check("slotted macro id", actions[1].type == "macro" and actions[1].id == macroRow.index and actions[120].id == macroRow.index)
check(
    "follow button",
    button ~= nil
        and button.template == "SecureActionButtonTemplate"
        and button.shown == true
        and button.width == 1920
        and button.height == 1080
        and button.strata == "FULLSCREEN_DIALOG"
        and button.clicks[1] == "AnyUp"
        and button.text.value == CCT.Leash.FOLLOW_TEXT
        and button.scripts.PostClick == nil
        and button:GetAttribute("type") == "macro"
        and button:GetAttribute("type1") == "macro"
        and button:GetAttribute("macro") == macroRow.index
        and button:GetAttribute("macrotext") == nil
        and button:GetAttribute("clickbutton") == nil
        and button:GetAttribute("clickbutton1") == nil
)
check("follow texture is dim", button.texture.color[1] == 0 and button.texture.color[4] == 0.3)

local macroCount = #macros
local still = cmd("Cmd,op:leash,on:1")
check("leashed again does not rewrite", still.reason == "leashed" and #macros == macroCount and rawequal(char().leashSlots, backup))

local foreignOk, foreignReason = CCT.Leash.Apply(false, "Other")
check("another character cannot unleash", foreignOk == false and foreignReason == "leasher" and state().leash == true)
local foreignCmd = cmd("Cmd,op:leash,on:0", "Guildmaster")
check("non owner command cannot unleash", foreignCmd.reason == "owner" and state().leash == true and actions[1].id == macroRow.index)

combat = true
clearList(sent)
local unleash = CCT.Leash.Apply(false, "Nyx")
check("combat unleash updates state now", unleash == true and state().leash == false and state().leashOwner == nil)
check("combat unleash hides the button", button.shown == false)
check("combat unleash keeps the backup", type(char().leashSlots) == "table" and actions[1].id == macroRow.index)
check("combat unleash does not retarget yet", button:GetAttribute("macrotext") == nil)
check("unleash whisper", hasWhisper(CCT.Msg("LEASH_REMOVE", "Kitten"), "Nyx"))
check("unleash lines wait with the state", hasLine("|cffffff00CatgirlTracker:|r Unleashed nya~") and hasNotice("Leash removed."))

combat = false
fire("PLAYER_REGEN_ENABLED")
check("regen shows the stop button", button.shown == true and button.text.value == CCT.Leash.STOP_TEXT and button:GetAttribute("macrotext") == "/stopfollow" and button:GetAttribute("macro") == nil)
check("regen restores the saved spells", actions[1].type == "spell" and actions[1].id == 100 and actions[120].id == 55 and actions[2] == nil)
check("backup is cleared", char().leashSlots == nil)

local reLeashPlaces = #places
local reMacros = #macros
local returned = CCT.Leash.Apply(true, "Nyx")
check("a new leash clears the stop latch", returned == true and state().leash == true and button.shown == true and button.text.value == CCT.Leash.FOLLOW_TEXT and button.scripts.PostClick == nil)
check("a new leash stamps again", #places == reLeashPlaces + 120 and #macros == reMacros + 1 and macros[#macros].op == "edit" and macros[#macros].body == "/target Nyx\n/follow")

combat = false
CCT.Leash.Apply(false, "Nyx")
check("out of combat stop is showing", button.shown == true and button.text.value == CCT.Leash.STOP_TEXT and state().leash == false)
button.scripts.PostClick()
check("stop click hides the button", button.shown == false and button.scripts.PostClick == nil and char().leashSlots == nil)

local oldCreate = CreateMacro
local oldEdit = EditMacro
CreateMacro = function()
    error("macro failed")
end
EditMacro = function()
    error("macro failed")
end
macroByName.FollowLeashMacro = nil
local failed = CCT.Leash.Apply(true, "Nyx")
check(
    "macro failure uses macrotext",
    failed == true
        and button.shown == true
        and button:GetAttribute("macrotext") == "/target Nyx\n/follow"
        and button:GetAttribute("macro") == nil
        and button:GetAttribute("type") == "macro"
)
CreateMacro = oldCreate
EditMacro = oldEdit
CCT.Leash.Apply(false, "Nyx")
if button.scripts.PostClick then
    button.scripts.PostClick()
end
check("leash is down", state().leash == false and char().leashSlots == nil)

-- Forever leaves PickupSpell as a no-op for the id GetActionInfo saved.
-- The spellbook slot for the saved name is what puts the spell back.
actions[1] = { type = "spell", id = 100 }
actions[3] = nil
actions[120] = nil
local oldPickupSpell = PickupSpell
local spellTries = {}
PickupSpell = function(id)
    spellTries[#spellTries + 1] = id
end
GetCursorInfo = function()
    if cursor then
        return cursor.type, cursor.id
    end
end
C_Spell = {
    GetSpellName = function(id)
        if id == 100 then
            return "Fireball"
        end
    end,
    PickupSpell = function(id)
        spellTries[#spellTries + 1] = id
    end,
}
C_SpellBook = {
    FindSpellBookSlotForSpell = function(key)
        if key == "Fireball" then
            return 4, 0
        end
    end,
    PickupSpellBookItem = function(index, bank)
        check("spellbook bank can be zero", index == 4 and bank == 0)
        oldPickupSpell(100)
    end,
}
local named = CCT.Leash.Apply(true, "Nyx")
check(
    "spell name is kept for restore",
    named == true
        and char().leashSlots[1].actionType == "spell"
        and char().leashSlots[1].id == 100
        and char().leashSlots[1].name == "Fireball"
        and char().leashSlots[3] == false
)
CCT.Leash.Apply(false, "Nyx")
if button.scripts.PostClick then
    button.scripts.PostClick()
end
check(
    "spellbook restore puts the original spell back",
    actions[1] ~= nil and actions[1].type == "spell" and actions[1].id == 100 and actions[3] == nil and char().leashSlots == nil
)
PickupSpell = oldPickupSpell
C_Spell = nil
C_SpellBook = nil
GetCursorInfo = nil
actions[1] = nil

for slot = 1, 120 do
    actions[slot] = nil
end
local pawPickup = PickupSpell
PickupSpell = function() end
GetCursorInfo = function()
    if cursor then
        return cursor.type, cursor.id
    end
end
C_Spell = {
    GetSpellName = function(id)
        if id == 100 then
            return "Fireball"
        end
        if id == 200 then
            return "Frostbolt"
        end
    end,
    PickupSpell = function() end,
}
C_SpellBook = {
    FindSpellBookSlotForSpell = function(key)
        if key == "Fireball" then
            return 4, 0
        end
        if key == "Frostbolt" then
            return 5, 0
        end
    end,
    PickupSpellBookItem = function(index)
        if index == 4 then
            pawPickup(100)
        elseif index == 5 then
            pawPickup(200)
        end
    end,
}
actions[1] = { type = "spell", id = 100 }
actions[2] = { type = "spell", id = 200 }
check("mittens cover one spell before the leash", CCT.Mittens.Set("Nyx", "locked") == true)
local pawRow = macroByName.PawMittensOops
local function countAction(id)
    local count = 0
    for slot = 1, 120 do
        if actions[slot] and actions[slot].id == id then
            count = count + 1
        end
    end
    return count
end
check("one paw macro before the leash", pawRow ~= nil and countAction(pawRow.index) == 1)
local leashed = CCT.Leash.Apply(true, "Nyx")
local kept = char().leashSlots
check(
    "leash keeps both spells under the paw swap",
    leashed == true
        and kept[1].actionType == "spell"
        and kept[1].name == "Fireball"
        and kept[2].actionType == "spell"
        and kept[2].name == "Frostbolt"
        and countAction(pawRow.index) == 0
)
local pawTicker = nil
for i = 1, #tickers do
    if tickers[i].interval == 5 and tickers[i].cancelled ~= true then
        pawTicker = tickers[i]
    end
end
check("leash pauses the paw swap", pawTicker == nil)
CCT.Leash.Apply(false, "Nyx")
if button.scripts.PostClick then
    button.scripts.PostClick()
end
check(
    "unleash restores both spells and one paw macro",
    actions[1] ~= nil
        and actions[2] ~= nil
        and countAction(pawRow.index) == 1
        and ((actions[1].id == 100 and actions[2].id == pawRow.index) or (actions[2].id == 200 and actions[1].id == pawRow.index) or (actions[1].id == 200 and actions[2].id == pawRow.index) or (actions[2].id == 100 and actions[1].id == pawRow.index))
)
local covered = actions[1].id == pawRow.index and 1 or 2
local resumed = nil
for i = 1, #tickers do
    if tickers[i].interval == 5 and tickers[i].cancelled ~= true then
        resumed = tickers[i]
    end
end
local placesBefore = #places
resumed.fn()
local putBack = false
for i = placesBefore + 1, #places do
    local row = places[i]
    if row.slot == covered and row.cursor and row.cursor.type == "spell" then
        putBack = true
    end
end
check("paw swap after unleash puts that spell back", resumed ~= nil and putBack == true and countAction(pawRow.index) == 1)
CCT.Mittens.Set("Nyx", "none")
for slot = 1, 120 do
    actions[slot] = nil
end
PickupSpell = pawPickup
GetCursorInfo = nil
C_Spell = nil
C_SpellBook = nil

local syncBackup = char().leashSlots
actions[5] = { type = "spell", id = 77 }
CCT.State.SetLeash(true, "Nyx")
check("sync does not recapture", char().leashSlots == syncBackup and actions[5].id == 77 and state().leash == true)
CCT.State.SetLeash(false, nil)
actions[5] = nil
check("direct unleash leaves the bar", actions[5] == nil and state().leash == false)

gagCalls = 0
clearList(sent)
clearList(lines)
clearList(notices)
local huge = cmd("op:gag,state:HUGE,cid:AbC")
check("huge gag parses without the cmd word", huge.ok == true and huge.op == "gag" and huge.cid == "AbC" and state().gag == "huge")
check("huge gag whisper is the message", #sent == 1 and sent[1].msg == CCT.Messages.GAG_HEAVY and sent[1].target == "Nyx" and sent[1].chatType == "WHISPER")
check("huge gag did not enter the gag filter", gagCalls == 0)
check("huge gag is not mmf", sent[1].msg:find("mmf", 1, true) == nil and sent[1].msg:find("mmmm", 1, true) == nil)
check("huge gag local and raid", hasLine("|cffff66ccCatgirlTracker:|r You've been heavily gagged nya~") and hasNotice("Gag applied: heavy gag."))
local sentBefore = #sent
local linesBefore = #lines
local quietHuge = cmd("Cmd,op:gag,state:huge")
check("repeat gag is quiet", quietHuge.ok == true and #sent == sentBefore and #lines == linesBefore)
linesBefore = #lines
local slashQuiet = CCT.Commands.Slash("Cmd,op:gag,state:huge")
check("slash prints and receive did not", slashQuiet.ok == true and #lines == linesBefore + 1 and lines[#lines] == "CatgirlTracker: applied gag")

clearList(sent)
clearList(notices)
local stepped = cmd("Cmd,op:gagstep,dir:up")
check("gagstep up from huge becomes inflatable", stepped.ok == true and state().gag == "inflatable" and state().gagStage == 1)
check("gagstep up announce", hasWhisper(CCT.Messages.GAG_INFLATE, "Nyx") and hasNotice("Gag inflated to stage 1."))
for stage = 2, 5 do
    local up = cmd("Cmd,op:gagstep,dir:UP")
    check("gag stage " .. stage, up.ok == true and state().gagStage == stage)
end
sentBefore = #sent
local capped = cmd("Cmd,op:gagstep,dir:up")
check("gag stage five is quiet", capped.ok == true and state().gagStage == 5 and #sent == sentBefore)
local down = cmd("Cmd,op:gagstep,dir:down")
check("gagstep down", down.ok == true and state().gagStage == 4 and hasNotice("Gag deflated to stage 4."))
CCT.State.SetGag("inflatable", 1)
sentBefore = #sent
local floorStep = cmd("Cmd,op:gagstep,dir:down")
check("gag stage one is quiet", floorStep.ok == true and state().gagStage == 1 and #sent == sentBefore)
CCT.State.SetGag("small", nil)
local refused = cmd("Cmd,op:gagstep,dir:down")
check("gagstep down needs an inflatable", refused.reason == "gag" and state().gag == "small")
clearList(sent)
clearList(lines)
cmd("Cmd,op:gag,state:none")
check("ungag", state().gag == "none" and hasWhisper(CCT.Messages.GAG_REMOVE, "Nyx") and hasLine("|cffaaffaaCatgirlTracker:|r You've been ungagged nya~") and hasNotice("Gag removed."))

clearList(sent)
clearList(lines)
clearList(notices)
local blind = CCT.Commands.Slash("Cmd,op:blind,state:light")
check("slash blind applies as the owner", blind.ok == true and state().blind == "light" and hasWhisper(CCT.Messages.BLINDFOLD_LIGHT, "Nyx") and hasNotice("Blindfold applied: light."))
check("blind has no local print before the slash line", lines[#lines] == "CatgirlTracker: applied blind" and #lines == 1)
cmd("Cmd,op:blind,state:mask")
check("kitty mask", state().blind == "mask" and hasWhisper(CCT.Messages.BLINDFOLD_KITTY, "Nyx") and hasNotice("Blindfold applied: kitty mask."))
cmd("Cmd,op:blind,state:full")
check("full blind", state().blind == "full" and hasNotice("Blindfold applied: full."))
cmd("Cmd,op:blind,state:none")
check("blind removed", state().blind == "none" and hasWhisper(CCT.Messages.BLINDFOLD_REMOVE, "Nyx") and hasNotice("Blindfold removed."))

clearList(lines)
clearList(notices)
cmd("Cmd,op:ears,state:heavy")
check("heavy earmuffs", state().ears == "heavy" and hasLine("Heavy earmuffs secured. Everything sounds like muffled nonsense.") and hasNotice("Earmuffs applied: heavy."))
cmd("Cmd,op:ears,state:none")
check("earmuffs removed", state().ears == "none" and hasLine("Your earmuffs have been removed.") and hasNotice("Earmuffs removed."))

clearList(sent)
clearList(notices)
cmd("Cmd,op:mittens,state:squeaking")
check("squeaking mittens", state().mittens == "squeaking" and hasWhisper(CCT.Messages.PAW_MITTENS_RESPONSE_SQUEAKING, "Nyx") and hasNotice("Squeaking paw mittens locked."))
cmd("Cmd,op:mittens,state:locked")
check("locked mittens", state().mittens == "locked" and hasWhisper(CCT.Messages.PAW_MITTENS_RESPONSE_LOCKED, "Nyx") and hasNotice("Paw mittens locked: paws restricted."))
cmd("Cmd,op:mittens,state:heavy")
check("heavy mittens share the locked reply", state().mittens == "heavy" and hasNotice("Paw mittens locked: paws restricted."))
cmd("Cmd,op:mittens,state:none")
check("mittens removed", state().mittens == "none" and hasWhisper(CCT.Messages.PAW_MITTENS_REMOVE, "Nyx") and hasNotice("Paw mittens removed."))

clearList(sent)
clearList(notices)
cmd("Cmd,op:heels,state:maid")
check("maid heels", state().heels == "maid" and hasWhisper(CCT.Messages.HEELS_RESPONSE_MAID, "Nyx") and hasNotice("Maid heels locked (3 cm)."))
cmd("Cmd,op:heels,state:high")
check("high heels", state().heels == "high" and hasNotice("High heels locked (8 cm)."))
cmd("Cmd,op:heels,state:ballet")
check("ballet heels", state().heels == "ballet" and hasNotice("Ballet boots locked (12 cm)."))
cmd("Cmd,op:heels,state:none")
check("heels removed", state().heels == "none" and hasWhisper(CCT.Messages.HEELS_REMOVE, "Nyx") and hasNotice("Heels removed."))

clearList(lines)
clearList(notices)
cmd("Cmd,op:bell,which:collar,on:1")
check("collar bell", state().bell == true and hasLine("|cffffff00CatgirlTracker:|r You now wear a jingling bell on your collar nya...") and hasNotice("Bell attached."))
cmd("Cmd,op:bell,which:collar,on:0")
check("collar bell off", state().bell == false and hasLine("|cffffff00CatgirlTracker:|r The bell has been removed... you're safe for now nya.") and hasNotice("Bell removed."))
cmd("Cmd,op:bell,which:tail,on:1")
check("tail bell", state().tail == true and hasLine("|cffffff00CatgirlTracker:|r You now wear a jingling tail bell nya...") and hasNotice("Tail bell attached."))
cmd("Cmd,op:bell,which:tail,on:0")
check("tail bell off", state().tail == false and hasLine("|cffffff00CatgirlTracker:|r The tail bell has been removed... you're safe for now nya.") and hasNotice("Tail bell removed."))
local badBell = cmd("Cmd,op:bell,which:paw,on:1")
check("bell which is refused", badBell.reason == "which" and state().bell == false)

clearList(lines)
clearList(notices)
local jewel = CCT.Commands.Receive("nyx", "Cmd,op:jewel,on:1,cid:Jewel9", now, false)
check("lower case owner", jewel.ok == true and jewel.cid == "Jewel9" and state().jewel == true)
check("jewel on", hasLine("|cffffff00CatgirlTracker:|r Your tracking jewel glows. Location tracking enabled.") and hasNotice("Tracking jewel attached."))
cmd("Cmd,op:jewel,on:0")
check("jewel off", state().jewel == false and hasLine("|cffffff00CatgirlTracker:|r The tracking jewel has been removed. Location tracking disabled.") and hasNotice("Tracking jewel removed."))
check("jewel did not sample a position", state().pos == nil or state().pos.x == nil)

local modeEarly = cmd("Cmd,op:beltmode,mode:deny")
check("mode is ignored while the belt is off", modeEarly.reason == "belt" and state().belt == false and state().beltMode == "allow")

clearList(sent)
clearList(notices)
cmd("Cmd,op:belt,on:1")
check("belt locked", state().belt == true and state().beltMode == "allow" and hasWhisper(CCT.Messages.CHASTITY_BELT_APPLY, "Nyx") and hasNotice("Chastity belt locked."))
sentBefore = #sent
local beltQuiet = CCT.Chastity.SetBelt(true, "Nyx")
check("repeat belt is quiet", beltQuiet == true and select(3, CCT.Chastity.SetBelt(true, "Nyx")) == true and #sent == sentBefore)
cmd("Cmd,op:beltmode,mode:DENY")
check("belt deny", state().beltMode == "deny" and hasWhisper(CCT.Messages.CHASTITY_BELT_DENY, "Nyx") and hasNotice("Chastity belt set to Deny Orgasm."))
CCT.State.SetHeat(10)
local deniedBefore = char().life.denied
local denyCounter = state().counters.deny
local orgasmBefore = state().counters.orgasm
local afterBefore = #afters
shockLoads = false
clearList(sent)
clearList(notices)
local allowed, newHeat = CCT.Chastity.OnOrgasmAttempt()
local shockFrame = frameNamed("CatgirlChastityShockFrame")
check("deny returns heat 70", allowed == false and newHeat == 70 and state().heat == 70)
check("deny counts life and the week", char().life.denied == deniedBefore + 1 and state().counters.deny == denyCounter + 1 and state().counters.orgasm == orgasmBefore)
check("missing shock art stays hidden", shockFrame ~= nil and shockFrame.shown == false and shockFrame.strata == "FULLSCREEN_DIALOG" and shockFrame.texture:GetTexture() == nil)
check("missing shock art does not start the timer", #afters == afterBefore)
check("deny whisper and raid", hasWhisper(CCT.Messages.CHASTITY_DENY_SHOCK, "Nyx") and hasNotice("Chastity belt denied an orgasm."))

shockLoads = true
afterBefore = #afters
local secondAllowed, secondHeat = CCT.Chastity.OnOrgasmAttempt()
check("loaded shock shows", secondAllowed == false and secondHeat == 70 and shockFrame.shown == true and type(shockFrame.texture:GetTexture()) == "string")
check("loaded shock starts five seconds", #afters == afterBefore + 1 and afters[#afters].delay == 5)
local firstTimer = afters[#afters].fn
CCT.Chastity.OnOrgasmAttempt()
local secondTimer = afters[#afters].fn
firstTimer()
check("an older shock does not hide the new one", shockFrame.shown == true)
secondTimer()
check("the newest shock hides itself", shockFrame.shown == false)
check("three denies counted", char().life.denied == deniedBefore + 3 and state().counters.deny == denyCounter + 3)

cmd("Cmd,op:beltmode,mode:allow")
CCT.State.SetHeat(15)
local deniedAtAllow = char().life.denied
local allowOk, allowHeat = CCT.Chastity.OnOrgasmAttempt()
check("allow does not force heat 70", allowOk == true and allowHeat == nil and state().heat == 15 and char().life.denied == deniedAtAllow and state().counters.orgasm == orgasmBefore)

clearList(notices)
cmd("Cmd,op:belt,on:0")
check("removing the belt forces allow", state().belt == false and state().beltMode == "allow" and hasNotice("Chastity belt removed."))
check("removal is not a second allow raid", hasNotice("Chastity belt set to Allow Orgasm.") == false)
cmd("Cmd,op:bra,on:1")
check("bra locked", state().bra == true and hasWhisper(CCT.Messages.CHASTITY_BRA_APPLY, "Nyx") and hasNotice("Chastity bra locked."))
cmd("Cmd,op:bra,on:0")
check("bra removed", state().bra == false and hasNotice("Chastity bra removed."))

local shockIds = {
    dildo = true,
    vibes_ears = true,
    nipple_piercings = true,
    ear_piercings = true,
    pussy_lipps_piercings = true,
}
local plugIds = {
    inflatable_butplug = true,
    small_butplug = true,
    large_butplug = true,
    taill_butplug = true,
}
check("toy catalogs match in length", #CCT.Toys.List == 12 and #CCT.State.Toys == 12)
for i = 1, #CCT.Toys.List do
    local toy = CCT.Toys.List[i]
    local spec = CCT.State.Toys[i]
    local shockOn = toy.shock == true
    local plugOn = toy.group == "butplug"
    check(
        "catalog " .. tostring(toy.id),
        spec ~= nil
            and spec.id == toy.id
            and spec.restrict == toy.restrict
            and spec.group == toy.group
            and spec.vibe == toy.vibe
            and spec.inflate == toy.inflate
            and shockOn == (shockIds[toy.id] == true)
            and plugOn == (plugIds[toy.id] == true)
            and CCT.Toys.Find(toy.id) == toy
    )
end
check("inflatable dildo is not a butplug", CCT.Toys.Find("inflatable_dildo").group == nil)
check("dildo icon", CCT.Toys.Icon("dildo") == CCT.MEDIA .. "Textures\\Dildo.tga")
for id in pairs(shockIds) do
    check(id .. " shock heat", CCT.Toys.ShockHeat(id, 1) == -5 and CCT.Toys.ShockHeat(id, 2) == -10 and CCT.Toys.ShockHeat(id, 3) == -15)
end

CCT.Sounds = {
    PlayToyInflateDeflate = function(id, dir)
        sounds[#sounds + 1] = { "inflate", id, dir }
    end,
    SetToyVibeState = function(id, stage)
        sounds[#sounds + 1] = { "vibe", id, stage }
    end,
    PlayToyShock = function(stage)
        sounds[#sounds + 1] = { "shock", stage }
    end,
}

local function soundCount(kind, id, dir)
    local n = 0
    for i = 1, #sounds do
        local row = sounds[i]
        if row[1] == kind and (id == nil or row[2] == id) and (dir == nil or row[3] == dir) then
            n = n + 1
        end
    end
    return n
end

clearList(sent)
clearList(lines)
clearList(notices)
local toyApply = cmd("Cmd,op:toy,id:Inflatable_Dildo,action:APPLY,cid:Toy9")
check("inflatable dildo applies", toyApply.ok == true and toyApply.cid == "Toy9" and state().toys.inflatable_dildo.applied == true and state().toys.inflatable_dildo.inflate == 1)
check("apply whisper has no format hole", hasWhisper(CCT.Messages.TOY_INFLATABLE_DILDO_APPLY, "Nyx"))
check("apply notify", hasLine("|cffcc88ffCatgirlTracker:|r Toy applied: Inflatable Dildo.") and hasNotice("Toy applied: Inflatable Dildo."))
check("apply plays inflate", soundCount("inflate", "inflatable_dildo", "inflate") == 1)

cmd("Cmd,op:toy,id:small_butplug,action:apply")
check("small butplug", state().toys.small_butplug.applied == true and state().toys.inflatable_dildo.applied == true)
cmd("Cmd,op:toy,id:large_butplug,action:apply")
check("large replaces small", state().toys.large_butplug.applied == true and state().toys.small_butplug.applied == false and hasLine("|cffcc88ffCatgirlTracker:|r Toy removed: Small Butplug."))
cmd("Cmd,op:toy,id:taill_butplug,action:apply")
check("taill replaces large", state().toys.taill_butplug.applied == true and state().toys.large_butplug.applied == false)
local deflatesBefore = soundCount("inflate", "inflatable_butplug", "deflate")
cmd("Cmd,op:toy,id:inflatable_butplug,action:apply")
check(
    "inflatable butplug replaces taill",
    state().toys.inflatable_butplug.applied == true
        and state().toys.inflatable_butplug.inflate == 1
        and state().toys.taill_butplug.applied == false
        and state().toys.inflatable_dildo.applied == true
)
check("cleared inflate toy does not deflate", soundCount("inflate", "inflatable_butplug", "deflate") == deflatesBefore)
sentBefore = #sent
local reToy = CCT.Toys.Handle("inflatable_butplug", "apply", nil, "Nyx")
check("reapply is quiet", reToy == true and select(3, CCT.Toys.Handle("inflatable_butplug", "apply", nil, "Nyx")) == true and #sent == sentBefore)

local soundsAtSwitch = #sounds
cmd("Cmd,op:toy,id:small_butplug,action:apply")
local switchedDeflate = false
for i = soundsAtSwitch + 1, #sounds do
    if sounds[i][3] == "deflate" then
        switchedDeflate = true
    end
end
check("switching plugs does not deflate", switchedDeflate == false and state().toys.inflatable_butplug.applied == false and state().toys.inflatable_butplug.inflate == 0 and state().toys.inflatable_dildo.applied == true)

local inflateSounds = soundCount("inflate", "inflatable_dildo", "inflate")
local steppedToy = CCT.Toys.Handle("inflatable_dildo", "inflate", 5, "Nyx")
check("inflate steps by one", steppedToy == true and state().toys.inflatable_dildo.inflate == 2 and hasWhisper(CCT.Messages.TOY_INFLATABLE_DILDO_INFLATE_2, "Nyx"))
check("inflate sound", soundCount("inflate", "inflatable_dildo", "inflate") == inflateSounds + 1)
CCT.Toys.Handle("inflatable_dildo", "deflate", 5, "Nyx")
check("deflate steps by one", state().toys.inflatable_dildo.inflate == 1 and hasWhisper(CCT.Messages.TOY_INFLATABLE_DILDO_DEFLATE_1, "Nyx"))
sentBefore = #sent
local quietDeflate = CCT.Toys.Handle("inflatable_dildo", "deflate", 1, "Nyx")
check("deflate at one is quiet", quietDeflate == true and select(3, quietDeflate) == nil)
check("deflate at one does not whisper", #sent == sentBefore and state().toys.inflatable_dildo.inflate == 1)
CCT.State.SetToyInflate("inflatable_dildo", 5)
sentBefore = #sent
local quietInflate = CCT.Toys.Handle("inflatable_dildo", "inflate", nil, "Nyx")
check("inflate at five is quiet", quietInflate == true and select(2, CCT.Toys.Handle("inflatable_dildo", "inflate", nil, "Nyx")) == nil and state().toys.inflatable_dildo.inflate == 5 and #sent == sentBefore)

cmd("Cmd,op:belt,on:1")
clearList(sent)
local blocked = cmd("Cmd,op:toy,id:dildo,action:apply")
check("belt blocks a dildo", blocked.reason == "belt" and state().toys.dildo.applied ~= true and hasWhisper(CCT.Msg("TOY_BLOCKED_BELT", "Dildo"), "Nyx"))
cmd("Cmd,op:bra,on:1")
clearList(sent)
local braBlocked = cmd("Cmd,op:toy,id:nipple_piercings,action:apply")
check("bra blocks nipple piercings", braBlocked.reason == "bra" and state().toys.nipple_piercings.applied ~= true and hasWhisper(CCT.Msg("TOY_BLOCKED_BRA", "Nipple Piercings"), "Nyx"))
local earsToy = cmd("Cmd,op:toy,id:vibes_ears,action:apply")
local earToy = cmd("Cmd,op:toy,id:ear_piercings,action:apply")
check("ears are not restricted", earsToy.ok == true and earToy.ok == true and state().toys.vibes_ears.applied == true and state().toys.ear_piercings.applied == true)
local vibe = cmd("Cmd,op:toy,id:vibes_ears,action:vibe,level:2")
check("vibe works under a belt", vibe.ok == true and state().toys.vibes_ears.vibe == 2 and hasWhisper(CCT.Messages.TOY_VIBES_EARS_VIBE_2, "Nyx") and hasNotice("Vibes Ears vibration set to 2."))
sentBefore = #sent
local sameVibe = CCT.Toys.Handle("vibes_ears", "vibe", 2, "Nyx")
check("same vibe is quiet", sameVibe == true and select(3, CCT.Toys.Handle("vibes_ears", "vibe", "2", "Nyx")) == true and #sent == sentBefore)
clearList(sent)
clearList(lines)
local missingOk, missingReason = CCT.Toys.Handle("vibes_pussy", "vibe", 3, "Nyx")
check("vibe on an absent toy", missingOk == false and missingReason == "applied")
check("absent toy whispers", hasWhisper(CCT.Msg("TOY_NOT_APPLIED", "Vibes Pussy"), "Nyx"))
check("absent toy does not notify", hasLine("|cffcc88ffCatgirlTracker:|r Vibes Pussy vibration set to 3.") == false)

CCT.Toys.Handle("vibes_ears", "vibe", 0, "Nyx")
check("vibe zero becomes one", state().toys.vibes_ears.vibe == 1)
CCT.Toys.Handle("vibes_ears", "vibe", 9, "Nyx")
check("vibe nine becomes five", state().toys.vibes_ears.vibe == 5)
CCT.Toys.Handle("vibes_ears", "vibe", 2.4, "Nyx")
check("vibe rounds down", state().toys.vibes_ears.vibe == 2)
CCT.Toys.Handle("vibes_ears", "vibe", 2.6, "Nyx")
check("vibe rounds up", state().toys.vibes_ears.vibe == 3)

cmd("Cmd,op:belt,on:0")
cmd("Cmd,op:toy,id:dildo,action:apply")
cmd("Cmd,op:belt,on:1")
CCT.State.SetHeat(40)
clearList(sent)
clearList(notices)
local shock = CCT.Toys.Handle("dildo", "shock", 2, "Nyx")
check("shock under a belt", shock == true and state().heat == 50 and state().toys.dildo.vibe == 0, "heat " .. tostring(state().heat) .. " sub " .. tostring(state().sub))
check("shock whisper", hasWhisper(CCT.Messages.TOY_DILDO_SHOCK_2, "Nyx") and hasNotice("Dildo shock intensity 2.") and soundCount("shock", 2) == 1)
sentBefore = #sent
CCT.Toys.Handle("dildo", "shock", 2, "Nyx")
check("shock is never quiet", #sent == sentBefore + 1 and state().heat == 60, "heat " .. tostring(state().heat))

local heatCalls = 0
local originalSetHeat = CCT.State.SetHeat
CCT.State.SetHeat = function(...)
    heatCalls = heatCalls + 1
    return originalSetHeat(...)
end
local deltas = {}
CCT.Heat = {
    AddDelta = function(delta)
        deltas[#deltas + 1] = delta
    end,
}
local heatNow = state().heat
CCT.Toys.Handle("dildo", "shock", 1, "Nyx")
check("heat module takes the delta", #deltas == 1 and deltas[1] == -5 and heatCalls == 0 and state().heat == heatNow)
CCT.HeatConfig = { toys = { dildo = { shock = { -1, -2, -3 } } } }
CCT.Toys.Handle("dildo", "shock", 2, "Nyx")
check("heat config overrides the fallback", deltas[#deltas] == -2 and heatCalls == 0)
CCT.HeatConfig = { toys = { dildo = { shock = { { heat = -7 }, { heat = -8 }, { heat = -9 } } } } }
CCT.Toys.Handle("dildo", "shock", 1, "Nyx")
check("heat config table form", deltas[#deltas] == -7)
CCT.Heat = nil
CCT.Toys.Handle("dildo", "shock", 3, "Nyx")
check("without the heat module config still applies", heatCalls == 1 and state().heat == heatNow - 9)
CCT.HeatConfig = nil
CCT.State.SetHeat = originalSetHeat

local badShock = CCT.Toys.Handle("small_butplug", "shock", 2, "Nyx")
check("a plug does not shock", badShock == false and select(2, CCT.Toys.Handle("small_butplug", "shock", 2, "Nyx")) == "shock")
local unknownToy = CCT.Toys.Handle("nope", "apply", nil, "Nyx")
check("unknown toy", unknownToy == false and select(2, CCT.Toys.Handle("nope", "apply", nil, "Nyx")) == "id")
local unknownAction = CCT.Toys.Handle("dildo", "spin", nil, "Nyx")
check("unknown toy action", unknownAction == false and select(2, CCT.Toys.Handle("dildo", "spin", nil, "Nyx")) == "action")

clearList(sent)
local blockedRemove = CCT.Toys.Handle("dildo", "remove", nil, "Nyx")
check("belt blocks removal", blockedRemove == false and select(2, CCT.Toys.Handle("dildo", "remove", nil, "Nyx")) == "belt" and state().toys.dildo.applied == true)
cmd("Cmd,op:belt,on:0")
cmd("Cmd,op:bra,on:0")
local vibeSounds = soundCount("vibe", "dildo", 0)
cmd("Cmd,op:toy,id:dildo,action:remove")
check("dildo removes", state().toys.dildo.applied == false and hasWhisper(CCT.Messages.TOY_DILDO_REMOVE, "Nyx") and soundCount("vibe", "dildo", 0) == vibeSounds + 1)
sentBefore = #sent
local quietRemove = CCT.Toys.Handle("dildo", "remove", nil, "Nyx")
check("remove of a clear toy is quiet", quietRemove == true and select(3, CCT.Toys.Handle("dildo", "remove", nil, "Nyx")) == true and #sent == sentBefore)

cmd("Cmd,op:toy,id:small_butplug,action:remove")
cmd("Cmd,op:toy,id:inflatable_dildo,action:remove")
check("toys are clear", state().toys.small_butplug.applied == false and state().toys.inflatable_dildo.applied == false and state().belt == false and state().bra == false)

now = 100000
local lockLines = #lines
local lockNotices = #notices
local lockSent = #sent
local timed = cmd("Cmd,op:lock,bind:gag,minutes:90,cid:Lock1")
check("lock stores ninety minutes", timed.ok == true and timed.cid == "Lock1" and state().locks.gag.minutes == 90 and state().locks.gag.unlockAt == 100000 + 5400)
check("lock does not equip or announce", state().gag == "none" and #lines == lockLines and #notices == lockNotices and #sent == lockSent)
local cappedLock = cmd("Cmd,op:lock,bind:earmuffs,minutes:20000")
check("lock minutes cap", cappedLock.ok == true and state().locks.earmuffs.minutes == 10080 and state().locks.earmuffs.unlockAt == 100000 + 10080 * 60)
check("lock cap does not equip ears", state().ears == "none")
local zeroLock = cmd("Cmd,op:lock,bind:bell,minutes:0")
check("zero minutes fail", zeroLock.reason == "minutes" and state().locks.bell == nil)
local badBind = cmd("Cmd,op:lock,bind:hat,minutes:5")
check("unknown bind fails", badBind.reason == "bind")
local missingMinutes = cmd("Cmd,op:lock,bind:gag")
check("missing minutes fail", missingMinutes.reason == "minutes" and state().locks.gag ~= nil)
CCT.State.SetLock("gag", nil)
CCT.State.SetLock("earmuffs", nil)
check("clearing a lock leaves the worn state", state().locks.gag == nil and state().locks.earmuffs == nil and state().gag == "none")

now = 200000
CCT.State.SetGag("huge")
CCT.State.SetLock("gag", 90)
local keptUnlock = state().locks.gag.unlockAt
CCT.State.SetGag("small")
check("swapping a gag keeps its lock", state().gag == "small" and state().locks.gag ~= nil and state().locks.gag.unlockAt == keptUnlock)
local linesBeforeUngag = #lines
local noticesBeforeUngag = #notices
CCT.State.SetGag("none")
check(
    "manual ungag clears the lock without expiry lines",
    state().gag == "none"
        and state().locks.gag == nil
        and #lines == linesBeforeUngag
        and #notices == noticesBeforeUngag
)
now = 210000
CCT.State.SetLock("gag", 30)
check("a lock can arm while the gag is off", state().gag == "none" and state().locks.gag.unlockAt == 210000 + 1800)
CCT.State.SetGag("none")
check("ungag cancels a lock that is still armed", state().locks.gag == nil)
CCT.State.SetEars("heavy")
CCT.State.SetLock("earmuffs", 10)
CCT.State.SetEars("kitten")
check("swapping earmuffs keeps the lock", state().ears == "kitten" and state().locks.earmuffs ~= nil)
CCT.State.SetEars("none")
check("removing earmuffs clears the lock", state().ears == "none" and state().locks.earmuffs == nil)
CCT.State.SetBell(true)
CCT.State.SetLock("bell", 10)
CCT.State.SetBell(false)
check("removing the bell clears the lock", state().bell == false and state().locks.bell == nil)
CCT.State.SetTail(true)
CCT.State.SetLock("tailbell", 10)
CCT.State.SetTail(false)
check("removing the tail bell clears the lock", state().tail == false and state().locks.tailbell == nil)
CCT.State.SetMittens("locked")
CCT.State.SetLock("mittens", 10)
CCT.State.SetMittens("none")
check("removing mittens clears the lock", state().mittens == "none" and state().locks.mittens == nil)
CCT.State.SetHeels("maid")
CCT.State.SetLock("heels", 10)
CCT.State.SetHeels("high")
check("swapping heels keeps the lock", state().heels == "high" and state().locks.heels ~= nil)
CCT.State.SetHeels("none")
check("removing heels clears the lock", state().heels == "none" and state().locks.heels == nil)
CCT.State.SetBlind("light")
CCT.State.SetLock("blindfold", 10)
CCT.State.SetBlind("none")
check("removing a blindfold clears the lock", state().blind == "none" and state().locks.blindfold == nil)
CCT.State.SetBelt(true)
CCT.State.SetBeltMode("deny")
CCT.State.SetLock("chastitybelt", 10)
CCT.State.SetBelt(false)
check(
    "removing the belt clears the lock",
    state().belt == false and state().beltMode == "allow" and state().locks.chastitybelt == nil
)
CCT.State.SetBra(true)
CCT.State.SetLock("chastitybra", 10)
CCT.State.SetBra(false)
check("removing the bra clears the lock", state().bra == false and state().locks.chastitybra == nil)

local LOCKS = {
    {
        bind = "gag",
        wear = function()
            CCT.State.SetGag("huge", nil)
        end,
        clear = function()
            return state().gag == "none" and state().gagStage == 0
        end,
        system = "|cffffff00[System]:|r Your gag has been automatically removed nya~",
        lock = "|cffffff00[System]:|r Your gag lock has expired!",
        raid = "Gag removed (timer expired).",
    },
    {
        bind = "earmuffs",
        wear = function()
            CCT.State.SetEars("kitten")
        end,
        clear = function()
            return state().ears == "none"
        end,
        system = "Earmuffs removed",
        lock = "|cff88ccff[System]:|r Your earmuffs were removed as the timer expired.",
        raid = "Earmuffs removed (timer expired).",
    },
    {
        bind = "blindfold",
        wear = function()
            CCT.State.SetBlind("full")
        end,
        clear = function()
            return state().blind == "none"
        end,
        lock = "|cffff99ff[System]:|r The blindfold timer ended. You can see again!",
        raid = "Blindfold removed (timer expired).",
    },
    {
        bind = "bell",
        wear = function()
            CCT.State.SetBell(true)
        end,
        clear = function()
            return state().bell == false
        end,
        system = "|cffffff00[System]:|r Your bell has been automatically removed nya~",
        lock = "|cffffcc00[System]:|r The bell fell off as the time ran out.",
        raid = "Bell removed (timer expired).",
    },
    {
        bind = "tailbell",
        wear = function()
            CCT.State.SetTail(true)
        end,
        clear = function()
            return state().tail == false
        end,
        system = "|cffffff00[System]:|r Your tail bell has been automatically removed nya~",
        lock = "|cffffcc00[System]:|r The tail bell fell off as the time ran out.",
        raid = "Tail bell removed (timer expired).",
    },
    {
        bind = "mittens",
        wear = function()
            CCT.State.SetMittens("locked")
        end,
        clear = function()
            return state().mittens == "none"
        end,
        system = "|cffffff00[System]:|r Your paw mittens lock has expired!",
        lock = "|cffffff00[System]:|r The paw mittens lock timer ended.",
        raid = "Paw mittens removed (timer expired).",
    },
    {
        bind = "heels",
        wear = function()
            CCT.State.SetHeels("maid")
        end,
        clear = function()
            return state().heels == "none"
        end,
        system = "|cffffff00[System]:|r Your heel lock has expired!",
        lock = "|cffffff00[System]:|r The heel lock timer ended.",
        raid = "Heels removed (timer expired).",
    },
    {
        bind = "chastitybelt",
        wear = function()
            CCT.State.SetBelt(true)
            CCT.State.SetBeltMode("deny")
        end,
        clear = function()
            return state().belt == false and state().beltMode == "allow"
        end,
        system = "|cffffff00[System]:|r Your chastity belt has been automatically removed nya~",
        lock = "|cffffff00[System]:|r The chastity belt timer ended.",
        raid = "Chastity belt removed (timer expired).",
    },
    {
        bind = "chastitybra",
        wear = function()
            CCT.State.SetBra(true)
        end,
        clear = function()
            return state().bra == false
        end,
        system = "|cffffff00[System]:|r Your chastity bra has been automatically removed nya~",
        lock = "|cffffff00[System]:|r The chastity bra timer ended.",
        raid = "Chastity bra removed (timer expired).",
    },
}

for i = 1, #LOCKS do
    local row = LOCKS[i]
    now = 800000 + i * 1000
    row.wear()
    local started = now
    local setOk = CCT.Locks.Set(row.bind, 1)
    local lock = state().locks[row.bind]
    linesBefore = #lines
    local noticesBefore = #notices
    sentBefore = #sent
    now = started + 60
    local fired = CCT.Locks.Sweep(now)
    local added = {}
    for n = linesBefore + 1, #lines do
        added[#added + 1] = lines[n]
    end
    local expectedLines = {}
    if row.system ~= nil then
        expectedLines[#expectedLines + 1] = row.system
    end
    expectedLines[#expectedLines + 1] = row.lock
    local linesMatch = #added == #expectedLines
    if linesMatch then
        for n = 1, #expectedLines do
            if added[n] ~= expectedLines[n] then
                linesMatch = false
            end
        end
    end
    local raid = notices[noticesBefore + 1]
    check(
        row.bind .. " expires once",
        setOk == true
            and lock ~= nil
            and lock.unlockAt == started + 60
            and fired == 1
            and row.clear()
            and state().locks[row.bind] == nil
            and linesMatch
            and raid == row.raid
            and #notices == noticesBefore + 1
            and #sent == sentBefore
            and CCT.Locks.Sweep(now) == 0
            and #lines == linesBefore + #expectedLines,
        table.concat(added, " || ")
    )
end
check("expiry did not add worn minutes", state().counters.gagMin == 0 and state().counters.playMin == 0 and state().counters.heelsMin == 0)

now = 910000
CCT.State.SetHeels("ballet")
CCT.State.SetLock("heels", 30)
state().locks.heels.unlockAt = now - 5
linesBefore = #lines
local noticesBefore = #notices
local gagMin = state().counters.gagMin
local playMin = state().counters.playMin
fire("PLAYER_LOGIN")
check("offline heel lock expires on login", state().heels == "none" and state().locks.heels == nil)
check(
    "offline heel lines",
    lines[linesBefore + 1] == "|cffffff00[System]:|r Your heel lock has expired!"
        and lines[linesBefore + 2] == "|cffffff00[System]:|r The heel lock timer ended."
        and notices[noticesBefore + 1] == "Heels removed (timer expired)."
)
check("login pass adds no minutes", state().counters.gagMin == gagMin and state().counters.playMin == playMin)
local linesAfterLogin = #lines
local noticesAfterLogin = #notices
fire("PLAYER_LOGIN")
check("a second login does not expire again", #lines == linesAfterLogin and #notices == noticesAfterLogin and state().heels == "none")

publishRoster({})
CCT.Roster.Rebuild()
local bypassPending = CCT.Commands.Pending()
linesBefore = #lines
local bypass = CCT.Commands.Slash("Cmd,op:jewel,on:1")
check("slash bypasses a missing owner", bypass.ok == true and state().jewel == true and CCT.Commands.Pending() == bypassPending)
check("bypassed slash is not held", lines[#lines] == "CatgirlTracker: applied jewel" and lines[#lines - 1] ~= "CatgirlTracker: command held until the owner note is known.")
publishRoster(ownerRows())
CCT.Roster.Rebuild()

local replaced = false
CCT.Commands.Register("disc", function(_, fields)
    replaced = true
    return { ok = true, reason = nil, op = fields.op, cid = fields.cid }
end)
local registered = cmd("Cmd,op:disc,cid:Swap")
check("a handler can replace disc", replaced == true and registered.ok == true and registered.cid == "Swap" and invites == 0)
CCT.Commands.Register("disc", function(_, fields)
    return { ok = false, reason = "later", op = fields.op, cid = fields.cid }
end)

publishRoster({})
CCT.Roster.Rebuild()
local tickerHeld = CCT.Commands.Receive("Nyx", "Cmd,op:ears,state:heavy", now, false)
check("ticker sees a hold", tickerHeld.reason == "hold" and state().ears ~= "heavy")
publishRoster(ownerRows())
CCT.Roster.Rebuild()
lockTicker.fn()
check("the lock ticker flushes a ready command", state().ears == "heavy" and CCT.Commands.Pending() == 0)
CCT.State.SetEars("none")

linesBefore = #lines
noticesBefore = #notices
lockTicker.fn()
check("a later idle tick stays silent", #lines == linesBefore and #notices == noticesBefore)
check("party was never invited", invites == 0 and leaves == 0)
check("addon messages stayed unused", true)

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr4 self-check passed")
