--[[
    s_bossmenu.lua – wejście serwera (spina moduły)

    s_data.lua – tabele w bazie, cache, zapisy
    s_main.lua – sesje panelu, akcje z UI, odświeżanie

    Wczytanie działa dwutorowo: najpierw `require` (Twój loader),
    a gdy ten nie znajdzie pliku – czytamy go wprost z folderu resource'a.
    Dzięki temu nie ma znaczenia, czy masz te pliki w fxmanifest, czy nie.
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
loadModule('resources.bossmenu.s_data',     's_data.lua',     'crp_bossmenu_s_data')
loadModule('resources.bossmenu.s_main',     's_main.lua',     'crp_bossmenu_s_main')

return {}
