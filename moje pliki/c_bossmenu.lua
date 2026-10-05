local ESX = exports["es_extended"]:getSharedObject()
local ui = require('modules.ui.c_ui')

RegisterCommand('testbossmenu', function()
    local bossmenuData = lib.callback.await('crp_jobcore:bossmenu:server:getBossmenuData', false)
    local closed = ui.openUI('open', {})
end, false)
