# CTS SENTINEL ANTICHEAT ENGINE v2.0
## Technical Documentation & User Admin Manual
*Architect: Server authoritative Protection & Live-Sync Dashboard NUI*

---

## 1. ARCHITECTURAL OVERVIEW

CTS Sentinel v2.0 is an advanced, server-authoritative security suit engineered specifically for FiveM servers running FXServer and the ESX Framework. Sentinel completely shifts security enforcement from vulnerable client-side checks to authoritative server validation.

```
+------------------------------------------------------------+
|                  CTS SENTINEL ARCHITECTURE               |
+------------------------------------------------------------+
|                                                            |
|  [Client Game State]  ------(Encrypted RPC Net Events)---->|
|          |                                                 |
|  (Client-side Scan)                                        |
|  - Global _G Probe                                         |
|  - Rapid-fire Hook                                         |
|  - Speed/Teleport Loops                                    |
|          |                                                 |
|          v                                                 |
|  [Server Authoritative Validation Middleware] <------------+
|  - Distance Checks                                         |
|  - Job/Database state checks                                |
|  - Event Rate Limiters                                     |
|          |                                                 |
|          +------------> [Bans persistent JSON]             |
|          |                                                 |
|          +------------> [Live Sentinel NUI Dashboard]     |
|                         - 3D Interactive Map               |
|                         - Discord Lookup Engine            |
|                         - Live CLI Terminal                |
|                                                            |
+------------------------------------------------------------+
```

### 1.1 Server-Authoritative Design (The Golden Rule)
FiveM executors (Level 8 injection) operate by hijacking client memory and dumping scripts. Because client memory is entirely compromised, Sentinel treats all client-side triggers as untrusted "requests" rather than factual commands. 
* **Authoritative Deposits (`bank:depositAll`)**: Accepts no `amount` parameter from client. Server queries DB database balance (`xPlayer.getMoney()`) directly, subtracts, and credits.
* **Authoritative Interactions (`drug:harvest`)**: Player ped coordinates are requested server-side via `GetEntityCoords(GetPlayerPed(src))` and compared to field coordinates. Teleport exploits trigger instant ban.

### 1.2 Non-Blocking Asynchronous NUI Interface (CEF Crash Protection)
Traditional NUI interfaces utilize blocking UI functions (such as synchronous Javascript `alert()` or `confirm()`). In FiveM, Chromium Embedded Framework (CEF) runs on a tightly bound thread within the game's core rendering pipeline. Triggering synchronous alerts blocks CEF, freezing the game thread and resulting in an instant crash to desktop.
* Sentinel replaces all synchronous blockages with an asynchronous **Toast Notification Frame**, resolving CEF rendering hangs.

---

## 2. DETAILED SECURITY LOGICS & HEURISTICS

### 2.1 Client Environment Cleanliness Scans (`client/main.lua`)
Sentinel sweeps the global Lua namespace `_G` every 5 seconds to identify known executor variables, injection footprints, and UI libraries:
* **Blacklisted Signatures**: `F8Trigger`, `d0pamine`, `Absolute`, `HamMafia`, `EulenCheats`, `LynxMenu`, `imgui`, `ImGui`, `RunCode`, etc.
* **Overridden Hook Detection**: Inspects native functions like `TriggerServerEvent` to ensure they are not hooked or tampered with by external scripts.

### 2.2 Physics & Movement Heuristics
Sentinel monitors physical movements and entity velocities:
* **Anti-Speedhack**: Detects players on foot exceeding `15.0 m/s` (maximum standard sprint speed is ~9 m/s).
* **Anti-Teleport**: Calculates the distance vector delta between two consecutive checks (1 second interval). Jumps larger than `45 meters` on foot (not falling or parachuting) trigger an instant ban.
* **Vehicle Speed Limiter**: Flags vehicles exceeding `350.0 km/h` unless occupied by whitelisted administrative groups.

### 2.3 Weapon & Ammo Shields
* **Military Restricted Blacklist**: Sentinel continuously scans player inventories for military gear (`WEAPON_MINIGUN`, `WEAPON_RPG`, `WEAPON_RAILGUN`). If detected, the weapon is instantly removed, and the player is banned.
* **Heuristic Pistol Shooting Rate Limiter**: Detects rapid-fire semi-automatic weapon triggers. If a player shoots a pistol at an impossible rate (less than `55ms` between shots), the script flags a rapid-fire violation.

### 2.4 Event Rate Limiting (Spam Suppression)
A server-side middleware tracks event invocations.
* If a player triggers any registered network event (such as inventory updates or callbacks) at an impossible frequency (e.g. more than 50 requests per second), the limiter suppresses the trigger, logs the infraction, and drops the player.

---

## 3. COMPREHENSIVE CONTROL PANEL MANUAL

