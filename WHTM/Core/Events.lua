local _, ns = ...
local WHTM = ns.WHTM
local band = bit.band

local trackedSubevents = {
    SWING_DAMAGE = true,
    RANGE_DAMAGE = true,
    SPELL_DAMAGE = true,
    SPELL_PERIODIC_DAMAGE = true,
    DAMAGE_SPLIT = true,
    DAMAGE_SHIELD = true,
    SWING_MISSED = true,
    RANGE_MISSED = true,
    SPELL_MISSED = true,
    SPELL_PERIODIC_MISSED = true,
    SPELL_HEAL = true,
    SPELL_PERIODIC_HEAL = true,
    UNIT_DIED = true,
    UNIT_DESTROYED = true,
    SPELL_RESURRECT = true,
    SPELL_DISPEL = true,
    SPELL_STOLEN = true,
    SPELL_INTERRUPT = true,
    SPELL_ENERGIZE = true,
    SPELL_PERIODIC_ENERGIZE = true,
    SPELL_DRAIN = true,
    SPELL_PERIODIC_DRAIN = true,
    SPELL_LEECH = true,
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REMOVED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_BROKEN = true,
    SPELL_AURA_BROKEN_SPELL = true,
}

local function sanitizeName(name)
    if not name or name == "" then
        return "Unknown"
    end
    return name:gsub("%-.+", "")
end

local function bestEffortPosition()
    local x, y = GetPlayerMapPosition("player")
    if not x or not y or (x == 0 and y == 0) then
        return nil, nil, nil
    end
    local pctX = math.floor((x * 100) + 0.5)
    local pctY = math.floor((y * 100) + 0.5)
    return x, y, ("%d,%d"):format(pctX, pctY)
end

local function safeUnitGUID(unit)
    if UnitExists(unit) then
        return UnitGUID(unit)
    end
end

local function buildClassCache(self)
    self.classByGUID = self.classByGUID or {}
    local classByGUID = self.classByGUID

    local function cacheUnit(unit)
        if not UnitExists(unit) then
            return
        end
        local guid = UnitGUID(unit)
        if not guid then
            return
        end
        local _, classFile = UnitClass(unit)
        if classFile then
            classByGUID[guid] = classFile
        end
    end

    cacheUnit("player")
    cacheUnit("target")
    cacheUnit("focus")
    cacheUnit("mouseover")

    for i = 1, 4 do
        cacheUnit("party" .. i)
        cacheUnit("partypet" .. i)
    end

    for i = 1, 40 do
        cacheUnit("raid" .. i)
        cacheUnit("raidpet" .. i)
    end
end

local function buildRaidIconCache(self)
    self.raidIconByGUID = self.raidIconByGUID or {}
    local raidIconByGUID = self.raidIconByGUID

    local function cacheUnit(unit)
        if not UnitExists(unit) then
            return
        end
        local guid = UnitGUID(unit)
        if not guid then
            return
        end
        local idx = GetRaidTargetIndex(unit)
        if idx and idx >= 1 and idx <= 8 then
            raidIconByGUID[guid] = idx
        end
    end

    cacheUnit("target")
    cacheUnit("focus")
    cacheUnit("mouseover")
    cacheUnit("player")
    cacheUnit("pet")

    for i = 1, 4 do
        cacheUnit("party" .. i)
        cacheUnit("partypet" .. i)
        cacheUnit("party" .. i .. "target")
    end

    for i = 1, 40 do
        cacheUnit("raid" .. i)
        cacheUnit("raidpet" .. i)
        cacheUnit("raid" .. i .. "target")
    end
end

local function findVisibleUnitByGUID(guid)
    if not guid then
        return nil
    end
    local candidates = {
        "target",
        "focus",
        "mouseover",
        "player",
    }
    for i = 1, #candidates do
        local unit = candidates[i]
        if safeUnitGUID(unit) == guid then
            return unit
        end
    end
    return nil
end

