-- NyaChat controls for the settings tab.
-- Options stay on db.chars[short].nya. Enabled stays default off.
-- There is no second chat wrapper. KittyLayerGroup layer chat is not here.

local ADDON_NAME, CCT = ...

CCT.NyaOptions = {}

local OPTIONS = {
    { key = "enabled", label = "Enable Nya" },
    { key = "appendNya", label = "Append nya" },
    { key = "cuteTilde", label = "Tildes" },
    { key = "asciiEmotes", label = "Ascii faces" },
    { key = "nyaSprinkle", label = "Sprinkle nya" },
    { key = "uwuSpeak", label = "UwU" },
    { key = "kittyWords", label = "Kitty words" },
    { key = "stutter", label = "Stutter" },
    { key = "sparklePunct", label = "Sparkle" },
    { key = "actionEmotes", label = "Action emotes" },
    { key = "softLowercase", label = "Lowercase" },
    { key = "trailingFace", label = "Trailing face" },
}

function CCT.NyaOptions.Rows()
    local state = CCT.Nya and CCT.Nya.GetSettings and CCT.Nya.GetSettings() or {}
    local rows = {}
    for i = 1, #OPTIONS do
        local opt = OPTIONS[i]
        rows[i] = { key = opt.key, label = opt.label, value = state[opt.key] }
    end
    rows[#rows + 1] = { key = "chance", label = "Chance", value = state.chance or 50 }
    return rows
end

function CCT.NyaOptions.Click(key)
    if CCT.Nya == nil or type(CCT.Nya.GetSettings) ~= "function" or type(CCT.Nya.SetOption) ~= "function" then
        return false
    end
    local state = CCT.Nya.GetSettings()
    if type(state[key]) ~= "boolean" then
        return false
    end
    return CCT.Nya.SetOption(key, not state[key])
end

function CCT.NyaOptions.SetChance(value)
    if CCT.Nya == nil or type(CCT.Nya.SetOption) ~= "function" then
        return false
    end
    return CCT.Nya.SetOption("chance", value)
end

local function Focused(box)
    if type(box) ~= "table" or type(box.HasFocus) ~= "function" then
        return false
    end
    return box:HasFocus() == true
end

local function Checked(box)
    if type(box) ~= "table" or type(box.GetChecked) ~= "function" then
        return false
    end
    local value = box:GetChecked()
    return value == true or value == 1
end

function CCT.NyaOptions.Paint(block)
    if type(block) ~= "table" then
        return
    end
    local rows = CCT.NyaOptions.Rows()
    for i = 1, #rows do
        local row = rows[i]
        local check = block.checks and block.checks[row.key]
        if check and check.SetChecked then
            check:SetChecked(row.value == true)
        end
        if row.key == "chance" and block.chance and block.chance.SetText and not Focused(block.chance) then
            block.chance:SetText(tostring(row.value or 50))
        end
    end
    if block.preview and block.preview.SetText and CCT.Nya and type(CCT.Nya.Preview) == "function" then
        block.preview:SetText("Preview: " .. tostring(CCT.Nya.Preview()))
    end
end

function CCT.NyaOptions.Attach(parent)
    if parent == nil or type(CreateFrame) ~= "function" then
        return nil
    end
    local block = CreateFrame("Frame", nil, parent)
    local y = -4
    local title = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if title.SetPoint then
        title:SetPoint("TOPLEFT", 8, y)
    end
    if title.SetText then
        title:SetText("NyaChat")
    end
    block.title = title
    y = y - 18
    local note = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if note.SetPoint then
        note:SetPoint("TOPLEFT", 8, y)
    end
    if note.SetWidth then
        note:SetWidth(320)
    end
    if note.SetJustifyH then
        note:SetJustifyH("LEFT")
    end
    if note.SetWordWrap then
        note:SetWordWrap(true)
    end
    if note.SetText then
        note:SetText("Rewrites chat you type: say, yell, party, raid, guild, officer, whisper, emote, and channel. Off until you enable it.")
    end
    y = y - 36
    block.checks = {}
    local rows = CCT.NyaOptions.Rows()
    for i = 1, #rows do
        local row = rows[i]
        if row.key == "chance" then
            local label = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            if label.SetPoint then
                label:SetPoint("TOPLEFT", 8, y - 2)
            end
            if label.SetText then
                label:SetText("Chance (10-100)")
            end
            local box = CreateFrame("EditBox", nil, block, "InputBoxTemplate")
            if box.SetAutoFocus then
                box:SetAutoFocus(false)
            end
            if box.SetSize then
                box:SetSize(48, 20)
            end
            if box.SetPoint then
                box:SetPoint("LEFT", label, "RIGHT", 8, 0)
            end
            if box.SetFont then
                box:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
            end
            if box.SetText then
                box:SetText(tostring(row.value or 50))
            end
            if box.ClearFocus then
                box:ClearFocus()
            end
            box:SetScript("OnEnterPressed", function(self)
                local text = self.GetText and self:GetText() or nil
                CCT.NyaOptions.SetChance(text)
                if self.ClearFocus then
                    self:ClearFocus()
                end
                CCT.NyaOptions.Paint(block)
            end)
            box:SetScript("OnEscapePressed", function(self)
                if self.SetAutoFocus then
                    self:SetAutoFocus(false)
                end
                if self.ClearFocus then
                    self:ClearFocus()
                end
                CCT.NyaOptions.Paint(block)
            end)
            if box.HookScript then
                box:HookScript("OnHide", function(self)
                    if self.ClearFocus then
                        self:ClearFocus()
                    end
                end)
            end
            block.chance = box
            y = y - 26
        else
            local key = row.key
            local check = CreateFrame("CheckButton", nil, block, "UICheckButtonTemplate")
            if check.SetSize then
                check:SetSize(24, 24)
            end
            if check.SetPoint then
                check:SetPoint("TOPLEFT", 4, y)
            end
            if check.SetChecked then
                check:SetChecked(row.value == true)
            end
            local label = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            if label.SetPoint then
                label:SetPoint("LEFT", check, "RIGHT", 2, 0)
            end
            if label.SetText then
                label:SetText(row.label)
            end
            check:SetScript("OnClick", function(self)
                if CCT.Nya and type(CCT.Nya.SetOption) == "function" then
                    CCT.Nya.SetOption(key, Checked(self))
                end
                CCT.NyaOptions.Paint(block)
            end)
            block.checks[key] = check
            y = y - 22
        end
    end
    local preview = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if preview.SetPoint then
        preview:SetPoint("TOPLEFT", 8, y)
    end
    if preview.SetWidth then
        preview:SetWidth(320)
    end
    if preview.SetJustifyH then
        preview:SetJustifyH("LEFT")
    end
    if preview.SetWordWrap then
        preview:SetWordWrap(true)
    end
    block.preview = preview
    y = y - 48
    block.cctHeight = -y + 8
    if block.SetSize then
        block:SetSize(340, block.cctHeight)
    end
    CCT.NyaOptions.Paint(block)
    parent.nya = block
    return block
end
