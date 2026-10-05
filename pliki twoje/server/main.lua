-- ═════════════════════════════════════════════════════════════
--  SERWER – sesje paneli, dyspozytor akcji, odświeżanie, godziny pracy
-- ═════════════════════════════════════════════════════════════
Server = Server or {}
local Sessions = {}        -- [src] = { job, identifier, ssn, firstname, lastname, grade }
local lastOpen = {}

MySQL.ready(function() Data.Install() end)

-- ───────── sesja / uprawnienia ─────────
-- Sprawdza, czy gracz nadal może zarządzać firmą. Zwraca kontekst albo nil, 'powód'.
local function context(src)
    local s = Sessions[src]
    if not s then return nil, 'Panel nie jest otwarty' end
    local x = Bridge.GetPlayer(src)
    if not x or x.job.name ~= s.job or not Bridge.CanManage(x) then return nil, 'Straciłeś dostęp do panelu' end
    s.grade = x.job.grade
    return { src = src, xPlayer = x, identifier = s.identifier, job = s.job, grade = s.grade, ssn = s.ssn,
        name = ('%s %s'):format(s.firstname, s.lastname) }
end

function Server.ForceClose(src)
    if Sessions[src] then
        Sessions[src] = nil
        TriggerClientEvent('crp_bossmenu:client:forceClose', src)
    end
end

function Server.NotifyJob(job, text, tone)
    for src, s in pairs(Sessions) do
        if s.job == job then Bridge.Notify(src, text, tone) end
    end
end

-- ───────── odświeżanie ─────────
local pendingRefresh, timer = {}, false
local function pushTo(src)
    local c = context(src)
    if not c then return Server.ForceClose(src) end
    local ok, data = pcall(Data.Build, Sessions[src])
    if ok then TriggerClientEvent('crp_bossmenu:client:update', src, data)
    else print('^1[crp_bossmenu] Data.Build:^7', data) end
end

local function flush()
    timer = false
    local jobs = pendingRefresh; pendingRefresh = {}
    for src, s in pairs(Sessions) do
        if jobs['*'] or jobs[s.job] then pushTo(src) end
    end
end

-- Odświeżenie z lekkim opóźnieniem: odpowiedź na żądanie dociera do UI PRZED paczką `update`
-- (UI nakłada lokalnie zmianę z odpowiedzi, a `update` ją potem nadpisuje stanem z serwera).
function Server.Refresh(...)
    for _, j in ipairs({ ... }) do pendingRefresh[j] = true end
    if not timer then timer = true; SetTimeout(250, flush) end
end
function Server.RefreshAll() Server.Refresh('*') end

-- ───────── otwieranie ─────────
local function nearLocation(src, job)
    if not Config.RequireLocation then return true end
    local ped = GetPlayerPed(src)
    local pos = GetEntityCoords(ped)
    for _, l in ipairs(Config.Locations) do
        if l.job == job and #(pos - l.coords) <= (l.radius or 2.0) + 2.0 then return true end
    end
    return false
end

function Server.Open(src)
    local now = GetGameTimer()
    if lastOpen[src] and now - lastOpen[src] < 1000 then return end
    lastOpen[src] = now
    local x = Bridge.GetPlayer(src)
    if not x or not Bridge.CanManage(x) then return Bridge.Notify(src, 'Nie masz dostępu do panelu zarządzania.', 'error') end
    if not nearLocation(src, x.job.name) then return Bridge.Notify(src, 'Musisz być przy panelu zarządzania.', 'error') end

    local me = Bridge.FindByIdentifier(x.identifier)
    if not me then return end
    Sessions[src] = { job = x.job.name, identifier = x.identifier, ssn = me.ssn or x.identifier,
        firstname = me.firstname or '', lastname = me.lastname or '', grade = x.job.grade }
    local ok, data = pcall(Data.Build, Sessions[src])
    if not ok then
        Sessions[src] = nil
        print('^1[crp_bossmenu] Data.Build:^7', data)
        return Bridge.Notify(src, 'Błąd wczytywania danych panelu.', 'error')
    end
    TriggerClientEvent('crp_bossmenu:client:open', src, data)
end

RegisterNetEvent('crp_bossmenu:server:open', function() Server.Open(source) end)
RegisterNetEvent('crp_bossmenu:server:close', function() Sessions[source] = nil end)
AddEventHandler('playerDropped', function() Sessions[source] = nil; lastOpen[source] = nil end)
exports('Open', function(src) Server.Open(src) end)

-- ───────── dyspozytor ─────────
RegisterNetEvent('crp_bossmenu:server:req', function(reqId, event, data)
    local src = source
    local function reply(res) TriggerClientEvent('crp_bossmenu:client:res', src, reqId, res) end

    local handler = type(event) == 'string' and Handlers[event]
    if not handler then return reply(U.err('Nieznana akcja')) end
    if type(data) ~= 'table' then data = {} end

    local c, why = context(src)
    if not c then
        Server.ForceClose(src)
        return reply(U.err(why))
    end

    local ok, res = pcall(handler, c, data)
    if not ok then
        print(('^1[crp_bossmenu] błąd w handlerze %s:^7 %s'):format(event, tostring(res)))
        res = U.err('Błąd serwera – spróbuj ponownie')
    end
    res = res or { ok = true }
    reply(res)

    if Handlers_Post[event] and not res.ok then
        Bridge.Notify(src, res.error or 'Nie udało się wykonać akcji', 'error')   -- UI zmienił stan optymistycznie; update go naprawi
    end
    if res.ok then
        if not Handlers_NoRefresh[event] then Server.Refresh(c.job) end
    else
        Server.Refresh(c.job)
    end
end)

-- ───────── godziny pracy (co minutę dla graczy na służbie) ─────────
CreateThread(function()
    while true do
        Wait(60000)
        for _, id in ipairs(GetPlayers()) do
            local x = Bridge.GetPlayer(tonumber(id))
            if x and Config.Jobs[x.job.name] and Config.GetDutyStatus(x.source, x) == 'duty' then
                MySQL.insert('INSERT INTO bossmenu_members (identifier, job, seconds, last_duty) VALUES (?, ?, 60, NOW()) ON DUPLICATE KEY UPDATE seconds = seconds + 60, last_duty = NOW()',
                    { x.identifier, x.job.name })
            end
        end
    end
end)

-- ───────── automatyczne odświeżanie otwartych paneli ─────────
if Config.RefreshInterval and Config.RefreshInterval > 0 then
    CreateThread(function()
        while true do
            Wait(Config.RefreshInterval * 1000)
            if next(Sessions) then Server.RefreshAll() end
        end
    end)
end

-- Gracz zmienił pracę – zamknij panel
AddEventHandler('esx:setJob', function(src)
    if Sessions[src] then
        local c = context(src)
        if not c then Server.ForceClose(src) end
    end
end)