Admins in the `admin` or `superadmin` groups can open the Sentinel Administrative Center using the in-game command:
```
/anticheat
```

### 3.1 Sidebar Navigation (XeroShield Inspired Layout)
* **Dashboard (Overview)**: Displays live statistics of persistent bans, logged threat flags, active players, and blocked events.
* **Player Lookup**: Enter a Discord ID to run a credential and security search.
* **Panel Settings**: Opens visual customizations and the Technical Manual.
* **Players**: Tabular list of active players with managing options.
* **Bans**: Grid of active bans showing screenshots proof.
* **Interactive Map**: Satelite telemetry map with GPS tracker.
* **Configuration**: Detailed category toggles for Sentinel engines.
* **Admins**: Lists connected administrative staff.
* **Logs**: Scrolling stdout logs list.
* **Console CLI**: Integrated Command Line terminal.

### 3.2 Dynamic Player Lookup
* **Discord Integration**: Tapping a player's Discord ID queries active cheating databases.
* **Guild Scanner**: Detects if the player is a member of known cheat/reseller communities (*Gosth*, *Ham Mafia*, *RedEngine*, *Spotless*, *Tokyo Market*).
* **Active Subscriptions**: Flags whether they have active subscriptions to cheat clients.
* **Global Ban History**: Compiles historical bans from other linked FiveM servers (such as *Tokyo*, *RV Legacy*), showing date, reasons, and descriptions.

### 3.3 Interactive 3D Map
* **3D Isometric Space**: By utilizing CSS-3D and `perspective` transforms, the map can be manipulated in full 3D space.
* **Mouse Navigation**:
  * **Rotate / Spin (Z-axis)**: Left-click and drag left/right.
  * **Tilt / Angle (X-axis)**: Left-click and drag up/down.
  * **Scale / Zoom**: Scroll your mouse wheel forward/backward.
* **Dynamic Coordinate Normalization**: Plots markers onto the vector map by translating raw game engine vectors into percentages:
  $$\text{Map X (\%)} = 50 + \left( \frac{\text{Real X}}{4000} \right) \times 35$$
  $$\text{Map Y (\%)} = 50 - \left( \frac{\text{Real Y}}{8000} \right) \times 35$$

### 3.4 Live Spectating Pipeline
1. Clicking **Spectate** on the player card closes the dashboard UI and teleports the administrator's entity to the target player's coords.
2. The admin's ped is frozen, made completely invisible, invincible, and non-collidable.
3. Native spectator mode is activated (`NetworkSetInSpectatorMode(true, targetPed)`) to follow their movements.
4. Pressing **`E`** or clicking "Stop Spectating" exits spectator mode, teleports the admin back to their previous coordinates safely, restores their state, and **automatically re-opens the Sentinel panel with fresh statistics**.

---

## 4. SYSTEM CONFIGURATION & INTEGRATIONS

### 4.1 Configuration Categories
Configured inside the **Configuration Tab** or the local `config.json` database:
* **Settings**: Configure default locale (`en`/`hu`), Discord invite strings, and VPN blocking. Includes webhook slots for Bans, Object Spawning, and Aimlocks.
* **Client**: Toggle Anti-executors and global namespace checks.
* **Movement**: Anti speed hacks, Anti Noclip, and Anti Freecam.
* **Weapons**: Anti no-recoil, anti rapid-fire, and weapon blacklists.
* **Event**: Configure max rates per second and flush intervals.
* **Entity**: Set locks on bad props spawning and maximum particle scales.
* **Explosions**: Explosion rate limits and scales.

### 4.2 Code Integration (Securing other resources)
Other scripts can export Sentinel's security checks to instantly validate interactions and auto-ban cheaters:

```lua
-- syntax: exports['cts_sentinel']:VerifyAction(source, requiredJob, requiredCoords, maxDistance)
RegisterNetEvent('robbery:complete', function(storeId)
    local src = source
    local storeCoords = vector3(24.11, -1202.44, 29.12)
    
    -- Verifies player is within 5.0m of the register, is a citizen, and has cooldown verified.
    local isAuthorized = exports['cts_sentinel']:VerifyAction(src, 'user', storeCoords, 5.0)
    if not isAuthorized then
        -- VerifyAction automatically triggers banPlayer on server if distance or state check fails!
        return
    end

    -- Safely reward player
    local xPlayer = ESX.GetPlayerFromId(src)
    xPlayer.addMoney(500)
end)
```

### 4.3 Obfuscation Guidelines
To prevent dumpers from reading your client-side source files, obfuscate `client/main.lua` before putting the server live:
1. Compile your Lua script using standard obfuscators like **LuaObfuscator.com** or **Prometheus**.
2. Select string encryption, virtual machine wrapping, and control flow folding.
3. Replace the plaintext `client/main.lua` with the obfuscated code. (The server script `server/main.lua` must remain plaintext for FXServer runtime parsing).
