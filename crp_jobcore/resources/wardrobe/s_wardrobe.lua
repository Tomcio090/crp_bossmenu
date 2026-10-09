local ESX = exports["es_extended"]:getSharedObject()
local data = require('resources.wardrobe.d_wardrobe')
local clothes = {}
local TABLE_NAME = 'crp_jobcore_wardrobe'

-- Tabela strojów nie jest zakładana w żadnym innym miejscu (bossmenu.sql jest pustym eksportem),
-- więc tworzymy ją idempotentnie przy starcie.
MySQL.ready(function()
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `components` LONGTEXT NULL,
            `props` LONGTEXT NULL,
            `pedmodel` VARCHAR(50) NULL,
            `job` VARCHAR(50) NOT NULL,
            `clothesName` VARCHAR(100) NOT NULL,
            `grades` TEXT NULL,
            `licenses` TEXT NULL,
            INDEX `idx_job` (`job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]):format(TABLE_NAME))
end)

-- JSON z bazy bez wywalania loadera (ręcznie wpisane / niepełne dane)
local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if not ok or type(decoded) ~= 'table' then return fallback end
    return decoded
end

-- Punkt w d_wardrobe.locations jest kluczowany np. 'mrpd', a nie nazwą pracy – szukamy po `job`.
local function jobConfig(job)
    for _, loc in pairs(data.locations or {}) do
        if loc.job and tostring(loc.job):lower() == tostring(job):lower() then return loc end
    end
end

-- Czy gracz ma stopień wymagany do zarządzania szatnią swojej pracy
local function canManage(xPlayer)
    local cfg = jobConfig(xPlayer.job.name)
    if not cfg then return false end
    return xPlayer.job.grade >= (cfg.requiredGrade or 0)
end

local function sameGrade(list, grade)
    for _, value in ipairs(list or {}) do
        if tostring(value) == tostring(grade) then return true end
    end
    return false
end

-- oxmysql udostępnia `MySQL.scalar.await` (zwraca wynik). Poprzednia wersja wołała
-- MySQL.Sync.fetchAll z callbackiem, który NIGDY się nie wykonywał – licencje zawsze wychodziły „brak”.
local function hasLicenses(xPlayer, list)
    for _, license in ipairs(list or {}) do
        local found = MySQL.scalar.await('SELECT 1 FROM user_licenses WHERE owner = ? AND type = ? LIMIT 1',
            { xPlayer.identifier, license })
        if not found then return false end
    end
    return true
end

CreateThread(function()
    local response = MySQL.query.await(('SELECT `id`, `components`, `props`, `pedmodel`, `job`, `clothesName`, `grades`, `licenses` FROM `%s`'):format(TABLE_NAME))
    if not response then return end

    for _, v in ipairs(response) do
        if not clothes[v.job] then clothes[v.job] = {} end
        table.insert(clothes[v.job], {
            id = v.id,
            clothesName = v.clothesName,
            pedmodel = v.pedmodel,
            grades = decode(v.grades, {}),
            licenses = decode(v.licenses, {}),
            components = decode(v.components, {}),
            props = decode(v.props, {})
        })
    end
end)

lib.callback.register('crp_jobcore:server:getJobs', function(source)
    return ESX.GetJobs()
end)

lib.callback.register('crp_jobcore:server:sendClothesInfo', function(source, components, props, pedmodel, pJob, clothesName, grades, licenses)
    if not source or not components or not props or not pedmodel or not clothesName or not grades then
        return false
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Pracę bierzemy z serwera – wcześniej `pJob` przychodził z klienta, więc można było
    -- dodać strój dowolnej firmie. Pilnujemy też progu stopnia z d_wardrobe.
    local job = xPlayer.job.name
    if not canManage(xPlayer) then return false end

    licenses = licenses or {}

    local id = MySQL.insert.await(('INSERT INTO `%s` (components, props, pedmodel, job, clothesName, grades, licenses) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(TABLE_NAME), {
        json.encode(components),
        json.encode(props),
        pedmodel,
        job,
        clothesName,
        json.encode(grades),
        json.encode(licenses)
    })

    if id and id > 0 then
        if not clothes[job] then clothes[job] = {} end
        table.insert(clothes[job], {
            id = id,
            clothesName = clothesName,
            pedmodel = pedmodel,
            grades = grades,
            licenses = licenses,
            components = components,
            props = props
        })
        return true
    end

    return false
end)

lib.callback.register('crp_jobcore:server:getAllClothesForJob', function(source)
    if not source then return {} end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local playerJob = xPlayer.job.name
    return clothes[playerJob] or {}
end)

-- Wspólna weryfikacja: gracz rusza tylko stroje SWOJEJ pracy i tylko od progu stopnia.
local function ownedOutfit(source, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    local job = xPlayer.job.name
    if not canManage(xPlayer) then return nil end

    local row = MySQL.single.await(('SELECT `id`, `job` FROM `%s` WHERE `id` = ?'):format(TABLE_NAME), { id })
    if not row or row.job ~= job then return nil end

    return { xPlayer = xPlayer, job = job, id = row.id }
end

lib.callback.register('crp_jobcore:server:updateOutfitMeta', function(source, id, newName, newGrades, newLicenses)
    if not source or not id or not newName or not newGrades then return false end

    local ctx = ownedOutfit(source, id)
    if not ctx then return false end

    newLicenses = newLicenses or {}

    -- licencje muszą pochodzić z listy dopuszczonej dla tej pracy (nie dowolny tekst z klienta)
    local allowed = {}
    for _, def in ipairs((jobConfig(ctx.job) or {}).licenses or {}) do allowed[tostring(def.value)] = true end
    for _, license in ipairs(newLicenses) do
        if not allowed[tostring(license)] then return false end
    end

    local affectedRows = MySQL.update.await(('UPDATE `%s` SET `clothesName` = ?, `grades` = ?, `licenses` = ? WHERE `id` = ? AND `job` = ?'):format(TABLE_NAME), {
        newName,
        json.encode(newGrades),
        json.encode(newLicenses),
        id,
        ctx.job
    })

    if affectedRows > 0 then
        local list = clothes[ctx.job]
        if list then
            for _, outfit in ipairs(list) do
                if outfit.id == id then
                    outfit.clothesName = newName
                    outfit.grades = newGrades
                    outfit.licenses = newLicenses
                    break
                end
            end
        end
        return true
    end

    return false
end)

lib.callback.register('crp_jobcore:server:updateOutfitAppearance', function(source, id, components, props, pedmodel)
    if not source or not id or not components or not props or not pedmodel then return false end

    local ctx = ownedOutfit(source, id)
    if not ctx then return false end

    local affectedRows = MySQL.update.await(('UPDATE `%s` SET `components` = ?, `props` = ?, `pedmodel` = ? WHERE `id` = ? AND `job` = ?'):format(TABLE_NAME), {
        json.encode(components),
        json.encode(props),
        pedmodel,
        id,
        ctx.job
    })

    if affectedRows > 0 then
        local list = clothes[ctx.job]
        if list then
            for _, outfit in ipairs(list) do
                if outfit.id == id then
                    outfit.components = components
                    outfit.props = props
                    outfit.pedmodel = pedmodel
                    break
                end
            end
        end
        return true
    end

    return false
end)

lib.callback.register('crp_jobcore:server:deleteOutfit', function(source, id, jobName)
    if not source or not id then return false end

    -- `jobName` z klienta jest ignorowany – pracę bierzemy z serwera i dodajemy warunek AND job = ?
    local ctx = ownedOutfit(source, id)
    if not ctx then return false end

    local affectedRows = MySQL.update.await(('DELETE FROM `%s` WHERE `id` = ? AND `job` = ?'):format(TABLE_NAME), { id, ctx.job })

    if affectedRows > 0 then
        local list = clothes[ctx.job]
        if list then
            for i, outfit in ipairs(list) do
                if outfit.id == id then
                    table.remove(list, i)
                    break
                end
            end
        end
        return true
    end

    return false
end)

lib.callback.register('crp_jobcore:server:getClothesInfo', function(source)
    if not source then return {} end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local jobClothes = clothes[xPlayer.job.name]
    if not jobClothes then return {} end

    local availableClothes = {}

    for _, outfit in ipairs(jobClothes) do
        -- Stopień i licencje sprawdzamy na serwerze, a MODEL PEDA na kliencie.
        -- Wcześniej model sprawdzał serwer (GetEntityModel(GetPlayerPed(source))), co dla
        -- zdalnego gracza zwracało 0 – przez to lista dostępnych ubrań była zawsze pusta.
        if sameGrade(outfit.grades, xPlayer.job.grade) and hasLicenses(xPlayer, outfit.licenses) then
            table.insert(availableClothes, outfit)
        end
    end

    return availableClothes
end)
