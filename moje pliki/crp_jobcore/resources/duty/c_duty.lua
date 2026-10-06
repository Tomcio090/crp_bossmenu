local ESX = exports["es_extended"]:getSharedObject()
local data = require('resources.duty.d_duty')
local boxs = {}

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

-- Zwraca bazową nazwę pracy, ale tylko wtedy, gdy ta praca ma punkt służby w konfiguracji.
-- (wcześniej każde „off…”, np. praca „officer”, było traktowane jak służba)
local function dutyBase(jobName)
    if type(jobName) ~= 'string' or jobName == '' then return nil, false end

    local isOff = jobName:sub(1, 3) == 'off'
    local base  = isOff and jobName:sub(4) or jobName

    for _, v in pairs(data.locations) do
        if v.jobs and (v.jobs[jobName] ~= nil or v.jobs[base] ~= nil) then return base, isOff end
    end
    return nil, false
end

local function dutyState()
    local jobName = ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name
    return dutyBase(jobName)
end

CreateThread(function()
    for k, v in pairs(data.locations) do
        boxs[k] = {}
        local bid = exports.ox_target:addBoxZone({
            coords = vec3(v.coords.x, v.coords.y, v.coords.z),
            size = vec3(0.5, 0.5, 0.5),
            rotation = v.coords.w,
            debug = data.dutyDebug,
            drawSprite = true,
            options = {
                {
                    name = 'duty_enable',
                    icon = 'fa-solid fa-cube',
                    label = 'Wejdź na służbę',
                    groups = v.jobs,
                    distance = 1.5,
                    canInteract = function()
                        local base, isOff = dutyState()
                        return base ~= nil and isOff
                    end,
                    onSelect = function()
                        local updated = lib.callback.await('crp_jobcore:server:duty', false)
                        if updated then
                            exports.ox_target:disableTargeting(false)
                        end
                    end,
                },
                {
                    name = 'duty_disable',
                    icon = 'fa-solid fa-cube',
                    label = 'Zejdź ze służby',
                    groups = v.jobs,
                    distance = 1.5,
                    canInteract = function()
                        local base, isOff = dutyState()
                        return base ~= nil and not isOff
                    end,
                    onSelect = function()
                        local updated = lib.callback.await('crp_jobcore:server:duty', false)
                        if updated then
                            exports.ox_target:disableTargeting(false)
                        end
                    end,
                },
            }
        })
        table.insert(boxs[k], bid)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    for _, list in pairs(boxs) do
        for _, zoneId in ipairs(list) do
            -- było: `exports.ox_targer:removeZone(v)` (literówka) + przekazanie tabeli zamiast id strefy,
            -- więc strefy nigdy nie były usuwane
            if exports.ox_target:zoneExists(zoneId) then
                exports.ox_target:removeZone(zoneId)
            end
        end
    end
end)
