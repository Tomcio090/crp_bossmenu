-- ██████████████████████████████████████████████████████████████████████████████
--  nano_cd / client.lua — wozi auta lawetą `tr2` (start skryptu CD/POD)
--
--  Co robi klient:
--   · stawia PEDZIWO na dokach i przypina do niego target (ox_target),
--   · z targetu otwiera listę aut z zamówienia (ox_lib) – wybrane auto pojawia się
--     na jednym z punktów na dokach,
--   · stawia zestaw (przyczepa `tr2` + auto do ciągnięcia) w bazie pod car dealerem,
--     ale TYLKO wtedy, gdy wiezie jakieś zadanie; sprząta, gdy zadań już nie ma,
--   · przypina auto do gniazda lawety, gdy wjedziesz nim na przyczepę,
--   · pilnuje, żeby auta oddać wyłącznie w miejscu odbioru.
--
--  Komendy w grze (/pod help):
--   /pod                 – stan zadań, zestawu i gniazd
--   /pod wez [id]        – weź zadanie (bez id: pierwsze wolne)
--   /pod menu            – lista aut do pobrania na dokach (ta sama co z targetu)
--   /pod pobierz [nr]    – pobierz auto nr z listy (bez ox_lib / bez targetu)
--   /pod attach [n]      – przypnij auto, którym jedziesz, do gniazda n (albo pierwszego wolnego)
--   /pod oddaj           – oddaj auta (tylko w miejscu odbioru)
--   /pod przyczepa       – postaw/znajdź zestaw (przyczepa + ciężarówka)
--   /pod truck           – postaw samo auto do ciągnięcia
--   /pod sprzataj        – usuń zestaw i auta pobrane na dokach
--   /pod slot [n]        – wypisz offset/rot auta względem przyczepy (kalibracja gniazd)
--   /pod zapisz <co>     – wypisz gotową linijkę do configu: base | przyczepa | truck |
--                          doki | ped | punkt | oddanie
--   /pod test            – szybki test: zestaw + wzięcie zadania + auta na dokach
-- ██████████████████████████████████████████████████████████████████████████████

local Jobs = {}                -- [id] = zadanie (to, co przysłał serwer)
local Trailer = nil            -- uchwyt przyczepy `tr2`
local Truck = nil              -- uchwyt auta do ciągnięcia
local DockPed = nil            -- ped na dokach
local DockZone = nil           -- strefa ox_target na pedzie
local Loaded = {}              -- [gniazdo] = { veh = auto, item = numer pozycji, plate = tablica }
local Spawned = {}             -- [numer pozycji] = auto pobrane na dokach (jeszcze nie na lawecie)
local BaseBlip, DockBlip, DestBlip, DestBlipJob
local autoLoad = Config.AutoLoad and true or false
local ESX

CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok then ESX = obj end
    end
end)

-- ── narzędzia ─────────────────────────────────────────────────────────────────
local interactKey = (Config.Keys and Config.Keys.interact) or 38

local function Dist(a, b)
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function V3(t) return vector3(t.x or 0.0, t.y or 0.0, t.z or 0.0) end
local function MyPed() return PlayerPedId() end
local function MyCoords() return GetEntityCoords(MyPed()) end

local function Help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function Progress(text, ms)
    ms = ms or (Config.Progress and Config.Progress.ms) or 2500
    if GetResourceState('ox_lib') == 'started' and lib and lib.progressBar then
        return lib.progressBar({ duration = ms, label = text, canCancel = true,
            disable = { move = true, car = true, combat = true } })
    end
    local endAt = GetGameTimer() + ms
    while GetGameTimer() < endAt do
        Help(text .. ' ...')
        Wait(0)
    end
    return true
end

local function Blip(coords, cfg)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, cfg.sprite or 477)
    SetBlipColour(b, cfg.color or 5)
    SetBlipScale(b, cfg.scale or 0.9)
    SetBlipAsShortRange(b, cfg.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label or 'CD')
    EndTextCommandSetBlipName(b)
    return b
end

local function Marker(coords, m)
    DrawMarker(m.type or 1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        (m.scale and m.scale.x) or 6.0, (m.scale and m.scale.y) or 6.0, (m.scale and m.scale.z) or 1.0,
        (m.color and m.color.r) or 90, (m.color and m.color.g) or 160, (m.color and m.color.b) or 255,
        (m.color and m.color.a) or 90, false, false, 2, false, nil, nil, false)
end

local function WaitModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local guard = 0
    while not HasModelLoaded(model) and guard < 200 do Wait(10); guard = guard + 1 end
    return HasModelLoaded(model)
end

-- ── zadania ───────────────────────────────────────────────────────────────────
-- Zadanie, które wieziemy (to z flagą `mine`); nil = nic nie wieziemy
local function CurrentJob()
    local best
    for _, job in pairs(Jobs) do
        if job.mine then
            if not best or (job.receivedAt or 0) < (best.receivedAt or 0) then best = job end
        end
    end
    return best
end

-- Czy jest cokolwiek do zawiezienia? (zestaw stawiamy dopiero wtedy)
local function NeedTrailer()
    for _, job in pairs(Jobs) do
        if job.state ~= 'done' then return true end
    end
    return false
