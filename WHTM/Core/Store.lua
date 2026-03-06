local _, ns = ...
local WHTM = ns.WHTM

function WHTM:InitializeStore()
    self.events = {}
    self.nextEventId = 1
    self.uiUpdateScheduled = false
    self.uiDirty = false
    self:InitializePerformanceStats()
end

function WHTM:InitializePerformanceStats()
    self.perf = {
        totalEvents = 0,
        eventsThisSec = 0,
        uiRefreshesThisSec = 0,
        uiRenderMsThisSec = 0,
        burstPeak = 0,
        eventsHistory = {},
        uiHistory = {},
        renderHistory = {},
        epsNow = 0,
        eps5 = 0,
        uiNow = 0,
        ui5 = 0,
        renderAvgMs = 0,
    }
    self:ScheduleRepeatingTimer("OnPerformanceTick", 1)
end

function WHTM:PushPerfSample(buf, value, maxLen)
    buf[#buf + 1] = value
    if #buf > maxLen then
        table.remove(buf, 1)
    end
end

function WHTM:AveragePerf(buf)
    if #buf == 0 then
        return 0
    end
    local total = 0
    for i = 1, #buf do
        total = total + (buf[i] or 0)
    end
    return total / #buf
end

function WHTM:OnPerformanceTick()
    local p = self.perf
    if not p then
        return
    end
    self:PushPerfSample(p.eventsHistory, p.eventsThisSec, 5)
    self:PushPerfSample(p.uiHistory, p.uiRefreshesThisSec, 5)

    local renderAvgThisSec = 0
    if p.uiRefreshesThisSec > 0 then
        renderAvgThisSec = p.uiRenderMsThisSec / p.uiRefreshesThisSec
    end
    self:PushPerfSample(p.renderHistory, renderAvgThisSec, 5)

    p.epsNow = p.eventsThisSec
    p.eps5 = self:AveragePerf(p.eventsHistory)
    p.uiNow = p.uiRefreshesThisSec
    p.ui5 = self:AveragePerf(p.uiHistory)
    p.renderAvgMs = self:AveragePerf(p.renderHistory)

    p.eventsThisSec = 0
    p.uiRefreshesThisSec = 0
    p.uiRenderMsThisSec = 0

    self:SendMessage("WHTM_PERF_UPDATED")
end

function WHTM:RecordEventStat()
    local p = self.perf
    if not p then
        return
    end
    p.totalEvents = p.totalEvents + 1
    p.eventsThisSec = p.eventsThisSec + 1
    if p.eventsThisSec > p.burstPeak then
        p.burstPeak = p.eventsThisSec
    end
end

function WHTM:RecordUIRefreshStat(dtMs)
    local p = self.perf
    if not p then
        return
    end
    p.uiRefreshesThisSec = p.uiRefreshesThisSec + 1
    p.uiRenderMsThisSec = p.uiRenderMsThisSec + (dtMs or 0)
end

function WHTM:GetPerformanceSnapshot()
    return self.perf
end

function WHTM:GetEvents()
    return self.events
end

function WHTM:AddEvent(eventRecord)
    eventRecord.id = self.nextEventId
    self.nextEventId = self.nextEventId + 1

    table.insert(self.events, eventRecord)
    self:RecordEventStat()
    self:TrimEventsToCap()
    self:QueueUIRefresh()
end

function WHTM:QueueUIRefresh()
    self.uiDirty = true
    if self.uiUpdateScheduled then
        return
    end
    self.uiUpdateScheduled = true
    self:ScheduleTimer(function()
        self.uiUpdateScheduled = false
        if self.uiDirty then
            self.uiDirty = false
            self:SendMessage("WHTM_EVENTS_UPDATED")
            if self.NotifyAPIListeners then
                self:NotifyAPIListeners("events_updated")
            end
        end
    end, 0.06)
end

function WHTM:TrimEventsToCap()
    local cap = tonumber(self.db.profile.maxRows) or 600
    while #self.events > cap do
        table.remove(self.events, 1)
    end
end

function WHTM:ClearEvents()
    wipe(self.events)
    self.uiDirty = false
    self:SendMessage("WHTM_EVENTS_UPDATED")
    if self.NotifyAPIListeners then
        self:NotifyAPIListeners("events_cleared")
    end
end
