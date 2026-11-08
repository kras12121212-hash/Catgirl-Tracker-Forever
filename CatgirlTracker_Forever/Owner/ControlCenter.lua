-- Owner control center. /cgcc reads the snapshot and enqueues Cmd.
-- Buttons do not call SendAddonMessage. Counting waits for Success and Ack ok:1.
-- The maid editor is an empty shell. Nothing in that shell is sent.
-- Force group is Cmd op group. KittyLayerGroup.lua layer list, linv, and the NWB read do not ship. The classic leave-first frame does not ship either.

local ADDON_NAME, CCT = ...

CCT.Control = {}

local DISC_RANGE = 0.02
local window = nil
local ready = nil
local nextCid = 1

local function Icon(fileName)
    if type(fileName) ~= "string" or fileName == "" then
        return nil
    end
    if fileName:find("[/\\]") then
        return (CCT.MEDIA or "") .. fileName:gsub("/", "\\")
    end
    return (CCT.MEDIA or "") .. "Textures\\cgcc\\" .. fileName
end

local function Button(id, label, icon, sentence, fields, extra)
    local row = {
        id = id,
        label = label,
        icon = Icon(icon),
        sentence = sentence,
        fields = fields,
    }
    if type(extra) == "table" then
        for key, value in pairs(extra) do
            row[key] = value
        end
    end
    return row
end

