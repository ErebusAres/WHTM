local _, ns = ...
local WHTM = ns.WHTM

local function get(info)
    local key = info[#info]
    if info[2] == "filters" then
        return WHTM.db.profile.filters[key]
    end
    if info[2] == "tableColumns" then
        return WHTM.db.profile.tableColumns[key]
    end
    if info[2] == "tableWidths" then
        return WHTM.db.profile.tableWidths[key]
    end
    if info[2] == "minimap" then
        return WHTM.db.profile.minimap[key]
    end
    return WHTM.db.profile[key]
end

local function set(info, value)
    local key = info[#info]
    if info[2] == "filters" then
        WHTM.db.profile.filters[key] = value
        WHTM:RefreshRows()
        return
    end
    if info[2] == "minimap" then
        WHTM.db.profile.minimap[key] = value
        WHTM:RefreshMinimapIcon()
        return
    end
    if info[2] == "tableColumns" then
        WHTM.db.profile.tableColumns[key] = value
        WHTM:RefreshRows()
        return
    end
    if info[2] == "tableWidths" then
        WHTM.db.profile.tableWidths[key] = value
        WHTM:RefreshRows()
        return
    end
    WHTM.db.profile[key] = value

    if key == "mode" then
        WHTM:SetDisplayMode(value)
    elseif key == "captureScope" then
        if WHTM.RebuildTrackedGUIDs then
            WHTM:RebuildTrackedGUIDs()
        end
        WHTM:RefreshRows()
    elseif key == "playerNameGlow" then
        WHTM:RefreshRows()
    elseif key == "apiPassiveUI" then
        if not value then
            WHTM:RefreshRows()
        end
    elseif key == "showProfiler" then
        WHTM:RefreshProfilerLine()
    elseif key == "paused" then
        WHTM:SetCapturePaused(value)
    elseif key == "maxRows" then
        WHTM:TrimEventsToCap()
        WHTM:RefreshRows()
    elseif key == "retainFullHistory" then
        if not value then
            WHTM:TrimEventsToCap()
        end
        WHTM:RefreshRows()
    elseif key == "timestampFormat" then
        WHTM:RefreshRows()
    end
end

function WHTM:InitializeOptions()
    local options = {
        type = "group",
        name = "WHTM",
        get = get,
        set = set,
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    mode = {
                        type = "select",
                        name = "Display Mode",
                        order = 1,
                        values = { chat = "Chat", table = "Table" },
                    },
                    captureScope = {
                        type = "select",
                        name = "Capture Scope",
                        order = 2,
                        values = {
                            player = "Self only",
                            party = "Party group",
                            raid = "Raid group",
                        },
                    },
                    paused = {
                        type = "toggle",
                        name = "Pause capture",
                        order = 3,
                    },
                    showProfiler = {
                        type = "toggle",
                        name = "Show profiler line",
                        order = 4,
                    },
                    playerNameGlow = {
                        type = "toggle",
                        name = "Player name glow",
                        order = 5,
                    },
                    apiPassiveUI = {
                        type = "toggle",
                        name = "Passive UI during API control",
                        desc = "When enabled, API-driven setting updates do not redraw WHTM while it is hidden.",
                        order = 6,
                    },
                    maxRows = {
                        type = "range",
                        name = "Max in-memory rows",
                        min = 100,
                        max = 3000,
                        step = 50,
                        order = 7,
                    },
                    retainFullHistory = {
                        type = "toggle",
                        name = "Retain full session history",
                        order = 8,
                    },
                    timestampFormat = {
                        type = "select",
                        name = "Timestamp format",
                        values = { ["24h"] = "24h", ["12h"] = "12h" },
                        order = 9,
                    },
                    shareChannel = {
                        type = "select",
                        name = "Default share channel",
                        values = {
                            SAY = "Say",
                            PARTY = "Party",
                            RAID = "Raid",
                            GUILD = "Guild",
                            WHISPER = "Whisper",
                        },
                        order = 10,
                    },
                    whisperTarget = {
                        type = "input",
                        name = "Whisper target",
                        order = 11,
                    },
                },
            },
            filters = {
                type = "group",
                name = "Event Filters",
                order = 2,
                args = {
                    incoming = { type = "toggle", name = "Incoming", order = 1 },
                    outgoing = { type = "toggle", name = "Outgoing", order = 2 },
                    internal = { type = "toggle", name = "Internal", order = 3 },
                    boss_only = { type = "toggle", name = "Boss encounters only", order = 4 },
                    damage = { type = "toggle", name = "Damage", order = 5 },
                    heal = { type = "toggle", name = "Heals", order = 6 },
                    aura = { type = "toggle", name = "Auras/Buffs", order = 7 },
                    aura_gained = { type = "toggle", name = "Aura gained", order = 8 },
                    aura_lost = { type = "toggle", name = "Aura lost", order = 9 },
                    aura_other = { type = "toggle", name = "Aura other", order = 10 },
                    miss = { type = "toggle", name = "Misses", order = 11 },
                    death = { type = "toggle", name = "Deaths/Res", order = 12 },
                    control = { type = "toggle", name = "Control", order = 13 },
                    resource = { type = "toggle", name = "Resource", order = 14 },
                },
            },
            minimap = {
                type = "group",
                name = "Minimap",
                order = 3,
                args = {
                    hide = {
                        type = "toggle",
                        name = "Hide minimap icon",
                        order = 1,
                    },
                },
            },
            tableColumns = {
                type = "group",
                name = "Table Columns",
                order = 4,
                args = {
                    time = { type = "toggle", name = "Show Time", order = 1 },
                    icon = { type = "toggle", name = "Show Icon", order = 2 },
                    source = { type = "toggle", name = "Show Source", order = 3 },
                    target = { type = "toggle", name = "Show Target", order = 4 },
                    ability = { type = "toggle", name = "Show Ability", order = 5 },
                    type = { type = "toggle", name = "Show Type", order = 6 },
                    amount = { type = "toggle", name = "Show Detail", order = 7 },
                    mitigation = { type = "toggle", name = "Show Total", order = 8 },
                    where = { type = "toggle", name = "Show Where", order = 9 },
                },
            },
            tableWidths = {
                type = "group",
                name = "Table Widths",
                order = 5,
                args = {
                    time = { type = "range", name = "Time width", min = 40, max = 220, step = 2, order = 1 },
                    icon = { type = "range", name = "Icon width", min = 30, max = 100, step = 2, order = 2 },
                    source = { type = "range", name = "Source width", min = 60, max = 260, step = 2, order = 3 },
                    target = { type = "range", name = "Target width", min = 60, max = 260, step = 2, order = 4 },
                    ability = { type = "range", name = "Ability width", min = 80, max = 360, step = 2, order = 5 },
                    type = { type = "range", name = "Type width", min = 40, max = 220, step = 2, order = 6 },
                    amount = { type = "range", name = "Detail width", min = 50, max = 220, step = 2, order = 7 },
                    mitigation = { type = "range", name = "Total width", min = 80, max = 320, step = 2, order = 8 },
                    where = { type = "range", name = "Where width", min = 80, max = 320, step = 2, order = 9 },
                },
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("WHTM", options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WHTM", "WHTM")
end

function WHTM:OpenOptions()
    if not self.optionsFrame then
        return
    end
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end
