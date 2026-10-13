local ESX = exports['es_extended']:getSharedObject()
local isOpen = false
local isSpectating = false
local spectateTarget = nil
local spectatePrevCoords = nil

-- Standard event to open the UI
RegisterNetEvent('cts_sentinel:openUi', function(serverData)
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'show'
    })
    SendNUIMessage({
        type = 'updateData',
        stats = serverData.stats,
        players = serverData.players,
        logs = serverData.logs,
        admins = serverData.admins,
        admin = serverData.admin,
        bansList = serverData.bansList
    })
end)


-- NUI callbacks
RegisterNUICallback('closeUi', function(data, cb)
    SetNuiFocus(false, false)
    isOpen = false
    SendNUIMessage({
        type = 'hide'
    })
    cb('ok')
end)

RegisterNUICallback('refreshPlayers', function(data, cb)
    TriggerServerEvent('cts_sentinel:requestUpdate')
    cb('ok')
end)

RegisterNUICallback('playerAction', function(data, cb)
    TriggerServerEvent('cts_sentinel:adminAction', data)
    cb('ok')
end)

RegisterNUICallback('stopSpectating', function(data, cb)
    TriggerServerEvent('cts_sentinel:stopSpectate')
    cb('ok')
end)

RegisterNUICallback('triggerDeepScan', function(data, cb)
    TriggerServerEvent('cts_sentinel:requestUpdate')
    cb('ok')
end)

RegisterNUICallback('executeCliCommand', function(data, cb)
    TriggerServerEvent('cts_sentinel:cliCommand', data.cmd, data.args)
    cb('ok')
end)

RegisterNUICallback('clearLogs', function(data, cb)
    TriggerServerEvent('cts_sentinel:clearServerLogs')
    cb('ok')
end)

RegisterNUICallback('saveConfig', function(data, cb)
    TriggerServerEvent('cts_sentinel:saveServerConfig', data)
    cb('ok')
end)

RegisterNUICallback('deleteBanEntry', function(data, cb)
    TriggerServerEvent('cts_sentinel:deleteBanServer', data.identifier)
    cb('ok')
end)

RegisterNUICallback('saveBanEntry', function(data, cb)
    TriggerServerEvent('cts_sentinel:saveBanEntryServer', data)
    cb('ok')
end)



-- Receive direct UI updates from server
RegisterNetEvent('cts_sentinel:updateClientUi', function(serverData)
    if isOpen then
        SendNUIMessage({
            type = 'updateData',
            stats = serverData.stats,
            players = serverData.players,
            logs = serverData.logs,
            admins = serverData.admins,
            admin = serverData.admin,
            bansList = serverData.bansList
        })
    end
end)


-- Administrative Spectating Implementation
RegisterNetEvent('cts_sentinel:spectatePlayer', function(targetId, targetCoords)
    local playerPed = PlayerPedId()
    if not isSpectating then
        isSpectating = true
        spectateTarget = targetId
        spectatePrevCoords = GetEntityCoords(playerPed)
        
        SendNUIMessage({
            type = 'spectateStart',
            targetId = targetId,
            targetName = 'Player ' .. targetId
        })

        -- Hide the dashboard UI if open
        if isOpen then
            SetNuiFocus(false, false)
            isOpen = false
            SendNUIMessage({ type = 'hide' })
        end

        RequestCollisionAtCoord(targetCoords.x, targetCoords.y, targetCoords.z)
        SetEntityVisible(playerPed, false, 0)
        SetEntityCollision(playerPed, false, false)
        SetEntityInvincible(playerPed, true)
        SetEntityCoords(playerPed, targetCoords.x, targetCoords.y, targetCoords.z - 10.0, 0, 0, 0, false)
        
        CreateThread(function()
            while isSpectating do
                Wait(500)
                local targetPed = GetPlayerPed(GetPlayerFromServerId(spectateTarget))
                if targetPed and targetPed ~= 0 then
                    -- Attach to target entity or position camera
                    local coords = GetEntityCoords(targetPed)
                    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z - 3.0, 0, 0, 0, false)
                    if not NetworkIsInSpectatorMode() then
                        NetworkSetInSpectatorMode(true, targetPed)
                    end
                else
                    -- Try to query target coordinates again from server
                    TriggerServerEvent('cts_sentinel:queryTargetCoords', spectateTarget)
                end
            end
        end)
    end
