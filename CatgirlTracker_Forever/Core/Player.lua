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

local function RealmSuffix(name)
    if type(name) ~= "string" then
        return nil
    end
    local suffix = name:match("^[^%-]+%-(.+)$")
    if suffix == nil or suffix == "" then
        return nil
    end
    return suffix
end

function CCT.Player.Refresh()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    if type(name) ~= "string" or name == "" then
        local unit = UnitName and UnitName("player") or nil
        if type(unit) ~= "string" or unit == "" then
            return false
        end
        name = unit
        realm = nil
    end

    local short = CCT.ShortName(name)
    if short == nil then
        return false
    end
    if type(realm) ~= "string" or realm == "" then
        realm = RealmSuffix(name)
    end

    local guid = nil
    if UnitGUID then
        local raw = UnitGUID("player")
        if type(raw) == "string" and raw ~= "" then
            guid = raw
        end
    end

    CCT.Player.name = name
    CCT.Player.realm = realm
    CCT.Player.short = short
    CCT.Player.guid = guid
    CCT.Player.ready = true

    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
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
