-- The only caller of C_GuildInfo.GuildRoster / GuildRoster.
-- Readers use the cache. They do not request the roster.

local ADDON_NAME, CCT = ...

CCT.Roster = {}

local COOLDOWN = 10
local members = {}
local byShort = {}
local assigned = nil
local lastRequestAt = 0

local function HasText(value)
    return type(value) == "string" and value:find("%S") ~= nil
end

-- publicNote and officerNote are GetGuildRosterInfo returns 7 and 8.
-- A non-empty officer note is the note this client can obey. An empty officer
-- note does not hide owner= on the public note.
function CCT.Roster.OwnerFromNotes(publicNote, officerNote)
    local source = nil
    if HasText(officerNote) then
        source = officerNote
    elseif HasText(publicNote) then
        source = publicNote
    end
    if source == nil then
        return nil
    end
    local token = source:match("owner=([^,%s]+)")
    if token == nil then
        return nil
    end
    return CCT.ShortName(token)
end

local function ReportOwner(previous)
    local now = CCT.Roster.GetOwnerShort()
    if CCT.SameName(previous, now) then
        return
    end
    CCT.Debug("owner", 0, string.format("Owner note is now %s.", now or "empty"))
end

local function ResolveAssigned()
    assigned = nil
    local me = CCT.Player.short
    if type(me) ~= "string" or me == "" then
        return
    end
    local first = nil
    local extras = {}
    for i = 1, #members do
        local row = members[i]
        if row.ownerShort and CCT.SameName(row.ownerShort, me) then
            if first == nil then
                first = row
            else
                extras[#extras + 1] = row.short or row.fullName or "?"
            end
        end
    end
    assigned = first
    if first ~= nil and #extras > 0 then
        CCT.Debug(
            "assigned-kitten",
            5,
            string.format(
                "Assigned kitten collision: kept %s, also %s.",
                first.short or first.fullName or "?",
                table.concat(extras, ", ")
            )
        )
    end
end

function CCT.Roster.Clear()
    local previous = CCT.Roster.GetOwnerShort()
    members = {}
    byShort = {}
    assigned = nil
    ReportOwner(previous)
end

function CCT.Roster.Rebuild()
    local previous = CCT.Roster.GetOwnerShort()
    if IsInGuild and not IsInGuild() then
        members = {}
        byShort = {}
        assigned = nil
        ReportOwner(previous)
        return
    end

    local count = 0
    if GetNumGuildMembers then
        count = GetNumGuildMembers() or 0
    end
    local nextMembers = {}
    local nextBy = {}
    for i = 1, count do
        local name, _, _, _, _, _, publicNote, officerNote, isOnline = GetGuildRosterInfo(i)
        if type(name) == "string" and name ~= "" then
            local short = CCT.ShortName(name)
            local online = nil
            if isOnline == true or isOnline == false then
                online = isOnline
            end
            local row = {
                index = i,
                fullName = name,
                short = short,
                online = online,
                publicNote = type(publicNote) == "string" and publicNote or "",
                officerNote = type(officerNote) == "string" and officerNote or "",
                ownerShort = CCT.Roster.OwnerFromNotes(publicNote, officerNote),
            }
            nextMembers[#nextMembers + 1] = row
            if short ~= nil then
                nextBy[short:lower()] = row
            end
        end
    end
    members = nextMembers
    byShort = nextBy
    ResolveAssigned()
    ReportOwner(previous)
end

function CCT.Roster.Request()
    if IsInGuild and not IsInGuild() then
        CCT.Roster.Clear()
        return false
    end
    local now = CCT.UnixNow()
    if now > 0 and lastRequestAt > 0 and (now - lastRequestAt) < COOLDOWN then
        return false
    end
    lastRequestAt = now
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
    return true
end

function CCT.Roster.GetSelf()
    if CCT.Player.short == nil then
        return nil
    end
    return CCT.Roster.GetMember(CCT.Player.short)
end

function CCT.Roster.GetMember(short)
    local key = CCT.ShortName(short)
    if key == nil then
        return nil
    end
    return byShort[key:lower()]
end

function CCT.Roster.GetOwnerShort()
    local row = CCT.Roster.GetSelf()
    if row == nil then
        return nil
    end
    return row.ownerShort
end

function CCT.Roster.GetAssignedKitten()
    return assigned
end

function CCT.Roster.IsMasterOnline()
    local settings = CCT.db and CCT.db.settings
    local master = settings and settings.masterName
    local row = CCT.Roster.GetMember(master)
    return row ~= nil and row.online == true
end

function CCT.Roster.OnEvent(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CCT.Roster.Request()
    elseif event == "GUILD_ROSTER_UPDATE" then
        CCT.Roster.Rebuild()
    elseif event == "PLAYER_GUILD_UPDATE" then
        if IsInGuild and not IsInGuild() then
            CCT.Roster.Clear()
        else
            CCT.Roster.Request()
        end
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("GUILD_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_GUILD_UPDATE")
    frame:SetScript("OnEvent", CCT.Roster.OnEvent)
end
