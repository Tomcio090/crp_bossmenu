# CRP JobCore

Zasób FiveM dla ESX zawierający boss menu NUI, przełączanie służby, szatnię oraz obsługę garażu i zamówień firmowych. Osobny folder `nano_cd` realizuje fizyczne dostawy pojazdów lawetą.

## Wymagania

- `es_extended`
- `oxmysql`
- `ox_lib`
- `ox_target`
- `esx_addonaccount` — konto firmy i operacje finansowe

`fxmanifest.lua` deklaruje zależności i importuje biblioteki oxmysql/ox_lib. Uruchamiaj zasób po jego zależnościach. `nano_cd` jest oddzielnym zasobem; dla dostaw wymaga `es_extended`, `oxmysql`, `ox_lib` oraz działającego `crp_jobcore`.

## Konfiguracja

- Boss menu, prace, progi dostępu, garaż i zamówienia: `resources/bossmenu/d_bossmenu.lua`
- Punkty oraz lista prac ze służbą: `resources/duty/d_duty.lua`
- Punkty szatni: `resources/wardrobe/d_wardrobe.lua`
- Dostawy lawetą: `nano_cd/config.lua`

Dla każdej pracy używającej przełącznika służby dodaj zarówno nazwę pracy, jak i odpowiadającą jej pracę `off<job>` do `d_duty.lua`. Domyślnie panelem zarządza najwyższy stopień ESX; próg można jawnie ustawić przez `minGrade` w `Config.Jobs`.

## Baza danych

Tabele boss menu i szatni są zakładane przy starcie zasobu. `bossmenu.sql` zawiera ich definicje do ręcznego przygotowania lub weryfikacji. Wpisy pojazdów trafiają dodatkowo do skonfigurowanej tabeli `owned_vehicles`; konto firmy musi być dostępne przez `esx_addonaccount`.