end

-- Czy to ja mam wozić? (zestaw stawia tylko osoba, która ma przypisane zadanie)
local function IShouldHaveRig()
    return CurrentJob() ~= nil
end

local function FreeSlot()
    for i = 1, #(Config.Trailer.slots or {}) do
        if not Loaded[i] then return i end
    end
    return nil
end

local function LoadedCount()
    local n = 0
    for _ in pairs(Loaded) do n = n + 1 end
    return n
end

local function ItemOf(job, index)
    for _, it in ipairs((job and job.items) or {}) do
        if tonumber(it.index) == tonumber(index) then return it end
    end
    return nil
end

-- Auto pobrane na dokach dla tej pozycji (jeśli zniknęło – zapominamy o nim)
local function ItemSpawned(index)
    local veh = Spawned[index]
    if veh and DoesEntityExist(veh) then return veh end
    if veh then Spawned[index] = nil end
    return nil
end

-- Co jeszcze zostało do pobrania na dokach (czysta funkcja – pokryta testami)
local function DockList(job)
    local out = {}
    for _, it in ipairs((job and job.items) or {}) do
        local i = tonumber(it.index)
        if i and not it.express and not (job.loaded and job.loaded[i]) and not (job.handed and job.handed[i]) then
            out[#out + 1] = {
                index = i,
                item = it,
                plate = tostring(it.plate or ''),
                label = ('%s (%s)'):format(tostring(it.name or it.model), tostring(it.plate or 'brak tablicy')),
                spawned = ItemSpawned(i) ~= nil,
            }
        end
    end
    return out
end

