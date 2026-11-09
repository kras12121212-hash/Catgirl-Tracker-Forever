-- PR 8 self-check. Run from the repo root:
--   lua tools/pr8_selfcheck.lua
-- Maid sync, the pet button, and Nya options. In-game play is not available here.

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

local script = (arg and arg[0]) or "tools/pr8_selfcheck.lua"
local root = script:gsub("/?tools/pr8_selfcheck%.lua$", "")
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

local function exists(path)
    local handle = io.open(path, "rb")
    if handle == nil then
        return false
    end
    handle:close()
    return true
end

local maidSrc = read(addon .. "/Kitten/Maid.lua")
local petSrc = read(addon .. "/Kitten/Pet.lua")
local nyaSrc = read(addon .. "/Owner/NyaOptions.lua")
local controlSrc = read(addon .. "/Owner/ControlCenter.lua")
local toc = read(addon .. "/CatgirlTracker_Forever.toc")

local function withoutItemApi(src)
    return src:gsub("C_Item%.GetItemInfoInstant", ""):gsub("C_Item%.GetItemInfo", "")
end

check("toc loads maid pet and nya", toc:find("Kitten/Maid.lua\nKitten/Pet.lua\n", 1, true) ~= nil and toc:find("Owner/NyaOptions.lua\nOwner/ControlCenter.lua\n", 1, true) ~= nil)
check("layer file is absent", exists(addon .. "/KittyLayerGroup.lua") == false)
check("layer chat stays named", controlSrc:find("KittyLayerGroup.lua layer list, linv, and the NWB read do not ship.", 1, true) ~= nil)
check("maid does not send addon messages", maidSrc:find("SendAddonMessage", 1, true) == nil and petSrc:find("SendAddonMessage", 1, true) == nil and nyaSrc:find("SendAddonMessage", 1, true) == nil)
check("maid uses the item api", withoutItemApi(maidSrc):find("GetItemInfo", 1, true) == nil and maidSrc:find("C_Item.GetItemCount", 1, true) ~= nil)
check("kitten tasks have one writer", maidSrc:find('CCT.State.AddCounter("tasks", 1)', 1, true) ~= nil)

local frames = {}
local sends = {}
local chats = {}
local lines = {}
local tickers = {}
local afters = {}
local created = {}
local macroBody = nil
local combat = false
local dead = false
local inGuild = true
local now = 1000
local itemCount = 0

