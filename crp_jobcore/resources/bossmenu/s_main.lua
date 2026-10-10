--[[
    s_main.lua – serwer: sesje panelu, akcje z UI i odświeżanie (tylko serwer)

    Przepływ:
      klient (NUI) -> 'crp_bossmenu:server:req' (id, nazwa akcji, dane) -> akcja z tabeli Actions
                   <- 'crp_bossmenu:client:res' (id, wynik)

    Każda akcja dostaje (c, d):
      c – kontekst gracza: { src, xPlayer, identifier, job, grade, ssn, name }  (sprawdzony po stronie serwera)
      d – dane z UI (niczemu nie wierzymy – wszystko jest walidowane)
    i zwraca { ok = true, ... } albo { ok = false, error = '...' }.

    Baza danych jest w s_data.lua – tutaj tylko logika.
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
if _G.crp_bossmenu_s_main then return _G.crp_bossmenu_s_main end

local Config = loadModule('resources.bossmenu.d_bossmenu', 'd_bossmenu.lua', 'crp_bossmenu_config')
local data   = loadModule('resources.bossmenu.s_data', 's_data.lua', 'crp_bossmenu_s_data')
local ESX    = exports['es_extended']:getSharedObject()

local Server   = {}
local Sessions = {}     -- [src] = { job, identifier, ssn, firstname, lastname, grade }
local lastOpen = {}
local pendingRefresh, refreshTimer = {}, false


-- ═════════════════════════════════════════════════════════════
--  MAŁE POMOCNIKI
-- ═════════════════════════════════════════════════════════════
local function int(v, min, max)
    v = tonumber(v)
    if not v or v ~= math.floor(v) then return nil end
    if (min and v < min) or (max and v > max) then return nil end
    return math.floor(v)
end

local function str(v, maxLen)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('%c', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and #v > maxLen then return nil end
    return v
end

local function plural(n, one, few, many)
    if n == 1 then return one end
    if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) then return few end
    return many
end

local function err(msg) return { ok = false, error = msg } end

-- `active TINYINT(1)` wraca z oxmysql raz jako boolean, raz jako 0/1 – patrz s_data.flag()
local function flag(v) return v == true or v == 1 or v == '1' or v == 'true' end

-- Prace „poza służbą” (offpolice / offambulance – patrz resources/duty) obsługujemy tak samo
-- jak ich bazowy odpowiednik, żeby szef po zejściu ze służby nie tracił dostępu do panelu.
local function baseJob(job)
    if type(job) ~= 'string' or job == '' then return nil end
    if Config.Jobs[job] then return job end
    if Config.AllowOffDuty == false then return job end     -- tryb „tylko na służbie”
    local stripped = job:gsub('^off', '')
    if stripped ~= job and Config.Jobs[stripped] then return stripped end
    return job
end

-- notatka: zostawiamy tylko bezpieczne znaczniki HTML, bez atrybutów
local ALLOWED_TAGS = { p = 1, br = 1, strong = 1, b = 1, em = 1, i = 1, u = 1, s = 1, h1 = 1, h2 = 1, h3 = 1,
                       ul = 1, ol = 1, li = 1, blockquote = 1 }
local function sanitizeHtml(html)
    html = tostring(html or ''):gsub('[\1\2]', '')
    html = html:gsub('<[^>]*>', function(tag)
        local slash, name = tag:match('^<(/?)%s*([%w]+)')
        name = name and name:lower()
        if name and ALLOWED_TAGS[name] then return '\1' .. slash .. name .. '\2' end
        return ''
    end)
    html = html:gsub('<', '&lt;'):gsub('>', '&gt;')
    return html:gsub('\1', '<'):gsub('\2', '>')
end

local function playerSrc(v)
    if type(v) == 'number' then return (v > 0) and v or nil end
    if type(v) == 'string' then
        local n = tonumber(v)
        return (n and n > 0) and n or nil
    end
    return nil
end

-- nazwa zgłaszającego, gdy nie ma gracza (albo gdy przyszła z obcego zasobu jako tekst/liczba)
local function whoName(v, fallback)
    if type(v) == 'string' and v ~= '' then return v end
    if type(v) == 'number' and v > 0 then return 'gracz #' .. tostring(v) end
    return fallback or 'System'
end

local function fullName(row)
    return ('%s %s'):format(row.firstname or '', row.lastname or '')
end


-- ═════════════════════════════════════════════════════════════
--  SESJE / UPRAWNIENIA
-- ═════════════════════════════════════════════════════════════
function Server.CanManage(xPlayer)
    local job = baseJob(xPlayer and xPlayer.job and xPlayer.job.name)
    if not job or not Config.Jobs[job] then return false end
    return xPlayer.job.grade >= data.MinGrade(job)
end

-- ═════════════════════════════════════════════════════════════
--  BLOKADY: krzesło i panel (jedna osoba naraz)
--
--  Krzesło: dopóki ktoś siedzi, nikt inny nie może zająć tego samego krzesła
--  (klient pyta serwer PRZED animacją siadania).
--  Panel:   jedna osoba na pracę – dotyczy także otwarcia komendą /bossmenu
--  albo exportem, więc dwóch szefów nie klika w tym samym panelu.
--  Wszystko trzyma serwer; klient dostaje tylko odpowiedź „wolne/zajęte”.
-- ═════════════════════════════════════════════════════════════
local Seats  = {}      -- [punkt] = { src, name, job, since }
local SeatBy = {}      -- [src] = punkt   (żeby zwolnić po rozłączeniu)
local Panels = {}      -- [praca] = { src, name, since, key }
local ANIM_RANGE = 60.0
local lastAnim = {}

local function lockEnabled()
    return not (Config.Panel and Config.Panel.singleUser == false)
end

local function jobAllowed(loc, job)
    if type(loc) ~= 'table' then return false end
    if loc.jobs then return loc.jobs[job] ~= nil end
    return loc.job == job
end

-- najbliższy punkt tej pracy (nil, gdy gracz stoi za daleko od wszystkich / jeszcze się wczytuje)
local function pointOf(src, job)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end

    local pos = GetEntityCoords(ped)
    if pos.x == 0.0 and pos.y == 0.0 and pos.z == 0.0 then return nil end

    local key, loc, dist
    for k, l in pairs(Config.Locations) do
        if jobAllowed(l, job) then
            local d = #(pos - vec3(l.mcoords.x, l.mcoords.y, l.mcoords.z))
            if not dist or d < dist then key, loc, dist = k, l, d end
        end
    end
    if loc and dist <= (loc.radius or loc.distance or 2.0) + 3.0 then return key, loc end
    return nil
end

local function displayName(src)
    local x = ESX.GetPlayerFromId(src)
    if x then
        local ok, name = pcall(x.getName, x)
        if ok and type(name) == 'string' and name ~= '' then return name end
    end
    return ('gracz #%d'):format(src)
end

local function panelHolder(job)
    local h = Panels[job]
    if not h then return nil end
    if not ESX.GetPlayerFromId(h.src) then Panels[job] = nil; return nil end
    return h
end

-- mówi wszystkim, kto aktualnie siedzi w panelu (podpowiedź przy krześle w textUI)
local function broadcastPanel(job)
    local h = Panels[job]
    TriggerClientEvent('crp_bossmenu:client:panelBusy', -1, job, h and h.name or nil)
end

local function freePanel(src, job)
    local h = Panels[job]
    if h and h.src == src then
        Panels[job] = nil
        broadcastPanel(job)
    end
end

local function releaseLocks(src)
    local key = SeatBy[src]
    if key then
        Seats[key] = nil
        SeatBy[src] = nil
    end
    for job, h in pairs(Panels) do
        if h.src == src then Panels[job] = nil; broadcastPanel(job) end
    end
    lastAnim[src] = nil
end

-- krzesło: klient pyta przed animacją siadania (want = true/false)
RegisterNetEvent('crp_bossmenu:server:seat', function(key, want)
    local src = playerSrc(source)
    if not src then return end                     -- krzesło może zająć tylko gracz, nie inny zasób
    local loc = type(key) == 'string' and Config.Locations[key]
    local x = ESX.GetPlayerFromId(src)
    local job = baseJob(x and x.job and x.job.name)

    if not loc or not job or not jobAllowed(loc, job) then
        return TriggerClientEvent('crp_bossmenu:client:seatRes', src, key, false)
    end

    if want == false then
        if Seats[key] and Seats[key].src == src then
            Seats[key] = nil
            SeatBy[src] = nil
        end
        return TriggerClientEvent('crp_bossmenu:client:seatRes', src, key, false)
    end

    if not lockEnabled() then
        return TriggerClientEvent('crp_bossmenu:client:seatRes', src, key, true)
    end

    if not Server.CanManage(x) then
        TriggerClientEvent('crp_bossmenu:client:seatRes', src, key, false)
        return TriggerClientEvent('crp_bossmenu:client:notify', src, 'Nie masz dostępu do panelu zarządzania.', 'error')
    end

    -- musi stać przy TYM krześle – danych z klienta nie bierzemy na słowo
    if pointOf(src, job) ~= key then
        TriggerClientEvent('crp_bossmenu:client:seatRes', src, key, false)
        return TriggerClientEvent('crp_bossmenu:client:notify', src, 'Musisz stać przy krześle panelu.', 'error')
    end

    local seat = Seats[key]
    if seat and seat.src ~= src then
        TriggerClientEvent('crp_bossmenu:client:seatRes', src, key, false, seat.name)
        TriggerClientEvent('crp_bossmenu:client:notify', src,
            ('Panel jest teraz używany przez %s – poczekaj, aż skończy.'):format(seat.name), 'error')
        return
    end

    Seats[key] = { src = src, name = displayName(src), job = job, since = os.time() }
    SeatBy[src] = key
    TriggerClientEvent('crp_bossmenu:client:seatRes', src, key, true)
end)

-- animacja krzesła u pozostałych graczy (TaskSynchronizedScene jest lokalny!)
local ANIM_PHASES = { enter = true, base = true, computer_enter = true, computer_idle = true,
                      computer_exit = true, exit = true, stop = true }

RegisterNetEvent('crp_bossmenu:server:anim', function(key, phase)
    local src = playerSrc(source)
    if not src or not ANIM_PHASES[phase] or type(key) ~= 'string' then return end

    local now = GetGameTimer()
    if lastAnim[src] and now - lastAnim[src] < 100 then return end     -- prosty rate-limit
    lastAnim[src] = now

    local loc = Config.Locations[key]
    if not loc or not loc.chaircoords then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    -- „stop” wysyłamy zawsze (gracz mógł już odejść od krzesła), pozostałe fazy – tylko przy krześle
    local pos = GetEntityCoords(ped)
    local chair = loc.chaircoords
    if phase ~= 'stop' and (pos.x ~= 0.0 or pos.y ~= 0.0)
        and #(pos - vec3(chair.x, chair.y, chair.z)) > (loc.radius or loc.distance or 2.0) + 3.0 then
        return
    end

    local range = (Config.Panel and Config.Panel.animRange) or ANIM_RANGE
    for _, id in ipairs(GetPlayers()) do
        local tgt = tonumber(id)
        if tgt and tgt ~= src then
            local tped = GetPlayerPed(tgt)
            if tped and tped ~= 0 and #(GetEntityCoords(tped) - pos) <= range then
                TriggerClientEvent('crp_bossmenu:client:anim', tgt, src, key, phase,
                    chair.x, chair.y, chair.z, chair.w or chair.heading or 0.0)
            end
        end
    end
end)


-- kontekst gracza albo nil, powód
local function context(src)
    local s = Sessions[src]
    if not s then return nil, 'Panel nie jest otwarty' end

    local x = ESX.GetPlayerFromId(src)
    if not x or baseJob(x.job.name) ~= s.job or not Server.CanManage(x) then
        return nil, 'Straciłeś dostęp do panelu'
    end

    s.grade = x.job.grade
    return {
        src = src, xPlayer = x, identifier = s.identifier, job = s.job, grade = s.grade,
        ssn = s.ssn, name = ('%s %s'):format(s.firstname, s.lastname)
    }
end

function Server.ForceClose(src)
    local s = Sessions[src]
    if s then
        Sessions[src] = nil
        freePanel(src, s.job)
        TriggerClientEvent('crp_bossmenu:client:forceClose', src)
    end
end

function Server.NotifyJob(job, text, tone)
    for src, s in pairs(Sessions) do
        if s.job == job then TriggerClientEvent('crp_bossmenu:client:notify', src, text, tone or 'info') end
    end
end


-- ═════════════════════════════════════════════════════════════
--  OTWIERANIE / ODŚWIEŻANIE
-- ═════════════════════════════════════════════════════════════
local function nearLocation(src, job)
    if not Config.RequireLocation then return true end
    local pos = GetEntityCoords(GetPlayerPed(src))
    for _, loc in pairs(Config.Locations) do
        -- klient aktywuje punkt z `distance` (c_main.lua), `radius` (jeśli ustawiony) zawęża tylko serwer
        if loc.job == job and #(pos - vec3(loc.mcoords.x, loc.mcoords.y, loc.mcoords.z)) <= (loc.radius or loc.distance or 2.0) + 2.0 then
            return true
        end
    end
    return false
end

function Server.Open(src)
    local now = GetGameTimer()
    if lastOpen[src] and now - lastOpen[src] < 1000 then return end
    lastOpen[src] = now

    local x = ESX.GetPlayerFromId(src)
    local job = baseJob(x and x.job and x.job.name)
    if not x or not job or not Config.Jobs[job] or not Server.CanManage(x) then
        TriggerClientEvent('crp_bossmenu:client:forceClose', src)
        return TriggerClientEvent('crp_bossmenu:client:notify', src, 'Nie masz dostępu do panelu zarządzania.', 'error')
    end
    if not nearLocation(src, job) then
        TriggerClientEvent('crp_bossmenu:client:forceClose', src)
        return TriggerClientEvent('crp_bossmenu:client:notify', src, 'Musisz być przy panelu zarządzania.', 'error')
    end

    local me = data.FindByIdentifier(x.identifier)
    if not me then
        -- wcześniej cichy `return` – gracz czekał 3 s na „brak odpowiedzi serwera”
        TriggerClientEvent('crp_bossmenu:client:forceClose', src)
        return TriggerClientEvent('crp_bossmenu:client:notify', src,
            'Nie znaleziono Twojej postaci w bazie (sprawdź Config.Db: identifier/kolumny w tabeli graczy).', 'error')
    end

    -- jedna osoba na panel: sprawdzamy i zajmujemy blokadę PRZED wczytaniem danych
    if lockEnabled() then
        local holder = panelHolder(job)
        if holder and holder.src ~= src then
            TriggerClientEvent('crp_bossmenu:client:forceClose', src)
            return TriggerClientEvent('crp_bossmenu:client:notify', src,
                ('Panel jest teraz używany przez %s – poczekaj, aż skończy.'):format(holder.name), 'error')
        end
        local full = ('%s %s'):format(me.firstname or '', me.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
        Panels[job] = { src = src, name = (full ~= '' and full or displayName(src)), since = os.time(), key = pointOf(src, job) }
        broadcastPanel(job)
    end

    Sessions[src] = {
        job = job, identifier = x.identifier,
        ssn = me.ssn or x.identifier, firstname = me.firstname or '', lastname = me.lastname or '', grade = x.job.grade
    }

    local ok, payload = pcall(data.Build, Sessions[src])
    if not ok then
        Sessions[src] = nil
        freePanel(src, job)                     -- nie zostawiamy po sobie blokady panelu
        print('^1[crp_bossmenu] Build:^7', payload)
        return TriggerClientEvent('crp_bossmenu:client:notify', src, 'Błąd wczytywania danych panelu.', 'error')
    end
    TriggerClientEvent('crp_bossmenu:client:open', src, payload)
end

local function push(src)
    local c = context(src)
    if not c then return Server.ForceClose(src) end

    local ok, payload = pcall(data.Build, Sessions[src])
    if ok then TriggerClientEvent('crp_bossmenu:client:update', src, payload)
    else print('^1[crp_bossmenu] Build:^7', payload) end
end

local function flushRefresh()
    refreshTimer = false
    local jobs = pendingRefresh
    pendingRefresh = {}

    for src, s in pairs(Sessions) do
        if jobs['*'] or jobs[s.job] then push(src) end
    end
end

-- Odświeżenie z krótkim opóźnieniem: odpowiedź na akcję dociera do UI PRZED paczką `update`.
function Server.Refresh(...)
    for _, job in ipairs({ ... }) do pendingRefresh[job] = true end
    if not refreshTimer then
        refreshTimer = true
        SetTimeout(250, flushRefresh)
    end
end

function Server.RefreshAll() Server.Refresh('*') end


-- ═════════════════════════════════════════════════════════════
--  WEBHOOKI DISCORD
-- ═════════════════════════════════════════════════════════════
local function postHook(url, title, desc, color, wait)
    local body = json.encode({
        username = Config.Discord.botName,
        embeds = { { title = title, description = desc, color = color, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } }
    })
    local p = promise.new()
    PerformHttpRequest(url, function(status) p:resolve(status) end, 'POST', body, { ['Content-Type'] = 'application/json' })
    if wait then return Citizen.Await(p) end
end

local function hook(job, key, title, desc, color)
    local url = data.Hooks(job)[key]
    if url and url ~= '' then
        postHook(url, title, ('%s\n\n**Firma:** %s'):format(desc, data.JobLabel(job)), color)
    end
end


-- ═════════════════════════════════════════════════════════════
--  AKCJE Z UI
-- ═════════════════════════════════════════════════════════════
local Actions = {}
local H = Actions

local function jobCfg(c) return Config.Jobs[c.job] end
local function feature(c, key)
    local f = jobCfg(c).features
    return f and f[key] == true
end

local function gradeName(job, grade)
    for _, g in ipairs(data.Grades(job)) do if g.id == grade then return g.name end end
    return '—'
end

-- pracownik tej samej firmy, znaleziony po SSN
local function target(c, ssn)
    ssn = str(ssn, 40)
    if not ssn or ssn == '' then return nil, 'Podaj SSN pracownika' end

    local t = data.FindBySsn(ssn)
    if not t then return nil, 'Nie znaleziono pracownika' end

    local x = ESX.GetPlayerFromIdentifier(t.identifier)
    t.grade = x and x.job.grade or t.grade
    t.job = x and x.job.name or t.job
    t.src = x and x.source or nil
    t.name = fullName(t)

    if t.job ~= c.job then return nil, 'Ta osoba nie pracuje w Twojej firmie' end
    return t
end

-- stopnia i zwolnienia nie robimy na szefie ani na sobie
local function manageable(c, t)
    if t.identifier == c.identifier then return 'Nie możesz wykonać tej akcji na sobie' end
    if t.grade >= data.BossGrade(c.job) then return 'Nie można wykonać tej akcji na szefie' end
end

local function reasonOf(v)
    local r = str(v, 300)
    if not r or #r < 5 then return nil end
    return r
end

local function summary(items)
    local parts = {}
    for i, it in ipairs(items) do
        parts[i] = ('%s ×%d%s'):format(it.name or it.model, it.qty or 1, it.express and ' ⚡' or '')
    end
    return table.concat(parts, ', ')
end

-- ── pracownicy ──

H.setGrade = function(c, d)
    local reason = reasonOf(d.reason); if not reason then return err('Podaj powód (min. 5 znaków)') end
    local t, e = target(c, d.ssn); if not t then return err(e) end
    local m = manageable(c, t); if m then return err(m) end

    local grade, boss = int(d.grade, 0), data.BossGrade(c.job)
    local jobGrades = ESX.Jobs[c.job] and ESX.Jobs[c.job].grades
    if not grade or not (jobGrades and jobGrades[tostring(grade)]) then return err('Nieprawidłowy stopień') end
    if grade >= boss and c.grade < boss then return err('Stopień szefa może nadać tylko szef') end
    if grade == t.grade then return err('Pracownik ma już ten stopień') end

    data.SetJob(t.identifier, c.job, grade)
    data.AddPromotion(c.job, t.identifier, t.grade, grade, c.name, reason)

    -- stopień w pamięci, żeby panel od razu pokazywał nowy (bez zapytania do bazy)
    local entry = data.Roster(c.job)[t.identifier]
    if entry then entry.grade = grade
    else data.RosterAdd(c.job, { identifier = t.identifier, firstname = t.firstname, lastname = t.lastname, ssn = t.ssn, phone = t.phone, grade = grade }) end

    hook(c.job, 'promo', grade > t.grade and 'Awans' or 'Degradacja',
        ('**Pracownik:** %s\n**Stopień:** %s → %s\n**Powód:** %s\n**Wykonał:** %s')
            :format(t.name, gradeName(c.job, t.grade), gradeName(c.job, grade), reason, c.name),
        Config.Discord.colors.promo)
    return { ok = true }
end

H.hire = function(c, d)
    local ssn = str(d.ssn, 40); if not ssn or ssn == '' then return err('Podaj SSN gracza') end

    local t = data.FindBySsn(ssn); if not t then return err('Nie znaleziono gracza o tym SSN') end
    local x = ESX.GetPlayerFromIdentifier(t.identifier)
    local job = x and x.job.name or t.job

    if job == c.job then return err('Ta osoba już u Ciebie pracuje') end
    if Config.HireOnlyUnemployed and job ~= Config.Unemployed.job then return err('Ten gracz pracuje w innej firmie') end

    local grade, boss = int(d.grade, 0), data.BossGrade(c.job)
    if not grade or grade >= boss or not ESX.Jobs[c.job].grades[tostring(grade)] then return err('Nieprawidłowy stopień startowy') end

    data.SetJob(t.identifier, c.job, grade)
    data.SetHired(c.job, t.identifier)
    data.RosterAdd(c.job, {
        identifier = t.identifier, firstname = t.firstname, lastname = t.lastname,
        ssn = t.ssn, phone = t.phone, grade = grade
    })

    if x then
        TriggerClientEvent('crp_bossmenu:client:notify', x.source,
            ('Zostałeś zatrudniony w firmie %s.'):format(data.JobLabel(c.job)), 'success')
    end

    return { ok = true, employee = {
        firstname = t.firstname, lastname = t.lastname, phonenumber = t.phone or '',
        status = x and Config.GetDutyStatus(x.source, x) or 'off'
    } }
end

H.fire = function(c, d)
    local t, e = target(c, d.ssn); if not t then return err(e) end
    local m = manageable(c, t); if m then return err(m) end

    -- odbierz przydzielone pojazdy
    local revoked = 0
    for _, v in ipairs(data.Vehicles(c.job)) do
        if v.assigned_identifier == t.identifier then
            revoked = revoked + 1
            data.SetVehicleOwner(c.job, v.plate, nil, nil)
            data.VehicleOwner(c.job, v.plate, nil)
        end
    end

    -- opcjonalnie: odbierz licencje, które firma nadaje (Config.Licenses.removeOnFire)
    local licenses = Config.Licenses or {}
    if licenses.removeOnFire then
        for _, def in ipairs(jobCfg(c).licenses or {}) do
            if data.SetLicense(c.job, t.identifier, def.id, false) then
                data.Hist(c.job, c.name, { type = 'license', action = 'remove', ssn = tostring(t.ssn), identifier = t.identifier,
                    name = t.name, license = def.id, label = def.label })
            end
        end
    end

    local gname = gradeName(c.job, t.grade)
    data.SetJob(t.identifier, Config.Unemployed.job, Config.Unemployed.grade)
    data.RemoveMember(c.job, t.identifier)
    data.RosterRemove(c.job, t.identifier)

    data.Hist(c.job, c.name, { type = 'fire', ssn = t.ssn, name = t.name, gradeName = gname, vehicles = revoked })

    if t.src then
        TriggerClientEvent('crp_bossmenu:client:notify', t.src,
            ('Zostałeś zwolniony z firmy %s.'):format(data.JobLabel(c.job)), 'error')
        Server.ForceClose(t.src)
    end
    return { ok = true }
end

H.setBadge = function(c, d)
    if not feature(c, 'badges') then return err('Odznaki są wyłączone') end
    local t, e = target(c, d.ssn); if not t then return err(e) end

    local badge
    if d.badge ~= nil and d.badge ~= '' and d.badge ~= 0 then
        badge = int(d.badge, 1, 99999)
        if not badge then return err('Numer odznaki: 1–99999') end
    end

    if not data.SetBadge(c.job, t.identifier, badge) then return err('Ten numer odznaki jest już zajęty') end
    return { ok = true }
end

local KINDS = {
    plus      = { key = 'plusminus', title = 'Plus' },
    minus     = { key = 'plusminus', title = 'Minus' },
    commend   = { key = 'commend',   title = 'Pochwała' },
    reprimand = { key = 'commend',   title = 'Nagana' }
}

H.addRecord = function(c, d)
    if not feature(c, 'records') then return err('Wpisy są wyłączone') end
    local kind = KINDS[d.kind]; if not kind then return err('Nieprawidłowy rodzaj wpisu') end
    local reason = reasonOf(d.reason); if not reason then return err('Podaj powód (min. 5 znaków)') end
    local t, e = target(c, d.ssn); if not t then return err(e) end

    data.AddRecord(c.job, t.identifier, d.kind, reason, c.name)

    hook(c.job, kind.key, kind.title,
        ('**Pracownik:** %s\n**Powód:** %s\n**Wystawił:** %s'):format(t.name, reason, c.name),
        Config.Discord.colors[d.kind])
    return { ok = true }
end

H.voidRecord = function(c, d)
    local id, reason = int(d.id, 1), reasonOf(d.reason)
    if not id then return err('Nie znaleziono wpisu') end
    if not reason then return err('Podaj powód (min. 5 znaków)') end

    if not data.VoidRecord(c.job, id, c.name, reason) then
        return err('Wpis nie istnieje albo jest już unieważniony')
    end
    return { ok = true }
end

H.setLicense = function(c, d)
    if not feature(c, 'licenses') then return err('Licencje są wyłączone') end

    local def
    for _, l in ipairs(jobCfg(c).licenses or {}) do if l.id == d.license then def = l end end
    if not def then return err('Nieznana licencja') end

    local t, e = target(c, d.ssn); if not t then return err(e) end

    local adding = d.value == true
    local ok, why = data.SetLicense(c.job, t.identifier, def.id, adding)
    if not ok then return err(why or 'Nie udało się zmienić licencji') end

    -- wpis w historii: daje też datę nadania, którą panel pokazuje w oknie licencji
    data.Hist(c.job, c.name, {
        type = 'license', action = adding and 'add' or 'remove',
        ssn = tostring(t.ssn), identifier = t.identifier, name = t.name,
        license = def.id, label = def.label
    })
    return { ok = true }
end

H.resetHours = function(c, d)
    local t, e = target(c, d.ssn); if not t then return err(e) end
    data.ResetHours(c.job, t.identifier)
    return { ok = true }
end

H.resetAllHours = function(c)
    local total, count = data.ResetAllHours(c.job)
    data.Hist(c.job, c.name, { type = 'resetHours', count = count, total = total })
    return { ok = true }
end

H.setNote = function(c, d)
    local t, e = target(c, d.ssn); if not t then return err(e) end

    local html = sanitizeHtml(d.html)
    if #html > 30000 then return err('Notatka jest za długa') end

    local plain = html:gsub('<[^>]*>', ''):gsub('&nbsp;', ' '):gsub('%s+', '')
    data.SetNote(c.job, t.identifier, plain == '' and '' or html, c.name)
    return { ok = true }
end

-- ── frakcja ──

H.setSalary = function(c, d)
    local grade = int(d.grade, 0)
    local def
    for _, g in ipairs(data.Grades(c.job)) do if g.id == grade then def = g end end
    if not def then return err('Nieprawidłowy stopień') end

    local max = jobCfg(c).salaryMax or 10000
    local salary = int(d.salary, 0, max)
    if not salary then return err(('Stawka: 0–%d'):format(max)) end
    if salary == def.salary then return { ok = true } end

    data.SetSalary(c.job, grade, salary)
    data.Hist(c.job, c.name, { type = 'salary', grade = grade, gradeName = def.name, from = def.salary, to = salary })
    return { ok = true }
end

local HOOK_KEYS = { 'plusminus', 'commend', 'promo' }

local function validHook(url)
    if url == '' then return true end
    if #url > 220 then return false end
    return url:match('^https://[%w%.]*discord%.com/api/webhooks/%d+/[%w_%-]+$') ~= nil
        or url:match('^https://[%w%.]*discordapp%.com/api/webhooks/%d+/[%w_%-]+$') ~= nil
end

H.setWebhooks = function(c, d)
    local previous = data.Hooks(c.job)
    local hooks = {}

    for _, key in ipairs(HOOK_KEYS) do
        local url = str(d[key] or '', 220)
        if url == nil or not validHook(url) then return err('Nieprawidłowy link webhooka') end
        hooks[key] = url
    end

    data.SetHooks(c.job, hooks)

    for i = #HOOK_KEYS, 1, -1 do          -- kolejność wpisów w historii jak w UI
        local key = HOOK_KEYS[i]
        if previous[key] ~= hooks[key] then
            data.Hist(c.job, c.name, {
                type = 'webhook', key = key,
                action = hooks[key] == '' and 'removed' or (previous[key] ~= '' and 'changed' or 'set')
            })
        end
    end
    return { ok = true }
end

H.testWebhook = function(c, d)
    local url = data.Hooks(c.job)[tostring(d.key)]
    if not url then return err('Nieznany webhook') end
    if url == '' then return err('Najpierw zapisz link webhooka') end

    local status = postHook(url, 'Test webhooka', ('Wiadomość testowa wysłana przez **%s**.'):format(c.name), Config.Discord.colors.test, true)
    if status and status >= 200 and status < 300 then return { ok = true } end
    return err(('Discord odrzucił żądanie (kod %s)'):format(tostring(status)))
end

H.deposit = function(c, d)
    local amount = int(d.amount, 1, 100000000); if not amount then return err('Nieprawidłowa kwota') end
    if c.xPlayer.getAccount(Config.PlayerAccount).money < amount then return err('Nie masz tyle pieniędzy') end

    c.xPlayer.removeAccountMoney(Config.PlayerAccount, amount)
    if not data.AddFunds(c.job, amount) then
        c.xPlayer.addAccountMoney(Config.PlayerAccount, amount)
        return err('Konto firmy jest niedostępne')
    end

    data.Tx(c.job, 'in', amount, c.name, 'Wpłata')
    return { ok = true, funds = data.Funds(c.job) }
end

H.withdraw = function(c, d)
    local amount = int(d.amount, 1, 100000000); if not amount then return err('Nieprawidłowa kwota') end
    local reason = reasonOf(d.reason); if not reason then return err('Podaj powód wypłaty (min. 5 znaków)') end
    if not data.RemoveFunds(c.job, amount) then return err('Brak środków na koncie firmy') end

    c.xPlayer.addAccountMoney(Config.PlayerAccount, amount)
    data.Tx(c.job, 'out', amount, c.name, 'Wypłata', reason)
    return { ok = true, funds = data.Funds(c.job) }
end

-- ── garaż ──

H.assignVehicle = function(c, d)
    local plate = str(d.plate, 12)
    local vehicle
    for _, v in ipairs(data.Vehicles(c.job)) do if v.plate == plate then vehicle = v end end
    if not vehicle then return err('Nie znaleziono pojazdu') end

    local t, e = target(c, d.ssn); if not t then return err(e) end
    if vehicle.assigned_identifier == t.identifier then return err('Pojazd jest już przydzielony temu pracownikowi') end

    local from = ''
    if vehicle.assigned_ssn then
        for _, u in pairs(data.Roster(c.job)) do
            if u.ssn == vehicle.assigned_ssn then from = fullName(u) end
        end
    end

    data.SetVehicleOwner(c.job, plate, t.identifier, t.ssn)
    data.VehicleOwner(c.job, plate, t.identifier)
    data.Hist(c.job, c.name, { type = 'vehAssign', plate = plate, vehicle = vehicle.name, ssn = t.ssn, name = t.name, from = from })

    if t.src then
        TriggerClientEvent('crp_bossmenu:client:notify', t.src, ('Przydzielono Ci pojazd: %s (%s)'):format(vehicle.name, plate), 'success')
    end
    return { ok = true }
end

H.revokeVehicle = function(c, d)
    local plate = str(d.plate, 12)
    local vehicle
    for _, v in ipairs(data.Vehicles(c.job)) do if v.plate == plate then vehicle = v end end
    if not vehicle then return err('Nie znaleziono pojazdu') end
    if not vehicle.assigned_identifier then return err('Pojazd nie jest przydzielony') end

    local name = '—'
    for _, u in pairs(data.Roster(c.job)) do
        if u.identifier == vehicle.assigned_identifier then name = fullName(u) end
    end

    data.SetVehicleOwner(c.job, plate, nil, nil)
    data.VehicleOwner(c.job, plate, nil)
    data.Hist(c.job, c.name, { type = 'vehRevoke', plate = plate, vehicle = vehicle.name, ssn = vehicle.assigned_ssn or '', name = name })
    return { ok = true }
end

H.orderVehicles = function(c, d)
    local vs = Config.VehicleShop
    if c.job == vs.supplierJob then return err('Ta firma sama jest dostawcą pojazdów') end
    if type(d.items) ~= 'table' or #d.items < 1 or #d.items > vs.cartMax then return err('Nieprawidłowa liczba pojazdów') end

    local catalog = {}
    for _, v in ipairs(data.VehicleCatalog(c.job)) do catalog[v.model] = v end

    local items, names, total, express = {}, {}, 0, 0
    for _, picked in ipairs(d.items) do
        local cat = type(picked) == 'table' and catalog[picked.model]
        if not cat then return err('Nie ma takiego pojazdu w katalogu') end

        local fast = picked.express == true
        local fee = fast and (cat.expressFee or vs.expressFee) or 0
        items[#items + 1] = { model = cat.model, name = cat.name, category = cat.category, price = cat.price, express = fast, fee = fee }
        names[#names + 1] = cat.name .. (fast and ' ⚡' or '')
        total = total + cat.price + fee
        if fast then express = express + 1 end
    end

    if not data.RemoveFunds(c.job, total) then return err('Brak środków na koncie firmy') end

    local id = data.NewOrder('vehicles', c.job, vs.supplierJob, items, total, c.name)
    if not id then
        data.AddFunds(c.job, total)
        return err('Nie udało się złożyć zamówienia')
    end

    local count = #items
    data.Tx(c.job, 'out', total, c.name, 'Zamówienie pojazdów',
        ('%d %s%s: %s'):format(count, plural(count, 'pojazd', 'pojazdy', 'pojazdów'),
            express > 0 and (' (w tym szybki transport: %d)'):format(express) or '', table.concat(names, ', ')))
    data.Hist(c.job, c.name, { type = 'order', orderId = 'ord-' .. id, count = count, total = total, express = express, items = names })

    Server.NotifyJob(vs.supplierJob, ('Nowe zamówienie pojazdów od %s (ord-%d)'):format(data.JobLabel(c.job), id), 'info')
    Server.Refresh(vs.supplierJob, c.job)

    return { ok = true, funds = data.Funds(c.job), order = {
        id = 'ord-' .. id, items = items, total = total, status = 'pending', by = c.name
    } }
end

local function parseOrderId(v)
    local prefix, id = tostring(v or ''):match('^(%a+)%-(%d+)$')
    id = tonumber(id)
    if not id or (prefix ~= 'ord' and prefix ~= 'zam') then return nil end
    return id, prefix == 'ord' and 'vehicles' or 'goods'
end

H.cancelOrder = function(c, d)
    local id, kind = parseOrderId(d.id); if not id then return err('Nie znaleziono zamówienia') end

    local order = data.GetOrder(id, kind, 'buyer_job', c.job)
    if not order then return err('Nie znaleziono zamówienia') end

    if not data.SetOrderStatus(id, 'buyer_job', c.job, 'pending', 'cancelled', nil, c.job, order.supplier_job) then
        return err('Zamówienie nie może już zostać anulowane')
    end

    Server.CancelDelivery(id, order, 'cancelled')

    data.AddFunds(c.job, order.total)
    local items = json.decode(order.items) or {}
    local names = {}
    for i, it in ipairs(items) do names[i] = it.name or it.model end

    data.Tx(c.job, 'in', order.total, c.name, 'Zwrot za zamówienie',
        ('%s: %s'):format((kind == 'vehicles' and 'ord-' or 'zam-') .. id, table.concat(names, ', ')))
    data.Hist(c.job, c.name, kind == 'vehicles'
        and { type = 'orderCancel', orderId = 'ord-' .. id, count = #items, total = order.total }
        or { type = 'goodsCancel', orderId = 'zam-' .. id, supplier = data.JobLabel(order.supplier_job), total = order.total })

    Server.Refresh(c.job, order.supplier_job)
    return { ok = true, funds = data.Funds(c.job) }
end

H.supplierOrder = function(c, d)
    local id, kind = parseOrderId(d.id); if not id then return err('Nie znaleziono zamówienia') end

    local action = d.action
    if action ~= 'accept' and action ~= 'reject' and action ~= 'deliver' then return err('Nieprawidłowa akcja') end

    local reason
    if action == 'reject' then
        reason = reasonOf(d.reason)
        if not reason then return err('Podaj powód odrzucenia (min. 5 znaków)') end
    end

    local order = data.GetOrder(id, kind, 'supplier_job', c.job)
    if not order then return err('Nie znaleziono zamówienia') end

    -- fizyczna dostawa: nie da się „dostarczyć” aut z panelu, zanim laweta ich nie odda
    if action == 'deliver' and kind == 'vehicles' and order.delivery == 'physical'
        and Server.DeliveryEnabled() and not (Config.VehicleShop.delivery or {}).manualOverride then
        return err('Pojazdy są w drodze lawetą – oddanie potwierdza firma dostawcy na miejscu odbioru')
    end
    local from = action == 'deliver' and 'accepted' or 'pending'
    local to   = ({ accept = 'accepted', reject = 'rejected', deliver = 'delivered' })[action]
    if not data.SetOrderStatus(id, 'supplier_job', c.job, from, to, reason, order.buyer_job, c.job) then
        return err('Status zamówienia już się zmienił')
    end
    if action == 'deliver' and kind == 'vehicles' then Server.CancelDelivery(id, order, 'manual') end

    local items = json.decode(order.items) or {}
    local buyerLabel = data.JobLabel(order.buyer_job)
    local names = {}
    for i, it in ipairs(items) do names[i] = it.name or it.model end
    local orderNo = (kind == 'vehicles' and 'ord-' or 'zam-') .. id

    if action == 'reject' then
        if kind == 'vehicles' then Server.CancelDelivery(id, order, 'rejected') end
        data.AddFunds(order.buyer_job, order.total)
        data.Tx(order.buyer_job, 'in', order.total, 'System', 'Zwrot za zamówienie', ('%s (odrzucone): %s'):format(orderNo, table.concat(names, ', ')))
        Server.NotifyJob(order.buyer_job, ('Zamówienie %s zostało odrzucone – środki wróciły na konto firmy'):format(orderNo), 'warn')

    elseif action == 'accept' then
        -- pojazdy bez szybkiego transportu: nie wpisujemy ich od razu do garażu,
        -- tylko wysyłamy zadanie do zasobu CD (auta jadą na lawecie `tr2`)
        if kind ~= 'vehicles' or not Server.StartDelivery(order, items, c.name) then
            Server.NotifyJob(order.buyer_job, ('Zamówienie %s zostało przyjęte do realizacji'):format(orderNo), 'success')
        end

    else
        data.AddFunds(c.job, order.total)
        data.Tx(c.job, 'in', order.total, c.name, 'Dostawa zamówienia', ('%s · %s: %s'):format(orderNo, buyerLabel, table.concat(names, ', ')))

        if kind == 'vehicles' then
            for _, it in ipairs(items) do
                local plate = data.NewPlate()
                if plate then
                    data.AddVehicle(order.buyer_job, plate, it.model, it.name, it.category)
                    data.GrantVehicle(order.buyer_job, plate, it.model)
                else
                    print(('^1[crp_bossmenu] nie udało się wygenerować tablicy dla %s^7'):format(orderNo))
                end
            end
        else
            Config.GoodsDelivery({ id = orderNo, buyerJob = order.buyer_job, supplierJob = c.job, total = order.total, items = items })
        end

        Server.NotifyJob(order.buyer_job, ('Zamówienie %s zostało dostarczone'):format(orderNo), 'success')
    end

    data.Hist(c.job, c.name, { type = 'orderHandled', orderId = orderNo, action = to, buyer = buyerLabel, total = order.total, reason = reason })
    Server.Refresh(order.buyer_job, c.job)
    return { ok = true, funds = data.Funds(c.job) }
end

-- ── oferta (produkty firm-dostawców) ──

H.orderGoods = function(c, d)
    local vs = Config.Goods
    local supplierJob = str(d.supplier, 50)
    local supplierCfg = supplierJob and Config.Jobs[supplierJob]
    if not supplierCfg or not supplierCfg.supplier or supplierJob == c.job then return err('Nieprawidłowy dostawca') end
    if type(d.items) ~= 'table' or #d.items < 1 or #d.items > vs.maxLines then return err('Nieprawidłowa liczba pozycji') end

    local catalog = {}
    for _, p in ipairs(data.Products(supplierJob)) do catalog[p.id] = p end

    local items, total, express = {}, 0, 0
    for _, picked in ipairs(d.items) do
        local product = type(picked) == 'table' and catalog[tonumber(picked.id)]
        local qty = type(picked) == 'table' and int(picked.qty, 1, vs.maxQty)
        if not product or not product.active or not data.HasAccess(product, c.job) or not qty then
            return err('Nieprawidłowa pozycja zamówienia')
        end
        -- pojazdy zamawia się w Garażu (katalog), nie w zamówieniach towarowych
        if product.model and product.model ~= '' then
            return err('Ten produkt to pojazd – zamów go w Garażu (zakładka Katalog)')
        end

        -- szybki transport: dopłatę (za sztukę) ustawia dostawca na produkcie, ewentualnie domyślna z Config.Goods;
        -- kupujący tylko zaznacza „zwykły / szybki”
        local fee = tonumber(product.expressFee) or tonumber(vs.expressFee) or 0
        local fast = picked.express == true and fee > 0
        items[#items + 1] = { id = product.id, name = product.name, price = product.price, qty = qty,
                              express = fast, fee = fast and fee or 0 }
        total = total + product.price * qty + (fast and fee * qty or 0)
        if fast then express = express + 1 end
    end

    local note = str(d.note or '', 300) or ''
    if not data.RemoveFunds(c.job, total) then return err('Brak środków na koncie firmy') end

    local id = data.NewOrder('goods', c.job, supplierJob, items, total, c.name, note ~= '' and note or nil)
    if not id then
        data.AddFunds(c.job, total)
        return err('Nie udało się złożyć zamówienia')
    end

    data.Tx(c.job, 'out', total, c.name, 'Zamówienie towarów', ('%s: %s'):format(data.JobLabel(supplierJob), summary(items)))
    data.Hist(c.job, c.name, { type = 'goodsOrder', orderId = 'zam-' .. id, supplier = data.JobLabel(supplierJob), lines = #items,
        units = (function() local n = 0 for _, it in ipairs(items) do n = n + it.qty end return n end)(),
        express = express, total = total, items = items })

    Server.NotifyJob(supplierJob, ('Nowe zamówienie towarów od %s (zam-%d)%s'):format(data.JobLabel(c.job), id,
        express > 0 and (' – szybki transport: %d %s'):format(express, plural(express, 'pozycja', 'pozycje', 'pozycji')) or ''), 'info')
    Server.Refresh(supplierJob, c.job)

    return { ok = true, funds = data.Funds(c.job), order = {
        id = 'zam-' .. id, items = items, total = total, status = 'pending', by = c.name,
        supplier = { job = supplierJob, label = data.JobLabel(supplierJob) },
        buyer = { job = c.job, label = data.JobLabel(c.job) }
    } }
end

local function requireSupplier(c) return jobCfg(c).supplier == true end

H.saveProduct = function(c, d)
    if not requireSupplier(c) then return err('Ta firma nie może publikować oferty') end

    local G = Config.Goods
    local name = str(d.name, 60); if not name or #name < 2 then return err('Nazwa produktu: 2–60 znaków') end
    local category = str(d.category or '', 30); if not category then return err('Kategoria jest za długa') end
    local desc = str(d.desc or '', 200); if not desc then return err('Opis jest za długi (max 200)') end
    local price = int(d.price, 1, G.maxPrice); if not price then return err(('Cena: 1–%d'):format(G.maxPrice)) end

    -- pojazd (tylko firma-dostawca): model do spawnu + własna dopłata za szybki transport
    local model = str(d.model or '', 50)
    if not model then return err('Model pojazdu jest za długi (max 50 znaków)') end
    if model ~= '' and not model:match('^[%w_%-]+$') then return err('Model pojazdu: tylko litery, cyfry, - i _') end
    model = model ~= '' and model or nil

    -- modelem steruje wyłącznie firma-dostawca pojazdów (Config.VehicleShop.supplierJob) – tylko takie
    -- pozycje trafiają do katalogu w Garażu i tylko one znikają z zamówień towarowych
    if model and c.job ~= (Config.VehicleShop and Config.VehicleShop.supplierJob) then
        return err('Model pojazdu może ustawić tylko firma-dostawca pojazdów')
    end

    local expressFee
    if d.expressFee ~= nil and d.expressFee ~= '' and d.expressFee ~= json.null then
        expressFee = int(d.expressFee, 0, G.maxPrice)
        if not expressFee then return err(('Dopłata za szybki transport: 0–%d'):format(G.maxPrice)) end
    end

    local access
    if d.access ~= nil and d.access ~= json.null and type(d.access) == 'table' then
        access = {}
        local seen = {}
        for _, job in ipairs(d.access) do
            if type(job) ~= 'string' or not Config.Jobs[job] or job == c.job then return err('Nieprawidłowa firma na liście dostępu') end
            if not seen[job] then seen[job] = true; access[#access + 1] = job end
        end
        if #access == 0 then return err('Wybierz co najmniej jedną firmę albo zezwól wszystkim') end
    end

    local id = d.id ~= nil and int(d.id, 1) or nil
    local previous
    if d.id ~= nil then
        previous = id and data.FindProduct(c.job, id)
        if not previous then return err('Nie znaleziono produktu') end
    end
    if data.ProductNameExists(c.job, name, id) then return err('Produkt o tej nazwie już istnieje w ofercie') end

    local product = { name = name, category = category, desc = desc, price = price, active = d.active ~= false,
                      access = access, model = model, expressFee = expressFee }
    id = data.SaveProduct(c.job, previous and id or nil, product)

    if not previous then
        data.Hist(c.job, c.name, { type = 'offerChange', action = 'add', name = name, to = price })
    else
        local entry
        if previous.price ~= price then entry = { action = 'price', from = previous.price, to = price }
        elseif flag(previous.active) ~= product.active then entry = { action = product.active and 'show' or 'hide' }
        elseif (previous.access or '') ~= (access and json.encode(access) or '') then entry = { action = 'access' }
        else entry = { action = 'edit' } end
        entry.type, entry.name = 'offerChange', name
        data.Hist(c.job, c.name, entry)
    end

    Server.RefreshAll()
    return { ok = true, product = { id = id } }
end

H.deleteProduct = function(c, d)
    if not requireSupplier(c) then return err('Ta firma nie może publikować oferty') end

    local id = int(d.id, 1)
    local product = id and data.FindProduct(c.job, id)
    if not product then return err('Nie znaleziono produktu') end

    data.DeleteProduct(c.job, id)
    data.Hist(c.job, c.name, { type = 'offerChange', action = 'remove', name = product.name, to = product.price })

    Server.RefreshAll()
    return { ok = true }
end


-- ═════════════════════════════════════════════════════════════
--  FIZYCZNA DOSTAWA POJAZDÓW (gdy kupujący NIE wybrał szybkiego transportu)
--
--  Zamówienie pojazdów bez ⚡ nie kończy się „magicznym” wpisem do garażu:
--  firma-dostawca (CD) musi załadować auta na lawetę i odwieźć je na miejsce.
--  Panel tylko:
--    • przy przyjęciu zamówienia generuje tablice i wysyła zadanie do zasobu dostawy,
--    • przy potwierdzeniu oddania aut (z zasobu dostawy) płaci i wpisuje pojazdy do garażu.
--  Gdy zasób dostawy nie jest uruchomiony, wszystko działa po staremu (auta od razu w garażu).
-- ═════════════════════════════════════════════════════════════
local Physical = {}      -- [id zamówienia] = { items = {...}, plates = { [1] = 'ABC 123' }, handed = {...}, at, by }

-- ── NIGDY nie porównujemy surowego `source` ──────────────────────────────────
--  Gdy event wywołuje INNY zasób (a nie gracz), do handlera potrafi trafić cokolwiek:
--  liczba, tekst, `nil`, a nawet funkcja-callback. Wcześniej `src > 0` wywalało wtedy
--  „attempt to compare number with string” i przewracało całą akcję (np. przyjęcie zamówienia).

local function deliveryCfg() return (Config.VehicleShop and Config.VehicleShop.delivery) or {} end

function Server.DeliveryEnabled()
    local res = deliveryCfg().resource
    return type(res) == 'string' and res ~= '' and GetResourceState(res) == 'started'
end

-- czy w zamówieniu jest choć jeden pojazd bez szybkiego transportu
local function hasPhysicalItems(items)
    for _, it in ipairs(items or {}) do if not it.express then return true end end
    return false
end

-- adres dostawy: punkt bossmenu pracy zamawiającej (np. policja → komenda); nil = adres z configu nano
local function deliveryDestination(buyerJob)
    for _, loc in pairs(Config.Locations) do
        if loc.job == buyerJob and loc.mcoords then
            local chair = loc.chaircoords
            return { x = loc.mcoords.x, y = loc.mcoords.y, z = loc.mcoords.z,
                     heading = (chair and (chair.w or chair.heading)) or 0.0, label = data.JobLabel(buyerJob) }
        end
    end
    return nil
end

local function pendingRow(id)
    for _, r in ipairs(data.Orders(Config.VehicleShop.supplierJob).supplier) do
        if r.id == id then return r end
    end
end

-- buduje i wysyła zadanie dostawy do zasobu CD (używa tego też ResendDeliveries)
local function dispatchDelivery(order, items)
    local cfg = deliveryCfg()
    local id = order.id

    local task, resend = Physical[id], Physical[id] ~= nil
    if not task then
        task = { plates = {}, handed = {}, by = order.by_name, at = os.time() }
        Physical[id] = task
    end
    task.handed = task.handed or {}

    local payload = {
        orderId    = 'ord-' .. id,
        id         = id,
        buyerJob   = order.buyer_job,
        buyerLabel = data.JobLabel(order.buyer_job),
        supplierJob = order.supplier_job,
        total      = order.total,
        destination = deliveryDestination(order.buyer_job),
        handed     = task.handed,
        items      = {}
    }

    for i, it in ipairs(items) do
        -- tablice generujemy raz – auto dostanie je już na placu, a my zapiszemy je w garażu
        if not it.express and not task.plates[i] then task.plates[i] = data.NewPlate() end
        payload.items[#payload.items + 1] = {
            index = i, model = it.model, name = it.name, category = it.category or '',
            express = it.express and true or false, plate = task.plates[i]
        }
    end

    -- kolejność: najpierw wpisy w tasku, potem event (zasób CD czyta od razu)
    TriggerEvent(cfg.event or 'crp_cd:server:start', payload)
    if resend and cfg.resendEvent then TriggerEvent(cfg.resendEvent, payload) end
    return payload
end

function Server.StartDelivery(order, items, who)
    if not Server.DeliveryEnabled() then return false end
    if not hasPhysicalItems(items) then return false end

    data.SetOrderDelivery(order.id, 'physical', order.buyer_job, order.supplier_job)
    local payload = dispatchDelivery(order, items)
    Physical[order.id].by = who or order.by_name

    -- pozycje z szybkim transportem w tym samym zamówieniu nie jadą lawetą –
    -- wpisujemy je do garażu od razu (za nie właśnie dopłacono)
    local fast = {}
    for _, it in ipairs(items) do
        if it.express then
            local plate = data.NewPlate()
            if plate then
                data.AddVehicle(order.buyer_job, plate, it.model, it.name, it.category)
                data.GrantVehicle(order.buyer_job, plate, it.model)
                fast[#fast + 1] = ('%s (%s)'):format(it.name or it.model, plate)
            end
        end
    end
    if #fast > 0 then
        Server.NotifyJob(order.buyer_job, ('Szybki transport – już w garażu: %s'):format(table.concat(fast, ', ')), 'success')
        Physical[order.id].fast = fast
    end

    Server.NotifyJob(order.supplier_job, ('Zamówienie %s: %d %s do odwiezienia do %s – załaduj auta na lawetę (tr2).'):format(
        payload.orderId, #payload.items, plural(#payload.items, 'pojazd', 'pojazdy', 'pojazdów'), payload.buyerLabel), 'info')
    Server.NotifyJob(order.buyer_job, ('Zamówienie %s przyjęte – pojazdy zostaną dostarczone lawetą.'):format(payload.orderId), 'info')
    return true
end

-- anulowanie zadania (odrzucenie zamówienia, ręczna dostawa z panelu, rozłączenie itd.)
function Server.CancelDelivery(id, order, why)
    local cfg = deliveryCfg()
    Physical[id] = nil
    if order then data.SetOrderDelivery(id, nil, order.buyer_job, order.supplier_job) end
    if cfg.cancelEvent then TriggerEvent(cfg.cancelEvent, 'ord-' .. id, why or '') end
end

-- ponowne wysłanie zadań dla zamówień, które czekają na dostawę (po restarcie zasobu CD)
function Server.ResendDeliveries(supplierJob, to)
    if not Server.DeliveryEnabled() then return 0 end
    if supplierJob ~= Config.VehicleShop.supplierJob then return 0 end

    local count = 0
    for _, r in ipairs(data.Orders(supplierJob).supplier) do
        if r.status == 'accepted' and r.delivery == 'physical' then
            local payload = dispatchDelivery(r, r.items or {})
            count = count + 1
            if to then TriggerClientEvent('crp_bossmenu:client:notify', to, ('Zadanie %s wznowione – %d %s do odwiezienia'):format(
                payload.orderId, #payload.items, plural(#payload.items, 'pojazd', 'pojazdy', 'pojazdów')), 'info') end
        end
    end
    return count
end

-- ── zgłoszenie oddania pojazdów (serwer-serwer, nie event klienta) ──
-- Nano CD i inne zaufane zasoby wołają to przez TriggerEvent.
local deliveryDoneLocks = {}

local function handleDeliveryDone(orderId, plates, final, byName)
    local id = tonumber(tostring(orderId or ''):match('(%d+)$') or '')
    if not id then return end

    local order = data.GetOrderRaw(id, 'vehicles')
    if not order or order.status ~= 'accepted' or order.delivery ~= 'physical' then return end

    local by = whoName(byName, 'System')
    local items = type(order.items) == 'string' and (json.decode(order.items) or {}) or (order.items or {})
    local task = Physical[id]
    if not task then
        task = { plates = {}, handed = {}, by = order.by_name, at = os.time() }
        Physical[id] = task
    end
    task.handed = task.handed or {}
    local handed = task.handed

    local provided = plates
    if type(provided) == 'string' then
        local txt = provided:gsub('^%s+', ''):gsub('%s+$', '')
        local decoded
        if txt:sub(1, 1) == '[' or txt:sub(1, 1) == '{' then
            local ok, value = pcall(json.decode, txt)
            if ok and type(value) == 'table' then decoded = value end
        end
        if decoded then provided = decoded
        elseif txt ~= '' then provided = { txt } end
    end

    local queue = {}
    for i, item in ipairs(items) do
        if not item.express and not handed[i] then queue[#queue + 1] = i end
    end
    if type(provided) ~= 'table' or #provided == 0 then
        provided = {}
        for k, i in ipairs(queue) do
            provided[k] = { index = i, plate = task.plates[i] }
        end
    end

    local pending, seen, pendingSet, pos = {}, {}, {}, 0
    for _, entry in ipairs(provided) do
        local index, requestedPlate
        if type(entry) == 'table' then
            index = tonumber(entry.index or entry[1])
            requestedPlate = tostring(entry.plate or entry[2] or '')
        else
            pos = pos + 1
            index = queue[pos]
            requestedPlate = tostring(entry or '')
        end

        if index and index == math.floor(index) and not seen[index] then
            local item = items[index]
            if item and not item.express and not handed[index] then
                local expected = tostring(task.plates[index] or '')
                local plate = expected ~= '' and expected or requestedPlate
                if plate == '' or not plate:match('^[%w ]+$') or #plate > 12 then
                    plate = data.NewPlate()
                end
                if plate then
                    seen[index] = true
                    pendingSet[index] = true
                    pending[#pending + 1] = { index = index, item = item, plate = plate }
                end
            end
        end
    end

    if #pending == 0 then
        print(('^3[crp_bossmenu]^7 dostawa %d: brak nowych, poprawnych pozycji do zapisania'):format(id))
        return
    end

    -- `final` pochodzi z zaufanego serwerowego zasobu dostawy; gdy nie zostanie
    -- podany, domykamy automatycznie tylko wtedy, gdy wszystkie pozycje są znane.
    local left = 0
    for i, item in ipairs(items) do
        if not item.express and not handed[i] and not pendingSet[i] then left = left + 1 end
    end
    local isFinal = final == nil and left == 0 or flag(final)
    local orderNo, buyerLabel = 'ord-' .. id, data.JobLabel(order.buyer_job)
    if isFinal and not data.HasSociety(order.supplier_job) then
        print(('^1[crp_bossmenu]^7 dostawa %d: brak konta firmy dostawcy; nie zapisano finalizacji'):format(id))
        Server.NotifyJob(order.supplier_job, ('Zamówienie %s czeka – konto firmy dostawcy jest niedostępne.'):format(orderNo), 'error')
        SetTimeout(1000, function() Server.ResendDeliveries(order.supplier_job) end)
        return
    end

    local names, attempted = {}, {}
    local function rollbackVehicles()
        for i = #attempted, 1, -1 do
            local entry = attempted[i]
            local ok, err = pcall(data.RemoveVehicle, order.buyer_job, entry.plate)
            if not ok or err == false then
                print(('^1[crp_bossmenu]^7 dostawa %d: nie udało się cofnąć pojazdu %s (%s)'):format(
                    id, tostring(entry.plate), tostring(err)))
            end
        end
    end

    for _, entry in ipairs(pending) do
        attempted[#attempted + 1] = entry
        local ok, err = pcall(function()
            data.AddVehicle(order.buyer_job, entry.plate, entry.item.model, entry.item.name, entry.item.category)
            data.GrantVehicle(order.buyer_job, entry.plate, entry.item.model)
        end)
        if not ok then
            rollbackVehicles()
            print(('^1[crp_bossmenu]^7 dostawa %d: rejestracja pojazdu nie powiodła się (%s)'):format(id, tostring(err)))
            return
        end
        names[#names + 1] = ('%s (%s)'):format(entry.item.name or entry.item.model, entry.plate)
    end

    if isFinal then
        local statusCall, statusChanged = pcall(function()
            return data.SetOrderStatus(id, 'supplier_job', order.supplier_job, 'accepted', 'delivered', nil,
                order.buyer_job, order.supplier_job)
        end)
        if not statusCall or not statusChanged then
            rollbackVehicles()
            print(('^3[crp_bossmenu]^7 dostawa %d: status zamówienia zmienił się przed domknięciem; pojazdy cofnięto, wypłaty brak'):format(id))
            return
        end

        local fundsCall, fundsAdded = pcall(data.AddFunds, order.supplier_job, order.total)
        if not fundsCall or not fundsAdded then
            local reopenCall, reopened = pcall(data.SetOrderStatus, id, 'supplier_job', order.supplier_job,
                'delivered', 'accepted', nil, order.buyer_job, order.supplier_job)
            if reopenCall and reopened then
                rollbackVehicles()
                print(('^1[crp_bossmenu]^7 dostawa %d: konto firmy dostawcy niedostępne; status cofnięto, pojazdy wycofano'):format(id))
                Server.NotifyJob(order.supplier_job, ('Zamówienie %s nie zostało rozliczone – sprawdź konto firmy; dostawa wróci do realizacji.'):format(orderNo), 'error')
                Server.Refresh(order.buyer_job, order.supplier_job)
                SetTimeout(1000, function() Server.ResendDeliveries(order.supplier_job) end)
            else
                for _, entry in ipairs(pending) do handed[entry.index] = entry.plate end
                print(('^1[crp_bossmenu]^7 dostawa %d: wypłata nieudana i nie udało się cofnąć statusu; pojazdy pozostawiono, wymagana ręczna kontrola'):format(id))
                Server.NotifyJob(order.supplier_job, ('Zamówienie %s wymaga ręcznego rozliczenia – sprawdź konto firmy.'):format(orderNo), 'error')
                Server.Refresh(order.buyer_job, order.supplier_job)
            end
            return
        end
    end

    for _, entry in ipairs(pending) do handed[entry.index] = entry.plate end

    data.Hist(order.supplier_job, by, { type = 'delivery', orderId = orderNo, buyer = buyerLabel,
        count = #pending, items = names, final = isFinal })
    Server.NotifyJob(order.buyer_job, ('Dostawa %s: odebrano %d %s (%s)'):format(orderNo, #pending,
        plural(#pending, 'pojazd', 'pojazdy', 'pojazdów'), table.concat(names, ', ')), 'success')
    Server.Refresh(order.buyer_job, order.supplier_job)

    if not isFinal then return end

    data.Tx(order.supplier_job, 'in', order.total, by, 'Dostawa zamówienia',
        ('%s · %s (dostawa lawetą)'):format(orderNo, buyerLabel))
    Server.NotifyJob(order.supplier_job, ('Zamówienie %s dostarczone – środki trafiły na konto firmy.'):format(orderNo), 'success')

    Physical[id] = nil
    data.SetOrderDelivery(id, nil, order.buyer_job, order.supplier_job)
    Server.Refresh(order.buyer_job, order.supplier_job)
end

AddEventHandler('crp_bossmenu:server:deliveryDone', function(orderId, plates, final, byName)
    local id = tonumber(tostring(orderId or ''):match('(%d+)$') or '')
    if not id or deliveryDoneLocks[id] then return end
    deliveryDoneLocks[id] = true
    local ok, err = pcall(handleDeliveryDone, orderId, plates, final, byName)
    deliveryDoneLocks[id] = nil
    if not ok then print(('^1[crp_bossmenu] deliveryDone:^7 %s'):format(tostring(err))) end
end)

-- zasób dostawy pyta o zadania (np. po swoim restarcie albo komendą „weź zadanie”)
AddEventHandler('crp_bossmenu:server:deliveryResend', function(supplierJob, cb)
    local src = playerSrc(source)

    -- obsługa różnych sposobów wołania (inne zasoby wołają nas jak chcą):
    --   ('centra_autos')            → konkretna firma dostawcy
    --   (callback)                  → odpowiedź liczbą wznowionych zadań
    --   ('centra_autos', callback)  → i jedno, i drugie
    --   ({ supplierJob = '...' })   → nazwa pracy w tabeli
    if type(supplierJob) == 'function' then cb, supplierJob = supplierJob, nil end
    if type(supplierJob) == 'table' then supplierJob = supplierJob.supplierJob or supplierJob.job end
    if type(supplierJob) ~= 'string' or supplierJob == '' then supplierJob = nil end
    if type(cb) ~= 'function' then cb = nil end

    if src then
        local x = ESX.GetPlayerFromId(src)
        if not x or baseJob(x.job and x.job.name) ~= Config.VehicleShop.supplierJob then
            if cb then cb(0) end
            return
        end
    elseif Config.Debug then
        -- nie jest to gracz (np. inny zasób) – tylko log, bez blokowania
        print(('[crp_bossmenu] deliveryResend z zewnątrz: source=%s (%s), job=%s'):format(
            tostring(source), type(source), tostring(supplierJob)))
    end

    local n = Server.ResendDeliveries(supplierJob or Config.VehicleShop.supplierJob, src)
    if cb then cb(n) end
    if src and n == 0 then
        TriggerClientEvent('crp_bossmenu:client:notify', src, 'Brak zamówień czekających na dostawę.', 'info')
    end
end)

-- zwolnienie miejsca w pamięci po restarcie zasobu: zadania odbudują się na żądanie (ResendDeliveries)
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Physical = {}
    if Server.DeliveryEnabled() then
        print(('^2[crp_bossmenu]^7 dostawa pojazdów: obsługuje ją zasób `%s` (zamówienia bez szybkiego transportu jadą lawetą)'):format(deliveryCfg().resource))
    end
end)


-- ═════════════════════════════════════════════════════════════
--  DYSPOZYTOR AKCJI
-- ═════════════════════════════════════════════════════════════
local NO_REFRESH = { testWebhook = true }

RegisterNetEvent('crp_bossmenu:server:req', function(reqId, action, d)
    local src = playerSrc(source)
    if not src then return end                     -- akcje panelu wykonuje gracz
    local function reply(result) TriggerClientEvent('crp_bossmenu:client:res', src, reqId, result) end

    local handler = type(action) == 'string' and Actions[action]
    if not handler then return reply(err('Nieznana akcja')) end
    if type(d) ~= 'table' then d = {} end

    local c, why = context(src)
    if not c then
        Server.ForceClose(src)
        return reply(err(why))
    end

    local ok, result = pcall(handler, c, d)
    if not ok then
        print(('^1[crp_bossmenu] błąd w akcji %s:^7 %s'):format(action, tostring(result)))
        result = err('Błąd serwera – spróbuj ponownie')
    end
    result = result or { ok = true }

    reply(result)
    if not result.ok then
        TriggerClientEvent('crp_bossmenu:client:notify', src, result.error or 'Nie udało się wykonać akcji', 'error')
    end
    if not NO_REFRESH[action] then Server.Refresh(c.job) end
end)

-- zamknięcie panelu: sesja + blokada panelu (krzesło zwalnia dopiero wstanie z niego)
function Server.Close(src)
    local s = Sessions[src]
    Sessions[src] = nil
    if s then freePanel(src, s.job) end
end

RegisterNetEvent('crp_bossmenu:server:open', function()
    local src = playerSrc(source); if src then Server.Open(src) end
end)
RegisterNetEvent('crp_bossmenu:server:close', function()
    local src = playerSrc(source); if src then Server.Close(src) end
end)

AddEventHandler('playerDropped', function()
    releaseLocks(source)
    Sessions[source] = nil
    lastOpen[source] = nil
end)

exports('Open', function(src) Server.Open(src) end)
Server.Sessions = Sessions


-- ═════════════════════════════════════════════════════════════
--  TŁO: godziny pracy, odświeżanie, lista pracowników
-- ═════════════════════════════════════════════════════════════

-- Nalicza 60 s graczom na służbie (w pamięci) i co Config.Cache.saveSeconds zrzuca wszystko do bazy.
CreateThread(function()
    local saveEvery = math.max(60, Config.Cache.saveSeconds)
    local sinceSave = 0

    while true do
        Wait(60000)
        sinceSave = sinceSave + 60

        for _, id in ipairs(GetPlayers()) do
            local x = ESX.GetPlayerFromId(tonumber(id))
            if x and Config.Jobs[x.job.name] and Config.GetDutyStatus(x.source, x) == 'duty' then
                data.AddSeconds(x.job.name, x.identifier, 60)
            end
        end

        if sinceSave >= saveEvery then
            sinceSave = 0
            data.Flush()
        end
    end
end)

-- Sprzątanie blokad: rozłączenia, wyjście z krzesła „po cichu” (crash klienta/teleport), zawieszone sesje.
-- Bez tego po crashu gracza krzesło zostałoby zajęte na zawsze.
if lockEnabled() then
    CreateThread(function()
        while true do
            Wait(15000)

            local now = os.time()
            local maxSeat = (Config.Panel and Config.Panel.seatTimeout) or 0
            local maxDist = (Config.Panel and Config.Panel.releaseDistance) or 10.0

            for key, seat in pairs(Seats) do
                local drop = not ESX.GetPlayerFromId(seat.src)
                if not drop and maxSeat and maxSeat > 0 and (now - seat.since) > maxSeat then drop = true end

                if not drop then
                    local loc = Config.Locations[key]
                    local ok, pos = pcall(function() return GetEntityCoords(GetPlayerPed(seat.src)) end)
                    if ok and loc and loc.chaircoords and type(pos) == 'table' then
                        -- (0,0,0) = gracz jeszcze się wczytuje – wtedy blokady nie ruszamy
                        if (pos.x ~= 0.0 or pos.y ~= 0.0)
                            and #(pos - vec3(loc.chaircoords.x, loc.chaircoords.y, loc.chaircoords.z)) > maxDist then
                            drop = true
                        end
                    end
                end

                if drop then
                    Seats[key] = nil
                    if SeatBy[seat.src] == key then SeatBy[seat.src] = nil end
                end
            end

            for job, h in pairs(Panels) do
                if not ESX.GetPlayerFromId(h.src) or not Sessions[h.src] then
                    Panels[job] = nil
                    broadcastPanel(job)
                end
            end
        end
    end)
end

-- Odświeżanie otwartych paneli (dane z pamięci, bez zapytań do bazy)
if Config.Cache.refreshSeconds > 0 then
    CreateThread(function()
        while true do
            Wait(Config.Cache.refreshSeconds * 1000)
            if next(Sessions) then Server.RefreshAll() end
        end
    end)
end

-- Lista pracowników odświeżana co jakiś czas, gdy panel jest otwarty
if Config.Cache.rosterSeconds > 0 then
    CreateThread(function()
        while true do
            Wait(Config.Cache.rosterSeconds * 1000)
            for _, s in pairs(Sessions) do
                data.RefreshRoster(s.job)
                -- listy innych prac (Config.ViewJobs) też muszą się odświeżać
                for _, def in ipairs(data.ViewJobList(s.job)) do data.RefreshRoster(def.job) end
            end
        end
    end)
end

-- Ktoś zmienił pracę: lista pracowników do odświeżenia, panel zamknięty gdy stracił dostęp
AddEventHandler('esx:setJob', function(src, job, lastJob)
    job, lastJob = baseJob(job), baseJob(lastJob)
    -- zmiana pracy wpływa też na listy, które podglądają inne prace (Config.ViewJobs)
    for _, name in ipairs({ job, lastJob }) do
        if name and Config.Jobs[name] then
            data.RefreshRoster(name)
            for _, def in ipairs(data.ViewJobList(name)) do data.RefreshRoster(def.job) end
        end
    end

    if Sessions[src] and not context(src) then Server.ForceClose(src) end
end)

-- Zrzut naliczonych godzin przy wyłączaniu zasobu
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    data.Flush()
end)

MySQL.ready(function()
    local ok, e = pcall(data.Install)
    if not ok then print(('^1[crp_bossmenu]^7 nie udało się przygotować tabel: %s'):format(tostring(e))) end
end)

-- Zgodność ze starym wywołaniem (np. Twoja komenda testowa)
lib.callback.register('crp_jobcore:bossmenu:server:getBossmenuData', function(src)
    local x = ESX.GetPlayerFromId(src)
    if not x or not Server.CanManage(x) then return {} end

    local me = data.FindByIdentifier(x.identifier)
    if not me then return {} end

    local ok, payload = pcall(data.Build, {
        job = baseJob(x.job.name) or x.job.name, identifier = x.identifier, grade = x.job.grade,
        ssn = me.ssn or x.identifier, firstname = me.firstname or '', lastname = me.lastname or ''
    })
    return ok and payload or {}
end)

_G.crp_bossmenu_s_main = { Server = Server, Actions = Actions }
return _G.crp_bossmenu_s_main