local function raidIconFromFlags(raidFlags)
    if not raidFlags then
        return nil
    end
    for i = 1, 8 do
        local bit = 2 ^ (i - 1)
        if band(raidFlags, bit) > 0 then
            return i
        end
    end
    return nil
end

local function classifyHostileTier(guid, flags)
    if not flags or band(flags, COMBATLOG_OBJECT_TYPE_NPC or 0) == 0 then
        return nil
    end

    local unit = findVisibleUnitByGUID(guid)
    if not unit then
        return "normal"
    end

    local classif = UnitClassification(unit)
    local level = UnitLevel(unit)
    local playerLevel = UnitLevel("player")
    local greenRange = GetQuestGreenRange() or 0

    if classif == "worldboss" or level == -1 then
        return "boss"
    end
    if classif == "elite" or classif == "rareelite" then
        return "elite"
    end
    if level and playerLevel and level > 0 and (playerLevel - level) > greenRange then
        return "junk"
    end
    return "normal"
end

local function classFromGUID(self, guid)
    if not guid then
        return nil
    end
    if self.classByGUID and self.classByGUID[guid] then
        return self.classByGUID[guid]
    end
    return nil
end

local function normalizeNumber(num)
    if not num then
        return nil
    end
    if num < 0 then
        return nil
    end
    if num == 0 then
        return nil
    end
    return num
end

local function applyDerivedAmounts(record)
    if not record.amount then
        return
    end

    local raw = tonumber(record.amount) or 0
    local overheal = tonumber(record.overheal) or 0
    local overkill = tonumber(record.overkill) or 0
    local resisted = tonumber(record.resisted) or 0
    local blocked = tonumber(record.blocked) or 0
    local absorbed = tonumber(record.absorbed) or 0

    local effective = raw - overheal - overkill - resisted
    if effective < 0 then
        effective = 0
    end

    record.rawAmount = raw
    record.effectiveAmount = effective
    record.preventedAmount = overheal + overkill + resisted + blocked + absorbed
end

local function buildAuraText(subevent, auraType, stacks)
    local action = "AURA"
    if subevent == "SPELL_AURA_APPLIED" then
        action = "APPLIED"
    elseif subevent == "SPELL_AURA_REMOVED" then
        action = "REMOVED"
    elseif subevent == "SPELL_AURA_REFRESH" then
        action = "REFRESH"
    elseif subevent == "SPELL_AURA_APPLIED_DOSE" then
        action = "STACK+"
    elseif subevent == "SPELL_AURA_REMOVED_DOSE" then
        action = "STACK-"
    elseif subevent == "SPELL_AURA_BROKEN" or subevent == "SPELL_AURA_BROKEN_SPELL" then
        action = "BROKEN"
    end

    local aura = auraType or "AURA"
    if stacks and tonumber(stacks) then
        return ("%s %s x%d"):format(action, aura, tonumber(stacks))
    end
    return ("%s %s"):format(action, aura)
end

local function getAuraState(subevent)
    if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_APPLIED_DOSE" then
        return "gained"
    end
    if subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REMOVED_DOSE" then
        return "lost"
    end
    return "other"
end

function WHTM:InitializeCombatCapture()
    buildClassCache(self)
    buildRaidIconCache(self)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnUnitContextUpdated")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnUnitContextUpdated")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnUnitContextUpdated")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnUnitContextUpdated")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnUnitContextUpdated")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "OnUnitContextUpdated")
    self:RegisterEvent("RAID_TARGET_UPDATE", "OnUnitContextUpdated")

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "OnCombatLogEvent")
end

function WHTM:OnUnitContextUpdated()
    buildClassCache(self)
    buildRaidIconCache(self)
    self:RebuildTrackedGUIDs()
end

function WHTM:RebuildTrackedGUIDs()
    local scope = self.db and self.db.profile and self.db.profile.captureScope or "player"
    local set = {}

    local function addUnit(unit)
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid then
                set[guid] = true
            end
        end
    end

    addUnit("player")

    if scope == "party" or scope == "raid" then
        addUnit("pet")
        if UnitInRaid("player") then
            for i = 1, 40 do
                addUnit("raid" .. i)
                addUnit("raidpet" .. i)
            end
        else
            for i = 1, 4 do
                addUnit("party" .. i)
                addUnit("partypet" .. i)
            end
        end
    end

    self.trackedGUIDs = set
