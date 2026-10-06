--[[
    c_main.lua – klient bossmenu

    1. Punkty w Config.Locations: strefa ox_target „Otwórz Boss Menu”.
    2. Po wybraniu: animacja siadania na krzesło -> [G] komputer -> panel (NUI).
    3. Panel otwiera się danymi z serwera ('crp_bossmenu:client:open'), a zamknięcie wraca na krzesło.

    Protokół NUI (bez zmian, Twój interfejs działa jak wcześniej):
      serwer -> NUI: { action = 'open'|'update'|'close'|'notify', ... }
      NUI -> serwer: 'bossmenu:<akcja>' (setGrade, fire, addRecord, deposit, ...)
]]

--┌───────────────────────────────────────────────────────────────────────────┐
--│  WCZYTYWANIE MODUŁÓW                                                      │
--│  1) próbujemy `require` (Twój loader),                                     │
--│  2) jeśli się nie uda – czytamy plik z folderu resource'a (LoadResourceFile),│
--│  3) wynik ląduje w cache, więc każdy moduł wczyta się tylko raz.           │
--│  Dzięki temu działa i z fxmanifestem, i z własnym loaderem.                │
--└───────────────────────────────────────────────────────────────────────────┘
local function loadModule(requirePath, fileName, cacheKey)
    local cached = _G[cacheKey]
    if type(cached) == 'table' then return cached end

    local ok, mod = pcall(require, requirePath)
    if not ok or type(mod) ~= 'table' then
        local source = LoadResourceFile(GetCurrentResourceName(), fileName)
        if not source then
            error(('[crp_bossmenu] nie mogę wczytać %s – sprawdź, czy plik jest w folderze resource (albo w fxmanifest.lua)')
                :format(fileName))
        end
        mod = ((load or loadstring)(source, '@' .. fileName))()
    end

    _G[cacheKey] = mod
    return mod
end

-- zabezpieczenie przed podwójnym załadowaniem (np. fxmanifest + require)
if _G.crp_bossmenu_c_main then return _G.crp_bossmenu_c_main end

local Config = loadModule('resources.bossmenu.d_bossmenu', 'd_bossmenu.lua', 'crp_bossmenu_config')
local ESX = exports['es_extended']:getSharedObject()

local points = {}

-- Prace „poza służbą” (offpolice / offambulance) obsługujemy jak ich bazowy odpowiednik —
-- spójnie z serwerem (Config.AllowOffDuty = false wyłącza to zachowanie).
local function baseJob(job)
    if type(job) ~= 'string' or job == '' then return nil end
    if Config.Jobs[job] then return job end
    if Config.AllowOffDuty == false then return job end
    local stripped = job:gsub('^off', '')
    if stripped ~= job and Config.Jobs[stripped] then return stripped end
    return job
end

local chairModel = `sf_prop_sf_offchair_exec_01a`
local animDict = 'anim@scripted@player@fix_agy_ig6_office_chair_entry@right@male@'

-- fazy animacji krzesła odtwarzane U POZOSTAŁYCH graczy (mirror – patrz sekcja „ANIMACJA” niżej)
local MIRROR_PHASES = {
    enter          = { clip = 'enter',          loop = false },
    base           = { clip = 'base',           loop = true  },
    computer_enter = { clip = 'computer_enter', loop = false },
    computer_idle  = { clip = 'computer_idle',  loop = true  },
    computer_exit  = { clip = 'computer_exit',  loop = false },
    exit           = { clip = 'exit',           loop = false },
    stop           = false                                   -- koniec: zdejmij animację z postaci
}

-- stan panelu
local uiOpen = false        -- okno NUI otwarte
local activePoint           -- punkt, z którego otwarto panel (żeby wrócić na krzesło)
local awaitingOpen = false  -- czekamy na zgodę serwera


