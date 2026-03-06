local _, ns = ...
local WHTM = ns.WHTM

function WHTM:InitializeDefaults()
    self.eventGroups = {
        damage = true,
        heal = true,
        aura = true,
        miss = true,
        death = true,
        control = true,
        resource = true,
    }

    self.defaults = {
        profile = {
            mode = "chat",
            paused = false,
            showProfiler = true,
            playerNameGlow = true,
            captureScope = "player",
            maxRows = 600,
            timestampFormat = "24h",
            shareChannel = "PARTY",
            whisperTarget = "",
            filters = {
                incoming = true,
                outgoing = false,
                internal = false,
                damage = true,
                heal = true,
                aura = true,
                aura_gained = true,
                aura_lost = true,
                aura_other = true,
                miss = true,
                death = true,
                control = true,
                resource = true,
            },
            tableColumns = {
                time = true,
                icon = true,
                source = true,
                target = true,
                ability = true,
                type = true,
                amount = true,
                mitigation = true,
                where = true,
            },
            tableWidths = {
                time = 72,
                icon = 38,
                source = 110,
                target = 110,
                ability = 144,
                type = 58,
                amount = 72,
                mitigation = 150,
                where = 150,
            },
            minimap = {
                hide = false,
                minimapPos = 220,
            },
            frame = {
                x = 0,
                y = 0,
                width = 920,
                height = 500,
            },
        },
    }
end

function WHTM:GetEventGroup(subevent)
    if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" or subevent == "SPELL_RESURRECT" then
        return "death"
    end
    if subevent == "SPELL_DISPEL" or subevent == "SPELL_STOLEN" or subevent == "SPELL_INTERRUPT" then
        return "control"
    end
    if subevent:find("SPELL_AURA_", 1, true) then
        return "aura"
    end
    if subevent == "SPELL_ENERGIZE" or subevent == "SPELL_PERIODIC_ENERGIZE" or subevent == "SPELL_DRAIN"
        or subevent == "SPELL_PERIODIC_DRAIN" or subevent == "SPELL_LEECH" then
        return "resource"
    end
    if subevent:find("MISSED", 1, true) then
        return "miss"
    end
    if subevent:find("HEAL", 1, true) then
        return "heal"
    end
    if subevent:find("DAMAGE", 1, true) then
        return "damage"
    end
    return "control"
end

function WHTM:IsGroupEnabled(group)
    local filters = self.db and self.db.profile and self.db.profile.filters
    if not filters then
        return true
    end
    if filters[group] == nil then
        return true
    end
    return filters[group]
end

function WHTM:IsDirectionEnabled(direction)
    local filters = self.db and self.db.profile and self.db.profile.filters
    if not filters then
        return true
    end
    if not direction or filters[direction] == nil then
        return true
    end
    return filters[direction]
end

function WHTM:IsAuraStateEnabled(state)
    local filters = self.db and self.db.profile and self.db.profile.filters
    if not filters or not state then
        return true
    end
    local key = "aura_" .. state
    if filters[key] == nil then
        return true
    end
    return filters[key]
end

function WHTM:SetCapturePaused(paused)
    self.db.profile.paused = paused and true or false
    self:SendMessage("WHTM_CAPTURE_STATE_CHANGED", self.db.profile.paused)
    if self.NotifyAPIListeners then
        self:NotifyAPIListeners("capture_state_changed", self.db.profile.paused)
    end
end

function WHTM:SetDisplayMode(mode)
    if mode ~= "chat" and mode ~= "table" then
        return
    end
    self.db.profile.mode = mode
    self:SendMessage("WHTM_MODE_CHANGED", mode)
    if self.NotifyAPIListeners then
        self:NotifyAPIListeners("mode_changed", mode)
    end
end

function WHTM:FormatClockTime(epoch)
    if not epoch then
        return "--:--:--"
    end
    local fmt = self.db.profile.timestampFormat == "12h" and "%I:%M:%S %p" or "%H:%M:%S"
    return date(fmt, epoch)
end
