-- PR 1 self-check. Run from the repo root:
--   lua tools/pr1_selfcheck.lua
-- Covers a nil player name, the public-note fallback, and a Forever surname.
-- and a speed value that errors if it is compared. The bad guard
-- `speed ~= nil and not issecretvalue(speed)` fails the source check:
-- outside the game client, `~= nil` does not raise, so the check reads
-- Move.lua and requires issecretvalue to be the next use of the raw return.

local stdout = print
local failures = 0

local function check(name, cond)
    if cond then
        stdout("ok  " .. name)
    else
        failures = failures + 1
        stdout("FAIL " .. name)
    end
end

local script = arg and arg[0] or "tools/pr1_selfcheck.lua"
local root = script:gsub("/?tools/pr1_selfcheck%.lua$", "")
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

UnitName = boom("UnitName")
UnitFullName = boom("UnitFullName")
UnitGUID = boom("UnitGUID")
GetGuildRosterInfo = boom("GetGuildRosterInfo")
GetNumGuildMembers = boom("GetNumGuildMembers")
GuildRoster = boom("GuildRoster")
C_GuildInfo = { GuildRoster = boom("C_GuildInfo.GuildRoster") }
SendChatMessage = boom("SendChatMessage")
C_ChatInfo = {
    SendChatMessage = boom("C_ChatInfo.SendChatMessage"),
    SendAddonMessage = boom("C_ChatInfo.SendAddonMessage"),
}
hooksecurefunc = boom("hooksecurefunc")
ChatFrame_AddMessageEventFilter = boom("ChatFrame_AddMessageEventFilter")
CreateFrame = nil
SlashCmdList = nil
issecretvalue = function()
    return false
end
CatgirlGuildDB = { leaked = true }
CatgirlTrackerDB = nil

local CCT = {}
local files = {
    "Core/Namespace.lua",
    "Core/Saved.lua",
    "Core/Debug.lua",
    "Core/Messages.lua",
    "Core/Player.lua",
    "Core/Roster.lua",
    "Core/Move.lua",
    "Kitten/State.lua",
}
for i = 1, #files do
    local path = addon .. "/" .. files[i]
    local chunk, err = loadfile(path)
    if chunk == nil then
        error(err)
    end
    chunk("CatgirlTracker_Forever", CCT)
end
check("file scope does not read the player or the roster", true)

