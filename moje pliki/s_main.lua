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

-- zabezpieczenie przed podwójnym załadowaniem (np. fxmanifest + require)
if _G.crp_bossmenu_s_main then return {} end
_G.crp_bossmenu_s_main = true

local Config = require('resources.bossmenu.d_bossmenu')
local data   = require('resources.bossmenu.s_data')
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

local function fullName(row)
    return ('%s %s'):format(row.firstname or '', row.lastname or '')
end


-- ═════════════════════════════════════════════════════════════
--  SESJE / UPRAWNIENIA
-- ═════════════════════════════════════════════════════════════
function Server.CanManage(xPlayer)
    local job = xPlayer and xPlayer.job and xPlayer.job.name
    if not job or not Config.Jobs[job] then return false end
    return xPlayer.job.grade >= data.MinGrade(job)
end

-- kontekst gracza albo nil, powód
local function context(src)
    local s = Sessions[src]
    if not s then return nil, 'Panel nie jest otwarty' end

    local x = ESX.GetPlayerFromId(src)
    if not x or x.job.name ~= s.job or not Server.CanManage(x) then
        return nil, 'Straciłeś dostęp do panelu'
    end

    s.grade = x.job.grade
    return {
        src = src, xPlayer = x, identifier = s.identifier, job = s.job, grade = s.grade,
        ssn = s.ssn, name = ('%s %s'):format(s.firstname, s.lastname)
    }
end

function Server.ForceClose(src)
    if Sessions[src] then
        Sessions[src] = nil
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
        if loc.job == job and #(pos - vec3(loc.mcoords.x, loc.mcoords.y, loc.mcoords.z)) <= (loc.radius or 2.0) + 2.0 then
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
    if not x or not Server.CanManage(x) then
        TriggerClientEvent('crp_bossmenu:client:forceClose', src)
        return TriggerClientEvent('crp_bossmenu:client:notify', src, 'Nie masz dostępu do panelu zarządzania.', 'error')
    end
    if not nearLocation(src, x.job.name) then
        TriggerClientEvent('crp_bossmenu:client:forceClose', src)
        return TriggerClientEvent('crp_bossmenu:client:notify', src, 'Musisz być przy panelu zarządzania.', 'error')
    end

    local me = data.FindByIdentifier(x.identifier)
    if not me then return end

    Sessions[src] = {
        job = x.job.name, identifier = x.identifier,
        ssn = me.ssn or x.identifier, firstname = me.firstname or '', lastname = me.lastname or '', grade = x.job.grade
    }

    local ok, payload = pcall(data.Build, Sessions[src])
    if not ok then
        Sessions[src] = nil
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
    for i, it in ipairs(items) do parts[i] = ('%s ×%d'):format(it.name or it.model, it.qty or 1) end
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
    data.SetLicense(c.job, t.identifier, def.id, d.value == true)
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
    return { ok = true }
end