-- Lista tekstowa (gdy nie ma ox_lib) – numeracja zgodna z `/pod pobierz <nr>`
local function MenuLines(job)
    local out = {}
    if not job then
        for _, j in pairs(Jobs) do
            if not j.claimedBy then
                out[#out + 1] = ('weź zadanie: /pod wez %s   (%s)'):format(tostring(j.id), tostring(j.key))
            end
        end
        if #out == 0 then out[#out + 1] = 'brak zadań do wzięcia' end
        return out
    end

    local n = 1
    for _, e in ipairs(DockList(job)) do
        out[#out + 1] = ('/pod pobierz %d   →   %s%s'):format(n, e.label, e.spawned and '  [już na dokach]' or '')
        n = n + 1
    end
    if #out == 0 then out[#out + 1] = 'wszystkie auta z tego zadania są już pobrane' end
    return out
end

-- ── pobieranie aut na dokach ──────────────────────────────────────────────────
local function FreeSpawnPoint()
    for _, sp in ipairs(Config.Docks.spawnPoints or {}) do
        local taken = GetClosestVehicle(sp.x, sp.y, sp.z, 4.0, 0, 70)
        if taken == 0 then return sp end
    end
    return nil
end

local function SpawnCarFor(entry)
    local job = CurrentJob()
    if not job or not entry then return nil end

    local already = ItemSpawned(entry.index)
    if already then
        Config.Notify('To auto stoi już na dokach – wjedź nim na lawetę.', 'info')
        return already
    end
    if not FreeSlot() then
        Config.Notify('Wszystkie gniazda lawety są zajęte – zawieź auta i wróć.', 'error')
        return nil
    end

    local sp = FreeSpawnPoint()
    if not sp then
        Config.Notify('Wszystkie miejsca na dokach są zajęte – załaduj auta i wróć.', 'error')
        return nil
    end

    local model = GetHashKey(entry.item.model)
    if not WaitModel(model) then
        Config.Notify(('Nie udało się wczytać modelu `%s`.'):format(tostring(entry.item.model)), 'error')
        return nil
    end

    local veh = CreateVehicle(model, sp.x, sp.y, sp.z, sp.w or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, entry.plate)
    SetVehicleEngineOn(veh, true, true, false)
    SetModelAsNoLongerNeeded(model)

    if Config.Docks.keyEvent and Config.Docks.keyEvent ~= '' then
        TriggerEvent(Config.Docks.keyEvent, entry.plate)
    end

    Spawned[entry.index] = veh
    Config.Notify(('Na dokach stoi: %s. Wjedź nim na lawetę.'):format(entry.label), 'success')
    if Config.Debug then print(('[nano_cd] auto z zadania #%d na dokach (entity %s)'):format(entry.index, tostring(veh))) end
    return veh
end

local function PickupByNumber(n)
    local job = CurrentJob()
    if not job then
        return Config.Notify('Najpierw weź zadanie (/pod wez).', 'error')
    end
    local e = DockList(job)[tonumber(n) or 0]
    if not e then
        return Config.Notify('Nie ma takiego numeru na liście – zobacz `/pod menu`.', 'error')
    end
    SpawnCarFor(e)
end

-- ── menu na dokach (ox_lib) z awaryjnym wypisem na czacie ─────────────────────
local function MenuOptions(job)
    local opts = {}

    if not job then
        local any = false
        for _, j in pairs(Jobs) do
            if not j.claimedBy then
                any = true
                opts[#opts + 1] = {
                    title = ('Weź zadanie %s'):format(tostring(j.key)),
                    description = ('%s → %s'):format(
                        tostring(j.buyerLabel or j.buyerJob or 'odbiorca'),
                        tostring(j.destination and j.destination.label or 'miejsce odbioru')),
                    icon = 'fa-solid fa-hand',
                    onSelect = function() TriggerServerEvent('nano_cd:server:take', j.id) end,
                }
            end
        end
        if not any then
            opts[#opts + 1] = {
                title = 'Brak zadań',
                description = 'Poczekaj, aż firma dostawcy przyjmie zamówienie pojazdów.',
                icon = 'fa-solid fa-hourglass-half',
                disabled = true,
            }
        end
        return opts
    end

    local list = DockList(job)
    if #list == 0 then
        opts[#opts + 1] = {
            title = 'Wszystko pobrane',
            description = 'Zostało zawieźć auta na miejsce odbioru.',
            icon = 'fa-solid fa-check',
            disabled = true,
        }
        return opts
    end

    if not FreeSlot() then
        opts[#opts + 1] = {
            title = 'Gniazda lawety zajęte',
            description = ('Na lawecie stoi już %d %s – zawieź je i wróć po kolejne.'):format(
                LoadedCount(), LoadedCount() == 1 and 'auto' or 'auta'),
            icon = 'fa-solid fa-triangle-exclamation',
            disabled = true,
        }
        return opts
    end

    for _, e in ipairs(list) do
        opts[#opts + 1] = {
            title = ('Pobierz: %s'):format(e.label),
            description = e.spawned and 'Auto czeka na dokach – wjedź nim na lawetę.'
                                     or 'Auto pojawi się na dokach – wjedź nim na lawetę.',
            icon = 'fa-solid fa-car-side',
            onSelect = function() SpawnCarFor(e) end,
        }
    end
    return opts
end

local function OpenDockMenu()
    local job = CurrentJob()
    local opts = MenuOptions(job)

    if GetResourceState('ox_lib') == 'started' and lib and lib.registerContext then
        lib.registerContext({ id = 'nano_cd_dock', title = 'Doki – odbiór pojazdów (CD)', options = opts })
        return lib.showContext('nano_cd_dock')
    end

    print('[nano_cd] ── doki: co mogę pobrać ──')
    for _, line in ipairs(MenuLines(job)) do print('   ' .. line) end
    Config.Notify('Lista wypisana w konsoli (F8) – pobierz auto komendą `/pod pobierz <nr>`.', 'info')
end

-- ── ped na dokach + target ────────────────────────────────────────────────────
local function ClosestPedOfModel(model, coords, radius)
    local best, bestDist
    local handle, ped = FindFirstPed()
    local again = true
    repeat
        if ped and ped ~= 0 and DoesEntityExist(ped) and GetEntityModel(ped) == model then
            local d = Dist(GetEntityCoords(ped), coords)
            if d <= radius and (not bestDist or d < bestDist) then best, bestDist = ped, d end
        end
        again, ped = FindNextPed(handle)
    until not again
    EndFindPed(handle)
    return best
end

local function SpawnDockPed()
    local cfg = Config.Docks.ped
    local model = GetHashKey(cfg.model)
    local coords = V3(cfg.coords)

    local existing = ClosestPedOfModel(model, coords, 3.0)
    if not existing then
        Wait(300)
        existing = ClosestPedOfModel(model, coords, 3.0)
    end

    if existing then
        DockPed = existing
    else
        if not WaitModel(model) then
            Config.Notify(('Nie udało się wczytać modelu peda `%s`.'):format(tostring(cfg.model)), 'error')
            return nil
        end
        DockPed = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w or 0.0, false, false)
        SetEntityAsMissionEntity(DockPed, true, true)
        SetModelAsNoLongerNeeded(model)
        if Config.Debug then print(('[nano_cd] ped na dokach postawiony (entity %s)'):format(tostring(DockPed))) end
    end

    SetEntityInvincible(DockPed, cfg.invincible ~= false)
    FreezeEntityPosition(DockPed, cfg.freeze ~= false)
    SetBlockingOfNonTemporaryEvents(DockPed, true)
    SetPedCanRagdoll(DockPed, false)
    if cfg.scenario and cfg.scenario ~= '' then
        TaskStartScenarioInPlace(DockPed, cfg.scenario, 0, true)
    end
    return DockPed
end

local function AddDockTarget()
    if GetResourceState('ox_target') ~= 'started' then return false end

    local t, p = Config.Docks.target, Config.Docks.ped.coords
    local ok, zoneId = pcall(function()
        return exports.ox_target:addBoxZone({
            name = 'nano_cd_dock',
            coords = vector3(p.x, p.y, p.z + 1.0),
            size = t.size,
            rotation = p.w or 0.0,
            debug = Config.Debug,
            options = { {
                name = 'nano_cd_dock_open',
                icon = t.icon,
                label = t.label,
                distance = t.distance,
                onSelect = function() OpenDockMenu() end,
            } },
        })
    end)

    if ok and zoneId then
        DockZone = zoneId
        if Config.Debug then print('[nano_cd] ox_target: strefa na dokach gotowa') end
        return true
    end
    if Config.Debug then print('[nano_cd] ox_target nie przyjął strefy – zostaje klawisz [E] przy pedzie') end
    return false
end

-- ── zestaw: przyczepa + ciężarówka (baza pod car dealerem) ────────────────────
local function TrailerExists() return Trailer ~= nil and DoesEntityExist(Trailer) end
local function TruckExists() return Truck ~= nil and DoesEntityExist(Truck) end

local function TrailerIsAttached()
    if not TrailerExists() then return false end
    local att = GetEntityAttachedTo(Trailer)
    return att ~= nil and att ~= 0
end

-- Zanim postawimy nowy model – sprawdźmy, czy taki pojazd już gdzieś tu nie stoi
-- (dzięki temu drugi gracz nie stawia drugiej przyczepy w tym samym miejscu).
local function FindVehicleNear(model, coords, radius)
    local veh = GetClosestVehicle(coords.x, coords.y, coords.z, radius, GetHashKey(model), 70)
    if veh and veh ~= 0 and DoesEntityExist(veh) then return veh end
    return nil
end

local trailerWasSpawned = false

local function SpawnTrailer()
    if TrailerExists() then return Trailer end

    local c = Config.Base.trailerCoords

    if Config.Trailer.mode == 'static' then
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, Config.Trailer.findRadius or 12.0, GetHashKey(Config.Trailer.model), false, false, false)
        if obj and obj ~= 0 then
            Trailer = obj
            SetEntityAsMissionEntity(Trailer, true, true)
            if Config.Trailer.freeze then FreezeEntityPosition(Trailer, true) end
        end
        return Trailer
    end

    Trailer = FindVehicleNear(Config.Trailer.model, c, 30.0)
    if Trailer then
        if Config.Debug then print(('[nano_cd] przyczepa już stoi w bazie (entity %s)'):format(tostring(Trailer))) end
        trailerWasSpawned = true
        return Trailer
    end

    if not IShouldHaveRig() then return nil end
    if not Config.Trailer.respawnIfMissing and trailerWasSpawned then return nil end

    local model = GetHashKey(Config.Trailer.model)
    if not WaitModel(model) then
        Config.Notify(('Nie udało się wczytać modelu przyczepy `%s`.'):format(tostring(Config.Trailer.model)), 'error')
        return nil
    end

    Trailer = CreateVehicle(model, c.x, c.y, c.z, c.w or 0.0, true, false)
    SetVehicleOnGroundProperly(Trailer)
    SetEntityAsMissionEntity(Trailer, true, true)
    SetVehicleHasBeenOwnedByPlayer(Trailer, true)
    SetModelAsNoLongerNeeded(model)
    if Config.Trailer.freeze then FreezeEntityPosition(Trailer, true) end
    trailerWasSpawned = true
    if Config.Debug then print(('[nano_cd] przyczepa %s postawiona w bazie (entity %s)'):format(Config.Trailer.model, tostring(Trailer))) end
    return Trailer