check("prefix length", CCT.PREFIX == "CatgirlTracker" and #CCT.PREFIX == 14)
check("media path", CCT.MEDIA == "Interface\\AddOns\\CatgirlTracker_Forever\\")
check("version", CCT.VERSION == "2.0.0")

local toc = read(addon .. "/CatgirlTracker_Forever.toc")
check("interface 16001", toc:find("## Interface: 16001\n", 1, true) ~= nil)
check("no classic interface", toc:find("20505", 1, true) == nil and toc:find("120000", 1, true) == nil)
check("saved variable", toc:find("## SavedVariables: CatgirlTrackerDB\n", 1, true) ~= nil)
check("no per character saved vars", toc:find("SavedVariablesPerCharacter", 1, true) == nil)
local tocCompact = toc:gsub("%s+", " ")
check(
    "toc order",
    tocCompact:find("Core/Namespace.lua Core/Saved.lua Core/Debug.lua Core/Messages.lua Core/Player.lua Core/Roster.lua Core/Move.lua Core/Chat.lua Core/Net.lua Kitten/State.lua", 1, true) ~= nil
)

local forbidden = {
    "SendChatMessage",
    "SendAddonMessage",
    "hooksecurefunc",
    "ChatFrame_AddMessageEventFilter",
    "FindLastEvent",
    "UnitPosition",
}
for i = 1, #files do
    local text = read(addon .. "/" .. files[i])
    for j = 1, #forbidden do
        if text:find(forbidden[j], 1, true) then
            check("no " .. forbidden[j] .. " in " .. files[i], false)
        end
    end
end
check("addon lua has no chat hook", true)

local moveSrc = read(addon .. "/Core/Move.lua")
local function stripComments(src)
    src = src:gsub("%-%-%[%[.-%]%]", " ")
    src = src:gsub("%-%-[^\n]*", " ")
    return src
end
local moveCompact = stripComments(moveSrc):gsub("%s+", " ")
check("no speed nil guard", moveSrc:find("speed%s*~=%s*nil") == nil)
check("no moving nil guard", moveSrc:find("moving%s*~=%s*nil") == nil)
check("no speed or", moveSrc:find("speed%s+or%s+") == nil)
check("no moving or", moveSrc:find("moving%s+or%s+") == nil)
check(
    "speed secret check is first",
    moveCompact:find('local speed = GetUnitSpeed("player") if issecretvalue(speed) then', 1, true) ~= nil
)
check(
    "moving secret check is first",
    moveCompact:find("local moving = IsPlayerMoving() if issecretvalue(moving) then", 1, true) ~= nil
)

check("known module default", CCT.Module.Enabled("HeadPetTracker") == true)
check("map default off", CCT.Module.Enabled("KittenMapShow") == false)
check("layer invite absent", CCT.Module.Enabled("LayerInvite") == false)
check("db not created by a module read", CatgirlTrackerDB == nil)

local repaired = {
    settings = {
        masterName = "Nyx",
        modules = { LayerInvite = true, KittenMapShow = true },
    },
}
CCT.Saved.Repair(repaired)
check("master name kept", repaired.settings.masterName == "Nyx")
check("layer flag removed", repaired.settings.modules.LayerInvite == nil)
check("map flag kept", repaired.settings.modules.KittenMapShow == true)
check("missing module filled", repaired.settings.modules.HeadPetTracker == true)
check("flavor default", repaired.settings.flavorAnnouncements == true)
local emptied = { settings = { masterName = "" } }
CCT.Saved.Repair(emptied)
check("blank master is empty", emptied.settings.masterName == nil)
local hyphenMaster = { settings = { masterName = "Anna-Brightvale" }, chars = { ["Mina-Dawn"] = { marker = true } } }
CCT.Saved.Repair(hyphenMaster)
check("master hyphen is the full name", hyphenMaster.settings.masterName == "Anna Brightvale")
check("hyphen character key is the full name", hyphenMaster.chars["Mina-Dawn"] == nil and hyphenMaster.chars["Mina Dawn"].marker == true)

CatgirlTrackerDB = nil
CCT.Saved.OnEvent(nil, "ADDON_LOADED", "CatgirlTracker_Forever")
check("empty db", type(CatgirlTrackerDB) == "table" and type(CatgirlTrackerDB.chars) == "table")
check("classic db ignored", CatgirlGuildDB.leaked == true and CatgirlTrackerDB.leaked == nil)
check("debug default off", CCT.DebugEnabled() == false)
check("master default empty", CatgirlTrackerDB.settings.masterName == nil)

UnitFullName = function()
    return nil
end
UnitName = function()
    return nil
end
UnitGUID = function()
    return nil
end
check("nil name refresh", CCT.Player.Refresh() == false)
check("not ready", CCT.Player.ready == false and CCT.Player.short == nil)
check("nil name is not stored", next(CatgirlTrackerDB.chars) == nil)
check("setter no-ops before login", CCT.State.SetGag("huge") == false)
check("still no character row", next(CatgirlTrackerDB.chars) == nil)

local now = 1000
time = function()
    return now
end
GetTime = function()
    return now
end

local lines = {}
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    lines[#lines + 1] = table.concat(parts, " ")
end

local function printed(fragment)
    for i = 1, #lines do
        if lines[i]:find(fragment, 1, true) then
            return true
        end
    end
    return false
end

CCT.ModuleCommand("")
check("module list has headpet", printed("HeadPetTracker: on"))
check("module list has map off", printed("KittenMapShow: off"))
check("module list omits layer", not printed("LayerInvite"))
lines = {}
CCT.ModuleCommand("LayerInvite")
check("layer command refused", printed("Unknown module") and CatgirlTrackerDB.settings.modules.LayerInvite == nil)
CCT.ModuleCommand("KittenMapShow")
check("map toggles on", CCT.Module.Enabled("KittenMapShow") == true)
check("set refuses layer", CCT.Module.Set("LayerInvite", true) == false)

CCT.db.chars.Kitten = {
    state = {
        mittens = "squeking",
        skillProgress = 5,
        nap = { on = true },
        heat = 40,
        counters = { heatPeak = 0, seq = 1 },
        gag = "none",
        gagStage = 0,
    },
    life = { denied = 3, orgasms = { 10 } },
    nya = { enabled = false },
}
UnitFullName = function()
    return "Kitten"
end
UnitGUID = function()
    return "Player-1-ABC"
end
check("login refresh", CCT.Player.Refresh() == true)
check("short name", CCT.Player.short == "Kitten")
check("no realm", CCT.Player.realm == nil and CCT.Player.name == "Kitten")
check("guid stored whole", CCT.Player.guid == "Player-1-ABC")
local state = CCT.State.Get()
check("typo mittens read once", state.mittens == "squeaking")
check("session progress dropped", state.skillProgress == nil and state.nap == nil)
check("heat peak raised from heat", state.counters.heatPeak == 40)
check("lifetime deny kept", CCT.db.chars.Kitten.life.denied == 3)
check("last unix on a partial row stays unset", state.lastUnixUpdate == nil)
check("clock stamp is not persisted yet", state.minuteStamp == nil)

state.nap = { on = true }
local revAfterRepair = state.rev
CCT.State.Bind("Kitten")
check("rebind keeps this session", state.nap ~= nil and state.rev == revAfterRepair)
CCT.State.OnEvent(nil, "PLAYER_LOGOUT")
check("logout drops the session", state.nap == nil and state.rev == revAfterRepair)

local heard = 0
local heardCounter = nil
CCT.State.Listen(function()
    heard = heard + 1
end)
CCT.State.ListenCounter(function(name)
    heardCounter = name
end)
local rev = state.rev
check("set gag", CCT.State.SetGag("huge") == true)
check("rev bumped", state.rev == rev + 1 and state.gag == "huge" and state.gagStage == 0)
check("updated at", state.updatedAt == 1000)
check("listener", heard == 1 and heardCounter == nil)
check("same gag is not a mutation", CCT.State.SetGag("huge") == true and state.rev == rev + 1)
check("inflatable stage", CCT.State.SetGag("inflatable", 3) == true and state.gagStage == 3)
check("squeking write is squeaking", CCT.State.SetMittens("squeking") == true and state.mittens == "squeaking")
check("belt mode while off", CCT.State.SetBeltMode("deny") == false and state.beltMode == "allow")
check("belt on", CCT.State.SetBelt(true) == true)
check("deny mode", CCT.State.SetBeltMode("deny") == true and state.beltMode == "deny")
check("belt off forces allow", CCT.State.SetBelt(false) == true and state.belt == false and state.beltMode == "allow")
check("dildo apply", CCT.State.ApplyToy("dildo") == true and state.toys.dildo.applied == true)
check("second butplug clears the first", CCT.State.ApplyToy("inflatable_butplug") == true and CCT.State.ApplyToy("small_butplug") == true)
check("butplug exclusion", state.toys.inflatable_butplug.applied == false and state.toys.small_butplug.applied == true)
CCT.State.SetBelt(true)
check("belt blocks apply", CCT.State.ApplyToy("dildo") == false)
check("belt blocks remove", CCT.State.RemoveToy("dildo") == false and state.toys.dildo.applied == true)
check("bra blocks nipple toy", CCT.State.SetBra(true) == true and CCT.State.ApplyToy("vibes_nipples") == false)
check("vibe on applied dildo", CCT.State.SetToyVibe("dildo", 4) == true and state.toys.dildo.vibe == 4)
check("plug has no vibe", CCT.State.SetToyVibe("small_butplug", 2) == false)
now = 2500
check("lock", CCT.State.SetLock("gag", 2) == true)
check("lock stamp", state.locks.gag.unlockAt == 2620 and state.locks.gag.minutes == 2)
check("expire gag", CCT.State.ExpireLock("gag") == true and state.locks.gag == nil and state.gag == "none")
check("heat peak", CCT.State.SetHeat(80.6) == true and state.heat == 80.6 and state.counters.heatPeak == 81)
check("counter listener", heardCounter == "heatPeak")
local peakRev = state.rev
check("clock does not bump rev", CCT.State.TouchClock(2500) == true and state.lastUnixUpdate == 2500 and state.rev == peakRev)
check("pets clamp", CCT.State.AddCounter("pets", 99999) == true and state.counters.pets == 9999)
check("unknown counter", CCT.State.AddCounter("trail", 1) == false)
check("pos rounded", CCT.State.SetPos({ mapID = 12, x = 0.123456, y = 0.5, instanceID = 4, t = 9 }) == true)
check("pos fields", state.pos.x == 0.1235 and state.pos.y == 0.5 and state.pos.mapID == 12 and state.pos.t == 9)
check("leash keeps the surname", CCT.State.SetLeash(true, "Nyx-Silvermoon") == true and state.leashOwner == "Nyx Silvermoon")
check("same leash name", CCT.SameName(state.leashOwner, "nyx silvermoon") == true and CCT.SameName("Nyx", state.leashOwner) == false)
check("message format", CCT.Msg("HEELS_PROGRESS", "Kit", "maid", 2):find('level "2"', 1, true) ~= nil)
check("missing message", CCT.Msg("NO_SUCH") == "NO_SUCH")

UnitFullName = function()
    return nil
end
UnitName = function()
    return nil
end
check("later nil keeps the name", CCT.Player.Refresh() == false and CCT.Player.short == "Kitten" and CCT.Player.ready == true)

local rosterCalls = 0
C_GuildInfo = {
    GuildRoster = function()
        rosterCalls = rosterCalls + 1
    end,
}
GuildRoster = boom("GuildRoster")
IsInGuild = function()
    return true
end
local roster = {
    { "KittenA", "rank", 0, 1, "Mage", "Elwynn", "hello", "owner=Alice", true },
    { "KittenB", "rank", 0, 1, "Mage", "Elwynn", "owner=alice", "", false },
    { "Nyx", "rank", 0, 1, "Mage", "Elwynn", "", "", nil },
    { "Kitten", "rank", 0, 1, "Mage", "Elwynn", "owner=Nyx", "", true },
}
GetNumGuildMembers = function()
    return #roster
end
GetGuildRosterInfo = function(index)
    local row = roster[index]
    return row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9]
end

CCT.Player.short = "Alice"
CCT.Player.ready = true
lines = {}
CCT.SetDebug(true)
now = 10
CCT.Roster.Rebuild()
local assigned = CCT.Roster.GetAssignedKitten()
check("first roster index wins", assigned ~= nil and assigned.short == "KittenA" and assigned.index == 1)
check("collision named", printed("Assigned kitten collision") and printed("KittenB"))
local collisionLines = 0
for i = 1, #lines do
    if lines[i]:find("Assigned kitten collision", 1, true) then
        collisionLines = collisionLines + 1
    end
end
CCT.Roster.Rebuild()
local afterSecond = 0
for i = 1, #lines do
    if lines[i]:find("Assigned kitten collision", 1, true) then
        afterSecond = afterSecond + 1
    end
end
check("collision rate limit", collisionLines == 1 and afterSecond == 1)
now = 20
CCT.Roster.Rebuild()
check("rate limit later prints the suppressed count", printed("(+1 similar)"))

check("owner keeps both names", CCT.Roster.OwnerFromNotes("ignored", "owner=Alice Brightvale") == "Alice Brightvale")
check("owner hyphen is the surname", CCT.Roster.OwnerFromNotes("", "owner=Alice-Brightvale") == "Alice Brightvale")
check("space and hyphen are one owner", CCT.SameName("Alice Brightvale", "Alice-Brightvale") == true)
check("first name is not the full name", CCT.SameName("Alice", "Alice Brightvale") == false)
check("public note fallback", CCT.Roster.OwnerFromNotes("owner=Alice", "") == "Alice")
check("blank officer does not hide public", CCT.Roster.OwnerFromNotes("owner=Cara", "   ") == "Cara")
check("comma ends the token", CCT.Roster.OwnerFromNotes("owner=Bob, owner=Cara", "") == "Bob")
check("comma ends a two part name", CCT.Roster.OwnerFromNotes("owner=Bob Vale, owner=Cara", "") == "Bob Vale")
check("words after the name are left out", CCT.Roster.OwnerFromNotes("owner=Bob Vale please", "") == "Bob Vale")
check("officer text without owner hides public", CCT.Roster.OwnerFromNotes("owner=Alice", "rank only") == nil)
check("online boolean is not a note", CCT.Roster.OwnerFromNotes("owner=Alice", true) == "Alice")
check("link form", CCT.LinkName("Alice Brightvale") == "Alice-Brightvale" and CCT.LinkName("Alice-Brightvale") == "Alice-Brightvale" and CCT.LinkName("Nyx") == "Nyx")

local selfRow = nil
CCT.Player.short = "Kitten"
CCT.Roster.Rebuild()
selfRow = CCT.Roster.GetSelf()
check("self row", selfRow ~= nil and selfRow.short == "Kitten" and selfRow.online == true)
check("kitten owner is short", CCT.Roster.GetOwnerShort() == "Nyx")
check("member case", CCT.Roster.GetMember("kittenA") ~= nil and CCT.Roster.GetMember("kittenA").ownerShort == "Alice")
CatgirlTrackerDB.settings.masterName = "nyx"
check("master online nil is not online", CCT.Roster.IsMasterOnline() == false)
roster[3][9] = true
CCT.Roster.Rebuild()
check("master online", CCT.Roster.IsMasterOnline() == true)
roster[3][9] = false
CCT.Roster.Rebuild()
check("master offline", CCT.Roster.IsMasterOnline() == false)
check("typed master keeps both names", CCT.ShortName("Anna-Brightvale") == "Anna Brightvale" and CCT.ShortName("anna brightvale") == "anna brightvale")
local callsBeforeRead = rosterCalls
CCT.Roster.GetOwnerShort()
CCT.Roster.GetMember("Nyx")
CCT.Roster.IsMasterOnline()
check("readers do not request", rosterCalls == callsBeforeRead)

now = 1000
check("request", CCT.Roster.Request() == true and rosterCalls == callsBeforeRead + 1)
check("cooldown", CCT.Roster.Request() == false and rosterCalls == callsBeforeRead + 1)
now = 1011
check("cooldown elapsed", CCT.Roster.Request() == true and rosterCalls == callsBeforeRead + 2)

IsInGuild = function()
    return false
end
check("leave guild clears", CCT.Roster.Request() == false and CCT.Roster.GetMember("Nyx") == nil)

C_GuildInfo = nil
IsInGuild = function()
    return true
end
local fallbackCalls = 0
GuildRoster = function()
    fallbackCalls = fallbackCalls + 1
end
now = 2000
check("guildroster fallback", CCT.Roster.Request() == true and fallbackCalls == 1)

local secret = setmetatable({}, {
    __lt = function()
        error("secret compared")
    end,
    __le = function()
        error("secret compared")
    end,
})
local secretCalls = 0
local movingCalls = 0
issecretvalue = function(value)
    secretCalls = secretCalls + 1
    return rawequal(value, secret)
end
GetUnitSpeed = function()
    return secret
end
IsPlayerMoving = function()
    movingCalls = movingCalls + 1
    return true
end
local sampleOk, sample = pcall(CCT.Move.Sample)
check("secret speed does not error", sampleOk and type(sample) == "table" and sample.kind == "hidden")
check("secret check ran", secretCalls == 1)
check("secret speed skips the bool api", movingCalls == 0)
local comparedOk = pcall(function()
    return secret > 0
end)
check("bare compare of that value errors", comparedOk == false)

GetUnitSpeed = function()
    return 0
end
sample = CCT.Move.Sample()
check("standing speed", sample.kind == "speed" and sample.yards == 0 and sample.moving == false)
GetUnitSpeed = function()
    return 2.5
end
sample = CCT.Move.Sample()
check("walking speed", sample.kind == "speed" and sample.moving == true and sample.yards == 2.5)

GetUnitSpeed = nil
IsPlayerMoving = function()
    return secret
end
secretCalls = 0
sampleOk, sample = pcall(CCT.Move.Sample)
check("secret moving flag", sampleOk and sample.kind == "hidden" and secretCalls == 1)

IsPlayerMoving = function()
    return true
end
sample = CCT.Move.Sample()
check("bool sample", sample.kind == "bool" and sample.moving == true)
IsPlayerMoving = nil
sample = CCT.Move.Sample()
check("no probe is hidden", sample.kind == "hidden")

local printCalled = false
print = function()
    printCalled = true
end
GetUnitSpeed = function()
    return 3
end
CCT.Move.Sample()
check("sample does not print", printCalled == false)

CCT.db.chars.Clutch = { nya = { enabled = false, chance = 12 } }
UnitName = function()
    return "Clutch", "Bloodfury"
end
UnitFullName = nil
GetUnitName = nil
check("unit surname is not a realm", CCT.Player.Refresh() == true and CCT.Player.short == "Clutch Bloodfury" and CCT.Player.name == "Clutch Bloodfury" and CCT.Player.realm == nil)
check("old first name row follows the surname", CCT.db.chars.Clutch == nil and CCT.db.chars["Clutch Bloodfury"].nya.chance == 12)
UnitName = function()
    return "Lira"
end
GetUnitName = function(_, full)
    if full then
        return "Lira-Stone"
    end
    return "Lira"
end
check("linked unit name keeps the surname", CCT.Player.Refresh() == true and CCT.Player.short == "Lira Stone" and CCT.Player.realm == nil)
check("new character has a clock stamp", CCT.db.chars["Lira Stone"].state.lastUnixUpdate == 0)
UnitName = function()
    return "Asha"
end
UnitFullName = function()
    return "Asha", "Brightvale"
end
GetUnitName = nil
check("full name second return is the surname", CCT.Player.Refresh() == true and CCT.Player.short == "Asha Brightvale" and CCT.Player.realm == nil)
check("given name does not match that character", CCT.SameName("Asha", CCT.Player.short) == false)

local bell = io.open(addon .. "/Sounds/Bell.ogg", "rb")
local icon = io.open(addon .. "/Textures/catgirltga.tga", "rb")
check("bell copied", bell ~= nil)
check("icon copied", icon ~= nil)
if bell then bell:close() end
if icon then icon:close() end

local function countFiles(path)
    local handle = io.popen("find '" .. path .. "' -type f | wc -l")
    local text = handle:read("*a")
    handle:close()
    return tonumber(text)
end
local classicSounds = root .. "/CatgirlTracker/sounds"
local classicProbe = io.open(classicSounds .. "/Bell.ogg", "rb")
if classicProbe then
    classicProbe:close()
    check("sound count", countFiles(classicSounds) == countFiles(addon .. "/Sounds"))
    check("texture count", countFiles(root .. "/CatgirlTracker/Textures") == countFiles(addon .. "/Textures"))
end

if failures > 0 then
    stdout(failures .. " failed")
    os.exit(1)
end
stdout("pr1 self-check passed")