end)

RegisterNetEvent('cts_sentinel:updateSpectateCoords', function(coords)
    if isSpectating then
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z - 3.0, 0, 0, 0, false)
    end
end)

RegisterNetEvent('cts_sentinel:stopSpectateClient', function()
    if isSpectating then
        isSpectating = false
        spectateTarget = nil
        NetworkSetInSpectatorMode(false, 0)
        
        local playerPed = PlayerPedId()
        SetEntityVisible(playerPed, true, 0)
        SetEntityCollision(playerPed, true, true)
        SetEntityInvincible(playerPed, false)
        
        if spectatePrevCoords then
            SetEntityCoords(playerPed, spectatePrevCoords.x, spectatePrevCoords.y, spectatePrevCoords.z, 0, 0, 0, false)
        end
        
        SendNUIMessage({
            type = 'spectateStop'
        })

        -- Seamlessly re-open the administrative Sentinel panel after spectating ends
        Wait(500)
        TriggerServerEvent('cts_sentinel:requestUpdate')
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ type = 'show' })
    end
end)


-- Key listener to stop spectating with 'E'
CreateThread(function()
    while true do
        Wait(100)
        if isSpectating then
            DisableControlAction(0, 38, true)
            if IsDisabledControlJustPressed(0, 38) then
                TriggerServerEvent('cts_sentinel:stopSpectate')
            end
        end
    end
end)


-- ==========================================
-- CLIENT ENVIRONMENT DETECTION (ANTIPROBE)
-- ==========================================

-- Check global _G namespace for blacklisted cheat indicators
local BlacklistedG = {
    "F8Trigger", "d0pamine", "Absolute", "HamMafia", "EulenCheats", "LynxMenu", 
    "Furious", "LuxMenu", "TiagoCheats", "BrutanCheats", "Dopamine", "SkidMenu", 
    "Injected", "CheatEngine", "imgui", "ImGui", "RunCode", "LumiaMenu", "Fallout",
    "PlutoMenu", "Unreallite", "ShitMenu", "RedEngine", "ReboundMenu", "AlphaMenu"
}

CreateThread(function()
    while true do
        Wait(5000)
        
        -- 1. _G Scanner
        for _, varName in ipairs(BlacklistedG) do
            if _G[varName] ~= nil then
                TriggerServerEvent('cts_sentinel:ban', 'Client Injection detected (Global variable violation: ' .. varName .. ')')
                break
            end
        end

        -- 2. Anti-Spectate Check (Force normal players out of spectate)
        if NetworkIsInSpectatorMode() and not isSpectating then
            ESX.TriggerServerCallback('cts_sentinel:isAdmin', function(isAdmin)
                if not isAdmin then
                    TriggerServerEvent('cts_sentinel:ban', 'Unauthorized Spectator Mode active')
                end
            end)
        end

        -- 3. Godmode Check
        local playerPed = PlayerPedId()
        if GetPlayerInvincible(PlayerId()) and not IsEntityDead(playerPed) and not isSpectating then
            ESX.TriggerServerCallback('cts_sentinel:isAdmin', function(isAdmin)
                if not isAdmin then
                    -- Double verification: Damage player to see if health decreases
                    local health = GetEntityHealth(playerPed)
                    ApplyDamageToPed(playerPed, 2, false)
                    Wait(50)
                    if GetEntityHealth(playerPed) == health then
                        TriggerServerEvent('cts_sentinel:ban', 'Physical Godmode vulnerability exploit')
                    else
                        SetEntityHealth(playerPed, health) -- Restore
                    end
                end
            end)
        end
    end
end)


-- ==========================================
-- HEURISTIC PHYSICS ANOMALY DETECTIONS
-- ==========================================

