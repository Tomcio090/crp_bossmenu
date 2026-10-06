--[[
    s_data.lua – cała baza danych i cache panelu (tylko serwer)

    Jak to działa (i dlaczego baza jest spokojna):
      1. Dane firmy wczytują się z bazy RAZ – przy pierwszym użyciu (wejście na służbę / otwarcie panelu).
      2. Otwarcie i odświeżenie panelu czytają TYLKO pamięć – zero SELECT-ów.
      3. Akcje (zatrudnienie, stopień, wpis, odznaka, licencja...) zmieniają pamięć
         i od razu zapisują do bazy tylko to, co się zmieniło.
      4. Naliczone godziny pracy lecą do bazy jednym zbiorczym zapytaniem (data.Flush)
         co Config.Cache.saveSeconds – a nie po jednym zapytaniu na gracza.

    Nazwy tabel: Config.Db.prefix .. nazwa (domyślnie crp_jobcore_bossmenu_*).
    Przy pierwszym starcie zasób sam przenosi dane ze starych tabel bossmenu_*, jeśli je znajdzie.

    Nic tu nie trzeba wywoływać ręcznie – reszta dzieje się w s_main.lua.
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
if _G.crp_bossmenu_s_data then return _G.crp_bossmenu_s_data end

local Config = loadModule('resources.bossmenu.d_bossmenu', 'd_bossmenu.lua', 'crp_bossmenu_config')
local ESX = exports['es_extended']:getSharedObject()

local data = {}

local DB  = Config.Db
local LIM = Config.Cache

--┌───────────────────────────────────────────────────────────────────────────┐
--│  KOLUMNY Z CONFIG.Db                                                      │
--│  Każda kolumna jest OPCJONALNA – jeśli jej nie ustawisz (albo zakomentujesz,│
--│  bo nie masz jej w tabeli), nie wywala to zasobu: pole leci jako NULL,     │
--│  a panel pokazuje pustą wartość. Kiedyś brak `phone` wysypywał cały plik.  │
--└───────────────────────────────────────────────────────────────────────────┘
local TICK = string.char(96)
local function wrap(name) return TICK .. (name or '') .. TICK end

-- nazwa kolumny z Config.Db ('' / false / brak wpisu -> wartość domyślna)
local function column(key, default)
    local name = DB[key]
    if name == nil or name == false or name == '' then return default end
    return name
end

local LC  = Config.Licenses or {}                 -- ustawienia licencji (d_bossmenu.lua)
local USERS = column('users', 'users')
local IDENT = column('identifier', 'identifier')   -- bez tego nic nie działa, więc jest domyślne
local SSN   = column('ssn', IDENT)                 -- brak kolumny SSN -> używamy identifiera
local JOB   = column('job', 'job')
local GRADE = column('grade', 'job_grade')

-- tabele ESX-a (nie zakładamy ich sami – tylko z nich korzystamy)
local USER_LICENSES = column('userLicenses', 'user_licenses')   -- nadane licencje
local LICENSES_DEF  = column('licenses', 'licenses')            -- definicje licencji

-- "`kolumna` AS alias" albo "NULL AS alias", gdy kolumny nie ma
local function field(name, alias)
    if not name then return 'NULL AS ' .. alias end
    return ('%s AS %s'):format(wrap(name), alias)
end

-- lista kolumn gracza – sklejona raz, używana w kilku zapytaniach
local USER_COLS = table.concat({
    field(IDENT, 'identifier'),
    field(column('firstname'), 'firstname'),
    field(column('lastname'), 'lastname'),
    field(SSN, 'ssn'),
    field(column('phone'), 'phone')
}, ', ')

-- informacja w konsoli o kolumnach, których nie ma w Config.Db (żeby nie było cichej niespodzianki).
-- `users`, `identifier`, `job`, `grade` mają sensowne wartości domyślne, więc o nich nie krzyczymy.
do
    local missing = {}
    for _, key in ipairs({ 'firstname', 'lastname', 'ssn', 'phone', 'userLicenses', 'licenses' }) do
        if DB[key] == nil or DB[key] == false or DB[key] == '' then missing[#missing + 1] = key end
    end
    if #missing > 0 then
        print(('^3[crp_bossmenu]^7 Config.Db bez kolumn: %s – te pola będą puste w panelu (nie blokuje działania)')
            :format(table.concat(missing, ', ')))
    end
end

-- formaty dat (wszystkie daty w cache trzymamy jako unix timestamp i formatujemy dopiero w payloadzie)
local function asDate(ts)     return ts and os.date('%d.%m.%Y', ts) or '' end
local function asDateTime(ts) return ts and os.date('%d.%m.%Y %H:%M', ts) or '' end
local function asShort(ts)    return ts and os.date('%d.%m %H:%M', ts) or '' end

local function secondsToHours(seconds)
    return math.floor(((seconds or 0) / 3600) * 10 + 0.5) / 10
end

-- Wartości liczbowe z bazy (kolumny INT) trafiają do JSON-a jako liczby, a interfejs
-- porównuje SSN-y, odznaki i numery jako tekst (atrybuty `data-*` są zawsze tekstem).
-- Dlatego wszystko, co jest identyfikatorem, wysyłamy do UI jako string.
local function asText(value)
    if value == nil then return nil end
    return tostring(value)
end

-- Kolumny `TINYINT(1)` (np. active) wracają z bazy raz jako 1/0 (mysql-async), a raz jako
-- true/false (oxmysql ma typecast zgodny z mysql-async). Wszystkie porównania robimy przez
-- flag(), żeby działały w obu przypadkach – inaczej `p.active == 1` jest zawsze fałszywe.
local function flag(value)
    return value == true or value == 1 or value == '1' or value == 'true'
end

-- JSON z kolumn tekstowych (access/grades/licenses) – nigdy nie wywala loadera
local function decodeJson(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= 'table' then return fallback end
    return decoded
end

-- dzieli listę na porcje (żeby zapytanie IN (...) nie było za długie)
local function chunks(list, size)
    local out, current = {}, {}
    for _, value in ipairs(list) do
        current[#current + 1] = value
        if #current >= size then out[#out + 1] = current; current = {} end
    end
    if #current > 0 then out[#out + 1] = current end
    return out
end


-- ═════════════════════════════════════════════════════════════
--  SCHEMAT BAZY
-- ═════════════════════════════════════════════════════════════
-- ═════════════════════════════════════════════════════════════
--  NAZWY TABEL
--  Każda tabela zasobu to Config.Db.prefix .. nazwa (np. crp_jobcore_bossmenu_members).
--  Zmieniasz przedrostek w jednym miejscu w d_bossmenu.lua – reszta podstawia go sama.
-- ═════════════════════════════════════════════════════════════
local PREFIX = (DB.prefix ~= nil and DB.prefix ~= false) and DB.prefix or 'crp_jobcore_bossmenu_'
local function T(name) return PREFIX .. name end

-- UWAGA: tabela licencji NIE jest nasza – to ESX-owe `user_licenses` (patrz data.SetLicense)
local TABLES = { 'members', 'records', 'promotions', 'transactions', 'history',
                 'settings', 'vehicles', 'orders', 'products' }

-- stare nazwy tabel (bossmenu_*) – z nich zasób przenosi dane przy pierwszym starcie
local OLD_PREFIX = 'bossmenu_'


-- ═════════════════════════════════════════════════════════════
--  SCHEMAT BAZY
-- ═════════════════════════════════════════════════════════════
-- ═════════════════════════════════════════════════════════════
--  SCHEMAT BAZY
--  Każda tabela jest opisana raz: `columns` to lista kolumn, `keys` to klucze i indeksy.
--  Z tej samej listy kolumn zasób:
--    * zakłada brakujące tabele (CREATE TABLE IF NOT EXISTS),
--    * dokłada brakujące kolumny w tabelach po starszej wersji (data.AlignSchema),
--  więc nic nie trzeba poprawiać ręcznie w bazie.
-- ═════════════════════════════════════════════════════════════
local TABLES_DEF = {
    members = {
        columns = {
            'identifier VARCHAR(60) NOT NULL',
            'job VARCHAR(50) NOT NULL',
            'hired_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
            'badge INT NULL',
            'seconds INT NOT NULL DEFAULT 0',
            'last_duty DATETIME NULL',
            'note MEDIUMTEXT NULL',
            'note_by VARCHAR(100) NULL',
            'note_at DATETIME NULL'
        },
        keys = { 'PRIMARY KEY (identifier, job)' }
    },

    records = {
        columns = {
            'id INT AUTO_INCREMENT PRIMARY KEY',
            'identifier VARCHAR(60) NOT NULL',
            'job VARCHAR(50) NOT NULL',
            'kind VARCHAR(12) NOT NULL',
            'reason VARCHAR(500) NOT NULL',
            'by_name VARCHAR(100) NOT NULL',
            'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
            'void_by VARCHAR(100) NULL',
            'void_at DATETIME NULL',
            'void_reason VARCHAR(500) NULL'
        },
        keys = { 'INDEX idx_emp (job, identifier)' }
    },

    promotions = {
        columns = {
            'id INT AUTO_INCREMENT PRIMARY KEY',
            'identifier VARCHAR(60) NOT NULL',
            'job VARCHAR(50) NOT NULL',
            'from_grade INT NOT NULL',
            'to_grade INT NOT NULL',
            'by_name VARCHAR(100) NOT NULL',
            'reason VARCHAR(500) NOT NULL',
            'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        },
        keys = { 'INDEX idx_emp (job, identifier)' }
    },

    transactions = {
        columns = {
            'id INT AUTO_INCREMENT PRIMARY KEY',
            'job VARCHAR(50) NOT NULL',
            'type VARCHAR(3) NOT NULL',
            'amount BIGINT NOT NULL',
            'by_name VARCHAR(100) NOT NULL',
            'label VARCHAR(100) NOT NULL',
            'reason VARCHAR(600) NULL',
            'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        },
        keys = { 'INDEX idx_job (job, id)' }
    },

    history = {
        columns = {
            'id INT AUTO_INCREMENT PRIMARY KEY',
            'job VARCHAR(50) NOT NULL',
            'by_name VARCHAR(100) NOT NULL',
            'entry LONGTEXT NOT NULL',
            'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        },
        keys = { 'INDEX idx_job (job, id)' }
    },

    settings = {
        columns = {
            'job VARCHAR(50) NOT NULL PRIMARY KEY',
            'webhooks LONGTEXT NULL'
        }
    },

    vehicles = {
        columns = {
            'plate VARCHAR(12) NOT NULL PRIMARY KEY',
            'job VARCHAR(50) NOT NULL',
            'model VARCHAR(50) NOT NULL',
            'name VARCHAR(100) NOT NULL',
            'category VARCHAR(60) NULL',
            'assigned_identifier VARCHAR(60) NULL',
            'assigned_at DATETIME NULL',
            'added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        },
        keys = { 'INDEX idx_job (job)' }
    },

    orders = {
        columns = {
            'id INT AUTO_INCREMENT PRIMARY KEY',
            'kind VARCHAR(10) NOT NULL',
            'buyer_job VARCHAR(50) NOT NULL',
            'supplier_job VARCHAR(50) NOT NULL',
            'items LONGTEXT NOT NULL',
            'total BIGINT NOT NULL',
            'status VARCHAR(12) NOT NULL DEFAULT \'pending\'',
            'delivery VARCHAR(12) NULL',        -- 'physical' = pojazdy dostarczane lawetą (nano skrypt CD)
            'note VARCHAR(300) NULL',
            'reason VARCHAR(500) NULL',
            'by_name VARCHAR(100) NOT NULL',
            'created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP'
        },
        keys = { 'INDEX idx_buyer (buyer_job, id)', 'INDEX idx_supplier (supplier_job, id)' }
    },

    products = {
        columns = {
            'id INT AUTO_INCREMENT PRIMARY KEY',
            'job VARCHAR(50) NOT NULL',
            'name VARCHAR(100) NOT NULL',
            'category VARCHAR(60) NULL',
            'descr VARCHAR(300) NULL',
            'price BIGINT NOT NULL',
            'active TINYINT(1) NOT NULL DEFAULT 1',
            'access LONGTEXT NULL',
            'model VARCHAR(50) NULL',      -- pojazd: nazwa modelu do spawnu (puste = zwykły towar)
            'express_fee INT NULL'         -- dopłata za szybki transport za sztukę (puste = domyślna z konfiguracji)
        },
        keys = { 'INDEX idx_job (job)' }
    }
}

-- gotowe polecenia CREATE z powyższego opisu
local SCHEMA = {}
for _, name in ipairs(TABLES) do
    local def = TABLES_DEF[name]
    local parts = {}
    for _, column in ipairs(def.columns) do parts[#parts + 1] = column end
    for _, key in ipairs(def.keys or {}) do parts[#parts + 1] = key end
    SCHEMA[#SCHEMA + 1] = ('CREATE TABLE IF NOT EXISTS %s (%s) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4')
        :format(T(name), table.concat(parts, ',\n        '))
end

data.Schema = TABLES_DEF


-- ═════════════════════════════════════════════════════════════
--  MIGRACJA ZE STARYCH TABEL (bossmenu_* → crp_jobcore_bossmenu_*)
--  Robi coś tylko wtedy, gdy stare tabele faktycznie istnieją:
--    * brak nowej tabeli                      → RENAME (dane zostają na miejscu),
--    * nowa istnieje i jest pusta, stara ma   → przepisanie wierszy (INSERT IGNORE ... SELECT),
--      dane
--    * obie mają dane                         → nic nie ruszamy, tylko komunikat w konsoli.
--  Wyłączyć można przez Config.Db.migrate = false.
-- ═════════════════════════════════════════════════════════════
local function tableExists(name)
    return MySQL.scalar.await([[SELECT 1 FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? LIMIT 1]], { name }) ~= nil
end

local function rowCount(name)
    return tonumber(MySQL.scalar.await(('SELECT COUNT(*) AS row_count FROM `%s`'):format(name))) or 0
end

-- kolumny wspólne obu tabelom (stara tabela po starszej wersji mogła mieć ich mniej)
local function sharedColumns(first, second)
    local function columnNames(table)
        local rows = MySQL.query.await([[SELECT COLUMN_NAME FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION]], { table }) or {}
        local list = {}
        for _, row in ipairs(rows) do list[#list + 1] = row.COLUMN_NAME or row.column_name end
        return list
    end

    local inFirst = {}
    for _, columnName in ipairs(columnNames(first)) do inFirst[columnName] = true end

    local out = {}
    for _, columnName in ipairs(columnNames(second)) do
        if inFirst[columnName] then out[#out + 1] = ('`%s`'):format(columnName) end
    end
    return out
end

function data.MigrateTables()
    if DB.migrate == false or PREFIX == OLD_PREFIX then return end

    local renamed, copied, skipped = {}, {}, {}
    for _, name in ipairs(TABLES) do
        local old, new = OLD_PREFIX .. name, T(name)
        if tableExists(old) then
            if not tableExists(new) then
                local ok = pcall(function() MySQL.query.await(('RENAME TABLE `%s` TO `%s`'):format(old, new)) end)
                if ok then renamed[#renamed + 1] = name end
            else
                local oldRows, newRows = rowCount(old), rowCount(new)
                if newRows == 0 and oldRows > 0 then
                    local columns = sharedColumns(old, new)          -- nie kopiujemy SELECT *, bo kolumny mogą się różnić
                    local ok = #columns > 0 and pcall(function()
                        local list = table.concat(columns, ', ')
                        MySQL.query.await(('INSERT IGNORE INTO `%s` (%s) SELECT %s FROM `%s`'):format(new, list, list, old))
                    end)
                    if ok then copied[#copied + 1] = ('%s (%d)'):format(name, oldRows) else skipped[#skipped + 1] = name end
                elseif oldRows > 0 and newRows > 0 then
                    skipped[#skipped + 1] = name
                end
            end
        end
    end

    if #renamed > 0 then
        print(('^2[crp_bossmenu]^7 tabele przeniesione ze starych nazw: %s'):format(table.concat(renamed, ', ')))
    end
    if #copied > 0 then
        print(('^2[crp_bossmenu]^7 dane przepisane ze starych tabel: %s'):format(table.concat(copied, ', ')))
    end
    if #skipped > 0 then
        print(('^3[crp_bossmenu]^7 stare i nowe tabele mają dane jednocześnie (%s) – nic nie ruszam, przenieś ręcznie (patrz NOTATKI.md)')
            :format(table.concat(skipped, ', ')))
    end
end

-- Dokłada brakujące kolumny w tabelach, które zostały założone przez starszą wersję zasobu.
-- Powód: CREATE TABLE IF NOT EXISTS istniejącej tabeli nie zmieni, a wtedy sypie się np.
--   "Unknown column 'void_at' in 'SELECT'".
-- Dokładamy wyłącznie brakujące kolumny – istniejących danych i typów nie ruszamy.
function data.AlignSchema()
    -- jedno zapytanie: które kolumny już są
    local names, placeholders = {}, {}
    for _, name in ipairs(TABLES) do
        names[#names + 1] = T(name)
        placeholders[#placeholders + 1] = '?'
    end
    local ok, rows = pcall(function()
        return MySQL.query.await(([[SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME IN (%s)]]):format(table.concat(placeholders, ', ')), names)
    end)
    if not ok then
        print(('^3[crp_bossmenu]^7 nie mogę sprawdzić kolumn tabel (%s) – pomijam'):format(tostring(rows)))
        return {}
    end
    rows = rows or {}

    local present = {}
    for _, row in ipairs(rows) do
        local table_  = row.TABLE_NAME or row.table_name        -- różne sterowniki zwracają raz tak, raz tak
        local column_ = row.COLUMN_NAME or row.column_name
        if table_ and column_ then
            present[table_] = present[table_] or {}
            present[table_][column_] = true
        end
    end

    local added = {}
    for _, name in ipairs(TABLES) do
        local tableName = T(name)
        local have = present[tableName]
        if have then
            local missing = {}
            for _, definition in ipairs(TABLES_DEF[name].columns) do
                local columnName = definition:match('^([%w_]+)')
                if columnName and not have[columnName] then missing[#missing + 1] = definition end
            end

            if #missing > 0 then
                local ok, e = pcall(function()
                    MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN %s'):format(tableName, table.concat(missing, ', ADD COLUMN ')))
                end)
                if ok then
                    added[#added + 1] = ('%s (+%d)'):format(name, #missing)
                else
                    print(('^1[crp_bossmenu]^7 nie udało się dodać kolumn w %s: %s'):format(tableName, tostring(e)))
                end
            end
        end
    end

    if #added > 0 then
        print(('^2[crp_bossmenu]^7 brakujące kolumny dodane: %s'):format(table.concat(added, ', ')))
    end
    return added
end

-- kolacja, w jakiej mają być tabele bossmenu (taka sama jak w tabeli graczy).
-- Na MariaDB 11+ nowe tabele dostają domyślnie utf8mb4_uca1400_ai_ci, a ESX-owe `users`
-- mają najczęściej utf8mb4_general_ci → łączenie takich kolumn kończy się błędem:
--   "Illegal mix of collations (utf8mb4_general_ci,IMPLICIT) and (utf8mb4_uca1400_ai_ci,IMPLICIT)"
local COLLATION = 'utf8mb4_general_ci'

local function tableCollation(name)
    return MySQL.scalar.await([[SELECT TABLE_COLLATION FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], { name })
end

-- Kolacja musi być z rodziny utf8mb4, bo tabele bossmenu są w utf8mb4.
-- Stare bazy ESX mają czasem utf8 (utf8mb3) / latin1 – wtedy bierzemy odpowiednik w utf8mb4,
-- inaczej ALTER/JOIN poleciałby błędem "COLLATION ... is not valid for CHARACTER SET utf8mb4".
local function normalizeCollation(name)
    if type(name) ~= 'string' or name == '' then return nil end
    if name:match('^utf8mb4_') then return name end
    if name:match('^utf8mb3_') then return 'utf8mb4_' .. name:sub(9) end
    if name:match('^utf8_') then return 'utf8mb4_' .. name:sub(6) end
    return nil   -- latin1 / cp1250 / ... -> zostajemy przy bezpiecznym utf8mb4_general_ci
end

-- Ustawia tabelom bossmenu taką kolację, jaką ma tabela graczy (sprawdza się przy starcie).
-- ustala kolację wzorcową (tabela graczy) – używane też przez migrację licencji
function data.DetectCollation()
    COLLATION = normalizeCollation(tableCollation(USERS)) or COLLATION
    return COLLATION
end

function data.AlignCollation()
    -- 1) kolacja tabeli graczy (ESX) – to jest nasz wzorzec
    data.DetectCollation()

    -- 2) wyrównaj tabele bossmenu, jeśli któraś ma inną kolację
    local fixed = {}
    for _, name in ipairs(TABLES) do
        local tableName = T(name)
        local current = tableCollation(tableName)
        if current and COLLATION and current ~= COLLATION and COLLATION:match('^[%w_]+$') then
            local ok, e = pcall(function()
                MySQL.query.await(('ALTER TABLE `%s` CONVERT TO CHARACTER SET utf8mb4 COLLATE %s'):format(tableName, COLLATION))
            end)
            if ok then
                fixed[#fixed + 1] = tableName
            else
                print(('^3[crp_bossmenu]^7 nie udało się wyrównać kolacji %s (%s) – JOIN-y mają własne COLLATE, więc działa dalej')
                    :format(tableName, tostring(e)))
            end
        end
    end
    if #fixed > 0 then
        print(('^2[crp_bossmenu]^7 kolacja %s dla: %s'):format(COLLATION, table.concat(fixed, ', ')))
    end
    return COLLATION
end

function data.Collation() return COLLATION end

-- Każdy krok osobno: gdy jedna operacja na bazie się nie uda (np. brak prawa do ALTER),
-- zasób i tak wystartuje, a w konsoli pojawi się konkretny powód.
function data.Install()
    local function step(label, fn)
        local ok, e = pcall(fn)
        if not ok then print(('^1[crp_bossmenu]^7 %s: %s'):format(label, tostring(e))) end
        return ok
    end

    step('kolacja wzorcowa (tabela graczy)', data.DetectCollation)
    step('przenoszenie danych ze starych tabel', data.MigrateTables)
    step('przenoszenie licencji do user_licenses', data.MigrateLicenses)
    step('zakładanie brakujących tabel', function()
        for _, sql in ipairs(SCHEMA) do MySQL.query.await(sql) end
    end)
    step('dokładanie brakujących kolumn', data.AlignSchema)
    step('katalog pojazdów → oferta dostawcy', data.SeedCatalog)
    step('wyrównanie kolacji', data.AlignCollation)
    step('sprawdzanie definicji licencji', data.CheckLicenseDefinitions)

    print(('^2[crp_bossmenu]^7 tabele gotowe (%s*)'):format(PREFIX))
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
local products = {}    -- products[job] = lista produktów firmy (osobny cache, bo korzystają z niego inne firmy)
local productsAt = {}  -- productsAt[job] = czas wczytania (patrz Config.Cache.productsSeconds)

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

-- pracownicy z tabeli members (odznaki, godziny, notatki, zatrudnienie)
function data.LoadMembers(job)
    local c = get(job)
    local rows = MySQL.query.await(([[
        SELECT identifier, badge, seconds,
               UNIX_TIMESTAMP(hired_at) AS hired_at, UNIX_TIMESTAMP(last_duty) AS last_duty,
               note, note_by, UNIX_TIMESTAMP(note_at) AS note_at
        FROM %s WHERE job = ?]]):format(T('members')), { job })

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

-- gwarantuje wiersz w tabeli members (np. gdy ktoś pracuje, a nigdy nie był w panelu)
function data.EnsureRow(job, identifier)
    local m = data.Member(job, identifier)
    if m.exists then return m end
    MySQL.insert.await('INSERT IGNORE INTO ' .. T('members') .. ' (identifier, job) VALUES (?, ?)', { identifier, job })
    m.exists, m.hired_at = true, os.time()
    return m
end

-- lista pracowników z tabeli graczy (kto jest w tej pracy)
function data.LoadRoster(job)
    local c = get(job)
    local rows = MySQL.query.await(('SELECT %s, %s FROM %s WHERE %s = ?')
        :format(USER_COLS, field(GRADE, 'grade'), wrap(USERS), wrap(JOB)), { job })

    local roster = {}
    for _, r in ipairs(rows or {}) do
        r.ssn = asText(r.ssn) or r.identifier          -- SSN jako tekst (patrz asText)
        r.grade = tonumber(r.grade) or 0
        roster[r.identifier] = r
    end
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
    if c and c.rosterLoaded then
        row.ssn = asText(row.ssn) or row.identifier
        row.grade = tonumber(row.grade) or 0
        c.roster[row.identifier] = row
    end
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

    -- licencje: ESX-owa tabela `user_licenses` (owner = identifier gracza)
    local owners, seen = {}, {}
    for identifier in pairs(c.members or {}) do
        if not seen[identifier] then seen[identifier] = true; owners[#owners + 1] = identifier end
    end
    for identifier in pairs(data.Roster(job)) do
        if not seen[identifier] then seen[identifier] = true; owners[#owners + 1] = identifier end
    end

    for _, group in ipairs(chunks(owners, 400)) do
        local placeholders = {}
        for i = 1, #group do placeholders[i] = '?' end
        local rows = MySQL.query.await(('SELECT owner, type, time FROM %s WHERE owner IN (%s)')
            :format(wrap(USER_LICENSES), table.concat(placeholders, ', ')), group)
        for _, r in ipairs(rows or {}) do
            c.licenses[r.owner] = c.licenses[r.owner] or {}
            c.licenses[r.owner][r.type] = r.time
        end
    end

    local rec = MySQL.query.await(('SELECT id, identifier, kind, reason, by_name, UNIX_TIMESTAMP(created_at) AS at, \
        void_by, UNIX_TIMESTAMP(void_at) AS void_at, void_reason FROM %s \
        WHERE job = ? ORDER BY id DESC LIMIT %d'):format(T('records'), LIM.recordLimit), { job })
    for _, r in ipairs(rec or {}) do
        local list = c.records[r.identifier] or {}; c.records[r.identifier] = list
        list[#list + 1] = r
    end

    local pro = MySQL.query.await(('SELECT identifier, from_grade, to_grade, by_name, reason, UNIX_TIMESTAMP(created_at) AS at \
        FROM %s WHERE job = ? ORDER BY id DESC LIMIT %d'):format(T('promotions'), LIM.recordLimit), { job })
    for _, r in ipairs(pro or {}) do
        local list = c.promos[r.identifier] or {}; c.promos[r.identifier] = list
        list[#list + 1] = r
    end

    local tx = MySQL.query.await(('SELECT type, amount, by_name, label, reason, UNIX_TIMESTAMP(created_at) AS at \
        FROM %s WHERE job = ? ORDER BY id DESC LIMIT %d'):format(T('transactions'), LIM.logLimit), { job })
    for _, r in ipairs(tx or {}) do c.tx[#c.tx + 1] = r end

    local hist = MySQL.query.await(('SELECT entry, by_name, UNIX_TIMESTAMP(created_at) AS at \
        FROM %s WHERE job = ? ORDER BY id DESC LIMIT %d'):format(T('history'), LIM.logLimit), { job })
    for _, r in ipairs(hist or {}) do
        local e = json.decode(r.entry) or {}
        e.by, e.at = r.by_name, r.at
        c.history[#c.history + 1] = e
    end

    local hooks = MySQL.scalar.await('SELECT webhooks FROM ' .. T('settings') .. ' WHERE job = ?', { job })
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
               %s
        FROM %s v
        LEFT JOIN %s u ON u.%s = v.assigned_identifier COLLATE %s
        WHERE v.job = ? ORDER BY v.added_at DESC]]):format(field(SSN, 'assigned_ssn'), T('vehicles'), wrap(USERS), wrap(IDENT), COLLATION), { job })

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
    id, kind, buyer_job, supplier_job, items, total, status, delivery, note, reason, by_name,
    UNIX_TIMESTAMP(created_at) AS at
]]

function data.LoadOrders(job)
    local c = get(job)
    local buyer = MySQL.query.await(('SELECT %s FROM %s WHERE buyer_job = ? ORDER BY id DESC LIMIT %d')
        :format(ORDER_COLS, T('orders'), LIM.orderLimit), { job })
    local supplier = MySQL.query.await(('SELECT %s FROM %s WHERE supplier_job = ? ORDER BY id DESC LIMIT %d')
        :format(ORDER_COLS, T('orders'), LIM.orderLimit), { job })

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
            MySQL.update.await(('INSERT INTO %s (identifier, job, seconds, last_duty) VALUES %s \
                ON DUPLICATE KEY UPDATE seconds = VALUES(seconds), last_duty = VALUES(last_duty)')
                :format(T('members'), table.concat(values, ', ')), params)
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

    MySQL.insert.await(([[INSERT INTO %s (identifier, job) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE hired_at = NOW(), badge = NULL, seconds = 0, last_duty = NULL,
                                note = NULL, note_by = NULL, note_at = NULL]]):format(T('members')), { identifier, job })
end

function data.RemoveMember(job, identifier)
    local c = get(job)
    c.members[identifier] = nil
    c.dirty[identifier] = nil
    c.licenses[identifier] = nil

    MySQL.update.await('DELETE FROM ' .. T('members') .. ' WHERE identifier = ? AND job = ?', { identifier, job })
    -- licencji NIE usuwamy: to wpisy w ESX-owym `user_licenses` (np. prawo jazdy),
    -- które widzą inne skrypty. Przy zwolnieniu odbieramy tylko te z listy firmy –
    -- decyduje Config.Licenses.removeOnFire (obsługa w s_main.lua).
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
    MySQL.update.await('UPDATE ' .. T('members') .. ' SET badge = ? WHERE identifier = ? AND job = ?', { badge, identifier, job })
    return true
end

function data.SetNote(job, identifier, html, by)
    local m = data.EnsureRow(job, identifier)
    if html == '' then
        m.note, m.note_by, m.note_at = nil, nil, nil
        MySQL.update.await('UPDATE ' .. T('members') .. ' SET note = NULL, note_by = NULL, note_at = NULL WHERE identifier = ? AND job = ?', { identifier, job })
    else
        m.note, m.note_by, m.note_at = html, by, os.time()
        MySQL.update.await('UPDATE ' .. T('members') .. ' SET note = ?, note_by = ?, note_at = NOW() WHERE identifier = ? AND job = ?', { html, by, identifier, job })
    end
end

-- Nadanie / odebranie licencji w ESX-owej tabeli `user_licenses`.
-- Zwraca true albo false, powód.
function data.SetLicense(job, identifier, license, on)
    local c = get(job)
    c.licenses[identifier] = c.licenses[identifier] or {}

    if on then
        -- zabezpieczenie jak w esx_license: typu musi być wpisany w tabeli `licenses`
        if LC.mustExist ~= false and not data.LicenseExists(license) then
            return false, ('Licencji "%s" nie ma w tabeli `%s` – najpierw dodaj definicję'):format(license, LICENSES_DEF)
        end

        c.licenses[identifier][license] = LC.time or -1
        MySQL.insert.await(('INSERT INTO %s (type, owner, time) VALUES (?, ?, ?)')
            :format(wrap(USER_LICENSES)), { license, identifier, LC.time or -1 })
        data.SyncLicense(identifier, license, true)
    else
        c.licenses[identifier][license] = nil
        MySQL.update.await(('DELETE FROM %s WHERE owner = ? AND type = ?')
            :format(wrap(USER_LICENSES)), { identifier, license })
        data.SyncLicense(identifier, license, false)
    end

    return true
end

function data.AddRecord(job, identifier, kind, reason, by)
    local id = MySQL.insert.await('INSERT INTO ' .. T('records') .. ' (identifier, job, kind, reason, by_name) VALUES (?, ?, ?, ?, ?)',
        { identifier, job, kind, reason, by })

    local c = get(job)
    local list = c.records[identifier] or {}
    c.records[identifier] = list
    table.insert(list, 1, { id = id, identifier = identifier, kind = kind, reason = reason, by_name = by, at = os.time() })
    return id
end

function data.VoidRecord(job, recordId, by, reason)
    local affected = MySQL.update.await(
        'UPDATE ' .. T('records') .. ' SET void_by = ?, void_at = NOW(), void_reason = ? WHERE id = ? AND job = ? AND void_by IS NULL',
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
    MySQL.insert.await('INSERT INTO ' .. T('promotions') .. ' (identifier, job, from_grade, to_grade, by_name, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { identifier, job, from, to, by, reason })

    local c = get(job)
    local list = c.promos[identifier] or {}
    c.promos[identifier] = list
    table.insert(list, 1, { identifier = identifier, from_grade = from, to_grade = to, by_name = by, reason = reason, at = os.time() })
end

function data.SetJob(identifier, job, grade)
    MySQL.update.await(('UPDATE %s SET %s = ?, %s = ? WHERE %s = ?'):format(wrap(USERS), wrap(JOB), wrap(GRADE), wrap(IDENT)),
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
--  LICENCJE (ESX: `licenses` = definicje, `user_licenses` = nadane)
-- ═════════════════════════════════════════════════════════════

-- W różnych wersjach ESX-a definicje mają kolumnę `type` albo `name` – wykrywamy raz.
local LICENSE_DEF_COLUMN
local function licenseDefColumn()
    if LICENSE_DEF_COLUMN ~= nil then return LICENSE_DEF_COLUMN or nil end

    for _, column_ in ipairs({ 'type', 'name' }) do
        local found = MySQL.scalar.await([[SELECT 1 FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? LIMIT 1]],
            { LICENSES_DEF, column_ })
        if found then
            LICENSE_DEF_COLUMN = column_
            return column_
        end
    end

    LICENSE_DEF_COLUMN = false
    return nil
end

-- czy typ licencji ma definicję w tabeli `licenses`
function data.LicenseExists(license)
    local column_ = licenseDefColumn()
    if not column_ then return false end
    return MySQL.scalar.await(('SELECT 1 FROM %s WHERE %s = ? LIMIT 1')
        :format(wrap(LICENSES_DEF), wrap(column_)), { license }) ~= nil
end

-- Przy starcie wypisuje, których licencji z Config.Jobs nie ma w tabeli `licenses`,
-- i podaje gotowy SQL do wklejenia.
function data.CheckLicenseDefinitions()
    if LC.mustExist == false then return end

    if not licenseDefColumn() then
        print(('^3[crp_bossmenu]^7 nie widzę tabeli `%s` (definicje licencji) – sprawdź Config.Db.licenses, '
            .. 'bez niej nadawanie licencji z panelu nie zadziała'):format(LICENSES_DEF))
        return
    end

    local missing, seen = {}, {}
    for _, jobCfg in pairs(Config.Jobs) do
        for _, def in ipairs(jobCfg.licenses or {}) do
            if def.id and not seen[def.id] and not data.LicenseExists(def.id) then
                seen[def.id] = true
                missing[#missing + 1] = def
            end
        end
    end
    if #missing == 0 then return end

    local values = {}
    for _, def in ipairs(missing) do
        values[#values + 1] = ("('%s', '%s')"):format(def.id, (def.label or def.id):gsub("'", "''"))
    end
    print(('^3[crp_bossmenu]^7 brak definicji licencji w tabeli `%s`: %s')
        :format(LICENSES_DEF, table.concat((function()
            local ids = {}
            for _, def in ipairs(missing) do ids[#ids + 1] = def.id end
            return ids
        end)(), ', ')))
    print(('^3[crp_bossmenu]^7 dodaj je np. tak: INSERT IGNORE INTO %s (type, label) VALUES %s;')
        :format(LICENSES_DEF, table.concat(values, ', ')))
end

-- Jeśli działa esx_license, wołamy jego zdarzenie, żeby gracz online od razu widział zmianę.
-- (Zapis do bazy i tak jest źródłem prawdy – inne skrypty czytają `user_licenses`.)
function data.SyncLicense(identifier, license, add)
    local resource = LC.syncResource
    if not resource or resource == false then return end
    if GetResourceState(resource) ~= 'started' then return end

    local x = ESX.GetPlayerFromIdentifier(identifier)
    if not x or not x.source then return end            -- tylko dla graczy online

    TriggerEvent(add and 'esx_license:addLicense' or 'esx_license:removeLicense', x.source, license)
end

-- Historia panelu → data nadania licencji (żeby UI pokazało „od …”; ESX nie ma takiej kolumny).
local function licenseGrantDates(c)
    local out = {}
    for _, entry in ipairs(c.history) do          -- historia jest od najnowszych
        if entry.type == 'license' and entry.action == 'add' and entry.ssn and entry.license then
            local key = asText(entry.ssn)
            out[key] = out[key] or {}
            if not out[key][entry.license] then out[key][entry.license] = entry.at end
        end
    end
    return out
end

-- Stare licencje panelu (bossmenu_licenses / crp_jobcore_bossmenu_licenses) → `user_licenses`.
-- Nic nie kasujemy: po weryfikacji możesz usunąć starą tabelę ręcznie.
function data.MigrateLicenses()
    local candidates = { T('licenses'), OLD_PREFIX .. 'licenses' }

    for _, old in ipairs(candidates) do
        if tableExists(old) and old ~= USER_LICENSES then
            local count = rowCount(old)
            if count > 0 then
                local col = LICENSE_DEF_COLUMN ~= false and licenseDefColumn() or nil
                local ok, moved = pcall(function()
                    return MySQL.update.await(('INSERT INTO %s (type, owner, time) \n' ..
                        'SELECT l.license, l.identifier, ? FROM %s l \n' ..
                        'WHERE NOT EXISTS (SELECT 1 FROM %s u WHERE u.owner = l.identifier AND u.type = l.license)')
                        :format(wrap(USER_LICENSES), wrap(old), wrap(USER_LICENSES)), { LC.time or -1 })
                end)
                if ok then
                    print(('^2[crp_bossmenu]^7 licencje przepisane z %s do %s (%s wierszy)')
                        :format(old, USER_LICENSES, tostring(moved or count)))
                    if not col then
                        print(('^3[crp_bossmenu]^7 uwaga: dodaj typy licencji do tabeli `%s`, inaczej panel ich nie nada ponownie')
                            :format(LICENSES_DEF))
                    end
                    print(('^3[crp_bossmenu]^7 gdy wszystko działa, możesz usunąć starą tabelę: DROP TABLE `%s`;'):format(old))
                else
                    print(('^3[crp_bossmenu]^7 nie udało się przepisać licencji z %s (%s)'):format(old, tostring(moved)))
                end
            end
        end
    end
end


-- ═════════════════════════════════════════════════════════════
--  HISTORIA / TRANSAKCJE / WEBHOOKI
-- ═════════════════════════════════════════════════════════════

function data.Tx(job, type_, amount, by, label, reason)
    MySQL.insert.await('INSERT INTO ' .. T('transactions') .. ' (job, type, amount, by_name, label, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { job, type_, amount, by, label, reason })

    local c = get(job)
    if c.extrasLoaded then
        table.insert(c.tx, 1, { type = type_, amount = amount, by = by, label = label, reason = reason, at = os.time() })
        if #c.tx > LIM.logLimit then table.remove(c.tx) end
    end
end

function data.Hist(job, by, entry)
    MySQL.insert.await('INSERT INTO ' .. T('history') .. ' (job, by_name, entry) VALUES (?, ?, ?)',
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
    MySQL.insert.await('INSERT INTO ' .. T('settings') .. ' (job, webhooks) VALUES (?, ?) ON DUPLICATE KEY UPDATE webhooks = VALUES(webhooks)',
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
local function normalizePlayer(row)
    if not row then return nil end
    row.ssn = asText(row.ssn) or asText(row.identifier)
    row.grade = tonumber(row.grade) or 0
    return row
end

function data.FindBySsn(ssn)
    return normalizePlayer(MySQL.single.await(('SELECT %s, job, job_grade AS grade FROM %s WHERE %s = ? LIMIT 1')
        :format(USER_COLS, wrap(USERS), wrap(SSN)), { asText(ssn) }))
end

function data.FindByIdentifier(identifier)
    return normalizePlayer(MySQL.single.await(('SELECT %s, job, job_grade AS grade FROM %s WHERE %s = ? LIMIT 1')
        :format(USER_COLS, wrap(USERS), wrap(IDENT)), { identifier }))
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
    local ttl = tonumber(LIM.productsSeconds) or 60
    -- 0 = cache tylko do najbliższej zmiany w panelu; wartość > 0 sprawia, że poprawki zrobione
    -- ręcznie w bazie (SQL) też się wczytają, bez restartu zasobu
    if list and ttl > 0 and (os.time() - (productsAt[job] or 0)) > ttl then list = nil end

    if not list then
        list = {}
        local rows = MySQL.query.await('SELECT id, name, category, descr, price, active, access, model, express_fee FROM ' .. T('products') .. ' WHERE job = ? ORDER BY id', { job })
        for _, p in ipairs(rows or {}) do
            list[#list + 1] = {
                id = p.id, name = p.name, category = p.category or '', desc = p.descr or '',
                price = p.price, active = flag(p.active), access = decodeJson(p.access, nil),
                model = p.model, expressFee = tonumber(p.express_fee)
            }
        end
        products[job] = list
        productsAt[job] = os.time()
    end
    return list
end

function data.InvalidateProducts(job)
    products[job] = nil
    productsAt[job] = nil
end

-- ── KATALOG POJAZDÓW ─────────────────────────────────────────────────────────
-- Katalogiem jest oferta firmy-dostawcy pojazdów (Config.VehicleShop.supplierJob).
-- Pozycja trafia do katalogu, gdy ma wpisany model pojazdu, jest widoczna (active)
-- i firma zamawiająca ma do niej dostęp (access). Cenę i dopłatę za szybki transport
-- ustawia dostawca w panelu (zakładka Oferta).
function data.VehicleCatalog(job)
    local out = {}
    local vs = Config.VehicleShop
    local supplierJob = vs and vs.supplierJob
    if not supplierJob or not Config.Jobs[supplierJob] then return out end

    for _, p in ipairs(data.Products(supplierJob)) do
        if p.model and p.model ~= '' and p.active and data.HasAccess(p, job) then
            out[#out + 1] = {
                model = p.model, name = p.name, category = p.category or '',
                price = p.price, expressFee = p.expressFee
            }
        end
    end
    return out
end

-- Katalog z Config.VehicleShop.catalog (jeśli go zostawisz) trafia do oferty dostawcy TYLKO raz –
-- od tej pory pojazdami zarządza firma w panelu. Wyłączyć: Config.VehicleShop.seedCatalog = false.
function data.SeedCatalog()
    local vs = Config.VehicleShop
    local list = vs and vs.catalog
    if not vs or vs.seedCatalog == false or type(list) ~= 'table' or #list == 0 then return 0 end

    local supplierJob = vs.supplierJob
    if not Config.Jobs[supplierJob] then return 0 end

    for _, p in ipairs(data.Products(supplierJob)) do
        if p.model and p.model ~= '' then return 0 end      -- dostawca ma już swoje pojazdy – nie dopisujemy
    end

    local added = 0
    for _, v in ipairs(list) do
        if v.model and v.name and not data.ProductNameExists(supplierJob, v.name) then
            data.SaveProduct(supplierJob, nil, {
                name = v.name, category = v.category or '', desc = v.desc or '',
                price = v.price, active = true, model = v.model, expressFee = v.expressFee
            })
            added = added + 1
        end
    end
    if added > 0 then
        print(('^2[crp_bossmenu]^7 katalog z konfiguracji przeniesiony do oferty %s (%d %s) – dalej zarządza nim firma w panelu')
            :format(supplierJob, added, added == 1 and 'pozycja' or 'pozycji'))
    end
    return added
end

function data.FindProduct(job, id)
    return MySQL.single.await('SELECT id, name, price, active, access FROM ' .. T('products') .. ' WHERE id = ? AND job = ?', { id, job })
end

function data.ProductNameExists(job, name, id)
    return MySQL.scalar.await('SELECT 1 FROM ' .. T('products') .. ' WHERE job = ? AND LOWER(name) = LOWER(?) AND id <> ? LIMIT 1',
        { job, name, id or 0 }) ~= nil
end

function data.SaveProduct(job, id, p)
    local access = p.access and json.encode(p.access) or nil
    local model = (p.model and p.model ~= '') and p.model or nil
    local expressFee = p.expressFee            -- nil = domyślna dopłata z Config.VehicleShop.expressFee

    if id then
        MySQL.update.await('UPDATE ' .. T('products') .. ' SET name = ?, category = ?, descr = ?, price = ?, active = ?, access = ?, model = ?, express_fee = ? WHERE id = ? AND job = ?',
            { p.name, p.category, p.desc, p.price, p.active and 1 or 0, access, model, expressFee, id, job })
    else
        id = MySQL.insert.await('INSERT INTO ' .. T('products') .. ' (job, name, category, descr, price, active, access, model, express_fee) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { job, p.name, p.category, p.desc, p.price, p.active and 1 or 0, access, model, expressFee })
    end
    data.InvalidateProducts(job)
    return id
end

function data.DeleteProduct(job, id)
    MySQL.update.await('DELETE FROM ' .. T('products') .. ' WHERE id = ? AND job = ?', { id, job })
    data.InvalidateProducts(job)
end


-- ═════════════════════════════════════════════════════════════
--  ZAMÓWIENIA (pojazdy + towary)
-- ═════════════════════════════════════════════════════════════

function data.NewOrder(kind, buyerJob, supplierJob, items, total, by, note)
    local id = MySQL.insert.await(
        'INSERT INTO ' .. T('orders') .. ' (kind, buyer_job, supplier_job, items, total, note, by_name) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { kind, buyerJob, supplierJob, json.encode(items), total, note, by })

    -- dorzucamy zamówienie do pamięci obu firm (jeśli już wczytana) – bez ponownego SELECT-a
    local row = { id = id, kind = kind, buyer_job = buyerJob, supplier_job = supplierJob, items = items,
        total = total, status = 'pending', delivery = nil, note = note, reason = nil, by_name = by, at = os.time() }

    local buyerCache = cache[buyerJob]
    if buyerCache and buyerCache.orders.buyerLoaded then table.insert(buyerCache.orders.buyer, 1, row) end

    local supplierCache = cache[supplierJob]
    if supplierCache and supplierCache.orders.supplierLoaded then table.insert(supplierCache.orders.supplier, 1, row) end

    return id
end

-- field = 'buyer_job' albo 'supplier_job'
function data.GetOrder(id, kind, field, job)
    return MySQL.single.await(('SELECT id, kind, buyer_job, supplier_job, items, total, status, delivery FROM %s \
        WHERE id = ? AND %s = ? AND kind = ?'):format(T('orders'), field), { id, job, kind })
end

-- bez filtra pracy – używa tego fizyczna dostawa pojazdów (nano skrypt CD)
function data.GetOrderRaw(id, kind)
    return MySQL.single.await(('SELECT id, kind, buyer_job, supplier_job, items, total, status, delivery FROM %s \
        WHERE id = ? AND kind = ?'):format(T('orders')), { id, kind })
end

-- 'physical' = zamówienie pojazdów realizowane lawetą; nil = zwykła dostawa
function data.SetOrderDelivery(id, value, buyerJob, supplierJob)
    MySQL.update.await(('UPDATE %s SET delivery = ? WHERE id = ?'):format(T('orders')), { value, id })

    for _, target in ipairs({ buyerJob, supplierJob }) do
        local c = target and cache[target]
        if c then
            for _, list in ipairs({ c.orders.buyer, c.orders.supplier }) do
                for _, order in ipairs(list) do if order.id == id then order.delivery = value end end
            end
        end
    end
end

function data.SetOrderStatus(id, field, job, from, to, reason, buyerJob, supplierJob)
    local affected = MySQL.update.await(('UPDATE %s SET status = ?, reason = COALESCE(?, reason) \
        WHERE id = ? AND %s = ? AND status = ?'):format(T('orders'), field), { to, reason, id, job, from })
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
    MySQL.insert.await('INSERT INTO ' .. T('vehicles') .. ' (plate, job, model, name, category) VALUES (?, ?, ?, ?, ?)',
        { plate, job, model, name, category })

    local c = get(job)
    if c.vehiclesLoaded then
        table.insert(c.vehicles, 1, { plate = plate, model = model, name = name, category = category, added_at = os.time() })
    end
end

function data.SetVehicleOwner(job, plate, identifier, ssn)
    MySQL.update.await('UPDATE ' .. T('vehicles') .. ' SET assigned_identifier = ?, assigned_at = NOW() WHERE plate = ?',
        { identifier, plate })

    local c = get(job)
    for _, v in ipairs(c.vehicles) do
        if v.plate == plate then
            v.assigned_identifier, v.assigned_ssn = identifier, asText(ssn)
            v.assigned_at = identifier and os.time() or nil
            break
        end
    end
end

-- ── wpis w `owned_vehicles` (garaż) ─────────────────────────────────────────
--  UWAGA: nazwy kolumn w tej tabeli różnią się między wersjami skryptów garażu:
--    • klasyczne ESX:  owner, plate, vehicle, type, stored
--    • polskie edycje: owner, vehicle, owner_type, state, plate, vehicleid, ZlomTime,
--                      typ, glovebox, trunk, fakeplate, garage, ssn, vin, isPolice, mileage, cansell
--  Dlatego nie wpisujemy niczego na sztywno: przy pierwszym użyciu czytamy strukturę tabeli
--  (SHOW COLUMNS) i budujemy INSERT wyłącznie z kolumn, które naprawdę istnieją. Kolumny z wartością
--  domyślną (state, isPolice, mileage, cansell, owner_type, typ…) zostawiamy bazie.
local function vehicleCfg() return Config.VehicleShop.ownedVehicles end

local ov = { cols = nil, modelStyle = nil }    -- cache: struktura tabeli + format modelu w istniejących wpisach

local function ovTable()
    local cfg = vehicleCfg()
    return (cfg and cfg.table) or 'owned_vehicles'
end

local function ovPick(cols, list)
    for _, name in ipairs(list or {}) do if cols[name] then return name end end
    return nil
end

local function ovColumns()
    if ov.cols then return ov.cols end
    ov.cols = {}
    local ok, rows = pcall(function() return MySQL.query.await('SHOW COLUMNS FROM `' .. ovTable() .. '`') end)
    if ok and type(rows) == 'table' then
        for _, r in ipairs(rows) do
            local name = r and (r.Field or r.field)
            if name then
                ov.cols[name] = {
                    null    = (r.Null or r.null) == 'YES',
                    default = (r.Default ~= nil) and r.Default or r.default,
                    extra   = tostring(r.Extra or r.extra or '')
                }
            end
        end
    else
        print(('^1[crp_bossmenu] nie mogłem odczytać struktury tabeli `%s` – wpis do garażu pominięty^7'):format(ovTable()))
    end
    return ov.cols
end

-- zresetuj cache, gdy zmienisz tabelę/nazwy kolumn w configu (albo po edycji struktury w bazie)
function data.InvalidateVehicleSchema()
    ov.cols, ov.modelStyle = nil, nil
end

-- format zapisu modelu bierzemy z tego, co już jest w bazie (hash/liczba czy nazwa modelu)
local function ovModelValue(model)
    local cfg = vehicleCfg()
    local style = cfg.modelFormat
    if style == 'auto' or style == nil then
        if ov.modelStyle == nil then
            ov.modelStyle = 'hash'
            local ok, row = pcall(function()
                return MySQL.single.await(('SELECT vehicle FROM `%s` WHERE vehicle IS NOT NULL AND vehicle <> "" LIMIT 1'):format(ovTable()))
            end)
            local raw = (ok and type(row) == 'table') and (row.vehicle or row.VEHICLE) or nil
            if raw then
                local decoded = select(2, pcall(json.decode, raw))
                if type(decoded) == 'table' and decoded.model ~= nil then
                    ov.modelStyle = (type(decoded.model) == 'string') and 'string' or 'hash'
                    print(('^2[crp_bossmenu]^7 owned_vehicles: model zapisuję jak w istniejących wpisach (%s)'):format(ov.modelStyle))
                end
            else
                print('^3[crp_bossmenu]^7 owned_vehicles: brak innych pojazdów do porównania – zapisuję model jako hash. '
                    .. 'Jeśli auto nie pojawi się w garażu, ustaw Config.VehicleShop.ownedVehicles.modelFormat = "string"')
            end
        end
        style = ov.modelStyle
    end
    if style == 'string' then return model end
    return GetHashKey(model)
end

-- 17 znaków: litery (bez I, O, Q) + cyfry – taki sam zestaw jak w prawdziwym VIN
local function ovVin()
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789'
    local t = {}
    for i = 1, 17 do local n = math.random(#chars); t[i] = chars:sub(n, n) end
    return table.concat(t)
end

function data.GrantVehicle(job, plate, model)
    local cfg = vehicleCfg()
    if not cfg.enabled then return end

    local cols = ovColumns()
    if not next(cols) then return end          -- brak tabeli/uprawnień – nie sypiemy błędami w pętli

    local c = cfg.columns or {}
    local fields, params, used = {}, {}, {}
    local function set(name, value)
        if not name or used[name] or not cols[name] or value == nil then return end
        used[name] = true
        fields[#fields + 1] = '`' .. name .. '`'
        params[#params + 1] = value
    end

    set(ovPick(cols, c.owner or { 'owner' }), cfg.owner(job, nil))
    set(ovPick(cols, c.plate or { 'plate' }), plate)
    set(ovPick(cols, c.vehicle or { 'vehicle' }), json.encode({ model = ovModelValue(model), plate = plate }))
    set(ovPick(cols, c.type or { 'typ', 'type' }), cfg.type)
    set(ovPick(cols, c.stored or { 'stored' }), 1)

    -- dodatkowe kolumny z configu (np. isPolice = 1, state = 3, garage = 1)
    for name, value in pairs(cfg.extra or {}) do
        set(name, type(value) == 'function' and value(job, plate, model) or value)
    end

    -- kolumny wymagane (NOT NULL bez wartości domyślnej), których jeszcze nie ustawiliśmy:
    -- `vin` umiemy wygenerować, o pozostałych mówimy wprost w konsoli
    local missing = {}
    for name, def in pairs(cols) do
        if not used[name] and not def.null and def.default == nil and not def.extra:find('auto_increment') then
            if name == ovPick(cols, c.vin or { 'vin' }) and cfg.vin ~= '' then set(name, cfg.vin or ovVin())
            else missing[#missing + 1] = name end
        end
    end
    if #missing > 0 then
        table.sort(missing)
        print(('^1[crp_bossmenu] tabela `%s` wymaga kolumn bez wartości domyślnej: %s – dopisz je w Config.VehicleShop.ownedVehicles.extra (np. extra = { %s = 1 }), inaczej pojazd nie trafi do garażu^7')
            :format(ovTable(), table.concat(missing, ', '), missing[1]))
        return
    end

    local marks = {}
    for i = 1, #fields do marks[i] = '?' end

    local ok, err = pcall(function()
        MySQL.insert.await(('INSERT INTO `%s` (%s) VALUES (%s)'):format(ovTable(), table.concat(fields, ', '), table.concat(marks, ', ')), params)
    end)
    if not ok then
        print('^1[crp_bossmenu] owned_vehicles:^7', err)
    elseif cfg.debug then
        print(('^2[crp_bossmenu]^7 %s (%s) → %s (%s)'):format(model, plate, ovTable(), table.concat(fields, ', ')))
    end
end

function data.VehicleOwner(job, plate, identifier)
    local cfg = vehicleCfg()
    if not cfg.enabled then return end
    pcall(function()
        MySQL.update.await(('UPDATE `%s` SET owner = ? WHERE plate = ?'):format(ovTable()), { cfg.owner(job, identifier), plate })
    end)
end

function data.NewPlate()
    for _ = 1, 50 do
        local plate = Config.VehicleShop.plateFormat
            :gsub('A', function() return string.char(math.random(65, 90)) end)
            :gsub('0', function() return tostring(math.random(0, 9)) end)

        local taken = MySQL.scalar.await('SELECT 1 FROM ' .. T('vehicles') .. ' WHERE plate = ?', { plate })
        if not taken then
            local ok, r = pcall(function() return MySQL.scalar.await(('SELECT 1 FROM `%s` WHERE plate = ?'):format(ovTable()), { plate }) end)
            if not ok or not r then return plate end
        end
    end
    return nil
end


-- ═════════════════════════════════════════════════════════════
--  PACZKA DLA UI (to leci do klienta przy otwarciu i odświeżeniu)
-- ═════════════════════════════════════════════════════════════
-- ── dopasowanie gracza do listy pracowników ─────────────────────────────────
--  Gracz online pokazuje się TYLKO na liście pracy, w której aktualnie pracuje –
--  ale „aktualnie” liczymy przez baseJob (offpolice → police), bo inaczej osoba
--  po zejściu ze służby znikała ze wszystkich list naraz.
--  Gdy ma inną pracę z naszego configu, pokazujemy ją jako plakietkę (Config.ShowOtherJobs).
local function playerJob(x)
    local name = x and x.job and x.job.name
    if type(name) ~= 'string' or name == '' then return nil end
    if Config.Jobs[name] then return name end
    if Config.AllowOffDuty == false then return name end
    local stripped = name:gsub('^off', '')
    if stripped ~= name and Config.Jobs[stripped] then return stripped end
    return name
end

--  nil = osoba nie pasuje do tej listy, '' = pasuje, 'Nazwa pracy' = pracuje gdzie indziej
local function jobMismatch(cur, job)
    if not cur or cur == job then return '' end
    if Config.ShowOtherJobs ~= false and Config.Jobs[cur] then return data.JobLabel(cur) end
    return nil
end

local function buildEmployee(c, job, identifier, u, granted)
    local m = c.members[identifier]

    -- gracz online ma zawsze aktualny stopień/status; osoba pracująca gdzie indziej dostaje plakietkę
    local grade, status, otherJob = u.grade, 'off', nil
    local x = ESX.GetPlayerFromIdentifier(identifier)
    if x then
        local other = jobMismatch(playerJob(x), job)
        if other == nil then return nil end          -- inna/nieznana praca → nie należy do tej listy
        otherJob = other ~= '' and other or nil
        grade, status = x.job.grade, otherJob and 'off' or Config.GetDutyStatus(x.source, x)
    end

    local seconds  = m and m.seconds or 0
    local lastSeen = m and (m.last_duty or m.hired_at) or nil

    local e = {
        ssn         = asText(u.ssn) or identifier,      -- zawsze tekst: UI dopasowuje pracownika po SSN
        firstname   = u.firstname or '',
        lastname    = u.lastname or '',
        phonenumber = u.phone and asText(u.phone) or '',
        grade       = tonumber(grade) or 0,
        status      = status,
        lastSeen    = status == 'off' and math.max(0, math.floor((os.time() - (lastSeen or os.time())) / 60)) or 0,
        badge       = m and m.badge ~= nil and tonumber(m.badge) or nil,
        hiredAt     = asDate((m and m.hired_at) or os.time()),
        hoursWeek   = secondsToHours(seconds),
        otherJob    = otherJob,                        -- 'Nazwa pracy', gdy aktualnie pracuje gdzie indziej
        licenses    = {}, records = {}, promotions = {}
    }

    if m and m.note and m.note ~= '' then
        e.note = { html = m.note, by = m.note_by or '—', at = asDateTime(m.note_at) }
    end

    -- licencje z ESX-owego `user_licenses`; data nadania z historii panelu (gdy nadano w panelu),
    -- a gdy wpis ma termin ważności (time > 0) – pokazujemy tę datę
    local ssnKey = e.ssn
    for license, timeLeft in pairs(c.licenses[identifier] or {}) do
        local at = granted[ssnKey] and granted[ssnKey][license]   -- unix (wpis z historii panelu)
        local date
        if at then date = asDate(at)
        elseif timeLeft and timeLeft > 0 then date = asDate(timeLeft) end   -- licencja z terminem ważności
        e.licenses[#e.licenses + 1] = { id = license, at = date or '' }
    end
    table.sort(e.licenses, function(a, b) return a.id < b.id end)
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
        by = r.by_name, at = asDateTime(r.at), status = r.status,
        delivery = r.delivery                 -- 'physical' = dostawa lawetą (nano skrypt CD)
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

-- ── podgląd listy pracowników innych prac (Config.ViewJobs / Config.Jobs[job].viewJobs) ──
--  Tylko do czytania: bez licencji, wpisów i awansów (te należą do ich własnej firmy).
local function buildRelated(x, job)
    local grade, status, otherJob = x.grade, 'off', nil
    local p = ESX.GetPlayerFromIdentifier(x.identifier)
    if p then
        local other = jobMismatch(playerJob(p), job)
        if other == nil then return nil end
        otherJob = other ~= '' and other or nil
        grade, status = p.job.grade, otherJob and 'off' or Config.GetDutyStatus(p.source, p)
    end

    local m = data.Member(job, x.identifier)
    return {
        ssn = asText(x.ssn) or x.identifier, firstname = x.firstname or '', lastname = x.lastname or '',
        phonenumber = x.phone and asText(x.phone) or '', grade = tonumber(grade) or 0, status = status,
        otherJob = otherJob, online = p ~= nil,
        hoursWeek = secondsToHours(m and m.seconds or 0),
        hiredAt = asDate((m and m.hired_at) or os.time())
    }
end

-- lista prac, które ta praca może podglądać: { { job, label }, ... }
function data.ViewJobList(job)
    local jc = Config.Jobs[job] or {}
    local map = Config.ViewJobs and Config.ViewJobs[job]
    if not map and type(jc.viewJobs) == 'table' then map = jc.viewJobs end

    local out = {}
    if type(map) == 'table' then
        for other, on in pairs(map) do
            if on and other ~= job and Config.Jobs[other] then
                out[#out + 1] = { job = other, label = data.JobLabel(other) }
            end
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function buildRelatedGroups(job)
    local groups = {}
    for _, def in ipairs(data.ViewJobList(job)) do
        local list = {}
        for _, x in pairs(data.Roster(def.job)) do
            local e = buildRelated(x, def.job)
            if e then list[#list + 1] = e end
        end
        table.sort(list, function(a, b)
            if a.grade ~= b.grade then return a.grade > b.grade end
            return (a.lastname .. a.firstname) < (b.lastname .. b.firstname)
        end)
        groups[#groups + 1] = { job = def.job, label = def.label, employees = list }
    end
    return groups
end

function data.Build(s)
    local job, jc = s.job, Config.Jobs[s.job]
    local c = data.Prepare(job)
    local orders = data.Orders(job)

    -- ── pracownicy ──
    local employees = {}
    local granted = licenseGrantDates(c)
    for identifier, u in pairs(c.roster) do
        local e = buildEmployee(c, job, identifier, u, granted)
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
            assignedTo = asText(v.assigned_ssn), assignedAt = asDateTime(v.assigned_at), addedAt = asDateTime(v.added_at)
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
                    -- pozycje z modelem pojazdu obsługuje Garaż (katalog), nie zamówienia towarowe
                    if p.active and hasAccess(p.access, job) and not (p.model and p.model ~= '') then
                        list[#list + 1] = p
                    end
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

    -- ── katalog pojazdów (oferta firmy-dostawcy: widoczność, ceny i dopłaty ustawiane w panelu) ──
    local catalog = data.VehicleCatalog(job)

    local ownProducts
    if jc.supplier then
        ownProducts = {}
        for _, p in ipairs(data.Products(job)) do ownProducts[#ownProducts + 1] = p end
    end

    return {
        job         = { name = job, label = data.JobLabel(job) },
        me          = { ssn = asText(s.ssn) or '', firstname = s.firstname, lastname = s.lastname,
                        grade = tonumber(s.grade) or 0 },
        features    = jc.features or {},
        licenseDefs = jc.licenses or {},
        grades      = data.Grades(job),
        salaryMax   = jc.salaryMax,
        webhooks    = c.webhooks,
        employees   = employees,
        related     = buildRelatedGroups(job),        -- listy innych prac (tylko do czytania)
        maxPrice    = (Config.Goods and Config.Goods.maxPrice) or 100000000,
        funds       = data.Funds(job),
        transactions = transactions,
        history     = history,
        supplier    = job ~= Config.VehicleShop.supplierJob and data.JobLabel(Config.VehicleShop.supplierJob) or '',
        expressFee  = Config.VehicleShop.expressFee,      -- domyślna dopłata, gdy produkt nie ma własnej
        goodsExpressFee = (Config.Goods and Config.Goods.expressFee) or 0,   -- to samo dla zamówień towarowych
        vehicleSupplier = job == Config.VehicleShop.supplierJob,
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

_G.crp_bossmenu_s_data = data
return data
