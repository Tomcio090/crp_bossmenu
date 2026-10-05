--[[
    s_data.lua – cała baza danych i cache panelu (tylko serwer)

    Jak to działa (i dlaczego baza jest spokojna):
      1. Dane firmy wczytują się z bazy RAZ – przy pierwszym użyciu (wejście na służbę / otwarcie panelu).
      2. Otwarcie i odświeżenie panelu czytają TYLKO pamięć – zero SELECT-ów.
      3. Akcje (zatrudnienie, stopień, wpis, odznaka, licencja...) zmieniają pamięć
         i od razu zapisują do bazy tylko to, co się zmieniło.
      4. Naliczone godziny pracy lecą do bazy jednym zbiorczym zapytaniem (data.Flush)
         co Config.Cache.saveSeconds – a nie po jednym zapytaniu na gracza.

    Nic tu nie trzeba wywoływać ręcznie – reszta dzieje się w s_main.lua.
]]

-- zabezpieczenie przed podwójnym załadowaniem (np. fxmanifest + require)
if _G.crp_bossmenu_s_data then return {} end
_G.crp_bossmenu_s_data = true

local Config = require('resources.bossmenu.d_bossmenu')
local ESX = exports['es_extended']:getSharedObject()

local data = {}

local DB  = Config.Db
local LIM = Config.Cache

-- nazwy kolumn z konfiguracji, opakowane w apostrofy SQL (bez backticków w kodzie)
local TICK = string.char(96)
local function q(key) return TICK .. DB[key] .. TICK end

-- lista kolumn gracza – sklejona raz, używana w kilku zapytaniach
local USER_COLS = ('%s AS identifier, %s AS firstname, %s AS lastname, %s AS ssn, %s AS phone'):format(
    q('identifier'), q('firstname'), q('lastname'), q('ssn'), q('phone'))

-- formaty dat (wszystkie daty w cache trzymamy jako unix timestamp i formatujemy dopiero w payloadzie)
local function asDate(ts)     return ts and os.date('%d.%m.%Y', ts) or '' end
local function asDateTime(ts) return ts and os.date('%d.%m.%Y %H:%M', ts) or '' end
local function asShort(ts)    return ts and os.date('%d.%m %H:%M', ts) or '' end

local function secondsToHours(seconds)
    return math.floor(((seconds or 0) / 3600) * 10 + 0.5) / 10
end