local lastCoords = nil
local lastCheckTime = 0

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if ped and ped ~= 0 and not IsEntityDead(ped) then
            local coords = GetEntityCoords(ped)
            local now = GetGameTimer()
            
            -- Detect physical speed/teleport anomaly on foot
            if not IsPedInAnyVehicle(ped, true) and not isSpectating then
                local currentSpeed = GetEntitySpeed(ped)
                
                -- Standard maximum sprint speed is ~9.0 m/s
                if currentSpeed > 15.0 and not IsPedFalling(ped) and not IsPedParachuting(ped) then
                    ESX.TriggerServerCallback('cts_sentinel:isAdmin', function(isAdmin)
                        if not isAdmin then
                            TriggerServerEvent('cts_sentinel:ban', 'Heuristic Speedhack detection (speed: ' .. string.format("%.2f", currentSpeed) .. ' m/s)')
                        end
                    end)
                end
                
                -- Check teleport distance (distance traveled in 1 second)
                if lastCoords and lastCheckTime > 0 then
                    local timeDiff = (now - lastCheckTime) / 1000.0
                    local dist = #(coords - lastCoords)
                    
                    -- If traveled more than 45 meters on foot in 1 second, flag as teleport
                    if dist > 45.0 and timeDiff < 1.5 and not IsPedFalling(ped) then
                        ESX.TriggerServerCallback('cts_sentinel:isAdmin', function(isAdmin)
                            if not isAdmin then
                                TriggerServerEvent('cts_sentinel:ban', 'Heuristic Teleportation anomaly (traveled: ' .. string.format("%.2f", dist) .. 'm in ' .. string.format("%.2f", timeDiff) .. 's)')
                            end
                        end)
                    end
                end
            end

            lastCoords = coords
            lastCheckTime = now

            -- Health and armor freeze detection (Subtle godmode hackings)
            local currentHealth = GetEntityHealth(ped)
            local currentArmor = GetPedArmour(ped)
            
            if currentHealth > 200 then
                ESX.TriggerServerCallback('cts_sentinel:isAdmin', function(isAdmin)
                    if not isAdmin then
                        TriggerServerEvent('cts_sentinel:ban', 'Entity Health Modifier injection (health value: ' .. currentHealth .. ')')
                    end
                end)
            end
        end
    end
end)


-- ==========================================
-- BLACKLIST WEAPONS & AMMO SCANNING
-- ==========================================

local BlacklistedWeapons = {
    [`WEAPON_MINIGUN`] = "Minigun",
    [`WEAPON_RPG`] = "RPG Rocket Launcher",
    [`WEAPON_RAILGUN`] = "Railgun Particle Cannon",
    [`WEAPON_HOMINGLAUNCHER`] = "Homing Rocket Launcher",
    [`WEAPON_COMPACTLAUNCHER`] = "Compact Grenade Launcher",
    [`WEAPON_FIREWORK`] = "Firework Launcher",
}

CreateThread(function()
    while true do
        Wait(2000)
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            local currentWeapon = GetSelectedPedWeapon(ped)
            if BlacklistedWeapons[currentWeapon] then
                ESX.TriggerServerCallback('cts_sentinel:isAdmin', function(isAdmin)
                    if not isAdmin then
                        RemoveWeaponFromPed(ped, currentWeapon)
                        TriggerServerEvent('cts_sentinel:ban', 'Possession of military-restricted blacklisted weapon: ' .. BlacklistedWeapons[currentWeapon])
                    end
                end)
            end
        end
    end
end)

-- Heuristic Weapon Shooting Rate Limiter (Anomaly Detection)
local lastShootTime = 0
CreateThread(function()
    while true do
        Wait(100)
        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            local now = GetGameTimer()
            local currentWeapon = GetSelectedPedWeapon(ped)
            
            if currentWeapon == `WEAPON_PISTOL` or currentWeapon == `WEAPON_COMBATPISTOL` or currentWeapon == `WEAPON_APPISTOL` then
                if lastShootTime > 0 then
                    local diff = now - lastShootTime
                    if diff < 55 then
                        ESX.TriggerServerCallback('cts_sentinel:isAdmin', function(isAdmin)
                            if not isAdmin then
                                TriggerServerEvent('cts_sentinel:ban', 'Heuristic Rapid-fire cheat detected (firing rate anomaly on semi-auto weapon)')
                            end
                        end)
                    end
                end
                lastShootTime = now
            end
        end
    end
end)

