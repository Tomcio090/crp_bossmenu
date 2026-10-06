local ESX = exports["es_extended"]:getSharedObject()
local data = require('resources.duty.d_duty')
local boxs = {}

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

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
                        local jobName = ESX.PlayerData.job and ESX.PlayerData.job.name
                        return jobName and string.sub(jobName, 1, 3) == "off"
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
                        local jobName = ESX.PlayerData.job and ESX.PlayerData.job.name
                        return jobName and string.sub(jobName, 1, 3) ~= "off"
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
  for _,v in pairs(boxs) do
    if exports.ox_target:zoneExists(v) then
        exports.ox_targer:removeZone(v)
    end
  end
end)