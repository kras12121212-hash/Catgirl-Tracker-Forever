-- Cmd intake. A command applies only when the sender is the owner.
-- An empty roster cache holds the command for 10 seconds, then drops it.
-- /cctcmd is deleted. Slash() remains a local bypass for tests.
-- This file does not send addon messages. It does not move feature state.
-- Maid handlers are replaced by Kitten/Maid.lua. A fragment with no update id stays later.

local ADDON_NAME, CCT = ...

CCT.Commands = {}

local HOLD_SECONDS = 10

CCT.Commands.HOLD_SECONDS = HOLD_SECONDS
CCT.Commands.Handlers = {}

local held = {}

local function Trim(text)
    return (text:match("^%s*(.-)%s*$"))
end

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

local function Say(text)
    if print and text then
        print(text)
    end
end

local function Announce(sender, key, localText, raidText)
    if key then
        Whisper(sender, CCT.Msg(key))
    end
    Say(localText)
    Raid(raidText)
end

local function Result(ok, reason, fields, isHeld)
    local op = nil
    local cid = nil
    if type(fields) == "table" then
        op = fields.op
        cid = fields.cid
    end
    return {
        ok = ok and true or false,
        reason = ok and nil or reason,
        op = op,
        cid = cid,
        held = isHeld and true or nil,
    }
end

local function Rev()
    local state = CCT.State and CCT.State.Get and CCT.State.Get()
    if type(state) ~= "table" then
        return 0
    end
    return tonumber(state.rev) or 0
end

local function Changed(before)
    return Rev() ~= before
end

local function State()
    if CCT.State and CCT.State.Get then
        return CCT.State.Get()
    end
    return nil
end

local function Flag(value)
    if value == "1" then
        return true
    end
    if value == "0" then
        return false
    end
    return nil
end

local function OwnerShort()
    if CCT.Roster and CCT.Roster.GetOwnerShort then
        return CCT.Roster.GetOwnerShort()
    end
    return nil
end

local function CacheReady()
    return CCT.Roster ~= nil and CCT.Roster.GetSelf ~= nil and CCT.Roster.GetSelf() ~= nil
end

