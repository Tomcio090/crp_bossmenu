-- ██████████████████████████████████████████████████████████████████████████████
--  nano_cd / client.lua — wozi auta lawetą `tr2` (start skryptu CD/POD)
--
--  Klient odpowiada za część „fizyczną”:
--   · stawia przyczepę `tr2` (i – jeśli chcesz – auto do ciągnięcia) na placu,
--   · ładuje na nią pojazdy z zamówienia i DOCZEPIA je do gniazd (AttachEntityToEntity),
--   · pilnuje, żeby auta oddawać wyłącznie w miejscu odbioru (promień z configu),
--   · zgłasza serwerowi „załadowane” / „oddane”, a serwer przekazuje to do boss menu.
--
--  Komendy do testów (w grze, na czacie):
--   /pod            – stan zadań i przyczepy
--   /pod help       – lista komend
--   /pod sluzba     – start/koniec służby (gdy Config.AllowAnyone = false)
--   /pod wez [id]   – weź zadanie (bez id: pierwsze wolne)
--   /pod test       – szybki test: przyczepa + auto + wszystkie auta na gniazda
--   /pod auto       – włącz/wyłącz automatyczny załadunek (tryb testowy)
--   /pod przyczepa  – postaw przyczepę na placu
--   /pod truck      – postaw auto do ciągnięcia (packer)
--   /pod attach <n> – doczep swoje ostatnie auto do gniazda n (kalibracja)
--   /pod slot <n>   – wypisz offset/rot auta względem przyczepy (do wklejenia w config)
--   /pod oddaj      – oddaj auta (tylko w miejscu odbioru)
-- ██████████████████████████████████████████████████████████████████████████████

local Jobs = {}                -- [id] = zadanie (to, co przysłał serwer)
local Trailer = nil            -- uchwyt przyczepy `tr2`
local Loaded = {}              -- [gniazdo] = { veh = auto, item = numer pozycji, plate = tablica }
local autoLoad = Config.AutoLoad and true or false
local Duty = false
local DepotBlip, DestBlip, DestBlipJob
local ESX

CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok then ESX = obj end
    end
end)

-- ── narzędzia ─────────────────────────────────────────────────────────────────
local function Dist(a, b)
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

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

-- ── przyczepa ─────────────────────────────────────────────────────────────────
local function TrailerExists()
    return Trailer ~= nil and DoesEntityExist(Trailer)
end

local function WaitModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local guard = 0
    while not HasModelLoaded(model) and guard < 200 do Wait(10); guard = guard + 1 end
    return HasModelLoaded(model)
end

local function SpawnTrailer()
    if TrailerExists() then return Trailer end

    local c = Config.Trailer.coords
    if Config.Trailer.mode == 'static' then
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, Config.Trailer.findRadius or 12.0, GetHashKey(Config.Trailer.model), false, false, false)
        if obj ~= 0 then
            Trailer = obj
            SetEntityAsMissionEntity(Trailer, true, true)
            if Config.Trailer.freeze then FreezeEntityPosition(Trailer, true) end
            return Trailer
        end
    end

    local model = GetHashKey(Config.Trailer.model)
    if not WaitModel(model) then
        Config.Notify(('Nie udało się wczytać modelu przyczepy `%s`.'):format(Config.Trailer.model), 'error')
        return nil
    end
    Trailer = CreateVehicle(model, c.x, c.y, c.z, c.w or 0.0, true, false)
    SetVehicleOnGroundProperly(Trailer)
    SetEntityAsMissionEntity(Trailer, true, true)
    SetVehicleHasBeenOwnedByPlayer(Trailer, true)
    SetModelAsNoLongerNeeded(model)
    if Config.Trailer.freeze then FreezeEntityPosition(Trailer, true) end
    if Config.Debug then print(('[nano_cd] przyczepa %s postawiona (entity %s)'):format(Config.Trailer.model, tostring(Trailer))) end
    return Trailer
end

local function SpawnTruck()
    local t = Config.Truck
    local model = GetHashKey(t.model)
    if not WaitModel(model) then return nil end
    local veh = CreateVehicle(model, t.coords.x, t.coords.y, t.coords.z, t.coords.w or 0.0, true, false)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetModelAsNoLongerNeeded(model)
    return veh
end

