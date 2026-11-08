-- Maid lists ride the reliable queue. One slot is one on-wire part.
-- An unchanged 60-second refresh reuses the update id and does not increment tasks.
-- A content change increments tasks once on the kitten when that id is applied,
-- and once on the owner after every logical fragment's parts pop Success and
-- the kitten acks ok:1. Not once per part and not once per fragment.
-- A push over 72 parts is a local Ack ok:0 reason:toobig. It is not retried.
-- A push that fits the cap but not the free slots enqueues nothing and retries.
-- ClampInstruction stays at 140 raw characters. A maidtext header is budgeted
-- at 80 bytes, so a legal instruction is at most two parts. Each item is one part.
-- Writers go through CCT.State. This file does not move feature state.

local ADDON_NAME, CCT = ...

CCT.Maid = {}

local MAX_PART = 255
local HEADER_BUDGET = 80
local ITEM_CAP = 20
local TEXT_CAP = 20
local TEXT_CHARS = 140
local THROTTLE_SECONDS = 5

CCT.Maid.HEADER_BUDGET = HEADER_BUDGET
CCT.Maid.ITEM_CAP = ITEM_CAP
CCT.Maid.TEXT_CAP = TEXT_CAP
CCT.Maid.TEXT_CHARS = TEXT_CHARS

local clock = nil
local updateSeq = 0
local lastSendAt = 0
local sentKey = nil
local sentId = nil
local appliedId = nil
local appliedKey = nil
local failure = nil
local pending = {}
local blocked = {}
local incoming = nil
local planHook = nil
local frame = nil
local frameItems = nil
local frameText = nil

local function Clock(now)
    if now ~= nil then
        local stamp = tonumber(now)
        if stamp ~= nil then
            clock = stamp
        end
    end
    if clock ~= nil then
        return clock
    end
    if type(time) == "function" then
        return time()
    end
    return 0
end

function CCT.Maid.Clock(now)
    return Clock(now)
end

local function Enabled()
    if CCT.Module and type(CCT.Module.Enabled) == "function" then
        return CCT.Module.Enabled("MaidTasks") == true
    end
    return true
end

local function PartCap()
    return (CCT.Net and CCT.Net.RELIABLE_CAP) or 72
end

local function Encode(value)
    if CCT.Net and type(CCT.Net.EncodeUser) == "function" then
        return CCT.Net.EncodeUser(value)
    end
    return tostring(value or "")
end

local function Decode(value)
    if value == nil then
        return ""
    end
    if CCT.Net and type(CCT.Net.DecodeUser) == "function" then
        return CCT.Net.DecodeUser(value)
    end
    return tostring(value)
end

function CCT.Maid.Encode(value)
    return Encode(value)
end

function CCT.Maid.ClampInstruction(text)
    if text == nil then
        return ""
    end
    local cleaned = tostring(text)
    cleaned = cleaned:gsub("\r", "")
    cleaned = cleaned:gsub("[\n]+", " ")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    if #cleaned > TEXT_CHARS then
        cleaned = cleaned:sub(1, TEXT_CHARS)
    end
    return cleaned
end

local function CompleteUtf8(text)
    local i = 1
    local last = 0
    while i <= #text do
        local b = text:byte(i)
        local len = 1
        if b >= 240 then
            len = 4
        elseif b >= 224 then
            len = 3
        elseif b >= 192 then
            len = 2
        elseif b >= 128 then
            return text:sub(1, last)
        end
        if i + len - 1 > #text then
            return text:sub(1, last)
        end
        last = i + len - 1
        i = i + len
    end
    return text:sub(1, last)
end

local function Store()
    local short = CCT.Player and CCT.Player.short
    if type(short) ~= "string" or short == "" or CCT.Saved == nil or type(CCT.Saved.EnsureChar) ~= "function" then
        return nil
    end
    local char = CCT.Saved.EnsureChar(short)
    if type(char) ~= "table" then
        return nil
    end
    if type(char.maid) ~= "table" then
        char.maid = { items = {}, instructions = {} }
    end
    if type(char.maid.items) ~= "table" then
        char.maid.items = {}
    end
    if type(char.maid.instructions) ~= "table" then
        char.maid.instructions = {}
    end
    return char.maid
