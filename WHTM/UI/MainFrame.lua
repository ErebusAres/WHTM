local _, ns = ...
local WHTM = ns.WHTM
local band = bit.band

local ROW_HEIGHT = 18
local DEFAULT_VISIBLE_ROWS = 20
local SHARE_CHANNELS = { "SAY", "PARTY", "RAID", "GUILD", "WHISPER" }
local TABLE_COLUMN_KEYS = { "time", "icon", "source", "target", "ability", "type", "amount", "mitigation", "where" }
local TABLE_COLUMN_LABELS = { "Time", "Icon", "Source", "Target", "Ability", "Type", "Detail", "Total", "Where" }
local TABLE_COLUMN_DEFAULT_WIDTHS = {
    time = 72,
    icon = 38,
    source = 116,
    target = 116,
    ability = 156,
    type = 62,
    amount = 72,
    mitigation = 150,
    where = 150,
}

local groupLabel = {
    incoming = "Incoming",
    outgoing = "Outgoing",
    internal = "Internal",
    damage = "Damage",
    heal = "Heal",
    aura = "Aura",
    aura_gained = "Aura gained",
    aura_lost = "Aura lost",
    aura_other = "Aura other",
    miss = "Miss",
    death = "Death",
    control = "Control",
    resource = "Resource",
}

local groupColor = {
    damage = { 1.00, 0.35, 0.35 },
    heal = { 0.45, 1.00, 0.45 },
    aura = { 1.00, 0.88, 0.35 },
    miss = { 0.85, 0.85, 0.85 },
    death = { 1.00, 0.15, 0.15 },
    control = { 0.65, 0.78, 1.00 },
    resource = { 0.75, 0.55, 1.00 },
}

local tierColor = {
    junk = { 0.62, 0.62, 0.62 },      -- grey
    normal = { 0.95, 0.95, 0.95 },    -- white
    elite = { 1.00, 0.30, 0.30 },     -- danger red
    boss = { 1.00, 0.50, 0.00 },      -- legendary orange
}

local spellColor = {
    damage = { 1.00, 0.30, 0.30 },
    heal = { 0.30, 1.00, 0.30 },
    overheal = { 0.00, 0.70, 0.20 },
    res = { 1.00, 0.95, 0.35 },
    control = { 0.35, 0.70, 1.00 },
    fear = { 0.70, 0.35, 1.00 },
    overkill = { 0.50, 0.02, 0.02 },
    resist = { 0.68, 0.10, 0.10 },
    default = { 0.90, 0.90, 0.90 },
}

local uiTone = {
    time = { 0.72, 0.72, 0.72 },
    where = { 0.74, 0.86, 1.00 },
}

local controlSpellNames = {
    ["Fear"] = true,
    ["Psychic Scream"] = true,
    ["Howl of Terror"] = true,
    ["Intimidating Shout"] = true,
}

local function hexFromRGB(r, g, b)
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function colorWrap(text, rgb)
    return ("%s%s|r"):format(hexFromRGB(rgb[1], rgb[2], rgb[3]), text)
end

local function raidIconTag(index)
    if not index or index < 1 or index > 8 then
        return nil
    end
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t"):format(index)
end

local function preferredRaidIcon(event, playerGUID)
    if not event then
        return nil
    end
    if playerGUID and event.destGUID == playerGUID then
        return event.sourceRaidIcon or event.destRaidIcon
    end
    if playerGUID and event.sourceGUID == playerGUID then
        return event.destRaidIcon or event.sourceRaidIcon
    end
    return event.sourceRaidIcon or event.destRaidIcon
end

local function short(v)
    if not v or v == "" then
        return "-"
    end
    return v
end

local function auraActionLabel(event)
    if not event or event.eventGroup ~= "aura" then
        return nil
    end
    if event.subevent == "SPELL_AURA_APPLIED" then
        return "Applied"
    end
    if event.subevent == "SPELL_AURA_REMOVED" then
        return "Lost"
    end
    if event.subevent == "SPELL_AURA_REFRESH" then
        return "Refreshed"
    end
    if event.subevent == "SPELL_AURA_APPLIED_DOSE" then
        return "Stacked"
    end
    if event.subevent == "SPELL_AURA_REMOVED_DOSE" then
        return "Unstacked"
    end
    if event.subevent == "SPELL_AURA_BROKEN" or event.subevent == "SPELL_AURA_BROKEN_SPELL" then
        return "Broken"
    end
    return "Changed"
end

local function eventTypeLabel(event)
    if event and event.eventGroup == "aura" then
        return "Aura"
    end
    return short(groupLabel[event.eventGroup])
end

local function buildMitigationText(event)
    local parts = {}
    if event.resisted then table.insert(parts, "R:" .. event.resisted) end
    if event.blocked then table.insert(parts, "B:" .. event.blocked) end
    if event.absorbed then table.insert(parts, "A:" .. event.absorbed) end
    if event.overkill then table.insert(parts, "OK:" .. event.overkill) end
    if event.overheal then table.insert(parts, "OH:" .. event.overheal) end
    if event.critical then table.insert(parts, "CRIT") end
    if event.crushing then table.insert(parts, "CRUSH") end
    if event.glancing then table.insert(parts, "GLANCE") end
    if event.missType then table.insert(parts, event.missType) end
    return #parts > 0 and table.concat(parts, " ") or "-"
end

local function controlActionLabel(event)
    if not event or event.eventGroup ~= "control" then
        return nil
    end
    if event.subevent == "SPELL_DISPEL" then
        return "Dispelled"
    end
    if event.subevent == "SPELL_STOLEN" then
        return "Devoured"
    end
    if event.subevent == "SPELL_INTERRUPT" then
        return "Interrupted"
    end
    return nil
end

local function controlDetailLabel(event)
    if not event or event.eventGroup ~= "control" then
        return nil
    end
    if event.extraSpellName and event.extraSpellName ~= "" then
        return event.extraSpellName
    end
    if event.auraType == "BUFF" then
        return "Buff"
    end
    if event.auraType == "DEBUFF" then
        return "Debuff"
    end
    return nil