end

local function SpawnTruck()
    if TruckExists() then return Truck end

    local c = Config.Base.truckCoords
    Truck = FindVehicleNear(Config.Truck.model, c, 30.0)
    if Truck then return Truck end

    if not IShouldHaveRig() then return nil end

    local model = GetHashKey(Config.Truck.model)
    if not WaitModel(model) then return nil end

    Truck = CreateVehicle(model, c.x, c.y, c.z, c.w or 0.0, true, false)
    SetVehicleOnGroundProperly(Truck)
    SetEntityAsMissionEntity(Truck, true, true)
    SetVehicleHasBeenOwnedByPlayer(Truck, true)
    SetModelAsNoLongerNeeded(model)
    if Config.Debug then print(('[nano_cd] auto do ciągnięcia %s postawione w bazie (entity %s)'):format(Config.Truck.model, tostring(Truck))) end
    return Truck
end

-- Zestaw jest „bezczynny”, gdy nic na nim nie stoi, nikt nim nie jedzie i nie ma pobranych aut
local function RigIsIdle()
    if next(Loaded) ~= nil then return false end
    if TrailerExists() and TrailerIsAttached() then return false end
    if TruckExists() and GetPedInVehicleSeat(Truck, -1) ~= 0 then return false end
    for _, veh in pairs(Spawned) do
        if DoesEntityExist(veh) then return false end
    end
    return true
end

local function RemoveRig()
    if TrailerExists() then DeleteEntity(Trailer) end
    if TruckExists() then DeleteEntity(Truck) end
    Trailer, Truck = nil, nil
end

local function TruckModelOk(veh)
    local hash = GetEntityModel(veh)
    for _, m in ipairs(Config.Trailer.truckModels or {}) do
        if hash == GetHashKey(m) then return true end
    end
    return false
end

-- Auto-doczepienie przyczepy do auta, którym jedzie pracownik (wygodne w bazie)
local function AutoAttachTrailer()
    if not Config.Trailer.autoAttachTruck or not TrailerExists() or TrailerIsAttached() then return end
    local veh = GetVehiclePedIsIn(MyPed(), false)
    if veh == 0 or not TruckModelOk(veh) then return end
    if Dist(GetEntityCoords(veh), GetEntityCoords(Trailer)) > 25.0 then return end
    AttachVehicleToTrailer(veh, Trailer, 1.0)
    Config.Notify('Laweta zaczepiona.', 'success')
