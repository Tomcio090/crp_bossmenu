local ESX = exports["es_extended"]:getSharedObject()

local function GetNewJob(jobname)
    if string.sub(jobname, 1, 3) == "off" then
        return string.sub(jobname, 4)
    else
        return "off" .. jobname
    end
end

lib.callback.register('crp_jobcore:server:duty', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    local currentJob = xPlayer.job.name
    local newJob = GetNewJob(currentJob)
    local grade = xPlayer.job.grade

    xPlayer.setJob(newJob, grade)
    
    return true
end)