-- One outgoing chat path. Installed once on ADDON_LOADED.
-- Feature files call CCT.Chat.Send. They do not replace the chat globals.
-- opts.raw skips gag and Nya. Addon lines pass raw. Only typed chat is rewritten.
-- A secret is sent unchanged and is not concatenated.
-- Battle.net whispers use the same rewrite. The old NyaChat file hooked them on its own.

local ADDON_NAME, CCT = ...

CCT.Chat = {}

local busy = false
local installed = false
local originalSend = nil
local originalCSend = nil

local function CallOriginal(msg, chatType, language, target)
    if type(originalCSend) == "function" then
        return originalCSend(msg, chatType, language, target)
    end
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        return C_ChatInfo.SendChatMessage(msg, chatType, language, target)
    end
    if type(originalSend) == "function" then
        return originalSend(msg, chatType, language, target)
    end
    if type(SendChatMessage) == "function" then
        return SendChatMessage(msg, chatType, language, target)
    end
end

local function Restore(ok, ...)
    busy = false
    if not ok then
        error((...), 0)
    end
    return ...
end

local function Rewrite(msg, chatType)
    local secret = type(issecretvalue) == "function" and issecretvalue(msg)
    if secret then
        return msg, false
    end
    if CCT.Gag and CCT.Gag.ApplyOutgoing then
        local updated, blocked = CCT.Gag.ApplyOutgoing(msg, chatType)
        if blocked then
            return nil, true
        end
        if updated ~= nil then
            msg = updated
        end
    end
    if CCT.Nya and CCT.Nya.Enabled and CCT.Nya.Enabled() and CCT.Nya.ApplyOutgoing then
        local updated = CCT.Nya.ApplyOutgoing(msg, chatType)
        if updated ~= nil then
            msg = updated
        end
    end
    return msg, false
end

function CCT.Chat.Send(msg, chatType, language, target, opts)
    if type(chatType) == "string" and chatType:upper() == "WHISPER" and type(CCT.LinkName) == "function" then
        target = CCT.LinkName(target) or target
    end
    if busy then
        return CallOriginal(msg, chatType, language, target)
    end

    busy = true
    local raw = type(opts) == "table" and opts.raw == true
    if not raw then
        local updated, blocked = Rewrite(msg, chatType)
        if blocked then
            busy = false
            return
        end
        if updated ~= nil then
            msg = updated
        end
    end

    return Restore(pcall(CallOriginal, msg, chatType, language, target))
end

function CCT.Chat.Install()
    if installed then
        return
    end
    installed = true

    if type(SendChatMessage) == "function" then
        originalSend = SendChatMessage
        SendChatMessage = function(msg, chatType, language, target)
            return CCT.Chat.Send(msg, chatType, language, target)
        end
    end

    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        originalCSend = C_ChatInfo.SendChatMessage
        C_ChatInfo.SendChatMessage = function(msg, chatType, language, target)
            return CCT.Chat.Send(msg, chatType, language, target)
        end
    end

    if type(BNSendWhisper) == "function" then
        local originalBN = BNSendWhisper
        BNSendWhisper = function(presenceID, msg)
            if busy then
                return originalBN(presenceID, msg)
            end
            busy = true
            local updated, blocked = Rewrite(msg, "WHISPER")
            if blocked then
                busy = false
                return
            end
            if updated ~= nil then
                msg = updated
            end
            return Restore(pcall(originalBN, presenceID, msg))
        end
    end
end

function CCT.Chat.OnEvent(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        CCT.Chat.Install()
    end
end

if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", CCT.Chat.OnEvent)
end
