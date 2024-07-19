local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------
-- law test alert
------------------------------------------
RSGCore.Commands.Add("testalert", "send test alert", {}, false, function(source)
    local src = source
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local text = "testing"
    TriggerClientEvent('rsg-lawman:client:lawmanAlert', src, playerCoords, text)
end)

------------------------------------------
-- law badge
------------------------------------------
RSGCore.Commands.Add('lawbadge', 'put on / take off badge', {}, false, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local jobname = Player.PlayerData.job.name
    local onduty = Player.PlayerData.job.onduty
    if onduty and jobname == 'vallaw' or jobname == 'rholaw' or jobname == 'blklaw' or jobname == 'strlaw' or jobname == 'stdenlaw' then
        TriggerClientEvent('rsg-lawman:client:lawbadge', src)
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Need to be on duty', type = 'error', duration = 5000 })
    end
end)

------------------------------------------
-- law on-duty callback
------------------------------------------
RSGCore.Functions.CreateCallback('rsg-lawman:server:getlaw', function(source, cb)
    local lawcount = 0
    local players = RSGCore.Functions.GetRSGPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            lawcount = lawcount + 1
        end
    end
    cb(lawcount)
end)

-- Add 'unjail' command
RSGCore.Commands.Add("unjail", "Release a player from jail", {{name = "id", help = "Player ID"}}, true, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    -- Check if the player issuing the command is a law enforcement officer
    if Player.PlayerData.job.type == "leo" then
        local playerId = tonumber(args[1])
        
        if playerId then
            local TargetPlayer = RSGCore.Functions.GetPlayer(playerId)
            
            if TargetPlayer then
                -- Trigger the unjail event for the target player
                TriggerClientEvent('rsg-prison:client:freedom', TargetPlayer.PlayerData.source)
                
                -- Notify the player issuing the command
                TriggerClientEvent('ox_lib:notify', src, {
                    title = "Unjail Success",
                    description = "Player has been successfully released from jail.",
                    type = 'success',
                    duration = 5000
                })
                
                -- Optionally notify the target player
                TriggerClientEvent('ox_lib:notify', TargetPlayer.PlayerData.source, {
                    title = "You Have Been Released",
                    description = "You have been released from jail by a law enforcement officer.",
                    type = 'success',
                    duration = 5000
                })
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = "Unjail Error",
                    description = "Player ID not found.",
                    type = 'error',
                    duration = 5000
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = "Unjail Error",
                description = "Invalid player ID.",
                type = 'error',
                duration = 5000
            })
        end
    else
        -- Notify the player issuing the command if they're not a law enforcement officer
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Unjail Error",
            description = "You do not have permission to use this command.",
            type = 'error',
            duration = 5000
        })
    end
end)


--------------------------------------------------------------------------------------------------
-- lawman alert
--------------------------------------------------------------------------------------------------

RegisterNetEvent('rsg-lawman:server:lawmanAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = RSGCore.Functions.GetRSGPlayers()

    for _, v in pairs(players) do
        if v.PlayerData.job.type == 'leo' and v.PlayerData.job.onduty then
            TriggerClientEvent('rsg-lawman:client:lawmanAlert', v.PlayerData.source, coords, text)
        end
    end
end)

--------------------------------------------------------------------------------------------------
-- jail player command (law only)
--------------------------------------------------------------------------------------------------
RSGCore.Commands.Add('jail', Lang:t('lang20'), {{name = 'id', help =  Lang:t('lang21')}, {name = 'time', help = Lang:t('lang22')}}, true, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
        if Player.PlayerData.job.type == 'leo' then
            local playerId = tonumber(args[1])
            local time = tonumber(args[2])
            if time > 0 then
                TriggerClientEvent('rsg-lawman:client:jailplayer', src, playerId, time)
            else
                TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('lang23'), description = Lang:t('lang24'), type = 'inform', duration = 5000 })
            end
        end
end)

