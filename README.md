# WHTM - What Happened To Me

WHTM is a player-focused combat timeline addon for **World of Warcraft 3.3.5a (Wrath of the Lich King)**.

It captures combat log events and renders them in a readable UI (chat-style or table-style), including context such as:
- who did what to whom
- when it happened
- where it happened (zone/subzone, coords when available)
- value breakdowns (effective, overheal, overkill, resisted, blocked, absorbed)
- aura gain/loss states, control events, deaths/resurrects, and more

## Compatibility
- Target client: **WoW 3.3.5a**
- TOC interface: **30300**
- Build target: **12340**

## Features
- Session-based combat event history (no persistent combat log storage)
- Chat and table display modes
- Filter system (direction, event groups, aura states, boss-only mode)
- Row selection + detailed metadata panel/tooltip
- Share selected events to chat channels (`SAY`, `PARTY`, `RAID`, `GUILD`, `WHISPER`)
- Minimap launcher icon (LibDataBroker + LibDBIcon)
- Public API for integration with other addons (`_G.WHTM_API`)

## Installation
1. Put the addon folder into your addons directory:
   - `World of Warcraft\Interface\AddOns\WHTM`
2. Ensure embedded libraries remain intact (`Ace3`, `LibDataBroker-1.1`, `LibDBIcon-1.0`).
3. Start or reload the game.

## Slash Commands
- `/whtm`
- `/whtm show`
- `/whtm hide`
- `/whtm clear`
- `/whtm pause`
- `/whtm resume`
- `/whtm mode chat|table`
- `/whtm options`

## API Integration (for other addons)
WHTM exposes a global API:

```lua
_G.WHTM_API
```

### Recommended loading pattern
In your addon `.toc`:

```toc
## OptionalDeps: WHTM
```

In Lua:

```lua
local api = _G.WHTM_API
if not (api and api.IsAvailable and api:IsAvailable()) then
  return
end
```

Note: `WHTM_API` functions are plain table functions. Use dot-style calls.

### API v1 contract
- `IsAvailable() -> boolean`
- `GetVersion() -> string`
- `GetEvents(limit, opts) -> table[]`
- `RegisterListener(key, callback) -> boolean`
- `UnregisterListener(key) -> boolean`
- `GetSettings() -> table`
- `UpdateSettings(patchTable) -> boolean, err?`
- `ClearEvents() -> boolean`
- `BuildShareLine(event) -> string|nil`
- `ShareEvent(event, channel, whisperTarget) -> boolean`

### Listener callback
`callback(eventType, payload)` may receive:
- `events_updated`
- `events_cleared`
- `settings_updated`
- `mode_changed`
- `capture_state_changed`

### `GetEvents(limit, opts)` options
- `includeRaw` (boolean)
- `groups` (set table, e.g. `{ damage=true, heal=true }`)
- `directions` (set table, e.g. `{ incoming=true, outgoing=true }`)
- `auraStates` (set table, e.g. `{ gained=true, lost=true, other=true }`)

### Example
```lua
local api = _G.WHTM_API
if api and api.IsAvailable and api.IsAvailable() then
  local ok = api.RegisterListener("MyAddon_WHTM", function(eventType)
    if eventType == "events_updated" then
      local events = api.GetEvents(100, { includeRaw = false })
      -- consume events
    end
  end)
end
```

## Project Link
- Repo: https://github.com/ErebusAres/WHTM

## License
This project is licensed under the **WHTM Open Link License** (see `LICENSE`).

You are free to use, modify, fork, and redistribute this addon and its API, including in private or commercial projects, as long as you include a visible link back to:
- https://github.com/ErebusAres/WHTM