end

local function formatAmountText(event, useColor)
    if not event.amount then
        if event.eventGroup == "aura" then
            return auraActionLabel(event) or "Aura"
        end
        if event.eventGroup == "control" then
            return controlActionLabel(event) or event.missType or "-"
        end
        return event.missType or "-"
    end

    if event.eventGroup == "heal" then
        local effective = tostring(event.effectiveAmount or event.amount)
        if useColor then
            effective = colorWrap(effective, spellColor.heal)
        end
        if event.overheal then
            local over = "(" .. tostring(event.overheal) .. ")"
            if useColor then
                over = colorWrap(over, spellColor.overheal)
            end
            return effective .. " " .. over
        end
        return effective
    end

    local effective = event.effectiveAmount or event.amount
    local parts = { tostring(effective) }
    if event.overheal then parts[#parts + 1] = "OH" .. event.overheal end
    if event.overkill then parts[#parts + 1] = "OK" .. event.overkill end
    if event.resisted then parts[#parts + 1] = "R" .. event.resisted end
    if event.blocked then parts[#parts + 1] = "B" .. event.blocked end
    if event.absorbed then parts[#parts + 1] = "A" .. event.absorbed end

    if #parts == 1 then
        return parts[1]
    end
    return parts[1] .. " /" .. table.concat(parts, " /", 2)
end

local function formatBreakdownText(event, useColor)
    if not event.amount then
        if event.eventGroup == "aura" then
            if event.auraType == "BUFF" then
                return "Buff"
            end
            if event.auraType == "DEBUFF" then
                return "Debuff"
            end
            return "Aura"
        end
        if event.eventGroup == "control" then
            return controlDetailLabel(event) or "-"
        end
        return event.missType or "-"
    end

    local base
    if event.eventGroup == "heal" then
        base = "HEAL"
    elseif event.eventGroup == "damage" then
        base = "DMG"
    else
        base = "AMT"
    end

    local function tag(text, color)
        if useColor then
            return colorWrap(text, color)
        end
        return text
    end

    local tokens = {}
    if event.overheal then tokens[#tokens + 1] = tag("OH" .. event.overheal, spellColor.overheal) end
    if event.resisted then tokens[#tokens + 1] = tag("R" .. event.resisted, spellColor.resist) end
    if event.overkill then tokens[#tokens + 1] = tag("OK" .. event.overkill, spellColor.overkill) end
    if event.blocked then tokens[#tokens + 1] = tag("B" .. event.blocked, { 0.80, 0.74, 0.46 }) end
    if event.absorbed then tokens[#tokens + 1] = tag("A" .. event.absorbed, { 0.60, 0.74, 0.98 }) end

    if #tokens == 0 then
        return base
    end
    return ("%s (%s)"):format(base, table.concat(tokens, " "))
end

local function formatTotalText(event)
    if not event.amount then
        if event.eventGroup == "aura" then
            return auraActionLabel(event) or "-"
        end
        if event.eventGroup == "control" then
            return controlActionLabel(event) or event.missType or "-"
        end
        return event.missType or "-"
    end
    return tostring(event.rawAmount or event.amount)
end

local function formatDetailValueText(event, useColor)
    if not event.amount then
        if event.eventGroup == "aura" then
            if event.auraType == "BUFF" then
                return "Buff"
            end
            if event.auraType == "DEBUFF" then
                return "Debuff"
            end
            return "Aura"
        end
        if event.eventGroup == "control" then
            return controlDetailLabel(event) or "-"
        end
        return event.missType or "-"
    end

    local function tag(text, color)
        if useColor then
            return colorWrap(text, color)
        end
        return text
    end

    local effective = tostring(event.effectiveAmount or event.amount)
    local mods = {}
    if event.eventGroup == "heal" and useColor then
        effective = tag(effective, spellColor.heal)
    end
    if event.overheal then
        if event.eventGroup == "heal" then
            mods[#mods + 1] = tag("(" .. tostring(event.overheal) .. ")", spellColor.overheal)
        else
            mods[#mods + 1] = tag(tostring(event.overheal), spellColor.overheal)
        end
    end
    if event.resisted then mods[#mods + 1] = tag("R " .. event.resisted, spellColor.resist) end
    if event.overkill then mods[#mods + 1] = tag("OK " .. event.overkill, spellColor.overkill) end
    if event.blocked then mods[#mods + 1] = tag("B " .. event.blocked, { 0.80, 0.74, 0.46 }) end
    if event.absorbed then mods[#mods + 1] = tag("A " .. event.absorbed, { 0.60, 0.74, 0.98 }) end

    if #mods == 0 then
        return effective
    end
    if event.eventGroup == "heal" and event.overheal and #mods == 1 then
        return effective .. " " .. mods[1]
    end
    return ("%s (%s)"):format(effective, table.concat(mods, " "))
end

local function eventTint(group, rowIndex)
    local c = groupColor[group] or { 0.8, 0.8, 0.8 }
    local a = (rowIndex % 2 == 0) and 0.17 or 0.12
    return c[1] * 0.25, c[2] * 0.25, c[3] * 0.25, a
end

local function sourceColorForEvent(event)
    if event.sourceTier and tierColor[event.sourceTier] then
        return tierColor[event.sourceTier]
    end
    if event.sourceFlags and band(event.sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER or 0) > 0
        and event.sourceClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[event.sourceClass] then
        local c = RAID_CLASS_COLORS[event.sourceClass]
        return { c.r, c.g, c.b }
    end
    return { 0.93, 0.93, 0.93 }
end

local function targetColorForEvent(event)
    if event.destTier and tierColor[event.destTier] then
        return tierColor[event.destTier]
    end
    if event.destFlags and band(event.destFlags, COMBATLOG_OBJECT_TYPE_PLAYER or 0) > 0
        and event.destClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[event.destClass] then
        local c = RAID_CLASS_COLORS[event.destClass]
        return { c.r, c.g, c.b }
    end
    return { 0.93, 0.93, 0.93 }
end

local function spellColorForEvent(event)
    local name = event.spellName or ""
    if event.subevent == "SPELL_RESURRECT" then
        return spellColor.res
    end
    if event.eventGroup == "heal" then
        if event.overheal then
            return spellColor.overheal
        end
        return spellColor.heal
    end
    if event.eventGroup == "damage" then
        if event.overkill or event.resisted then
            return spellColor.overkill
        end
        return spellColor.damage
    end
    if event.eventGroup == "control" then
        if controlSpellNames[name] or name:find("Fear") then
            return spellColor.fear
        end
        return spellColor.control
    end
    if event.eventGroup == "aura" then
        return { 1.00, 0.88, 0.35 }
    end
    if event.resisted then
        return spellColor.resist
    end
    return spellColor.default
end

local function statusColorForEvent(event)
    if not event then
        return spellColor.default
    end

    if event.eventGroup == "heal" then
        return spellColor.heal
    end
    if event.eventGroup == "damage" then
        return spellColor.damage
    end
    if event.eventGroup == "aura" then
        if event.subevent == "SPELL_AURA_APPLIED" then
            return { 0.45, 1.00, 0.45 }
        end
        if event.subevent == "SPELL_AURA_REMOVED" then
            return { 1.00, 0.35, 0.35 }
        end
        if event.subevent == "SPELL_AURA_REFRESH" then
            return { 1.00, 0.90, 0.40 }
        end
        if event.subevent == "SPELL_AURA_APPLIED_DOSE" then
            return { 0.45, 0.85, 1.00 }
        end
        if event.subevent == "SPELL_AURA_REMOVED_DOSE" then
            return { 1.00, 0.70, 0.30 }
        end
        if event.subevent == "SPELL_AURA_BROKEN" or event.subevent == "SPELL_AURA_BROKEN_SPELL" then
            return { 1.00, 0.35, 0.35 }
        end
    end
    if event.eventGroup == "control" then
        if event.subevent == "SPELL_DISPEL" then
            return { 1.00, 0.95, 0.45 }
        end
        if event.subevent == "SPELL_STOLEN" then
            return { 0.80, 0.55, 1.00 }
        end
        if event.subevent == "SPELL_INTERRUPT" then
            return { 0.45, 0.85, 1.00 }
        end
    end
    return groupColor[event.eventGroup] or spellColor.default
end

local function detailLine(label, value)
    return ("|cffffc94d%s|r %s"):format(label, short(value))
end

local function playerMarker(name)
    return "< " .. short(name) .. " >"
end

local function getPlayerClassRGB()
    local _, classFile = UnitClass("player")
    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r, c.g, c.b
    end
    return 1.0, 0.84, 0.0
end

local function countLines(text)
    if not text or text == "" then
        return 1
    end
    local _, n = text:gsub("\n", "\n")
    return n + 1
end

function WHTM:InitializeUI()
    self.sortKey = self.sortKey or "time"
    if self.sortAsc == nil then
        self.sortAsc = false
    end

    local frame = CreateFrame("Frame", "WHTM_MainFrame", UIParent)
    frame:SetWidth(self.db.profile.frame.width or 920)
    frame:SetHeight(self.db.profile.frame.height or 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", self.db.profile.frame.x or 0, self.db.profile.frame.y or 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(selfFrame)
        selfFrame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local _, _, _, x, y = selfFrame:GetPoint(1)
        WHTM.db.profile.frame.x = x or 0
        WHTM.db.profile.frame.y = y or 0
    end)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    frame:Hide()
    self.mainFrame = frame

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
    title:SetText("What Happened To Me")

    local profiler = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    profiler:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -14)
    profiler:SetJustifyH("RIGHT")
    profiler:SetText("")
    frame.profilerText = profiler

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetTexture("Interface\\Buttons\\WHITE8x8")
    accent:SetVertexColor(1.0, 0.84, 0.0, 0.45)
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -34)
    accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -34)
    accent:SetHeight(1)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

    local modeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    modeBtn:SetWidth(112)
    modeBtn:SetHeight(22)
    modeBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -42)
    modeBtn:SetScript("OnClick", function()
        local nextMode = (WHTM.db.profile.mode == "chat") and "table" or "chat"
        WHTM:SetDisplayMode(nextMode)
    end)
    frame.modeButton = modeBtn

    local filterBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    filterBtn:SetWidth(84)
    filterBtn:SetHeight(22)
    filterBtn:SetPoint("LEFT", modeBtn, "RIGHT", 6, 0)
    filterBtn:SetText("Filters")
    filterBtn:SetScript("OnClick", function(selfButton)
        WHTM:ShowFilterMenu(selfButton)
    end)
    self.filterMenuFrame = CreateFrame("Frame", "WHTM_FilterMenuFrame", UIParent, "UIDropDownMenuTemplate")

    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetWidth(70)
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("LEFT", filterBtn, "RIGHT", 6, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        WHTM:ClearEvents()
    end)

    local pauseBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    pauseBtn:SetWidth(84)
    pauseBtn:SetHeight(22)
    pauseBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
    pauseBtn:SetScript("OnClick", function()
        WHTM:SetCapturePaused(not WHTM.db.profile.paused)
    end)
    frame.pauseButton = pauseBtn

    local channelDrop = CreateFrame("Frame", "WHTM_ChannelDropDown", frame, "UIDropDownMenuTemplate")
    channelDrop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -170, -42)
    UIDropDownMenu_SetWidth(channelDrop, 82)
    UIDropDownMenu_Initialize(channelDrop, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, channel in ipairs(SHARE_CHANNELS) do
            info.text = channel
            info.func = function()
                WHTM.db.profile.shareChannel = channel
                UIDropDownMenu_SetSelectedValue(channelDrop, channel)
                WHTM:RefreshShareWidgets()
            end
            info.value = channel
            info.checked = (WHTM.db.profile.shareChannel == channel)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetSelectedValue(channelDrop, self.db.profile.shareChannel)
    frame.channelDrop = channelDrop

    local whisperEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    whisperEdit:SetWidth(78)
    whisperEdit:SetHeight(20)
    whisperEdit:SetAutoFocus(false)
    whisperEdit:SetPoint("LEFT", channelDrop, "RIGHT", -14, 0)
    whisperEdit:SetTextInsets(6, 6, 0, 0)
    whisperEdit:SetScript("OnTextChanged", function(selfBox)
        WHTM.db.profile.whisperTarget = selfBox:GetText() or ""
    end)
    frame.whisperEdit = whisperEdit

    local shareBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    shareBtn:SetWidth(72)
    shareBtn:SetHeight(22)
    shareBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -42)
    shareBtn:SetText("Share")
    shareBtn:SetScript("OnClick", function()
        WHTM:ShareEvent(WHTM.selectedEvent, WHTM.db.profile.shareChannel, WHTM.db.profile.whisperTarget)
    end)
    frame.shareButton = shareBtn

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)
    frame.content = content
    frame.visibleRows = DEFAULT_VISIBLE_ROWS

    local header = CreateFrame("Frame", nil, content)
    header:SetHeight(18)
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    frame.header = header

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    headerBg:SetVertexColor(0.26, 0.2, 0.06, 0.5)
    headerBg:SetAllPoints(header)

    local cols = TABLE_COLUMN_LABELS
    frame.columnKeys = TABLE_COLUMN_KEYS
    header.cols = {}
    header.buttons = {}
    local x = 6
    for i, text in ipairs(cols) do
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", header, "TOPLEFT", x, -2)
        fs:SetWidth(self:GetTableColumnWidth(frame.columnKeys[i]))
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        header.cols[i] = fs

        local btn = CreateFrame("Button", nil, header)
        btn:SetPoint("TOPLEFT", header, "TOPLEFT", x, 0)
        btn:SetWidth(self:GetTableColumnWidth(frame.columnKeys[i]))
        btn:SetHeight(18)
        btn:SetScript("OnClick", function()
            WHTM:SetSort(frame.columnKeys[i])
        end)
        header.buttons[i] = btn
        x = x + self:GetTableColumnWidth(frame.columnKeys[i])
    end

    local scrollFrame = CreateFrame("ScrollFrame", "WHTM_ScrollFrame", content, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -20)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 88)
    scrollFrame:SetScript("OnVerticalScroll", function(selfScroll, offset)
        FauxScrollFrame_OnVerticalScroll(selfScroll, offset, ROW_HEIGHT, function()
            WHTM:RefreshRows()
        end)
    end)
    frame.scrollFrame = scrollFrame

    local details = CreateFrame("Frame", nil, content)
    details:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    details:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -2, 0)
    details:SetHeight(80)
    details:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    details:SetBackdropColor(0.04, 0.04, 0.04, 0.96)
    details:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.6)
    frame.detailsPanel = details
    frame.detailsMinHeight = 80
    frame.detailsMaxHeight = 180
    frame.detailsPadding = 8

    local detailsTitle = details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailsTitle:SetPoint("TOPLEFT", details, "TOPLEFT", 10, -8)
    detailsTitle:SetPoint("TOPRIGHT", details, "TOPRIGHT", -10, -8)
    detailsTitle:SetJustifyH("LEFT")
    detailsTitle:SetText("Selected Event")
    details.title = detailsTitle

    local detailsBody = details:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailsBody:SetPoint("TOPLEFT", detailsTitle, "BOTTOMLEFT", 0, -4)
    detailsBody:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", -10, 8)
    detailsBody:SetJustifyH("LEFT")
    detailsBody:SetJustifyV("TOP")
    detailsBody:SetNonSpaceWrap(true)
    detailsBody:SetText("Click any row to view details.")
    details.body = detailsBody

    frame.rows = {}
    for i = 1, DEFAULT_VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, content)
        row:SetID(i)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -20 - ((i - 1) * ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -20 - ((i - 1) * ROW_HEIGHT))
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:GetHighlightTexture():SetBlendMode("ADD")

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.bg:SetAllPoints(row)
        row.bg:SetVertexColor(0.08, 0.08, 0.08, (i % 2 == 0) and 0.25 or 0.18)

        row.selected = row:CreateTexture(nil, "ARTWORK")
        row.selected:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.selected:SetAllPoints(row)
        row.selected:SetVertexColor(1.0, 0.82, 0.0, 0.18)
        row.selected:Hide()

        row.chatText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.chatText:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.chatText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.chatText:SetJustifyH("LEFT")

        row.cols = {}
        local colX = 6
        for c = 1, #frame.columnKeys do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", row, "LEFT", colX, 0)
            fs:SetWidth(self:GetTableColumnWidth(frame.columnKeys[c]))
            fs:SetJustifyH("LEFT")
            row.cols[c] = fs
            colX = colX + self:GetTableColumnWidth(frame.columnKeys[c])
        end

        row:SetScript("OnClick", function(selfRow)
            WHTM.selectedEvent = selfRow.event
            WHTM:RefreshRows()
        end)
        row:SetScript("OnEnter", function(selfRow)
            if not selfRow.event then
                return
            end
            WHTM:ShowEventTooltip(selfRow)
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        frame.rows[i] = row
    end

    self:RegisterMessage("WHTM_EVENTS_UPDATED", "RefreshRows")
    self:RegisterMessage("WHTM_MODE_CHANGED", "RefreshRows")
    self:RegisterMessage("WHTM_CAPTURE_STATE_CHANGED", "RefreshButtons")
    self:RegisterMessage("WHTM_PERF_UPDATED", "RefreshProfilerLine")

    self:RefreshButtons()
    self:RefreshShareWidgets()
    self:RefreshHeaderSortLabels()
    self:ApplyTableColumnLayout()
    self:RefreshProfilerLine()
    self:RefreshDetailsDrawer()
    self:RefreshRows()
end

function WHTM:ApplyPlayerNameGlow(fontString, shouldGlow)
    if not fontString then
        return
    end
    if shouldGlow and self.db.profile.playerNameGlow then
        local r, g, b = getPlayerClassRGB()
        fontString:SetShadowColor(r, g, b, 0.75)
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0.6)
        fontString:SetShadowOffset(1, -1)
    end
end

function WHTM:SetDetailsPanelHeight(height)
    if not self.mainFrame or not self.mainFrame.detailsPanel then
        return
    end

    local minH = self.mainFrame.detailsMinHeight or 80
    local maxH = self.mainFrame.detailsMaxHeight or 180
    if height < minH then
        height = minH
    elseif height > maxH then
        height = maxH
    end

    if self.mainFrame.detailsPanel:GetHeight() == height then
        return
    end

    self.mainFrame.detailsPanel:SetHeight(height)
    self.mainFrame.scrollFrame:ClearAllPoints()
    self.mainFrame.scrollFrame:SetPoint("TOPLEFT", self.mainFrame.content, "TOPLEFT", 0, -20)
    self.mainFrame.scrollFrame:SetPoint("BOTTOMRIGHT", self.mainFrame.content, "BOTTOMRIGHT", 0, height + (self.mainFrame.detailsPadding or 8))
end

function WHTM:IsTableColumnVisible(key)
    local t = self.db and self.db.profile and self.db.profile.tableColumns
    if not t or t[key] == nil then
        return true
    end
    return t[key]
end

function WHTM:GetTableColumnWidth(key)
    local t = self.db and self.db.profile and self.db.profile.tableWidths
    local width = t and t[key]
    if not width then
        width = TABLE_COLUMN_DEFAULT_WIDTHS[key] or 80
    end
    if width < 30 then
        width = 30
    end
    return width
end

function WHTM:ApplyTableColumnLayout()
    if not self.mainFrame or not self.mainFrame.header then
        return
    end

    local x = 6
    local keys = self.mainFrame.columnKeys
    for i = 1, #keys do
        local key = keys[i]
        local width = self:GetTableColumnWidth(key)
        local show = self:IsTableColumnVisible(key)
        local hcol = self.mainFrame.header.cols[i]
        local hbtn = self.mainFrame.header.buttons[i]

        hcol:ClearAllPoints()
        hbtn:ClearAllPoints()

        if show then
            hcol:SetPoint("TOPLEFT", self.mainFrame.header, "TOPLEFT", x, -2)
            hcol:SetWidth(width)
            hcol:Show()

            hbtn:SetPoint("TOPLEFT", self.mainFrame.header, "TOPLEFT", x, 0)
            hbtn:SetWidth(width)
            hbtn:SetHeight(18)
            hbtn:Show()
            x = x + width
        else
            hcol:Hide()
            hbtn:Hide()
        end
    end

    for r = 1, #self.mainFrame.rows do
        local row = self.mainFrame.rows[r]
        local colX = 6
        for i = 1, #keys do
            local key = keys[i]
            local fs = row.cols[i]
            local width = self:GetTableColumnWidth(key)
            local show = self:IsTableColumnVisible(key)
            fs:ClearAllPoints()
            if show then
                fs:SetPoint("LEFT", row, "LEFT", colX, 0)
                fs:SetWidth(width)
                colX = colX + width
            end
        end
    end
end

function WHTM:ShowFilterMenu(anchor)
    local menu = {
        {
            text = "Event Filters",
            isTitle = true,
            notCheckable = true,
        },
    }

    local function addFilter(key)
        table.insert(menu, {
            text = groupLabel[key],
            checked = self.db.profile.filters[key],
            keepShownOnClick = true,
            func = function(_, _, _, checked)
                self.db.profile.filters[key] = checked
                self:RefreshRows()
            end,
        })
    end

    addFilter("incoming")
    addFilter("outgoing")
    addFilter("internal")
    addFilter("damage")
    addFilter("heal")
    addFilter("aura")
    addFilter("aura_gained")
    addFilter("aura_lost")
    addFilter("aura_other")
    addFilter("miss")
    addFilter("death")
    addFilter("control")
    addFilter("resource")

    EasyMenu(menu, self.filterMenuFrame, anchor, 0, 0, "MENU")
end

function WHTM:RefreshButtons()
    if not self.mainFrame then
        return
    end
    self.mainFrame.modeButton:SetText("Mode: " .. (self.db.profile.mode == "chat" and "Chat" or "Table"))
    self.mainFrame.pauseButton:SetText(self.db.profile.paused and "Resume" or "Pause")
end

function WHTM:RefreshProfilerLine()
    if not self.mainFrame or not self.mainFrame.profilerText then
        return
    end
    if not self.db.profile.showProfiler then
        self.mainFrame.profilerText:Hide()
        return
    end

    local p = self:GetPerformanceSnapshot()
    if not p then
        self.mainFrame.profilerText:SetText("")
        self.mainFrame.profilerText:Show()
        return
    end

    local rows = #self:GetEvents()
    local cap = tonumber(self.db.profile.maxRows) or 0
    local text = ("EPS %d (%.1f)  UI/s %d (%.1f)  ms %.2f  Rows %d/%d  Peak %d"):format(
        p.epsNow or 0,
        p.eps5 or 0,
        p.uiNow or 0,
        p.ui5 or 0,
        p.renderAvgMs or 0,
        rows,
        cap,
        p.burstPeak or 0
    )

    self.mainFrame.profilerText:SetText(text)
    self.mainFrame.profilerText:Show()
end

function WHTM:RefreshShareWidgets()
    if not self.mainFrame then
        return
    end
    UIDropDownMenu_SetSelectedValue(self.mainFrame.channelDrop, self.db.profile.shareChannel)
    local whisperTarget = self.db.profile.whisperTarget or ""
    if self.mainFrame.whisperEdit:GetText() ~= whisperTarget then
        self.mainFrame.whisperEdit:SetText(whisperTarget)
    end
    if self.db.profile.shareChannel == "WHISPER" then
        self.mainFrame.whisperEdit:EnableMouse(true)
    else
        self.mainFrame.whisperEdit:ClearFocus()
        self.mainFrame.whisperEdit:EnableMouse(false)
    end
    local alpha = self.db.profile.shareChannel == "WHISPER" and 1 or 0.45
    self.mainFrame.whisperEdit:SetAlpha(alpha)
end

function WHTM:RefreshDetailsDrawer()
    if not self.mainFrame or not self.mainFrame.detailsPanel then
        return
    end

    local details = self.mainFrame.detailsPanel
    local event = self.selectedEvent
    if not event then
        details.title:SetText("Selected Event")
        details.title:SetTextColor(1, 0.82, 0, 1)
        details.body:SetText("Click any row to view details.")
        self:SetDetailsPanelHeight(self.mainFrame.detailsMinHeight or 80)
        return
    end

    local group = groupLabel[event.eventGroup] or "Event"
    local c = groupColor[event.eventGroup] or { 1, 1, 1 }
    details.title:SetText(("Selected: %s  (%s)"):format(group, self:FormatClockTime(event.timestamp)))
    details.title:SetTextColor(c[1], c[2], c[3])

    local where = event.coordsText and ((event.subzone ~= "" and event.subzone or event.zone) .. " " .. event.coordsText)
        or (event.subzone ~= "" and event.subzone or event.zone)

    local body = table.concat({
        detailLine("Who:", ("%s -> %s"):format(short(event.sourceName), short(event.destName))),
        detailLine("What:", event.spellName or event.subevent),
        detailLine("Type:", eventTypeLabel(event)),
        detailLine("Detail:", formatDetailValueText(event, false)),
        detailLine("Total:", formatTotalText(event)),
        detailLine("Effective:", event.effectiveAmount or event.amount or "-"),
        detailLine("Aura:", event.auraType or "-"),
        detailLine("Aura state:", event.auraState or "-"),
        detailLine("Stacks:", event.stackCount or "-"),
        detailLine("Source Tier:", event.sourceTier or "-"),
        detailLine("Target Tier:", event.destTier or "-"),
        detailLine("Mitigation:", buildMitigationText(event)),
        detailLine("Where:", where),
        detailLine("How:", event.subevent),
    }, "\n")

    details.body:SetText(body)
    local lines = countLines(body)
    local desiredHeight = 30 + (lines * 12)
    self:SetDetailsPanelHeight(desiredHeight)
end

function WHTM:SetSort(key)
    if not key then
        return
    end
    if self.sortKey == key then
        self.sortAsc = not self.sortAsc
    else
        self.sortKey = key
        self.sortAsc = (key ~= "time")
    end
    self:RefreshRows()
end

function WHTM:RefreshHeaderSortLabels()
    if not self.mainFrame or not self.mainFrame.header then
        return
    end
    local labels = TABLE_COLUMN_LABELS
    for i = 1, #labels do
        local key = self.mainFrame.columnKeys[i]
        local suffix = ""
        if key == self.sortKey then
            suffix = self.sortAsc and " ^" or " v"
        end
        self.mainFrame.header.cols[i]:SetText(labels[i] .. suffix)
    end
end

function WHTM:GetSortValue(event, key)
    if key == "time" then
        return event.timestamp or 0
    end
    if key == "icon" then
        return preferredRaidIcon(event, self.playerGUID) or 0
    end
    if key == "type" then
        return eventTypeLabel(event)
    end
    if key == "source" then
        return short(event.sourceName)
    end
    if key == "target" then
        return short(event.destName)
    end
    if key == "ability" then
        return short(event.spellName)
    end
    if key == "amount" then
        return tonumber(event.preventedAmount) or 0
    end
    if key == "mitigation" then
        return tonumber(event.rawAmount) or tonumber(event.amount) or 0
    end
    if key == "where" then
        return short((event.subzone and event.subzone ~= "" and event.subzone) or event.zone)
    end
    return 0
end

function WHTM:CompareEvents(a, b)
    local key = self.sortKey or "time"
    local asc = self.sortAsc and true or false
    local av = self:GetSortValue(a, key)
    local bv = self:GetSortValue(b, key)

    if type(av) == "string" or type(bv) == "string" then
        av, bv = tostring(av or ""), tostring(bv or "")
        if av == bv then
            return (a.timestamp or 0) > (b.timestamp or 0)
        end
        if asc then
            return av < bv
        end
        return av > bv
    end

    av, bv = tonumber(av) or 0, tonumber(bv) or 0
    if av == bv then
        return (a.timestamp or 0) > (b.timestamp or 0)
    end
    if asc then
        return av < bv
    end
    return av > bv
end

function WHTM:BuildVisibleEvents()
    local all = self:GetEvents()
    self.visibleScratch = self.visibleScratch or {}
    local out = self.visibleScratch
    wipe(out)
    for i = #all, 1, -1 do
        local event = all[i]
        if self:IsGroupEnabled(event.eventGroup)
            and self:IsDirectionEnabled(event.direction)
            and (event.eventGroup ~= "aura" or self:IsAuraStateEnabled(event.auraState)) then
            out[#out + 1] = event
        end
    end
    if #out > 1 then
        table.sort(out, function(a, b)
            return self:CompareEvents(a, b)
        end)
    end
    return out
end

function WHTM:RenderRowChat(row, event)
    local detail = formatBreakdownText(event, true)
    local total = formatTotalText(event)
    local effective = formatAmountText(event, true)
    local where = event.subzone ~= "" and event.subzone or event.zone
    local srcText = short(event.sourceName)
    local dstText = short(event.destName)
    local spellText = short(event.spellName)
    local srcColor = sourceColorForEvent(event)
    local dstColor = targetColorForEvent(event)
    local splColor = spellColorForEvent(event)
    local typeColor = groupColor[event.eventGroup] or { 0.95, 0.95, 0.95 }
    local statusColor = statusColorForEvent(event)
    local iconIdx = preferredRaidIcon(event, self.playerGUID)
    local iconText = raidIconTag(iconIdx) or ""
    if self.db.profile.playerNameGlow and event.sourceGUID == self.playerGUID then
        srcText = playerMarker(srcText)
    end
    if self.db.profile.playerNameGlow and event.destGUID == self.playerGUID then
        dstText = playerMarker(dstText)
    end

    if detail and detail ~= "-" and not detail:find("|cff", 1, true) then
        detail = colorWrap(detail, typeColor)
    end

    local line = ("[%s] %s %s -> %s %s (%s) @ %s"):format(
        colorWrap(self:FormatClockTime(event.timestamp), uiTone.time),
        colorWrap(eventTypeLabel(event), typeColor),
        (iconText ~= "" and (iconText .. " ") or "") .. colorWrap(srcText, srcColor),
        colorWrap(dstText, dstColor),
        colorWrap(spellText, splColor),
        effective,
        colorWrap(short(where), uiTone.where)
    )
    line = line .. (" | %s | %s"):format(detail, colorWrap(total, statusColor))
    row.chatText:SetTextColor(0.95, 0.95, 0.95, 1)
    row.chatText:SetText(line)
    self:ApplyPlayerNameGlow(row.chatText, event.sourceGUID == self.playerGUID or event.destGUID == self.playerGUID)
    row.chatText:Show()
    local r, g, b, a = eventTint(event.eventGroup, row:GetID() or 1)
    row.bg:SetVertexColor(r, g, b, a)
    for i = 1, #row.cols do
        row.cols[i]:Hide()
    end
end

function WHTM:RenderRowTable(row, event)
    row.chatText:Hide()
    local srcColor = sourceColorForEvent(event)
    local splColor = spellColorForEvent(event)
    local iconIdx = preferredRaidIcon(event, self.playerGUID)
    row.cols[1]:SetText(self:FormatClockTime(event.timestamp))
    row.cols[2]:SetText(raidIconTag(iconIdx) or "")
    local sourceText = short(event.sourceName)
    local targetText = short(event.destName)
    if self.db.profile.playerNameGlow and event.sourceGUID == self.playerGUID then
        sourceText = playerMarker(sourceText)
    end
    if self.db.profile.playerNameGlow and event.destGUID == self.playerGUID then
        targetText = playerMarker(targetText)
    end
    row.cols[3]:SetText(sourceText)
    row.cols[4]:SetText(targetText)
    row.cols[5]:SetText(short(event.spellName))
    row.cols[6]:SetText(eventTypeLabel(event))
    row.cols[7]:SetText(formatDetailValueText(event, true))
    row.cols[8]:SetText(formatTotalText(event))
    row.cols[9]:SetText(event.coordsText and ((event.subzone ~= "" and event.subzone or event.zone) .. " " .. event.coordsText)
        or (event.subzone ~= "" and event.subzone or event.zone))
    local c = groupColor[event.eventGroup] or { 1, 1, 1 }
    local dstColor = targetColorForEvent(event)
    row.cols[2]:SetTextColor(1, 1, 1, 1)
    row.cols[3]:SetTextColor(srcColor[1], srcColor[2], srcColor[3], 1)
    row.cols[4]:SetTextColor(dstColor[1], dstColor[2], dstColor[3], 1)
    row.cols[5]:SetTextColor(splColor[1], splColor[2], splColor[3], 1)
    row.cols[6]:SetTextColor(c[1], c[2], c[3], 1)
    row.cols[7]:SetTextColor(1, 1, 1, 1)
    row.cols[8]:SetTextColor(splColor[1], splColor[2], splColor[3], 1)
    self:ApplyPlayerNameGlow(row.cols[3], event.sourceGUID == self.playerGUID)
    self:ApplyPlayerNameGlow(row.cols[4], event.destGUID == self.playerGUID)
    for i = 1, #row.cols do
        if i ~= 2 and i ~= 3 and i ~= 4 and i ~= 5 and i ~= 6 and i ~= 7 and i ~= 8 then
            row.cols[i]:SetTextColor(1, 1, 1, 1)
        end
    end
    local r, g, b, a = eventTint(event.eventGroup, row:GetID() or 1)
    row.bg:SetVertexColor(r, g, b, a)
    for i = 1, #row.cols do
        if self:IsTableColumnVisible(self.mainFrame.columnKeys[i]) then
            row.cols[i]:Show()
        else
            row.cols[i]:Hide()
        end
    end
end

function WHTM:ShowEventTooltip(row)
    local event = row.event
    local srcColor = sourceColorForEvent(event)
    local dstColor = targetColorForEvent(event)
    local spellC = spellColorForEvent(event)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(("WHTM Event #%d"):format(event.id or 0), 1.0, 0.82, 0.0)
    GameTooltip:AddLine(("Type: %s (%s)"):format(event.subevent or "?", event.eventGroup or "?"), 1, 1, 1)
    if event.eventGroup == "aura" then
        GameTooltip:AddLine(("Aura state: %s"):format(event.auraState or "?"), 1, 0.9, 0.4)
        if event.auraType then
            GameTooltip:AddLine(("Aura type: %s"):format(event.auraType), 1, 0.9, 0.4)
        end
        if event.stackCount then
            GameTooltip:AddLine(("Stacks: %s"):format(event.stackCount), 1, 0.9, 0.4)
        end
    end
    GameTooltip:AddLine(("Time: %s"):format(self:FormatClockTime(event.timestamp)), 1, 1, 1)
    GameTooltip:AddLine(("Source: %s"):format(short(event.sourceName)), srcColor[1], srcColor[2], srcColor[3])
    if event.sourceClass then
        GameTooltip:AddLine(("Source class: %s"):format(event.sourceClass), srcColor[1], srcColor[2], srcColor[3])
    end
    if event.sourceTier then
        local tc = tierColor[event.sourceTier] or { 1, 1, 1 }
        GameTooltip:AddLine(("Source tier: %s"):format(event.sourceTier), tc[1], tc[2], tc[3])
    end
    GameTooltip:AddLine(("Target: %s"):format(short(event.destName)), dstColor[1], dstColor[2], dstColor[3])
    if event.destTier then
        local tc = tierColor[event.destTier] or { 1, 1, 1 }
        GameTooltip:AddLine(("Target tier: %s"):format(event.destTier), tc[1], tc[2], tc[3])
    end
    if event.spellName then
        GameTooltip:AddLine(("Ability: %s"):format(event.spellName), spellC[1], spellC[2], spellC[3])
    end
    if event.eventGroup == "control" then
        local action = controlActionLabel(event)
        local detail = controlDetailLabel(event)
        if action then
            GameTooltip:AddLine(("Action: %s"):format(action), 1, 0.9, 0.4)
        end
        if detail then
            GameTooltip:AddLine(("Affected: %s"):format(detail), 1, 0.9, 0.4)
        end
    end
    if event.amount then
        GameTooltip:AddLine(("Detail: %s"):format(formatBreakdownText(event, false)), 1, 1, 1)
        GameTooltip:AddLine(("Total: %s"):format(formatTotalText(event)), 1, 1, 1)
        GameTooltip:AddLine(("Amount: %s"):format(formatAmountText(event)), 1, 1, 1)
        GameTooltip:AddLine(("Raw: %s"):format(event.rawAmount or event.amount), 0.85, 0.85, 0.85)
        GameTooltip:AddLine(("Effective: %s"):format(event.effectiveAmount or event.amount), 0.6, 1, 0.6)
    end
    if event.missType then
        GameTooltip:AddLine(("Miss: %s"):format(event.missType), 1, 1, 1)
    end
    if event.overkill then GameTooltip:AddLine(("Overkill: %d"):format(event.overkill), 1, 0.3, 0.3) end
    if event.overheal then GameTooltip:AddLine(("Overheal: %d"):format(event.overheal), 0.3, 1, 0.3) end
    if event.resisted then GameTooltip:AddLine(("Resisted: %d"):format(event.resisted), 1, 1, 0.6) end
    if event.blocked then GameTooltip:AddLine(("Blocked: %d"):format(event.blocked), 1, 1, 0.6) end
    if event.absorbed then GameTooltip:AddLine(("Absorbed: %d"):format(event.absorbed), 1, 1, 0.6) end
    if event.critical then GameTooltip:AddLine("Critical: yes", 1, 0.5, 0.5) end
    GameTooltip:AddLine(("Where: %s / %s"):format(short(event.zone), short(event.subzone)), 1, 1, 1)
    if event.coordsText then
        GameTooltip:AddLine(("Coords: %s"):format(event.coordsText), 1, 1, 1)
    end
    if event.raw then
        GameTooltip:AddLine("Raw tokens:", 0.7, 0.7, 0.7)
        local line = {}
        for i = 1, #event.raw do
            line[#line + 1] = tostring(event.raw[i])
            if #line >= 8 then
                GameTooltip:AddLine(table.concat(line, ", "), 0.7, 0.7, 0.7, true)
                wipe(line)
            end
        end
        if #line > 0 then
            GameTooltip:AddLine(table.concat(line, ", "), 0.7, 0.7, 0.7, true)
        end
    end
    GameTooltip:Show()
end

function WHTM:RefreshRows()
    local perfStart = GetTime()
    if not self.mainFrame then
        return
    end
    if not self.mainFrame:IsShown() then
        self.pendingRefreshWhileHidden = true
        return
    end
    self.pendingRefreshWhileHidden = false

    self:RefreshButtons()
    self:RefreshShareWidgets()
    self:ApplyTableColumnLayout()

    local events = self:BuildVisibleEvents()
    self.visibleEvents = events

    local total = #events
    local usableHeight = self.mainFrame.scrollFrame:GetHeight() or (ROW_HEIGHT * DEFAULT_VISIBLE_ROWS)
    local visibleRows = math.floor(usableHeight / ROW_HEIGHT)
    if visibleRows < 6 then
        visibleRows = 6
    elseif visibleRows > DEFAULT_VISIBLE_ROWS then
        visibleRows = DEFAULT_VISIBLE_ROWS
    end
    self.mainFrame.visibleRows = visibleRows

    FauxScrollFrame_Update(self.mainFrame.scrollFrame, total, visibleRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(self.mainFrame.scrollFrame)

    self.mainFrame.header:SetShown(self.db.profile.mode == "table")
    for i = 1, DEFAULT_VISIBLE_ROWS do
        local row = self.mainFrame.rows[i]
        local event = events[i + offset]
        row.event = event
        if i <= visibleRows and event then
            if self.db.profile.mode == "chat" then
                self:RenderRowChat(row, event)
            else
                self:RenderRowTable(row, event)
            end
            row.selected:SetShown(self.selectedEvent and self.selectedEvent.id == event.id)
            row:Show()
        else
            row:Hide()
        end
    end
    self:RefreshDetailsDrawer()
    self:RecordUIRefreshStat((GetTime() - perfStart) * 1000)
    self:RefreshProfilerLine()
end

function WHTM:ToggleMainFrame()
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        if self.pendingRefreshWhileHidden then
            self:RefreshRows()
        end
    end
end

function WHTM:ShowMainFrame()
    self.mainFrame:Show()
    if self.pendingRefreshWhileHidden then
        self:RefreshRows()
    end
end

function WHTM:HideMainFrame()
    self.mainFrame:Hide()
end
