-- ██████████████████████████████████████████████████████████████████████████████
--  nano_cd — nano skrypt dostawy pojazdów (start prac nad skryptem CD / POD)
--
--  To JEST osobny zasób. Wrzuć folder `nano_cd` do `resources/`, dopisz `ensure nano_cd`
--  w server.cfg i gotowe. Gdy w przyszłości zrobisz własny skrypt CD, przeniesiesz do
--  niego te pliki (albo tylko podłączysz się do tych samych eventów – patrz README_PL.txt).
--
--  Nazwa zasobu (folder) MUSI się zgadzać z `Config.VehicleShop.delivery.resource`
--  w d_bossmenu.lua (domyślnie: nano_cd). Po zmianie nazwy folderu popraw też tam.
-- ██████████████████████████████████████████████████████████████████████████████
fx_version 'cerulean'
game 'gta5'

name 'nano_cd'
author 'crp'
description 'Dostawa pojazdów lawetą (tr2) dla zamówień bez szybkiego transportu — start skryptu CD/POD'
version '0.1.0'

lua54 'yes'

shared_script 'config.lua'
server_script 'server.lua'
client_script 'client.lua'

dependencies {
    'oxmysql',        -- zapis trwały zadań (tabela crp_cd_jobs tworzy się sama)
    -- 'es_extended',  -- używamy tylko do powiadomień/uprawnień pracownika CD (opcjonalnie)
}