--------------------------------------------------------------------------------------------------
-- jail player
--------------------------------------------------------------------------------------------------
RegisterNetEvent('rsg-lawman:server:jailplayer', function(playerId, time)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local OtherPlayer = RSGCore.Functions.GetPlayer(playerId)
    local currentDate = os.date("*t")
    if currentDate.day == 31 then
        currentDate.day = 30
    end

        if Player.PlayerData.job.type == 'leo' then
            if OtherPlayer then
                OtherPlayer.Functions.SetMetaData('injail', time)
                OtherPlayer.Functions.SetMetaData('criminalrecord', { ['hasRecord'] = true, ['date'] = currentDate })
                TriggerClientEvent('rsg-lawman:client:sendtojail', OtherPlayer.PlayerData.source, time)
                TriggerClientEvent('ox_lib:notify', src, {title =  Lang:t('lang25')..time, type = 'success', duration = 5000 })
            end
        end
end)

--------------------------------------------------------------------------------------------------
-- lawman tash can collection system
--------------------------------------------------------------------------------------------------
UpkeepInterval = function()
    local result = MySQL.query.await('SELECT * FROM stashitems LIMIT 1')

    if not result or not result[1] then
        return
    end

    local stash = result[1].stash
    local items = result[1].items

    if stash == 'lawtrashcan' and items == '[]' then 
        if Config.Debug then
            print('trash already taken out')
        end
        return 
    end

    MySQL.update('UPDATE stashitems SET items = ? WHERE stash = ?',{ '[]', 'lawtrashcan' })

    if Config.Debug then
        print('law trash removal complete')
    end

    ::continue::

    SetTimeout(Config.TrashCollection * (60 * 1000), UpkeepInterval)
end

SetTimeout(Config.TrashCollection * (60 * 1000), UpkeepInterval)

------------------------------------------
-- handcuff player command
------------------------------------------
RSGCore.Commands.Add('cuff',  Lang:t('lang26'), {}, false, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
        if Player.PlayerData.job.type == 'leo' then
            TriggerClientEvent('rsg-lawman:client:cuffplayer', src)
        end
end)

------------------------------------------
-- handcuff player use
------------------------------------------
RSGCore.Functions.CreateUseableItem('handcuffs', function(source, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player.Functions.GetItemByName(item.name) then
        TriggerClientEvent('rsg-lawman:client:cuffplayer', src)
    end
end)

------------------------------------------
-- handcuff player
------------------------------------------
RegisterNetEvent('rsg-lawman:server:cuffplayer', function(playerId, isSoftcuff)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' then
        local CuffedPlayer = RSGCore.Functions.GetPlayer(playerId)
        if CuffedPlayer then
            if Player.Functions.GetItemByName('handcuffs') then
                TriggerClientEvent('rsg-lawman:client:getcuffed', CuffedPlayer.PlayerData.source, Player.PlayerData.source, isSoftcuff)
            end
        end
    end
end)

------------------------------------------
-- set handcuff status
------------------------------------------
RegisterNetEvent('rsg-lawman:server:sethandcuffstatus', function(isHandcuffed)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.SetMetaData('ishandcuffed', isHandcuffed)
    end
end)

------------------------------------------
-- escort player command
------------------------------------------
RSGCore.Commands.Add('escort', Lang:t('lang27'), {}, false, function(source, args)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.type == 'leo' then
        TriggerClientEvent('rsg-lawman:client:escortplayer', src)
    end
end)

------------------------------------------
-- set escort status
------------------------------------------
RegisterNetEvent('rsg-lawman:server:setescortstatus', function(isEscorted)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.SetMetaData('isescorted', isEscorted)
    end
end)

------------------------------------------
-- escort player
------------------------------------------
RegisterNetEvent('rsg-lawman:server:escortplayer', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == 'leo' then
        local EscortPlayer = RSGCore.Functions.GetPlayer(playerId)
        if EscortPlayer then
            if (EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead']) then
                TriggerClientEvent('rsg-lawman:client:getescorted', EscortPlayer.PlayerData.source, Player.PlayerData.source)
            else
                lib.notify({ title = Lang:t('lang28'), type = 'error', duration = 5000 })
            end
        end
    end
end)
