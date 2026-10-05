-- ═════════════════════════════════════════════════════════════
--  BRIDGE – wszystko, co dotyka frameworka (ESX) w jednym miejscu.
--  Chcesz przenieść zasób na inny core / konto firmy? Zmieniasz tylko ten plik.
-- ═════════════════════════════════════════════════════════════
ESX = exports['es_extended']:getSharedObject()

Bridge = {}
U = {}

-- ───────── narzędzia ─────────
local function strlen(s) return utf8.len(s) or #s end

function U.int(v, min, max)
    v = tonumber(v)
    if not v or v ~= math.floor(v) or v ~= v then return nil end
    if min and v < min then return nil end
    if max and v > max then return nil end
    return math.floor(v)
end

-- tekst: przycięty, bez znaków sterujących; nil gdy nie jest stringiem albo za długi
function U.str(v, maxLen)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[\0-\8\11\12\14-\31]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and strlen(v) > maxLen then return nil end
    return v
end

function U.len(s) return strlen(s or '') end

function U.plural(n, one, few, many)
    if n == 1 then return one end
    if n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) then return few end
    return many
end

function U.log(...) if Config.Debug then print('^3[crp_bossmenu]^7', ...) end end
function U.err(msg) return { ok = false, error = msg } end

-- HTML notatki: zostawiamy tylko bezpieczne znaczniki i usuwamy z nich wszystkie atrybuty
local ALLOWED = { p = 1, br = 1, strong = 1, b = 1, em = 1, i = 1, u = 1, s = 1, h1 = 1, h2 = 1, h3 = 1, ul = 1, ol = 1, li = 1, blockquote = 1 }
function U.sanitizeHtml(html)
    html = tostring(html or ''):gsub('[\1\2]', '')
    html = html:gsub('<[^>]*>', function(tag)
        local slash, name = tag:match('^<(/?)%s*([%w]+)')
        name = name and name:lower()
        if name and ALLOWED[name] then return '\1' .. slash .. name .. '\2' end
        return ''
    end)
    html = html:gsub('<', '&lt;'):gsub('>', '&gt;')
    html = html:gsub('\1', '<'):gsub('\2', '>')
    return html
end

-- ───────── gracz / praca ─────────
function Bridge.GetPlayer(src) return ESX.GetPlayerFromId(src) end
function Bridge.GetPlayerByIdentifier(id) return ESX.GetPlayerFromIdentifier(id) end

function Bridge.JobLabel(job) return (ESX.Jobs[job] and ESX.Jobs[job].label) or job end

function Bridge.Grades(job)
    local out, j = {}, ESX.Jobs[job]
    if not j then return out end
    for g, d in pairs(j.grades) do
        out[#out + 1] = { id = tonumber(g), name = d.label or d.name, salary = tonumber(d.salary) or 0 }
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Bridge.BossGrade(job)
    local m = 0
    for _, g in ipairs(Bridge.Grades(job)) do if g.id > m then m = g.id end end
    return m
end

function Bridge.MinGrade(job)
    local c = Config.Jobs[job]
    return (c and c.minGrade) or Bridge.BossGrade(job)
end

function Bridge.CanManage(xPlayer)
    local job = xPlayer and xPlayer.job and xPlayer.job.name
    if not job or not Config.Jobs[job] then return false end
    return xPlayer.job.grade >= Bridge.MinGrade(job)
end

local COL = Config.Db
local function q(s) return ('`%s`'):format(s) end

-- dane gracza z bazy po SSN (działa dla online i offline)
function Bridge.FindBySsn(ssn)
    return MySQL.single.await(('SELECT %s AS identifier, %s AS firstname, %s AS lastname, %s AS ssn, %s AS phone, job, job_grade AS grade FROM %s WHERE %s = ? LIMIT 1')
        :format(q(COL.identifier), q(COL.firstname), q(COL.lastname), q(COL.ssn), q(COL.phone), q(COL.users), q(COL.ssn)), { ssn })
end

function Bridge.FindByIdentifier(identifier)
    return MySQL.single.await(('SELECT %s AS identifier, %s AS firstname, %s AS lastname, %s AS ssn, %s AS phone, job, job_grade AS grade FROM %s WHERE %s = ? LIMIT 1')
        :format(q(COL.identifier), q(COL.firstname), q(COL.lastname), q(COL.ssn), q(COL.phone), q(COL.users), q(COL.identifier)), { identifier })
end

-- ustawia pracę (online przez ESX, zawsze też w bazie)
function Bridge.SetJob(identifier, job, grade)
    MySQL.update.await(('UPDATE %s SET job = ?, job_grade = ? WHERE %s = ?'):format(q(COL.users), q(COL.identifier)), { job, grade, identifier })
    local x = Bridge.GetPlayerByIdentifier(identifier)
    if x then x.setJob(job, grade) end
    return x and x.source or nil
end

function Bridge.SetSalary(job, grade, salary)
    MySQL.update.await('UPDATE job_grades SET salary = ? WHERE job_name = ? AND grade = ?', { salary, job, grade })
    local g = ESX.Jobs[job] and ESX.Jobs[job].grades[tostring(grade)]
    if g then g.salary = salary end
    for _, x in pairs(ESX.GetExtendedPlayers('job', job)) do          -- od razu dla graczy online
        if x.job.grade == grade then x.job.grade_salary = salary end
    end
end

-- ───────── konto firmy (esx_addonaccount) ─────────
local function account(job)
    local acc
    TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society(job), function(a) acc = a end)
    return acc