-- ═════════════════════════════════════════════════════════════
--  SCHEMAT BAZY
-- ═════════════════════════════════════════════════════════════
local SCHEMA = {
[[CREATE TABLE IF NOT EXISTS bossmenu_members (
    identifier VARCHAR(60) NOT NULL, job VARCHAR(50) NOT NULL,
    hired_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    badge INT NULL, seconds INT NOT NULL DEFAULT 0, last_duty DATETIME NULL,
    note MEDIUMTEXT NULL, note_by VARCHAR(100) NULL, note_at DATETIME NULL,
    PRIMARY KEY (identifier, job)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_licenses (
    identifier VARCHAR(60) NOT NULL, job VARCHAR(50) NOT NULL, license VARCHAR(50) NOT NULL,
    granted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, job, license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_records (
    id INT AUTO_INCREMENT PRIMARY KEY, identifier VARCHAR(60) NOT NULL, job VARCHAR(50) NOT NULL,
    kind VARCHAR(12) NOT NULL, reason VARCHAR(500) NOT NULL, by_name VARCHAR(100) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    void_by VARCHAR(100) NULL, void_at DATETIME NULL, void_reason VARCHAR(500) NULL,
    INDEX idx_emp (job, identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_promotions (
    id INT AUTO_INCREMENT PRIMARY KEY, identifier VARCHAR(60) NOT NULL, job VARCHAR(50) NOT NULL,
    from_grade INT NOT NULL, to_grade INT NOT NULL, by_name VARCHAR(100) NOT NULL, reason VARCHAR(500) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_emp (job, identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_transactions (
    id INT AUTO_INCREMENT PRIMARY KEY, job VARCHAR(50) NOT NULL, type VARCHAR(3) NOT NULL,
    amount BIGINT NOT NULL, by_name VARCHAR(100) NOT NULL, label VARCHAR(100) NOT NULL, reason VARCHAR(600) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job (job, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_history (
    id INT AUTO_INCREMENT PRIMARY KEY, job VARCHAR(50) NOT NULL, by_name VARCHAR(100) NOT NULL, entry LONGTEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job (job, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_settings (
    job VARCHAR(50) NOT NULL PRIMARY KEY, webhooks LONGTEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_vehicles (
    plate VARCHAR(12) NOT NULL PRIMARY KEY, job VARCHAR(50) NOT NULL, model VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL, category VARCHAR(60) NULL,
    assigned_identifier VARCHAR(60) NULL, assigned_at DATETIME NULL,
    added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job (job)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_orders (
    id INT AUTO_INCREMENT PRIMARY KEY, kind VARCHAR(10) NOT NULL,
    buyer_job VARCHAR(50) NOT NULL, supplier_job VARCHAR(50) NOT NULL,
    items LONGTEXT NOT NULL, total BIGINT NOT NULL, status VARCHAR(12) NOT NULL DEFAULT 'pending',
    note VARCHAR(300) NULL, reason VARCHAR(500) NULL, by_name VARCHAR(100) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_buyer (buyer_job, id), INDEX idx_supplier (supplier_job, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

[[CREATE TABLE IF NOT EXISTS bossmenu_products (
    id INT AUTO_INCREMENT PRIMARY KEY, job VARCHAR(50) NOT NULL, name VARCHAR(100) NOT NULL,
    category VARCHAR(60) NULL, descr VARCHAR(300) NULL, price BIGINT NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1, access LONGTEXT NULL,
    INDEX idx_job (job)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
}

function data.Install()
    for _, sql in ipairs(SCHEMA) do MySQL.query.await(sql) end
    print('^2[crp_bossmenu]^7 tabele gotowe')
end


-- ═════════════════════════════════════════════════════════════
--  CACHE
--
--  cache[job] = {
--      members  = { [identifier] = { badge, seconds, hired_at, last_duty, note, note_by, note_at } },
--      dirty    = { [identifier] = true },   -- godziny do zrzutu do bazy
--      roster   = { [identifier] = { ssn, firstname, lastname, phone, grade } },
--      licenses = { [identifier] = { [license] = unix } },
--      records  = { [identifier] = { {id, kind, reason, by_name, at, void_*} } },
--      promos   = { [identifier] = { {from_grade, to_grade, by_name, reason, at} } },
--      tx, history, vehicles, orders, webhooks
--  }
-- ═════════════════════════════════════════════════════════════
local cache = {}
local products = {}   -- products[job] = lista produktów firmy (osobny cache, bo korzystają z niego inne firmy)

local function newJob()
    return {
        membersLoaded = false, members = {}, dirty = {},
        rosterLoaded = false, rosterStale = true, roster = {},
        extrasLoaded = false, licenses = {}, records = {}, promos = {}, tx = {}, history = {},
        vehiclesLoaded = false, vehicles = {},
        orders = { buyerLoaded = false, supplierLoaded = false, buyer = {}, supplier = {} },
        webhooks = { plusminus = '', commend = '', promo = '' }
    }
end

local function get(job)
    local c = cache[job]
    if not c then c = newJob(); cache[job] = c end
    return c
end


-- ───────── wczytywanie ─────────

-- pracownicy z bossmenu_members (odznaki, godziny, notatki)
function data.LoadMembers(job)
    local c = get(job)
    local rows = MySQL.query.await([[
        SELECT identifier, badge, seconds,
               UNIX_TIMESTAMP(hired_at) AS hired_at, UNIX_TIMESTAMP(last_duty) AS last_duty,
               note, note_by, UNIX_TIMESTAMP(note_at) AS note_at
        FROM bossmenu_members WHERE job = ?]], { job })

    c.members = {}
    for _, r in ipairs(rows or {}) do
        r.exists = true
        c.members[r.identifier] = r
    end
    c.membersLoaded = true
    return c.members
end

function data.Members(job)
    local c = get(job)
    if not c.membersLoaded then data.LoadMembers(job) end
    return c.members
end

-- wpis pracownika w pamięci (bez zapisu do bazy)
function data.Member(job, identifier)
    local members = data.Members(job)
    local m = members[identifier]
    if not m then
        m = { identifier = identifier, badge = nil, seconds = 0, hired_at = os.time(), last_duty = nil, exists = false }
        members[identifier] = m
    end
    return m
end

-- gwarantuje wiersz w bossmenu_members (np. gdy ktoś pracuje, a nigdy nie był w panelu)
function data.EnsureRow(job, identifier)
    local m = data.Member(job, identifier)
    if m.exists then return m end
    MySQL.insert.await('INSERT IGNORE INTO bossmenu_members (identifier, job) VALUES (?, ?)', { identifier, job })
    m.exists, m.hired_at = true, os.time()
    return m
end

-- lista pracowników z tabeli graczy (kto jest w tej pracy)
function data.LoadRoster(job)
    local c = get(job)
    local rows = MySQL.query.await(('SELECT %s, job_grade AS grade FROM %s WHERE job = ?')
        :format(USER_COLS, q('users')), { job })

    local roster = {}
    for _, r in ipairs(rows or {}) do roster[r.identifier] = r end
    c.roster, c.rosterLoaded, c.rosterStale = roster, true, false
    return roster
end

function data.Roster(job)
    local c = get(job)
    if not c.rosterLoaded or c.rosterStale then data.LoadRoster(job) end
    return c.roster
end

function data.RosterAdd(job, row)
    local c = cache[job]
    if c and c.rosterLoaded then c.roster[row.identifier] = row end
end

function data.RosterRemove(job, identifier)
    local c = cache[job]
    if c and c.rosterLoaded then c.roster[identifier] = nil end
end

-- oznacz listę pracowników do odświeżenia (zmiana pracy, okresowy refresh)
function data.RefreshRoster(job)
    local c = cache[job]
    if c then c.rosterStale = true end
end

-- licencje, wpisy, awanse, historia, transakcje, pojazdy, zamówienia, webhooki
function data.LoadExtras(job)
    local c = get(job)
    data.Members(job)

    c.licenses, c.records, c.promos, c.tx, c.history = {}, {}, {}, {}, {}

    local lic = MySQL.query.await(
        'SELECT identifier, license, UNIX_TIMESTAMP(granted_at) AS at FROM bossmenu_licenses WHERE job = ?', { job })
    for _, r in ipairs(lic or {}) do
        c.licenses[r.identifier] = c.licenses[r.identifier] or {}
        c.licenses[r.identifier][r.license] = r.at
    end

    local rec = MySQL.query.await(('SELECT id, identifier, kind, reason, by_name, UNIX_TIMESTAMP(created_at) AS at, \
        void_by, UNIX_TIMESTAMP(void_at) AS void_at, void_reason FROM bossmenu_records \
        WHERE job = ? ORDER BY id DESC LIMIT %d'):format(LIM.recordLimit), { job })
    for _, r in ipairs(rec or {}) do
        local list = c.records[r.identifier] or {}; c.records[r.identifier] = list
        list[#list + 1] = r
    end

    local pro = MySQL.query.await(('SELECT identifier, from_grade, to_grade, by_name, reason, UNIX_TIMESTAMP(created_at) AS at \
        FROM bossmenu_promotions WHERE job = ? ORDER BY id DESC LIMIT %d'):format(LIM.recordLimit), { job })
    for _, r in ipairs(pro or {}) do
        local list = c.promos[r.identifier] or {}; c.promos[r.identifier] = list
        list[#list + 1] = r
    end

    local tx = MySQL.query.await(('SELECT type, amount, by_name, label, reason, UNIX_TIMESTAMP(created_at) AS at \
        FROM bossmenu_transactions WHERE job = ? ORDER BY id DESC LIMIT %d'):format(LIM.logLimit), { job })
    for _, r in ipairs(tx or {}) do c.tx[#c.tx + 1] = r end

    local hist = MySQL.query.await(('SELECT entry, by_name, UNIX_TIMESTAMP(created_at) AS at \
        FROM bossmenu_history WHERE job = ? ORDER BY id DESC LIMIT %d'):format(LIM.logLimit), { job })
    for _, r in ipairs(hist or {}) do
        local e = json.decode(r.entry) or {}
        e.by, e.at = r.by_name, r.at
        c.history[#c.history + 1] = e
    end

    local hooks = MySQL.scalar.await('SELECT webhooks FROM bossmenu_settings WHERE job = ?', { job })
    local h = hooks and json.decode(hooks) or {}
    c.webhooks = { plusminus = h.plusminus or '', commend = h.commend or '', promo = h.promo or '' }

    c.orders.buyerLoaded, c.orders.supplierLoaded = false, false
    c.vehiclesLoaded = false
    c.extrasLoaded = true
    return c
end

function data.LoadVehicles(job)
    local c = get(job)
    c.vehicles = {}

    local rows = MySQL.query.await(([[
        SELECT v.plate, v.model, v.name, v.category, v.assigned_identifier,
               UNIX_TIMESTAMP(v.assigned_at) AS assigned_at, UNIX_TIMESTAMP(v.added_at) AS added_at,
               u.%s AS assigned_ssn
        FROM bossmenu_vehicles v
        LEFT JOIN %s u ON u.%s = v.assigned_identifier
        WHERE v.job = ? ORDER BY v.added_at DESC]]):format(q('ssn'), q('users'), q('identifier')), { job })

    for _, r in ipairs(rows or {}) do c.vehicles[#c.vehicles + 1] = r end
    c.vehiclesLoaded = true
    return c.vehicles
end

function data.Vehicles(job)
    local c = get(job)
    if not c.vehiclesLoaded then data.LoadVehicles(job) end
    return c.vehicles
end

local ORDER_COLS = [[
    id, kind, buyer_job, supplier_job, items, total, status, note, reason, by_name,
    UNIX_TIMESTAMP(created_at) AS at
]]

function data.LoadOrders(job)
    local c = get(job)
    local buyer = MySQL.query.await(('SELECT %s FROM bossmenu_orders WHERE buyer_job = ? ORDER BY id DESC LIMIT %d')
        :format(ORDER_COLS, LIM.orderLimit), { job })
    local supplier = MySQL.query.await(('SELECT %s FROM bossmenu_orders WHERE supplier_job = ? ORDER BY id DESC LIMIT %d')
        :format(ORDER_COLS, LIM.orderLimit), { job })

    c.orders.buyer, c.orders.supplier = {}, {}
    for _, r in ipairs(buyer or {}) do
        r.items = json.decode(r.items) or {}
        c.orders.buyer[#c.orders.buyer + 1] = r
    end
    for _, r in ipairs(supplier or {}) do
        r.items = json.decode(r.items) or {}
        c.orders.supplier[#c.orders.supplier + 1] = r
    end
    c.orders.buyerLoaded, c.orders.supplierLoaded = true, true
    return c.orders
end

function data.Orders(job)
    local c = get(job)
    if not c.orders.buyerLoaded or not c.orders.supplierLoaded then data.LoadOrders(job) end
    return c.orders
end

function data.InvalidateOrders(job)
    local c = cache[job]
    if c then c.orders.buyerLoaded, c.orders.supplierLoaded = false, false end
end

-- wszystko, co potrzebuje panel
function data.Prepare(job)
    data.Members(job)
    data.Roster(job)
    local c = get(job)
    if not c.extrasLoaded then data.LoadExtras(job) end
    return get(job)
end


-- ═════════════════════════════════════════════════════════════
--  GODZINY PRACY
-- ═════════════════════════════════════════════════════════════

function data.AddSeconds(job, identifier, seconds)
    local m = data.Member(job, identifier)
    m.seconds = (m.seconds or 0) + seconds
    m.last_duty = os.time()
    get(job).dirty[identifier] = true
end

function data.ResetHours(job, identifier)
    local m = data.Member(job, identifier)
    m.seconds = 0
    get(job).dirty[identifier] = true
end

function data.ResetAllHours(job)
    local c = get(job)
    local total, count = 0, 0
    for identifier, m in pairs(data.Members(job)) do
        total = total + secondsToHours(m.seconds)
        count = count + 1
        m.seconds = 0
        c.dirty[identifier] = true
    end
    return total, count
end

-- jeden INSERT na firmę, zamiast zapytania na każdego gracza
function data.Flush()
    for job, c in pairs(cache) do
        local values, params = {}, {}
        for identifier in pairs(c.dirty) do
            local m = c.members[identifier]
            if m then
                values[#values + 1] = '(?, ?, ?, FROM_UNIXTIME(?))'
                params[#params + 1] = identifier
                params[#params + 1] = job
                params[#params + 1] = m.seconds or 0
                params[#params + 1] = m.last_duty or os.time()
            end
        end
        if #values > 0 then
            MySQL.update.await(('INSERT INTO bossmenu_members (identifier, job, seconds, last_duty) VALUES %s \
                ON DUPLICATE KEY UPDATE seconds = VALUES(seconds), last_duty = VALUES(last_duty)')
                :format(table.concat(values, ', ')), params)
            c.dirty = {}
        end
    end
end


-- ═════════════════════════════════════════════════════════════
--  ZATRUDNIENIE / ZWOLNIENIE / DANE PRACOWNIKA
-- ═════════════════════════════════════════════════════════════

function data.SetHired(job, identifier)
    local m = data.Member(job, identifier)
    m.badge, m.seconds, m.last_duty = nil, 0, nil
    m.note, m.note_by, m.note_at = nil, nil, nil
    m.hired_at, m.exists = os.time(), true
    get(job).dirty[identifier] = nil

    MySQL.insert.await([[INSERT INTO bossmenu_members (identifier, job) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE hired_at = NOW(), badge = NULL, seconds = 0, last_duty = NULL,
                                note = NULL, note_by = NULL, note_at = NULL]], { identifier, job })
end

function data.RemoveMember(job, identifier)
    local c = get(job)
    c.members[identifier] = nil
    c.dirty[identifier] = nil
    c.licenses[identifier] = nil

    MySQL.update.await('DELETE FROM bossmenu_members WHERE identifier = ? AND job = ?', { identifier, job })
    MySQL.update.await('DELETE FROM bossmenu_licenses WHERE identifier = ? AND job = ?', { identifier, job })
end

function data.SetBadge(job, identifier, badge)
    -- zajętość numeru sprawdzamy w pamięci, nie w bazie
    if badge then
        for id, m in pairs(data.Members(job)) do
            if id ~= identifier and m.badge == badge then return false end
        end
    end
    local m = data.EnsureRow(job, identifier)
    m.badge = badge
    MySQL.update.await('UPDATE bossmenu_members SET badge = ? WHERE identifier = ? AND job = ?', { badge, identifier, job })
    return true
end

function data.SetNote(job, identifier, html, by)
    local m = data.EnsureRow(job, identifier)
    if html == '' then
        m.note, m.note_by, m.note_at = nil, nil, nil
        MySQL.update.await('UPDATE bossmenu_members SET note = NULL, note_by = NULL, note_at = NULL WHERE identifier = ? AND job = ?', { identifier, job })
    else
        m.note, m.note_by, m.note_at = html, by, os.time()
        MySQL.update.await('UPDATE bossmenu_members SET note = ?, note_by = ?, note_at = NOW() WHERE identifier = ? AND job = ?', { html, by, identifier, job })
    end
end

function data.SetLicense(job, identifier, license, on)
    local c = get(job)
    c.licenses[identifier] = c.licenses[identifier] or {}
    if on then
        c.licenses[identifier][license] = os.time()
        MySQL.insert.await('INSERT IGNORE INTO bossmenu_licenses (identifier, job, license) VALUES (?, ?, ?)', { identifier, job, license })
    else
        c.licenses[identifier][license] = nil
        MySQL.update.await('DELETE FROM bossmenu_licenses WHERE identifier = ? AND job = ? AND license = ?', { identifier, job, license })
    end
end

function data.AddRecord(job, identifier, kind, reason, by)
    local id = MySQL.insert.await('INSERT INTO bossmenu_records (identifier, job, kind, reason, by_name) VALUES (?, ?, ?, ?, ?)',
        { identifier, job, kind, reason, by })

    local c = get(job)
    local list = c.records[identifier] or {}
    c.records[identifier] = list
    table.insert(list, 1, { id = id, identifier = identifier, kind = kind, reason = reason, by_name = by, at = os.time() })
    return id
end

function data.VoidRecord(job, recordId, by, reason)
    local affected = MySQL.update.await(
        'UPDATE bossmenu_records SET void_by = ?, void_at = NOW(), void_reason = ? WHERE id = ? AND job = ? AND void_by IS NULL',
        { by, reason, recordId, job })
    if affected ~= 1 then return false end

    for _, list in pairs(get(job).records) do
        for _, r in ipairs(list) do
            if r.id == recordId then
                r.void_by, r.void_at, r.void_reason = by, os.time(), reason
                return true
            end
        end
    end
    return true
end

function data.AddPromotion(job, identifier, from, to, by, reason)
    MySQL.insert.await('INSERT INTO bossmenu_promotions (identifier, job, from_grade, to_grade, by_name, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { identifier, job, from, to, by, reason })

    local c = get(job)
    local list = c.promos[identifier] or {}
    c.promos[identifier] = list
    table.insert(list, 1, { identifier = identifier, from_grade = from, to_grade = to, by_name = by, reason = reason, at = os.time() })
end

function data.SetJob(identifier, job, grade)
    MySQL.update.await(('UPDATE %s SET job = ?, job_grade = ? WHERE %s = ?'):format(q('users'), q('identifier')),
        { job, grade, identifier })

    local x = ESX.GetPlayerFromIdentifier(identifier)
    if x then x.setJob(job, grade) end
    return x
end

function data.SetSalary(job, grade, salary)
    MySQL.update.await('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', { salary, job, grade })

    local g = ESX.Jobs[job] and ESX.Jobs[job].grades[tostring(grade)]
    if g then g.salary = salary end

    for _, x in pairs(ESX.GetExtendedPlayers('job', job)) do
        if x.job.grade == grade then x.job.grade_salary = salary end
    end
end


-- ═════════════════════════════════════════════════════════════
--  HISTORIA / TRANSAKCJE / WEBHOOKI
-- ═════════════════════════════════════════════════════════════

function data.Tx(job, type_, amount, by, label, reason)
    MySQL.insert.await('INSERT INTO bossmenu_transactions (job, type, amount, by_name, label, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { job, type_, amount, by, label, reason })

    local c = get(job)
    if c.extrasLoaded then
        table.insert(c.tx, 1, { type = type_, amount = amount, by = by, label = label, reason = reason, at = os.time() })
        if #c.tx > LIM.logLimit then table.remove(c.tx) end
    end
end

function data.Hist(job, by, entry)
    MySQL.insert.await('INSERT INTO bossmenu_history (job, by_name, entry) VALUES (?, ?, ?)',
        { job, by, json.encode(entry) })

    local c = get(job)
    if c.extrasLoaded then
        entry.by, entry.at = by, os.time()
        table.insert(c.history, 1, entry)
        if #c.history > LIM.logLimit then table.remove(c.history) end
    end
end

function data.Hooks(job)
    return get(job).webhooks
end

function data.SetHooks(job, hooks)
    MySQL.insert.await('INSERT INTO bossmenu_settings (job, webhooks) VALUES (?, ?) ON DUPLICATE KEY UPDATE webhooks = VALUES(webhooks)',
        { job, json.encode(hooks) })
    get(job).webhooks = hooks
end


-- ═════════════════════════════════════════════════════════════
--  KONTO FIRMY (esx_addonaccount)
-- ═════════════════════════════════════════════════════════════
local function society(job)
    local account
    TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society(job), function(a) account = a end)
    return account
end

function data.Funds(job)
    local a = society(job)
    return a and math.floor(a.money) or 0
end

function data.RemoveFunds(job, amount)
    local a = society(job)
    if not a or a.money < amount then return false end
    a.removeMoney(amount)
    return true
end

function data.AddFunds(job, amount)
    local a = society(job)
    if not a then return false end
    a.addMoney(amount)
    return true
end


-- ═════════════════════════════════════════════════════════════
--  GRACZE (odczyt z tabeli graczy – tylko dla akcji, nie dla panelu)
-- ═════════════════════════════════════════════════════════════
function data.FindBySsn(ssn)
    return MySQL.single.await(('SELECT %s, job, job_grade AS grade FROM %s WHERE %s = ? LIMIT 1')
        :format(USER_COLS, q('users'), q('ssn')), { ssn })
end

function data.FindByIdentifier(identifier)
    return MySQL.single.await(('SELECT %s, job, job_grade AS grade FROM %s WHERE %s = ? LIMIT 1')
        :format(USER_COLS, q('users'), q('identifier')), { identifier })
end

function data.JobLabel(job)
    return (ESX.Jobs[job] and ESX.Jobs[job].label) or job
end

function data.Grades(job)
    local out, j = {}, ESX.Jobs[job]
    if not j then return out end
    for grade, def in pairs(j.grades) do
        out[#out + 1] = { id = tonumber(grade), name = def.label or def.name, salary = tonumber(def.salary) or 0 }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function data.BossGrade(job)
    local max = 0
    for _, g in ipairs(data.Grades(job)) do if g.id > max then max = g.id end end
    return max
end

function data.MinGrade(job)
    local jc = Config.Jobs[job]
    return (jc and jc.minGrade) or data.BossGrade(job)
end


-- ═════════════════════════════════════════════════════════════
--  OFERTA (produkty firm)
-- ═════════════════════════════════════════════════════════════
function data.Products(job)
    local list = products[job]
    if not list then
        list = {}
        local rows = MySQL.query.await('SELECT id, name, category, descr, price, active, access FROM bossmenu_products WHERE job = ? ORDER BY id', { job })
        for _, p in ipairs(rows or {}) do
            list[#list + 1] = {
                id = p.id, name = p.name, category = p.category or '', desc = p.descr or '',
                price = p.price, active = p.active == 1, access = p.access and json.decode(p.access) or nil
            }
        end
        products[job] = list
    end
    return list
end

function data.InvalidateProducts(job) products[job] = nil end

function data.FindProduct(job, id)
    return MySQL.single.await('SELECT id, name, price, active, access FROM bossmenu_products WHERE id = ? AND job = ?', { id, job })
end

function data.ProductNameExists(job, name, id)
    return MySQL.scalar.await('SELECT 1 FROM bossmenu_products WHERE job = ? AND LOWER(name) = LOWER(?) AND id <> ? LIMIT 1',
        { job, name, id or 0 }) ~= nil
end

function data.SaveProduct(job, id, p)
    local access = p.access and json.encode(p.access) or nil
    if id then
        MySQL.update.await('UPDATE bossmenu_products SET name = ?, category = ?, descr = ?, price = ?, active = ?, access = ? WHERE id = ? AND job = ?',
            { p.name, p.category, p.desc, p.price, p.active and 1 or 0, access, id, job })
    else
        id = MySQL.insert.await('INSERT INTO bossmenu_products (job, name, category, descr, price, active, access) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { job, p.name, p.category, p.desc, p.price, p.active and 1 or 0, access })
    end
    data.InvalidateProducts(job)
    return id
end

function data.DeleteProduct(job, id)
    MySQL.update.await('DELETE FROM bossmenu_products WHERE id = ? AND job = ?', { id, job })
    data.InvalidateProducts(job)
end


-- ═════════════════════════════════════════════════════════════
--  ZAMÓWIENIA (pojazdy + towary)
-- ═════════════════════════════════════════════════════════════

function data.NewOrder(kind, buyerJob, supplierJob, items, total, by, note)
    local id = MySQL.insert.await(
        'INSERT INTO bossmenu_orders (kind, buyer_job, supplier_job, items, total, note, by_name) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { kind, buyerJob, supplierJob, json.encode(items), total, note, by })

    -- dorzucamy zamówienie do pamięci obu firm (jeśli już wczytana) – bez ponownego SELECT-a
    local row = { id = id, kind = kind, buyer_job = buyerJob, supplier_job = supplierJob, items = items,
        total = total, status = 'pending', note = note, reason = nil, by_name = by, at = os.time() }

    local buyerCache = cache[buyerJob]
    if buyerCache and buyerCache.orders.buyerLoaded then table.insert(buyerCache.orders.buyer, 1, row) end

    local supplierCache = cache[supplierJob]
    if supplierCache and supplierCache.orders.supplierLoaded then table.insert(supplierCache.orders.supplier, 1, row) end

    return id
end

-- field = 'buyer_job' albo 'supplier_job'
function data.GetOrder(id, kind, field, job)
    return MySQL.single.await(('SELECT id, kind, buyer_job, supplier_job, items, total, status FROM bossmenu_orders \
        WHERE id = ? AND %s = ? AND kind = ?'):format(field), { id, job, kind })
end

function data.SetOrderStatus(id, field, job, from, to, reason, buyerJob, supplierJob)
    local affected = MySQL.update.await(('UPDATE bossmenu_orders SET status = ?, reason = COALESCE(?, reason) \
        WHERE id = ? AND %s = ? AND status = ?'):format(field), { to, reason, id, job, from })
    if affected ~= 1 then return false end

    -- ten sam status w pamięci obu firm (bez ponownego SELECT-a)
    for _, target in ipairs({ buyerJob, supplierJob }) do
        local c = cache[target]
        if c then
            for _, list in ipairs({ c.orders.buyer, c.orders.supplier }) do
                for _, order in ipairs(list) do
                    if order.id == id then
                        order.status = to
                        if reason then order.reason = reason end
                    end
                end
            end
        end
    end
    return true
end


-- ═════════════════════════════════════════════════════════════
--  POJAZDY
-- ═════════════════════════════════════════════════════════════

function data.AddVehicle(job, plate, model, name, category)
    MySQL.insert.await('INSERT INTO bossmenu_vehicles (plate, job, model, name, category) VALUES (?, ?, ?, ?, ?)',
        { plate, job, model, name, category })

    local c = get(job)
    if c.vehiclesLoaded then
        table.insert(c.vehicles, 1, { plate = plate, model = model, name = name, category = category, added_at = os.time() })
    end
end

function data.SetVehicleOwner(job, plate, identifier, ssn)
    MySQL.update.await('UPDATE bossmenu_vehicles SET assigned_identifier = ?, assigned_at = NOW() WHERE plate = ?',
        { identifier, plate })

    local c = get(job)
    for _, v in ipairs(c.vehicles) do
        if v.plate == plate then
            v.assigned_identifier, v.assigned_ssn = identifier, ssn
            v.assigned_at = identifier and os.time() or nil
            break
        end
    end
end

-- ── wpis w owned_vehicles (ESX) ──
local function vehicleCfg() return Config.VehicleShop.ownedVehicles end

function data.GrantVehicle(job, plate, model)
    local cfg = vehicleCfg()
    if not cfg.enabled then return end
    local ok, err = pcall(function()
        MySQL.insert.await('INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, 1)',
            { cfg.owner(job, nil), plate, json.encode({ model = GetHashKey(model), plate = plate }), cfg.type })
    end)
    if not ok then print('^1[crp_bossmenu] owned_vehicles:^7', err) end
end

function data.VehicleOwner(job, plate, identifier)
    local cfg = vehicleCfg()
    if not cfg.enabled then return end
    pcall(function()
        MySQL.update.await('UPDATE owned_vehicles SET owner = ? WHERE plate = ?', { cfg.owner(job, identifier), plate })
    end)
end

function data.NewPlate()
    for _ = 1, 50 do
        local plate = Config.VehicleShop.plateFormat
            :gsub('A', function() return string.char(math.random(65, 90)) end)
            :gsub('0', function() return tostring(math.random(0, 9)) end)

        local taken = MySQL.scalar.await('SELECT 1 FROM bossmenu_vehicles WHERE plate = ?', { plate })
        if not taken then
            local ok, r = pcall(function() return MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ?', { plate }) end)
            if not ok or not r then return plate end
        end
    end
    return nil
end


-- ═════════════════════════════════════════════════════════════
--  PACZKA DLA UI (to leci do klienta przy otwarciu i odświeżeniu)
-- ═════════════════════════════════════════════════════════════
local function buildEmployee(c, job, identifier, u)
    local m = c.members[identifier]

    -- gracz online ma zawsze aktualny stopień/status i nie pokazujemy go, jeśli zmienił pracę
    local grade, status = u.grade, 'off'
    local x = ESX.GetPlayerFromIdentifier(identifier)
    if x then
        if x.job.name ~= job then return nil end
        grade, status = x.job.grade, Config.GetDutyStatus(x.source, x)
    end

    local seconds  = m and m.seconds or 0
    local lastSeen = m and (m.last_duty or m.hired_at) or nil

    local e = {
        ssn         = u.ssn or identifier,
        firstname   = u.firstname or '',
        lastname    = u.lastname or '',
        phonenumber = u.phone or '',
        grade       = grade,
        status      = status,
        lastSeen    = status == 'off' and math.max(0, math.floor((os.time() - (lastSeen or os.time())) / 60)) or 0,
        badge       = m and m.badge or nil,
        hiredAt     = asDate((m and m.hired_at) or os.time()),
        hoursWeek   = secondsToHours(seconds),
        licenses    = {}, records = {}, promotions = {}
    }

    if m and m.note and m.note ~= '' then
        e.note = { html = m.note, by = m.note_by or '—', at = asDateTime(m.note_at) }
    end

    for license, at in pairs(c.licenses[identifier] or {}) do
        e.licenses[#e.licenses + 1] = { id = license, at = asDate(at) }
    end
    for _, r in ipairs(c.records[identifier] or {}) do
        e.records[#e.records + 1] = {
            id = r.id, kind = r.kind, by = r.by_name, reason = r.reason, at = asDateTime(r.at),
            voided = r.void_by and { by = r.void_by, at = asDateTime(r.void_at), reason = r.void_reason } or nil
        }
    end
    for _, p in ipairs(c.promos[identifier] or {}) do
        e.promotions[#e.promotions + 1] = {
            from = p.from_grade, to = p.to_grade, by = p.by_name, reason = p.reason, at = asDateTime(p.at)
        }
    end

    return e
end

-- wiersz zamówienia w formie, którą czyta UI
local function orderRow(r, view)
    local o = {
        id = (r.kind == 'vehicles' and 'ord-' or 'zam-') .. r.id,
        kind = r.kind, items = r.items, total = r.total,
        by = r.by_name, at = asDateTime(r.at), status = r.status
    }
    if r.kind == 'vehicles' then
        o.note, o.reason = r.reason, r.reason          -- garaż pokazuje powód odrzucenia jako note
    else
        o.note, o.reason = r.note, r.reason
        o.supplier = { job = r.supplier_job, label = data.JobLabel(r.supplier_job) }
    end
    o.buyer = { job = r.buyer_job, label = data.JobLabel(r.buyer_job) }
    if view == 'buyer' and r.kind == 'vehicles' then o.kind, o.buyer = nil, nil end
    return o
end

-- czy dana firma ma dostęp do produktu (access = lista firm, pusta/brak = wszyscy)
local function hasAccess(access, job)
    if not access then return true end
    for _, allowed in ipairs(access) do if allowed == job then return true end end
    return false
end

function data.HasAccess(product, job) return hasAccess(product.access, job) end

function data.Build(s)
    local job, jc = s.job, Config.Jobs[s.job]
    local c = data.Prepare(job)
    local orders = data.Orders(job)

    -- ── pracownicy ──
    local employees = {}
    for identifier, u in pairs(c.roster) do
        local e = buildEmployee(c, job, identifier, u)
        if e then employees[#employees + 1] = e end
    end
    table.sort(employees, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return (a.lastname .. a.firstname) < (b.lastname .. b.firstname)
    end)

    -- ── pojazdy ──
    local vehicles = {}
    for _, v in ipairs(data.Vehicles(job)) do
        vehicles[#vehicles + 1] = {
            plate = v.plate, model = v.model, name = v.name, category = v.category or '',
            assignedTo = v.assigned_ssn, assignedAt = asDateTime(v.assigned_at), addedAt = asDateTime(v.added_at)
        }
    end

    -- ── zamówienia: moje (garaż / towary) + przychodzące ──
    local vehicleOrders, goodsOrders, incoming = {}, {}, {}
    for _, r in ipairs(orders.buyer) do
        if r.kind == 'vehicles' then vehicleOrders[#vehicleOrders + 1] = orderRow(r, 'buyer')
        else goodsOrders[#goodsOrders + 1] = orderRow(r, 'buyer') end
    end
    for _, r in ipairs(orders.supplier) do incoming[#incoming + 1] = orderRow(r, 'incoming') end

    -- ── firmy / dostawcy (oferta B2B) ──
    local suppliers, companies = {}, {}
    for other, otherCfg in pairs(Config.Jobs) do
        if other ~= job then
            companies[#companies + 1] = { job = other, label = data.JobLabel(other) }
            if otherCfg.supplier then
                local list = {}
                for _, p in ipairs(data.Products(other)) do
                    if p.active and hasAccess(p.access, job) then list[#list + 1] = p end
                end
                if #list > 0 then
                    suppliers[#suppliers + 1] = { job = other, label = data.JobLabel(other), desc = otherCfg.supplierDesc or '', products = list }
                end
            end
        end
    end
    table.sort(suppliers, function(a, b) return a.label < b.label end)
    table.sort(companies, function(a, b) return a.label < b.label end)

    -- ── historia / transakcje ──
    local history, transactions = {}, {}
    for _, h in ipairs(c.history) do
        local e = {}
        for k, v in pairs(h) do e[k] = v end
        e.at = asDateTime(h.at)
        history[#history + 1] = e
    end
    for _, t in ipairs(c.tx) do
        transactions[#transactions + 1] = {
            type = t.type, amount = t.amount, by = t.by, label = t.label, reason = t.reason, at = asShort(t.at)
        }
    end

    -- ── katalog pojazdów ──
    local catalog = {}
    for _, v in ipairs(Config.VehicleShop.catalog) do
        catalog[#catalog + 1] = { model = v.model, name = v.name, category = v.category, price = v.price, expressFee = v.expressFee }
    end

    local ownProducts
    if jc.supplier then
        ownProducts = {}
        for _, p in ipairs(data.Products(job)) do ownProducts[#ownProducts + 1] = p end
    end

    return {
        job         = { name = job, label = data.JobLabel(job) },
        me          = { ssn = s.ssn, firstname = s.firstname, lastname = s.lastname, grade = s.grade },
        features    = jc.features or {},
        licenseDefs = jc.licenses or {},
        grades      = data.Grades(job),
        salaryMax   = jc.salaryMax,
        webhooks    = c.webhooks,
        employees   = employees,
        funds       = data.Funds(job),
        transactions = transactions,
        history     = history,
        supplier    = job ~= Config.VehicleShop.supplierJob and data.JobLabel(Config.VehicleShop.supplierJob) or '',
        expressFee  = Config.VehicleShop.expressFee,
        catalog     = catalog,
        vehicles    = vehicles,
        orders      = vehicleOrders,
        shop        = {
            suppliers = suppliers,
            offer     = ownProducts and { products = ownProducts } or nil,
            out       = goodsOrders,
            incoming  = incoming,
            companies = companies
        }
    }
end

return data