end

-- Cykl życia zestawu: stawiamy dopiero przy zadaniu, sprzątamy gdy zadań brak
local function ManageRig()
    if IShouldHaveRig() then
        if not TrailerExists() and Config.Trailer.mode ~= 'static' then SpawnTrailer() end
        if not TruckExists() and Config.Truck.mode == 'spawn' then SpawnTruck() end
        return
    end

    if not (Config.Base and Config.Base.removeWhenIdle) then return end
    if not RigIsIdle() then return end

    if TrailerExists() then
        local dist = Dist(MyCoords(), GetEntityCoords(Trailer))
        if dist < (Config.Base.removeDistance or 25.0) then return end
    end
    RemoveRig()
end

-- ── przypinanie auta do lawety ────────────────────────────────────────────────
local function AttachToSlot(veh, item, slotIdx)
    local job = CurrentJob()
    local slot = (Config.Trailer.slots or {})[slotIdx]
    if not job or not slot or not veh or not DoesEntityExist(veh) then return false end

    local o = slot.offset
    local r = slot.rot or { x = 0.0, y = 0.0, z = 0.0 }
    local a = Config.Trailer.attach or {}

    if not autoLoad then
        local ok = Progress(('Przypinanie: %s'):format(tostring(item.name or item.model)))
        if ok == false then return false end
    end

    AttachEntityToEntity(veh, Trailer, slot.bone or 0,
        o.x, o.y, o.z, r.x, r.y, r.z,
        false, a.softPinning and true or false, a.collision and true or false, false,
        a.vertexIndex or 2, a.fixedRot ~= false)

    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleUndriveable(veh, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleDirtLevel(veh, 0.0)

    local plate = tostring(item.plate or '')
    Loaded[slotIdx] = { veh = veh, item = item.index, plate = plate }
    Spawned[item.index] = nil

    TriggerServerEvent('nano_cd:server:loaded', job.id, item.index, plate)
    Config.Notify(('Auto przypięte do gniazda %d/%d. Wysiądź i pobierz kolejne (/pod menu).'):format(
        slotIdx, #(Config.Trailer.slots or {})), 'success')
    return true
end

-- Wjechałeś autem na lawetę? Przypinamy je do pierwszego wolnego gniazda.
local function TryAttachNearTrailer()
    if not TrailerExists() then return end
    local job = CurrentJob()
    if not job then return end

    local tcoords = GetEntityCoords(Trailer)
    for index, veh in pairs(Spawned) do
        if not DoesEntityExist(veh) then
            Spawned[index] = nil
        elseif GetEntityAttachedTo(veh) == 0 then
            local item = ItemOf(job, index)
            if item then
                local d = Dist(GetEntityCoords(veh), tcoords)
                local speed = GetEntitySpeed(veh)
                if d <= (Config.Trailer.attachRadius or 3.6) and speed <= (Config.Trailer.attachMaxSpeed or 2.5) then
                    local slotIdx = FreeSlot()
                    if slotIdx then AttachToSlot(veh, item, slotIdx) end
                end
            end
        end
    end
end

-- ── rozładunek i oddanie ──────────────────────────────────────────────────────
local function UnloadAll(job)
    local plates, trailer = {}, Trailer
    local n = 0
    for slotIdx, entry in pairs(Loaded) do
        n = n + 1
        local veh = entry.veh
        if veh and DoesEntityExist(veh) then
            DetachEntity(veh, true, true)
            SetEntityCollision(veh, true, true)

            local u = (Config.Handover and Config.Handover.unload) or {}
            local idx = n - 1
            local coords = trailer and GetOffsetFromEntityInWorldCoords(trailer,
                u.side or 4.5, (u.firstY or -1.0) - idx * (u.spacing or 6.5), u.z or 0.0) or GetEntityCoords(veh)
            SetEntityCoords(veh, coords.x, coords.y, coords.z, false, false, false, true)
            SetEntityHeading(veh, u.useTrailerHeading ~= false and trailer and GetEntityHeading(trailer) or GetEntityHeading(veh))
            SetVehicleOnGroundProperly(veh)
            SetVehicleEngineOn(veh, false, true, true)
            SetEntityAsMissionEntity(veh, true, true)

            if Config.Handover and Config.Handover.keepVehicles == false then
                DeleteEntity(veh)
            else
                SetEntityAsNoLongerNeeded(veh)
            end
        end
        plates[#plates + 1] = { index = entry.item, plate = entry.plate }
        Loaded[slotIdx] = nil
    end
    return plates
end

local function HandOver(job)
    local plates = UnloadAll(job)
    if #plates == 0 then
        return Config.Notify('Laweta jest pusta.', 'error')
    end
    TriggerServerEvent('nano_cd:server:handin', job.id, plates)
end

-- ── zdarzenia z serwera ───────────────────────────────────────────────────────
RegisterNetEvent('nano_cd:jobs', function(list)
    Jobs = {}
    for _, job in ipairs(list or {}) do Jobs[job.id] = job end
end)

RegisterNetEvent('nano_cd:job', function(job)
    if type(job) ~= 'table' then return end
    Jobs[job.id] = job
    if job.state == 'pending' and not job.claimedBy then
        Config.Notify(('Zadanie %s czeka (do pobrania: %d %s). Weź je: /pod wez'):format(
            tostring(job.key), tostring(job.toLoad or 0),
            (job.toLoad == 1 and 'pojazd' or 'pojazdy')), 'info')
    end
end)

RegisterNetEvent('nano_cd:jobRemove', function(id, why)
    local wasMine = Jobs[id] and Jobs[id].mine
    Jobs[id] = nil
    if DestBlipJob == id and DestBlip then RemoveBlip(DestBlip); DestBlip, DestBlipJob = nil, nil end
    if wasMine then
        for index, veh in pairs(Spawned) do
            if DoesEntityExist(veh) then DeleteEntity(veh) end
            Spawned[index] = nil
        end
    end
    if why == 'cancelled' then
        Config.Notify('Zadanie dostawy zostało anulowane – rozładuj lawetę.', 'warn')
    end
end)

RegisterNetEvent('nano_cd:cleared', function()
    Jobs = {}
    for index, veh in pairs(Spawned) do
        if DoesEntityExist(veh) then DeleteEntity(veh) end
        Spawned[index] = nil
    end
    if DestBlip then RemoveBlip(DestBlip); DestBlip, DestBlipJob = nil, nil end
    Config.Notify('Zejście ze służby – lista zadań wyczyszczona.', 'info')
end)

RegisterNetEvent('nano_cd:notify', function(text, tone)
    Config.Notify(text, tone)
end)

-- ── pętla główna ──────────────────────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(1500)
        BaseBlip = Blip(Config.Base.coords, Config.Base.blip)
        DockBlip = Blip(Config.Docks.coords, Config.Docks.blip)
        SpawnDockPed()
        AddDockTarget()
        TriggerServerEvent('nano_cd:server:resync')
    end)
end)

CreateThread(function()
    Wait(2000)
    while true do
        local wait = 500
        local ped = MyPed()
        local here = GetEntityCoords(ped)
        local baseDist = Dist(here, Config.Base.coords)
        local dockDist = Dist(here, Config.Docks.coords)

        if baseDist < 150.0 then Marker(Config.Base.coords, Config.Base.marker or {}) end
        if dockDist < 150.0 then Marker(Config.Docks.coords, Config.Docks.marker or {}) end

        ManageRig()
        AutoAttachTrailer()
        TryAttachNearTrailer()

        local job = CurrentJob()
        local dest = job and job.destination or nil

        -- blip miejsca odbioru
        if dest then
            if DestBlip and DestBlipJob ~= job.id then RemoveBlip(DestBlip); DestBlip = nil end
            if not DestBlip then
                DestBlip = Blip({ x = dest.x, y = dest.y, z = dest.z },
                    { sprite = 478, color = 1, scale = 1.0, label = ('Odbiór: %s'):format(tostring(dest.label or job.buyerLabel or 'punkt')), shortRange = false })
                SetBlipRoute(DestBlip, true)
                DestBlipJob = job.id
            end
        elseif DestBlip then
            RemoveBlip(DestBlip); DestBlip = nil; DestBlipJob = nil
        end

        if job then
            local trailer = TrailerExists() and Trailer or nil
            local trailerDist = trailer and Dist(here, GetEntityCoords(trailer)) or 9999.0
            local destDist = dest and Dist(here, V3(dest)) or 9999.0
            local toGet = DockList(job)

            -- ── podpowiedź: jedź z bazy na doki ──
            if job.state == 'loading' and baseDist < (Config.Base.radius or 45.0) and dockDist > (Config.Docks.radius or 70.0) then
                wait = 0
                Help(('Auta czekają na dokach (%.0f m) – jedź tam lawetą.'):format(dockDist))
            end

            -- ── DOKI: podpowiedź przy pedzie ──
            if job.state == 'loading' and dockDist < (Config.Docks.radius or 70.0) then
                local pedDist = Dist(here, V3(Config.Docks.ped.coords))

                if not trailer then
                    wait = 0
                    Help('Przyczepa nie stoi jeszcze w bazie – podjedź do bazy CD.')
                elseif trailerDist > 30.0 then
                    wait = 0
                    Help(('Podjedź lawetą na doki (%.0f m) – auta czekają na pobranie.'):format(dockDist))
                elseif toGet[1] then
                    wait = 0
                    if pedDist < 4.0 then
                        Help(('[E] Odbiór pojazdów (CD) – do pobrania: %d'):format(#toGet))
                        if not DockZone and IsControlJustPressed(0, interactKey) then OpenDockMenu() end
                    else
                        Help(('Podejdź do obsługi doków (%.0f m) i wybierz auto z listy.'):format(pedDist))
                    end
                elseif FreeSlot() then
                    wait = 0
                    Help('Wjedź autem na lawetę – przypnie się samo.')
                else
                    wait = 0
                    Help('Gniazda zajęte – jedź oddać auta i wróć po kolejne.')
                end
            end

            -- ── ODDANIE (tylko w miejscu odbioru) ──
            if job.state == 'hauling' and dest and destDist < ((Config.Handover and Config.Handover.radius) or 25.0) and next(Loaded) ~= nil then
                wait = 0
                Help(('[E] Oddaj pojazdy (%d) – %s'):format(LoadedCount(), tostring(dest.label or 'miejsce odbioru')))
                if IsControlJustPressed(0, interactKey) then
                    if Progress('Rozładunek lawety') ~= false then HandOver(job) end
                end
            elseif job.state == 'hauling' and dest and next(Loaded) == nil then
                wait = 0
                Help('Laweta jest pusta – wracaj na doki po auta.')
            end
        elseif NeedTrailer() and baseDist < (Config.Base.radius or 45.0) then
            wait = 0
            Help('Jest zamówienie do zawiezienia – weź zadanie: /pod wez')
        end

        Wait(wait)
    end
end)

-- ── komendy ───────────────────────────────────────────────────────────────────
local function Dump()
    print('[nano_cd] ── stan ──')
    local pobrane = 0
    for _, veh in pairs(Spawned) do
        if DoesEntityExist(veh) then pobrane = pobrane + 1 end
    end
    print(('  zadania: %d | przyczepa: %s | ciężarówka: %s | na lawecie: %d | pobrane na dokach: %d | do pobrania: %d'):format(
        (function() local n = 0 for _ in pairs(Jobs) do n = n + 1 end return n end)(),
        TrailerExists() and tostring(Trailer) or 'brak',
        TruckExists() and tostring(Truck) or 'brak', LoadedCount(), pobrane, #DockList(CurrentJob())))
    for _, job in pairs(Jobs) do
        print(('  %s: %s | do pobrania: %s | do przewiezienia: %s | wiezie: %s | cel: %s'):format(
            tostring(job.key), tostring(job.state), tostring(job.toLoad), tostring(job.remaining),
            tostring(job.claimedName or '-'), tostring(job.destination and job.destination.label or 'brak')))
    end
    for slotIdx, e in pairs(Loaded) do
        print(('  gniazdo %d: %s (%s)'):format(slotIdx, tostring(e.veh), tostring(e.plate)))
    end
end

-- Wypisuje gotową linijkę do configu na podstawie tego, gdzie stoisz / czym jedziesz
local function SaveLine(what)
    local veh = GetVehiclePedIsIn(MyPed(), false)
    local pos = veh ~= 0 and GetEntityCoords(veh) or MyCoords()
    local heading = veh ~= 0 and GetEntityHeading(veh) or GetEntityHeading(MyPed())
    local x, y, z, w = pos.x, pos.y, pos.z, heading

    local lines = {
        base      = ('    coords = vector3(%.2f, %.2f, %.2f),'):format(x, y, z),
        przyczepa = ('    trailerCoords = vector4(%.2f, %.2f, %.2f, %.1f),'):format(x, y, z, w),
        truck     = ('    truckCoords = vector4(%.2f, %.2f, %.2f, %.1f),'):format(x, y, z, w),
        doki      = ('    coords = vector3(%.2f, %.2f, %.2f),'):format(x, y, z),
        ped       = ('        coords = vector4(%.2f, %.2f, %.2f, %.1f),'):format(x, y, z, w),
        punkt     = ('        vector4(%.2f, %.2f, %.2f, %.1f),'):format(x, y, z, w),
        oddanie   = ('        x = %.2f, y = %.2f, z = %.2f, heading = %.1f,'):format(x, y, z, w),
    }

    local line = lines[what]
    if not line then
        return Config.Notify('Użycie: /pod zapisz base | przyczepa | truck | doki | ped | punkt | oddanie', 'error')
    end
    print(('[nano_cd] %s → wklej do config.lua:'):format(what))
    print('[nano_cd] ' .. line)
    Config.Notify(('Linijka dla „%s” wypisana w konsoli (F8).'):format(what), 'success')
end

local function SlotInfo(n)
    local trailer = Trailer
    if not trailer or not DoesEntityExist(trailer) then return Config.Notify('Najpierw postaw przyczepę (/pod przyczepa).', 'error') end
    local veh = GetVehiclePedIsIn(MyPed(), false)
    if veh == 0 then veh = GetPlayersLastVehicle() end
    if veh == 0 or not DoesEntityExist(veh) then return Config.Notify('Wsiądź do auta, które chcesz skalibrować.', 'error') end

    local c = GetEntityCoords(veh)
    local rel = GetOffsetFromEntityGivenWorldCoords(trailer, c.x, c.y, c.z)
    local vr, tr = GetEntityRotation(veh, 2), GetEntityRotation(trailer, 2)
    local function norm(a) a = a % 360.0; if a > 180.0 then a = a - 360.0 end; return a end
    local line = ('        { offset = vector3(%.2f, %.2f, %.2f), rot = vector3(%.0f, %.0f, %.0f), bone = 0 },'):format(
        rel.x, rel.y, rel.z, norm(vr.x - tr.x), norm(vr.y - tr.y), norm(vr.z - tr.z))
    print(('[nano_cd] gniazdo %d → wklej do Config.Trailer.slots:'):format(n))
    print('[nano_cd] ' .. line)
    Config.Notify('Offset gniazda wypisany w konsoli (F8).', 'success')
end

RegisterCommand('pod', function(_, args)
    local sub = (args[1] or ''):lower()

    if sub == 'help' then
        print('[nano_cd] /pod | /pod help | /pod wez [id] | /pod menu | /pod pobierz [nr] | /pod attach [n] | /pod oddaj | /pod przyczepa | /pod truck | /pod sprzataj | /pod slot [n] | /pod zapisz <co> | /pod test')
        print('[nano_cd] służbę włączasz/wyłączasz w systemie duty crp_jobcore (punkt duty), nie tutaj.')

    elseif sub == 'menu' then
        OpenDockMenu()

    elseif sub == 'pobierz' then
        PickupByNumber(tonumber(args[2]) or 1)

    elseif sub == 'wez' then
        local id = tonumber(args[2])
        if not id then
            local best
            for _, job in pairs(Jobs) do
                if job.state == 'pending' and not job.claimedBy and (not best or (job.receivedAt or 0) < (best.receivedAt or 0)) then best = job end
            end
            id = best and best.id or nil
        end
        if not id then return Config.Notify('Brak wolnych zadań.', 'error') end
        TriggerServerEvent('nano_cd:server:take', id)

    elseif sub == 'przyczepa' then
        if SpawnTrailer() then Config.Notify('Zestaw jest w bazie.', 'success') end

    elseif sub == 'truck' then
        if SpawnTruck() then Config.Notify('Auto do ciągnięcia stoi w bazie.', 'success') end

    elseif sub == 'sprzataj' then
        for index, veh in pairs(Spawned) do
            if DoesEntityExist(veh) then DeleteEntity(veh) end
            Spawned[index] = nil
        end
        RemoveRig()
        Config.Notify('Zestaw i pobrane auta usunięte.', 'info')

    elseif sub == 'attach' then
        local n = tonumber(args[2]) or FreeSlot()
        local job = CurrentJob()
        if not job then return Config.Notify('Najpierw weź zadanie (/pod wez).', 'error') end
        if not n then return Config.Notify('Wszystkie gniazda są zajęte.', 'error') end
        if not TrailerExists() then return Config.Notify('Nie ma przyczepy – /pod przyczepa.', 'error') end

        local veh = GetVehiclePedIsIn(MyPed(), false)
        if veh == 0 then veh = GetPlayersLastVehicle() end
        if veh == 0 or not DoesEntityExist(veh) then return Config.Notify('Brak auta do przypięcia.', 'error') end

        local plate = tostring(GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', '')
        local item
        for _, e in ipairs(DockList(job)) do
            if e.plate == plate then item = e.item break end
        end
        item = item or (DockList(job)[1] and DockList(job)[1].item)
        if not item then return Config.Notify('Z tego zadania nie ma już czego przypinać.', 'error') end

        AttachToSlot(veh, item, n)

    elseif sub == 'slot' then
        SlotInfo(tonumber(args[2]) or 1)

    elseif sub == 'zapisz' then
        SaveLine((args[2] or ''):lower())

    elseif sub == 'oddaj' then
        local job = CurrentJob()
        if not job then return Config.Notify('Nie wieziesz żadnego zadania.', 'error') end
        local dest = job.destination
        if not dest or Dist(MyCoords(), V3(dest)) > ((Config.Handover and Config.Handover.radius) or 25.0) then
            return Config.Notify('Jesteś za daleko od miejsca odbioru – podjedź na miejsce.', 'error')
        end
        HandOver(job)

    elseif sub == 'test' then
        autoLoad = true
        local best
        for _, job in pairs(Jobs) do
            if not job.claimedBy and (not best or (job.receivedAt or 0) < (best.receivedAt or 0)) then best = job end
        end
        if not best then
            return Config.Notify('Brak zadań – złóż zamówienie pojazdów w boss menu i przyjmij je.', 'error')
        end
        TriggerServerEvent('nano_cd:server:take', best.id)
        Config.Notify('Test: zestaw stoi w bazie, auta czekają na dokach – pobieraj z listy.', 'info')

    else
        Dump()
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if BaseBlip then RemoveBlip(BaseBlip) end
    if DockBlip then RemoveBlip(DockBlip) end
    if DestBlip then RemoveBlip(DestBlip) end
    if DockZone and GetResourceState('ox_target') == 'started' and exports.ox_target then
        pcall(function() exports.ox_target:removeZone(DockZone) end)
    end
end)

-- ── podgląd dla testów / innych skryptów (nieużywane w grze) ──────────────────
_G.nanoCDC = {
    DockList = DockList,
    MenuLines = MenuLines,
    NeedTrailer = NeedTrailer,
    IShouldHaveRig = IShouldHaveRig,
    FreeSlot = FreeSlot,
    LoadedCount = LoadedCount,
    RigIsIdle = RigIsIdle,
    SetJobs = function(t) Jobs = t or {} end,
    SetLoaded = function(t) Loaded = t or {} end,
    SetSpawned = function(t) Spawned = t or {} end,
    SetTrailer = function(v) Trailer = v end,
    SetTruck = function(v) Truck = v end,
}
