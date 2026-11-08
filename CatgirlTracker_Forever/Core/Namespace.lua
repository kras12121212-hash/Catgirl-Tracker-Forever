-- First file. Later files only add fields to this table.
-- Sounds is capitalised on purpose: a case-sensitive client does not see "sounds".

local ADDON_NAME, CCT = ...

CCT.VERSION = "2.0.0"
CCT.PREFIX = "CatgirlTracker"
CCT.MEDIA = "Interface\\AddOns\\CatgirlTracker_Forever\\"
CCT.ADDON = ADDON_NAME

-- The five module flags this addon ships. LayerInvite is not one of them.
CCT.MODULES = {
    { name = "HeadPetTracker", default = true },
    { name = "InnSlackerTracker", default = true },
    { name = "PetTracker", default = true },
    { name = "MaidTasks", default = true },
    { name = "KittenMapShow", default = false },
}

-- Forever has no realms. A character is "First Surname".
-- "Anna Brightvale", "Anna-Brightvale", and UnitName's ("Anna", "Brightvale")
-- are one person. The text after a hyphen is the surname, not a realm.
-- "Anna" is not "Anna Brightvale". `surname` is that second unit-name return.

local function NormalizeName(text)
    if type(text) ~= "string" or text:find("[%c]") then
        return nil
    end
    text = text:gsub("%s*%-%s*", " ")
    text = text:gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$")
    if text == nil or text == "" then
        return nil
    end
    return text
end

local function AlreadyHasSurname(full, surname)
    local lower = full:lower()
    local tail = surname:lower()
    if lower == tail then
        return true
    end
    if #lower > #tail and lower:sub(-#tail) == tail and lower:sub(#lower - #tail, #lower - #tail) == " " then
        return true
    end
    return false
end

function CCT.ShortName(name, surname)
    local full = NormalizeName(name)
    if full == nil then
        return nil
    end
    if surname == nil then
        return full
    end
    local last = NormalizeName(surname)
    if last == nil or AlreadyHasSurname(full, last) then
        return full
    end
    return NormalizeName(full .. " " .. last)
end

-- Whisper, party invite, and /target want First-Surname. Stored names keep a space.
function CCT.LinkName(name)
    local full = CCT.ShortName(name)
    if full == nil then
        return nil
    end
    return (full:gsub(" ", "-"))
end

function CCT.SameName(a, b)
    if a == nil and b == nil then
        return true
    end
    local left = CCT.ShortName(a)
    local right = CCT.ShortName(b)
    if left == nil or right == nil then
        return false
    end
    return left:lower() == right:lower()
end

function CCT.UnixNow()
    if time then
        return time()
    end
    return 0
end