-- ═════════════════════════════════════════════════════════════
--  ANIMACJA WIDOCZNA DLA INNYCH GRACZY
--
--  TaskSynchronizedScene tworzy scenę LOKALNIE – gracz widzi swoją animację
--  tylko u siebie, a pozostali patrzą na postać stojącą. Dlatego siedzący klient
--  wysyła fazę animacji na serwer ('crp_bossmenu:server:anim'), a serwer rozsyła ją
--  graczom w pobliżu. Oni odtwarzają ten sam klip na zdalnej postaci (TaskPlayAnim)
--  i – jeśli trzeba – dokładają lokalnie krzesło, żeby wszystko zgadzało się wizualnie.
-- ═════════════════════════════════════════════════════════════
local MIRROR = {}          -- [src gracza] = { clip, loop, chair, tempChair, heals, at }
local panelBusy = {}       -- [praca] = nazwa gracza, który aktualnie używa panelu (podpowiedź w textUI)

local function mirrorStop(src, keepPed)
    local m = MIRROR[src]
    if not m then return end
    MIRROR[src] = nil

    if not keepPed and m.clip then
        local pid = GetPlayerFromServerId(src)
        local ped = pid ~= -1 and GetPlayerPed(pid) or 0
        if ped and ped ~= 0 then StopAnimTask(ped, animDict, m.clip, 8.0) end
    end
    if m.tempChair and DoesEntityExist(m.tempChair) then DeleteEntity(m.tempChair) end
end

local function mirrorStopAll()
    for src in pairs(MIRROR) do mirrorStop(src) end
end

