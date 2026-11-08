-- Owner control center. /cgcc reads the snapshot and enqueues Cmd.
-- The window opens with no assigned kitten. Kitten actions stay disabled until one is assigned.
-- A draggable cgcc button opens the same window. Nya and advertise stay available. They belong to this character.
-- Buttons do not call SendAddonMessage. Counting waits for Success and Ack ok:1.
-- The maid editor is CCT.Maid. Picture popups, the binds strip, and advertise already shipped.
-- Force group is Cmd op group. KittyLayerGroup.lua layer list, linv, and the NWB read do not ship. The classic leave-first frame does not ship either.
-- The omitted layer list is KittyLayerGroup.lua. Layer chat is not in this addon.

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
    local body = "0 items, 0 instructions"
    if CCT.Maid and type(CCT.Maid.Summary) == "function" then
        body = CCT.Maid.Summary()
    end
    return "Maid editor", body
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

local launcher = nil

local function HasKitten()
    return KittenName() ~= nil
end

local function SetWidgetEnabled(widget, enabled)
    if widget == nil then
        return
    end
    widget.cctEnabled = enabled == true
    if type(widget.SetEnabled) == "function" then
        widget:SetEnabled(enabled == true)
    end
end

local function ApplyAccess()
    if window == nil then
        return
    end
    local owned = HasKitten()
    local rows = window.rows
    if type(rows) == "table" then
        for i = 1, #rows do
            local row = rows[i]
            local localOnly = type(row.spec) == "table" and row.spec.localOnly == true
            SetWidgetEnabled(row.button, owned or localOnly)
        end
    end
    SetWidgetEnabled(window.hours, owned)
end

local function StatusLine(summary)
    local name = type(summary) == "table" and summary.kitten or nil
    if type(name) ~= "string" or name == "" then
        return "Kitten: None assigned"
    end
    if summary.text == "no snapshot" then
        return "Kitten: " .. name .. ". no snapshot"
    end
    return string.format("Kitten: %s. heat %s sub %s", name, tostring(summary.heat), tostring(summary.sub))
end

local function OnRowClick(spec)
    if spec.localOnly ~= true and not HasKitten() then
        return false
    end
    return CCT.Control.Press(spec.id, CCT.Control.Hours())
end

local function BuildRows(parent)
    local rows = {}
    for i = 1, #BUTTONS do
        local spec = BUTTONS[i]
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        if button.SetSize then
            button:SetSize(340, 20)
        end
        if button.SetPoint then
            button:SetPoint("TOPLEFT", 8, -4 - ((i - 1) * 22))
        end
        if button.SetText then
            button:SetText(spec.label)
        end
        if button.RegisterForClicks then
            button:RegisterForClicks("LeftButtonUp")
        end
        if button.SetScript then
            button:SetScript("OnClick", function()
                OnRowClick(spec)
            end)
        end
        rows[i] = { id = spec.id, spec = spec, button = button }
    end
    return rows
end

local function OnMouseWheel(self, delta)
    if type(self.GetVerticalScroll) ~= "function" or type(self.SetVerticalScroll) ~= "function" then
        return
    end
    local current = self:GetVerticalScroll()
    if type(current) ~= "number" then
        return
    end
    local nextScroll = current - ((tonumber(delta) or 0) * 22)
    if nextScroll < 0 then
        nextScroll = 0
    end
    local child = type(self.GetScrollChild) == "function" and self:GetScrollChild() or nil
    local maxScroll = 0
    if type(child) == "table" and type(child.GetHeight) == "function" and type(self.GetHeight) == "function" then
        local content = child:GetHeight()
        local view = self:GetHeight()
        if type(content) == "number" and type(view) == "number" then
            maxScroll = content - view
        end
    end
    if maxScroll < 0 then
        maxScroll = 0
    end
    if nextScroll > maxScroll then
        nextScroll = maxScroll
    end
    self:SetVerticalScroll(nextScroll)
end

local function LauncherChar(create)
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" or CCT.Saved == nil then
        return nil
    end
    if create and type(CCT.Saved.EnsureChar) == "function" then
        return CCT.Saved.EnsureChar(short)
    end
    local db = CCT.db
    if type(db) ~= "table" or type(db.chars) ~= "table" then
        return nil
    end
    local char = db.chars[short]
    if type(char) ~= "table" then
        return nil
    end
    return char
end

local function SaveLauncher(frame)
    if frame == nil or type(frame.GetPoint) ~= "function" then
        return
    end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then
        return
    end
    local char = LauncherChar(true)
    if char == nil then
        return
    end
    char.cgccButton = {
        point = point,
        relativePoint = type(relativePoint) == "string" and relativePoint or point,
        x = tonumber(x) or 0,
        y = tonumber(y) or -210,
    }
end

local function ApplyLauncherPoint(frame)
    if frame == nil or type(frame.SetPoint) ~= "function" then
        return
    end
    local char = LauncherChar(false)
    local saved = char and char.cgccButton
    if type(saved) ~= "table" or type(saved.point) ~= "string" then
        frame:SetPoint("TOP", UIParent, "TOP", 0, -210)
        return
    end
    if type(frame.ClearAllPoints) == "function" then
        frame:ClearAllPoints()
    end
    frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or -210)
end

function CCT.Control.Launcher()
    return launcher
end

