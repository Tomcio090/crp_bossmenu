-- ██████████████████████████████████████████████████████████████████████████████
--  nano_cd / server.lua — logika dostaw (autorytet: serwer)
--
--  Serwer trzyma prawdę o zadaniach: co jest do przewiezienia, kto to wiezie,
--  co już załadowano i co oddano. Klient tylko stawia auta na lawecie i zgłasza fakty.
--
--  Kontrakt z boss menu (crp_jobcore):
--    ←  crp_cd:server:start   { orderId='ord-12', id=12, buyerJob, buyerLabel, supplierJob,
--                               total, destination={x,y,z,heading,label}|nil,
--                               items = { { index, model, name, category, express, plate } } }
--    ←  crp_cd:server:cancel  'ord-12'/'12', powód
--    ←  crp_cd:server:resend  (to samo co start – np. ponowne wysłanie zadania)
--    →  crp_bossmenu:server:deliveryDone  orderId, { {index, plate}, ... }, final, byName
--    →  crp_bossmenu:server:deliveryResend  (prośba: wyślij ponownie wszystkie aktywne zadania)
-- ██████████████████████████████████████████████████████████████████████████████

local CD = { jobs = {}, duty = {} }      -- jobs = [id zadania], duty = [source] = true

-- `source` przy TriggerEvent z INNEGO zasobu to nazwa zasobu (tekst), nie numer gracza –
-- bierzemy tylko prawdziwych graczy, żeby obcy skrypt nie przewrócił zadania
local function srcOf(v)
    if type(v) == 'number' then return (v > 0) and v or nil end
    if type(v) == 'string' then local n = tonumber(v); return (n and n > 0) and n or nil end
    return nil
end

CD.__name = 'nano_cd'
exports('Jobs', function() return CD.jobs end)
exports('Job', function(id) return CD.jobs[tonumber(id)] end)

-- Skróty do testów / innych skryptów (np. `nanoCD.jobs` w konsoli)
_G.nanoCD = CD

-- ── narzędzia ─────────────────────────────────────────────────────────────────
local function log(fmt, ...)
    if Config.Debug then print(('^5[nano_cd]^7 %s'):format(string.format(fmt, ...))) end
end

local function Dist(a, b)
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function PlayerName(src)
    if not src or src == 0 then return 'System' end
    local ok, name = pcall(GetPlayerName, src)
    if ok and name then return name end
    return ('gracz #%d'):format(src)
end

local function dbQuery(q, params)
    if not Config.Persist or not MySQL or not MySQL.query then return nil end
    local ok, res = pcall(function() return MySQL.query.await(q, params) end)
    if not ok then log('baza: %s', tostring(res)) return nil end
    return res
end

