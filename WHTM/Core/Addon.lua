local addonName, ns = ...

local WHTM = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")
ns.WHTM = WHTM
ns.L = ns.L or {}

local function trim(msg)
    return (msg and msg:match("^%s*(.-)%s*$")) or ""
end

function WHTM:Printf(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage(("|cffffc94dWHTM|r: " .. fmt):format(...))
end

function WHTM:OnInitialize()
    self:InitializeDefaults()
    self.db = LibStub("AceDB-3.0"):New("WHTMDB", self.defaults, true)

    self:InitializeStore()
    self:InitializeAPI()
    self:InitializeSharing()
    self:InitializeMinimap()
    self:InitializeUI()
    self:InitializeOptions()

    self:RegisterChatCommand("whtm", "HandleSlashCommand")
end

function WHTM:OnEnable()
    self.playerGUID = UnitGUID("player")
    self:InitializeCombatCapture()
end

function WHTM:HandleSlashCommand(input)
    local text = trim(input or "")
    if text == "" then
        self:ToggleMainFrame()
        return
    end

    local cmd, rest = text:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    rest = trim(rest or "")

    if cmd == "show" then
        self:ShowMainFrame()
    elseif cmd == "hide" then
        self:HideMainFrame()
    elseif cmd == "clear" then
        self:ClearEvents()
        self:Printf("Session events cleared.")
    elseif cmd == "pause" then
        self:SetCapturePaused(true)
        self:Printf("Capture paused.")
    elseif cmd == "resume" then
        self:SetCapturePaused(false)
        self:Printf("Capture resumed.")
    elseif cmd == "mode" then
        local mode = rest:lower()
        if mode == "chat" or mode == "table" then
            self:SetDisplayMode(mode)
            self:Printf("Display mode set to %s.", mode)
        else
            self:Printf("Usage: /whtm mode chat|table")
        end
    elseif cmd == "options" or cmd == "config" then
        self:OpenOptions()
    else
        self:Printf("Commands: /whtm show|hide|clear|pause|resume|mode chat|table|options")
    end
end
