-- Nya checkboxes for the control center settings block.
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

function CCT.NyaOptions.Attach(parent)
    if parent == nil or type(CreateFrame) ~= "function" then
        return nil
    end
    local block = CreateFrame("Frame", nil, parent)
    if block.SetSize then
        block:SetSize(280, 28 + (#OPTIONS * 18))
    end
    if block.SetPoint then
        block:SetPoint("BOTTOMLEFT", 12, 12)
    end
    local title = block:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if title and title.SetText then
        title:SetText("Settings")
    end
    local rows = CCT.NyaOptions.Rows()
    for i = 1, #rows do
        local row = rows[i]
        if row.key == "chance" then
            local box = CreateFrame("EditBox", nil, block)
            if box.SetAutoFocus then
                box:SetAutoFocus(false)
            end
            if box.ClearFocus then
                box:ClearFocus()
            end
            if box.SetSize then
                box:SetSize(48, 18)
            end
            if box.SetText then
                box:SetText(tostring(row.value or 50))
            end
            box:SetScript("OnEnterPressed", function(self)
                local text = self.GetText and self:GetText() or nil
                CCT.NyaOptions.SetChance(text)
                if self.ClearFocus then
                    self:ClearFocus()
                end
            end)
            box:SetScript("OnEscapePressed", function(self)
                if self.SetAutoFocus then
                    self:SetAutoFocus(false)
                end
                if self.ClearFocus then
                    self:ClearFocus()
                end
            end)
            if box.HookScript then
                box:HookScript("OnHide", function(self)
                    if self.ClearFocus then
                        self:ClearFocus()
                    end
                end)
            end
            block.chance = box
        else
            local check = CreateFrame("CheckButton", nil, block)
            if check.SetChecked then
                check:SetChecked(row.value == true)
            end
            local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            if label and label.SetText then
                label:SetText(row.label)
            end
            check:SetScript("OnClick", function()
                CCT.NyaOptions.Click(row.key)
            end)
        end
    end
    parent.nya = block
    return block
end