local function Build()
    dbQuery([[CREATE TABLE IF NOT EXISTS `crp_cd_jobs` (
        `id` INT NOT NULL,
        `data` LONGTEXT NOT NULL,
        `state` VARCHAR(12) NOT NULL DEFAULT 'pending',
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function SaveJob(job)
    if not Config.Persist then return end
    job.updatedAt = os.time()
    dbQuery('INSERT INTO `crp_cd_jobs` (`id`, `data`, `state`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `data` = VALUES(`data`), `state` = VALUES(`state`)',
        { job.id, json.encode(job), job.state })
end

local function DropJob(id)
    if Config.Persist then dbQuery('DELETE FROM `crp_cd_jobs` WHERE `id` = ?', { id }) end
end

-- ── stan zadania ──────────────────────────────────────────────────────────────
local function Item(job, i) return job.items and job.items[i] end

local function Remaining(job)                 -- ile aut jeszcze trzeba odwieźć (bez szybkiego transportu)
    local n = 0
    for i, it in ipairs(job.items or {}) do
        if not it.express and not (job.handed and job.handed[i]) then n = n + 1 end
    end
    return n
end

local function LoadedCount(job)
    local n = 0
    for _ in pairs(job.loaded or {}) do n = n + 1 end
    return n
end

local function ToLoad(job)
    local n = 0
    for i, it in ipairs(job.items or {}) do
        if not it.express and not (job.loaded and job.loaded[i]) and not (job.handed and job.handed[i]) then n = n + 1 end
    end
    return n
end

local function JobDest(job)
    return job.destination or Config.Handover.fallback
end

-- `forSrc` = odbiorca (żeby dopisać `mine`, czyli „to ja to wiozę”)
local function Snapshot(job, forSrc)
    local handed, n = {}, 0
    for i in pairs(job.handed or {}) do handed[i] = true; n = n + 1 end
    return {
        id = job.id, key = job.key, state = job.state,
        items = job.items, buyerJob = job.buyerJob, buyerLabel = job.buyerLabel,
        supplierJob = job.supplierJob, total = job.total,
        destination = JobDest(job), destinationFromPanel = job.destination ~= nil,
        claimedBy = job.claimedBy, claimedName = job.claimedBy and PlayerName(job.claimedBy) or nil,
        mine = (forSrc ~= nil and job.claimedBy == forSrc) or false,
        loaded = job.loaded, handed = handed, handedCount = n,
        toLoad = ToLoad(job), remaining = Remaining(job),
        receivedAt = job.receivedAt,
    }
end

-- ── powiadomienia / synchronizacja z klientami na służbie ─────────────────────
local function OnDuty()
    local list = {}
    for src in pairs(CD.duty) do list[#list + 1] = src end
    return list
end

local function Push(job)                         -- wyślij zadanie wszystkim na służbie
    for _, src in ipairs(OnDuty()) do TriggerClientEvent('nano_cd:job', src, Snapshot(job, src)) end
    if job.claimedBy then TriggerClientEvent('nano_cd:job', job.claimedBy, Snapshot(job, job.claimedBy)) end
end

local function PushAll(src)                      -- wyślij pełną listę jednemu graczowi
    local list = {}
    for _, job in pairs(CD.jobs) do list[#list + 1] = Snapshot(job, src) end
    TriggerClientEvent('nano_cd:jobs', src, list)
end

local function RemoveFor(job, why)               -- „to zadanie już nie istnieje”
    if not job then return end
    for _, src in ipairs(OnDuty()) do TriggerClientEvent('nano_cd:jobRemove', src, job.id, why or '') end
end

local function NotifyJob(job, text, tone)        -- wiadomość tylko do osoby, która wiezie
    if job.claimedBy then TriggerClientEvent('nano_cd:notify', job.claimedBy, text, tone) end
end

local function NotifyAll(text, tone)
    for _, src in ipairs(OnDuty()) do TriggerClientEvent('nano_cd:notify', src, text, tone) end
end

-- ── uprawnienia ───────────────────────────────────────────────────────────────
local function CanWork(src)
    if CD.duty[src] and not Config.RequireDuty then return true end
    local ok, xPlayer = pcall(function() return ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) end)
    if not ok then xPlayer = nil end
    local job = xPlayer and xPlayer.job and xPlayer.job.name or nil
    if Config.AllowAnyone then return true end
    return job == Config.Job
end

-- ── zadania: start / anulowanie / wznowienie ─────────────────────────────────
local function ParseId(v)
    if type(v) == 'number' then return v end
    return tonumber(tostring(v or ''):match('(%d+)$') or '')
end

local function Upsert(payload)
    -- niektóre skrypty wysyłają payload jako JSON (tekst) – przyjmujemy obie postacie
    if type(payload) == 'string' then
        local ok, decoded = pcall(json.decode, payload)
        if ok and type(decoded) == 'table' then payload = decoded end
    end
    if type(payload) ~= 'table' then return nil end
    if type(payload.items) == 'string' then
        local ok, decoded = pcall(json.decode, payload.items)
        payload.items = (ok and type(decoded) == 'table') and decoded or nil
    end

    local id = ParseId(payload.id or payload.orderId)
    if not id then return nil end

    local job = CD.jobs[id]
    if job and job.state == 'done' then return job end
    local fresh = job == nil
    if fresh then
        job = { id = id, key = payload.orderId or ('ord-' .. id), loaded = {}, handed = {}, state = 'pending', receivedAt = os.time() }
        CD.jobs[id] = job
    end

    job.items        = payload.items or job.items or {}
    job.buyerJob     = payload.buyerJob   or job.buyerJob
    job.buyerLabel   = payload.buyerLabel or job.buyerLabel or payload.buyerJob
    job.supplierJob  = payload.supplierJob or job.supplierJob
    job.total        = payload.total or job.total
    job.destination  = payload.destination or job.destination

    local label = (job.destination and job.destination.label) or (Config.Handover.fallback and Config.Handover.fallback.label) or 'punktu odbioru'
    SaveJob(job)
    Push(job)

    if fresh then
        NotifyAll(('Nowe zadanie %s: %d %s → %s. Przyczepa czeka na placu CD.'):format(
            job.key, Remaining(job), (Remaining(job) == 1 and 'pojazd' or 'pojazdy'), label), 'info')
    end
    log('zadanie %s: %s (do przewiezienia: %d)', job.key, fresh and 'nowe' or 'aktualizacja', Remaining(job))
    return job
end

RegisterNetEvent('crp_cd:server:start', function(payload)
    Upsert(payload)                      -- Upsert sam odrzuca śmieci (nil/tekst bez JSON-a)
end)

RegisterNetEvent('crp_cd:server:resend', function(payload)
    Upsert(payload)
end)

RegisterNetEvent('crp_cd:server:cancel', function(orderId, why)
    local id = ParseId(type(orderId) == 'table' and (orderId.id or orderId.orderId) or orderId)
    local job = id and CD.jobs[id]
    if not job then return end
    NotifyJob(job, ('Zadanie %s zostało anulowane%s.'):format(job.key, why and why ~= '' and (' (' .. tostring(why) .. ')') or ''), 'error')
    CD.jobs[id] = nil
    DropJob(id)
    RemoveFor(job, 'cancelled')
    log('zadanie %s anulowane (%s)', job.key, tostring(why))
end)

-- ── praca: wzięcie zadania, załadunek, oddanie ───────────────────────────────
RegisterNetEvent('nano_cd:server:duty', function(on)
    local src = srcOf(source); if not src then return end
    
    if on then
        if not CanWork(src) then
            return TriggerClientEvent('nano_cd:notify', src, 'Nie należysz do firmy CD.', 'error')
        end
        CD.duty[src] = true
        PushAll(src)
        TriggerClientEvent('nano_cd:notify', src, 'Jesteś na służbie CD.', 'success')
        log('na służbie: %s', PlayerName(src))
    else
        CD.duty[src] = nil
        TriggerClientEvent('nano_cd:cleared', src)
        log('koniec służby: %s', PlayerName(src))
    end
end)

RegisterNetEvent('nano_cd:server:take', function(id)
    local src = srcOf(source); if not src then return end
    
    local job = CD.jobs[tonumber(id)]
    if not job then return TriggerClientEvent('nano_cd:notify', src, 'Nie ma takiego zadania.', 'error') end
    if not CanWork(src) then return TriggerClientEvent('nano_cd:notify', src, 'Nie należysz do firmy CD.', 'error') end
    if Config.RequireDuty and not CD.duty[src] then
        return TriggerClientEvent('nano_cd:notify', src, 'Najpierw zacznij służbę (`/pod sluzba`).', 'error')
    end
    if job.claimedBy and job.claimedBy ~= src and CD.duty[job.claimedBy] then
        return TriggerClientEvent('nano_cd:notify', src, ('To zadanie wiezie już %s.'):format(PlayerName(job.claimedBy)), 'error')
    end

    job.claimedBy = src
    if job.state == 'pending' or job.state == 'done' then job.state = 'loading' end
    SaveJob(job)
    Push(job)
    TriggerClientEvent('nano_cd:job', src, Snapshot(job, src))
    NotifyJob(job, ('Zadanie %s: %d %s do załadowania na lawetę.'):format(job.key, Remaining(job),
        (Remaining(job) == 1 and 'pojazd' or 'pojazdy')), 'info')
    log('%s wziął zadanie %s', PlayerName(src), job.key)
end)

-- klient zgłasza: auto numer `index` stoi już na gnieździe `slot`
RegisterNetEvent('nano_cd:server:loaded', function(id, index, plate)
    local src = srcOf(source); if not src then return end
    
    local job = CD.jobs[tonumber(id)]
    if not job or job.claimedBy ~= src then return end

    index = tonumber(index)
    local item = Item(job, index)
    if not item or item.express then return end
    if job.handed and job.handed[index] then return end
    if job.loaded[index] then return end

    job.loaded[index] = tostring(plate or item.plate or '')
    local left = ToLoad(job)
    if left == 0 then
        job.state = 'hauling'
        TriggerClientEvent('nano_cd:notify', src, ('Wszystko załadowane – jedź do: %s.'):format(
            (JobDest(job) and JobDest(job).label) or 'punktu odbioru'), 'success')
    else
        job.state = 'loading'
    end
    SaveJob(job)
    Push(job)
    log('zadanie %s: załadowano #%d (%s), zostało %d', job.key, index, job.loaded[index], left)
end)

-- klient zgłasza: auta zjechały z lawety na miejscu odbioru
RegisterNetEvent('nano_cd:server:handin', function(id, plates)
    local src = srcOf(source); if not src then return end
    
    local job = CD.jobs[tonumber(id)]
    if not job then return end
    if job.claimedBy and job.claimedBy ~= src then
        return TriggerClientEvent('nano_cd:notify', src, 'To zadanie wiezie ktoś inny.', 'error')
    end

    -- ── weryfikacja: oddawać wolno tylko w miejscu odbioru ──
    local dest = JobDest(job)
    if dest then
        local ped = GetPlayerPed and GetPlayerPed(src) or 0
        if ped and ped ~= 0 then
            local pos = GetEntityCoords(ped)
            local d = Dist(pos, dest)
            if d > (Config.Handover.maxServerDistance or 90.0) then
                return TriggerClientEvent('nano_cd:notify', src,
                    ('Pojazdy można oddać tylko na miejscu odbioru (%s) – jesteś %.0f m od celu.'):format(dest.label or 'punkt', d), 'error')
            end
            log('oddanie %s: gracz %.1f m od celu (limit %.1f)', job.key, d, Config.Handover.maxServerDistance or 90.0)
        end
    end

    -- `plates` może przyjść jako tabela, JSON albo zwykły tekst – bierzemy tylko sensowne wpisy
    if type(plates) == 'string' then
        local ok, decoded = pcall(json.decode, plates)
        plates = (ok and type(decoded) == 'table') and decoded or nil
    end

    local list = {}
    for _, entry in ipairs(type(plates) == 'table' and plates or {}) do
        if type(entry) ~= 'table' then entry = { index = entry } end
        local i = tonumber(entry.index or entry[1])
        local item = Item(job, i)
        if item and not item.express and not (job.handed and job.handed[i]) then
            job.handed[i] = true
            list[#list + 1] = { index = i, plate = tostring(entry.plate or entry[2] or (job.loaded and job.loaded[i]) or item.plate or '') }
        end
    end

    if #list == 0 then
        return TriggerClientEvent('nano_cd:notify', src, 'Nie ma czego oddawać.', 'error')
    end

    for _, e in ipairs(list) do job.loaded[e.index] = nil end     -- laweta znów jest pusta

    local final = Remaining(job) == 0
    local byName = PlayerName(src)

    -- → boss menu: płaci firmie dostawcy, wpisuje pojazdy do garażu i zamyka zamówienie
    TriggerEvent('crp_bossmenu:server:deliveryDone', job.key, list, final, byName)

    if final then
        job.state = 'done'
        CD.jobs[job.id] = nil
        DropJob(job.id)
        RemoveFor(job, 'done')
        log('zadanie %s: ODDANE i zamknięte (%s)', job.key, byName)
    else
        job.state = 'loading'      -- zostały auta → wracasz na plac po kolejną partię
        SaveJob(job)
        Push(job)
        TriggerClientEvent('nano_cd:notify', src, ('Partia oddana. Na lawecie zostało jeszcze %d %s – wracaj na plac.'):format(
            Remaining(job), (Remaining(job) == 1 and 'pojazd' or 'pojazdy')), 'info')
        log('zadanie %s: oddano partię (%d), zostało %d', job.key, #list, Remaining(job))
    end
end)

-- ── synchronizacja ────────────────────────────────────────────────────────────
RegisterNetEvent('nano_cd:server:resync', function()
    local src = srcOf(source); if not src then return end
    
    PushAll(src)
    -- poproś boss menu o ponowne wysłanie wszystkich fizycznych zadań (także po restarcie naszego zasobu)
    TriggerEvent('crp_bossmenu:server:deliveryResend')
end)

AddEventHandler('playerDropped', function()
    local src = source
    CD.duty[src] = nil
    for _, job in pairs(CD.jobs) do
        if job.claimedBy == src then
            job.claimedBy = nil
            job.state = 'pending'
            SaveJob(job)
            Push(job)
            NotifyAll(('Zadanie %s wróciło na listę (kierowca wyszedł z serwera).'):format(job.key), 'warn')
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Build()
        local rows = dbQuery('SELECT `id`, `data` FROM `crp_cd_jobs`')
        for _, row in ipairs(rows or {}) do
            local ok, job = pcall(json.decode, row.data)
            if ok and type(job) == 'table' then
                job.claimedBy = nil
                if job.state ~= 'done' then
                    if job.state == 'hauling' or job.state == 'handover' then job.state = 'pending' end
                    CD.jobs[job.id] = job
                end
            end
        end
        local n = 0
        for _ in pairs(CD.jobs) do n = n + 1 end
        log('wczytano %d zadań z bazy', n)

        Wait(2000)
        -- poproś boss menu o aktualne zadania (może wystartować przed nami / po nas)
        TriggerEvent('crp_bossmenu:server:deliveryResend')
    end)
end)

-- ── eksporty (przydadzą się, gdy podłączysz to do pełnego skryptu CD) ─────────
exports('SetDuty', function(src, on)           -- exports.nano_cd:SetDuty(source, true/false)
    if not src or src == 0 then return end
    if on then CD.duty[src] = true; PushAll(src)
    else CD.duty[src] = nil; TriggerClientEvent('nano_cd:cleared', src) end
end)

exports('Handin', function(id, plates, byName)  -- exports.nano_cd:Handin(12, { {index=1, plate='ABC 123'} }, 'Jan')
    local job = CD.jobs[tonumber(id)]
    if not job then return false end
    TriggerEvent('crp_bossmenu:server:deliveryDone', job.key, plates, true, byName or 'System')
    CD.jobs[job.id] = nil
    DropJob(job.id)
    RemoveFor(job, 'done')
    return true
end)

CreateThread(function()
    while true do
        Wait((Config.RefreshSeconds or 30) * 1000)
        if next(CD.duty) ~= nil then TriggerEvent('crp_bossmenu:server:deliveryResend') end
    end
end)
