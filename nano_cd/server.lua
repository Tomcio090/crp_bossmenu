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
--
--  Uprawnienia: NIE mamy własnej służby – używamy systemu duty z crp_jobcore
--  (praca `cd`/`centra_autos` ⇄ `off…`, state bag `duty` → export `crp_jobcore:IsOnDuty`).
-- ██████████████████████████████████████████████████████████████████████████████

local ESX = exports['es_extended']:getSharedObject()
local CD = { jobs = {} }                -- jobs = [id zadania] = zadanie

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

local function numericMap(value)
    local out = {}
    for key, item in pairs(type(value) == 'table' and value or {}) do
        local index = tonumber(key)
        if index and index > 0 and index == math.floor(index) then out[index] = item end
    end
    return out
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

-- ── uprawnienia ───────────────────────────────────────────────────────────────
--  UWAGA: nano_cd NIE MA własnego systemu służby. Korzystamy z systemu duty z
--  crp_jobcore (`police` ⇄ `offpolice`, `centra_autos` ⇄ `offcentra_autos` itd.):
--  pytamy jego export `IsOnDuty`, a gdy go nie ma – czytamy ten sam state bag
--  `duty`, który czyta panel boss menu (true/'duty' = na służbie, false/'off' = poza,
--  'break' = przerwa). Dzięki temu jedna służba obsługuje cały serwer.

-- 'offpolice' → 'police' (praca ze zdjętym „off”, czyli ta sama firma na służbie i poza)
local function baseJob(name)
    return (tostring(name or ''):gsub('^off', ''))
end

