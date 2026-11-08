-- Player name is read from events, never at file scope.
-- A nil name is not written into the database.

local ADDON_NAME, CCT = ...

CCT.Player = {
    name = nil,
    realm = nil,
    short = nil,
    guid = nil,
    ready = false,
}

-- The second return is the surname on Forever. It is not a realm.
-- A name that already contains both parts wins over a given name alone.
local function Pull(fn, ...)
    if type(fn) ~= "function" then
        return nil, nil
    end
    local ok, given, surname = pcall(fn, ...)
    if not ok or type(given) ~= "string" or given == "" then
        return nil, nil
    end
    if type(surname) ~= "string" or surname == "" then
        surname = nil
    end
    return given, surname
end

local function NameScore(given, surname)
    if surname ~= nil then
        return 2
    end
    if given:find(" ", 1, true) or given:find("-", 1, true) then
        return 2
    end
    return 1
end

local function Consider(bestGiven, bestSurname, bestScore, given, surname)
    if given == nil then
        return bestGiven, bestSurname, bestScore
    end
    local score = NameScore(given, surname)
    if score > bestScore then
        return given, surname, score
    end
    return bestGiven, bestSurname, bestScore
end

local function ReadIdentity()
    local given, surname, score = nil, nil, 0
    local nextGiven, nextSurname = Pull(UnitName, "player")
    given, surname, score = Consider(given, surname, score, nextGiven, nextSurname)
    nextGiven, nextSurname = Pull(UnitFullName, "player")
    given, surname, score = Consider(given, surname, score, nextGiven, nextSurname)
    nextGiven, nextSurname = Pull(GetUnitName, "player", true)
    given, surname, score = Consider(given, surname, score, nextGiven, nextSurname)
    nextGiven, nextSurname = Pull(UnitNameUnmodified, "player")
    given, surname = Consider(given, surname, score, nextGiven, nextSurname)
    return given, surname
end

-- The old build stored this character under the given name and kept the
-- surname in memory as a realm. That realm was never saved. Move the row
-- once the full name is known. A row that already uses the full name stays.
local function MoveTruncatedRow(short)
    local chars = CCT.db and CCT.db.chars
    if type(chars) ~= "table" or type(short) ~= "string" or chars[short] ~= nil then
        return
    end
    local first = short:match("^(%S+)")
    if first ~= nil and first ~= short and type(chars[first]) == "table" then
        chars[short] = chars[first]
        chars[first] = nil
        return
    end
    local linked = (short:gsub(" ", "-"))
    if linked ~= short and type(chars[linked]) == "table" then
        chars[short] = chars[linked]
        chars[linked] = nil
    end
end

function CCT.Player.Refresh()
    local given, surname = ReadIdentity()
    local short = CCT.ShortName(given, surname)
    if short == nil then
        return false
    end

    local guid = nil
    if type(UnitGUID) == "function" then
        local ok, raw = pcall(UnitGUID, "player")
        if ok and type(raw) == "string" and raw ~= "" then
            guid = raw
        end
    end

    CCT.Player.name = short
    CCT.Player.realm = nil
    CCT.Player.short = short
    CCT.Player.guid = guid
    CCT.Player.ready = true

    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    MoveTruncatedRow(short)
    if CCT.State and CCT.State.Bind then
        CCT.State.Bind(short)
    end
    return true
end

function CCT.Player.OnEvent(_, event, arg1)
    if event == "UNIT_NAME_UPDATE" then
        if arg1 ~= "player" then
            return
        end
    elseif event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ENTERING_WORLD" then
        return
    end
    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    CCT.Player.Refresh()
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    frame:SetScript("OnEvent", CCT.Player.OnEvent)
end