local BUTTONS = {
    Button("leash", "Leash", "leash-232-with-gb_ergebnis.tga", nil, { op = "leash", on = "1" }),
    Button("unleash", "Unleash", nil, nil, { op = "leash", on = "0" }),
    Button("nya-mask", "Cute Kitten Mask", "cute-kitty-mask-232-with-bg_ergebnis.tga", "Your owner gave you a cute~ Kitten Mask ~UwU~ It gives you an irresistible urge to Nya in every sentence.", { op = "gag", state = "nyamask" }),
    Button("gag-small", "Small Gag", "small-gag-232-with-bg_ergebnis.tga", "Your owner has fitted a small silken gag over your mouth. Speech is now garbled.", { op = "gag", state = "small" }),
    Button("gag-heavy", "Heavy Gag", "Heavy-gag-232-with-bg_ergebnis.tga", "Your owner has secured a heavy gag in place. You can no longer speak.", { op = "gag", state = "huge" }),
    Button("gag-full", "Kitty Mask With Gag!", "kitty-mask-with-gag-232-with-bg_ergebnis.tga", "Your owner put a gag and a Kitten Mask on you! You must have been a really naughty cat!", { op = "gag", state = "full" }),
    Button("gag-inflatable", "Inflatable Gag", "Inflatable-gag-232-with-bg_ergebnis.tga", "Your owner fits an inflatable gag over your mouth.", { op = "gag", state = "inflatable", stage = "0" }),
    Button("gag-inflate", "Inflate Gag", nil, "Your owner inflates your gag.", { op = "gagstep", dir = "up" }),
    Button("gag-deflate", "Deflate Gag", nil, "Your owner deflates your gag.", { op = "gagstep", dir = "down" }),
    Button("ungag", "Ungag", nil, "Your gag has been removed by your owner. You can speak freely again.", { op = "gag", state = "none" }),
    Button("lock-gag", "Remove Gag in X Hours", nil, "Your owner set your gag to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "gag" }, { delay = true }),
    Button("blind-light", "Light Blindfold", "Light-Blindfold-232-with-bg_ergebnis.tga", "Your owner put a light blindfold on you.", { op = "blind", state = "light" }),
    Button("blind-mask", "Cute Kitty Blindfold", "Cute-Kitty-Blindfold-232-with-bg_ergebnis.tga", "Your owner put a cute kitty blindfold on you.", { op = "blind", state = "mask" }),
    Button("blind-full", "Full Blindfold", "Heavy-Blindfold-232-with-bg_ergebnis.tga", "Your owner put a full blindfold on you.", { op = "blind", state = "full" }),
    Button("blind-off", "Remove Blindfold", nil, "Your owner removed your blindfold.", { op = "blind", state = "none" }),
    Button("lock-blind", "Remove Blindfold in X Hours", nil, "Your owner set your blindfold to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "blindfold" }, { delay = true }),
    Button("ears-kitten", "Kitten Earmuffs", "Kitten-Earmuffs-bg_ergebnis.tga", "Your owner put kitten earmuffs on you.", { op = "ears", state = "kitten" }),
    Button("ears-heavy", "Heavy Earmuffs", "Heav-Earmuffs-bg_ergebnis.tga", "Your owner put heavy earmuffs on you, Nyo!!!", { op = "ears", state = "heavy" }),
    Button("ears-off", "Remove Earmuffs", nil, "Your owner removed your earmuffs. Puhhh~", { op = "ears", state = "none" }),
    Button("lock-ears", "Remove Earmuffs in X Hours", nil, "Your owner set your earmuffs to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "earmuffs" }, { delay = true }),
    Button("bell-on", "Attach Bell", "bell-232-with-bg_ergebnis.tga", "You hear a soft *click* as your owner attaches a tiny bell to your collar. Every step now jingles~", { op = "bell", which = "collar", on = "1" }),
    Button("tail-on", "Attach Tail Bell", "tail-bell-232-with-bg_ergebnis.tga", "You hear a soft *click* as your owner attaches a tiny bell to your tail. Every step now jingles~", { op = "bell", which = "tail", on = "1" }),
    Button("bell-off", "Remove Bell", nil, "With a gentle touch, your owner removes the bell from your collar. It's quiet again... for now.", { op = "bell", which = "collar", on = "0" }),
    Button("lock-bell", "Remove Bell in X Hours", nil, "Your owner set your bell to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "bell" }, { delay = true }),
    Button("tail-off", "Remove Tail Bell", nil, "With a gentle touch, your owner removes the tail bell. It's quiet again... for now.", { op = "bell", which = "tail", on = "0" }),
    Button("lock-tail", "Remove Tail Bell in X Hours", nil, "Your owner set your tail bell to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "tailbell" }, { delay = true }),
    Button("mittens-locked", "Lockable Paw Mittens", "locking-paw-mitten-232-with-bg_ergebnis.tga", "Your owner has locked tight paw mittens onto your paws. They are reinforced so you cannot use your paws properly or extend your claws at all.", { op = "mittens", state = "locked" }),
    Button("mittens-squeak", "Squeking Paw Mittens", "paw-mitten-232-with-bg_ergebnis.tga", "Your owner has locked squeking paw mittens onto your paws. They squeak whenever you cast and only swap your spells briefly every 30 seconds.", { op = "mittens", state = "squeaking" }),
    Button("mittens-off", "Remove Paw Mittens", nil, "Your owner removed your paw mittens. Your paws are free again.", { op = "mittens", state = "none" }),
    Button("lock-mittens", "Remove Paw Mittens in X Hours", nil, "Your owner set your paw mittens to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "mittens" }, { delay = true }),
    Button("belt-on", "Lock Chastity Belt", "Chastitybelt.tga", "Your owner locked a chastity belt around your hips. Your pleasure is sealed away.", { op = "belt", on = "1" }),
    Button("bra-on", "Lock Chastity Bra", "chastitybra.tga", "Your owner locked a chastity bra around your chest. Your nipples are sealed away.", { op = "bra", on = "1" }),
    Button("belt-deny", "Deny Orgasm", nil, "Your owner set the chastity belt to Deny Orgasm.", { op = "beltmode", mode = "deny" }),
    Button("belt-allow", "Allow Orgasm", nil, "Your owner set the chastity belt to Allow Orgasm.", { op = "beltmode", mode = "allow" }),
    Button("belt-off", "Remove Chastity Belt", nil, "Your owner removed your chastity belt.", { op = "belt", on = "0" }),
    Button("lock-belt", "Remove Chastity Belt in X Hours", nil, "Your owner set your chastity belt to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "chastitybelt" }, { delay = true }),
    Button("bra-off", "Remove Chastity Bra", nil, "Your owner removed your chastity bra.", { op = "bra", on = "0" }),
    Button("lock-bra", "Remove Chastity Bra in X Hours", nil, "Your owner set your chastity bra to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "chastitybra" }, { delay = true }),
    Button("heels-maid", "Locking Maid Heels 3-CM", "maid-heell-232-with-bg_ergebnis.tga", "Your owner locked you into locking maid heels 3-CM. The heels are locked on; the higher the heel, the harder it is to walk.", { op = "heels", state = "maid" }),
    Button("heels-high", "Locking High Heels 8-CM", "heell-232-with-bg_ergebnis.tga", "Your owner locked you into locking high heels 8-CM. The heels are locked on; the higher the heel, the harder it is to walk.", { op = "heels", state = "high" }),
    Button("heels-ballet", "Locking Ballet Boot 12-CM", "balletheel-232-with-bg_ergebnis.tga", "Your owner locked you into locking ballet boot 12-CM. The heels are locked on; the higher the heel, the harder it is to walk. Your feet were squeezed into them, and it is going to be painful for an untrained kitten after just a few minutes.", { op = "heels", state = "ballet" }),
    Button("heels-off", "Remove Heels", nil, "Your owner removed your heels. Your feet are free again.", { op = "heels", state = "none" }),
    Button("lock-heels", "Remove Heels in X Hours", nil, "Your owner set your heels to unlock in %.1f hours (%d) minutes.", { op = "lock", bind = "heels" }, { delay = true }),
    Button("jewel-on", "Attach Tracking Jewel", "jewel-232-with-bg_ergebnis.tga", "Your owner attached a glowing jewel to your collar. Its magic will track your every move!", { op = "jewel", on = "1" }),
    Button("group", "Force Kitty Group", nil, "Owner Forces you to Create a group", { op = "group" }),
    Button("jewel-off", "Remove Tracking Jewel", nil, "Your owner removed the glowing jewel from your collar. Its magic will no longer track you.", { op = "jewel", on = "0" }),
}

local function CopyFields(fields)
    local copy = {}
    for key, value in pairs(fields or {}) do
        copy[key] = value
    end
    return copy
end

local function AddToys()
    local list = CCT.Toys and CCT.Toys.List or {}
    for i = 1, #list do
        local toy = list[i]
        BUTTONS[#BUTTONS + 1] = Button(
            "toy-apply-" .. toy.id,
            toy.label,
            toy.icon,
            nil,
            { op = "toy", id = toy.id, action = "apply" },
            { toy = toy.id, action = "apply" }
        )
        BUTTONS[#BUTTONS + 1] = Button(
            "toy-remove-" .. toy.id,
            "Remove " .. toy.label,
            toy.icon,
            nil,
            { op = "toy", id = toy.id, action = "remove" },
            { toy = toy.id, action = "remove" }
        )
        if toy.vibe then
            BUTTONS[#BUTTONS + 1] = Button(
                "toy-vibe-" .. toy.id,
                toy.label .. " Vibe",
                toy.icon,
                nil,
                { op = "toy", id = toy.id, action = "vibe", level = "1" },
                { toy = toy.id, action = "vibe" }
            )
        end
        if toy.shock then
            BUTTONS[#BUTTONS + 1] = Button(
                "toy-shock-" .. toy.id,
                toy.label .. " Shock",
                toy.icon,
                nil,
                { op = "toy", id = toy.id, action = "shock", level = "1" },
                { toy = toy.id, action = "shock" }
            )
        end
        if toy.inflate then
            BUTTONS[#BUTTONS + 1] = Button(
                "toy-inflate-" .. toy.id,
                toy.label .. " Inflate",
                toy.icon,
                nil,
                { op = "toy", id = toy.id, action = "inflate" },
                { toy = toy.id, action = "inflate" }
            )
            BUTTONS[#BUTTONS + 1] = Button(
                "toy-deflate-" .. toy.id,
                toy.label .. " Deflate",
                toy.icon,
                nil,
                { op = "toy", id = toy.id, action = "deflate" },
                { toy = toy.id, action = "deflate" }
            )
        end
    end
end

local function AddDiscipline()
    local actions = CCT.Discipline and CCT.Discipline.Actions or {}
    for i = 1, #actions do
        local action = actions[i]
        for p = 1, #action.parts do
            local part = action.parts[p]
            BUTTONS[#BUTTONS + 1] = Button(
                "disc-" .. action.id .. "-" .. part.id,
                action.label .. " " .. part.label,
                action.icon,
                nil,
                { op = "disc", id = action.id, part = part.id, str = "1" },
                { discipline = true, action = action.id, part = part.id }
            )
        end
    end
end

AddToys()
AddDiscipline()

BUTTONS[#BUTTONS + 1] = Button("advertise", "Advertise", nil, nil, nil, { localOnly = true })

CCT.Control.Buttons = BUTTONS

local function FindButton(id)
    for i = 1, #BUTTONS do
        if BUTTONS[i].id == id then
            return BUTTONS[i]
        end
    end
    return nil
end

function CCT.Control.IconPath(fileName)
    return Icon(fileName)
end

function CCT.Control.LockMinutes(text)
    local hours = tonumber(text)
    if hours == nil then
        hours = 1.5
    end
    if hours <= 0 then
        return nil
    end
    local minutes = math.floor(hours * 60 + 0.5)
    if minutes > 10080 then
        minutes = 10080
    end
    if minutes < 1 then
        return nil
    end
    return minutes, hours
end

function CCT.Control.MaidShell()
    return "Maid editor", "Maid lists are edited here. Nothing is sent yet."
end

local function KittenName(name)
    if type(name) == "string" and name ~= "" then
        return CCT.ShortName(name) or name
    end
    local assigned = CCT.Roster and CCT.Roster.GetAssignedKitten and CCT.Roster.GetAssignedKitten()
    if type(assigned) == "table" then
        return assigned.short
    end
    return nil
end

local function KittenRecord(name)
    local short = KittenName(name)
    if short == nil or CCT.Saved == nil or type(CCT.Saved.Init) ~= "function" then
        return nil, short
    end
    CCT.Saved.Init()
    local db = CCT.db
    if type(db) ~= "table" or type(db.owner) ~= "table" or type(db.owner.kitten) ~= "table" then
        return nil, short
    end
    if type(db.owner.kitten[short]) == "table" then
        return db.owner.kitten[short], short
    end
    for key, row in pairs(db.owner.kitten) do
        if CCT.SameName(key, short) then
            return row, key
        end
    end
    return nil, short
end

function CCT.Control.OwnerPos()
    if CCT.Report and CCT.Report.Here then
        return CCT.Report.Here()
    end
    return nil
end

local function Distance(state)
    local pos = type(state) == "table" and state.pos or nil
    if type(state) ~= "table" or state.jewel ~= true or type(pos) ~= "table" then
        return "unknown", nil
    end
    local owner = CCT.Control.OwnerPos()
    if type(owner) ~= "table" or type(owner.x) ~= "number" or type(pos.x) ~= "number" or owner.mapID ~= pos.mapID then
        return "unknown", nil
    end
    local dx = owner.x - pos.x
    local dy = owner.y - pos.y
    local dist = math.sqrt(dx * dx + dy * dy)
    return dist, dist
end

function CCT.Control.Summary(name)
    local row = KittenRecord(name)
    if type(row) ~= "table" or type(row.state) ~= "table" or row.state.rev == nil then
        return { text = "no snapshot", kitten = KittenName(name) }
    end
    local state = row.state
    local distance = Distance(state)
    local locks = {}
    local now = CCT.UnixNow()
    for bind, lock in pairs(state.locks or {}) do
        if type(lock) == "table" and tonumber(lock.unlockAt) then
            locks[bind] = lock.unlockAt - now
        end
    end
    local toys = {}
    for id, toy in pairs(state.toys or {}) do
        if type(toy) == "table" and (toy.applied or (tonumber(toy.vibe) or 0) ~= 0 or (tonumber(toy.inflate) or 0) ~= 0) then
            toys[id] = { applied = toy.applied == true, vibe = toy.vibe or 0, inflate = toy.inflate or 0 }
        end
    end
    local heat = tonumber(state.heat) or 0
    local color = "green"
    if heat >= 70 then
        color = "red"
    elseif heat >= 40 then
        color = "yellow"
    end
    return {
        text = "snapshot",
        kitten = KittenName(name),
        heat = heat,
        sub = tonumber(state.sub) or 0,
        color = color,
        distance = distance,
        locks = locks,
        toys = toys,
        state = state,
        sent = row.sent or {},
    }
end

local function Pairs(fields)
    local list = {}
    local order = { "op", "cid", "state", "stage", "dir", "which", "on", "mode", "id", "action", "level", "part", "str", "bind", "minutes", "map", "x", "y", "inst" }
    local used = {}
    for i = 1, #order do
        local key = order[i]
        if fields[key] ~= nil then
            list[#list + 1] = { key, fields[key] }
            used[key] = true
        end
    end
    for key, value in pairs(fields) do
        if not used[key] then
            list[#list + 1] = { key, value }
        end
    end
    return list
end

function CCT.Control.Send(kitten, fields, meta)
    if type(fields) ~= "table" or fields.op == nil or CCT.Net == nil then
        return false, "fields"
    end
    local cid = tostring(fields.cid or nextCid)
    if fields.cid == nil then
        nextCid = nextCid + 1
        fields.cid = cid
    end
    meta = type(meta) == "table" and meta or {}
    meta.op = fields.op
    meta.fields = fields
    if CCT.Corroboration and CCT.Corroboration.Begin then
        CCT.Corroboration.Begin(kitten, cid, meta)
    end
    local queued = CCT.Net.Whisper(kitten, "cmd", Pairs(fields), function(ok, result)
        if CCT.Corroboration and CCT.Corroboration.OnResult then
            CCT.Corroboration.OnResult(cid, ok, result)
        end
    end)
    return queued and true or false, cid
end

local function TooFar(state)
    if type(state) ~= "table" or state.jewel ~= true then
        return true
    end
    local owner = CCT.Control.OwnerPos()
    local pos = state.pos
    if type(owner) == "table" and type(pos) == "table" and type(owner.x) == "number" and type(pos.x) == "number" and owner.mapID == pos.mapID then
        local dx = owner.x - pos.x
        local dy = owner.y - pos.y
        return math.sqrt(dx * dx + dy * dy) > DISC_RANGE
    end
    if type(owner) == "table" and type(owner.instanceID) == "number" and type(pos) == "table" and tonumber(pos.instanceID) ~= nil and (type(pos.x) ~= "number" or type(owner.x) ~= "number") then
        return owner.instanceID ~= pos.instanceID
    end
    return true
end

local function ToyBlocked(spec, state)
    if spec.toy == nil or (spec.action ~= "apply" and spec.action ~= "remove") then
        return false
    end
    if type(state) ~= "table" then
        return false
    end
    local toy = nil
    local list = CCT.Toys and CCT.Toys.List or {}
    for i = 1, #list do
        if list[i].id == spec.toy then
            toy = list[i]
            break
        end
    end
    if toy == nil then
        return false
    end
    if toy.restrict == "belt" and state.belt == true then
        return true
    end
    if toy.restrict == "bra" and state.bra == true then
        return true
    end
    return false
end

function CCT.Control.Press(id, hoursText, kitten)
    local spec = FindButton(id)
    if spec == nil then
        return false, "button"
    end
    if spec.localOnly then
        if CCT.Advertise and CCT.Advertise.Toggle then
            CCT.Advertise.Toggle()
        end
        return true, "advertise"
    end
    local name = KittenName(kitten)
    if name == nil then
        return false, "kitten"
    end
    local record = KittenRecord(name)
    local state = type(record) == "table" and record.state or nil
    if spec.discipline and TooFar(state) then
        if print then
            print(CCT.Msg("DISCIPLINE_TOO_FAR"))
        end
        return false, "toofar"
    end
    if ToyBlocked(spec, state) then
        return false, "restrict"
    end
    local fields = CopyFields(spec.fields)
    local sentence = spec.sentence
    if spec.delay then
        local minutes, hours = CCT.Control.LockMinutes(hoursText)
        if minutes == nil then
            return false, "minutes"
        end
        fields.minutes = tostring(minutes)
        if type(sentence) == "string" then
            sentence = string.format(sentence, hours, minutes)
        end
    end
    if spec.discipline then
        local owner = CCT.Control.OwnerPos() or {}
        if type(owner.mapID) == "number" then
            fields.map = string.format("%.0f", owner.mapID)
        end
        if type(owner.x) == "number" then
            fields.x = string.format("%.4f", owner.x)
        end
        if type(owner.y) == "number" then
            fields.y = string.format("%.4f", owner.y)
        end
        if type(owner.instanceID) == "number" then
            fields.inst = tostring(owner.instanceID)
        end
    end
    return CCT.Control.Send(name, fields, {
        op = fields.op,
        sentence = sentence,
        detail = spec.label,
    })
end

local function Supports()
    if ready ~= nil then
        return ready
    end
    ready = false
    if type(CreateFrame) ~= "function" or UIParent == nil then
        return false
    end
    local probe = CreateFrame("Frame")
    if type(probe.SetClampedToScreen) ~= "function" then
        return false
    end
    local scroll = CreateFrame("ScrollFrame")
    if type(scroll.SetScrollChild) ~= "function" then
        return false
    end
    local edit = CreateFrame("EditBox")
    if type(edit.SetText) ~= "function" or type(edit.GetText) ~= "function" then
        return false
    end
    ready = true
    return true
end

function CCT.Control.Open()
    if not Supports() then
        return nil
    end
    if window == nil then
        window = CreateFrame("Frame", "CatgirlControlCenter", UIParent)
        window:SetSize(420, 520)
        window:SetPoint("CENTER")
        window:SetClampedToScreen(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        local scroll = CreateFrame("ScrollFrame", nil, window)
        scroll:SetAllPoints()
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(400, 40 + (#BUTTONS * 22))
        scroll:SetScrollChild(child)
        window.hours = CreateFrame("EditBox", nil, window)
        window.hours:SetText("1.5")
        window.status = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        window:Hide()
    end
    local summary = CCT.Control.Summary()
    if window.status and window.status.SetText then
        if summary.text == "no snapshot" then
            window.status:SetText("no snapshot")
        else
            window.status:SetText(string.format("heat %s sub %s", tostring(summary.heat), tostring(summary.sub)))
        end
    end
    window:Show()
    return window
end

function CCT.Control.Toggle()
    if window and window.IsShown and window:IsShown() then
        window:Hide()
        return window
    end
    return CCT.Control.Open()
end

function CCT.Control.Hours()
    if window and window.hours and window.hours.GetText then
        return window.hours:GetText()
    end
    return "1.5"
end

SLASH_CGCC1 = "/cgcc"
if SlashCmdList then
    SlashCmdList.CGCC = function(msg)
        if type(msg) == "string" and msg:lower():find("advertise", 1, true) then
            if CCT.Advertise and CCT.Advertise.Toggle then
                CCT.Advertise.Toggle()
            end
            return
        end
        CCT.Control.Toggle()
    end
end