-- 'duty' | 'off' | 'break' – jedno źródło prawdy: crp_jobcore
local function dutyOf(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    local jobName = xPlayer and xPlayer.job and xPlayer.job.name
    local isOffWorker = type(jobName) == 'string'
        and jobName:sub(1, 3) == 'off'
        and (Config.Job == nil or Config.Job == '' or baseJob(jobName) == baseJob(Config.Job))
    -- ESX-owy job jest autorytatywny dla statusu off; pusty state bag po reconnect
    -- nie może zamienić `offcentra_autos` w pracownika na służbie.
    if isOffWorker then return 'off' end

    local ok, res = pcall(function() return exports['crp_jobcore']:IsOnDuty(src) end)
    if ok and (type(res) == 'boolean' or res == 'break') then
        if res == 'break' then return 'break' end
        return res and 'duty' or 'off'
    end

    local v
    ok, v = pcall(function() return Player(src).state.duty end)
    if ok then
        if v == 'break' then return 'break' end
        if v == false or v == 'off' then return 'off' end
        if v == true or v == 'duty' then return 'duty' end
    end

    -- Przy braku exportu/state bagu aktywna nazwa pracy oznacza służbę; off* nigdy.
    if type(jobName) == 'string' and jobName:sub(1, 3) ~= 'off' then return 'duty' end
    return 'off'
end

-- czy gracz pracuje w firmie CD (na służbie albo poza – sama przynależność)
local function isWorker(src)
    if Config.Job == nil or Config.Job == '' then return true end
    local ok, x = pcall(function() return ESX.GetPlayerFromId(src) end)
    if not ok or not x or not x.job then return false end
    return baseJob(x.job.name) == baseJob(Config.Job)
end

-- czy może teraz wozić (firma + służba z crp_jobcore). Zwraca true albo false, powód.
local function CanWork(src)
    if not isWorker(src) then
        return false, ('Wozić pojazdy może tylko firma `%s`.'):format(tostring(Config.Job))
    end
    if Config.RequireDuty and dutyOf(src) ~= 'duty' then
        return false, 'Jesteś poza służbą – wejdź na służbę (punkt duty), żeby wozić pojazdy.'
    end
    return true
end

-- ── powiadomienia / synchronizacja z klientami na służbie ─────────────────────
-- Lista odbiorców: pracownicy firmy CD, którzy są NA SŁUŻBIE (system duty z crp_jobcore).
local function OnDuty()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and isWorker(src) and dutyOf(src) == 'duty' then list[#list + 1] = src end
    end
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
        job = {
            id = id, key = payload.orderId or ('ord-' .. id), loaded = {},
            handed = numericMap(payload.handed), state = 'pending', receivedAt = os.time()
        }
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

-- Te zdarzenia są kontraktem serwer-serwer (TriggerEvent), nie API dla klienta.
AddEventHandler('crp_cd:server:start', function(payload)
    Upsert(payload)
end)

AddEventHandler('crp_cd:server:resend', function(payload)
    Upsert(payload)
end)

AddEventHandler('crp_cd:server:cancel', function(orderId, why)
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
RegisterNetEvent('nano_cd:server:take', function(id)
    local src = srcOf(source); if not src then return end
    
    local job = CD.jobs[tonumber(id)]
    if not job then return TriggerClientEvent('nano_cd:notify', src, 'Nie ma takiego zadania.', 'error') end
    local can, why = CanWork(src)
    if not can then return TriggerClientEvent('nano_cd:notify', src, why, 'error') end
    if job.claimedBy and job.claimedBy ~= src then
        if isWorker(job.claimedBy) and dutyOf(job.claimedBy) == 'duty' then
            return TriggerClientEvent('nano_cd:notify', src, ('To zadanie wiezie już %s.'):format(PlayerName(job.claimedBy)), 'error')
        end
        job.claimedBy = nil
        job.loaded = {} -- stare uchwyty/pojazdy należały do poprzedniego kierowcy
    end

    if job.claimedBy ~= src then job.loaded = {} end
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
    local can, why = CanWork(src)
    if not can then return TriggerClientEvent('nano_cd:notify', src, why, 'error') end

    index = tonumber(index)
    if not index or index ~= math.floor(index) then return end
    local item = Item(job, index)
    if not item or item.express then return end
    if job.handed and job.handed[index] then return end
    if job.loaded[index] then return end

    local expectedPlate = tostring(item.plate or ''):gsub('%s+$', '')
    local submittedPlate = tostring(plate or ''):gsub('%s+$', '')
    if expectedPlate == '' or (submittedPlate ~= '' and submittedPlate ~= expectedPlate) then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local dockDistance = Dist(GetEntityCoords(ped), Config.Docks.coords)
    if dockDistance > (Config.Docks.radius or 70.0) + 15.0 then
        return TriggerClientEvent('nano_cd:notify', src, 'Załadunek możesz zgłosić tylko w strefie doków.', 'error')
    end

    -- Tablicę bierzemy z serwerowego payloadu zamówienia, nigdy z klienta.
    job.loaded[index] = expectedPlate
    local left = ToLoad(job)
    local capacity = #(Config.Trailer.slots or {})
    local trailerFull = capacity > 0 and LoadedCount(job) >= capacity
    if left == 0 or trailerFull then
        job.state = 'hauling'
        local message = left == 0
            and ('Wszystko załadowane – jedź do: %s.'):format((JobDest(job) and JobDest(job).label) or 'punktu odbioru')
            or ('Laweta pełna – jedź oddać partię do: %s.'):format((JobDest(job) and JobDest(job).label) or 'punktu odbioru')
        TriggerClientEvent('nano_cd:notify', src, message, 'success')
    else
        job.state = 'loading'
    end
    SaveJob(job)
    Push(job)
    log('zadanie %s: załadowano #%d (%s), zostało %d', job.key, index, job.loaded[index], left)
end)

-- Klient zgłasza oddanie, ale serwer akceptuje wyłącznie pozycje, które sam
-- oznaczył jako załadowane; indeksy i tablice z payloadu klienta nie są źródłem prawdy.
RegisterNetEvent('nano_cd:server:handin', function(id, plates)
    local src = srcOf(source); if not src then return end

    local job = CD.jobs[tonumber(id)]
    if not job then return end
    local can, why = CanWork(src)
    if not can then return TriggerClientEvent('nano_cd:notify', src, why, 'error') end
    if job.claimedBy ~= src then
        return TriggerClientEvent('nano_cd:notify', src, 'Najpierw przejmij to zadanie.', 'error')
    end

    local dest = JobDest(job)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pos = GetEntityCoords(ped)
    local distance = Dist(pos, dest)
    local maxDistance = (Config.Handover and Config.Handover.maxServerDistance) or 35.0
    if distance > maxDistance then
        return TriggerClientEvent('nano_cd:notify', src,
            ('Pojazdy można oddać tylko na miejscu odbioru (%s) – jesteś %.0f m od celu.'):format(dest.label or 'punkt', distance), 'error')
    end
    log('oddanie %s: gracz %.1f m od celu (limit %.1f)', job.key, distance, maxDistance)

    if type(plates) == 'string' then
        local ok, decoded = pcall(json.decode, plates)
        plates = (ok and type(decoded) == 'table') and decoded or nil
    end

    local list, seen = {}, {}
    for _, entry in ipairs(type(plates) == 'table' and plates or {}) do
        if type(entry) ~= 'table' then entry = { index = entry } end
        local i = tonumber(entry.index or entry[1])
        if i and i == math.floor(i) and not seen[i] then
            local item = Item(job, i)
            local loadedPlate = job.loaded and job.loaded[i]
            if item and not item.express and loadedPlate and not (job.handed and job.handed[i]) then
                seen[i] = true
                list[#list + 1] = { index = i, plate = tostring(loadedPlate) }
            end
        end
    end

    if #list == 0 then
        return TriggerClientEvent('nano_cd:notify', src, 'Nie ma załadowanych pojazdów do oddania.', 'error')
    end

    for _, entry in ipairs(list) do
        job.handed[entry.index] = true
        job.loaded[entry.index] = nil
    end

    local final = Remaining(job) == 0 -- `final` wylicza serwer, nie klient
    local byName = PlayerName(src)
    TriggerEvent('crp_bossmenu:server:deliveryDone', job.key, list, final, byName)

    if final then
        job.state = 'done'
        CD.jobs[job.id] = nil
        DropJob(job.id)
        RemoveFor(job, 'done')
        log('zadanie %s: ODDANE i zamknięte (%s)', job.key, byName)
    else
        job.state = 'loading'
        SaveJob(job)
        Push(job)
        TriggerClientEvent('nano_cd:notify', src, ('Partia oddana. Zostało jeszcze %d %s – wracaj na plac.'):format(
            Remaining(job), (Remaining(job) == 1 and 'pojazd' or 'pojazdy')), 'info')
        log('zadanie %s: oddano partię (%d), zostało %d', job.key, #list, Remaining(job))
    end
end)

-- ── synchronizacja ────────────────────────────────────────────────────────────
RegisterNetEvent('nano_cd:server:resync', function()
    local src = srcOf(source); if not src then return end
    local can = CanWork(src)
    if not can then
        TriggerClientEvent('nano_cd:cleared', src)
        return
    end

    PushAll(src)
    -- Poproś boss menu o ponowne wysłanie zadań po autoryzacji pracownika.
    TriggerEvent('crp_bossmenu:server:deliveryResend')
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, job in pairs(CD.jobs) do
        if job.claimedBy == src then
            job.claimedBy = nil
            job.loaded = {}
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
            if ok and type(job) == 'table' and tonumber(job.id) then
                job.id = tonumber(job.id)
                job.claimedBy = nil
                job.handed = numericMap(job.handed)
                -- Klientowe entity handles nie przeżywają restartu zasobu. Ponownie
                -- pobieramy wszystkie jeszcze nieoddane pojazdy zamiast zostawić wpisy
                -- loaded, których handle nie istnieje już po stronie żadnego kierowcy.
                job.loaded = {}
                if job.state ~= 'done' then
                    job.state = 'pending'
                    CD.jobs[job.id] = job
                    SaveJob(job)
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

-- ── reakcja na zmianę pracy (to robi system duty z crp_jobcore) ───────────────
-- Wejście na służbę = powrót do pracy `cd`/`centra_autos` → wysyłamy zadania.
-- Zejście = praca `off…` → czyścimy u gracza listę zadań (i zwalniamy to, co wiózł).
local function HandleJobChange(src)
    if not src then return end

    -- na służbie (w firmie + duty z crp_jobcore) → dostaje aktualną listę zadań
    if isWorker(src) and dutyOf(src) == 'duty' then
        PushAll(src)
        log('na służbie: %s', PlayerName(src))
        return
    end

    -- poza firmą albo poza służbą: oddajemy to, co wiózł (zadanie wraca na listę)
    for _, job in pairs(CD.jobs) do
        if job.claimedBy == src then
            job.claimedBy = nil
            job.loaded = {}
            job.state = 'pending'
            SaveJob(job)
            Push(job)
            NotifyAll(('Zadanie %s wróciło na listę (kierowca zszedł ze służby).'):format(job.key), 'warn')
        end
    end
    TriggerClientEvent('nano_cd:cleared', src)
    log('poza służbą: %s (praca %s)', PlayerName(src), tostring(src))
end

AddEventHandler('esx:setJob', function(src)
    CreateThread(function()
        Wait(200)                     -- state bag `duty` ustawia się chwilę po zmianie pracy
        HandleJobChange(src)
    end)
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
        if #OnDuty() > 0 then TriggerEvent('crp_bossmenu:server:deliveryResend') end
    end
end)

-- ── podgląd dla testów (nieużywane w grze) ────────────────────────────────────
_G.nanoCD.baseJob     = function(name) return baseJob(name) end
_G.nanoCD.dutyOf      = function(src) return dutyOf(src) end
_G.nanoCD.isWorker    = function(src) return isWorker(src) end
_G.nanoCD.canWork     = function(src) local ok, why = CanWork(src) return ok, why end
_G.nanoCD.onJobChange = function(src) return HandleJobChange(src) end
