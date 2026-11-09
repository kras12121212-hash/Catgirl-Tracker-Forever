-- Account-wide CatgirlTrackerDB. One table. No per-character saved variables.
-- Nothing here reads the classic databases.

local ADDON_NAME, CCT = ...

CCT.Saved = {}

local function DefaultModules()
    local modules = {}
    for i = 1, #CCT.MODULES do
        local spec = CCT.MODULES[i]
        modules[spec.name] = spec.default
    end
    return modules
end

function CCT.Saved.Empty()
    return {
        settings = {
            debug = false,
            flavorAnnouncements = true,
            masterName = nil,
            modules = DefaultModules(),
        },
        chars = {},
        owner = {
            kitten = {},
            weeks = {},
        },
        master = {
            kittens = {},
        },
    }
end

function CCT.Saved.Repair(db)
    if type(db.settings) ~= "table" then
        db.settings = {}
    end
    local settings = db.settings
    if settings.debug == nil then
        settings.debug = false
    end
    if settings.flavorAnnouncements == nil then
        settings.flavorAnnouncements = true
    end
    if settings.masterName == "" then
        settings.masterName = nil
    elseif type(settings.masterName) == "string" then
        settings.masterName = CCT.ShortName(settings.masterName)
    end
    if type(settings.modules) ~= "table" then
        settings.modules = {}
    end
    settings.modules.LayerInvite = nil
    for i = 1, #CCT.MODULES do
        local spec = CCT.MODULES[i]
        if settings.modules[spec.name] == nil then
            settings.modules[spec.name] = spec.default
        end
    end
    if type(db.chars) ~= "table" then
        db.chars = {}
    end
    if type(db.owner) ~= "table" then
        db.owner = {}
    end
    if type(db.owner.kitten) ~= "table" then
        db.owner.kitten = {}
    end
    if type(db.owner.weeks) ~= "table" then
        db.owner.weeks = {}
    end
    if type(db.master) ~= "table" then
        db.master = {}
    end
    if type(db.master.kittens) ~= "table" then
        db.master.kittens = {}
    end
    -- "Mina-Dawn" and "Mina Dawn" are one character. Week ids stay as they are.
    local function RekeyNames(map)
        if type(map) ~= "table" then
            return
        end
        local pending = {}
        for key in pairs(map) do
            if type(key) == "string" and key:match("^%d%d%d%d%-W%d%d$") == nil then
                local full = CCT.ShortName(key)
                if type(full) == "string" and full ~= key then
                    pending[#pending + 1] = key
                    pending[#pending + 1] = full
                end
            end
        end
        for i = 1, #pending, 2 do
            local key = pending[i]
            local full = pending[i + 1]
            if map[full] == nil then
                map[full] = map[key]
                map[key] = nil
            end
        end
    end
    RekeyNames(db.chars)
    RekeyNames(db.owner.kitten)
    RekeyNames(db.owner.weeks)
    RekeyNames(db.owner.closed)
    RekeyNames(db.master.kittens)
    return db
end

function CCT.Saved.Init()
    if type(CatgirlTrackerDB) ~= "table" then
        CatgirlTrackerDB = CCT.Saved.Empty()
    else
        CCT.Saved.Repair(CatgirlTrackerDB)
    end
    CCT.db = CatgirlTrackerDB
    return CCT.db
end

local function NewLife()
    return {
        denied = 0,
        total = 0,
        orgasms = {},
        denials = {},
    }
end

function CCT.Saved.NewChar()
    local state
    if CCT.State and CCT.State.New then
        state = CCT.State.New()
    else
        state = { lastUnixUpdate = 0 }
    end
    return {
        state = state,
        trail = {},
        pictures = {},
        life = NewLife(),
        archive = nil,
        droppedWeek = nil,
        nya = { enabled = false },
    }
end

local function RepairChar(char)
    if type(char.trail) ~= "table" then
        char.trail = {}
    end
    if type(char.pictures) ~= "table" then
        char.pictures = {}
    end
    if type(char.life) ~= "table" then
        char.life = NewLife()
    else
        if type(char.life.denied) ~= "number" then
            char.life.denied = 0
        end
        if type(char.life.orgasms) ~= "table" then
            char.life.orgasms = {}
        end
        if type(char.life.denials) ~= "table" then
            char.life.denials = {}
        end
        local seen = #char.life.orgasms
        local total = tonumber(char.life.total)
        if total == nil or total < seen then
            char.life.total = seen
        else
            char.life.total = math.floor(total)
        end
    end
    if type(char.nya) ~= "table" then
        char.nya = { enabled = false }
    elseif char.nya.enabled == nil then
        char.nya.enabled = false
    end
    return char
end

function CCT.Saved.EnsureChar(short)
    if type(short) ~= "string" or short == "" then
        return nil
    end
    local db = CCT.Saved.Init()
    local char = db.chars[short]
    if type(char) ~= "table" then
        char = CCT.Saved.NewChar()
        db.chars[short] = char
        return char
    end
    return RepairChar(char)
end

function CCT.Saved.OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        CCT.Saved.Init()
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", CCT.Saved.OnEvent)
end
