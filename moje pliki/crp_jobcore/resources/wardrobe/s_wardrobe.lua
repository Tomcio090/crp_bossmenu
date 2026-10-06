local ESX = exports["es_extended"]:getSharedObject()
local data = require('resources.wardrobe.d_wardrobe')
local clothes = {}

local function HasPlayerLicense(source, licenseName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local hasLicense = false
    MySQL.Sync.fetchAll('SELECT * FROM user_licenses WHERE owner = ? AND type = ?', {
        xPlayer.identifier, licenseName
    }, function(result)
        if result and #result > 0 then
            hasLicense = true
        end
    end)

    return hasLicense
end

CreateThread(function()
    local response = MySQL.query.await('SELECT `id`, `components`, `props`, `pedmodel`, `job`, `clothesName`, `grades`, `licenses` FROM `crp_jobcore_wardrobe`')
    if not response then return end

    for _, v in ipairs(response) do
        if not clothes[v.job] then clothes[v.job] = {} end
        table.insert(clothes[v.job], {
            id = v.id,
            clothesName = v.clothesName,
            pedmodel = v.pedmodel,
            grades = type(v.grades) == 'string' and json.decode(v.grades) or v.grades,
            licenses = type(v.licenses) == 'string' and json.decode(v.licenses) or v.licenses,
            components = type(v.components) == 'string' and json.decode(v.components) or v.components,
            props = type(v.props) == 'string' and json.decode(v.props) or v.props
        })
    end
end)

lib.callback.register('crp_jobcore:server:getJobs', function(source)
    return ESX.GetJobs()
end)

lib.callback.register('crp_jobcore:server:sendClothesInfo', function(source, components, props, pedmodel, pJob, clothesName, grades, licenses)
    if not source or not components or not props or not pedmodel or not pJob or not clothesName or not grades then 
        return false
    end

    licenses = licenses or {}

    local id = MySQL.insert.await('INSERT INTO `crp_jobcore_wardrobe` (components, props, pedmodel, job, clothesName, grades, licenses) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        json.encode(components),
        json.encode(props),
        pedmodel,
        pJob,
        clothesName,
        json.encode(grades),
        json.encode(licenses)
    })

    if id and id > 0 then
        if not clothes[pJob] then clothes[pJob] = {} end
        table.insert(clothes[pJob], {
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

lib.callback.register('crp_jobcore:server:updateOutfitMeta', function(source, id, newName, newGrades, newLicenses)
    if not source or not id or not newName or not newGrades then return false end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    newLicenses = newLicenses or {}

    local affectedRows = MySQL.update.await('UPDATE `crp_jobcore_wardrobe` SET `clothesName` = ?, `grades` = ?, `licenses` = ? WHERE `id` = ?', {
        newName,
        json.encode(newGrades),
        json.encode(newLicenses),
        id
    })

    if affectedRows > 0 then
        local playerJob = xPlayer.job.name
        if clothes[playerJob] then
            for _, outfit in ipairs(clothes[playerJob]) do
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
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local affectedRows = MySQL.update.await('UPDATE `crp_jobcore_wardrobe` SET `components` = ?, `props` = ?, `pedmodel` = ? WHERE `id` = ?', {
        json.encode(components),
        json.encode(props),
        pedmodel,
        id
    })

    if affectedRows > 0 then
        local playerJob = xPlayer.job.name
        if clothes[playerJob] then
            for _, outfit in ipairs(clothes[playerJob]) do
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
    if not source or not id or not jobName then return false end

    local affectedRows = MySQL.update.await('DELETE FROM `crp_jobcore_wardrobe` WHERE `id` = ?', { id })

    if affectedRows > 0 then
        if clothes[jobName] then
            for i, outfit in ipairs(clothes[jobName]) do
                if outfit.id == id then
                    table.remove(clothes[jobName], i)
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

    local playerJob = xPlayer.job.name
    local playerGrade = tostring(xPlayer.job.grade)
    local playerPed = GetEntityModel(GetPlayerPed(source))

    local jobClothes = clothes[playerJob]
    if not jobClothes then return {} end

    local availableClothes = {}

    for _, outfit in ipairs(jobClothes) do
        local targetPedHash = joaat(outfit.pedmodel)
        local isPedValid = (playerPed == targetPedHash)

        local isGradeValid = false
        for _, grade in ipairs(outfit.grades) do
            if grade == playerGrade then
                isGradeValid = true
                break
            end
        end

        local hasAllLicenses = true
        if outfit.licenses and #outfit.licenses > 0 then
            for _, lic in ipairs(outfit.licenses) do
                if not HasPlayerLicense(source, lic) then
                    hasAllLicenses = false
                    break
                end
            end
        end

        if isPedValid and isGradeValid and hasAllLicenses then
            table.insert(availableClothes, outfit)
        end
    end

    return availableClothes
end)