function CCT.Control.EnsureLauncher()
    if launcher ~= nil or type(CreateFrame) ~= "function" or UIParent == nil then
        return launcher
    end
    launcher = CreateFrame("Button", "CatgirlControlCenterOpenButton", UIParent, "UIPanelButtonTemplate")
    if launcher == nil then
        return nil
    end
    if launcher.SetSize then
        launcher:SetSize(80, 24)
    end
    ApplyLauncherPoint(launcher)
    if launcher.SetText then
        launcher:SetText("cgcc")
    end
    if launcher.SetMovable then
        launcher:SetMovable(true)
    end
    if launcher.EnableMouse then
        launcher:EnableMouse(true)
    end
    if launcher.RegisterForClicks then
        launcher:RegisterForClicks("LeftButtonUp")
    end
    if launcher.RegisterForDrag then
        launcher:RegisterForDrag("LeftButton")
    end
    if launcher.SetClampedToScreen then
        launcher:SetClampedToScreen(true)
    end
    if launcher.SetScript then
        launcher:SetScript("OnDragStart", function(self)
            if self.StartMoving then
                self:StartMoving()
            end
        end)
        launcher:SetScript("OnDragStop", function(self)
            if self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end
            SaveLauncher(self)
        end)
        launcher:SetScript("OnClick", function()
            CCT.Control.Toggle()
        end)
    end
    if launcher.Show then
        launcher:Show()
    end
    return launcher
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

function CCT.Control.Refresh()
    if window == nil then
        return nil
    end
    local summary = CCT.Control.Summary()
    if window.status and window.status.SetText then
        window.status:SetText(StatusLine(summary))
    end
    if window.maid and window.maid.SetText then
        window.maid:SetText(select(2, CCT.Control.MaidShell()))
    end
    ApplyAccess()
    return window
end

function CCT.Control.Open()
    if not Supports() then
        return nil
    end
    if window == nil then
        window = CreateFrame("Frame", "CatgirlControlCenter", UIParent, "BackdropTemplate")
        window:SetSize(420, 520)
        window:SetPoint("CENTER")
        window:SetClampedToScreen(true)
        window:SetMovable(true)
        window:EnableMouse(true)
        if window.SetFrameStrata then
            window:SetFrameStrata("DIALOG")
        end
        if window.SetBackdrop then
            window:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 8,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
        end
        if window.SetBackdropColor then
            window:SetBackdropColor(0, 0, 0, 0.85)
        end
        if window.RegisterForDrag then
            window:RegisterForDrag("LeftButton")
        end
        if window.SetScript then
            window:SetScript("OnDragStart", function(self)
                if self.StartMoving then
                    self:StartMoving()
                end
            end)
            window:SetScript("OnDragStop", function(self)
                if self.StopMovingOrSizing then
                    self:StopMovingOrSizing()
                end
            end)
        end
        local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if title and title.SetPoint then
            title:SetPoint("TOPLEFT", 12, -10)
        end
        if title and title.SetText then
            title:SetText("Catgirl Control")
        end
        local close = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        if close.SetSize then
            close:SetSize(56, 18)
        end
        if close.SetPoint then
            close:SetPoint("TOPRIGHT", -8, -8)
        end
        if close.SetText then
            close:SetText("Close")
        end
        if close.SetScript then
            close:SetScript("OnClick", function()
                window:Hide()
            end)
        end
        window.status = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if window.status.SetPoint then
            window.status:SetPoint("TOPLEFT", 12, -32)
        end
        local hoursLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if hoursLabel and hoursLabel.SetPoint then
            hoursLabel:SetPoint("TOPLEFT", 12, -52)
        end
        if hoursLabel and hoursLabel.SetText then
            hoursLabel:SetText("Hours")
        end
        window.hours = CreateFrame("EditBox", nil, window)
        window.hours:SetText("1.5")
        if window.hours.SetSize then
            window.hours:SetSize(48, 18)
        end
        if window.hours.SetPoint then
            window.hours:SetPoint("TOPLEFT", 58, -50)
        end
        if window.hours.SetAutoFocus then
            window.hours:SetAutoFocus(false)
        end
        if window.hours.SetFont then
            window.hours:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        end
        if window.hours.SetScript then
            window.hours:SetScript("OnEnterPressed", function(self)
                if self.ClearFocus then
                    self:ClearFocus()
                end
            end)
            window.hours:SetScript("OnEscapePressed", function(self)
                if self.ClearFocus then
                    self:ClearFocus()
                end
            end)
        end
        window.maid = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if window.maid.SetPoint then
            window.maid:SetPoint("TOPLEFT", 120, -52)
        end
        local scroll = CreateFrame("ScrollFrame", nil, window)
        if scroll.SetPoint then
            scroll:SetPoint("TOPLEFT", 8, -74)
            scroll:SetPoint("BOTTOMRIGHT", -12, 270)
        end
        local child = CreateFrame("Frame", nil, scroll)
        if child.SetSize then
            child:SetSize(380, 8 + (#BUTTONS * 22))
        end
        if scroll.SetScrollChild then
            scroll:SetScrollChild(child)
        end
        if scroll.EnableMouseWheel then
            scroll:EnableMouseWheel(true)
        end
        if scroll.SetScript then
            scroll:SetScript("OnMouseWheel", OnMouseWheel)
        end
        window.rows = BuildRows(child)
        if CCT.NyaOptions and type(CCT.NyaOptions.Attach) == "function" then
            CCT.NyaOptions.Attach(window)
        end
        window:Hide()
    end
    CCT.Control.Refresh()
    window:Show()
    if window.Raise then
        window:Raise()
    end
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

if type(CreateFrame) == "function" then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("GUILD_ROSTER_UPDATE")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            local frame = CCT.Control.EnsureLauncher()
            ApplyLauncherPoint(frame)
            return
        end
        if window ~= nil and window.IsShown and window:IsShown() then
            CCT.Control.Refresh()
        end
    end)
end

if type(CreateFrame) == "function" and UIParent ~= nil then
    CCT.Control.EnsureLauncher()
end
