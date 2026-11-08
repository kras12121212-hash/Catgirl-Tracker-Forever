-- Heat numbers. Decay, the flip table, toy rows, discipline rows, and
-- the control intervals stay the classic values. Activity is read from
-- CCT.State. This file does not send addon messages.

local ADDON_NAME, CCT = ...

CCT.HeatConfig = {}

local cfg = CCT.HeatConfig

cfg.decay = {
    totalSeconds = 20 * 60,
    ratio100to10 = 5,
}

cfg.updateInterval = 0.25
cfg.syncIntervalSeconds = 10
cfg.syncMinDelta = 1

cfg.bar = {
    width = 240,
    height = 18,
    texture = "Interface\\TARGETINGFRAME\\UI-StatusBar",
    font = "GameFontHighlightSmall",
    locked = false,
}

cfg.colors = {
    low = { 0.0, 0.45, 1.0 },
    mid = { 1.0, 0.35, 0.75 },
    high = { 1.0, 0.0, 0.0 },
}

cfg.orgasm = {
    texture = "Textures/orgasm.toc",
    flashDuration = 0.6,
    alpha = 0.9,
}

-- A negative delta whose magnitude is within the highest matching
-- threshold flips to the same positive magnitude. Past that limit it stays negative.
cfg.submissivenessHeatFlip = {
    [10] = -1,
    [20] = -2,
    [30] = -3,
    [40] = -5,
    [50] = -7,
    [60] = -10,
    [70] = -11,
    [80] = -13,
    [90] = -15,
    [100] = -20,
}

cfg.toys = {
    dildo = {
        label = "Dildo",
        base = { intervalSeconds = 90, heat = 1 },
        vibe = {
            { intervalSeconds = 30, heat = 1 },
            { intervalSeconds = 25, heat = 2 },
            { intervalSeconds = 20, heat = 3 },
            { intervalSeconds = 15, heat = 4 },
            { intervalSeconds = 10, heat = 5 },
        },
        shock = { -5, -10, -15 },
    },
    inflatable_butplug = {
        label = "Inflatable Butplug",
        base = { intervalSeconds = 90, heat = 1 },
        inflate = {
            { intervalSeconds = 60, heat = 1 },
            { intervalSeconds = 50, heat = 2 },
            { intervalSeconds = 40, heat = 3 },
            { intervalSeconds = 30, heat = 4 },
            { intervalSeconds = 20, heat = 5 },
        },
    },
    inflatable_dildo = {
        label = "Inflatable Dildo",
        base = { intervalSeconds = 90, heat = 1 },
        inflate = {
            { intervalSeconds = 60, heat = 1 },
            { intervalSeconds = 50, heat = 2 },
            { intervalSeconds = 40, heat = 3 },
            { intervalSeconds = 30, heat = 4 },
            { intervalSeconds = 20, heat = 5 },
        },
    },
    small_butplug = {
        label = "Small Butplug",
        base = { intervalSeconds = 90, heat = 1 },
    },
    large_butplug = {
        label = "Large Butplug",
        base = { intervalSeconds = 90, heat = 1 },
    },
    taill_butplug = {
        label = "Taill Butplug",
        base = { intervalSeconds = 90, heat = 1 },
    },
    vibes_pussy = {
        label = "Vibes Pussy",
        base = { intervalSeconds = 90, heat = 1 },
        vibe = {
            { intervalSeconds = 30, heat = 1 },
            { intervalSeconds = 25, heat = 2 },
            { intervalSeconds = 20, heat = 3 },
            { intervalSeconds = 15, heat = 4 },
            { intervalSeconds = 10, heat = 5 },
        },
    },
    vibes_nipples = {
        label = "Vibes Nipples",
        base = { intervalSeconds = 90, heat = 1 },
        vibe = {
            { intervalSeconds = 30, heat = 1 },
            { intervalSeconds = 25, heat = 2 },
            { intervalSeconds = 20, heat = 3 },
            { intervalSeconds = 15, heat = 4 },
            { intervalSeconds = 10, heat = 5 },
        },
    },
    vibes_ears = {
        label = "Vibes Ears",
        base = { intervalSeconds = 90, heat = 1 },
        vibe = {
            { intervalSeconds = 30, heat = 1 },
            { intervalSeconds = 25, heat = 2 },
            { intervalSeconds = 20, heat = 3 },
            { intervalSeconds = 15, heat = 4 },
            { intervalSeconds = 10, heat = 5 },
        },
        shock = { -5, -10, -15 },
    },
    nipple_piercings = {
        label = "Nipple Piercings",
        base = { intervalSeconds = 90, heat = 1 },
        vibe = {
            { intervalSeconds = 30, heat = 1 },
            { intervalSeconds = 25, heat = 2 },
            { intervalSeconds = 20, heat = 3 },
            { intervalSeconds = 15, heat = 4 },
            { intervalSeconds = 10, heat = 5 },
        },
        shock = { -5, -10, -15 },
    },
    ear_piercings = {
        label = "Ear Piercings",
        base = { intervalSeconds = 90, heat = 1 },
        vibe = {
            { intervalSeconds = 30, heat = 1 },
            { intervalSeconds = 25, heat = 2 },
            { intervalSeconds = 20, heat = 3 },
            { intervalSeconds = 15, heat = 4 },
            { intervalSeconds = 10, heat = 5 },
        },
        shock = { -5, -10, -15 },
    },
    pussy_lipps_piercings = {
        label = "Pussy Lipps Piercings",
        base = { intervalSeconds = 90, heat = 1 },
        vibe = {
            { intervalSeconds = 30, heat = 1 },
            { intervalSeconds = 25, heat = 2 },
            { intervalSeconds = 20, heat = 3 },
            { intervalSeconds = 15, heat = 4 },
            { intervalSeconds = 10, heat = 5 },
        },
        shock = { -5, -10, -15 },
    },
}

