-- ═════════════════════════════════════════════════════════════
--  KLIENT – otwieranie panelu, most NUI <-> serwer
-- ═════════════════════════════════════════════════════════════
local ESX = exports['es_extended']:getSharedObject()
local isOpen = false
local pending, nextId = {}, 0

-- ───────── otwieranie / zamykanie ─────────
local function closeUI(notifyServer)
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if notifyServer ~= false then TriggerServerEvent('crp_bossmenu:server:close') end
end

RegisterNetEvent('crp_bossmenu:client:open', function(data)
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('crp_bossmenu:client:update', function(data)
    if isOpen then SendNUIMessage({ action = 'update', data = data }) end
end)

RegisterNetEvent('crp_bossmenu:client:forceClose', function() closeUI(false) end)

RegisterNetEvent('crp_bossmenu:client:notify', function(text, tone)
    if isOpen then
        SendNUIMessage({ action = 'notify', text = text, tone = tone })
    else
        ESX.ShowNotification(text)
    end
end)

RegisterNUICallback('bossmenu:close', function(_, cb)
    closeUI()
    cb({})
end)

-- ───────── żądania z UI -> serwer ─────────
local EVENTS = {
    'setGrade', 'hire', 'fire', 'setBadge', 'addRecord', 'voidRecord', 'setLicense', 'resetHours', 'resetAllHours', 'setNote',
    'setSalary', 'setWebhooks', 'testWebhook', 'deposit', 'withdraw',
    'orderVehicles', 'cancelOrder', 'assignVehicle', 'revokeVehicle',
    'orderGoods', 'supplierOrder', 'saveProduct', 'deleteProduct'
}

for _, name in ipairs(EVENTS) do
    RegisterNUICallback('bossmenu:' .. name, function(data, cb)
        nextId = nextId + 1
        local id = nextId
        pending[id] = cb
        TriggerServerEvent('crp_bossmenu:server:req', id, name, data)
        SetTimeout(15000, function()
            if pending[id] then
                pending[id]({ ok = false, error = 'Brak odpowiedzi serwera' })
                pending[id] = nil
            end
        end)
    end)
end

RegisterNetEvent('crp_bossmenu:client:res', function(id, res)
    local cb = pending[id]
    if cb then pending[id] = nil; cb(res or { ok = false }) end
end)

-- ───────── komenda / export ─────────
if Config.Command then
    RegisterCommand(Config.Command, function() TriggerServerEvent('crp_bossmenu:server:open') end, false)
end
exports('Open', function() TriggerServerEvent('crp_bossmenu:server:open') end)

-- ───────── punkty (marker + [E]) ─────────
local function canSee(loc)
    local job = ESX.PlayerData and ESX.PlayerData.job
    if not job or job.name ~= loc.job then return false end
    local jc = Config.Jobs[loc.job]
    if not jc then return false end
    if jc.minGrade then return job.grade >= jc.minGrade end
    return job.grade_name == Config.BossGradeName
end

CreateThread(function()
    if #Config.Locations == 0 then return end
    while true do
        local sleep = 800
        if not isOpen then
            local pos = GetEntityCoords(PlayerPedId())
            for _, loc in ipairs(Config.Locations) do
                local dist = #(pos - loc.coords)
                if dist < 12.0 and canSee(loc) then
                    sleep = 0
                    DrawMarker(2, loc.coords.x, loc.coords.y, loc.coords.z + 0.1, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 0.3, 0.3, 0.3, 252, 68, 68, 160, false, true, 2, false, nil, nil, false)
                    if dist < (loc.radius or 2.0) then
                        ESX.ShowHelpNotification('Naciśnij ~INPUT_CONTEXT~, aby otworzyć panel zarządzania')
                        if IsControlJustReleased(0, Config.InteractKey) then TriggerServerEvent('crp_bossmenu:server:open') end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Zmiana pracy zamyka panel (serwer i tak weryfikuje uprawnienia przy każdej akcji)
RegisterNetEvent('esx:setJob', function() closeUI() end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end end)