end

function WHTM:IsTrackedGUID(guid)
    return guid and self.trackedGUIDs and self.trackedGUIDs[guid] and true or false
end

function WHTM:IsEventRelevant(subevent, srcGUID, dstGUID)
    if not self.trackedGUIDs then
        self:RebuildTrackedGUIDs()
    end

    local srcTracked = self:IsTrackedGUID(srcGUID)
    local dstTracked = self:IsTrackedGUID(dstGUID)
    if not srcTracked and not dstTracked then
        return false, nil, srcTracked, dstTracked
    end

    local direction = "incoming"
    if srcTracked and dstTracked then
        if srcGUID and dstGUID and srcGUID == dstGUID then
            direction = "incoming"
        else
            direction = "internal"
        end
    elseif srcTracked then
        direction = "outgoing"
    elseif dstTracked then
        direction = "incoming"
    end

    return true, direction, srcTracked, dstTracked
end

function WHTM:OnCombatLogEvent(_, ...)
    if self.db.profile.paused then
        return
    end

    local timestamp, subevent = select(1, ...), select(2, ...)
    local hideCaster
    local srcGUID, srcName, srcFlags, srcRaidFlags
    local dstGUID, dstName, dstFlags, dstRaidFlags
    local payloadStart

    -- Wrath 3.3.5a format:
    -- timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...
    -- Later format adds hideCaster and raid flags before payload.
    if type(select(3, ...)) == "boolean" then
        hideCaster = select(3, ...)
        srcGUID, srcName, srcFlags, srcRaidFlags = select(4, ...), select(5, ...), select(6, ...), select(7, ...)
        dstGUID, dstName, dstFlags, dstRaidFlags = select(8, ...), select(9, ...), select(10, ...), select(11, ...)
        payloadStart = 12
    else
        hideCaster = false
        srcGUID, srcName, srcFlags, srcRaidFlags = select(3, ...), select(4, ...), select(5, ...), nil
        dstGUID, dstName, dstFlags, dstRaidFlags = select(6, ...), select(7, ...), select(8, ...), nil
        payloadStart = 9
    end

    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 =
        select(payloadStart, ...)

    if not trackedSubevents[subevent] then
        return
    end
    local isRelevant, direction, srcTracked, dstTracked = self:IsEventRelevant(subevent, srcGUID, dstGUID)
    if not isRelevant then
        return
    end

    local now = time()
    local zone, subzone, mapX, mapY, coordsText
    if not self.lastContextAt or (now - self.lastContextAt) >= 1 then
        self.lastContextAt = now
        self.cachedZone = GetRealZoneText() or UNKNOWN
        self.cachedSubzone = GetSubZoneText() or ""
        self.cachedMapX, self.cachedMapY, self.cachedCoordsText = bestEffortPosition()
    end
    zone, subzone = self.cachedZone or UNKNOWN, self.cachedSubzone or ""
    mapX, mapY, coordsText = self.cachedMapX, self.cachedMapY, self.cachedCoordsText
    local group = self:GetEventGroup(subevent)

    local record = {
        timestamp = now,
        combatTimestamp = timestamp,
        subevent = subevent,
        eventGroup = group,
        direction = direction,
        sourceTracked = srcTracked,
        destTracked = dstTracked,
        sourceGUID = srcGUID,
        sourceName = sanitizeName(srcName),
        sourceFlags = srcFlags,
        sourceRaidFlags = srcRaidFlags,
        sourceRaidIcon = raidIconFromFlags(srcRaidFlags) or (self.raidIconByGUID and self.raidIconByGUID[srcGUID]),
        sourceClass = classFromGUID(self, srcGUID),
        sourceTier = classifyHostileTier(srcGUID, srcFlags),
        destGUID = dstGUID,
        destName = sanitizeName(dstName),
        destFlags = dstFlags,
        destRaidFlags = dstRaidFlags,
        destRaidIcon = raidIconFromFlags(dstRaidFlags) or (self.raidIconByGUID and self.raidIconByGUID[dstGUID]),
        destClass = classFromGUID(self, dstGUID),
        destTier = classifyHostileTier(dstGUID, dstFlags),
        zone = zone,
        subzone = subzone,
        mapX = mapX,
        mapY = mapY,
        coordsText = coordsText,
        raw = {
            a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12,
            hideCaster and 1 or 0,
        },
    }

    if subevent == "SWING_DAMAGE" then
        record.amount, record.overkill, record.school, record.resisted, record.blocked, record.absorbed, record.critical, record.glancing, record.crushing =
            a1, normalizeNumber(a2), a3, normalizeNumber(a4), normalizeNumber(a5), normalizeNumber(a6), a7, a8, a9
        record.spellName = "Melee"
    elseif subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE"
        or subevent == "DAMAGE_SPLIT" or subevent == "DAMAGE_SHIELD" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.amount, record.overkill, record.school, record.resisted, record.blocked, record.absorbed, record.critical, record.glancing, record.crushing =
            a4, normalizeNumber(a5), a6, normalizeNumber(a7), normalizeNumber(a8), normalizeNumber(a9), a10, a11, a12
    elseif subevent == "SWING_MISSED" then
        record.spellName = "Melee"
        record.missType, record.isOffHand, record.amountMissed = a1, a2, normalizeNumber(a3)
    elseif subevent == "RANGE_MISSED" or subevent == "SPELL_MISSED" or subevent == "SPELL_PERIODIC_MISSED" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.missType, record.isOffHand, record.amountMissed = a4, a5, normalizeNumber(a6)
    elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.amount, record.overheal, record.absorbed, record.critical = a4, normalizeNumber(a5), normalizeNumber(a6), a7
    elseif subevent == "SPELL_RESURRECT" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
    elseif subevent == "SPELL_DISPEL" or subevent == "SPELL_STOLEN" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.extraSpellId, record.extraSpellName, record.extraSchool, record.auraType = a4, a5, a6, a7
    elseif subevent == "SPELL_INTERRUPT" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.extraSpellId, record.extraSpellName, record.extraSchool = a4, a5, a6
    elseif subevent == "SPELL_ENERGIZE" or subevent == "SPELL_PERIODIC_ENERGIZE" or subevent == "SPELL_DRAIN"
        or subevent == "SPELL_PERIODIC_DRAIN" or subevent == "SPELL_LEECH" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.amount, record.powerType = a4, a5
        record.extraAmount = normalizeNumber(a6)
    elseif subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REFRESH" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.auraType = a4
        record.auraState = getAuraState(subevent)
        record.eventText = buildAuraText(subevent, a4, nil)
    elseif subevent == "SPELL_AURA_APPLIED_DOSE" or subevent == "SPELL_AURA_REMOVED_DOSE" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.auraType = a4
        record.auraState = getAuraState(subevent)
        record.stackCount = tonumber(a5) or nil
        record.eventText = buildAuraText(subevent, a4, record.stackCount)
    elseif subevent == "SPELL_AURA_BROKEN" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.auraType = a4
        record.auraState = getAuraState(subevent)
        record.eventText = buildAuraText(subevent, a4, nil)
    elseif subevent == "SPELL_AURA_BROKEN_SPELL" then
        record.spellId, record.spellName, record.spellSchool = a1, a2, a3
        record.extraSpellId, record.extraSpellName, record.extraSchool = a4, a5, a6
        record.auraType = "AURA"
        record.auraState = getAuraState(subevent)
        record.eventText = buildAuraText(subevent, record.auraType, nil)
    elseif subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
        record.killingBlow = (srcGUID == self.playerGUID)
        record.spellName = "Death"
    end

    applyDerivedAmounts(record)
    self:AddEvent(record)
end
