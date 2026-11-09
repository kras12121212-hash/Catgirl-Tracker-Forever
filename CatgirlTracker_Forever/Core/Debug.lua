-- /cctdebug and /cctmodule. Hot paths call CCT.Debug, not print.

local ADDON_NAME, CCT = ...

local rate = {}

local function Clock()
    if GetTime then
        return GetTime()
    end
    return CCT.UnixNow()
end

function CCT.DebugEnabled()
    local db = CCT.db
    return db ~= nil and db.settings ~= nil and db.settings.debug == true
end

function CCT.SetDebug(enabled)
    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    if CCT.db == nil or CCT.db.settings == nil then
        return false
    end
    CCT.db.settings.debug = enabled and true or false
    if not CCT.db.settings.debug then
        rate = {}
    end
    return true
end

function CCT.ToggleDebug()
    local enabled = not CCT.DebugEnabled()
    CCT.SetDebug(enabled)
    if print then
        print("|cffffcc00[CatgirlTracker Debug]:|r " .. (enabled and "ON" or "OFF"))
    end
    return enabled
end

function CCT.Debug(key, interval, text)
    if not CCT.DebugEnabled() or text == nil then
        return
    end
    if not key or key == "" then
        if print then
            print(text)
        end
        return
    end

    local now = Clock()
    local gap = tonumber(interval) or 0
    local state = rate[key]
    if not state then
        state = { lastAt = 0, suppressed = 0 }
        rate[key] = state
    end

    if state.lastAt == 0 or gap <= 0 or (now - state.lastAt) >= gap then
        if print then
            if state.suppressed > 0 then
                print(string.format("%s |cff888888(+%d similar)|r", tostring(text), state.suppressed))
            else
                print(text)
            end
        end
        state.lastAt = now
        state.suppressed = 0
        return
    end

    state.suppressed = state.suppressed + 1
end

CCT.Module = {}

function CCT.Module.Known(name)
    if type(name) ~= "string" then
        return nil
    end
    for i = 1, #CCT.MODULES do
        local spec = CCT.MODULES[i]
        if spec.name == name then
            return spec
        end
    end
    return nil
end

function CCT.Module.Enabled(name)
    local spec = CCT.Module.Known(name)
    if not spec then
        return false
    end
    local modules = CCT.db and CCT.db.settings and CCT.db.settings.modules
    if type(modules) ~= "table" or modules[name] == nil then
        return spec.default == true
    end
    return modules[name] == true
end

function CCT.Module.Set(name, enabled)
    if not CCT.Module.Known(name) then
        return false
    end
    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    if CCT.db == nil or CCT.db.settings == nil then
        return false
    end
    if type(CCT.db.settings.modules) ~= "table" then
        CCT.db.settings.modules = {}
    end
    CCT.db.settings.modules[name] = enabled and true or false
    CCT.db.settings.modules.LayerInvite = nil
    if name == "KittenMapShow" and CCT.Map and type(CCT.Map.Refresh) == "function" then
        CCT.Map.Refresh()
    end
    return true
end

function CCT.ModuleCommand(msg)
    if CCT.Saved and CCT.Saved.Init then
        CCT.Saved.Init()
    end
    local text = ""
    if type(msg) == "string" then
        text = msg:match("^%s*(.-)%s*$") or ""
    end
    if text == "" then
        if print then
            print("CatgirlTracker modules:")
            for i = 1, #CCT.MODULES do
                local name = CCT.MODULES[i].name
                local flag = CCT.Module.Enabled(name) and "on" or "off"
                print("  " .. name .. ": " .. flag)
            end
        end
        return
    end

    local name = text:match("^(%S+)")
    if not CCT.Module.Known(name) then
        if print then
            print("Unknown module. /cctmodule lists the five modules that ship.")
        end
        return
    end
    local enabled = not CCT.Module.Enabled(name)
    CCT.Module.Set(name, enabled)
    if print then
        print(name .. ": " .. (enabled and "on" or "off"))
    end
end

SLASH_CCTDEBUG1 = "/cctdebug"
SLASH_CCTMODULE1 = "/cctmodule"
if SlashCmdList then
    SlashCmdList.CCTDEBUG = function()
        CCT.ToggleDebug()
    end
    SlashCmdList.CCTMODULE = function(msg)
        CCT.ModuleCommand(msg)
    end
end
