-- ═════════════════════════════════════════════════════════════
--  HANDLERY AKCJI Z UI
--  Każdy handler dostaje (c, d):
--    c – kontekst gracza { src, xPlayer, identifier, job, grade, ssn, name }  (zweryfikowany po stronie serwera)
--    d – dane z NUI (NIE UFAJ im – wszystko jest walidowane)
--  i zwraca { ok = true, ... } albo { ok = false, error = '...' }.
-- ═════════════════════════════════════════════════════════════
Handlers = {}
Server = Server or {}
local H = Handlers
local err = U.err

-- ───────── pomocnicze ─────────
local function jobCfg(c) return Config.Jobs[c.job] end
local function feature(c, key) return jobCfg(c).features and jobCfg(c).features[key] == true end

local function gradeName(job, grade)
    for _, g in ipairs(Bridge.Grades(job)) do if g.id == grade then return g.name end end
    return '—'
end

-- pracownik tej samej firmy po SSN
local function target(c, ssn)
    ssn = U.str(ssn, 40)
    if not ssn or ssn == '' then return nil, 'Nieprawidłowy SSN' end
    local t = Bridge.FindBySsn(ssn)
    if not t then return nil, 'Nie znaleziono pracownika' end
    local x = Bridge.GetPlayerByIdentifier(t.identifier)
    local job, grade = t.job, t.grade
    if x then job, grade = x.job.name, x.job.grade end
    if job ~= c.job then return nil, 'Ta osoba nie pracuje w Twojej firmie' end
    t.grade, t.src = grade, x and x.source or nil
    t.name = Data.FullName(t)
    return t
end

-- zmiany stopnia / zwolnienia: nie na szefie i nie na sobie
local function manageable(c, t)
    if t.identifier == c.identifier then return 'Nie możesz wykonać tej akcji na sobie' end
    if t.grade >= Bridge.BossGrade(c.job) then return 'Nie można wykonać tej akcji na szefie' end
end

local function reasonOf(v)
    local r = U.str(v, 300)
    if not r or U.len(r) < 5 then return nil end
    return r
end

