local _, ns = ...
local WHTM = ns.WHTM

local apiListeners = {}
local WHTM_API = {}

local function shallowCopy(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = v
    end
    return out
end

local function copyEvent(event, includeRaw)
    if type(event) ~= "table" then
        return nil
    end
    local out = {}
    for k, v in pairs(event) do
        if includeRaw or k ~= "raw" then
            out[k] = v
        end
    end
    return out
end

local function passesSetFilter(set, value)
    if type(set) ~= "table" then
        return true
    end
    if value == nil then
        return false
    end
    return set[value] and true or false
end

function WHTM:NotifyAPIListeners(eventType, payload)
    for key, cb in pairs(apiListeners) do
        if type(cb) == "function" then
            local ok = pcall(cb, eventType, payload)
            if not ok then
                apiListeners[key] = nil
            end
        else
            apiListeners[key] = nil
        end
    end
end

function WHTM:InitializeAPI()
    local addonVersion = GetAddOnMetadata("WHTM", "Version") or "dev"

    function WHTM_API.IsAvailable()
        return true
    end

    function WHTM_API.GetVersion()
        return addonVersion
    end

    function WHTM_API.GetEvents(limit, opts)
        local out = {}
        local all = WHTM:GetEvents() or {}
        local max = tonumber(limit)
        if max and max < 1 then
            max = nil
        end
        local options = type(opts) == "table" and opts or {}
        local includeRaw = options.includeRaw and true or false
        local groups = options.groups
        local directions = options.directions
        local auraStates = options.auraStates

        for i = #all, 1, -1 do
            local event = all[i]
            if passesSetFilter(groups, event.eventGroup)
                and passesSetFilter(directions, event.direction)
                and (event.eventGroup ~= "aura" or passesSetFilter(auraStates, event.auraState or "other")) then
                out[#out + 1] = copyEvent(event, includeRaw)
                if max and #out >= max then
                    break
                end
            end
        end
        return out
    end

    function WHTM_API.RegisterListener(key, callback)
        if type(key) ~= "string" or key == "" then
            return false
        end
        if type(callback) ~= "function" then
            return false
        end
        apiListeners[key] = callback
        return true
    end

    function WHTM_API.UnregisterListener(key)
        if type(key) ~= "string" or key == "" then
            return false
        end
        apiListeners[key] = nil
        return true
    end

    function WHTM_API.GetSettings()
        local p = WHTM.db and WHTM.db.profile or {}
        return {
            mode = p.mode,
            paused = p.paused and true or false,
            captureScope = p.captureScope,
            maxRows = p.maxRows,
            retainFullHistory = p.retainFullHistory and true or false,
            minimapHide = p.minimap and p.minimap.hide and true or false,
            timestampFormat = p.timestampFormat,
            filters = shallowCopy(p.filters or {}),
            shareChannel = p.shareChannel,
            whisperTarget = p.whisperTarget,
        }
    end

    function WHTM_API.UpdateSettings(patch)
        if type(patch) ~= "table" then
            return false, "invalid_patch"
        end
        local p = WHTM.db and WHTM.db.profile
        if not p then
            return false, "no_profile"
        end

        local needsRefresh = false
        local deferUI = WHTM.ShouldDeferUIRefreshFromAPI and WHTM:ShouldDeferUIRefreshFromAPI() or false

        if patch.mode == "chat" or patch.mode == "table" then
            WHTM:SetDisplayMode(patch.mode, deferUI)
        end
        if patch.paused ~= nil then
            WHTM:SetCapturePaused(patch.paused and true or false, deferUI)
        end
        if patch.captureScope == "player" or patch.captureScope == "party" or patch.captureScope == "raid" then
            p.captureScope = patch.captureScope
            if WHTM.RebuildTrackedGUIDs then
                WHTM:RebuildTrackedGUIDs()
            end
            needsRefresh = true
        end
        if patch.maxRows ~= nil then
            local maxRows = tonumber(patch.maxRows) or p.maxRows or 600
            if maxRows < 100 then
                maxRows = 100
            elseif maxRows > 5000 then
                maxRows = 5000
            end
            p.maxRows = maxRows
            if WHTM.TrimEventsToCap then
                WHTM:TrimEventsToCap()
            end
            needsRefresh = true
        end
        if patch.retainFullHistory ~= nil then
            p.retainFullHistory = patch.retainFullHistory and true or false
            if not p.retainFullHistory and WHTM.TrimEventsToCap then
                WHTM:TrimEventsToCap()
            end
            needsRefresh = true
        end
        if patch.timestampFormat == "24h" or patch.timestampFormat == "12h" then
            p.timestampFormat = patch.timestampFormat
            needsRefresh = true
        end
        if type(patch.filters) == "table" then
            p.filters = p.filters or {}
            for key, value in pairs(patch.filters) do
                if p.filters[key] ~= nil then
                    p.filters[key] = value and true or false
                    needsRefresh = true
                end
            end
        end
        if type(patch.shareChannel) == "string" and patch.shareChannel ~= "" then
            p.shareChannel = patch.shareChannel
            needsRefresh = true
        end
        if patch.whisperTarget ~= nil then
            p.whisperTarget = tostring(patch.whisperTarget or "")
            needsRefresh = true
        end
        if patch.minimapHide ~= nil then
            p.minimap = p.minimap or {}
            local nextHide = patch.minimapHide and true or false
            local changed = (p.minimap.hide and true or false) ~= nextHide
            p.minimap.hide = nextHide
            if changed and WHTM.RefreshMinimapIcon then
                WHTM:RefreshMinimapIcon()
            end
        end

        if needsRefresh and WHTM.RefreshRows then
            if deferUI then
                WHTM.pendingRefreshWhileHidden = true
            else
                WHTM:RefreshRows()
            end
        end
        WHTM:NotifyAPIListeners("settings_updated", WHTM_API.GetSettings())
        return true
    end

    function WHTM_API.ClearEvents()
        if WHTM.ClearEvents then
            WHTM:ClearEvents()
            return true
        end
        return false
    end

    function WHTM_API.BuildShareLine(event)
        if WHTM.BuildShareLine then
            return WHTM:BuildShareLine(event)
        end
        return nil
    end

    function WHTM_API.ShareEvent(event, channel, whisperTarget)
        if WHTM.ShareEvent then
            WHTM:ShareEvent(event, channel, whisperTarget)
            return true
        end
        return false
    end

    _G.WHTM_API = WHTM_API
end
