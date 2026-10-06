--[[
    c_bossmenu.lua – wejście klienta (spina moduły)

    c_main.lua – punkty, animacja krzesła, panel NUI
    Komenda: Config.Command (domyślnie /bossmenu).
]]

local function loadModule(requirePath, fileName, cacheKey)
    local cached = _G[cacheKey]
    if type(cached) == 'table' then return cached end

    local ok, mod = pcall(require, requirePath)
    if not ok or type(mod) ~= 'table' then
        local source = LoadResourceFile(GetCurrentResourceName(), fileName)
        if not source then
            error(('[crp_bossmenu] nie mogę wczytać %s – sprawdź, czy plik jest w folderze resource'):format(fileName))
        end
        mod = ((load or loadstring)(source, '@' .. fileName))()
    end

    _G[cacheKey] = mod
    return mod
end

loadModule('resources.bossmenu.d_bossmenu', 'd_bossmenu.lua', 'crp_bossmenu_config')
loadModule('resources.bossmenu.c_main',     'c_main.lua',     'crp_bossmenu_c_main')

return {}
