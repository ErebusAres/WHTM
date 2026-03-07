local _, ns = ...
local WHTM = ns.WHTM

function WHTM:InitializeSharing()
end

local function safe(v, fallback)
    if v == nil or v == "" then
        return fallback or "n/a"
    end
    return tostring(v)
end

function WHTM:BuildShareLine(event)
    local clock = self:FormatClockTime(event.timestamp)
    local spell = safe(event.spellName, event.subevent)
    local amount
    if event.amount then
        local effective = event.effectiveAmount or event.amount
        amount = tostring(effective)
        if event.overheal then amount = amount .. " /OH" .. event.overheal end
        if event.overkill then amount = amount .. " /OK" .. event.overkill end
        if event.resisted then amount = amount .. " /R" .. event.resisted end
    else
        if event.eventGroup == "aura" then
            amount = event.eventText or event.auraState or "aura"
        else
            amount = event.missType and ("miss:" .. event.missType) or "-"
        end
    end

    local extras = {}
    if event.overkill then table.insert(extras, "OK:" .. event.overkill) end
    if event.overheal then table.insert(extras, "OH:" .. event.overheal) end
    if event.resisted then table.insert(extras, "R:" .. event.resisted) end
    if event.blocked then table.insert(extras, "B:" .. event.blocked) end
    if event.absorbed then table.insert(extras, "A:" .. event.absorbed) end
    if event.critical then table.insert(extras, "CRIT") end
    if event.coordsText then table.insert(extras, event.coordsText) end

    local where = event.subzone and event.subzone ~= "" and event.subzone or safe(event.zone, "?")
    local rhs = #extras > 0 and (" [" .. table.concat(extras, " ") .. "]") or ""

    return ("[%s] %s %s -> %s | %s | %s @ %s%s"):format(
        clock,
        safe(event.eventGroup, "evt"),
        safe(event.sourceName, "?"),
        safe(event.destName, "?"),
        spell,
        amount,
        where,
        rhs
    )
end

function WHTM:ShareEvent(event, channel, whisperTarget)
    if not event then
        self:Printf("No event selected.")
        return
    end

    local text = self:BuildShareLine(event)
    -- WoW chat parser treats "|" as an escape prefix; literal pipes must be doubled.
    text = tostring(text or ""):gsub("|", "||")
    channel = channel or self.db.profile.shareChannel or "PARTY"

    if channel == "WHISPER" then
        local target = whisperTarget or self.db.profile.whisperTarget or ""
        target = target:match("^%s*(.-)%s*$")
        if target == "" then
            self:Printf("Whisper target is empty.")
            return
        end
        SendChatMessage(text, "WHISPER", nil, target)
        return
    end

    SendChatMessage(text, channel)
end
