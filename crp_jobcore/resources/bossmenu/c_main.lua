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

-- fazy animacji krzesła; `clip` = klip na postać, `chair` = klip na krzesło (przedmiot)
local MIRROR_PHASES = {
    enter          = { clip = 'enter',          chair = 'enter_chair',          loop = false },
    base           = { clip = 'base',           chair = 'base_chair',           loop = true  },
    computer_enter = { clip = 'computer_enter', chair = 'computer_enter_chair', loop = false },
    computer_idle  = { clip = 'computer_idle',  chair = 'computer_idle_chair',  loop = true  },
    computer_exit  = { clip = 'computer_exit',  chair = 'computer_exit_chair',  loop = false },
    exit           = { clip = 'exit',           chair = 'exit_chair',           loop = false },
    stop           = false                                   -- koniec: zdejmij animację z postaci
}

-- stan panelu
local uiOpen = false        -- okno NUI otwarte
local activePoint           -- punkt, z którego otwarto panel (żeby wrócić na krzesło)
local awaitingOpen = false  -- czekamy na zgodę serwera


-- ═════════════════════════════════════════════════════════════
--  ANIMACJA KRZESŁA – JEDNA SCENA SIECIOWA DLA POSTACI *I* KRZESŁA
--
--  Zgodnie z dokumentacją natywek (docs.fivem.net/natives, NETWORK/*.md):
--   · CreateSynchronizedScene / TaskSynchronizedScene tworzą scenę LOKALNĄ – istnieje
--     tylko na komputerze gracza, który ją utworzył (dlatego inni widzieli nas stojących).
--   · NETWORK_CREATE_SYNCHRONISED_SCENE + NETWORK_ADD_PED_TO_SYNCHRONISED_SCENE +
--     NETWORK_ADD_ENTITY_TO_SYNCHRONISED_SCENE + NETWORK_START_SYNCHRONISED_SCENE
--     tworzą scenę SIECIOWĄ – gra synchronizuje ją wszystkim, którzy nas widzą.
--   · POSTAĆ I KRZESŁO MUSZĄ BYĆ W TEJ SAMEJ SCENIE (w wersji lokalnej było to
--     TaskSynchronizedScene + PlaySynchronizedEntityAnim). Gdy krzesło grało OSOBNO
--     (PlayEntityAnim), prop odjeżdżał od postaci – stąd dziwne przesunięcie.
--   · Krzesło siadającego tworzymy jako obiekt SIECIOWY (CreateObject ... isNetwork),
--     więc scena animuje ten sam przedmiot u wszystkich graczy; swoje lokalne kopie
--     chowamy na czas, gdy ktoś inny siedzi.
--   · Faza sceny: NETWORK_GET_LOCAL_SCENE_FROM_NETWORK_ID(netScene) → GET_SYNCHRONIZED_SCENE_PHASE.
--   · Flagi bitowe są te same co w wersji, która działała poprawnie:
--     13 = 1 (fizyka) | 4 (scena nieprzerywalna) | 8 (przerwanie zadania zatrzymuje scenę),
--     ragdollFlags 16 = scena przerwana przy obrażeniach.
-- ═════════════════════════════════════════════════════════════
local MIRROR = {}          -- [src gracza] = { key, clip, loop, at } – awaryjna animacja obserwatora

-- Parametry każdej fazy – 1:1 z wersją lokalną, która nie miała przesunięcia.
--   blendIn/blendOut – prędkości wtapiania klipu postaci
--   mover            – moverBlendInDelta (1000.0 = domyślne; 1.5 tylko przy wsiadaniu)
--   chairIn/chairOut – wtapianie klipu krzesła (tak jak PlaySynchronizedEntityAnim w oryginale)
--   looped/hold      – parametry sceny: pętla oraz „zostań na ostatniej klatce”
local PHASE_PARAMS = {
    enter          = { blendIn = 1.5, blendOut = -1.5, mover = 1.5,    chairIn = 4.0, chairOut = -4.0, looped = false, hold = true  },
    base           = { blendIn = 4.0, blendOut = -2.0, mover = 1000.0, chairIn = 4.0, chairOut = -1.0, looped = true,  hold = false },
    computer_enter = { blendIn = 4.0, blendOut = -1.5, mover = 1000.0, chairIn = 4.0, chairOut = -4.0, looped = false, hold = true  },
    computer_idle  = { blendIn = 4.0, blendOut = -1.5, mover = 1000.0, chairIn = 4.0, chairOut = -4.0, looped = true,  hold = false },
    computer_exit  = { blendIn = 4.0, blendOut = -1.5, mover = 1000.0, chairIn = 4.0, chairOut = -4.0, looped = false, hold = true  },
    exit           = { blendIn = 4.0, blendOut = -4.0, mover = 1000.0, chairIn = 4.0, chairOut = -4.0, looped = false, hold = true  }
}

-- ── jedna scena sieciowa na fazę ─────────────────────────────────────────────
--  Parametry NETWORK_CREATE_SYNCHRONISED_SCENE:
--    pozycja + obrót sceny (u nas: krzesło), kolejność obrotu 2,
--    holdLastFrame (zostań na ostatniej klatce), looped (zapętl scenę),
--    faza zatrzymania 1.0, faza startu 0.0, prędkość animacji 1.0.
local function newScene(coords, rot, looped, hold)
    return NetworkCreateSynchronisedScene(
        coords.x, coords.y, coords.z,
        rot.x, rot.y, rot.z,
        2,
        hold and true or false,
        looped and true or false,
        1.0,
        0.0,
        1.0)
end

-- zakończ scenę u wszystkich (przy holdLastFrame dokumentacja każe sprzątać samemu)
local function stopScene(self)
    if self and self.netScene then
        NetworkStopSynchronisedScene(self.netScene)
        self.netScene = nil
    end
end

-- lokalny uchwyt sceny sieciowej – tylko jego wolno podawać do natywek fazy
local function localSceneId(netScene)
    if not netScene then return nil end
    local id = NetworkGetLocalSceneFromNetworkId(netScene)
    local guard = 0
    while (not id or id == -1) and guard < 100 do
        Wait(10)
        id = NetworkGetLocalSceneFromNetworkId(netScene)
        guard = guard + 1
    end
    return (id and id ~= -1) and id or nil
end

-- Kiedy faza faktycznie leci? Sprawdzamy DWA sygnały (scenę i klip na postaci), bo:
--  · po NETWORK_STOP_SYNCHRONISED_SCENE gra potrzebuje chwili na zwolnienie postaci –
--    bez tego nowa faza (np. idle po siadaniu) potrafiła nie wystartować,
--  · scena bez animacji na postaci też bywa „niedomknięta”.
-- czy postać gra właśnie ten klip (scena sieciowa też się liczy – flaga 3)
local function pedPlayingClip(def)
    if not def then return false end
    local ped = cache.ped or PlayerPedId()
    return IsEntityPlayingAnim(ped, animDict, def.clip, 3) or false
end

-- czy bieżąca scena jeszcze żyje (lokalny uchwyt / faza)
local function sceneRunning(self)
    if not self or not self.netScene then return false end
    local id = NetworkGetLocalSceneFromNetworkId(self.netScene)
    if not id or id == -1 then return false end
    return IsSynchronizedSceneRunning(id) or GetSynchronizedScenePhase(id) > 0.0
end

local function sceneAlive(self, def)
    return pedPlayingClip(def) or sceneRunning(self)
end

-- czekamy, aż faza dobiegnie końca (0.99 = koniec; przy holdLastFrame zostaje na 1.0)
local function waitForScenePhase(netScene, point, ms)
    local id = localSceneId(netScene)
    if not id then return false end

    local endAt = GetGameTimer() + (ms or 10000)
    while GetSynchronizedScenePhase(id) < 0.99 and GetGameTimer() < endAt do
        if point and not point.isSeated then return false end
        Wait(0)
    end
    return true
end

-- KRZESŁO wchodzi do TEJ SAMEJ sceny co postać – to likwiduje przesunięcie prop↔postać.
-- Odpowiednik dawnego PlaySynchronizedEntityAnim(chair, scene, clip, dict, 4.0, -4.0, 0, 1000.0).
local function addChairToScene(self, netScene, clip, blendIn, blendOut)
    local chair = self and (self.netChair or self.chairEntity)
    if not clip or not netScene or not chair or not DoesEntityExist(chair) then return end
    NetworkAddEntityToSynchronisedScene(chair, netScene, animDict, clip,
        blendIn or 4.0, blendOut or -4.0, 0)
end

-- Start jednej fazy. KOLEJNOŚĆ JEST TU KLUCZOWA (wypracowana na Twoich testach w grze):
--   1) NAJPIERW powstaje i startuje nowa scena – dodanie postaci do nowej sceny samo przejmuje
--      ją z poprzedniej, więc postać ANI NA KLATKĘ nie zostaje bez sceny (brak „momentu stania”
--      przy przejściu np. enter → idle albo idle → komputer),
--   2) DOPIERO POTEM zatrzymujemy starą scenę (sprzątanie), w tym samym ticku, bez żadnego Wait.
-- Czego nie wolno robić (sprawdzone w grze):
--   · zatrzymać starej sceny PRZED startem nowej → gra puszcza postać do pozycji stojącej
--     i widać krótkie stanie (tak było w 1.0.10),
--   · wstawiać między nie żadnego Wait → to samo, plus widoczne „siadanie od nowa”.
-- Pozycję sceny czytamy ZAWSZE na świeżo z fotela: on (na kółkach) sam przesuwa się i obraca
-- w trakcie swoich klipów, więc stare współrzędne zostawiłyby postać obok fotela.
local function startPhase(self, phase)
    local p, def = PHASE_PARAMS[phase], MIRROR_PHASES[phase]
    if not self or not p or not def then return false end

    local chair = self.netChair or self.chairEntity
    if not chair or not DoesEntityExist(chair) then return false end

    local ped = cache.ped or PlayerPedId()
    local prev = self.netScene

    -- 1) nowa scena: postać + krzesło, start u wszystkich (postać przechodzi tu z poprzedniej)
    local pos, rot = GetEntityCoords(chair), GetEntityRotation(chair, 2)
    self.netScene = newScene(pos, rot, p.looped, p.hold)
    NetworkAddPedToSynchronisedScene(ped, self.netScene, animDict, def.clip,
        p.blendIn, p.blendOut, 13, 16, p.mover, 0)
    NetworkAddEntityToSynchronisedScene(chair, self.netScene, animDict, def.chair,
        p.chairIn, p.chairOut, 0)
    NetworkStartSynchronisedScene(self.netScene)

    -- 2) stara scena schodzi – postać jest już w nowej, więc to tylko sprzątanie
    if prev and prev ~= self.netScene then
        NetworkStopSynchronisedScene(prev)
    end

    self:syncAnim(phase)
    return true
end

-- ── krzesło punktu: lokalne („puste”) + wspólne (sieciowe) ───────────────────
-- Uwaga na Z: CREATE_OBJECT stawia obiekt Z OFFSETEM o promień modelu (dokumentacja
-- natywek), dlatego wszędzie używamy CREATE_OBJECT_NO_OFFSET – inaczej krzesło „podnosi
-- się” nad ziemię, a przy zamrożeniu zostaje tam na stałe.
local function placeChair(chair, c, dz)
    if not c or not chair or not DoesEntityExist(chair) then return end
    SetEntityCoordsNoOffset(chair, c.x, c.y, c.z + (dz or 0.0), false, false, false)
    SetEntityHeading(chair, c.w or c.heading or 0.0)
end

-- czy przy punkcie stoi już wspólne (sieciowe) krzesło kogoś, kto siedzi
local function sharedChairNear(c)
    if not c then return nil end
    local obj = GetClosestObjectOfType(c.x, c.y, c.z, 2.5, chairModel, false, false, false)
    if obj and obj ~= 0 and DoesEntityExist(obj) and NetworkGetEntityIsNetworked(obj) then return obj end
    return nil
end

local MIRROR = {}          -- [src gracza] = { key, clip, loop, at } – awaryjna animacja obserwatora
local panelBusy = {}       -- [praca] = nazwa gracza, który aktualnie używa panelu (podpowiedź w textUI)

local function mirrorStop(src)
    local m = MIRROR[src]
    if not m then return end
    MIRROR[src] = nil

    if m.clip then
        local pid = GetPlayerFromServerId(src)
        local ped = pid ~= -1 and GetPlayerPed(pid) or 0
        if ped and ped ~= 0 then StopAnimTask(ped, animDict, m.clip, 8.0) end
    end

    -- wracamy do swojego (lokalnego) krzesła – wspólne właśnie zniknęło
    local pt = m.key and points[m.key]
    if pt then pt:spawnChair() end
end

local function mirrorStopAll()
    for src in pairs(MIRROR) do mirrorStop(src) end
end

--  Podstawą jest scena sieciowa (postać + wspólne krzesło) – gra synchronizuje ją
--  wszystkim. Odtwarzanie klipu na zdalnej postaci to WYŁĄCZNIE siatka bezpieczeństwa:
--  sięgamy po nie, gdy u nas animacji ze sceny nie ma.
local function mirrorApply(src)
    local m = MIRROR[src]
    if not m or not m.clip then return false end

    local pid = GetPlayerFromServerId(src)
    local ped = pid ~= -1 and GetPlayerPed(pid) or 0
    if not ped or ped == 0 then return false end

    -- 1 = zapętl, 2 = zatrzymaj na ostatniej klatce
    TaskPlayAnim(ped, animDict, m.clip, 8.0, -8.0, -1, m.loop and 1 or 2, 0.0, false, false, false)
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
            if not ped or ped == 0 then mirrorStop(src) break end   -- gracz wyszedł – sprzątamy

            -- koniec: gracz padł / jest w ragdollu / odjechał daleko od krzesła
            local drop = IsPedFatallyInjured(ped) or IsPedRagdoll(ped)
            if not drop then
                local c = points[m.key] and points[m.key].chaircoords
                if c then drop = #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) > 60.0 end
            end
            if drop then mirrorStop(src) break end

            -- animacja zniknęła (np. scena do nas nie dotarła) – dokładamy klip.
            -- Pętle pilnujemy cały czas; klipy jednorazowe tylko chwilę po zgłoszeniu fazy.
            if m.clip and not IsEntityPlayingAnim(ped, animDict, m.clip, 3) then
                if m.loop or (GetGameTimer() - (m.at or 0)) < 5000 then
                    mirrorApply(src)
                end
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

    local m = MIRROR[playerSrc]
    if not m then
        m = {}
        MIRROR[playerSrc] = m
        mirrorHeal(playerSrc)
    end

    -- Faz NIE odtwarzamy tu na siłę – animuje je scena sieciowa u wszystkich.
    -- Zapisujemy tylko stan (awaryjne dokładanie klipu robi mirrorHeal) i chowamy
    -- SWOJĄ kopię krzesła, bo animuje je wspólne krzesło siedzącego.
    m.key, m.clip, m.loop, m.at = key, def.clip, def.loop, GetGameTimer()

    local pt = points[key]
    if pt then pt:parkLocalChair() end
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

            -- krzesło, które scena animuje: wspólne (sieciowe) albo nasze lokalne
            chairInScene = function(self)
                return self.netChair or self.chairEntity
            end,

            -- sprzątanie wszystkiego (wyjście z punktu / restart zasobu)
            removeChair = function(self)
                if self.netChair and DoesEntityExist(self.netChair) then DeleteEntity(self.netChair) end
                if self.chairEntity and DoesEntityExist(self.chairEntity) then DeleteEntity(self.chairEntity) end
                self.netChair, self.chairEntity = nil, nil
                self.chairNetworked, self.chairParked = false, false
            end,

            -- Bierze nasze lokalne („puste”) krzesło i stawia je tam, gdzie ma być:
            -- istniejące przywraca na miejsce (po wspólnym krześle), brakujące tworzy.
            spawnChair = function(self)
                local c = self.chaircoords

                if self.chairEntity and DoesEntityExist(self.chairEntity) and not self.chairNetworked then
                    local chair = self.chairEntity
                    placeChair(chair, c, 0.0)
                    self.chairParked = false
                    -- druga korekta w następnej klatce: gdyby gra zdążyła jeszcze raz ruszyć prop
                    CreateThread(function()
                        Wait(0)
                        if DoesEntityExist(chair) then placeChair(chair, c, 0.0) end
                    end)
                    return
                end

                if sharedChairNear(c) then return end        -- ktoś siedzi – nie stawiamy dubla

                -- CREATE_OBJECT_NO_OFFSET = dokładnie w podanych współrzędnych (bez offsetu Z)
                self.chairEntity = CreateObjectNoOffset(chairModel, c.x, c.y, c.z, false, false, false)
                SetEntityHeading(self.chairEntity, c.w or c.heading or 0.0)
                FreezeEntityPosition(self.chairEntity, true)
                SetEntityInvincible(self.chairEntity, true)
                self.chairNetworked, self.chairParked = false, false
            end,

            -- chowamy SWOJE lokalne krzesło, gdy przy punkcie animuje się wspólne (sieciowe)
            parkLocalChair = function(self)
                if self.chairNetworked then return end
                if self.chairEntity and DoesEntityExist(self.chairEntity) then
                    placeChair(self.chairEntity, self.chaircoords, -10.0)
                    self.chairParked = true
                end
            end,

            -- krzesło, na którym siadamy: obiekt SIECIOWY – scena animuje go u wszystkich graczy.
            -- Uwaga: CreateObjectNoOffset (CreateObject dodałby offset Z = promień modelu!).
            useNetworkChair = function(self)
                self:parkLocalChair()                          -- nasza kopia zeszłaby się z wspólną

                local c = self.chaircoords
                local obj = CreateObjectNoOffset(chairModel, c.x, c.y, c.z, true, false, false)
                if not obj or obj == 0 then
                    self:spawnChair()                          -- nie wyszło: siadamy na swoim lokalnym
                    return false
                end

                SetEntityHeading(obj, c.w or c.heading or 0.0)
                FreezeEntityPosition(obj, true)
                SetEntityInvincible(obj, true)

                -- chwila, aż obiekt dostanie identyfikator sieciowy (scena go potrzebuje)
                local tries = 0
                while NetworkGetNetworkIdFromEntity(obj) == 0 and tries < 20 do
                    Wait(50)
                    tries = tries + 1
                end

                self.netChair, self.chairNetworked = obj, true
                return true
            end,

            -- pokaż innym graczom, co robi nasza postać (serwer rozsyła fazę graczom w pobliżu)
            syncAnim = function(self, phase)
                self.currentPhase = MIRROR_PHASES[phase] ~= nil and phase or nil
                if self.key and MIRROR_PHASES[phase] ~= nil then
                    TriggerServerEvent('crp_bossmenu:server:anim', self.key, phase)
                end
            end,

            -- co 10 s ponawiamy informację o fazie (gracz, który podejdzie później, też nas zobaczy)
            -- i sprawdzamy, czy faza naprawdę leci – gdyby gra ją zdjęła (np. po zatrzymaniu
            -- sceny nowa faza nie ruszyła), wracamy do niej. Idle ma trwać do wstania (E).
            startSyncLoop = function(self)
                if self.syncLoop then return end
                self.syncLoop = true
                CreateThread(function()
                    while self.isSeated do
                        Wait(10000)
                        if self.isSeated and self.currentPhase then
                            local def = MIRROR_PHASES[self.currentPhase]
                            -- Reagujemy WYŁĄCZNIE wtedy, gdy klipu naprawdę nie ma – inaczej
                            -- niepotrzebny restart fazy wyglądał jak „wstaje i siada ponownie”.
                            if def and def.loop and not pedPlayingClip(def) and not sceneRunning(self) then
                                startPhase(self, self.currentPhase)   -- przywracamy siedzenie/pracę
                            else
                                self:syncAnim(self.currentPhase)
                            end
                        end
                    end
                    self.syncLoop = false
                end)
            end,

            -- faza „siedzę”: scena sieciowa z krzesłem, zapętlona – trwa aż gracz wstanie (E)
            -- albo przejdzie do komputera (G)
            playBaseScene = function(self)
                startPhase(self, 'base')
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
                    self.currentPhase = nil
                    stopScene(self)                       -- scena sieciowa u wszystkich
                    ClearPedTasks(cache.ped or PlayerPedId())
                    releaseSeat()
                    self:syncAnim('stop')
                end

                if self.targetId then
                    exports.ox_target:removeZone(self.targetId)
                    self.targetId = nil
                end

                self:removeChair()
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

                -- krzesło wspólne (sieciowe): scena animuje je u wszystkich graczy
                self:useNetworkChair()

                local chair = self:chairInScene()
                if not chair or not DoesEntityExist(chair) then
                    self.isSeated = false                    -- bez krzesła nie ma na czym siedzieć
                    releaseSeat()
                    return
                end

                -- fotel startuje dokładnie z pozycji z konfiguracji – dzięki temu każda sesja
                -- zaczyna się z tego samego miejsca (klipy fotela przesuwają go potem same)
                placeChair(chair, self.chaircoords, 0.0)

                SetEntityNoCollisionEntity(ped, chair, false)   -- postać nie ma kolidować z krzesłem

                -- wejście na krzesło: postać + krzesło w JEDNEJ scenie sieciowej
                if not startPhase(self, 'enter') then
                    self.isSeated = false
                    releaseSeat()
                    return
                end

                waitForScenePhase(self.netScene, self, 10000)
                if not self.isSeated then return end         -- gracz wstał w trakcie animacji

                self:playBaseScene()                          -- zapętlony idle, aż wstanie (E)
                self:startControls()
                self:startSyncLoop()
            end,

            playComputerSequence = function(self)
                if not self.isSeated or self.isAtComputer then return end
                if not self.chairEntity or not DoesEntityExist(self.chairEntity) then return end

                self.isAtComputer = true

                lib.hideTextUI()

                -- przejście do komputera: postać + krzesło w jednej scenie sieciowej
                if not startPhase(self, 'computer_enter') then
                    self.isAtComputer = false
                    return
                end

                waitForScenePhase(self.netScene, self, 10000)
                if not self.isSeated then return end          -- gracz wstał w trakcie przejścia

                -- praca przy komputerze: scena sieciowa zapętlona (do zamknięcia panelu)
                startPhase(self, 'computer_idle')

                -- panel otwiera się, gdy serwer przyśle dane ('client:open');
                -- zamknięcie panelu samo wraca na krzesło (playComputerExit)
                requestOpen(self)
            end,

            playComputerExit = function(self)
                if not self.isSeated or not self.chairEntity or not DoesEntityExist(self.chairEntity) then
                    self.isAtComputer = false
                    return
                end

                startPhase(self, 'computer_exit')

                waitForScenePhase(self.netScene, self, 10000)
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
                    stopScene(self)
                    ClearPedTasks(ped)
                    if self.netChair and DoesEntityExist(self.netChair) then DeleteEntity(self.netChair) end
                    self.netChair, self.chairNetworked = nil, false
                    self:spawnChair()
                    releaseSeat()
                    self:syncAnim('stop')
                    return
                end

                if self.isAtComputer then
                    startPhase(self, 'computer_exit')                 -- gdyby krzesła już nie było – pomijamy
                    waitForScenePhase(self.netScene, self, 10000)
                end

                startPhase(self, 'exit')
                waitForScenePhase(self.netScene, self, 10000)

                stopScene(self)               -- koniec sceny u wszystkich
                ClearPedTasks(ped)

                -- KRZESŁO: klip „exit” zostawia prop w swojej ostatniej pozie, dlatego zanim go
                -- sprzątniemy, przywracamy mu pozycję i obrót z konfiguracji. Wtedy podmiana na
                -- nasze lokalne krzesło jest niewidoczna (żadnego „magicznego obrotu”).
                local cc = self.chaircoords
                if self.netChair and DoesEntityExist(self.netChair) then
                    SetEntityNoCollisionEntity(ped, self.netChair, true)
                    placeChair(self.netChair, cc, 0.0)
                    DeleteEntity(self.netChair)
                elseif self.chairEntity and DoesEntityExist(self.chairEntity) then
                    SetEntityNoCollisionEntity(ped, self.chairEntity, true)
                end
                self.netChair, self.chairNetworked = nil, false
                self:spawnChair()             -- nasze lokalne krzesło wraca na miejsce

                self.isSeated = false
                self.isAtComputer = false
                self.currentPhase = nil

                releaseSeat()          -- krzesło wolne dla następnego gracza
                self:syncAnim('stop')  -- pozostali zdejmują animację i wracają do swoich krzeseł
            end
        })
    end
end)

-- Siatka bezpieczeństwa dla krzesła: gdyby wspólne (sieciowe) krzesło zniknęło bez wysłania
-- „stop” (np. gracz się rozłączył w trakcie siedzenia), każdy sam przywraca swoje lokalne
-- krzesło – bez tego punkt zostałby bez krzesła aż do ponownego wejścia w strefę.
CreateThread(function()
    while true do
        Wait(5000)
        for _, point in pairs(points) do
            if point.chairParked and not point.isSeated and not point.netChair then
                if not sharedChairNear(point.chaircoords) then point:spawnChair() end
            end
        end
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
            stopScene(point)
            ClearPedTasks(cache.ped or PlayerPedId())
        end
        if point.targetId then exports.ox_target:removeZone(point.targetId) end
        if point.removeChair then point:removeChair() end
    end
end)

return {}
