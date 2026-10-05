--[[
    c_main.lua – klient bossmenu

    1. Punkty w Config.Locations: strefa ox_target „Otwórz Boss Menu”.
    2. Po wybraniu: animacja siadania na krzesło -> [G] komputer -> panel (NUI).
    3. Panel otwiera się danymi z serwera ('crp_bossmenu:client:open'), a zamknięcie wraca na krzesło.

    Protokół NUI (bez zmian, Twój interfejs działa jak wcześniej):
      serwer -> NUI: { action = 'open'|'update'|'close'|'notify', ... }
      NUI -> serwer: 'bossmenu:<akcja>' (setGrade, fire, addRecord, deposit, ...)
]]

-- zabezpieczenie przed podwójnym załadowaniem (np. fxmanifest + require)
if _G.crp_bossmenu_c_main then return {} end
_G.crp_bossmenu_c_main = true

local Config = require('resources.bossmenu.d_bossmenu')
local ESX = exports['es_extended']:getSharedObject()

local points = {}
local chairModel = `sf_prop_sf_offchair_exec_01a`
local animDict = 'anim@scripted@player@fix_agy_ig6_office_chair_entry@right@male@'

-- stan panelu
local uiOpen = false        -- okno NUI otwarte
local activePoint           -- punkt, z którego otwarto panel (żeby wrócić na krzesło)
local awaitingOpen = false  -- czekamy na zgodę serwera


-- ═════════════════════════════════════════════════════════════
--  PANEL (NUI)
-- ═════════════════════════════════════════════════════════════
local function resumeChair(point)
    if point and point.isSeated then point:playComputerExit() end
end

local function closePanel(fromServer)
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if not fromServer then TriggerServerEvent('crp_bossmenu:server:close') end

    local point = activePoint
    activePoint = nil
    resumeChair(point)
end

local function requestOpen(point)
    awaitingOpen = true
    activePoint = point
    TriggerServerEvent('crp_bossmenu:server:open')

    -- serwer nie odpowiedział (brak uprawnień / błąd) – wracamy na krzesło
    SetTimeout(2500, function()
        if awaitingOpen then
            awaitingOpen = false
            resumeChair(point)
        end
    end)
end

RegisterNetEvent('crp_bossmenu:client:open', function(payload)
    if uiOpen or not awaitingOpen then return end
    awaitingOpen = false
    uiOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = payload })
end)

RegisterNetEvent('crp_bossmenu:client:update', function(payload)
    if uiOpen then SendNUIMessage({ action = 'update', data = payload }) end
end)

RegisterNetEvent('crp_bossmenu:client:forceClose', function()
    awaitingOpen = false
    if uiOpen then
        closePanel(true)
    else
        local point = activePoint
        activePoint = nil
        resumeChair(point)
    end
end)

RegisterNetEvent('crp_bossmenu:client:notify', function(text, tone)
    if uiOpen then
        SendNUIMessage({ action = 'notify', text = text, tone = tone })
    else
        ESX.ShowNotification(text)
    end
end)

-- ── NUI -> serwer ──
local ACTIONS = {
    'setGrade', 'hire', 'fire', 'setBadge', 'addRecord', 'voidRecord', 'setLicense', 'resetHours', 'resetAllHours', 'setNote',
    'setSalary', 'setWebhooks', 'testWebhook', 'deposit', 'withdraw',
    'orderVehicles', 'cancelOrder', 'assignVehicle', 'revokeVehicle',
    'orderGoods', 'supplierOrder', 'saveProduct', 'deleteProduct'
}

local pending, nextId = {}, 0

RegisterNUICallback('bossmenu:close', function(_, cb)
    closePanel(false)
    cb({})
end)

for _, action in ipairs(ACTIONS) do
    RegisterNUICallback('bossmenu:' .. action, function(data, cb)
        nextId = nextId + 1
        local id = nextId
        pending[id] = cb
        TriggerServerEvent('crp_bossmenu:server:req', id, action, data)

        SetTimeout(15000, function()
            if pending[id] then
                pending[id]({ ok = false, error = 'Brak odpowiedzi serwera' })
                pending[id] = nil
            end
        end)
    end)
end

RegisterNetEvent('crp_bossmenu:client:res', function(id, result)
    local cb = pending[id]
    if cb then
        pending[id] = nil
        cb(result or { ok = false })
    end
end)

