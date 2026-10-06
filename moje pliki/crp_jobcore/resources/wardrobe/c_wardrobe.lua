local ESX = exports["es_extended"]:getSharedObject()
local data = require('resources.wardrobe.d_wardrobe')
local boxs = {}
local jobs = {}
local savedCivilians = {}

CreateThread(function()
    jobs = lib.callback.await('crp_jobcore:server:getJobs', false) or {}
    if ESX.IsPlayerLoaded() then
        ESX.PlayerData = ESX.GetPlayerData()
    end
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    ESX.PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

local function getGradeList(jobname)
    local grades = {}
    if not jobname or not jobs or not jobs[jobname] or not jobs[jobname].grades then 
        return grades 
    end

    for y, z in pairs(jobs[jobname].grades) do
        table.insert(grades, { value = y, label = z.label })
    end

    table.sort(grades, function(a, b)
        return (tonumber(a.value) or 0) < (tonumber(b.value) or 0)
    end)

    return grades
end

CreateThread(function()
    RemoveIpl("v_stripclub")
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
                    label = 'Stwórz ubranie',
                    groups = {[v.job] = v.requiredGrade},
                    distance = 1.5,
                    canInteract = function()
                        local jobName = ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name
                        return jobName and string.sub(jobName, 1, 3) ~= "off"
                    end,
                    onSelect = function()
                        if not ESX.PlayerData or not ESX.PlayerData.job then return end
                        local pJob = ESX.PlayerData.job.name
                        local config = {
                            ped = false,
                            headBlend = false,
                            faceFeatures = false,
                            headOverlays = false,
                            components = true,
                            componentConfig = {
                                masks = true,
                                upperBody = true,
                                lowerBody = true,
                                bags = true,
                                shoes = true,
                                scarfAndChains = true,
                                bodyArmor = true,
                                shirts = true,
                                decals = true,
                                jackets = true
                            },
                            props = true,
                            propConfig = {
                                hats = true,
                                glasses = true,
                                ear = true,
                                watches = true,
                                bracelets = true
                            },
                            tattoos = false,
                            enableExit = true,
                            hasTracker = false,
                            automaticFade = false
                        }

                        exports['illenium-appearance']:startPlayerCustomization(function(appearance)
                            if appearance then
                                local components = exports['illenium-appearance']:getPedComponents(cache.ped)
                                local props = exports['illenium-appearance']:getPedProps(cache.ped)
                                local grades = getGradeList(pJob)
                                local licenses = v.licenses or {}
                                local pedmodel = exports['illenium-appearance']:getPedModel(cache.ped)

                                local input = lib.inputDialog('Tworzenie stroju', {
                                    {type = 'input', label = 'Praca', placeholder = pJob, disabled = true},
                                    {type = 'input', label = 'Nazwa stroju', placeholder = 'Ubranie robocze', required = true},
                                    {type = 'multi-select', label = 'Ranga', options = grades, required = true},
                                    {type = 'multi-select', label = 'Licencja', options = licenses, required = false},
                                })

                                if not input then return end
                                lib.callback.await('crp_jobcore:server:sendClothesInfo', false, components, props, pedmodel, pJob, input[2], input[3], input[4])
                            end
                        end, config)
                    end,
                },
                {
                    name = 'duty_manage_wardrobe',
                    icon = 'fa-solid fa-sliders',
                    label = 'Zarządzaj szatnią',
                    groups = {[v.job] = v.requiredGrade},
                    distance = 1.5,
                    canInteract = function()
                        local jobName = ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name
                        return jobName and string.sub(jobName, 1, 3) ~= "off"
                    end,
                    onSelect = function()
                        if not ESX.PlayerData or not ESX.PlayerData.job then return end
                        local pJob = ESX.PlayerData.job.name

                        local allJobClothes = lib.callback.await('crp_jobcore:server:getAllClothesForJob', false)

                        if not allJobClothes or #allJobClothes == 0 then
                            lib.notify({
                                title = 'Zarządzanie Szatnią',
                                description = 'Brak jakichkolwiek ubrań w bazie dla tej pracy.',
                                type = 'error'
                            })
                            return
                        end

                        local options = {}
                        for index, outfit in ipairs(allJobClothes) do
                            table.insert(options, {
                                title = outfit.clothesName,
                                description = 'Model: ' .. outfit.pedmodel .. ' | Kliknij, aby zarządzać.',
                                icon = 'shirt',
                                menu = 'manage_outfit_options_' .. index
                            })

                            lib.registerContext({
                                id = 'manage_outfit_options_' .. index,
                                title = 'Zarządzaj: ' .. outfit.clothesName,
                                menu = 'job_clothes_manage_main',
                                options = {
                                    {
                                        title = 'Edytuj dane (Nazwa, Rangi, Licencje)',
                                        description = 'Zmień uprawnienia i nazwę stroju.',
                                        icon = 'pen-to-square',
                                        onSelect = function()
                                            local grades = getGradeList(pJob)
                                            local licenses = v.licenses or {}

                                            local input = lib.inputDialog('Edycja stroju: ' .. outfit.clothesName, {
                                                {type = 'input', label = 'Nazwa stroju', default = outfit.clothesName, required = true},
                                                {type = 'multi-select', label = 'Ranga', options = grades, default = outfit.grades, required = true},
                                                {type = 'multi-select', label = 'Licencja', options = licenses, default = outfit.licenses, required = false},
                                            })

                                            if not input then return end

                                            local success = lib.callback.await('crp_jobcore:server:updateOutfitMeta', false, outfit.id, input[1], input[2], input[3])
                                            if success then
                                                lib.notify({title = 'Sukces', description = 'Zaktualizowano dane stroju.', type = 'success'})
                                            else
                                                lib.notify({title = 'Błąd', description = 'Nie udało się zaktualizować stroju.', type = 'error'})
                                            end
                                        end
                                    },
                                    {
                                        title = 'Edytuj wygląd (Nadpisz ciuchy)',
                                        description = 'Otwórz edytor i nadpisz obecny wygląd stroju.',
                                        icon = 'user-pen',
                                        onSelect = function()
                                            local config = {
                                                ped = false,
                                                headBlend = false,
                                                faceFeatures = false,
                                                headOverlays = false,
                                                components = true,
                                                componentConfig = { masks = true, upperBody = true, lowerBody = true, bags = true, shoes = true, scarfAndChains = true, bodyArmor = true, shirts = true, decals = true, jackets = true },
                                                props = true,
                                                propConfig = { hats = true, glasses = true, ear = true, watches = true, bracelets = true },
                                                tattoos = false,
                                                enableExit = true,
                                                hasTracker = false,
                                                automaticFade = false
                                            }

                                            exports['illenium-appearance']:startPlayerCustomization(function(appearance)
                                                if appearance then
                                                    local components = exports['illenium-appearance']:getPedComponents(cache.ped)
                                                    local props = exports['illenium-appearance']:getPedProps(cache.ped)
                                                    local pedmodel = exports['illenium-appearance']:getPedModel(cache.ped)

                                                    local success = lib.callback.await('crp_jobcore:server:updateOutfitAppearance', false, outfit.id, components, props, pedmodel)
                                                    if success then
                                                        lib.notify({title = 'Sukces', description = 'Zaktualizowano wygląd stroju.', type = 'success'})
                                                    else
                                                        lib.notify({title = 'Błąd', description = 'Nie udało się zapisać wyglądu.', type = 'error'})
                                                    end
                                                end
                                            end, config)
                                        end
                                    },
                                    {
                                        title = 'Usuń ubiór',
                                        description = 'Trwale usuń ten strój z bazy danych.',
                                        icon = 'trash',
                                        iconColor = 'red',
                                        onSelect = function()
                                            local alert = lib.alertDialog({
                                                header = 'Potwierdzenie usunięcia',
                                                content = 'Czy na pewno chcesz bezpowrotnie usunąć ubiór: **' .. outfit.clothesName .. '**?',
                                                centered = true,
                                                cancel = true
                                            })

                                            if alert == 'confirm' then
                                                local success = lib.callback.await('crp_jobcore:server:deleteOutfit', false, outfit.id, pJob)
                                                if success then
                                                    lib.notify({title = 'Sukces', description = 'Usunięto ubiór.', type = 'success'})
                                                else
                                                    lib.notify({title = 'Błąd', description = 'Nie udało się usunąć ubioru.', type = 'error'})
                                                end
                                            end
                                        end
                                    }
                                }
                            })
                        end

                        lib.registerContext({
                            id = 'job_clothes_manage_main',
                            title = 'Zarządzanie Szatnią',
                            options = options
                        })

                        lib.showContext('job_clothes_manage_main')
                    end,
                },
                {
                    name = 'duty_open_wardrobe',
                    icon = 'fa-solid fa-shirt',
                    label = 'Otwórz szatnie',
                    groups = {[v.job] = 0},
                    distance = 1.5,
                    canInteract = function()
                        local jobName = ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name
                        return jobName and string.sub(jobName, 1, 3) ~= "off"
                    end,
                    onSelect = function()
                        if not ESX.PlayerData or not ESX.PlayerData.job then return end

                        local availableClothes = lib.callback.await('crp_jobcore:server:getClothesInfo', false)

                        local playerId = cache.serverId or GetPlayerServerId(PlayerId())
                        if not savedCivilians[playerId] then
                            savedCivilians[playerId] = {
                                components = exports['illenium-appearance']:getPedComponents(cache.ped),
                                props = exports['illenium-appearance']:getPedProps(cache.ped)
                            }
                        end

                        local options = {}

                        table.insert(options, {
                            title = 'Ubranie cywilne',
                            description = 'Wróć do swojego prywatnego ubrania.',
                            icon = 'user',
                            onSelect = function()
                                if savedCivilians[playerId] then
                                    exports['illenium-appearance']:setPedComponents(cache.ped, savedCivilians[playerId].components)
                                    exports['illenium-appearance']:setPedProps(cache.ped, savedCivilians[playerId].props)

                                    lib.notify({
                                        title = 'Garderoba',
                                        description = 'Pomyślnie założono ubranie cywilne.',
                                        type = 'success'
                                    })
                                else
                                    lib.notify({
                                        title = 'Garderoba',
                                        description = 'Nie znaleziono zapisanego cywilnego ubrania.',
                                        type = 'error'
                                    })
                                end
                            end
                        })

                        if availableClothes and #availableClothes > 0 then
                            for _, outfit in ipairs(availableClothes) do
                                table.insert(options, {
                                    title = outfit.clothesName,
                                    description = 'Kliknij, aby założyć ten zestaw.',
                                    icon = 'shirt',
                                    onSelect = function()
                                        exports['illenium-appearance']:setPedComponents(cache.ped, outfit.components)
                                        exports['illenium-appearance']:setPedProps(cache.ped, outfit.props)

                                        lib.notify({
                                            title = 'Garderoba',
                                            description = 'Pomyślnie założono strój: ' .. outfit.clothesName,
                                            type = 'success'
                                        })
                                    end
                                })
                            end
                        end

                        lib.registerContext({
                            id = 'job_clothes_wardrobe_menu',
                            title = 'Szatnia Pracy',
                            options = options
                        })

                        lib.showContext('job_clothes_wardrobe_menu')
                    end,
                },
            }
        })
        table.insert(boxs[k], bid)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    for _, zoneList in pairs(boxs) do
        for _, zoneId in ipairs(zoneList) do
            if exports.ox_target:zoneExists(zoneId) then
                exports.ox_target:removeZone(zoneId)
            end
        end
    end
end)