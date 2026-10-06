local ESX = exports["es_extended"]:getSharedObject()
local data = require('resources.duty.d_duty')

-- Dozwolone prace (d_duty.jobs) – dzięki tej liście praca typu „officer” nie jest brana za „off…”.
local function allowed(job)
    for _, name in ipairs(data.jobs or {}) do
        if name == job then return true end
    end
    return false
end

-- 'police' -> 'offpolice', 'offpolice' -> 'police'.
-- Zwraca: nazwę nowej pracy + czy gracz wchodzi NA służbę (albo nil = ta praca nie ma służby).
local function GetNewJob(jobname)
    if type(jobname) ~= 'string' or jobname == '' then return nil end

    local isOff = jobname:sub(1, 3) == 'off'
    local base  = isOff and jobname:sub(4) or jobname
    if not allowed(base) then return nil end

    local target = isOff and base or ('off' .. base)
    if not ESX.Jobs[target] then
        print(('^3[crp_jobcore]^7 praca `%s` nie istnieje w ESX – dodaj ją, żeby służba działała'):format(target))
        return nil
    end

    return target, not isOff
end

lib.callback.register('crp_jobcore:server:duty', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local newJob, goingOnDuty = GetNewJob(xPlayer.job.name)
    if not newJob then return false end

    -- stopień musi istnieć w nowej pracy (inaczej ESX zostawiał gracza z nieistniejącym stopniem)
    local grade = xPlayer.job.grade
    local grades = ESX.Jobs[newJob] and ESX.Jobs[newJob].grades
    if grades and not grades[tostring(grade)] then return false end

    xPlayer.setJob(newJob, grade)

    -- status dla innych zasobów (Config.GetDutyStatus w bossmenu czyta właśnie ten statebag;
    -- wcześniej nikt go nie ustawiał, więc każdy online wychodził jako „Na służbie”)
    Player(source).state:set('duty', goingOnDuty and 'duty' or 'off', true)
    if xPlayer.set then xPlayer.set('duty', goingOnDuty and 'duty' or 'off') end

    return true
end)
