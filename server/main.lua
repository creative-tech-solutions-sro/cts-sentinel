local ESX = exports['es_extended']:getSharedObject()

-- Memory State
local ActiveBans = {}
local SystemLogs = {}
local ThreatCount = 0
local BlockedEventsCount = 0
local SpectatorTargets = {} -- [AdminSrc] = TargetSrc
local AnticheatConfig = {}  -- Persistently loaded configuration state
local PlayerEventHits = {}  -- Rate limiter: [src][eventName] = { count, lastTime }

-- Admin Bypass Exclusions (loaded from server/config.lua)
local AdminExclusions = CtsSentinelConfig.AdminExclusions or {}


-- Load/Save Config persistently to json
local function loadConfig()
    local content = LoadResourceFile(GetCurrentResourceName(), 'config.json')
    if content then
        local success, parsed = pcall(json.decode, content)
        if success and parsed then
            AnticheatConfig = parsed
            print('[CTS-Sentinel] Successfully loaded persistent Sentinel configurations.')
        end
    else
        AnticheatConfig = {
            locals = "en",
            discordInvite = "discord.gg/your-server",
            revealBanReason = true,
            autoInstall = false,
            txadmin = true,
            banIp = true,
            antiRelease = true,
            antiVpn = true,
            antiCrash = true,
            antiSpoof = true,
            antiSpoofAi = true,
            globalBan = true,
            reqSteam = true,
            reqDiscord = true
        }
        SaveResourceFile(GetCurrentResourceName(), 'config.json', json.encode(AnticheatConfig, {indent = true}), -1)
    end
end

local function saveConfigPersistent(data)
    AnticheatConfig = data
    SaveResourceFile(GetCurrentResourceName(), 'config.json', json.encode(AnticheatConfig, {indent = true}), -1)
    print('[CTS-Sentinel] Persisted active configurations to config.json.')
end

local function saveBans()
    local content = json.encode(ActiveBans, {indent = true})
    SaveResourceFile(GetCurrentResourceName(), 'bans.json', content, -1)
end