local function TrailerIsAttached()
    if not TrailerExists() then return false end
    local att = GetEntityAttachedTo(Trailer)
    return att ~= nil and att ~= 0
end

local function TruckModelOk(veh)
    local hash = GetEntityModel(veh)
    for _, m in ipairs(Config.Trailer.truckModels or {}) do
        if hash == GetHashKey(m) then return true end
    end
    return false
end

-- auto-doczepienie przyczepy do auta, którym jedzie pracownik (wygodne na placu)
local function AutoAttachTrailer()
    if not Config.Trailer.autoAttachTruck or not TrailerExists() or TrailerIsAttached() then return end
    local veh = GetVehiclePedIsIn(MyPed(), false)
    if veh == 0 or not TruckModelOk(veh) then return end
    if Dist(GetEntityCoords(veh), GetEntityCoords(Trailer)) > 25.0 then return end
    AttachVehicleToTrailer(veh, Trailer, 1.0)
    Config.Notify('Laweta zaczepiona.', 'success')
end

-- ── załadunek ─────────────────────────────────────────────────────────────────
local function CurrentJob()
    local best
    for _, job in pairs(Jobs) do
        if job.mine then
            if not best or (job.receivedAt or 0) < (best.receivedAt or 0) then best = job end
        end
    end
    return best
end

local function NextItemToLoad(job)
    if not job then return nil end
    for _, it in ipairs(job.items or {}) do
        -- szybki transport (express) jedzie do garażu od razu – nie ładujemy go na lawetę
        if not it.express and not (job.loaded and job.loaded[it.index]) and not (job.handed and job.handed[it.index]) then
            return it
        end
    end
    return nil
end

local function LoadedCount()
    local n = 0
    for _ in pairs(Loaded) do n = n + 1 end
    return n
end

local function FreeSlot()
    for i = 1, #(Config.Trailer.slots or {}) do
        if not Loaded[i] then return i end
    end
    return nil
end

local function Plate(item) return tostring(item.plate or '') end

-- tworzy auto i doczepia je do gniazda `slotIdx`
local function AttachCar(item, slotIdx)
    local trailer = SpawnTrailer()
    if not trailer then return nil end

    local slot = (Config.Trailer.slots or {})[slotIdx]
    if not slot then
        Config.Notify('Brak takiego gniazda na lawecie (sprawdź Config.Trailer.slots).', 'error')
        return nil
    end

    local model = GetHashKey(item.model)
    if not WaitModel(model) then
        Config.Notify(('Nie udało się wczytać modelu `%s`.'):format(tostring(item.model)), 'error')
        return nil
    end

    local o, r = slot.offset, slot.rot or { x = 0.0, y = 0.0, z = 0.0 }
    local coords = GetOffsetFromEntityInWorldCoords(trailer, o.x, o.y, o.z)
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, GetEntityHeading(trailer), true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleDirtLevel(veh, 0.0)

    local plate = Plate(item)
    SetVehicleNumberPlateText(veh, plate)

    if Config.Trailer.attach.placeOnGroundBeforeAttach then
        SetVehicleOnGroundProperly(veh)
        Wait(50)
    end
    if Config.Trailer.attach.freezeDuringAttach then
        FreezeEntityPosition(veh, true)
    end

    -- ██ DOCZEPIENIE AUTA DO PRZYCZEPY ██
    --  AttachEntityToEntity(auto, przyczepa, kość, offsetX/Y/Z, rotX/Y/Z,
    --                       isPed, softPinning, collision, isCar, vertexIndex, fixedRot)
    local a = Config.Trailer.attach
    AttachEntityToEntity(veh, trailer, slot.bone or 0,
        o.x, o.y, o.z, r.x, r.y, r.z,
        false, a.softPinning and true or false, a.collision and true or false, false,
        a.vertexIndex or 2, a.fixedRot ~= false)
    FreezeEntityPosition(veh, false)
    SetModelAsNoLongerNeeded(model)
    SetVehicleEngineOn(veh, false, true, true)   -- silnik zgaszony, żeby auto nie uciekało z lawety
    SetVehicleUndriveable(veh, false)

    Loaded[slotIdx] = { veh = veh, item = item.index, plate = plate }
    if Config.Debug then
        print(('[nano_cd] auto %s (%s) na gnieździe %d – offset (%.2f, %.2f, %.2f)'):format(
            tostring(item.name or item.model), plate, slotIdx, o.x, o.y, o.z))
    end
    return veh