function CCT.Commands.Parse(text)
    if type(text) ~= "string" or text:find("[\r\n%z]") then
        return nil
    end
    local body = Trim(text)
    if body == "" then
        return nil
    end
    local tokens = {}
    for token in body:gmatch("[^,]+") do
        local piece = Trim(token)
        if piece ~= "" then
            tokens[#tokens + 1] = piece
        end
    end
    if #tokens == 0 then
        return nil
    end
    local startAt = 1
    if not tokens[1]:find(":", 1, true) then
        if tokens[1]:lower() ~= "cmd" then
            return nil
        end
        startAt = 2
    end
    local fields = {}
    for i = startAt, #tokens do
        local key, value = tokens[i]:match("^([^:]+):(.*)$")
        if key == nil then
            return nil
        end
        key = Trim(key):lower()
        if key == "" then
            return nil
        end
        fields[key] = value
    end
    if type(fields.op) ~= "string" or fields.op == "" then
        return nil
    end
    fields.op = fields.op:lower()
    return fields
end

local function FromModule(fields, ok, reason, quiet)
    if ok and quiet then
        return Result(true, nil, fields)
    end
    if ok then
        return Result(true, nil, fields)
    end
    return Result(false, reason or "state", fields)
end

local GAG = {
    huge = {
        key = "GAG_HEAVY",
        say = "|cffff66ccCatgirlTracker:|r You've been heavily gagged nya~",
        raid = "Gag applied: heavy gag.",
    },
    small = {
        key = "GAG_SMALL",
        say = "|cffcc88ffCatgirlTracker:|r A small gag muffles your words...",
        raid = "Gag applied: small gag.",
    },
    full = {
        key = "GAG_FULLBLOCK",
        say = "|cffff0000CatgirlTracker:|r You've been fully muzzled. No words can escape now!",
        raid = "Gag applied: full mask gag.",
    },
    nyamask = {
        key = "GAG_NYAMASK",
        say = "|cffff88eeCatgirlTracker:|r You're overcome with the urge to add ~Nya~ to everything!",
        raid = "Gag applied: cute mask.",
    },
    none = {
        key = "GAG_REMOVE",
        say = "|cffaaffaaCatgirlTracker:|r You've been ungagged nya~",
        raid = "Gag removed.",
    },
}

local function ApplyGag(sender, fields)
    local value = type(fields.state) == "string" and fields.state:lower() or ""
    local stage = tonumber(fields.stage)
    if value == "inflatable" and stage == nil then
        stage = 1
    end
    local before = Rev()
    if not CCT.State.SetGag(value, stage) then
        return Result(false, "state", fields)
    end
    if not Changed(before) then
        return Result(true, nil, fields)
    end
    if value == "inflatable" then
        local worn = State()
        local nowStage = worn and worn.gagStage or stage or 1
        Announce(
            sender,
            "GAG_INFLATABLE",
            "|cffcc88ffCatgirlTracker:|r An inflatable gag fills your mouth... it's only a little swollen.",
            string.format("Gag applied: inflatable (stage %d).", nowStage)
        )
        return Result(true, nil, fields)
    end
    local line = GAG[value]
    if line then
        Announce(sender, line.key, line.say, line.raid)
    end
    return Result(true, nil, fields)
end

local function ApplyGagStep(sender, fields)
    local dir = type(fields.dir) == "string" and fields.dir:lower() or ""
    local state = State()
    if type(state) ~= "table" then
        return Result(false, "state", fields)
    end
    local before = Rev()
    if dir == "up" then
        local stage = 1
        if state.gag == "inflatable" then
            stage = math.min(5, (tonumber(state.gagStage) or 1) + 1)
        end
        if not CCT.State.SetGag("inflatable", stage) then
            return Result(false, "state", fields)
        end
        if Changed(before) then
            local worn = State()
            local nowStage = worn and worn.gagStage or stage
            Announce(
                sender,
                "GAG_INFLATE",
                "|cffff99ffCatgirlTracker:|r The inflatable gag swells tighter in your mouth...",
                string.format("Gag inflated to stage %d.", nowStage)
            )
        end
        return Result(true, nil, fields)
    end
    if dir == "down" then
        if state.gag ~= "inflatable" then
            return Result(false, "gag", fields)
        end
        local stage = math.max(1, (tonumber(state.gagStage) or 1) - 1)
        if not CCT.State.SetGag("inflatable", stage) then
            return Result(false, "state", fields)
        end
        if Changed(before) then
            local worn = State()
            local nowStage = worn and worn.gagStage or stage
            Announce(
                sender,
                "GAG_DEFLATE",
                "|cff88ffccCatgirlTracker:|r The inflatable gag softens and loosens a bit...",
                string.format("Gag deflated to stage %d.", nowStage)
            )
        end
        return Result(true, nil, fields)
    end
    return Result(false, "dir", fields)
end

local BLIND = {
    light = { key = "BLINDFOLD_LIGHT", raid = "Blindfold applied: light." },
    mask = { key = "BLINDFOLD_KITTY", raid = "Blindfold applied: kitty mask." },
    full = { key = "BLINDFOLD_FULL", raid = "Blindfold applied: full." },
    none = { key = "BLINDFOLD_REMOVE", raid = "Blindfold removed." },
}

local function ApplyBlind(sender, fields)
    local value = type(fields.state) == "string" and fields.state:lower() or ""
    local before = Rev()
    if not CCT.State.SetBlind(value) then
        return Result(false, "state", fields)
    end
    if Changed(before) then
        local line = BLIND[value]
        if line then
            Announce(sender, line.key, nil, line.raid)
        end
    end
    return Result(true, nil, fields)
end

local function ApplyEars(sender, fields)
    local value = type(fields.state) == "string" and fields.state:lower() or ""
    local before = Rev()
    if not CCT.State.SetEars(value) then
        return Result(false, "state", fields)
    end
    if not Changed(before) then
        return Result(true, nil, fields)
    end
    if value == "kitten" then
        Say("Kitten earmuffs applied. Words sound cuter now nya~")
        Raid("Earmuffs applied: kitten.")
    elseif value == "heavy" then
        Say("Heavy earmuffs secured. Everything sounds like muffled nonsense.")
        Raid("Earmuffs applied: heavy.")
    elseif value == "none" then
        Say("Your earmuffs have been removed.")
        Raid("Earmuffs removed.")
    end
    return Result(true, nil, fields)
end

local function ApplyMittens(sender, fields)
    local value = type(fields.state) == "string" and fields.state:lower() or ""
    local before = Rev()
    if not CCT.State.SetMittens(value) then
        return Result(false, "state", fields)
    end
    if not Changed(before) then
        return Result(true, nil, fields)
    end
    if value == "squeaking" then
        Announce(sender, "PAW_MITTENS_RESPONSE_SQUEAKING", nil, "Squeaking paw mittens locked.")
    elseif value == "none" then
        Announce(sender, "PAW_MITTENS_REMOVE", nil, "Paw mittens removed.")
    elseif value == "locked" or value == "heavy" then
        Announce(sender, "PAW_MITTENS_RESPONSE_LOCKED", nil, "Paw mittens locked: paws restricted.")
    end
    return Result(true, nil, fields)
end

local HEELS = {
    maid = { key = "HEELS_RESPONSE_MAID", raid = "Maid heels locked (3 cm)." },
    high = { key = "HEELS_RESPONSE_HIGH", raid = "High heels locked (8 cm)." },
    ballet = { key = "HEELS_RESPONSE_BALLET", raid = "Ballet boots locked (12 cm)." },
    none = { key = "HEELS_REMOVE", raid = "Heels removed." },
}

local function ApplyHeels(sender, fields)
    local value = type(fields.state) == "string" and fields.state:lower() or ""
    local before = Rev()
    if not CCT.State.SetHeels(value) then
        return Result(false, "state", fields)
    end
    if Changed(before) then
        local line = HEELS[value]
        if line then
            Announce(sender, line.key, nil, line.raid)
        end
    end
    return Result(true, nil, fields)
end

local function ApplyBell(sender, fields)
    local which = type(fields.which) == "string" and fields.which:lower() or ""
    local on = Flag(fields.on)
    if on == nil then
        return Result(false, "on", fields)
    end
    local before = Rev()
    local ok = false
    if which == "collar" then
        ok = CCT.State.SetBell(on) == true
    elseif which == "tail" then
        ok = CCT.State.SetTail(on) == true
    else
        return Result(false, "which", fields)
    end
    if not ok then
        return Result(false, "state", fields)
    end
    if not Changed(before) then
        return Result(true, nil, fields)
    end
    if which == "collar" and on then
        Say("|cffffff00CatgirlTracker:|r You now wear a jingling bell on your collar nya...")
        Raid("Bell attached.")
    elseif which == "collar" then
        Say("|cffffff00CatgirlTracker:|r The bell has been removed... you're safe for now nya.")
        Raid("Bell removed.")
    elseif on then
        Say("|cffffff00CatgirlTracker:|r You now wear a jingling tail bell nya...")
        Raid("Tail bell attached.")
    else
        Say("|cffffff00CatgirlTracker:|r The tail bell has been removed... you're safe for now nya.")
        Raid("Tail bell removed.")
    end
    return Result(true, nil, fields)
end

local function ApplyJewel(sender, fields)
    local on = Flag(fields.on)
    if on == nil then
        return Result(false, "on", fields)
    end
    local before = Rev()
    if not CCT.State.SetJewel(on) then
        return Result(false, "state", fields)
    end
    if Changed(before) then
        if on then
            Say("|cffffff00CatgirlTracker:|r Your tracking jewel glows. Location tracking enabled.")
            Raid("Tracking jewel attached.")
        else
            Say("|cffffff00CatgirlTracker:|r The tracking jewel has been removed. Location tracking disabled.")
            Raid("Tracking jewel removed.")
        end
    end
    return Result(true, nil, fields)
end

local function ApplyLeash(sender, fields)
    if not CCT.Leash or not CCT.Leash.Apply then
        return Result(false, "state", fields)
    end
    local on = Flag(fields.on)
    if on == nil then
        return Result(false, "on", fields)
    end
    return FromModule(fields, CCT.Leash.Apply(on, sender))
end

local function ApplyBelt(sender, fields)
    if not CCT.Chastity or not CCT.Chastity.SetBelt then
        return Result(false, "state", fields)
    end
    local on = Flag(fields.on)
    if on == nil then
        return Result(false, "on", fields)
    end
    return FromModule(fields, CCT.Chastity.SetBelt(on, sender))
end

local function ApplyBra(sender, fields)
    if not CCT.Chastity or not CCT.Chastity.SetBra then
        return Result(false, "state", fields)
    end
    local on = Flag(fields.on)
    if on == nil then
        return Result(false, "on", fields)
    end
    return FromModule(fields, CCT.Chastity.SetBra(on, sender))
end

local function ApplyBeltMode(sender, fields)
    if not CCT.Chastity or not CCT.Chastity.SetMode then
        return Result(false, "state", fields)
    end
    local mode = type(fields.mode) == "string" and fields.mode:lower() or ""
    return FromModule(fields, CCT.Chastity.SetMode(mode, sender))
end

local function ApplyToy(sender, fields)
    if not CCT.Toys or not CCT.Toys.Handle then
        return Result(false, "state", fields)
    end
    local id = type(fields.id) == "string" and fields.id:lower() or ""
    local action = type(fields.action) == "string" and fields.action:lower() or ""
    return FromModule(fields, CCT.Toys.Handle(id, action, fields.level, sender))
end

local function ApplyLock(sender, fields)
    if not CCT.Locks or not CCT.Locks.Set then
        return Result(false, "state", fields)
    end
    local bind = type(fields.bind) == "string" and fields.bind:lower() or ""
    local minutes = tonumber(fields.minutes)
    if minutes == nil then
        return Result(false, "minutes", fields)
    end
    return FromModule(fields, CCT.Locks.Set(bind, minutes))
end

local function Later(fields)
    return Result(false, "later", fields)
end

CCT.Commands.Handlers.gag = ApplyGag
CCT.Commands.Handlers.gagstep = ApplyGagStep
CCT.Commands.Handlers.blind = ApplyBlind
CCT.Commands.Handlers.ears = ApplyEars
CCT.Commands.Handlers.mittens = ApplyMittens
CCT.Commands.Handlers.heels = ApplyHeels
CCT.Commands.Handlers.bell = ApplyBell
CCT.Commands.Handlers.jewel = ApplyJewel
CCT.Commands.Handlers.leash = ApplyLeash
CCT.Commands.Handlers.belt = ApplyBelt
CCT.Commands.Handlers.bra = ApplyBra
CCT.Commands.Handlers.beltmode = ApplyBeltMode
CCT.Commands.Handlers.toy = ApplyToy
CCT.Commands.Handlers.lock = ApplyLock
CCT.Commands.Handlers.disc = function(_, fields)
    return Later(fields)
end
CCT.Commands.Handlers.group = function(_, fields)
    return Later(fields)
end
CCT.Commands.Handlers.maid = function(_, fields)
    return Later(fields)
end
CCT.Commands.Handlers.maiditem = function(_, fields)
    return Later(fields)
end
CCT.Commands.Handlers.maidtext = function(_, fields)
    return Later(fields)
end

function CCT.Commands.Register(op, fn)
    if type(op) ~= "string" or type(fn) ~= "function" then
        return false
    end
    CCT.Commands.Handlers[op:lower()] = fn
    return true
end

function CCT.Commands.Pending()
    return #held
end

local function Deliver(sender, result)
    if type(result) == "table" and not result.held and CCT.Report and type(CCT.Report.OnCommand) == "function" then
        CCT.Report.OnCommand(sender, result)
    end
    return result
end

function CCT.Commands.Apply(sender, fields)
    if type(fields) ~= "table" or type(fields.op) ~= "string" then
        return Result(false, "parse", fields)
    end
    if type(State()) ~= "table" then
        return Result(false, "state", fields)
    end
    local handler = CCT.Commands.Handlers[fields.op]
    if handler == nil then
        return Result(false, "op", fields)
    end
    return handler(sender, fields)
end

local function AcceptSender(sender)
    local owner = OwnerShort()
    if owner == nil or not CCT.SameName(sender, owner) then
        return false
    end
    return true
end

function CCT.Commands.Flush(now)
    local stamp = tonumber(now) or CCT.UnixNow()
    local index = 1
    while index <= #held do
        local item = held[index]
        local ready = CacheReady()
        local expired = (stamp - item.at) >= HOLD_SECONDS
        if not ready and not expired then
            index = index + 1
        else
            table.remove(held, index)
            if ready and AcceptSender(item.sender) then
                local fields = CCT.Commands.Parse(item.text)
                if fields then
                    Deliver(item.sender, CCT.Commands.Apply(item.sender, fields))
                end
            end
        end
    end
end

function CCT.Commands.Receive(sender, text, now, localBypass)
    local stamp = tonumber(now) or CCT.UnixNow()
    local fields = CCT.Commands.Parse(text)
    if fields == nil then
        return Result(false, "parse", nil)
    end
    if not localBypass then
        if not CacheReady() then
            held[#held + 1] = { sender = sender, text = text, at = stamp }
            return Result(false, "hold", fields, true)
        end
        if not AcceptSender(sender) then
            return Result(false, "owner", fields)
        end
    end
    return Deliver(sender, CCT.Commands.Apply(sender, fields))
end

function CCT.Commands.Slash(text)
    local owner = OwnerShort()
    local sender = owner
    local bypass = false
    if sender == nil then
        if CCT.Player and type(CCT.Player.short) == "string" and CCT.Player.short ~= "" then
            sender = CCT.Player.short
        else
            sender = "local"
        end
        bypass = true
    end
    local result = CCT.Commands.Receive(sender, text, CCT.UnixNow(), bypass)
    if result.ok then
        Say("CatgirlTracker: applied " .. tostring(result.op))
    elseif result.held then
        Say("CatgirlTracker: command held until the owner note is known.")
    else
        Say("CatgirlTracker: command not applied (" .. tostring(result.reason) .. ").")
    end
    return result
end

function CCT.Commands.OnEvent(_, event)
    if event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CCT.Commands.Flush(CCT.UnixNow())
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:SetScript("OnEvent", CCT.Commands.OnEvent)
end