end

function Bridge.GetFunds(job)
    local a = account(job)
    return a and math.floor(a.money) or 0
end

-- zwraca false gdy brak konta/środków; operacja jest atomowa (bez yield między sprawdzeniem a pobraniem)
function Bridge.RemoveFunds(job, amount)
    local a = account(job)
    if not a or a.money < amount then return false end
    a.removeMoney(amount)
    return true
end

function Bridge.AddFunds(job, amount)
    local a = account(job)
    if not a then return false end
    a.addMoney(amount)
    return true
end

-- ───────── konto gracza ─────────
function Bridge.PlayerMoney(xPlayer) return xPlayer.getAccount(Config.PlayerAccount).money end
function Bridge.PlayerRemove(xPlayer, amount) xPlayer.removeAccountMoney(Config.PlayerAccount, amount) end
function Bridge.PlayerAdd(xPlayer, amount) xPlayer.addAccountMoney(Config.PlayerAccount, amount) end

-- ───────── pojazdy (owned_vehicles) ─────────
local function plateExists(plate)
    if MySQL.scalar.await('SELECT 1 FROM bossmenu_vehicles WHERE plate = ?', { plate }) then return true end
    local ok, r = pcall(function() return MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ?', { plate }) end)
    return ok and r ~= nil
end

function Bridge.NewPlate()
    local fmt = Config.VehicleShop.plateFormat
    for _ = 1, 50 do
        local p = fmt:gsub('A', function() return string.char(math.random(65, 90)) end):gsub('0', function() return tostring(math.random(0, 9)) end)
        if not plateExists(p) then return p end
    end
    return nil
end

function Bridge.GrantVehicle(job, plate, model)
    local cfg = Config.VehicleShop.ownedVehicles
    if not cfg.enabled then return end
    local ok, e = pcall(function()
        MySQL.insert.await('INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, 1)',
            { cfg.owner(job, nil), plate, json.encode({ model = GetHashKey(model), plate = plate }), cfg.type })
    end)
    if not ok then print('^1[crp_bossmenu] owned_vehicles insert failed:^7', e) end
end

-- zmiana właściciela w owned_vehicles po przydziale / odebraniu (identifier = nil -> konto firmy)
function Bridge.VehicleOwner(job, plate, identifier)
    local cfg = Config.VehicleShop.ownedVehicles
    if not cfg.enabled then return end
    pcall(function() MySQL.update.await('UPDATE owned_vehicles SET owner = ? WHERE plate = ?', { cfg.owner(job, identifier), plate }) end)
end

function Bridge.RemoveVehicleRecord(plate) end   -- miejsce na ewentualną obsługę usuwania auta (nieużywane)

-- ───────── powiadomienia ─────────
function Bridge.Notify(src, text, tone)
    TriggerClientEvent('crp_bossmenu:client:notify', src, text, tone or 'info')
end