end

local function LoadOne(job, item, silent)
    local slotIdx = FreeSlot()
    if not slotIdx then
        if not silent then Config.Notify('Wszystkie gniazda lawety są zajęte – zawieź auta i wróć.', 'error') end
        return false
    end
    if not silent then
        local ok = Progress(('Załadunek: %s'):format(tostring(item.name or item.model)))
        if ok == false then return false end          -- gracz przerwał progres
    end
    if not AttachCar(item, slotIdx) then return false end
    TriggerServerEvent('nano_cd:server:loaded', job.id, item.index, Plate(item))
    return true
end

-- zjechać autami z lawety i posprzątać stan lokalny
local function UnloadAll(job)
    local plates, trailer = {}, Trailer
    local n = 0
    for slotIdx, entry in pairs(Loaded) do
        n = n + 1
        local veh = entry.veh
        if veh and DoesEntityExist(veh) then
            DetachEntity(veh, true, true)
            SetEntityCollision(veh, true, true)

            local u = Config.Handover.unload or {}
            local idx = n - 1
            local coords = trailer and GetOffsetFromEntityInWorldCoords(trailer,
                u.side or 4.5, (u.firstY or -1.0) - idx * (u.spacing or 6.5), u.z or 0.0) or GetEntityCoords(veh)
            SetEntityCoords(veh, coords.x, coords.y, coords.z, false, false, false, true)
            SetEntityHeading(veh, u.useTrailerHeading ~= false and trailer and GetEntityHeading(trailer) or GetEntityHeading(veh))
            SetVehicleOnGroundProperly(veh)
            SetVehicleEngineOn(veh, false, true, true)
            SetEntityAsMissionEntity(veh, true, true)

            if not Config.Handover.keepVehicles then
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

-- ── zdarzenia z serwera ───────────────────────────────────────────────────────
RegisterNetEvent('nano_cd:jobs', function(list)
    Jobs = {}
    for _, job in ipairs(list or {}) do Jobs[job.id] = job end
end)

RegisterNetEvent('nano_cd:job', function(job)
    if type(job) ~= 'table' then return end
    Jobs[job.id] = job
    if job.state == 'pending' and Duty and not job.claimedBy then
        Config.Notify(('Zadanie %s czeka na placu CD (%d %s).'):format(job.key, job.toLoad or 0,
            (job.toLoad == 1 and 'pojazd' or 'pojazdy')), 'info')
    end
end)

RegisterNetEvent('nano_cd:jobRemove', function(id, why)
    Jobs[id] = nil
    if DestBlipJob == id and DestBlip then RemoveBlip(DestBlip); DestBlip, DestBlipJob = nil, nil end
    if why == 'cancelled' then Config.Notify('Zadanie dostawy zostało anulowane – rozładuj lawetę.', 'warn') end
end)

RegisterNetEvent('nano_cd:cleared', function()
    Duty = false
    Jobs = {}
    Config.Notify('Koniec służby CD.', 'info')
end)

RegisterNetEvent('nano_cd:notify', function(text, tone)
    Config.Notify(text, tone)
end)

-- ── pętla główna ──────────────────────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        DepotBlip = Blip(Config.Depot.coords, Config.Depot.blip)
        if Config.AutoDuty or Config.AllowAnyone then
            TriggerServerEvent('nano_cd:server:duty', true)
            Duty = true
        end
        TriggerServerEvent('nano_cd:server:resync')
        if Config.Trailer.respawnIfMissing then SpawnTrailer() end
    end)
end)

