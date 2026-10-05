-- ═════════════════════════════════════════════════════════════
--  DANE – schemat bazy, zapytania i budowanie paczki dla UI
-- ═════════════════════════════════════════════════════════════
Data = {}

local COL = Config.Db
local function q(s) return ('`%s`'):format(s) end
local FMT_DT    = '%d.%m.%Y %H:%i'
local FMT_SHORT = '%d.%m %H:%i'
local FMT_D     = '%d.%m.%Y'

-- ───────── schemat ─────────
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

function Data.Install()
    for _, sql in ipairs(SCHEMA) do MySQL.query.await(sql) end
    print('^2[crp_bossmenu]^7 tabele gotowe')
end

-- ───────── zapis: transakcje / historia ─────────
function Data.Tx(job, type_, amount, by, label, reason)
    MySQL.insert.await('INSERT INTO bossmenu_transactions (job, type, amount, by_name, label, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { job, type_, amount, by, label, reason })
end

function Data.Hist(job, by, entry)
    MySQL.insert.await('INSERT INTO bossmenu_history (job, by_name, entry) VALUES (?, ?, ?)', { job, by, json.encode(entry) })
end

function Data.Hooks(job)
    local r = MySQL.scalar.await('SELECT webhooks FROM bossmenu_settings WHERE job = ?', { job })
    local t = r and json.decode(r) or {}
    return { plusminus = t.plusminus or '', commend = t.commend or '', promo = t.promo or '' }
end

function Data.FullName(row) return ('%s %s'):format(row.firstname or '', row.lastname or '') end

-- ───────── odczyt ─────────
local function group(rows, key)
    local out = {}
    for _, r in ipairs(rows) do
        out[r[key]] = out[r[key]] or {}
        table.insert(out[r[key]], r)
    end
    return out
end

function Data.Employees(job, statusFn)
    local rows = MySQL.query.await(([[
        SELECT u.%s AS identifier, u.%s AS firstname, u.%s AS lastname, u.job_grade AS grade, u.%s AS ssn, u.%s AS phone,
               m.identifier AS m_id, m.badge, m.seconds, DATE_FORMAT(m.hired_at, '%s') AS hired_at,
               TIMESTAMPDIFF(MINUTE, COALESCE(m.last_duty, m.hired_at), NOW()) AS last_seen,
               m.note, m.note_by, DATE_FORMAT(m.note_at, '%s') AS note_at
        FROM %s u LEFT JOIN bossmenu_members m ON m.identifier = u.%s AND m.job = ?
        WHERE u.job = ?]]):format(q(COL.identifier), q(COL.firstname), q(COL.lastname), q(COL.ssn), q(COL.phone),
        FMT_D, FMT_DT, q(COL.users), q(COL.identifier)), { job, job })

    local lic = group(MySQL.query.await(([[SELECT identifier, license, DATE_FORMAT(granted_at, '%s') AS at FROM bossmenu_licenses WHERE job = ?]]):format(FMT_D), { job }), 'identifier')
    local rec = group(MySQL.query.await(([[SELECT id, identifier, kind, reason, by_name, DATE_FORMAT(created_at, '%s') AS at,
        void_by, DATE_FORMAT(void_at, '%s') AS void_at, void_reason FROM bossmenu_records WHERE job = ? ORDER BY id DESC LIMIT 3000]]):format(FMT_DT, FMT_DT), { job }), 'identifier')
    local pro = group(MySQL.query.await(([[SELECT identifier, from_grade, to_grade, by_name, reason, DATE_FORMAT(created_at, '%s') AS at
        FROM bossmenu_promotions WHERE job = ? ORDER BY id DESC LIMIT 3000]]):format(FMT_DT), { job }), 'identifier')

    local out, missing = {}, {}
    for _, r in ipairs(rows) do
        local grade, status = r.grade, 'off'
        local x = Bridge.GetPlayerByIdentifier(r.identifier)
        local skip = false
        if x then
            if x.job.name ~= job then skip = true
            else grade = x.job.grade; status = statusFn(x.source, x) end
        end
        if not skip then
            if not r.m_id then missing[#missing + 1] = r.identifier end
            local e = {
                ssn = r.ssn or r.identifier, firstname = r.firstname, lastname = r.lastname, phonenumber = r.phone or '',
                grade = grade, status = status, lastSeen = status == 'off' and (r.last_seen or 0) or 0,
                badge = r.badge, hiredAt = r.hired_at or os.date('%d.%m.%Y'),
                hoursWeek = math.floor(((r.seconds or 0) / 3600) * 10 + 0.5) / 10,
                licenses = {}, records = {}, promotions = {}
            }
            if r.note and r.note ~= '' then e.note = { html = r.note, by = r.note_by or '—', at = r.note_at or '' } end
            for _, l in ipairs(lic[r.identifier] or {}) do e.licenses[#e.licenses + 1] = { id = l.license, at = l.at } end
            for _, c in ipairs(rec[r.identifier] or {}) do
                e.records[#e.records + 1] = { id = c.id, kind = c.kind, by = c.by_name, reason = c.reason, at = c.at,
                    voided = c.void_by and { by = c.void_by, at = c.void_at, reason = c.void_reason } or nil }
            end
            for _, p in ipairs(pro[r.identifier] or {}) do
                e.promotions[#e.promotions + 1] = { from = p.from_grade, to = p.to_grade, by = p.by_name, reason = p.reason, at = p.at }
            end
            out[#out + 1] = e
            e._identifier = r.identifier
        end
    end
    for _, id in ipairs(missing) do   -- pracownicy zatrudnieni poza bossmenu – dopisz z datą „dziś”
        MySQL.insert('INSERT IGNORE INTO bossmenu_members (identifier, job) VALUES (?, ?)', { id, job })
    end
    for _, e in ipairs(out) do e._identifier = nil end
    return out
end

local function decode(s) return s and json.decode(s) or {} end

function Data.OrderRow(r, view)
    local items = decode(r.items)
    local o = { id = (r.kind == 'vehicles' and 'ord-' or 'zam-') .. r.id, kind = r.kind, items = items, total = r.total,
        by = r.by_name, at = r.at, status = r.status }
    if r.kind == 'vehicles' then
        o.note = r.reason                           -- Garaż pokazuje powód odrzucenia jako note
        o.reason = r.reason
    else
        o.note = r.note; o.reason = r.reason
        o.supplier = { job = r.supplier_job, label = Bridge.JobLabel(r.supplier_job) }
    end
    o.buyer = { job = r.buyer_job, label = Bridge.JobLabel(r.buyer_job) }
    if view == 'buyer' and r.kind == 'vehicles' then o.kind = nil; o.buyer = nil end
    return o
end

local function hasAccess(access, job)
    if not access then return true end
    for _, j in ipairs(access) do if j == job then return true end end
    return false
end
Data.HasAccess = hasAccess

function Data.Products(job, onlyActiveFor)
    local rows = MySQL.query.await('SELECT id, name, category, descr, price, active, access FROM bossmenu_products WHERE job = ? ORDER BY id', { job })
    local out = {}
    for _, p in ipairs(rows) do
        local access = p.access and json.decode(p.access) or nil
        if not onlyActiveFor or (p.active == 1 and hasAccess(access, onlyActiveFor)) then
            out[#out + 1] = { id = p.id, name = p.name, category = p.category or '', desc = p.descr or '', price = p.price, active = p.active == 1, access = access }
        end
    end
    return out
end

-- Pełna paczka danych dla gracza (open / update)
function Data.Build(s)
    local job, jc = s.job, Config.Jobs[s.job]
    local vs = Config.VehicleShop
    local grades = Bridge.Grades(job)
    local hist = {}
    for _, h in ipairs(MySQL.query.await(('SELECT entry, by_name, DATE_FORMAT(created_at, \'%s\') AS at FROM bossmenu_history WHERE job = ? ORDER BY id DESC LIMIT 300'):format(FMT_DT), { job })) do
        local e = json.decode(h.entry) or {}
        e.by = h.by_name; e.at = h.at
        hist[#hist + 1] = e
    end
    local tx = {}
    for _, t in ipairs(MySQL.query.await(('SELECT type, amount, by_name, label, reason, DATE_FORMAT(created_at, \'%s\') AS at FROM bossmenu_transactions WHERE job = ? ORDER BY id DESC LIMIT 300'):format(FMT_SHORT), { job })) do
        tx[#tx + 1] = { type = t.type, amount = t.amount, by = t.by_name, label = t.label, reason = t.reason, at = t.at }
    end
    local vehicles = {}
    for _, v in ipairs(MySQL.query.await(([[SELECT v.plate, v.model, v.name, v.category, u.%s AS assigned, DATE_FORMAT(v.assigned_at, '%s') AS assigned_at,
        DATE_FORMAT(v.added_at, '%s') AS added_at FROM bossmenu_vehicles v LEFT JOIN %s u ON u.%s = v.assigned_identifier
        WHERE v.job = ? ORDER BY v.added_at DESC]]):format(q(COL.ssn), FMT_DT, FMT_DT, q(COL.users), q(COL.identifier)), { job })) do
        vehicles[#vehicles + 1] = { plate = v.plate, model = v.model, name = v.name, category = v.category or '', assignedTo = v.assigned, assignedAt = v.assigned_at, addedAt = v.added_at }
    end

    -- zamówienia
    local ordCols = ('id, kind, buyer_job, supplier_job, items, total, status, note, reason, by_name, DATE_FORMAT(created_at, \'%s\') AS at'):format(FMT_DT)
    local orders, out, incoming = {}, {}, {}
    for _, r in ipairs(MySQL.query.await(('SELECT %s FROM bossmenu_orders WHERE buyer_job = ? ORDER BY id DESC LIMIT 150'):format(ordCols), { job })) do
        if r.kind == 'vehicles' then orders[#orders + 1] = Data.OrderRow(r, 'buyer') else out[#out + 1] = Data.OrderRow(r) end
    end
    for _, r in ipairs(MySQL.query.await(('SELECT %s FROM bossmenu_orders WHERE supplier_job = ? ORDER BY id DESC LIMIT 150'):format(ordCols), { job })) do
        incoming[#incoming + 1] = Data.OrderRow(r)
    end

    local suppliers, companies = {}, {}
    for j, c in pairs(Config.Jobs) do
        if j ~= job then
            companies[#companies + 1] = { job = j, label = Bridge.JobLabel(j) }
            if c.supplier then
                local prods = Data.Products(j, job)
                if #prods > 0 then suppliers[#suppliers + 1] = { job = j, label = Bridge.JobLabel(j), desc = c.supplierDesc or '', products = prods } end
            end
        end
    end
    table.sort(suppliers, function(a, b) return a.label < b.label end)
    table.sort(companies, function(a, b) return a.label < b.label end)

    local catalog = {}
    for _, c in ipairs(vs.catalog) do catalog[#catalog + 1] = { model = c.model, name = c.name, category = c.category, price = c.price, expressFee = c.expressFee } end

    return {
        job = { name = job, label = Bridge.JobLabel(job) },
        me = { ssn = s.ssn, firstname = s.firstname, lastname = s.lastname, grade = s.grade },
        features = jc.features or {},
        licenseDefs = jc.licenses or {},
        grades = grades,
        salaryMax = jc.salaryMax,
        webhooks = Data.Hooks(job),
        employees = Data.Employees(job, Config.GetDutyStatus),
        funds = Bridge.GetFunds(job),
        transactions = tx, history = hist,
        supplier = job ~= vs.supplierJob and Bridge.JobLabel(vs.supplierJob) or '',
        expressFee = vs.expressFee, catalog = catalog, vehicles = vehicles, orders = orders,
        shop = { suppliers = suppliers, offer = jc.supplier and { products = Data.Products(job) } or nil, out = out, incoming = incoming, companies = companies }
    }
end