end

local function ItemCount(item)
    if type(item) ~= "table" or C_Item == nil or type(C_Item.GetItemCount) ~= "function" then
        return 0
    end
    local key = item.itemID or item.displayName or item.name
    if key == nil then
        return 0
    end
    local ok, count = pcall(C_Item.GetItemCount, key, true)
    if not ok then
        return 0
    end
    return tonumber(count) or 0
end

local function ContentKey(items, instructions)
    local bits = {}
    for i = 1, #items do
        local item = items[i]
        bits[#bits + 1] = table.concat({
            tostring(item.itemID or ""),
            tostring(item.count or 0),
            Encode(item.name or ""),
        }, "=")
    end
    bits[#bits + 1] = "#"
    for i = 1, #instructions do
        bits[#bits + 1] = Encode(instructions[i] or "")
    end
    return table.concat(bits, ";")
end

local function LiveCopy(store)
    local items = {}
    local source = store and store.items or {}
    for i = 1, math.min(ITEM_CAP, #source) do
        local item = source[i]
        items[#items + 1] = {
            itemID = item.itemID,
            name = item.displayName or item.name or "",
            count = ItemCount(item),
        }
    end
    local instructions = {}
    local texts = store and store.instructions or {}
    for i = 1, math.min(TEXT_CAP, #texts) do
        if type(texts[i]) == "string" then
            instructions[#instructions + 1] = texts[i]
        end
    end
    return items, instructions
end

function CCT.Maid.Summary()
    local store = Store()
    local items, instructions = LiveCopy(store)
    return string.format("%d items, %d instructions", #items, #instructions)
end

function CCT.Maid.Items()
    local store = Store()
    if store == nil then
        return {}
    end
    return store.items
end

function CCT.Maid.Instructions()
    local store = Store()
    if store == nil then
        return {}
    end
    return store.instructions
end

function CCT.Maid.Failure()
    return failure
end

function CCT.Maid.HookPlan(fn)
    if fn ~= nil and type(fn) ~= "function" then
        return false
    end
    planHook = fn
    return true
end

local function Assigned()
    local row = CCT.Roster and CCT.Roster.GetAssignedKitten and CCT.Roster.GetAssignedKitten()
    if type(row) ~= "table" or type(row.short) ~= "string" or row.short == "" then
        return nil
    end
    if row.online ~= true then
        return nil
    end
    return row.short
end

local function NextId()
    updateSeq = (updateSeq + 1) % 1000
    local base = Clock() % 2000000
    return tostring((base * 1000) + updateSeq)
end

local function Prefix(op, id, idx)
    local cid = tostring(id)
    local text = "Cmd,op:" .. op .. ",cid:" .. cid .. ",id:" .. cid
    if idx ~= nil then
        text = text .. ",idx:" .. tostring(idx)
    end
    return text
end

local function ItemWire(prefix, itemID, count, label)
    local encoded = Encode(label)
    local tail = ",n:" .. tostring(count or 0) .. ",name:" .. encoded
    if itemID ~= nil then
        tail = ",item:" .. tostring(itemID) .. tail
    end
    return prefix .. tail
end

local function FitLabel(prefix, itemID, count, name)
    local function wire(label)
        return ItemWire(prefix, itemID, count, label)
    end
    if #wire(name) <= MAX_PART then
        return { wire(name) }
    end
    local lo, hi = 0, #name
    local best = 0
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local cut = CompleteUtf8(name:sub(1, mid))
        if #wire(cut) <= MAX_PART then
            best = #cut
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    local cut = CompleteUtf8(name:sub(1, best))
    return { wire(cut) }
end

local function TextWire(prefix, slice, part, total)
    local encoded = Encode(slice)
    local partToken = ""
    if total > 1 then
        partToken = ",part:" .. tostring(part) .. "/" .. tostring(total)
    end
    return prefix .. partToken .. ",text:" .. encoded
end

local function TwoPart(prefix, slice)
    for cut = 1, #slice - 1 do
        local left = CompleteUtf8(slice:sub(1, cut))
        if left ~= "" and #left == cut then
            local right = slice:sub(#left + 1)
            local a = TextWire(prefix, left, 1, 2)
            local b = TextWire(prefix, right, 2, 2)
            if #a <= MAX_PART and #b <= MAX_PART and #right > 0 then
                return { a, b }
            end
        end
    end
    return nil
end

local function FitText(prefix, raw)
    if raw == "" then
        return { TextWire(prefix, "", 1, 1) }
    end
    if #TextWire(prefix, raw, 1, 1) <= MAX_PART then
        return { TextWire(prefix, raw, 1, 1) }
    end
    local pair = TwoPart(prefix, raw)
    if pair ~= nil then
        return pair
    end
    local limit = #raw
    while limit > 1 do
        limit = limit - 1
        local slice = CompleteUtf8(raw:sub(1, limit))
        if slice ~= "" then
            if #TextWire(prefix, slice, 1, 1) <= MAX_PART then
                return { TextWire(prefix, slice, 1, 1) }
            end
            pair = TwoPart(prefix, slice)
            if pair ~= nil then
                return pair
            end
        end
    end
    return nil
end

local function Header(id, role, count, owner)
    local wire = Prefix("maid", id, nil) .. ",role:" .. role .. ",count:" .. tostring(count)
    if owner ~= nil and owner ~= "" then
        wire = wire .. ",owner:" .. owner
    end
    return { kind = "maid", wires = { wire } }
end

local function Build(id)
    local store = Store()
    local items, instructions = LiveCopy(store)
    local owner = CCT.Player and CCT.Player.short or nil
    local fragments = {
        Header(id, "items", #items, owner),
        Header(id, "texts", #instructions, nil),
    }
    for i = 1, #items do
        local item = items[i]
        local wires = FitLabel(Prefix("maiditem", id, i), item.itemID, item.count, item.name or "")
        if wires == nil or wires[1] == nil or #wires[1] > MAX_PART then
            return nil
        end
        fragments[#fragments + 1] = { kind = "maiditem", wires = wires }
    end
    for i = 1, #instructions do
        local wires = FitText(Prefix("maidtext", id, i), instructions[i])
        if wires == nil then
            return nil
        end
        for n = 1, #wires do
            if #wires[n] > MAX_PART then
                return nil
            end
        end
        fragments[#fragments + 1] = { kind = "maidtext", wires = wires }
    end
    local parts = 0
    for i = 1, #fragments do
        parts = parts + #fragments[i].wires
    end
    return fragments, parts, ContentKey(items, instructions)
end

local function TryCount(slot)
    if slot == nil or slot.counted or slot.armed ~= true or slot.sent ~= true or slot.ack ~= true then
        return false
    end
    slot.counted = true
    if CCT.Corroboration and type(CCT.Corroboration.CountTasks) == "function" then
        CCT.Corroboration.CountTasks(slot.kitten)
    end
    return true
end

function CCT.Maid.Send(force)
    if not Enabled() then
        return "disabled"
    end
    local now = Clock()
    if not force and (now - lastSendAt) < THROTTLE_SECONDS then
        return "throttle"
    end
    local target = Assigned()
    if target == nil then
        return "offline"
    end
    local fragments, parts, fingerprint, changed, id
    if planHook ~= nil then
        local plan = planHook()
        if type(plan) ~= "table" then
            return "empty"
        end
        fragments = plan.fragments or {}
        parts = tonumber(plan.parts) or 0
        fingerprint = plan.fingerprint or ""
        changed = plan.changed and true or false
        id = plan.id or NextId()
    else
        fingerprint = select(3, Build("0"))
        if fingerprint == nil then
            blocked[""] = true
            failure = { ok = "0", reason = "toobig" }
            return "toobig"
        end
        if blocked[fingerprint] then
            return "toobig"
        end
        changed = fingerprint ~= sentKey or sentId == nil
        id = (not changed and sentId) or NextId()
        fragments, parts, fingerprint = Build(id)
        if fragments == nil then
            blocked[fingerprint or ""] = true
            failure = { ok = "0", reason = "toobig", id = id }
            return "toobig"
        end
    end
    fingerprint = fingerprint or ""
    if blocked[fingerprint] then
        return "toobig"
    end
    if parts > PartCap() then
        blocked[fingerprint] = true
        failure = { ok = "0", reason = "toobig", id = id ~= nil and tostring(id) or nil }
        return "toobig"
    end
    if CCT.Net == nil or type(CCT.Net.EnqueueSet) ~= "function" then
        return "offline"
    end
    local idText = tostring(id)
    local existing = pending[idText]
    local reused = existing ~= nil and existing.armed == true and existing.counted ~= true
    local slot = existing
    if reused then
        slot.kitten = target
    else
        slot = {
            armed = changed and true or false,
            kitten = target,
            counted = false,
            sent = false,
            ack = false,
            id = idText,
        }
        pending[slot.id] = slot
    end
    local status = CCT.Net.EnqueueSet(target, fragments, function(ok)
        slot.sent = ok == true
        if ok == true then
            TryCount(slot)
        end
    end)
    if status ~= "queued" then
        if not reused and pending[slot.id] == slot then
            pending[slot.id] = nil
        end
        if status == "toobig" then
            blocked[fingerprint] = true
            failure = { ok = "0", reason = "toobig", id = slot.id }
        end
        return status
    end
    sentKey = fingerprint
    sentId = slot.id
    lastSendAt = now
    return "queued", slot.id
end

function CCT.Maid.Tick(now)
    if now ~= nil then
        Clock(now)
    end
    return CCT.Maid.Send(false)
end

local function PushEdit()
    return CCT.Maid.Send(true)
end

local function ExtractItemID(text)
    local fromLink = text:match("item:(%d+)")
    if fromLink then
        return tonumber(fromLink)
    end
    local numeric = tonumber(text)
    if numeric then
        return numeric
    end
    if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local ok, maybe = pcall(C_Item.GetItemInfoInstant, text)
        if ok and tonumber(maybe) then
            return tonumber(maybe)
        end
    end
    return nil
end

local function ResolveName(itemID, fallback)
    if itemID and C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, name = pcall(C_Item.GetItemInfo, itemID)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return fallback
end

local function StripLink(text)
    local bracket = text:match("%[(.-)%]")
    if bracket and bracket ~= "" then
        return bracket
    end
    return text
end

local function NormalizeItem(text)
    if type(text) ~= "string" then
        return nil, nil
    end
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return nil, nil
    end
    local itemID = ExtractItemID(trimmed)
    local fallback = StripLink(trimmed)
    local name = ResolveName(itemID, fallback)
    if type(name) ~= "string" or name == "" then
        return nil, nil
    end
    return itemID, name
end

local function SameItem(existing, itemID, name)
    if type(existing) ~= "table" then
        return false
    end
    if existing.itemID and itemID and existing.itemID == itemID then
        return true
    end
    local have = existing.displayName or existing.name
    if type(have) == "string" and type(name) == "string" and have:lower() == name:lower() then
        return true
    end
    return false
end

function CCT.Maid.AddItem(text)
    if not Enabled() then
        return false, "disabled"
    end
    local itemID, name = NormalizeItem(text)
    if name == nil then
        return false, "item"
    end
    local store = Store()
    if store == nil then
        return false, "store"
    end
    for i = 1, #store.items do
        if SameItem(store.items[i], itemID, name) then
            return false, "duplicate"
        end
    end
    if #store.items >= ITEM_CAP then
        return false, "full"
    end
    store.items[#store.items + 1] = { itemID = itemID, displayName = name }
    PushEdit()
    return true
end

function CCT.Maid.RemoveItem(index)
    if not Enabled() then
        return false
    end
    local store = Store()
    index = tonumber(index)
    if store == nil or index == nil or store.items[index] == nil then
        return false
    end
    table.remove(store.items, index)
    PushEdit()
    return true
end

function CCT.Maid.AddInstruction(text)
    if not Enabled() then
        return false, "disabled"
    end
    local cleaned = CCT.Maid.ClampInstruction(text)
    if cleaned == "" then
        return false, "text"
    end
    local store = Store()
    if store == nil then
        return false, "store"
    end
    for i = 1, #store.instructions do
        if type(store.instructions[i]) == "string" and store.instructions[i]:lower() == cleaned:lower() then
            return false, "duplicate"
        end
    end
    if #store.instructions >= TEXT_CAP then
        return false, "full"
    end
    store.instructions[#store.instructions + 1] = cleaned
    PushEdit()
    return true
end

function CCT.Maid.RemoveInstruction(index)
    if not Enabled() then
        return false
    end
    local store = Store()
    index = tonumber(index)
    if store == nil or index == nil or store.instructions[index] == nil then
        return false
    end
    table.remove(store.instructions, index)
    PushEdit()
    return true
end

local function Ordered(map, expected)
    local list = {}
    for i = 1, expected do
        list[i] = map[i]
    end
    return list
end

local function Filled(map, expected)
    for i = 1, expected do
        if map[i] == nil then
            return false
        end
    end
    return true
end

local function UpdateFrame()
    if type(CreateFrame) ~= "function" or UIParent == nil then
        return
    end
    if frame == nil then
        frame = CreateFrame("Frame", "CatgirlMaidTaskFrame", UIParent)
        frame:SetSize(320, 240)
        frame:SetPoint("CENTER", 380, 0)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        if frame.RegisterForDrag then
            frame:RegisterForDrag("LeftButton")
        end
        frame:SetScript("OnDragStart", function(self)
            if self.StartMoving then
                self:StartMoving()
            end
        end)
        frame:SetScript("OnDragStop", function(self)
            if self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end
        end)
        frameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frameItems = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame:Hide()
    end
    local shown = CCT.State and CCT.State.Maid and CCT.State.Maid() or nil
    local texts = type(shown) == "table" and shown.instructions or {}
    local items = type(shown) == "table" and shown.items or {}
    local lines = { "Instructions:" }
    if #texts == 0 then
        lines[#lines + 1] = "None."
    end
    for i = 1, #texts do
        lines[#lines + 1] = tostring(i) .. ". " .. texts[i]
    end
    local itemLines = { "Owner inventory:" }
    if #items == 0 then
        itemLines[#itemLines + 1] = "No maid tasks synced yet."
    end
    for i = 1, #items do
        local item = items[i]
        itemLines[#itemLines + 1] = string.format("%s: %d", item.name or "Unknown item", tonumber(item.count) or 0)
    end
    if frameText and frameText.SetText then
        frameText:SetText(table.concat(lines, "\n"))
    end
    if frameItems and frameItems.SetText then
        frameItems:SetText(table.concat(itemLines, "\n"))
    end
    if #texts == 0 and #items == 0 then
        frame:Hide()
    else
        frame:Show()
    end
end

local function ApplyBucket(bucket)
    local items = Ordered(bucket.items, bucket.itemsExpected)
    local instructions = Ordered(bucket.texts, bucket.textsExpected)
    local key = ContentKey(items, instructions)
    local freshId = tostring(bucket.id) ~= tostring(appliedId)
    local freshBody = key ~= appliedKey
    appliedId = tostring(bucket.id)
    appliedKey = key
    local wrote = false
    if CCT.State and type(CCT.State.SetMaid) == "function" then
        wrote = CCT.State.SetMaid({
            id = bucket.id,
            items = items,
            instructions = instructions,
        }) and true or false
    end
    if wrote and freshId and freshBody and CCT.State and type(CCT.State.AddCounter) == "function" then
        CCT.State.AddCounter("tasks", 1)
    end
    UpdateFrame()
    return true
end

local function Bucket(id)
    id = tostring(id)
    if incoming == nil or incoming.id ~= id then
        incoming = {
            id = id,
            itemsExpected = nil,
            textsExpected = nil,
            items = {},
            texts = {},
            sawItems = false,
            sawTexts = false,
        }
    end
    return incoming
end

local function Ready(bucket)
    if not bucket.sawItems or not bucket.sawTexts then
        return false
    end
    if bucket.itemsExpected == nil or bucket.textsExpected == nil then
        return false
    end
    return Filled(bucket.items, bucket.itemsExpected) and Filled(bucket.texts, bucket.textsExpected)
end

function CCT.Maid.Accept(fields)
    if type(fields) ~= "table" or fields.id == nil or fields.id == "" then
        return { ok = false, reason = "later", op = fields and fields.op, cid = fields and fields.cid }
    end
    if not Enabled() then
        return { ok = false, reason = "disabled", op = "maid", cid = fields.cid, id = tostring(fields.id) }
    end
    local bucket = Bucket(fields.id)
    local op = tostring(fields.op or "")
    if op == "maid" then
        local count = tonumber(fields.count) or 0
        if count < 0 then
            count = 0
        end
        if fields.role == "texts" then
            bucket.textsExpected = count
            bucket.sawTexts = true
        else
            bucket.itemsExpected = count
            bucket.sawItems = true
        end
    elseif op == "maiditem" then
        local idx = tonumber(fields.idx)
        if idx ~= nil and idx >= 1 then
            bucket.items[idx] = {
                itemID = tonumber(fields.item),
                name = Decode(fields.name),
                count = tonumber(fields.n) or 0,
            }
        end
    elseif op == "maidtext" then
        local idx = tonumber(fields.idx)
        if idx ~= nil and idx >= 1 then
            bucket.texts[idx] = Decode(fields.text)
        end
    end
    if Ready(bucket) then
        ApplyBucket(bucket)
        incoming = nil
        return { ok = true, op = "maid", cid = fields.cid, id = tostring(bucket.id) }
    end
    return { ok = false, reason = "wait", op = op, cid = fields.cid, held = true, id = tostring(fields.id) }
end

function CCT.Maid.OnAck(sender, parsed)
    if type(parsed) ~= "table" or type(parsed.fields) ~= "table" then
        return false
    end
    local fields = parsed.fields
    if tostring(fields.op) ~= "maid" or tostring(fields.ok) ~= "1" then
        return false
    end
    local slot = pending[tostring(fields.id)]
    if slot == nil or slot.counted then
        return false
    end
    if sender ~= nil and slot.kitten ~= nil and CCT.SameName and not CCT.SameName(sender, slot.kitten) then
        return false
    end
    slot.ack = true
    return TryCount(slot)
end

function CCT.Maid.Reset()
    pending = {}
    blocked = {}
    incoming = nil
    appliedId = nil
    appliedKey = nil
    sentKey = nil
    sentId = nil
    lastSendAt = 0
    failure = nil
    updateSeq = 0
    planHook = nil
    clock = nil
end

local function Later(fields)
    return { ok = false, reason = "later", op = fields and fields.op, cid = fields and fields.cid }
end

local function Handler(_, fields)
    if type(fields) ~= "table" or fields.id == nil or fields.id == "" then
        return Later(fields)
    end
    return CCT.Maid.Accept(fields)
end

if CCT.Commands and type(CCT.Commands.Register) == "function" then
    CCT.Commands.Register("maid", Handler)
    CCT.Commands.Register("maiditem", Handler)
    CCT.Commands.Register("maidtext", Handler)
end

if CCT.Net and type(CCT.Net.On) == "function" then
    CCT.Net.On("ack", function(sender, parsed)
        CCT.Maid.OnAck(sender, parsed)
    end)
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(2, function()
                CCT.Maid.Send(true)
            end)
        end
    end)
end

if C_Timer and type(C_Timer.NewTicker) == "function" then
    C_Timer.NewTicker(60, function()
        CCT.Maid.Tick()
    end)
end