CreateThread(function()
    Wait(1500)
    while true do
        local wait = 500
        local ped = MyPed()
        local here = GetEntityCoords(ped)
        local depotDist = Dist(here, Config.Depot.coords)

        -- blip/marker placu
        if depotDist < 150.0 then
            Marker(Config.Depot.coords, Config.Depot.marker or {})
        end

        -- auto-doczepienie lawety
        AutoAttachTrailer()

        -- przyczepa zniknęła? postaw nową (jeśli tak ustawiono)
        if Config.Trailer.respawnIfMissing and Config.Trailer.mode == 'spawn' and not TrailerExists() and LoadedCount() == 0 then
            SpawnTrailer()
        end

        local job = CurrentJob()

        -- blip miejsca odbioru
        local dest = job and job.destination or nil
        if dest then
            if DestBlip and DestBlipJob ~= job.id then RemoveBlip(DestBlip); DestBlip = nil end
            if not DestBlip then
                DestBlip = Blip({ x = dest.x, y = dest.y, z = dest.z }, { sprite = 478, color = 1, scale = 1.0, label = ('Odbiór: %s'):format(dest.label or job.buyerLabel or 'punkt'), shortRange = false })
                SetBlipRoute(DestBlip, true)
                DestBlipJob = job.id
                Config.Notify(('Cel: %s. Załaduj auta na lawetę.'):format(dest.label or 'punkt odbioru'), 'info')
            end
        elseif DestBlip then
            RemoveBlip(DestBlip); DestBlip = nil; DestBlipJob = nil
        end

        if job then
            local trailer = TrailerExists() and Trailer or nil
            local trailerDist = trailer and Dist(here, GetEntityCoords(trailer)) or 9999.0
            local destDist = dest and Dist(here, dest) or 9999.0

            -- ── ZAŁADUNEK (na placu, przy przyczepie) ──
            if job.state == 'loading' and depotDist < (Config.Depot.radius or 45.0) and trailerDist < 12.0 then
                local item = NextItemToLoad(job)
                local slot = FreeSlot()
                if item and slot then
                    wait = 0
                    Help(('[E] Załaduj na lawetę: %s (gniazdo %d/%d)'):format(
                        tostring(item.name or item.model), slot, #(Config.Trailer.slots or {})))
                    if autoLoad or IsControlJustPressed(0, (Config.Keys and Config.Keys.interact) or 38) then
                        LoadOne(job, item, autoLoad)
                    end
                elseif not item then
                    wait = 0
                    Help('Wszystkie auta z tego zadania są na lawecie – jedź do miejsca odbioru.')
                else
                    wait = 0
                    Help('Wszystkie gniazda zajęte – zawieź auta do miejsca odbioru i wróć.')
                end
            end

            -- ── ODDANIE (tylko w miejscu odbioru) ──
            if job.state == 'hauling' and dest and destDist < (Config.Handover.radius or 25.0) and next(Loaded) ~= nil then
                wait = 0
                Help(('[E] Oddaj pojazdy (%d) – %s'):format(LoadedCount(), dest.label or 'miejsce odbioru'))
                if IsControlJustPressed(0, (Config.Keys and Config.Keys.interact) or 38) then
                    if Progress('Rozładunek lawety') ~= false then
                        local plates = UnloadAll(job)
                        TriggerServerEvent('nano_cd:server:handin', job.id, plates)
                    end
                end
            elseif job.state == 'hauling' and dest and next(Loaded) == nil then
                wait = 0
                Help(('Laweta pusta – wracaj na plac CD (%.0f m).'):format(depotDist))
            end
        end

        Wait(wait)
    end
end)

-- ── komendy ───────────────────────────────────────────────────────────────────
local function Dump()
    print('[nano_cd] ── stan ──')
    print(('  służba: %s | przyczepa: %s | zajęte gniazda: %d'):format(tostring(Duty),
        TrailerExists() and tostring(Trailer) or 'brak', LoadedCount()))
    for _, job in pairs(Jobs) do
        print(('  %s: %s | do załadowania: %s | do przewiezienia: %s | wiezie: %s | cel: %s'):format(
            tostring(job.key), tostring(job.state), tostring(job.toLoad), tostring(job.remaining),
            tostring(job.claimedName or '-'), tostring(job.destination and job.destination.label or 'brak')))
    end
    for slotIdx, e in pairs(Loaded) do
        print(('  gniazdo %d: %s (%s)'):format(slotIdx, tostring(e.veh), tostring(e.plate)))
    end
end

local function SlotInfo(n)
    local trailer = Trailer
    if not trailer or not DoesEntityExist(trailer) then return Config.Notify('Najpierw postaw przyczepę (/pod przyczepa).', 'error') end
    local veh = GetVehiclePedIsIn(MyPed(), false)
    if veh == 0 then veh = GetPlayersLastVehicle() end
    if veh == 0 or not DoesEntityExist(veh) then return Config.Notify('Wsiądź do auta, które chcesz skalibrować (albo ustaw je na gnieździe).', 'error') end

    local c = GetEntityCoords(veh)
    local rel = GetOffsetFromEntityGivenWorldCoords(trailer, c.x, c.y, c.z)
    local vr, tr = GetEntityRotation(veh, 2), GetEntityRotation(trailer, 2)
    local function norm(a) a = a % 360.0; if a > 180.0 then a = a - 360.0 end; return a end
    local line = ('{ offset = vector3(%.2f, %.2f, %.2f), rot = vector3(%.0f, %.0f, %.0f), bone = 0 }, -- gniazdo %d'):format(
        rel.x, rel.y, rel.z, norm(vr.x - tr.x), norm(vr.y - tr.y), norm(vr.z - tr.z), n)
    print('[nano_cd] ' .. line)
    Config.Notify('Offset gniazda wypisany w konsoli (F8) – wklej go do Config.Trailer.slots.', 'success')
end

RegisterCommand('pod', function(_, args)
    local sub = (args[1] or ''):lower()

    if sub == 'help' then
        print('[nano_cd] /pod | /pod help | /pod sluzba | /pod wez [id] | /pod test | /pod auto | /pod przyczepa | /pod truck | /pod attach <n> | /pod slot <n> | /pod oddaj')

    elseif sub == 'sluzba' then
        Duty = not Duty
        TriggerServerEvent('nano_cd:server:duty', Duty)

    elseif sub == 'auto' then
        autoLoad = not autoLoad
        Config.Notify(('Automatyczny załadunek: %s'):format(autoLoad and 'WŁĄCZONY' or 'wyłączony'), 'info')

    elseif sub == 'przyczepa' then
        SpawnTrailer()

    elseif sub == 'truck' then
        SpawnTruck()

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

    elseif sub == 'test' then
        -- szybka weryfikacja: przyczepa + auto + weź zadanie + załaduj wszystko
        SpawnTrailer()
        if Config.Truck.mode ~= 'none' then SpawnTruck() end
        autoLoad = true
        local best
        for _, job in pairs(Jobs) do
            if not job.claimedBy and (not best or (job.receivedAt or 0) < (best.receivedAt or 0)) then best = job end
        end
        if not best then return Config.Notify('Brak zadań do przetestowania – złóż zamówienie pojazdów w boss menu.', 'error') end
        TriggerServerEvent('nano_cd:server:take', best.id)
        Config.Notify('Test: załaduję wszystkie auta automatycznie, potem jedź do punktu odbioru.', 'info')

    elseif sub == 'attach' then
        local n = tonumber(args[2]) or 1
        local veh = GetVehiclePedIsIn(MyPed(), false)
        if veh == 0 then veh = GetPlayersLastVehicle() end
        if veh == 0 or not DoesEntityExist(veh) then return Config.Notify('Brak auta do doczepienia.', 'error') end
        local trailer = SpawnTrailer()
        if not trailer then return end
        local slot = (Config.Trailer.slots or {})[n]
        if not slot then return Config.Notify('Brak takiego gniazda w configu.', 'error') end
        local o, r = slot.offset, slot.rot or { x = 0, y = 0, z = 0 }
        AttachEntityToEntity(veh, trailer, slot.bone or 0, o.x, o.y, o.z, r.x, r.y, r.z,
            false, false, false, false, 2, true)
        Config.Notify(('Auto doczepione do gniazda %d – popraw offset komendą /pod slot %d.'):format(n, n), 'success')

    elseif sub == 'slot' then
        SlotInfo(tonumber(args[2]) or 1)

    elseif sub == 'oddaj' then
        local job = CurrentJob()
        if not job then return Config.Notify('Nie wieziesz żadnego zadania.', 'error') end
        local dest = job.destination
        if not dest or Dist(MyCoords(), dest) > (Config.Handover.radius or 25.0) then
            return Config.Notify('Jesteś za daleko od miejsca odbioru – podjedź na miejsce.', 'error')
        end
        local plates = UnloadAll(job)
        if #plates == 0 then return Config.Notify('Laweta jest pusta.', 'error') end
        TriggerServerEvent('nano_cd:server:handin', job.id, plates)

    else
        Dump()
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if DepotBlip then RemoveBlip(DepotBlip) end
    if DestBlip then RemoveBlip(DestBlip) end
end)
