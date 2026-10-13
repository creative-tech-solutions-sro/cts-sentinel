# CTS Sentinel

**Advanced server-authoritative anti-cheat & live admin dashboard for FiveM (ESX).**

CTS Sentinel v2.0 runs every security decision on the server. Client scripts can be
dumped and edited, but nothing the client claims is trusted without server-side
validation. It combines heuristic detections, connection screening, a persistent
ban system, and a full in-game web dashboard for admins.

## Features

**Detection engine (server-authoritative)**
- Heuristic speedhack + teleportation anomaly detection (distance/time analysis)
- Rapid-fire detection on semi-automatic weapons
- Entity health-modifier (godmode injection) detection
- Physical godmode vulnerability checks & unauthorized spectate detection
- Blacklisted military-restricted weapon possession checks
- Client-injection / global-variable violation detection
- Persistent bans with reason, banner identity, timestamps, and IP capture
- Rate-limited network events (anti event-spam)
- Connection deferrals: credential screening + VPN/release/Spoof checks
- Configurable ban appeals flow (appeal link shown on connect)

**Live admin dashboard (NUI, opened with the anticheat command)**
- Live player list with identifiers, job and ping
- Player spectate with live coordinate tracking
- CLI terminal for server commands from inside the game
- Server log viewer + config editor + ban editor (add/edit/delete)
- 3D map (`html/map.glb`, ~52 MB) for geographic overview

**Integration**
- `VerifyAction` export for other resources to enforce distance/job checks:

```lua
-- server side
local ok = exports['cts_sentinel']:VerifyAction(source, 'user', coords, 5.0)
```

## Requirements

- FiveM server (FXServer, cerulean)
- [`es_extended`](https://github.com/esx-framework/esx_core) (ESX)
- [`ox_lib`](https://github.com/overextended/ox_lib)
- MySQL database (oxmysql used by ESX)

## Installation

1. Copy the `cts_sentinel` folder into your `resources/` directory.
2. Ensure your database and ESX are running.
3. Add to `server.cfg` (after ESX + ox_lib):

   ```cfg
   ensure cts_sentinel
   ```

4. Restart the server. The console prints a `[CTS-Sentinel]` banner when loaded.

## Configuration

| File | Purpose |
|---|---|
| `config.json` | Feature toggles: Steam/Discord requirement, anti-VPN, anti-crash, global ban, ban reason reveal, invite shown in dashboard, locale |
| `server/config.lua` | `CtsSentinelConfig.AdminExclusions` — identifiers that bypass all checks (set your own `license:` / `discord:` / `steam:` entries) |
| `bans.json` | Persistent ban list (runtime data) |

## Repository notes

- `bans.json` is shipped empty — it is runtime data on live servers. Do not publish
  your real ban list (it contains player identifiers and IPs).
- Invite and server-name strings are placeholders (`discord.gg/your-server`).
- `html/map.glb` is ~52 MB. If GitHub warns during push, consider
  [Git LFS](https://git-lfs.com/) for `*.glb`.

## Files

```
cts_sentinel/
├── fxmanifest.lua
├── client/main.lua          # detections, NUI bridge, spectate
├── server/main.lua          # authoritative checks, bans, dashboard API
├── server/config.lua        # admin exclusions
├── html/                    # dashboard UI (index.html, script.js, style.css, map.glb)
├── config.json              # feature toggles
├── bans.json                # ban persistence (empty in repo)
└── TECHNICAL_DOCUMENTATION.md
```

## License

MIT — see [LICENSE](LICENSE).
