local ui = {}
local uiState = false
CurrentPromise = nil

ui.IsUIOpen = function()
    return uiState
end

ui.CloseUI = function(action)
    uiState = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = action,
    })
end

---@param action string
---@param data table
---@param ... any
---@return boolean
ui.openUI = function(action, data, ...)
    if CurrentPromise then
        CurrentPromise:resolve(false)
        CurrentPromise = nil
    end
    uiState = true
    SetNuiFocus(true, true)
    CurrentPromise = promise.new()
    SendNUIMessage({
        action = action,
        data = data,
        ...
    })

    return Citizen.Await(CurrentPromise)
end

RegisterNUICallback('close', function(data, cb)
    ui.CloseUI(data.action)
    if CurrentPromise then
        CurrentPromise:resolve(data.success)
        CurrentPromise = nil
    end
    cb('ok')
end)

return ui