-- krzesło dla zdalnej postaci: bierzemy to z punktu (jeśli gracz je ma), inaczej stawiamy tymczasowe
local function mirrorChair(key, coords, heading)
    local pt = points[key]
    if pt and pt.chairEntity and DoesEntityExist(pt.chairEntity) then return pt.chairEntity, false end

    if not lib.requestModel(chairModel, 2000) then return nil, false end
    local obj = CreateObjectNoOffset(chairModel, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    return obj, true
end

local function mirrorApply(src)
    local m = MIRROR[src]
    if not m then return false end

    local pid = GetPlayerFromServerId(src)
    local ped = pid ~= -1 and GetPlayerPed(pid) or 0
    if not ped or ped == 0 then return false end

    -- duration -1 = do końca klipu; flag 1 = zapętl (dla klipów „base”/„computer_idle”)
    TaskPlayAnim(ped, animDict, m.clip, 8.0, -8.0, -1, m.loop and 1 or 0, 0.0, false, false, false)
    return true
end

local function mirrorHeal(src)
    CreateThread(function()
        while MIRROR[src] do
            Wait(1200)
            local m = MIRROR[src]
            if not m then break end

            local pid = GetPlayerFromServerId(src)
            local ped = pid ~= -1 and GetPlayerPed(pid) or 0
            if not ped or ped == 0 then break end

            -- koniec: gracz padł / jest w ragdollu / odjechał daleko od krzesła
            local drop = IsPedFatallyInjured(ped) or IsPedRagdoll(ped)
            if not drop and m.chair and DoesEntityExist(m.chair) then
                drop = #(GetEntityCoords(ped) - GetEntityCoords(m.chair)) > 60.0
            end
            if drop then mirrorStop(src) break end

            -- animacja zniknęła (np. nadpisana przez synchronizację gry) – wstawiamy ją z powrotem
            if m.clip and m.heals < 3 and not IsEntityPlayingAnim(ped, animDict, m.clip, 3) then
                m.heals = m.heals + 1
                mirrorApply(src)
            end
        end
    end)
end

RegisterNetEvent('crp_bossmenu:client:anim', function(playerSrc, key, phase, cx, cy, cz, heading)
    if playerSrc == GetPlayerServerId(PlayerId()) then return end

    if phase == 'stop' or MIRROR_PHASES[phase] == false then
        mirrorStop(playerSrc)
        return
    end
    local def = MIRROR_PHASES[phase]
    if not def then return end

    local pid = GetPlayerFromServerId(playerSrc)
    if pid == -1 or GetPlayerPed(pid) == 0 then return end
    if not lib.requestAnimDict(animDict, 3000) then return end

    local m = MIRROR[playerSrc]
    if m and m.chair and DoesEntityExist(m.chair) and m.key ~= key then
        mirrorStop(playerSrc)                 -- ten gracz zmienił krzesło – sprzątamy poprzednie
        m = nil
    end

    if not m then
        local chair, temp = mirrorChair(key, vec3(cx, cy, cz), heading)
        m = { chair = chair, tempChair = temp }
        MIRROR[playerSrc] = m
        mirrorHeal(playerSrc)
    end

    m.key, m.clip, m.loop, m.heals, m.at = key, def.clip, def.loop, 0, GetGameTimer()
    if not mirrorApply(playerSrc) then mirrorStop(playerSrc) end
end)

-- informacja „kto siedzi w panelu” (podpowiedź przy krześle; blokadę egzekwuje serwer)
RegisterNetEvent('crp_bossmenu:client:panelBusy', function(job, name)
    if not job then return end
    panelBusy[job] = name or nil
end)


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

-- ── blokada krzesła: jedno krzesło = jedna osoba (pilnuje serwer) ──
local seatWait, seatLock = nil, nil   -- seatWait = trwa handshake, seatLock = zajęte krzesło

local function reserveSeat(key, timeout)
    seatWait = { key = key }
    TriggerServerEvent('crp_bossmenu:server:seat', key, true)

    local limit = GetGameTimer() + (timeout or 1500)
    while seatWait and not seatWait.done and GetGameTimer() < limit do Wait(25) end

    local res, answered = seatWait, seatWait and seatWait.done or false
    seatWait = nil

    -- brak odpowiedzi (np. starsza wersja s_main.lua na serwerze) – nie blokujemy graczowi krzesła,
    -- bo panel i tak pilnuje serwer przy otwieraniu
    if not answered or not res then
        print('^3[crp_bossmenu]^7 serwer nie potwierdził rezerwacji krzesła – wchodzę mimo to.')
        seatLock = { key = key, held = false }
        return true
    end

    if not res.granted then
        seatLock = nil
        return false, res.holder
    end

    seatLock = { key = key, held = true }
    return true
end

local function releaseSeat()
    if seatLock and seatLock.held then
        TriggerServerEvent('crp_bossmenu:server:seat', seatLock.key, false)
    end
    seatLock = nil
end

RegisterNetEvent('crp_bossmenu:client:seatRes', function(key, granted, holder)
    if not seatWait or seatWait.key ~= key then return end
    seatWait.granted, seatWait.holder, seatWait.done = granted and true or false, holder, true
end)

local function requestOpen(point)
    awaitingOpen = true
    activePoint = point
    TriggerServerEvent('crp_bossmenu:server:open')

    -- serwer nie odpowiedział (brak uprawnień / błąd) – wracamy na krzesło i mówimy o tym
    SetTimeout(3000, function()
        if awaitingOpen then
            awaitingOpen = false
            resumeChair(point)
            ESX.ShowNotification('Nie udało się otworzyć panelu – brak odpowiedzi serwera.')
            print('^1[crp_bossmenu]^7 serwer nie odpowiedział na `crp_bossmenu:server:open` – zajrzyj w konsolę serwera (najczęściej błąd w s_data/s_main przy starcie).')
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

-- uwaga: bossmenu.js wysyła zamknięcie na `close` (bez prefiksu), zo_bossmenu używał `bossmenu:close`
-- – obsługujemy oba, żeby okno zawsze oddało fokus i zdjęło gracza z komputera
local function onClose(_, cb)
    closePanel(false)
    cb({})
end

RegisterNUICallback('close', onClose)
RegisterNUICallback('bossmenu:close', onClose)

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
            key = name,                      -- klucz z Config.Locations (potrzebny do blokad i animacji)
            coords = vec3(loc.mcoords.x, loc.mcoords.y, loc.mcoords.z),
            distance = loc.distance or 20.0,
            job = loc.job,
            jobs = loc.jobs,                 -- punkt może obsługiwać kilka prac: { police = 10, mechanic = 4 }
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

            -- pokaż innym graczom, co robi nasza postać (TaskSynchronizedScene jest lokalny!)
            syncAnim = function(self, phase)
                if self.key and MIRROR_PHASES[phase] ~= nil then
                    TriggerServerEvent('crp_bossmenu:server:anim', self.key, phase)
                end
            end,

            playBaseScene = function(self)
                local ped = cache.ped or PlayerPedId()

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local baseScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneLooped(baseScene, true)

                TaskSynchronizedScene(ped, baseScene, animDict, 'base', 4.0, -2.0, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, baseScene, 'base_chair', animDict, 4.0, -1.0, 0, 1148846080)
                self:syncAnim('base')
            end,

            startControls = function(self)
                local jd = ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name
                local busy = jd and panelBusy[baseJob(jd) or jd]
                lib.showTextUI('[E] - Wstań z krzesła  \n' .. (busy
                    and ('[G] - Boss Menu (używa: ' .. busy .. ')')
                    or '[G] - Użyj Boss Menu'), {
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
                                local jd = ESX.PlayerData and ESX.PlayerData.job
                                if not jd or self.isSeated then return false end
                                if self.jobs then
                                    -- punkt wielu prac: wystarczy dowolny klucz z listy (także wersja „off…”)
                                    return self.jobs[jd.name] ~= nil or self.jobs[baseJob(jd.name)] ~= nil
                                end
                                return baseJob(jd.name) == self.job
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
                    releaseSeat()
                    self:syncAnim('stop')
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

                -- jedno krzesło = jedna osoba: pytamy serwer, czy nikt go nie zajął
                local granted, holder = reserveSeat(self.key)
                if not granted then
                    ESX.ShowNotification(holder
                        and ('Panel jest teraz używany przez %s – poczekaj, aż skończy.'):format(holder)
                        or 'Ktoś właśnie używa tego panelu – poczekaj chwilę.')
                    return
                end

                self.isSeated = true
                self.isAtComputer = false

                local ped = cache.ped or PlayerPedId()

                if not lib.requestAnimDict(animDict, 3000) then
                    self.isSeated = false
                    releaseSeat()
                    return
                end

                SetEntityNoCollisionEntity(ped, self.chairEntity, false)

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                local enterScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(enterScene, true)

                TaskSynchronizedScene(ped, enterScene, animDict, 'enter', 1.5, -1.5, 13, 16, 1.5, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, enterScene, 'enter_chair', animDict, 4.0, -4.0, 0, 1148846080)
                self:syncAnim('enter')

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
                self:syncAnim('computer_enter')

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
                self:syncAnim('computer_idle')

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
                self:syncAnim('computer_exit')

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
                    releaseSeat()
                    self:syncAnim('stop')
                    return
                end

                local chairPos = GetEntityCoords(self.chairEntity)
                local chairRot = GetEntityRotation(self.chairEntity, 2)

                if self.isAtComputer then
                    local compExit = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                    SetSynchronizedSceneHoldLastFrame(compExit, true)

                    TaskSynchronizedScene(ped, compExit, animDict, 'computer_exit', 4.0, -1.5, 13, 16, 1000.0, 0)
                    PlaySynchronizedEntityAnim(self.chairEntity, compExit, 'computer_exit_chair', animDict, 4.0, -4.0, 0, 1148846080)
                    self:syncAnim('computer_exit')

                    waitForScenePhase(compExit, self)

                    chairPos = GetEntityCoords(self.chairEntity)
                    chairRot = GetEntityRotation(self.chairEntity, 2)
                end

                local exitScene = CreateSynchronizedScene(chairPos.x, chairPos.y, chairPos.z, chairRot.x, chairRot.y, chairRot.z, 2)
                SetSynchronizedSceneHoldLastFrame(exitScene, true)

                TaskSynchronizedScene(ped, exitScene, animDict, 'exit', 4.0, -4.0, 13, 16, 1000.0, 0)
                PlaySynchronizedEntityAnim(self.chairEntity, exitScene, 'exit_chair', animDict, 4.0, -4.0, 0, 1148846080)
                self:syncAnim('exit')

                waitForScenePhase(exitScene, self)

                ClearPedTasks(ped)
                SetEntityNoCollisionEntity(ped, self.chairEntity, true)

                self:spawnChair()

                self.isSeated = false
                self.isAtComputer = false

                releaseSeat()          -- krzesło wolne dla następnego gracza
                self:syncAnim('stop')  -- pozostałym zdejmujemy animację z postaci
            end
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if uiOpen then SetNuiFocus(false, false) end
    releaseSeat()
    mirrorStopAll()

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