-- ── komenda / export ──
if Config.Command then
    RegisterCommand(Config.Command, function() requestOpen(nil) end, false)
end
exports('Open', function() requestOpen(nil) end)


-- ═════════════════════════════════════════════════════════════
--  PUNKTY + ANIMACJA KRZESŁA
-- ═════════════════════════════════════════════════════════════
if ESX.IsPlayerLoaded() then
    ESX.PlayerData = ESX.GetPlayerData()
end

RegisterNetEvent('esx:playerLoaded', function(xPlayer) ESX.PlayerData = xPlayer end)
RegisterNetEvent('esx:setJob', function(job)
    ESX.PlayerData.job = job
    if uiOpen then closePanel(false) end
end)

local function waitForScenePhase(scene, point)
    local timeout = GetGameTimer() + 10000
    while GetSynchronizedScenePhase(scene) < 0.99 and GetGameTimer() < timeout do
        if point and not point.isSeated then return false end
        Wait(0)
    end
    return true
end

CreateThread(function()
    for name, loc in pairs(Config.Locations) do
        points[name] = lib.points.new({
            coords = vec3(loc.mcoords.x, loc.mcoords.y, loc.mcoords.z),
            distance = loc.distance or 20.0,
            job = loc.job,
            bossmenucoords = loc.bossmenucoords,
            chaircoords = loc.chaircoords,
            debug = Config.Debug,

            spawnChair = function(self)
                if self.chairEntity and DoesEntityExist(self.chairEntity) then
                    DeleteEntity(self.chairEntity)
                end

                local c = self.chaircoords
                local heading = c.w or c.heading or 0.0

                self.chairEntity = CreateObjectNoOffset(chairModel, c.x, c.y, c.z, false, false, false)
                SetEntityHeading(self.chairEntity, heading)
                FreezeEntityPosition(self.chairEntity, true)
                SetEntityInvincible(self.chairEntity, true)
            end,

            playBaseScene = function(self)
                local ped = cache.ped or PlayerPedId()

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local baseScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneLooped(baseScene, true)

                TaskSynchronizedScene(ped, baseScene, animDict, 'base', 4.0, -2.0, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, baseScene, 'base_chair', animDict, 4.0, -1.0, 0, 1148846080)
            end,

            startControls = function(self)
                lib.showTextUI('[E] - Wstań z krzesła  \n[G] - Użyj Boss Menu', {
                    position = 'left-center',
                    icon = 'chair'
                })

                CreateThread(function()
                    while self.isSeated and not self.isAtComputer do
                        Wait(0)
                        if IsControlJustPressed(0, 38) then
                            self:playExitAnimation()
                            break
                        elseif IsControlJustPressed(0, 47) then
                            self:playComputerSequence()
                            break
                        end
                    end
                end)
            end,

            onEnter = function(self)
                if not lib.requestModel(chairModel, 3000) then return end

                self:spawnChair()

                local zone = self.bossmenucoords
                self.targetId = exports.ox_target:addBoxZone({
                    coords = vec3(zone.x, zone.y, zone.z),
                    size = vec3(1.0, 1.0, 1.0),
                    rotation = zone.w or zone.heading or 0.0,
                    debug = self.debug,
                    options = {
                        {
                            name = 'bossmenu_zone_' .. self.id,
                            icon = 'fas fa-user-tie',
                            label = 'Otwórz Boss Menu',
                            canInteract = function()
                                local job = ESX.PlayerData.job
                                return job and job.name == self.job and not self.isSeated
                            end,
                            onSelect = function()
                                self:playChairAnimationAndOpenMenu()
                            end
                        }
                    }
                })
            end,

            onExit = function(self)
                if self.isSeated then
                    lib.hideTextUI()
                    self.isSeated = false
                    self.isAtComputer = false
                    ClearPedTasks(cache.ped or PlayerPedId())
                end

                if self.targetId then
                    exports.ox_target:removeZone(self.targetId)
                    self.targetId = nil
                end

                if self.chairEntity and DoesEntityExist(self.chairEntity) then
                    DeleteEntity(self.chairEntity)
                    self.chairEntity = nil
                end
            end,

            playChairAnimationAndOpenMenu = function(self)
                if self.isSeated or uiOpen then return end
                self.isSeated = true
                self.isAtComputer = false

                local ped = cache.ped or PlayerPedId()

                if not lib.requestAnimDict(animDict, 3000) then
                    self.isSeated = false
                    return
                end

                SetEntityNoCollisionEntity(ped, self.chairEntity, false)

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local enterScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(enterScene, true)

                TaskSynchronizedScene(ped, enterScene, animDict, 'enter', 1.5, -1.5, 13, 16, 1.5, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, enterScene, 'enter_chair', animDict, 4.0, -4.0, 0, 1148846080)

                if not waitForScenePhase(enterScene, self) then return end

                self:playBaseScene()
                self:startControls()
            end,

            playComputerSequence = function(self)
                if not self.isSeated or self.isAtComputer then return end
                self.isAtComputer = true

                lib.hideTextUI()

                local ped = cache.ped or PlayerPedId()
                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local enterScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(enterScene, true)

                TaskSynchronizedScene(ped, enterScene, animDict, 'computer_enter', 4.0, -1.5, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, enterScene, 'computer_enter_chair', animDict, 4.0, -4.0, 0, 1148846080)

                if not waitForScenePhase(enterScene, self) then
                    if self.isSeated then
                        self.isAtComputer = false
                        self:playBaseScene()
                        self:startControls()
                    end
                    return
                end

                chairPos = GetEntityCoords(self.chairEntity)
                chairRot = GetEntityRotation(self.chairEntity, 2)

                local idleScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneLooped(idleScene, true)

                TaskSynchronizedScene(ped, idleScene, animDict, 'computer_idle', 4.0, -1.5, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, idleScene, 'computer_idle_chair', animDict, 4.0, -4.0, 0, 1148846080)

                -- panel otwiera się, gdy serwer przyśle dane ('client:open');
                -- zamknięcie panelu samo wraca na krzesło (playComputerExit)
                requestOpen(self)
            end,

            playComputerExit = function(self)
                if not self.isSeated or not self.chairEntity or not DoesEntityExist(self.chairEntity) then
                    self.isAtComputer = false
                    return
                end

                local ped = cache.ped or PlayerPedId()
                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local exitScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(exitScene, true)

                TaskSynchronizedScene(ped, exitScene, animDict, 'computer_exit', 4.0, -1.5, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, exitScene, 'computer_exit_chair', animDict, 4.0, -4.0, 0, 1148846080)

                if not waitForScenePhase(exitScene, self) then return end
                if not self.isSeated then return end

                self.isAtComputer = false
                self:playBaseScene()
                self:startControls()
            end,

            playExitAnimation = function(self)
                local ped = cache.ped or PlayerPedId()

                lib.hideTextUI()

                if not lib.requestAnimDict(animDict, 3000) then
                    self.isSeated = false
                    self.isAtComputer = false
                    ClearPedTasks(ped)
                    self:spawnChair()
                    return
                end

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                if self.isAtComputer then
                    local compExit = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                    SetSynchronizedSceneHoldLastFrame(compExit, true)

                    TaskSynchronizedScene(ped, compExit, animDict, 'computer_exit', 4.0, -1.5, 13, 16, 1000.0, 0)
                    PlaySynchronizedEntityAnim(self.chairEntity, compExit, 'computer_exit_chair', animDict, 4.0, -4.0, 0, 1148846080)

                    waitForScenePhase(compExit, self)

                    chairPos = GetEntityCoords(self.chairEntity)
                    chairRot = GetEntityRotation(self.chairEntity, 2)
                end

                local exitScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(exitScene, true)

                TaskSynchronizedScene(ped, exitScene, animDict, 'exit', 4.0, -4.0, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, exitScene, 'exit_chair', animDict, 4.0, -4.0, 0, 1148846080)

                waitForScenePhase(exitScene, self)

                ClearPedTasks(ped)
                SetEntityNoCollisionEntity(ped, self.chairEntity, true)

                self:spawnChair()

                self.isSeated = false
                self.isAtComputer = false
            end
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if uiOpen then SetNuiFocus(false, false) end

    for _, point in pairs(points) do
        if point.isSeated then
            lib.hideTextUI()
            ClearPedTasks(cache.ped or PlayerPedId())
        end
        if point.targetId then exports.ox_target:removeZone(point.targetId) end
        if point.chairEntity and DoesEntityExist(point.chairEntity) then DeleteEntity(point.chairEntity) end
    end
end)

return {}
