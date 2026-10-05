local ESX = exports["es_extended"]:getSharedObject()
local data = require('resources.bossmenu.d_bossmenu')
local ui = require('modules.ui.c_ui')

local points = {}
local chairModel = `sf_prop_sf_offchair_exec_01a`
local animDict = "anim@scripted@player@fix_agy_ig6_office_chair_entry@right@male@"

if ESX.IsPlayerLoaded() then
    ESX.PlayerData = ESX.GetPlayerData()
end

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    ESX.PlayerData.job = job
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
    for k, v in pairs(data.locations) do
        points[k] = lib.points.new({
            coords = vec3(v.mcoords.x, v.mcoords.y, v.mcoords.z),
            distance = v.distance,
            bossmenucoords = v.bossmenucoords,
            chaircoords = v.chaircoords,
            debug = data.bossmenuDebug,

            spawnChair = function(self)
                if self.chairEntity and DoesEntityExist(self.chairEntity) then
                    DeleteEntity(self.chairEntity)
                end

                local cCoords = self.chaircoords
                local heading = cCoords.w or cCoords.heading or 0.0

                self.chairEntity = CreateObjectNoOffset(chairModel, cCoords.x, cCoords.y, cCoords.z, false, false, false)
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

                TaskSynchronizedScene(ped, baseScene, animDict, "base", 4.0, -2.0, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, baseScene, "base_chair", animDict, 4.0, -1.0, 0, 1148846080)
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

                local bCoords = self.bossmenucoords
                self.targetId = exports.ox_target:addBoxZone({
                    coords = vec3(bCoords.x, bCoords.y, bCoords.z),
                    size = vec3(1.0, 1.0, 1.0),
                    rotation = bCoords.w or bCoords.heading or 0.0,
                    debug = self.debug,
                    options = {
                        {
                            name = 'bossmenu_zone_' .. self.id,
                            icon = 'fas fa-user-tie',
                            label = 'Otwórz Boss Menu',
                            canInteract = function()
                                local jobName = ESX.PlayerData.job and ESX.PlayerData.job.name
                                return jobName and string.sub(jobName, 1, 3) ~= "off" and not self.isSeated
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
                if self.isSeated then return end
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

                TaskSynchronizedScene(ped, enterScene, animDict, "enter", 1.5, -1.5, 13, 16, 1.5, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, enterScene, "enter_chair", animDict, 4.0, -4.0, 0, 1148846080)

                if not waitForScenePhase(enterScene, self) then return end

                self:playBaseScene()
                self:startControls()
            end,

            playComputerSequence = function(self)
                if not self.isSeated or self.isAtComputer then return end
                self.isAtComputer = true

                local ped = cache.ped or PlayerPedId()

                lib.hideTextUI()

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local compEnterScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(compEnterScene, true)

                TaskSynchronizedScene(ped, compEnterScene, animDict, "computer_enter", 4.0, -1.5, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, compEnterScene, "computer_enter_chair", animDict, 4.0, -4.0, 0, 1148846080)

                if not waitForScenePhase(compEnterScene, self) then
                    if self.isSeated then
                        self.isAtComputer = false
                        self:playBaseScene()
                        self:startControls()
                    end
                    return
                end

                chairPos = GetEntityCoords(self.chairEntity)
                chairRot = GetEntityRotation(self.chairEntity, 2)

                local compIdleScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneLooped(compIdleScene, true)

                TaskSynchronizedScene(ped, compIdleScene, animDict, "computer_idle", 4.0, -1.5, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, compIdleScene, "computer_idle_chair", animDict, 4.0, -4.0, 0, 1148846080)

                local closed = ui.openUI('open', {})

                if not self.isSeated or not self.chairEntity or not DoesEntityExist(self.chairEntity) then
                    self.isAtComputer = false
                    return
                end

                if closed ~= true then
                    print(('[bossmenu] ui.openUI zwróciło "%s" zamiast true - wykonuję i tak wyjście z komputera.'):format(tostring(closed)))
                end

                self:playComputerExit()
            end,

            playComputerExit = function(self)
                if not self.isSeated then
                    self.isAtComputer = false
                    return
                end

                if not self.chairEntity or not DoesEntityExist(self.chairEntity) then
                    self.isAtComputer = false
                    return
                end

                local ped = cache.ped or PlayerPedId()

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local compExitScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(compExitScene, true)

                TaskSynchronizedScene(ped, compExitScene, animDict, "computer_exit", 4.0, -1.5, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, compExitScene, "computer_exit_chair", animDict, 4.0, -4.0, 0, 1148846080)

                if not waitForScenePhase(compExitScene, self) then return end
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
                    local compExitScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                    SetSynchronizedSceneHoldLastFrame(compExitScene, true)

                    TaskSynchronizedScene(ped, compExitScene, animDict, "computer_exit", 4.0, -1.5, 13, 16, 1000.0, 0)
                    PlaySynchronizedEntityAnim(self.chairEntity, compExitScene, "computer_exit_chair", animDict, 4.0, -4.0, 0, 1148846080)

                    waitForScenePhase(compExitScene, self)

                    chairPos = GetEntityCoords(self.chairEntity)
                    chairRot = GetEntityRotation(self.chairEntity, 2)
                end

                local exitScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(exitScene, true)

                TaskSynchronizedScene(ped, exitScene, animDict, "exit", 4.0, -4.0, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, exitScene, "exit_chair", animDict, 4.0, -4.0, 0, 1148846080)

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

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for _, point in pairs(points) do
        if point.isSeated then
            lib.hideTextUI()
            ClearPedTasks(cache.ped or PlayerPedId())
        end
        if point.targetId then
            exports.ox_target:removeZone(point.targetId)
        end
        if point.chairEntity and DoesEntityExist(point.chairEntity) then
            DeleteEntity(point.chairEntity)
        end
    end
end)