local function auto(kind, name, parent, template)
    local obj = {
        kind = kind,
        name = name,
        parent = parent,
        template = template,
        events = {},
        scripts = {},
        attrs = {},
        points = {},
        shown = true,
        text = "",
    }
    frames[#frames + 1] = obj
    return setmetatable(obj, {
        __index = function(self, key)
            return function(s, ...)
                if key == "RegisterEvent" then
                    s.events[(...)] = true
                    return
                end
                if key == "SetScript" then
                    local which, fn = ...
                    s.scripts[which] = fn
                    return
                end
                if key == "SetText" then
                    s.text = (...) or ""
                    return
                end
                if key == "GetText" then
                    return s.text or ""
                end
                if key == "SetChecked" then
                    s.checked = (...) and true or false
                    return
                end
                if key == "Show" then
                    s.shown = true
                    return
                end
                if key == "Hide" then
                    s.shown = false
                    return
                end
                if key == "IsShown" then
                    return s.shown == true
                end
                if key == "SetAttribute" then
                    local attr, value = ...
                    s.attrs[attr] = value
                    return
                end
                if key == "GetPoint" then
                    if type(s.pointReturn) == "table" then
                        local row = s.pointReturn
                        return row[1], row[2], row[3], row[4], row[5]
                    end
                    return s
                end
                if key == "SetPoint" then
                    s.points[#s.points + 1] = { ... }
                    return
                end
                if key == "CreateFontString" or key == "CreateTexture" then
                    return auto(key)
                end
                return s
            end
        end,
    })
end

CreateFrame = function(kind, name, parent, template)
    return auto(kind or "Frame", name, parent, template)
end
UIParent = auto("UIParent")
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
}
SlashCmdList = {}
time = function()
    return now
end
date = os.date
math.random = function()
    return 0
end
GetTime = time
print = function(text)
    lines[#lines + 1] = tostring(text)
end
issecretvalue = function()
    return false
end
UnitName = function()
    return "Nyx"
end
UnitFullName = function()
    return "Nyx"
end
UnitGUID = function()
    return "Player-1"
end
UnitIsDeadOrGhost = function()
    return dead
end
InCombatLockdown = function()
    return combat
end
IsInGuild = function()
    return inGuild
end
IsInInstance = function()
    return false, "none"
end
IsInGroup = function()
    return false
end
IsInRaid = function()
    return false
end
Ambiguate = function(name)
    return (type(name) == "string" and name:match("^[^%-]+")) or name
end
C_GuildInfo = { GuildRoster = function() end }
GetNumGuildMembers = function()
    return 0
end
GetGuildRosterInfo = function()
    return nil
end
SendChatMessage = function(msg, chatType, language, target)
    chats[#chats + 1] = { msg = msg, chatType = chatType, target = target }
end
C_ChatInfo = {
    SendChatMessage = SendChatMessage,
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, message, chatType, target)
        sends[#sends + 1] = {
            prefix = prefix,
            message = message,
            chatType = chatType,
            target = target,
        }
        return 0
    end,
}
Enum = { SendAddonMessageResult = { Success = 0 } }
C_PartyInfo = { InviteUnit = function() end, LeaveParty = function() end }
C_Map = {
    GetBestMapForUnit = function()
        return 12
    end,
    GetPlayerMapPosition = function()
        return { x = 0.4, y = 0.5 }
    end,
}
GetInstanceInfo = function()
    return nil, nil, nil, nil, nil, nil, nil, 9
end
CreateMacro = function(name, icon, body, perChar)
    created[#created + 1] = { name = name, icon = icon, body = body, perChar = perChar }
    macroBody = body
    return 1
end
EditMacro = function(_, _, _, body)
    macroBody = body
end
GetMacroIndexByName = function(name)
    if name == "CatNya" and type(macroBody) == "string" then
        return 1
    end
    return 0
end
GetMacroInfo = function()
    return "CatNya", "INV_Misc_QuestionMark", macroBody
end

local CCT = {}
for line in toc:gmatch("[^\n]+") do
    if line:find("%.lua$") then
        local chunk, err = loadfile(addon .. "/" .. line)
        if chunk == nil then
            error(err)
        end
        chunk("CatgirlTracker_Forever", CCT)
    end
end

check("files load", CCT.Maid ~= nil and CCT.Pet ~= nil and CCT.NyaOptions ~= nil and CCT.Nya ~= nil and CCT.Net ~= nil)

local function countInterval(interval)
    local n = 0
    for i = 1, #tickers do
        if tickers[i].interval == interval and tickers[i].cancelled ~= true then
            n = n + 1
        end
    end
    return n
end

check("maid ticker is created once", countInterval(60) == 1)

local function fire(event, ...)
    local limit = #frames
    for i = 1, limit do
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

local function bind(name)
    UnitName = function()
        return name
    end
    UnitFullName = function()
        return name
    end
    CCT.Player.Refresh()
    CCT.Saved.Init()
    return CCT.State.Bind(name)
end

CCT.Roster.GetSelf = function()
    local short = CCT.Player and CCT.Player.short or ""
    return { short = short, online = true, ownerShort = "Nyx" }
end
CCT.Roster.GetOwnerShort = function()
    local row = CCT.Roster.GetSelf()
    return row and row.ownerShort or nil
end
CCT.Roster.GetAssignedKitten = function()
    return { short = "Kitten", online = true }
end
CCT.Roster.GetMember = function(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return { short = name, online = true }
end

bind("Kitten")
CCT.Net.Reset()
CCT.Net.Clock(1000)
CCT.Maid.Clock(1000)
CCT.Corroboration.Reset()

local function kittenTasks()
    local state = CCT.db.chars.Kitten and CCT.db.chars.Kitten.state
    local counters = state and state.counters
    return counters and tonumber(counters.tasks) or 0
end

local function ownerTasks()
    local week = CCT.Corroboration.Week("Kitten")
    return week and tonumber(week.tasks) or 0
end

local function shown()
    local state = CCT.db.chars.Kitten and CCT.db.chars.Kitten.state
    return state and state.maid or nil
end

local function wipe()
    bind("Nyx")
    local char = CCT.Saved.EnsureChar("Nyx")
    char.maid = { items = {}, instructions = {} }
    CCT.Module.Set("MaidTasks", true)
    CCT.Maid.Reset()
    CCT.Net.Reset()
    now = 1000
    CCT.Net.Clock(1000)
    CCT.Maid.Clock(1000)
    itemCount = 0
    C_Item = nil
end

local function pumpReliable()
    local guard = 0
    while CCT.Net.Depth().reliable > 0 and guard < 400 do
        guard = guard + 1
        local before = #sends
        CCT.Net.Pump()
        if #sends == before then
            CCT.Net.Clock(CCT.Net.Clock() + 2)
        end
    end
    return CCT.Net.Depth().reliable == 0
end

local function cmdsFrom(mark)
    local list = {}
    for i = mark + 1, #sends do
        local message = sends[i].message
        if type(message) == "string" and message:sub(1, 4) == "Cmd," then
            list[#list + 1] = sends[i]
        end
    end
    return list
end

local function deliverCmds(list)
    bind("Kitten")
    for i = 1, #list do
        CCT.Net.Receive("CatgirlTracker", list[i].message, "WHISPER", "Nyx")
    end
end

local function deliverAcks()
    local mark = #sends
    pumpReliable()
    local n = 0
    for i = mark + 1, #sends do
        local message = sends[i].message
        if type(message) == "string" and message:sub(1, 4) == "Ack," then
            n = n + 1
            CCT.Net.Receive("CatgirlTracker", message, "WHISPER", "Kitten")
        end
    end
    bind("Nyx")
    return n
end

local function cmdId(message)
    return type(message) == "string" and message:match("id:([^,]+)") or nil
end

local function headerThroughText(wire)
    local at = wire:find(",text:", 1, true)
    if at == nil then
        return nil
    end
    return at + #",text:" - 1
end

-- Nya stays off until a click, and a click can turn it off again.
check("nya starts off", CCT.Nya.Enabled() == false and CCT.Nya.GetSettings().chance == 50)
local nyaRows = CCT.NyaOptions.Rows()
check("nya rows expose the chance", nyaRows[#nyaRows].key == "chance" and nyaRows[#nyaRows].value == 50 and nyaRows[1].value == false)
check("nya click enables", CCT.NyaOptions.Click("enabled") == true and CCT.Nya.Enabled() == true)
check("nya click disables", CCT.NyaOptions.Click("enabled") == true and CCT.Nya.Enabled() == false)
check("nya chance clamps", CCT.NyaOptions.SetChance(4) == true and CCT.Nya.GetSettings().chance == 10)
CCT.NyaOptions.SetChance(50)
local window = CCT.Control.Open()
check("settings block attaches", window ~= nil and window.nya ~= nil and window.maid ~= nil and window.maid:GetText() == "0 items, 0 instructions")
local nyaChecks = 0
if window.nya and type(window.nya.checks) == "table" then
    for _, check in pairs(window.nya.checks) do
        if type(check.points) == "table" and #check.points > 0 then
            nyaChecks = nyaChecks + 1
        end
    end
end
check(
    "nyachat panel shows the options",
    window.nya ~= nil
        and window.nya.title ~= nil
        and window.nya.title.text == "NyaChat"
        and nyaChecks == 12
        and type(window.nya.cctHeight) == "number"
        and window.nya.cctHeight > 280
        and window.nya.chance ~= nil
        and window.nya.chance.text == "50"
        and window.nya.preview ~= nil
        and window.nya.preview.text:find("nya", 1, true) ~= nil
)
if CCT.State and CCT.State.SetGag then
    CCT.State.SetGag("none")
end
local bn = {}
BNSendWhisper = function(_, msg)
    bn[#bn + 1] = msg
end
CCT.Chat.Install()
BNSendWhisper(7, "Hello")
check("nyachat stays quiet while off", #bn == 1 and bn[1] == "Hello")
CCT.Nya.SetOption("enabled", true)
CCT.Nya.SetOption("asciiEmotes", false)
BNSendWhisper(7, "Hello")
local sayMark = #chats
SendChatMessage("Hello", "SAY")
check("nyachat rewrites say", #chats == sayMark + 1 and chats[#chats].msg == "Hello nya~")
check("nyachat rewrites a bnet whisper", bn[2] == "Hello nya~")
CCT.Chat.Send("Status line", "GUILD", nil, nil, { raw = true })
check("raw chat skips nyachat", chats[#chats].msg == "Status line")
CCT.Nya.SetOption("enabled", false)
CCT.Nya.SetOption("asciiEmotes", true)

-- Pet macro, button, and the five-minute reminder.
local carriers = {
    "/use Cat Carrier (Cornish Rex)",
    "/use Cat Carrier (Siamese)",
    "/use Cat Carrier (Orange Tabby)",
    "/use Cat Carrier (Silver Tabby)",
    "/use Cat Carrier (Black Tabby)",
    "/use Cat Carrier (Bombay)",
    "/use Cat Carrier (White Kitten)",
}
check("macro body is the seven carriers", CCT.Pet.MacroBody() == table.concat(carriers, "\n"))
local tickersAtLogin = #tickers
local savedCreate = CreateMacro
CreateMacro = function()
    error("blocked")
end
GetMacroIndexByName = function()
    return 0
end
combat = true
fire("PLAYER_LOGIN")
check("login does not add a maid ticker", countInterval(60) == 1 and #tickers >= tickersAtLogin)
check("combat defers the macro", #created == 0)
combat = false
local linesBefore = #lines
check("missing macro does not toggle", CCT.Pet.Click() == false and CCT.db.chars.Kitten.state.petSummoned ~= true and #lines == linesBefore + 1)
CreateMacro = savedCreate
GetMacroIndexByName = function(name)
    if name == "CatNya" and type(macroBody) == "string" then
        return 1
    end
    return 0
end
EditMacro = function(_, _, _, body)
    macroBody = body
end
fire("PLAYER_REGEN_ENABLED")
check("regen writes a general macro", #created == 1 and created[1].name == "CatNya" and created[1].icon == "INV_Misc_QuestionMark" and created[1].perChar == nil and created[1].body == CCT.Pet.MacroBody())
local summon = frameNamed("CatgirlSummonCatButton")
check("pet button is secure", summon ~= nil and summon.template == "UIPanelButtonTemplate,SecureActionButtonTemplate" and summon.attrs.macrotext1 == CCT.Pet.MacroBody() and summon.attrs.type1 == "macro")
local moved = CCT.Saved.EnsureChar("Kitten")
summon.scripts.OnDragStop(summon)
check("non string point is not saved", type(moved.petButton) ~= "table")
summon.pointReturn = { "BOTTOM", nil, "BOTTOM", 3, -20 }
summon.scripts.OnDragStop(summon)
check("string point is saved", moved.petButton and moved.petButton.point == "BOTTOM" and moved.petButton.x == 3 and moved.petButton.y == -20)
local clicked = CCT.Pet.Click()
check("click toggles summoned", clicked == true and CCT.Pet.Summoned() == true and summon.text == "Good Kitten!, You Cat is Summoned")
CCT.Pet.Click()
check("click toggles back", CCT.Pet.Summoned() == false and summon.text == "Summon your cat Nya !")

dead = true
inGuild = true
now = 5000
local chatsBefore = #chats
fire("PLAYER_LOGIN")
check("early reminder waits", CCT.Pet.Check(5299) == false and #chats == chatsBefore)
check("dead reminder waits", CCT.Pet.Check(5300) == false and #chats == chatsBefore)
dead = false
fire("PLAYER_ALIVE")
check("revival sends the bad line once", #chats == chatsBefore + 1 and chats[#chats].chatType == "GUILD" and chats[#chats].msg == CCT.Msg("PET_SUMMON_BAD"))
fire("PLAYER_ALIVE")
check("reminder does not repeat", #chats == chatsBefore + 1)
CCT.db.settings.flavorAnnouncements = false
now = 8000
fire("PLAYER_LOGIN")
CCT.Pet.Check(8300)
check("flavor off sends nothing", #chats == chatsBefore + 1)
CCT.db.settings.flavorAnnouncements = true
inGuild = false
now = 9000
fire("PLAYER_LOGIN")
CCT.Pet.Check(9300)
check("guild absence sends nothing", #chats == chatsBefore + 1)
inGuild = true
now = 10000
fire("PLAYER_LOGIN")
CCT.Pet.Click()
CCT.Pet.Check(10300)
check("summoned reminder is the good line", chats[#chats].msg == CCT.Msg("PET_SUMMON_GOOD") and chats[#chats].chatType == "GUILD" and kittenTasks() == 0)
CCT.Module.Set("PetTracker", false)
CCT.Pet.Apply()
check("disabled pet button hides", summon.shown == false)
CCT.Module.Set("PetTracker", true)
CCT.Pet.Apply()
check("enabled pet button shows", summon.shown == true)

-- Structural colons stay on zone and pet tokens.
local zoneParsed = CCT.Net.Parse("Zones,week:2026-W45,seq:1,z:Elwynn%3AForest:12")
check("zone token keeps the minutes", zoneParsed and zoneParsed.many.z[1].name == "Elwynn:Forest" and zoneParsed.many.z[1].minutes == 12)
local petParsed = CCT.Net.Parse("Pets,week:2026-W45,seq:1,p:pets:Nyx%3AOne")
check("pet token keeps the sender", petParsed and petParsed.many.p[1].action == "pets" and petParsed.many.p[1].sender == "Nyx:One")

-- Command edges that must not count.
wipe()
bind("Kitten")
local tasksBefore = kittenTasks()
local ownerBefore = ownerTasks()
local later = CCT.Commands.Receive("Nyx", "Cmd,op:maid,cid:Later1", 1000, false)
check("maid without an id stays later", later.ok == false and later.reason == "later" and later.cid == "Later1" and kittenTasks() == tasksBefore)
local stranger = CCT.Commands.Receive("Stranger", "Cmd,op:maid,cid:Zed,id:Zed,role:items,count:0", 1000, false)
check("stranger is rejected", stranger.ok == false and stranger.reason == "owner" and kittenTasks() == tasksBefore and ownerTasks() == ownerBefore)

-- An unchanged refresh reuses the id. The ack still counts once if the first push was armed.
wipe()
local baseK = kittenTasks()
local baseO = ownerTasks()
check("add item stores", CCT.Maid.AddItem("Soap") == true)
check("duplicate item is refused", CCT.Maid.AddItem("Soap") == false)
check("add instruction stores", CCT.Maid.AddInstruction("fold the towels") == true)
check("summary names both", CCT.Maid.Summary() == "1 items, 1 instructions")
CCT.Net.Reset()
CCT.Maid.Reset()
CCT.Maid.Clock(1000)
CCT.Net.Clock(1000)
local queuedStatus, queuedId = CCT.Maid.Send(true)
check("combined list queues", queuedStatus == "queued" and queuedId ~= nil)
local depthAtSend = CCT.Net.Depth().reliable
check("immediate refresh is throttled", CCT.Maid.Tick() == "throttle" and CCT.Net.Depth().reliable == depthAtSend)
local firstMark = #sends
check("refresh pump finishes", pumpReliable())
local firstCmds = cmdsFrom(firstMark)
check("first push has an id", #firstCmds >= 1 and cmdId(firstCmds[1].message) == queuedId)
CCT.Maid.Clock(1060)
CCT.Net.Clock(1060)
local refreshStatus, refreshId = CCT.Maid.Tick()
check("sixty second refresh reuses the id", refreshStatus == "queued" and refreshId == queuedId)
local secondMark = #sends
pumpReliable()
local secondCmds = cmdsFrom(secondMark)
check("refresh wires keep the id", #secondCmds >= 1 and cmdId(secondCmds[1].message) == queuedId)
deliverCmds(firstCmds)
deliverCmds(secondCmds)
local ackCount = deliverAcks()
check(
    "refresh counts once",
    ackCount == 2 and kittenTasks() == baseK + 1 and ownerTasks() == baseO + 1,
    "acks=" .. tostring(ackCount) .. " kitten=" .. tostring(kittenTasks()) .. " base=" .. tostring(baseK) .. " owner=" .. tostring(ownerTasks()) .. " base=" .. tostring(baseO)
)
local shownList = shown()
check("kitten shows the folded towels", shownList and shownList.instructions[1] == "fold the towels" and shownList.items[1].name == "Soap")

-- One content change is one increment, including a split instruction and a long name.
wipe()
baseK = kittenTasks()
baseO = ownerTasks()
local ownerChar = CCT.Saved.EnsureChar("Nyx")
ownerChar.maid = {
    items = {
        { displayName = "Tea:Cup" },
        { displayName = string.rep("N", 400) },
    },
    instructions = {
        string.rep("%", 140),
        "fold towels",
    },
}
local richStatus, richId = CCT.Maid.Send(true)
local richDepth = CCT.Net.Depth().reliable
check("rich list queues", richStatus == "queued" and richDepth >= 6)
local richMark = #sends
pumpReliable()
local richCmds = cmdsFrom(richMark)
local textWires = {}
local itemWires = {}
local tooLong = false
local colonOk = false
local headerOk = true
for i = 1, #richCmds do
    local message = richCmds[i].message
    if #message > 255 then
        tooLong = true
    end
    if message:find("op:maidtext", 1, true) then
        textWires[#textWires + 1] = message
        local header = headerThroughText(message)
        if header == nil or header > 80 then
            headerOk = false
        end
    end
    if message:find("op:maiditem", 1, true) then
        itemWires[#itemWires + 1] = message
        if message:find("name:Tea%3ACup", 1, true) then
            colonOk = true
        end
    end
end
local percentWires = 0
for i = 1, #textWires do
    if textWires[i]:find("idx:1", 1, true) then
        percentWires = percentWires + 1
    end
end
check("wires stay inside 255", tooLong == false and #richCmds == richDepth)
check("colon in a name is escaped", colonOk == true)
check("percent instruction is two parts", percentWires == 2 and headerOk == true)
check("long item is one wire", #itemWires == 2)
local longWire = itemWires[1]
if itemWires[2] and #itemWires[2] > #itemWires[1] then
    longWire = itemWires[2]
end
check("long item wire is one part", longWire and #longWire <= 255 and longWire:find(string.rep("N", 400), 1, true) == nil)
deliverCmds(richCmds)
ackCount = deliverAcks()
check("rich change counts once", ackCount == 1 and kittenTasks() == baseK + 1 and ownerTasks() == baseO + 1 and cmdId(richCmds[1].message) == richId)
local richShown = shown()
local sawColon = false
local sawShortName = false
if richShown then
    for i = 1, #richShown.items do
        if richShown.items[i].name == "Tea:Cup" then
            sawColon = true
        end
        if richShown.items[i].name and #richShown.items[i].name < 400 and richShown.items[i].name:find("^N") then
            sawShortName = true
        end
    end
end
check("kitten decodes the colon and the short name", sawColon and sawShortName and richShown.instructions[2] == "fold towels" and #richShown.instructions[1] < 140)
CCT.Maid.Clock(1120)
CCT.Net.Clock(1120)
local sameStatus, sameId = CCT.Maid.Tick()
check("counted refresh keeps the id", sameStatus == "queued" and sameId == richId)
local sameMark = #sends
pumpReliable()
deliverCmds(cmdsFrom(sameMark))
deliverAcks()
check("counted refresh does not count again", kittenTasks() == baseK + 1 and ownerTasks() == baseO + 1)

-- Direct apply rules: same id, same body, and a real change.
wipe()
bind("Kitten")
baseK = kittenTasks()
local function feed(id, text)
    CCT.Maid.Accept({ op = "maid", id = id, cid = id, role = "items", count = "0" })
    CCT.Maid.Accept({ op = "maid", id = id, cid = id, role = "texts", count = "1" })
    return CCT.Maid.Accept({ op = "maidtext", id = id, cid = id, idx = "1", text = text })
end
feed("a", "fold")
check("first apply counts", kittenTasks() == baseK + 1)
feed("a", "fold")
check("same id does not count", kittenTasks() == baseK + 1)
feed("b", "fold")
check("same body does not count", kittenTasks() == baseK + 1)
feed("c", "sweep")
check("new body counts once", kittenTasks() == baseK + 2)

-- Incomplete pieces do not apply. The finishing piece counts once.
wipe()
bind("Kitten")
baseK = kittenTasks()
baseO = ownerTasks()
local beforeText = shown() and shown().instructions and shown().instructions[1] or nil
local function recv(text)
    CCT.Net.Receive("CatgirlTracker", text, "WHISPER", "Nyx")
end
recv("Cmd,op:maidtext,cid:600,id:600,idx:1,part:1/2,text:hel")
recv("Cmd,op:maid,cid:600,id:600,role:items,count:0")
recv("Cmd,op:maid,cid:600,id:600,role:texts,count:1")
check("half a text does not apply", kittenTasks() == baseK and ((shown() and shown().instructions and shown().instructions[1]) or nil) == beforeText)
recv("Cmd,op:maidtext,cid:600,id:600,idx:1,part:2/2,text:lo")
check("the second part applies once", kittenTasks() == baseK + 1 and shown().instructions[1] == "hello")
recv("Cmd,op:maid,cid:601,id:601,role:items,count:1")
recv("Cmd,op:maid,cid:601,id:601,role:texts,count:0")
check("missing item does not apply", kittenTasks() == baseK + 1)
recv("Cmd,op:maiditem,cid:601,id:601,idx:1,n:2,name:Bro%3Aom")
check("the item applies once", kittenTasks() == baseK + 2 and shown().items[1].name == "Bro:om" and shown().items[1].count == 2)
check("held fragments did not count the owner", ownerTasks() == baseO)

-- A disabled kitten acks ok:0 and neither side counts.
wipe()
baseK = kittenTasks()
baseO = ownerTasks()
CCT.Maid.AddInstruction("hidden task")
local hiddenMark = #sends
pumpReliable()
local hiddenCmds = cmdsFrom(hiddenMark)
CCT.Module.Set("MaidTasks", false)
deliverCmds(hiddenCmds)
local hiddenAckMark = #sends
pumpReliable()
local sawDeny = false
for i = hiddenAckMark + 1, #sends do
    local message = sends[i].message
    if type(message) == "string" and message:sub(1, 4) == "Ack," and message:find("ok:0", 1, true) and message:find("reason:disabled", 1, true) then
        sawDeny = true
        CCT.Net.Receive("CatgirlTracker", message, "WHISPER", "Kitten")
    end
end
bind("Nyx")
check("disabled ack does not count", sawDeny and kittenTasks() == baseK and ownerTasks() == baseO)
CCT.Module.Set("MaidTasks", true)

-- A count change is one content change.
wipe()
baseK = kittenTasks()
baseO = ownerTasks()
itemCount = 1
C_Item = {
    GetItemCount = function()
        return itemCount
    end,
}
CCT.Maid.AddItem("Soap")
CCT.Net.Reset()
CCT.Maid.Reset()
CCT.Maid.Clock(2000)
CCT.Net.Clock(2000)
CCT.Maid.Send(true)
local countMark = #sends
pumpReliable()
deliverCmds(cmdsFrom(countMark))
deliverAcks()
check("first count counts once", kittenTasks() == baseK + 1 and ownerTasks() == baseO + 1 and shown().items[1].count == 1)
itemCount = 4
CCT.Maid.Clock(2060)
CCT.Net.Clock(2060)
local countStatus = CCT.Maid.Tick()
local changedMark = #sends
pumpReliable()
local changedCmds = cmdsFrom(changedMark)
deliverCmds(changedCmds)
deliverAcks()
check("a new count counts once", countStatus == "queued" and cmdId(changedCmds[1].message) ~= nil and kittenTasks() == baseK + 2 and ownerTasks() == baseO + 2 and shown().items[1].count == 4)
C_Item = nil

-- Twenty items and twenty two-part instructions are 62 wires and they fit.
wipe()
ownerChar = CCT.Saved.EnsureChar("Nyx")
ownerChar.maid = { items = {}, instructions = {} }
for i = 1, 20 do
    ownerChar.maid.items[i] = { displayName = string.format("Item%02d", i) }
    ownerChar.maid.instructions[i] = string.rep("%", 139) .. string.char(64 + i)
end
local fullK = kittenTasks()
local fullO = ownerTasks()
local fullStatus = CCT.Maid.Send(true)
local fullDepth = CCT.Net.Depth().reliable
local fullMark = #sends
local fullPumped = pumpReliable()
local fullCmds = cmdsFrom(fullMark)
local fullFit = fullStatus == "queued" and fullDepth == 62 and fullPumped and #fullCmds == 62
for i = 1, #fullCmds do
    if #fullCmds[i].message > 255 then
        fullFit = false
    end
end
check("legal full list is 62 parts", fullFit, "status=" .. tostring(fullStatus) .. " depth=" .. tostring(fullDepth) .. " cmds=" .. tostring(#fullCmds))
check("undelivered full list does not count", kittenTasks() == fullK and ownerTasks() == fullO)

-- More than 72 parts is a local failure and is not retried.
wipe()
baseK = kittenTasks()
baseO = ownerTasks()
local sendsBefore = #sends
CCT.Maid.HookPlan(function()
    local fragments = {}
    for i = 1, 73 do
        fragments[i] = { kind = "maid", wires = { "Cmd,op:maid,cid:73,id:73,role:items,count:0" } }
    end
    return { fragments = fragments, parts = 73, fingerprint = "oversize", changed = true, id = "73" }
end)
local hugeStatus = CCT.Maid.Send(true)
local hugeFailure = CCT.Maid.Failure()
check("73 parts are toobig", hugeStatus == "toobig" and CCT.Net.Depth().reliable == 0 and #sends == sendsBefore)
check("toobig is a local ack", hugeFailure and hugeFailure.ok == "0" and hugeFailure.reason == "toobig")
CCT.Maid.Clock(1060)
local hugeAgain = CCT.Maid.Tick()
check("toobig is not retried", hugeAgain == "toobig" and CCT.Net.Depth().reliable == 0 and #sends == sendsBefore and kittenTasks() == baseK and ownerTasks() == baseO)
CCT.Maid.HookPlan(nil)

-- A set that fits the cap but not the free slots waits for the next tick.
wipe()
baseK = kittenTasks()
baseO = ownerTasks()
local snapQueued = CCT.Net.Whisper("Nyx", "state", { { "rev", "1" }, { "gag", "none" } })
local snapDepth = CCT.Net.Depth().snapshot
for i = 1, 71 do
    CCT.Net.Whisper("Kitten", "cmd", { { "op", "gag" }, { "cid", tostring(1000 + i) }, { "state", "huge" } })
end
local busyStatus = CCT.Maid.Send(true)
check("busy enqueues nothing", snapQueued == true and busyStatus == "busy" and CCT.Net.Depth().reliable == 71 and CCT.Net.Depth().snapshot == snapDepth)
check("busy does not count", kittenTasks() == baseK and ownerTasks() == baseO)
check("busy queue drains", pumpReliable() and CCT.Net.Depth().reliable == 0 and CCT.Net.Depth().snapshot == snapDepth)
local retryStatus = CCT.Maid.Send(true)
check("the next send queues", retryStatus == "queued" and CCT.Net.Depth().reliable == 2 and CCT.Net.Depth().snapshot == snapDepth)

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr8 self-check passed")