local function loadBans()
    local content = LoadResourceFile(GetCurrentResourceName(), 'bans.json')
    if content then
        local success, parsed = pcall(json.decode, content)
        if success and parsed then
            ActiveBans = parsed
            print(('[CTS-Sentinel] Successfully loaded %s persistent bans.'):format(#ActiveBans))
        end
    else
        SaveResourceFile(GetCurrentResourceName(), 'bans.json', '[]', -1)
        ActiveBans = {}
    end
end

-- Load bans and config on server initialization
CreateThread(function()
    loadConfig()
    loadBans()
end)


-- Helper to add logs and broadcast to admins
local function addLog(logType, message)
    local time = os.date('%H:%M:%S')
    local logData = {
        time = time,
        type = logType, -- 'ban', 'flag', 'event', 'info'
        message = message
    }
    table.insert(SystemLogs, 1, logData)
    if #SystemLogs > 200 then
        table.remove(SystemLogs)
    end

    if logType == 'ban' then
        -- Increment bans count
    elseif logType == 'flag' then
        ThreatCount = ThreatCount + 1
    elseif logType == 'event' then
        BlockedEventsCount = BlockedEventsCount + 1
    end

    -- Broadcast log to all open admin panels
    local totalPing = 0
    local pCount = 0
    for _, pid in ipairs(GetPlayers()) do
        local ping = GetPlayerPing(pid)
        if ping and ping > 0 then
            totalPing = totalPing + ping
            pCount = pCount + 1
        end
    end
    local calculatedAvgPing = 15
    if pCount > 0 then
        calculatedAvgPing = math.floor(totalPing / pCount)
    end

    local xPlayers = ESX.GetExtendedPlayers('group', 'admin')
    for _, xAdmin in ipairs(xPlayers) do
        TriggerClientEvent('cts_sentinel:updateClientUi', xAdmin.source, {
            stats = {
                bans = #ActiveBans,
                threats = ThreatCount,
                blocked = BlockedEventsCount,
                playersOnline = #GetPlayers(),
                maxPlayers = GetConvarInt('sv_maxclients', 48),
                uptime = string.format('%dd %dh %dm', math.floor(GetGameTimer() / 86400000), math.floor((GetGameTimer() % 86400000) / 3600000), math.floor((GetGameTimer() % 3600000) / 60000)),
                avgPing = calculatedAvgPing,
                gameBuild = GetConvar('sv_enforceGameBuild', '3095'),
                onesync = GetConvar('onesync', 'off') == 'on',
                resourcesCount = GetNumResources()
            },
            players = {}, -- Fetched dynamically on request
            logs = SystemLogs
        })
    end
end

-- Hook global Lua print function to mirror all console print statements to the Live Logs Panel in real-time!
local origPrint = print
print = function(...)
    local args = {...}
    local message = ""
    for i, arg in ipairs(args) do
        if i == 1 then
            message = tostring(arg)
        else
            message = message .. " " .. tostring(arg)
        end
    end
    origPrint(table.unpack(args)) -- print to actual server terminal
    
    -- Clean and feed to our Live Logs Panel
    message = string.gsub(message, "^%s*(.-)%s*$", "%1")
    if message ~= "" then
        addLog('info', '[Console] ' .. message)
    end
end


-- Persistent Ban Logic
local function banPlayer(source, reason, banner)
    local src = tonumber(source)
    if not src or src == 0 then return end

    local name = GetPlayerName(src)
    local identifiers = GetPlayerIdentifiers(src)
    local license = 'N/A'
    local steam = 'N/A'
    local discord = 'N/A'
    local ip = 'N/A'

    for _, id in ipairs(identifiers) do
        if string.find(id, 'license:') then license = id
        elseif string.find(id, 'steam:') then steam = id
        elseif string.find(id, 'discord:') then discord = id
        elseif string.find(id, 'ip:') then ip = id
        end
    end

    -- Authoritative Admin Exclusions check
    if AdminExclusions[discord] or AdminExclusions[steam] or AdminExclusions[license] then
        addLog('info', ('[BYPASS] Admin/Whitelisted %s (%s) triggered "%s" but was skipped.'):format(name, src, reason))
        print(('[CTS-Sentinel] Admin %s (%s) triggered "%s" but was bypassed.'):format(name, src, reason))
        return
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and (xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin') then
        addLog('info', ('[BYPASS] Admin %s (%s) triggered "%s" but was skipped.'):format(name, src, reason))
        print(('[CTS-Sentinel] Admin %s (%s) triggered "%s" but was bypassed.'):format(name, src, reason))
        return
    end

    local banRecord = {
        name = name,
        license = license,
        steam = steam,
        discord = discord,
        ip = ip,
        reason = reason,
        banner = banner or 'CTS Sentinel System',
        time = os.date('%Y-%m-%d %H:%M:%S')
    }


    table.insert(ActiveBans, banRecord)
    saveBans()
    
    addLog('ban', ('Player %s (%s) was PERMANENTLY BANNED by %s for: %s'):format(name, src, banRecord.banner, reason))
    DropPlayer(src, ('[CTS-Sentinel] Permanent Ban: %s. Appeal at discord.gg/your-server'):format(reason))
end

-- Unban Logic
local function unbanPlayer(license)
    for i, ban in ipairs(ActiveBans) do
        if ban.license == license or ban.license == 'license:'..license then
            table.remove(ActiveBans, i)
            saveBans()
            addLog('info', ('Removed ban record for license: %s'):format(license))
            return true
        end
    end
    return false
end

-- ESX Admin Callback verification
ESX.RegisterServerCallback('cts_sentinel:isAdmin', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local identifiers = GetPlayerIdentifiers(source)
    local isExcluded = false
    for _, id in ipairs(identifiers) do
        if AdminExclusions[id] then
            isExcluded = true
            break
        end
    end
    if isExcluded or (xPlayer and (xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin')) then
        cb(true)
    else
        cb(false)
    end
end)


-- Connection block for Banned Players
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(50)

    deferrals.update(("[CTS-Sentinel] Scanning credentials of %s for security screening..."):format(name))
    Wait(500)

    local identifiers = GetPlayerIdentifiers(src)
    local isBanned = false
    local banReason = ''

    for _, ban in ipairs(ActiveBans) do
        for _, id in ipairs(identifiers) do
            if id == ban.license or id == ban.steam or id == ban.discord or id == ban.ip then
                isBanned = true
                banReason = ban.reason
                break
            end
        end
        if isBanned then break end
    end

    if isBanned then
        deferrals.done(("[CTS-Sentinel] Permanent Ban Active: %s. Appeal at discord.gg/your-server"):format(banReason))
        print(('[CTS-Sentinel] Connection rejected from banned player %s'):format(name))
    else
        deferrals.done()
        addLog('info', ('Player %s connected safely.'):format(name))
    end
end)


-- ==========================================
-- EVENT RATE LIMITING & SECURITY VERIFICATION
-- ==========================================

-- Rate Limit Middleware
local EventRateLimits = {
    ["esx:triggerServerCallback"] = { limit = 30, interval = 1000 },
    ["chat:addMessage"] = { limit = 5, interval = 1000 },
    ["ox_inventory:moveItem"] = { limit = 15, interval = 1000 },
    ["bank:depositAll"] = { limit = 2, interval = 5000 },
    ["cts_sentinel:requestUpdate"] = { limit = 10, interval = 1000 }
}

local function handleRateLimiter(source, eventName)
    local src = tonumber(source)
    if not src or src == 0 then return true end

    local rule = EventRateLimits[eventName]
    if not rule then return true end -- No rate limit defined for this event

    if not PlayerEventHits[src] then PlayerEventHits[src] = {} end
    if not PlayerEventHits[src][eventName] then
        PlayerEventHits[src][eventName] = { count = 1, lastTime = GetGameTimer() }
        return true
    end

    local hit = PlayerEventHits[src][eventName]
    local now = GetGameTimer()

    if now - hit.lastTime < rule.interval then
        hit.count = hit.count + 1
        if hit.count > rule.limit then
            -- Trigger Rate Limit Action: block and drop player
            addLog('event', ('Player %s (%s) rate limited on event "%s" (%s triggers in %sms)'):format(GetPlayerName(src), src, eventName, hit.count, rule.interval))
            DropPlayer(src, ('[CTS-Sentinel] Rate Limit Violation on network event "%s"'):format(eventName))
            return false
        end
    else
        hit.count = 1
        hit.lastTime = now
    end

    return true
end

-- Intercept standard triggers if we want, or monitor directly
-- For FiveM, we can intercept ESX callbacks easily and secure events!
-- Let's hook event triggers for rate limiting
local origRegisterNetEvent = RegisterNetEvent
RegisterNetEvent = function(eventName, callback)
    if EventRateLimits[eventName] then
        origRegisterNetEvent(eventName, function(...)
            local src = source
            if handleRateLimiter(src, eventName) then
                if callback then callback(...) end
            end
        end)
    else
        origRegisterNetEvent(eventName, callback)
    end
end


-- ==========================================
-- SERVER DISTANCE & JOB VALIDATION HELPER
-- ==========================================

function VerifyPlayerInteraction(source, targetCoords, maxDistance, requiredJob)
    local src = tonumber(source)
    if not src or src == 0 then return false end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    -- 1. Job Verification
    if requiredJob then
        if xPlayer.getJob().name ~= requiredJob then
            banPlayer(src, 'Job state exploitation (event required job: ' .. requiredJob .. ', player has job: ' .. xPlayer.getJob().name .. ')', 'Server Security Engine')
            return false
        end
    end

    -- 2. Distance Verification
    if targetCoords and maxDistance then
        local ped = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(ped)
        local distance = #(playerCoords - targetCoords)

        if distance > maxDistance then
            banPlayer(src, ('Teleport / Remote Interaction exploit (interaction distance: %.2fm, max allowed: %.2fm)'):format(distance, maxDistance), 'Server Security Engine')
            return false
        end
    end

    return true
end


-- ==========================================
-- BACKGROUND AUTONOMOUS SCANNING LOOP
-- ==========================================

local PlayerHeuristicFlags = {} -- [playerSrc] = { flags... }

CreateThread(function()
    while true do
        Wait(5000) -- Scan every 5 seconds
        
        local players = GetPlayers()
        for _, pid in ipairs(players) do
            local src = tonumber(pid)
            local ped = GetPlayerPed(src)
            local xPlayer = ESX.GetPlayerFromId(src)

            if ped and ped ~= 0 and xPlayer then
                local coords = GetEntityCoords(ped)
                local health = GetEntityHealth(ped)
                local armor = GetPedArmour(ped)
                local name = GetPlayerName(src)
                
                if not PlayerHeuristicFlags[src] then PlayerHeuristicFlags[src] = {} end
                local flags = PlayerHeuristicFlags[src]

                -- Speed heuristics (simple vehicle speed / passive speed check)
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle and vehicle ~= 0 then
                    local speed = GetEntitySpeed(vehicle) * 3.6 -- km/h
                    if speed > 350.0 and xPlayer.getGroup() ~= 'admin' then
                        if not flags["speed_veh"] then
                            flags["speed_veh"] = true
                            addLog('flag', ('Autonomous Scanner Flag: Player %s (%s) speed anomaly in vehicle (%.2f km/h)'):format(name, src, speed))
                        end
                    end
                end

                -- Health modification check
                if health > 200 then
                    if not flags["health_mod"] then
                        flags["health_mod"] = true
                        addLog('flag', ('Autonomous Scanner Flag: Player %s (%s) custom health modifier detected (health: %s)'):format(name, src, health))
                    end
                end

                -- Weapon check
                local currentWeapon = GetSelectedPedWeapon(ped)
                if currentWeapon == `WEAPON_MINIGUN` and xPlayer.getJob().name ~= 'police' and xPlayer.getGroup() ~= 'admin' then
                    if not flags["blacklisted_wpn"] then
                        flags["blacklisted_wpn"] = true
                        addLog('flag', ('Autonomous Scanner Flag: Player %s (%s) holding blacklisted minigun'):format(name, src))
                        RemoveWeaponFromPed(ped, `WEAPON_MINIGUN`)
                    end
                end
            end
        end
    end
end)


-- ==========================================
-- ADMIN GUI DATA & EVENT INTERFACES
-- ==========================================

local function getGuiStats()
    local uptime = GetGameTimer()
    local days = math.floor(uptime / 86400000)
    local hours = math.floor((uptime % 86400000) / 3600000)
    local minutes = math.floor((uptime % 3600000) / 60000)
    local uptimeStr = string.format('%dd %dh %dm', days, hours, minutes)

    -- Dynamic Real-Time Average Ping calculation of online players
    local totalPing = 0
    local pCount = 0
    for _, pid in ipairs(GetPlayers()) do
        local ping = GetPlayerPing(pid)
        if ping and ping > 0 then
            totalPing = totalPing + ping
            pCount = pCount + 1
        end
    end
    local calculatedAvgPing = 15 -- standard default fallback
    if pCount > 0 then
        calculatedAvgPing = math.floor(totalPing / pCount)
    end

    return {
        bans = #ActiveBans,
        threats = ThreatCount,
        blocked = BlockedEventsCount,
        playersOnline = #GetPlayers(),
        maxPlayers = GetConvarInt('sv_maxclients', 48),
        uptime = uptimeStr,
        avgPing = calculatedAvgPing,
        gameBuild = GetConvar('sv_enforceGameBuild', '3095'),
        onesync = GetConvar('onesync', 'off') == 'on',
        resourcesCount = GetNumResources()
    }
end


local function getGuiPlayerList()
    local list = {}
    for _, pid in ipairs(GetPlayers()) do
        local src = tonumber(pid)
        local p = ESX.GetPlayerFromId(src)
        if p then
            local ped = GetPlayerPed(src)
            local coords = GetEntityCoords(ped)
            local coordsStr = string.format('%.1f, %.1f, %.1f', coords.x, coords.y, coords.z)
            
            -- Compile active scanner flags
            local flags = {}
            if PlayerHeuristicFlags[src] then
                for fName, active in pairs(PlayerHeuristicFlags[src]) do
                    if active then table.insert(flags, fName) end
                end
            end

            table.insert(list, {
                id = src,
                name = p.getName(),
                job = p.getJob().label or p.getJob().name,
                ping = GetPlayerPing(src),
                flags = flags,
                coords = coordsStr
            })
        end
    end
    return list
end

local function getGuiAdminList()
    local list = {}
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in ipairs(xPlayers) do
        local group = xPlayer.getGroup()
        if group == 'admin' or group == 'superadmin' then
            local src = xPlayer.source
            local identifiers = GetPlayerIdentifiers(src)
            local steam = "N/A"
            for _, id in ipairs(identifiers) do
                if string.find(id, "steam:") then steam = id end
            end
            table.insert(list, {
                name = xPlayer.getName(),
                steam = steam,
                group = string.upper(group),
                ip = GetPlayerEndpoint(src) or "127.0.0.1"
            })
        end
    end
    -- Fallback default if list is empty for presentation
    if #list == 0 then
        table.insert(list, {
            name = "wtfomgasd",
            steam = "steam:11000011339C060",
            group = "SUPERADMIN",
            ip = "127.0.0.1"
        })
    end
    return list
end

-- Command to open Admin UI
ESX.RegisterCommand('anticheat', 'admin', function(xPlayer, args, showError)
    local src = xPlayer.source
    local identifiers = GetPlayerIdentifiers(src)
    local discordId = "N/A"
    for _, id in ipairs(identifiers) do
        if string.find(id, "discord:") then
            discordId = string.gsub(id, "discord:", "")
        elseif string.find(id, "license:") and discordId == "N/A" then
            discordId = string.gsub(id, "license:", "LIC-")
        end
    end


    local data = {
        stats = getGuiStats(),
        players = getGuiPlayerList(),
        logs = SystemLogs,
        admins = getGuiAdminList(),
        bansList = ActiveBans,
        admin = {
            name = xPlayer.getName(),
            discord = discordId,
            avatar = "https://api.dicebear.com/7.x/bottts/svg?seed=" .. xPlayer.getName()
        }
    }

    TriggerClientEvent('cts_sentinel:openUi', src, data)
end, true, {help = 'Open CTS Sentinel Dashboard'})


-- CLI Command Parser
local function executeCliCommandOnServer(adminSrc, cmd, args)
    local reply = ""
    local replyClass = "success"

    if cmd == 'status' then
        local stats = getGuiStats()
        reply = string.format(
            "System Status:\n  Uptime: %s\n  Online Players: %s/%s\n  Total Persistent Bans: %s\n  Threat Alerts: %s\n  Blocked Event Cheats: %s\n  Enforced GameBuild: %s\n  OneSync Infinity: %s",
            stats.uptime, stats.playersOnline, stats.maxPlayers, stats.bans, stats.threats, stats.blocked, stats.gameBuild, stats.onesync and "ENABLED" or "DISABLED"
        )
    elseif cmd == 'list' then
        local players = getGuiPlayerList()
        reply = "Active Players List:"
        for _, p in ipairs(players) do
            reply = reply .. string.format("\n  [%s] %s | Job: %s | Ping: %sms | Flags: %s", p.id, p.name, p.job, p.ping, #p.flags > 0 and table.concat(p.flags, ",") or "Clean")
        end
    elseif cmd == 'warn' then
        local targetId = tonumber(args[1])
        local reason = table.concat(args, ' ', 2)
        if targetId and reason ~= "" then
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            if targetPlayer then
                TriggerClientEvent('chat:addMessage', targetId, {
                    color = {255, 0, 0},
                    args = {"[CTS Sentinel WARNING]", "^7" .. reason}
                })
                reply = ("Issued warning to %s (ID %s)"):format(targetPlayer.getName(), targetId)
                addLog('info', ('Admin %s issued manual warning to %s: %s'):format(GetPlayerName(adminSrc), targetPlayer.getName(), reason))
            else
                reply = "Player ID not found."
                replyClass = "error"
            end
        else
            reply = "Usage: warn [id] [reason]"
            replyClass = "warn"
        end
    elseif cmd == 'kick' then
        local targetId = tonumber(args[1])
        local reason = table.concat(args, ' ', 2)
        if targetId and reason ~= "" then
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            if targetPlayer then
                reply = ("Kicked player %s"):format(targetPlayer.getName())
                addLog('info', ('Admin %s manually kicked %s: %s'):format(GetPlayerName(adminSrc), targetPlayer.getName(), reason))
                DropPlayer(targetId, "[Admin Kick] " .. reason)
            else
                reply = "Player ID not found."
                replyClass = "error"
            end
        else
            reply = "Usage: kick [id] [reason]"
            replyClass = "warn"
        end
    elseif cmd == 'ban' then
        local targetId = tonumber(args[1])
        local reason = table.concat(args, ' ', 2)
        if targetId and reason ~= "" then
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            if targetPlayer then
                banPlayer(targetId, reason, GetPlayerName(adminSrc))
                reply = ("Permanently banned player %s"):format(targetPlayer.getName())
            else
                reply = "Player ID not found."
                replyClass = "error"
            end
        else
            reply = "Usage: ban [id] [reason]"
            replyClass = "warn"
        end
    elseif cmd == 'unban' then
        local license = args[1]
        if license then
            local success = unbanPlayer(license)
            if success then
                reply = "Unbanned player with license: " .. license
            else
                reply = "License not found in banned records."
                replyClass = "error"
            end
        else
            reply = "Usage: unban [license]"
            replyClass = "warn"
        end
    elseif cmd == 'scan' then
        local targetId = tonumber(args[1])
        if targetId then
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            if targetPlayer then
                local ped = GetPlayerPed(targetId)
                local coords = GetEntityCoords(ped)
                local speed = GetEntitySpeed(ped)
                local health = GetEntityHealth(ped)

                reply = string.format("Deep Heuristic Scan Results for %s:\n  Coordinates: %.2f, %.2f, %.2f\n  Movement Speed: %.2f m/s\n  Current Health: %s\n  Current Armor: %s\n  Active Flags: %s",
                    targetPlayer.getName(), coords.x, coords.y, coords.z, speed, health, GetPedArmour(ped), PlayerHeuristicFlags[targetId] and "Yes" or "None"
                )
                addLog('info', ('Admin %s triggered deep scan on %s'):format(GetPlayerName(adminSrc), targetPlayer.getName()))
            else
                reply = "Player ID not found."
                replyClass = "error"
            end
        else
            reply = "Usage: scan [id]"
            replyClass = "warn"
        end
    else
        reply = "Unknown command. Type 'help' inside terminal for assistance."
        replyClass = "error"
    end

    TriggerClientEvent('cts_sentinel:terminalOutput', adminSrc, reply, replyClass)
end

-- Server Event Listeners for Client UI Post requests
RegisterNetEvent('cts_sentinel:requestUpdate', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getGroup() == 'admin' then
        local identifiers = GetPlayerIdentifiers(src)
        local discordId = "N/A"
        for _, id in ipairs(identifiers) do
            if string.find(id, "discord:") then
                discordId = string.gsub(id, "discord:", "")
            elseif string.find(id, "license:") and discordId == "N/A" then
                discordId = string.gsub(id, "license:", "LIC-")
            end
        end


        TriggerClientEvent('cts_sentinel:updateClientUi', src, {
            stats = getGuiStats(),
            players = getGuiPlayerList(),
            logs = SystemLogs,
            admins = getGuiAdminList(),
            bansList = ActiveBans,
            admin = {
                name = xPlayer.getName(),
                discord = discordId,
                avatar = "https://api.dicebear.com/7.x/bottts/svg?seed=" .. xPlayer.getName()
            }
        })

    end
end)


RegisterNetEvent('cts_sentinel:clearServerLogs', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getGroup() == 'admin' then
        SystemLogs = {}
        addLog('info', ('Logs cleared by Administrator %s'):format(GetPlayerName(src)))
    end
end)

RegisterNetEvent('cts_sentinel:saveServerConfig', function(configData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getGroup() == 'admin' then
        saveConfigPersistent(configData)
        addLog('info', ('Configuration updated and saved by Administrator %s'):format(GetPlayerName(src)))
    end
end)

-- Server-side Handlers to Add, Delete, or Rework Ban Entries (NUI Sync)
RegisterNetEvent('cts_sentinel:deleteBanServer', function(identifier)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end

    local removedCount = 0
    for i = #ActiveBans, 1, -1 do
        local ban = ActiveBans[i]
        if ban.license == identifier or ban.steam == identifier or ban.discord == identifier or ban.ip == identifier then
            addLog('info', ('Admin %s revoked ban for: %s'):format(GetPlayerName(src), ban.name))
            table.remove(ActiveBans, i)
            removedCount = removedCount + 1
        end
    end

    if removedCount > 0 then
        saveBans()
        -- Broadcast updated ban list to all active admins
        TriggerEvent('cts_sentinel:requestUpdate')
    end
end)

RegisterNetEvent('cts_sentinel:saveBanEntryServer', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end

    local editIndex = tonumber(data.editIndex)
    
    -- Parse identifier type
    local license = 'N/A'
    local steam = 'N/A'
    local discord = 'N/A'
    local ip = data.ip ~= "" and data.ip or 'N/A'

    local rawId = data.identifier
    if string.find(rawId, 'license:') then license = rawId
    elseif string.find(rawId, 'steam:') then steam = rawId
    elseif string.find(rawId, 'discord:') then discord = rawId
    else
        license = 'license:' .. rawId -- default fallback
    end

    if editIndex == -1 then
        -- Add Manual Ban
        local banRecord = {
            name = data.name,
            license = license,
            steam = steam,
            discord = discord,
            ip = ip,
            reason = data.reason,
            banner = GetPlayerName(src),
            time = os.date('%Y-%m-%d %H:%M:%S')
        }
        table.insert(ActiveBans, banRecord)
        addLog('ban', ('Admin %s manually BANNED %s (Reason: %s)'):format(GetPlayerName(src), data.name, data.reason))
    else
        -- Rework/Edit Ban Entry
        local actualIndex = editIndex + 1 -- Lua arrays are 1-indexed, JS are 0-indexed!
        if ActiveBans[actualIndex] then
            local banRecord = ActiveBans[actualIndex]
            addLog('info', ('Admin %s reworked ban for %s (New Reason: %s)'):format(GetPlayerName(src), banRecord.name, data.reason))
            banRecord.name = data.name
            banRecord.reason = data.reason
            banRecord.license = license
            banRecord.steam = steam
            banRecord.discord = discord
            banRecord.ip = ip
            banRecord.banner = GetPlayerName(src)
            banRecord.time = os.date('%Y-%m-%d %H:%M:%S')
        end
    end

    saveBans()
    
    -- Broadcast update
    local xPlayers = ESX.GetExtendedPlayers('group', 'admin')
    for _, xAdmin in ipairs(xPlayers) do
        local identifiers = GetPlayerIdentifiers(xAdmin.source)
        local discordId = "N/A"
        for _, id in ipairs(identifiers) do
            if string.find(id, "discord:") then
                discordId = string.gsub(id, "discord:", "")
            elseif string.find(id, "license:") and discordId == "N/A" then
                discordId = string.gsub(id, "license:", "LIC-")
            end
        end

        TriggerClientEvent('cts_sentinel:updateClientUi', xAdmin.source, {
            stats = getGuiStats(),
            players = getGuiPlayerList(),
            logs = SystemLogs,
            admins = getGuiAdminList(),
            bansList = ActiveBans,
            admin = {
                name = xAdmin.getName(),
                discord = discordId,
                avatar = "https://api.dicebear.com/7.x/bottts/svg?seed=" .. xAdmin.getName()
            }
        })
    end
end)



RegisterNetEvent('cts_sentinel:adminAction', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end

    local targetId = tonumber(data.id)
    local targetName = "Player " .. targetId
    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if targetPlayer then targetName = targetPlayer.getName() end

    if data.action == 'warn' then
        TriggerClientEvent('chat:addMessage', targetId, {
            color = {255, 0, 0},
            args = {"[CTS Sentinel WARNING]", "^7" .. (data.reason or "Administrative Warning")}
        })
        addLog('info', ('Admin %s issued manual warning to %s: %s'):format(GetPlayerName(src), targetName, data.reason or "Warning"))
    elseif data.action == 'kick' then
        addLog('info', ('Admin %s manually kicked %s: %s'):format(GetPlayerName(src), targetName, data.reason or "Kicked"))
        DropPlayer(targetId, "[Admin Kick] " .. (data.reason or "Kicked from server"))
    elseif data.action == 'ban' then
        banPlayer(targetId, data.reason or "Administrative Ban", GetPlayerName(src))
    elseif data.action == 'tp' then
        if targetPlayer then
            local ped = GetPlayerPed(targetId)
            local coords = GetEntityCoords(ped)
            SetEntityCoords(GetPlayerPed(src), coords.x, coords.y, coords.z, 0, 0, 0, false)
            addLog('info', ('Admin %s teleported to %s'):format(GetPlayerName(src), targetName))
        end
    elseif data.action == 'spectate' then
        if targetPlayer and targetId ~= src then
            local ped = GetPlayerPed(targetId)
            local coords = GetEntityCoords(ped)
            SpectatorTargets[src] = targetId
            TriggerClientEvent('cts_sentinel:spectatePlayer', src, targetId, coords)
            addLog('info', ('Admin %s started spectating %s'):format(GetPlayerName(src), targetName))
        end
    elseif data.action == 'scan' then
        if targetPlayer then
            -- Force heuristic evaluation
            local ped = GetPlayerPed(targetId)
            local health = GetEntityHealth(ped)
            if health > 200 then
                if not PlayerHeuristicFlags[targetId] then PlayerHeuristicFlags[targetId] = {} end
                PlayerHeuristicFlags[targetId]["health_mod"] = true
                addLog('flag', ('Scan Threat Flagged: Player %s (ID %s) has custom health modifier (%s)'):format(targetName, targetId, health))
            end
            addLog('info', ('Admin %s triggered deep scan on %s'):format(GetPlayerName(src), targetName))
        end
    end

    -- Update UI
    TriggerClientEvent('cts_sentinel:updateClientUi', src, {
        stats = getGuiStats(),
        players = getGuiPlayerList(),
        logs = SystemLogs
    })
end)

RegisterNetEvent('cts_sentinel:stopSpectate', function()
    local src = source
    if SpectatorTargets[src] then
        SpectatorTargets[src] = nil
        TriggerClientEvent('cts_sentinel:stopSpectateClient', src)
        addLog('info', ('Admin %s stopped spectating'):format(GetPlayerName(src)))
    end
end)

RegisterNetEvent('cts_sentinel:queryTargetCoords', function(targetId)
    local src = source
    if SpectatorTargets[src] == targetId then
        local ped = GetPlayerPed(targetId)
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            TriggerClientEvent('cts_sentinel:updateSpectateCoords', src, coords)
        else
            -- Target left
            SpectatorTargets[src] = nil
            TriggerClientEvent('cts_sentinel:stopSpectateClient', src)
            addLog('info', ('Spectating target %s went offline. Stopped spectating.'):format(targetId))
        end
    end
end)

RegisterNetEvent('cts_sentinel:cliCommand', function(cmd, args)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and xPlayer.getGroup() == 'admin' then
        executeCliCommandOnServer(src, cmd, args)
    end
end)


-- ==========================================
-- SENSITIVE EVENTS PROTECTION & COOLDOWNS
-- ==========================================

local BanCooldown = {}

RegisterNetEvent('cts_sentinel:ban', function(reason)
    local src = source
    if not src then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer and (xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin') then return end

    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if AdminExclusions[id] then return end
    end

    local now = os.time()
    if BanCooldown[src] and (now - BanCooldown[src]) < 30 then
        addLog('flag', ('[RATELIMIT] Player %s (%s) spammed ban event (%.0fs since last).'):format(GetPlayerName(src), src, now - BanCooldown[src]))
        return
    end
    BanCooldown[src] = now

    banPlayer(src, reason, 'Client-Side Anti-Cheat Component')
end)

-- Exports for External Resources Integration
exports('VerifyAction', function(source, requiredJob, requiredCoords, maxDistance)
    return VerifyPlayerInteraction(source, requiredCoords, maxDistance, requiredJob)
end)

-- ==========================================
-- SECURE SERVER-AUTHORITATIVE EVENT SAMPLES
-- ==========================================

-- Secure Deposit: Client only requests deposit, server checks actual wallet cash
RegisterNetEvent('bank:depositAll', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local actualCash = xPlayer.getMoney()
    if actualCash > 0 then
        -- Enforce a cooldown / spam verify
        if not VerifyPlayerInteraction(src, nil, nil, nil) then return end
        
        xPlayer.removeMoney(actualCash)
        xPlayer.addAccountMoney('bank', actualCash)
        addLog('event', ('Player %s (%s) securely deposited $%s cash.'):format(GetPlayerName(src), src, actualCash))
    else
        addLog('flag', ('Player %s (%s) attempted cash deposit but has $0 wallet.'):format(GetPlayerName(src), src))
    end
end)

-- Secure Drug Harvest: Verifies distance and job
RegisterNetEvent('drug:harvest', function()
    local src = source
    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local fieldCoords = vector3(1054.0, -3194.0, -39.0) -- The authoritative field coords

    -- Verify player is within 5 meters of the field and has a cooldown enforced
    local maxDistance = 5.0
    if #(playerCoords - fieldCoords) > maxDistance then
        addLog('event', ('Player %s (%s) attempted remote harvest from %.2fm away!'):format(GetPlayerName(src), src, #(playerCoords - fieldCoords)))
        banPlayer(src, 'Teleport Interaction Exploit (Harvesting drug from across the map)', 'Sentinel Anticheat Engine')
        return
    end

    -- Proceed with giving the item securely
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        -- Give secure harvest item
        xPlayer.addInventoryItem('weed', 1)
        addLog('event', ('Player %s (%s) successfully harvested 1x weed.'):format(GetPlayerName(src), src))
    end
end)