H.withdraw = function(c, d)
    local amount = int(d.amount, 1, 100000000); if not amount then return err('Nieprawidłowa kwota') end
    local reason = reasonOf(d.reason); if not reason then return err('Podaj powód wypłaty (min. 5 znaków)') end
    if not data.RemoveFunds(c.job, amount) then return err('Brak środków na koncie firmy') end

    c.xPlayer.addAccountMoney(Config.PlayerAccount, amount)
    data.Tx(c.job, 'out', amount, c.name, 'Wypłata', reason)
    return { ok = true }
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
    for _, v in ipairs(vs.catalog) do catalog[v.model] = v end

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

    local from = action == 'deliver' and 'accepted' or 'pending'
    local to   = ({ accept = 'accepted', reject = 'rejected', deliver = 'delivered' })[action]
    if not data.SetOrderStatus(id, 'supplier_job', c.job, from, to, reason, order.buyer_job, c.job) then
        return err('Status zamówienia już się zmienił')
    end

    local items = json.decode(order.items) or {}
    local buyerLabel = data.JobLabel(order.buyer_job)
    local names = {}
    for i, it in ipairs(items) do names[i] = it.name or it.model end
    local orderNo = (kind == 'vehicles' and 'ord-' or 'zam-') .. id

    if action == 'reject' then
        data.AddFunds(order.buyer_job, order.total)
        data.Tx(order.buyer_job, 'in', order.total, 'System', 'Zwrot za zamówienie', ('%s (odrzucone): %s'):format(orderNo, table.concat(names, ', ')))
        Server.NotifyJob(order.buyer_job, ('Zamówienie %s zostało odrzucone – środki wróciły na konto firmy'):format(orderNo), 'warn')

    elseif action == 'accept' then
        Server.NotifyJob(order.buyer_job, ('Zamówienie %s zostało przyjęte do realizacji'):format(orderNo), 'success')

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

    local items, total = {}, 0
    for _, picked in ipairs(d.items) do
        local product = type(picked) == 'table' and catalog[tonumber(picked.id)]
        local qty = type(picked) == 'table' and int(picked.qty, 1, vs.maxQty)
        if not product or not product.active or not data.HasAccess(product, c.job) or not qty then
            return err('Nieprawidłowa pozycja zamówienia')
        end

        items[#items + 1] = { id = product.id, name = product.name, price = product.price, qty = qty }
        total = total + product.price * qty
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
        units = (function() local n = 0 for _, it in ipairs(items) do n = n + it.qty end return n end)(), total = total, items = items })

    Server.NotifyJob(supplierJob, ('Nowe zamówienie towarów od %s (zam-%d)'):format(data.JobLabel(c.job), id), 'info')
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

    local product = { name = name, category = category, desc = desc, price = price, active = d.active ~= false, access = access }
    id = data.SaveProduct(c.job, previous and id or nil, product)

    if not previous then
        data.Hist(c.job, c.name, { type = 'offerChange', action = 'add', name = name, to = price })
    else
        local entry
        if previous.price ~= price then entry = { action = 'price', from = previous.price, to = price }
        elseif (previous.active == 1) ~= product.active then entry = { action = product.active and 'show' or 'hide' }
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
--  DYSPOZYTOR AKCJI
-- ═════════════════════════════════════════════════════════════
local NO_REFRESH = { testWebhook = true }

RegisterNetEvent('crp_bossmenu:server:req', function(reqId, action, d)
    local src = source
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

RegisterNetEvent('crp_bossmenu:server:open', function() Server.Open(source) end)
RegisterNetEvent('crp_bossmenu:server:close', function() Sessions[source] = nil end)

AddEventHandler('playerDropped', function()
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
            for _, s in pairs(Sessions) do data.RefreshRoster(s.job) end
        end
    end)
end

-- Ktoś zmienił pracę: lista pracowników do odświeżenia, panel zamknięty gdy stracił dostęp
AddEventHandler('esx:setJob', function(src, job, lastJob)
    if job and Config.Jobs[job] then data.RefreshRoster(job) end
    if lastJob and Config.Jobs[lastJob] then data.RefreshRoster(lastJob) end

    if Sessions[src] and not context(src) then Server.ForceClose(src) end
end)

-- Zrzut naliczonych godzin przy wyłączaniu zasobu
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    data.Flush()
end)

MySQL.ready(function() data.Install() end)

-- Zgodność ze starym wywołaniem (np. Twoja komenda testowa)
lib.callback.register('crp_jobcore:bossmenu:server:getBossmenuData', function(src)
    local x = ESX.GetPlayerFromId(src)
    if not x or not Server.CanManage(x) then return {} end

    local me = data.FindByIdentifier(x.identifier)
    if not me then return {} end

    local ok, payload = pcall(data.Build, {
        job = x.job.name, identifier = x.identifier, grade = x.job.grade,
        ssn = me.ssn or x.identifier, firstname = me.firstname or '', lastname = me.lastname or ''
    })
    return ok and payload or {}
end)

return { Server = Server, Actions = Actions }