local HOOK_PATTERN = '^https://[%w%.]*discord%.com/api/webhooks/%d+/[%w_%-]+$'
local HOOK_PATTERN2 = '^https://[%w%.]*discordapp%.com/api/webhooks/%d+/[%w_%-]+$'
local HOOK_KEYS = { 'plusminus', 'commend', 'promo' }
local function validHook(u) return u == '' or (#u <= 220 and (u:match(HOOK_PATTERN) or u:match(HOOK_PATTERN2))) and true or false end

local function postHook(url, title, desc, color, wait)
    local body = json.encode({ username = Config.Discord.botName, embeds = { {
        title = title, description = desc, color = color, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } } })
    local p = promise.new()
    PerformHttpRequest(url, function(status) p:resolve(status) end, 'POST', body, { ['Content-Type'] = 'application/json' })
    if wait then return Citizen.Await(p) end
end

local function hook(job, key, title, desc, color)
    local url = Data.Hooks(job)[key]
    if url and url ~= '' then postHook(url, title, ('%s\n\n**Firma:** %s'):format(desc, Bridge.JobLabel(job)), color) end
end

local function upsertMember(identifier, job) MySQL.insert.await('INSERT IGNORE INTO bossmenu_members (identifier, job) VALUES (?, ?)', { identifier, job }) end

local function hist(c, entry) Data.Hist(c.job, c.name, entry) end
local function ordNo(n) return '#' .. n end

-- ═════════════ PRACOWNICY ═════════════

H.setGrade = function(c, d)
    local reason = reasonOf(d.reason); if not reason then return err('Podaj powód (min. 5 znaków)') end
    local t, e = target(c, d.ssn); if not t then return err(e) end
    local m = manageable(c, t); if m then return err(m) end
    local grade, boss = U.int(d.grade, 0), Bridge.BossGrade(c.job)
    if not grade or not (ESX.Jobs[c.job] and ESX.Jobs[c.job].grades[tostring(grade)]) then return err('Nieprawidłowy stopień') end
    if grade >= boss and c.grade < boss then return err('Stopień szefa może nadać tylko szef') end
    if grade == t.grade then return err('Pracownik ma już ten stopień') end
    Bridge.SetJob(t.identifier, c.job, grade)
    MySQL.insert.await('INSERT INTO bossmenu_promotions (identifier, job, from_grade, to_grade, by_name, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { t.identifier, c.job, t.grade, grade, c.name, reason })
    hook(c.job, 'promo', grade > t.grade and 'Awans' or 'Degradacja',
        ('**Pracownik:** %s\n**Stopień:** %s → %s\n**Powód:** %s\n**Wykonał:** %s'):format(t.name, gradeName(c.job, t.grade), gradeName(c.job, grade), reason, c.name), Config.Discord.colors.promo)
    return { ok = true }
end

H.hire = function(c, d)
    local ssn = U.str(d.ssn, 40); if not ssn or ssn == '' then return err('Podaj SSN gracza') end
    local t = Bridge.FindBySsn(ssn); if not t then return err('Nie znaleziono gracza o tym SSN') end
    local x = Bridge.GetPlayerByIdentifier(t.identifier)
    local job = x and x.job.name or t.job
    if job == c.job then return err('Ta osoba już u Ciebie pracuje') end
    if Config.HireOnlyUnemployed and job ~= Config.Unemployed.job then return err('Ten gracz pracuje w innej firmie') end
    local grade, boss = U.int(d.grade, 0), Bridge.BossGrade(c.job)
    if not grade or grade >= boss or not ESX.Jobs[c.job].grades[tostring(grade)] then return err('Nieprawidłowy stopień startowy') end
    Bridge.SetJob(t.identifier, c.job, grade)
    MySQL.insert.await([[INSERT INTO bossmenu_members (identifier, job) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE hired_at = NOW(), badge = NULL, seconds = 0, last_duty = NULL, note = NULL, note_by = NULL, note_at = NULL]], { t.identifier, c.job })
    if x then Bridge.Notify(x.source, ('Zostałeś zatrudniony w firmie %s.'):format(Bridge.JobLabel(c.job)), 'success') end
    return { ok = true, employee = {
        firstname = t.firstname, lastname = t.lastname, phonenumber = t.phone or '',
        status = x and Config.GetDutyStatus(x.source, x) or 'off'
    } }
end

H.fire = function(c, d)
    local t, e = target(c, d.ssn); if not t then return err(e) end
    local m = manageable(c, t); if m then return err(m) end
    local gname = gradeName(c.job, t.grade)
    local vehs = MySQL.query.await('SELECT plate FROM bossmenu_vehicles WHERE job = ? AND assigned_identifier = ?', { c.job, t.identifier })
    for _, v in ipairs(vehs) do
        MySQL.update.await('UPDATE bossmenu_vehicles SET assigned_identifier = NULL, assigned_at = NULL WHERE plate = ?', { v.plate })
        Bridge.VehicleOwner(c.job, v.plate, nil)
    end
    Bridge.SetJob(t.identifier, Config.Unemployed.job, Config.Unemployed.grade)
    MySQL.update.await('DELETE FROM bossmenu_members WHERE identifier = ? AND job = ?', { t.identifier, c.job })
    MySQL.update.await('DELETE FROM bossmenu_licenses WHERE identifier = ? AND job = ?', { t.identifier, c.job })
    hist(c, { type = 'fire', ssn = t.ssn, name = t.name, gradeName = gname, vehicles = #vehs })
    if t.src then
        Bridge.Notify(t.src, ('Zostałeś zwolniony z firmy %s.'):format(Bridge.JobLabel(c.job)), 'error')
        Server.ForceClose(t.src)
    end
    return { ok = true }
end

H.setBadge = function(c, d)
    if not feature(c, 'badges') then return err('Odznaki są wyłączone') end
    local t, e = target(c, d.ssn); if not t then return err(e) end
    local badge
    if d.badge ~= nil and d.badge ~= '' and d.badge ~= 0 then
        badge = U.int(d.badge, 1, 99999); if not badge then return err('Numer odznaki: 1–99999') end
        if MySQL.scalar.await('SELECT 1 FROM bossmenu_members WHERE job = ? AND badge = ? AND identifier <> ? LIMIT 1', { c.job, badge, t.identifier }) then
            return err('Ten numer odznaki jest już zajęty')
        end
    end
    upsertMember(t.identifier, c.job)
    MySQL.update.await('UPDATE bossmenu_members SET badge = ? WHERE identifier = ? AND job = ?', { badge, t.identifier, c.job })
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
    local k = KINDS[d.kind]; if not k then return err('Nieprawidłowy rodzaj wpisu') end
    local reason = reasonOf(d.reason); if not reason then return err('Podaj powód (min. 5 znaków)') end
    local t, e = target(c, d.ssn); if not t then return err(e) end
    MySQL.insert.await('INSERT INTO bossmenu_records (identifier, job, kind, reason, by_name) VALUES (?, ?, ?, ?, ?)', { t.identifier, c.job, d.kind, reason, c.name })
    hook(c.job, k.key, k.title, ('**Pracownik:** %s\n**Powód:** %s\n**Wystawił:** %s'):format(t.name, reason, c.name), Config.Discord.colors[d.kind])
    return { ok = true }
end

H.voidRecord = function(c, d)
    local id, reason = U.int(d.id, 1), reasonOf(d.reason)
    if not id then return err('Nie znaleziono wpisu') end
    if not reason then return err('Podaj powód (min. 5 znaków)') end
    local aff = MySQL.update.await('UPDATE bossmenu_records SET void_by = ?, void_at = NOW(), void_reason = ? WHERE id = ? AND job = ? AND void_by IS NULL', { c.name, reason, id, c.job })
    if aff ~= 1 then return err('Wpis nie istnieje albo jest już unieważniony') end
    return { ok = true }
end

H.setLicense = function(c, d)
    if not feature(c, 'licenses') then return err('Licencje są wyłączone') end
    local def
    for _, l in ipairs(jobCfg(c).licenses or {}) do if l.id == d.license then def = l end end
    if not def then return err('Nieznana licencja') end
    local t, e = target(c, d.ssn); if not t then return err(e) end
    if d.value == true then
        MySQL.insert.await('INSERT IGNORE INTO bossmenu_licenses (identifier, job, license) VALUES (?, ?, ?)', { t.identifier, c.job, def.id })
    else
        MySQL.update.await('DELETE FROM bossmenu_licenses WHERE identifier = ? AND job = ? AND license = ?', { t.identifier, c.job, def.id })
    end
    return { ok = true }
end

H.resetHours = function(c, d)
    local t, e = target(c, d.ssn); if not t then return err(e) end
    MySQL.update.await('UPDATE bossmenu_members SET seconds = 0 WHERE identifier = ? AND job = ?', { t.identifier, c.job })
    return { ok = true }
end

H.resetAllHours = function(c)
    local emps, total = Data.Employees(c.job, Config.GetDutyStatus), 0
    for _, e in ipairs(emps) do total = total + (e.hoursWeek or 0) end
    MySQL.update.await('UPDATE bossmenu_members SET seconds = 0 WHERE job = ?', { c.job })
    hist(c, { type = 'resetHours', count = #emps, total = math.floor(total * 10 + 0.5) / 10 })
    return { ok = true }
end

-- ═════════════ FRAKCJA ═════════════

H.setSalary = function(c, d)
    local grade = U.int(d.grade, 0)
    local g
    for _, x in ipairs(Bridge.Grades(c.job)) do if x.id == grade then g = x end end
    if not g then return err('Nieprawidłowy stopień') end
    local max = jobCfg(c).salaryMax or 10000
    local salary = U.int(d.salary, 0, max); if not salary then return err(('Stawka: 0–%d'):format(max)) end
    if salary == g.salary then return { ok = true } end
    Bridge.SetSalary(c.job, grade, salary)
    hist(c, { type = 'salary', grade = grade, gradeName = g.name, from = g.salary, to = salary })
    return { ok = true }
end

H.setWebhooks = function(c, d)
    local prev, new = Data.Hooks(c.job), {}
    for _, k in ipairs(HOOK_KEYS) do
        local v = U.str(d[k] or '', 220); if v == nil or not validHook(v) then return err('Nieprawidłowy link webhooka') end
        new[k] = v
    end
    MySQL.insert.await('INSERT INTO bossmenu_settings (job, webhooks) VALUES (?, ?) ON DUPLICATE KEY UPDATE webhooks = VALUES(webhooks)', { c.job, json.encode(new) })
    for i = #HOOK_KEYS, 1, -1 do   -- osobny wpis na każdy webhook; kolejność jak w UI
        local k = HOOK_KEYS[i]
        if prev[k] ~= new[k] then
            hist(c, { type = 'webhook', key = k, action = new[k] == '' and 'removed' or (prev[k] ~= '' and 'changed' or 'set') })
        end
    end
    return { ok = true }
end

H.testWebhook = function(c, d)
    local url = Data.Hooks(c.job)[tostring(d.key)]
    if not url then return err('Nieznany webhook') end
    if url == '' then return err('Najpierw zapisz link webhooka') end
    local st = postHook(url, 'Test webhooka', ('Wiadomość testowa wysłana przez **%s**.'):format(c.name), Config.Discord.colors.test, true)
    if st and st >= 200 and st < 300 then return { ok = true } end
    return err(('Discord odrzucił żądanie (kod %s)'):format(tostring(st)))
end

H.deposit = function(c, d)
    local amount = U.int(d.amount, 1, 100000000); if not amount then return err('Nieprawidłowa kwota') end
    if Bridge.PlayerMoney(c.xPlayer) < amount then return err('Nie masz tyle pieniędzy') end
    Bridge.PlayerRemove(c.xPlayer, amount)
    if not Bridge.AddFunds(c.job, amount) then Bridge.PlayerAdd(c.xPlayer, amount); return err('Konto firmy jest niedostępne') end
    Data.Tx(c.job, 'in', amount, c.name, 'Wpłata', nil)
    return { ok = true }
end

H.withdraw = function(c, d)
    local amount = U.int(d.amount, 1, 100000000); if not amount then return err('Nieprawidłowa kwota') end
    local reason = reasonOf(d.reason); if not reason then return err('Podaj powód wypłaty (min. 5 znaków)') end
    if not Bridge.RemoveFunds(c.job, amount) then return err('Brak środków na koncie firmy') end
    Bridge.PlayerAdd(c.xPlayer, amount)
    Data.Tx(c.job, 'out', amount, c.name, 'Wypłata', reason)
    return { ok = true }
end

H.setNote = function(c, d)
    local t, e = target(c, d.ssn); if not t then return err(e) end
    local html = U.sanitizeHtml(d.html)
    if #html > 30000 then return err('Notatka jest za długa') end
    local plain = html:gsub('<[^>]*>', ''):gsub('&nbsp;', ' '):gsub('%s+', '')
    upsertMember(t.identifier, c.job)
    if plain == '' then
        MySQL.update.await('UPDATE bossmenu_members SET note = NULL, note_by = NULL, note_at = NULL WHERE identifier = ? AND job = ?', { t.identifier, c.job })
    else
        MySQL.update.await('UPDATE bossmenu_members SET note = ?, note_by = ?, note_at = NOW() WHERE identifier = ? AND job = ?', { html, c.name, t.identifier, c.job })
    end
    return { ok = true }
end

-- ═════════════ GARAŻ ═════════════

H.assignVehicle = function(c, d)
    local plate = U.str(d.plate, 12)
    local v = plate and MySQL.single.await('SELECT plate, name, assigned_identifier FROM bossmenu_vehicles WHERE plate = ? AND job = ?', { plate, c.job })
    if not v then return err('Nie znaleziono pojazdu') end
    local t, e = target(c, d.ssn); if not t then return err(e) end
    if v.assigned_identifier == t.identifier then return err('Pojazd jest już przydzielony temu pracownikowi') end
    local from = ''
    if v.assigned_identifier then
        local p = Bridge.FindByIdentifier(v.assigned_identifier)
        from = p and Data.FullName(p) or ''
    end
    MySQL.update.await('UPDATE bossmenu_vehicles SET assigned_identifier = ?, assigned_at = NOW() WHERE plate = ?', { t.identifier, plate })
    Bridge.VehicleOwner(c.job, plate, t.identifier)
    hist(c, { type = 'vehAssign', plate = plate, vehicle = v.name, ssn = t.ssn, name = t.name, from = from })
    if t.src then Bridge.Notify(t.src, ('Przydzielono Ci pojazd: %s (%s)'):format(v.name, plate), 'success') end
    return { ok = true }
end

H.revokeVehicle = function(c, d)
    local plate = U.str(d.plate, 12)
    local v = plate and MySQL.single.await('SELECT plate, name, assigned_identifier FROM bossmenu_vehicles WHERE plate = ? AND job = ?', { plate, c.job })
    if not v then return err('Nie znaleziono pojazdu') end
    if not v.assigned_identifier then return err('Pojazd nie jest przydzielony') end
    local p = Bridge.FindByIdentifier(v.assigned_identifier)
    MySQL.update.await('UPDATE bossmenu_vehicles SET assigned_identifier = NULL, assigned_at = NULL WHERE plate = ?', { plate })
    Bridge.VehicleOwner(c.job, plate, nil)
    hist(c, { type = 'vehRevoke', plate = plate, vehicle = v.name, ssn = p and p.ssn or '', name = p and Data.FullName(p) or '—' })
    return { ok = true }
end

H.orderVehicles = function(c, d)
    local vs = Config.VehicleShop
    if c.job == vs.supplierJob then return err('Ta firma sama jest dostawcą pojazdów') end
    if type(d.items) ~= 'table' or #d.items < 1 or #d.items > vs.cartMax then return err('Nieprawidłowa liczba pojazdów') end
    local byModel = {}
    for _, v in ipairs(vs.catalog) do byModel[v.model] = v end
    local items, names, total, nExp = {}, {}, 0, 0
    for _, it in ipairs(d.items) do
        local cat = type(it) == 'table' and byModel[it.model]
        if not cat then return err('Nie ma takiego pojazdu w katalogu') end
        local express = it.express == true
        local fee = express and (cat.expressFee or vs.expressFee) or 0
        items[#items + 1] = { model = cat.model, name = cat.name, category = cat.category, price = cat.price, express = express, fee = fee }
        names[#names + 1] = cat.name
        total = total + cat.price + fee
        if express then nExp = nExp + 1 end
    end
    if not Bridge.RemoveFunds(c.job, total) then return err('Brak środków na koncie firmy') end
    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO bossmenu_orders (kind, buyer_job, supplier_job, items, total, by_name) VALUES (?, ?, ?, ?, ?, ?)',
        { 'vehicles', c.job, vs.supplierJob, json.encode(items), total, c.name })
    if not ok or not id then Bridge.AddFunds(c.job, total); return err('Nie udało się złożyć zamówienia') end
    local n = #items
    Data.Tx(c.job, 'out', total, c.name, 'Zamówienie pojazdów',
        ('%d %s%s: %s'):format(n, U.plural(n, 'pojazd', 'pojazdy', 'pojazdów'), nExp > 0 and (' (w tym szybki transport: %d)'):format(nExp) or '', table.concat(names, ', ')))
    local hn = {}
    for i, it in ipairs(items) do hn[i] = it.name .. (it.express and ' ⚡' or '') end
    hist(c, { type = 'order', orderId = 'ord-' .. id, count = n, total = total, express = nExp, items = hn })
    Server.NotifyJob(vs.supplierJob, ('Nowe zamówienie pojazdów od %s (%s)'):format(Bridge.JobLabel(c.job), ordNo(id)), 'info')
    Server.Refresh(vs.supplierJob)
    return { ok = true, funds = Bridge.GetFunds(c.job), order = { id = 'ord-' .. id, items = items, total = total, status = 'pending', by = c.name } }
end

-- ═════════════ ZAMÓWIENIA TOWARÓW ═════════════

local function summary(items)
    local t = {}
    for i, it in ipairs(items) do t[i] = (it.qty or 1) > 1 and ('%s ×%d'):format(it.name, it.qty) or it.name end
    return table.concat(t, ', ')
end

H.orderGoods = function(c, d)
    local G = Config.Goods
    local sj = U.str(d.supplier, 50)
    if not sj or sj == c.job or not (Config.Jobs[sj] and Config.Jobs[sj].supplier) then return err('Nie znaleziono dostawcy') end
    if type(d.items) ~= 'table' or #d.items < 1 or #d.items > G.maxLines then return err('Nieprawidłowa liczba pozycji') end
    local note = d.note and U.str(tostring(d.note), 200) or nil
    local items, seen, total, units = {}, {}, 0, 0
    for _, it in ipairs(d.items) do
        local id, qty = type(it) == 'table' and U.int(it.id, 1), type(it) == 'table' and U.int(it.qty, 1, G.maxQty)
        if not id or seen[id] then return err('Nieprawidłowa pozycja zamówienia') end
        if not qty then return err('Nieprawidłowa ilość') end
        seen[id] = true
        local p = MySQL.single.await('SELECT id, name, price, active, access FROM bossmenu_products WHERE id = ? AND job = ?', { id, sj })
        if not p or p.active ~= 1 or not Data.HasAccess(p.access and json.decode(p.access) or nil, c.job) then return err('Produkt nie jest już dostępny w ofercie') end
        items[#items + 1] = { id = p.id, name = p.name, price = p.price, qty = qty }
        total, units = total + p.price * qty, units + qty
    end
    if not Bridge.RemoveFunds(c.job, total) then return err('Brak środków na koncie firmy') end
    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO bossmenu_orders (kind, buyer_job, supplier_job, items, total, note, by_name) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { 'goods', c.job, sj, json.encode(items), total, note ~= '' and note or nil, c.name })
    if not ok or not id then Bridge.AddFunds(c.job, total); return err('Nie udało się złożyć zamówienia') end
    local label, hn = Bridge.JobLabel(sj), {}
    for i, it in ipairs(items) do hn[i] = it.qty > 1 and ('%s ×%d'):format(it.name, it.qty) or it.name end
    Data.Tx(c.job, 'out', total, c.name, 'Zamówienie towarów', ('%s: %s'):format(label, summary(items)))
    hist(c, { type = 'goodsOrder', orderId = 'zam-' .. id, supplier = label, lines = #items, units = units, total = total, items = hn })
    Server.NotifyJob(sj, ('Nowe zamówienie towarów od %s (%s)'):format(Bridge.JobLabel(c.job), ordNo(id)), 'info')
    Server.Refresh(sj)
    return { ok = true, funds = Bridge.GetFunds(c.job), order = { id = 'zam-' .. id, items = items, total = total, status = 'pending', by = c.name,
        supplier = { job = sj, label = label }, buyer = { job = c.job, label = Bridge.JobLabel(c.job) } } }
end

local function parseOrderId(v)
    local prefix, n = tostring(v or ''):match('^(%a+)%-(%d+)$')
    n = tonumber(n)
    if not n or (prefix ~= 'ord' and prefix ~= 'zam') then return nil end
    return n, prefix == 'ord' and 'vehicles' or 'goods'
end

H.cancelOrder = function(c, d)
    local n, kind = parseOrderId(d.id); if not n then return err('Nie znaleziono zamówienia') end
    local o = MySQL.single.await('SELECT id, kind, items, total, supplier_job FROM bossmenu_orders WHERE id = ? AND buyer_job = ? AND kind = ?', { n, c.job, kind })
    if not o then return err('Nie znaleziono zamówienia') end
    local aff = MySQL.update.await("UPDATE bossmenu_orders SET status = 'cancelled' WHERE id = ? AND buyer_job = ? AND status = 'pending'", { n, c.job })
    if aff ~= 1 then return err('Zamówienie nie może już zostać anulowane') end
    Bridge.AddFunds(c.job, o.total)
    local items = json.decode(o.items) or {}
    if kind == 'vehicles' then
        local names = {}
        for i, it in ipairs(items) do names[i] = it.name end
        Data.Tx(c.job, 'in', o.total, c.name, 'Zwrot za zamówienie', ('%s: %s'):format(ordNo(n), table.concat(names, ', ')))
        hist(c, { type = 'orderCancel', orderId = 'ord-' .. n, count = #items, total = o.total })
    else
        Data.Tx(c.job, 'in', o.total, c.name, 'Zwrot za zamówienie', ('%s: %s'):format(ordNo(n), summary(items)))
        hist(c, { type = 'goodsCancel', orderId = 'zam-' .. n, supplier = Bridge.JobLabel(o.supplier_job), total = o.total })
    end
    Server.Refresh(o.supplier_job)
    return { ok = true, funds = Bridge.GetFunds(c.job) }
end

H.supplierOrder = function(c, d)
    local n, kind = parseOrderId(d.id); if not n then return err('Nie znaleziono zamówienia') end
    local action = d.action
    if action ~= 'accept' and action ~= 'reject' and action ~= 'deliver' then return err('Nieprawidłowa akcja') end
    local reason
    if action == 'reject' then reason = reasonOf(d.reason); if not reason then return err('Podaj powód odrzucenia (min. 5 znaków)') end end
    local o = MySQL.single.await('SELECT id, kind, buyer_job, supplier_job, items, total FROM bossmenu_orders WHERE id = ? AND supplier_job = ? AND kind = ?', { n, c.job, kind })
    if not o then return err('Nie znaleziono zamówienia') end
    local from = action == 'deliver' and 'accepted' or 'pending'
    local to = ({ accept = 'accepted', reject = 'rejected', deliver = 'delivered' })[action]
    local aff = MySQL.update.await('UPDATE bossmenu_orders SET status = ?, reason = COALESCE(?, reason) WHERE id = ? AND supplier_job = ? AND status = ?', { to, reason, n, c.job, from })
    if aff ~= 1 then return err('Status zamówienia już się zmienił') end

    local items = json.decode(o.items) or {}
    local buyerLabel = Bridge.JobLabel(o.buyer_job)
    local sum
    if kind == 'vehicles' then
        local names = {}
        for i, it in ipairs(items) do names[i] = it.name end
        sum = table.concat(names, ', ')
    else sum = summary(items) end

    if action == 'reject' then
        Bridge.AddFunds(o.buyer_job, o.total)
        Data.Tx(o.buyer_job, 'in', o.total, 'System', 'Zwrot za zamówienie', ('%s (odrzucone): %s'):format(ordNo(n), sum))
        Server.NotifyJob(o.buyer_job, ('Zamówienie %s zostało odrzucone – środki wróciły na konto firmy'):format(ordNo(n)), 'warn')
    elseif action == 'accept' then
        Server.NotifyJob(o.buyer_job, ('Zamówienie %s zostało przyjęte do realizacji'):format(ordNo(n)), 'success')
    else
        Bridge.AddFunds(c.job, o.total)
        Data.Tx(c.job, 'in', o.total, c.name, 'Dostawa zamówienia', ('%s · %s: %s'):format(ordNo(n), buyerLabel, sum))
        if kind == 'vehicles' then
            for _, it in ipairs(items) do
                local plate = Bridge.NewPlate()
                if plate then
                    MySQL.insert.await('INSERT INTO bossmenu_vehicles (plate, job, model, name, category) VALUES (?, ?, ?, ?, ?)', { plate, o.buyer_job, it.model, it.name, it.category })
                    Bridge.GrantVehicle(o.buyer_job, plate, it.model)
                else
                    print(('^1[crp_bossmenu] nie udało się wygenerować tablicy dla zamówienia %s^7'):format(ordNo(n)))
                end
            end
        else
            Config.GoodsDelivery({ id = 'zam-' .. n, buyerJob = o.buyer_job, supplierJob = c.job, total = o.total, items = items })
        end
        Server.NotifyJob(o.buyer_job, ('Zamówienie %s zostało dostarczone'):format(ordNo(n)), 'success')
    end
    hist(c, { type = 'orderHandled', orderId = (kind == 'vehicles' and 'ord-' or 'zam-') .. n, action = to, buyer = buyerLabel, total = o.total, reason = reason })
    Server.Refresh(o.buyer_job)
    return { ok = true, funds = Bridge.GetFunds(c.job) }
end

-- ═════════════ OFERTA ═════════════

local function requireSupplier(c) return jobCfg(c).supplier == true end

H.saveProduct = function(c, d)
    if not requireSupplier(c) then return err('Ta firma nie może publikować oferty') end
    local G = Config.Goods
    local name = U.str(d.name, 60); if not name or U.len(name) < 2 then return err('Nazwa produktu: 2–60 znaków') end
    local category = U.str(d.category or '', 30); if not category then return err('Kategoria jest za długa') end
    local desc = U.str(d.desc or '', 200); if not desc then return err('Opis jest za długi (max 200)') end
    local price = U.int(d.price, 1, G.maxPrice); if not price then return err(('Cena: 1–%d'):format(G.maxPrice)) end
    local active = d.active ~= false

    local access
    if d.access ~= nil and d.access ~= json.null and type(d.access) == 'table' then
        access = {}
        local seen = {}
        for _, j in ipairs(d.access) do
            if type(j) ~= 'string' or not Config.Jobs[j] or j == c.job then return err('Nieprawidłowa firma na liście dostępu') end
            if not seen[j] then seen[j] = true; access[#access + 1] = j end
        end
        if #access == 0 then return err('Wybierz co najmniej jedną firmę albo zezwól wszystkim') end
    end
    local accessJson = access and json.encode(access) or nil

    local id = d.id ~= nil and U.int(d.id, 1) or nil
    local old
    if d.id ~= nil then
        old = id and MySQL.single.await('SELECT id, name, price, active, access FROM bossmenu_products WHERE id = ? AND job = ?', { id, c.job })
        if not old then return err('Nie znaleziono produktu') end
    end
    if MySQL.scalar.await('SELECT 1 FROM bossmenu_products WHERE job = ? AND LOWER(name) = LOWER(?) AND id <> ? LIMIT 1', { c.job, name, id or 0 }) then
        return err('Produkt o tej nazwie już istnieje w ofercie')
    end
    if not old then
        id = MySQL.insert.await('INSERT INTO bossmenu_products (job, name, category, descr, price, active, access) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { c.job, name, category, desc, price, active and 1 or 0, accessJson })
        hist(c, { type = 'offerChange', action = 'add', name = name, to = price })
    else
        MySQL.update.await('UPDATE bossmenu_products SET name = ?, category = ?, descr = ?, price = ?, active = ?, access = ? WHERE id = ?',
            { name, category, desc, price, active and 1 or 0, accessJson, id })
        local entry
        if old.price ~= price then entry = { action = 'price', from = old.price, to = price }
        elseif (old.active == 1) ~= active then entry = { action = active and 'show' or 'hide' }
        elseif (old.access or '') ~= (accessJson or '') then entry = { action = 'access' }
        else entry = { action = 'edit' } end
        entry.type, entry.name = 'offerChange', name
        hist(c, entry)
    end
    Server.RefreshAll()
    return { ok = true, product = { id = id } }
end

H.deleteProduct = function(c, d)
    if not requireSupplier(c) then return err('Ta firma nie może publikować oferty') end
    local id = U.int(d.id, 1)
    local p = id and MySQL.single.await('SELECT id, name, price FROM bossmenu_products WHERE id = ? AND job = ?', { id, c.job })
    if not p then return err('Nie znaleziono produktu') end
    MySQL.update.await('DELETE FROM bossmenu_products WHERE id = ?', { id })
    hist(c, { type = 'offerChange', action = 'remove', name = p.name, to = p.price })
    Server.RefreshAll()
    return { ok = true }
end

-- zdarzenia, które nie zmieniają danych (nie wymagają odświeżenia)
Handlers_NoRefresh = { testWebhook = true }
-- zdarzenia „fire-and-forget” z UI (post): błędy pokazujemy powiadomieniem i wymuszamy odświeżenie danych
Handlers_Post = { setGrade = true, setBadge = true, addRecord = true, voidRecord = true, setLicense = true, resetHours = true,
    resetAllHours = true, fire = true, setSalary = true, setWebhooks = true, deposit = true, withdraw = true }