cfg.discipline = {
    spank_hand = { label = "Spank Hand", heat = { 1, 2, 3, 4, 5 } },
    pinch = { label = "Pinch", heat = { 1, 2, 3 } },
    vibrating_wand = { label = "Vibrating Wand", heat = { 1, 2, 3 } },
    shock_wand = { label = "Shock Wand", heat = { 1, 2, 3, 4, 5 } },
    crop = { label = "Crop", heat = { 1, 2, 3 } },
    paddle = { label = "Paddle", heat = { 1, 2, 3 } },
    heart_crop = { label = "Heart Crop", heat = { 1, 2, 3 } },
    whip = { label = "Whip", heat = { 1, 2, 3 } },
}

local function AddOneToy(list, id, toy)
    if toy.base then
        list[#list + 1] = {
            key = "toy_" .. id .. "_base",
            label = toy.label or ("Toy " .. id),
            intervalSeconds = toy.base.intervalSeconds,
            heat = toy.base.heat,
        }
    end
    if type(toy.vibe) == "table" then
        for stage, def in ipairs(toy.vibe) do
            list[#list + 1] = {
                key = "toy_" .. id .. "_vibe_" .. stage,
                label = (toy.label or ("Toy " .. id)) .. " Vibe " .. stage,
                intervalSeconds = def.intervalSeconds,
                heat = def.heat,
            }
        end
    end
    if type(toy.inflate) == "table" then
        for stage, def in ipairs(toy.inflate) do
            list[#list + 1] = {
                key = "toy_" .. id .. "_inflate_" .. stage,
                label = (toy.label or ("Toy " .. id)) .. " Inflate " .. stage,
                intervalSeconds = def.intervalSeconds,
                heat = def.heat,
            }
        end
    end
end

local function AddToyControls(list)
    local toys = cfg.toys
    if type(toys) ~= "table" then
        return
    end
    local order = CCT.State and CCT.State.Toys
    if type(order) == "table" then
        for i = 1, #order do
            local id = order[i].id
            if type(toys[id]) == "table" then
                AddOneToy(list, id, toys[id])
            end
        end
        return
    end
    for id, toy in pairs(toys) do
        if type(toy) == "table" then
            AddOneToy(list, id, toy)
        end
    end
end

cfg.controls = {
    { key = "heels_maid", label = "Maid Heels", intervalSeconds = 60, heat = 2 },
    { key = "heels_high", label = "High Heels", intervalSeconds = 60, heat = 3 },
    { key = "heels_ballet", label = "Ballet Boots", intervalSeconds = 60, heat = 4 },
    { key = "mittens", label = "Paw Mittens", intervalSeconds = 90, heat = 1 },
    { key = "gag", label = "Gag", intervalSeconds = 90, heat = 1 },
    { key = "blindfold", label = "Blindfold", intervalSeconds = 90, heat = 1 },
    { key = "earmuffs_kitten", label = "Kitten Earmuffs", intervalSeconds = 120, heat = 1 },
    { key = "earmuffs_heavy", label = "Heavy Earmuffs", intervalSeconds = 120, heat = 2 },
    { key = "bell", label = "Bell", intervalSeconds = 180, heat = 1 },
    { key = "tailbell", label = "Tail Bell", intervalSeconds = 180, heat = 1 },
    { key = "leash", label = "Leash", intervalSeconds = 60, heat = 2 },
}

AddToyControls(cfg.controls)
