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

function CCT.ShortName(name)
    if type(name) ~= "string" then
        return nil
    end
    local short = name:match("^[^%-]+")
    if short == nil or short == "" then
        return nil
    end
    return short
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
