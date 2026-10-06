-- ██████████████████████████████████████████████████████████████████████████████
--  nano_cd / config.lua — CAŁA konfiguracja dostawy lawetą
--
--  Jak to działa (w skrócie):
--   1. Boss menu (crp_jobcore) przyjmuje zamówienie pojazdów, w którym kupujący
--      NIE wybrał szybkiego transportu i wysyła do nas event `crp_cd:server:start`.
--   2. Pracownik CD jedzie na plac (Config.Depot), zaczepia przyczepę `tr2` do auta
--      i po kolei ładuje na nią pojazdy z zamówienia (event z boss menu podaje modele
--      i tablice, więc auto na lawecie ma tę samą tablicę, którą potem dostaje garaż).
--   3. Gdy wszystkie auta są na lawecie, pracownik wiezie je do miejsca odbioru
--      (dla zamówień policji = komenda; adres przysyła boss menu w zadaniu).
--   4. Oddanie pojazdów działa TYLKO w promieniu Config.Handover.radius od tego miejsca.
--      Dopiero wtedy nasz skrypt zgłasza do boss menu „oddane” i zamówienie zmienia
--      status na „dostarczone” + auta trafiają do garażu kupującego.
--
--  Wszystkie współrzędne/model są startowe – dopasuj je w grze (komenda `/pod help`).
-- ██████████████████████████████████████████████████████████████████████████████
Config = {}

Config.Debug = false              -- true = wypisuje w konsoli każdy krok (start/załadunek/oddanie)

-- ── KTO MOŻE REALIZOWAĆ DOSTAWĘ ────────────────────────────────────────────────
Config.Job = 'cd'                 -- nazwa pracy CD/POD w ESX (używana tylko do filtrów i powiadomień)
Config.AllowAnyone = true         -- true = na razie KAŻDY może odprawić dostawę (tryb testowy nano skryptu).
                                  --   Gdy zrobisz pełny skrypt CD: ustaw false i podaj prawdziwą pracę wyżej.
                                  --   Docelowo nie trzeba nic więcej zmieniać – innym skryptom wystarczy
                                  --   export: exports.nano_cd.SetDuty(source, true/false)
Config.RequireDuty = false        -- true = zadanie można wziąć dopiero po `/pod sluzba` (albo po SetDuty)
Config.AutoDuty = true            -- true = wejście w strefę placu automatycznie ustawia „na służbie”
                                  --   (wygodne w testach; w pełnym skrypcie CD ustaw false)

-- ── PLAC (baza CD) ────────────────────────────────────────────────────────────
-- Tu stoi laweta i tu ładuje się pojazdy. Ustaw duży, płaski teren.
Config.Depot = {
    coords = vector3(461.0, -1002.0, 30.4),   -- środek placu (podmień!)
    radius = 45.0,                            -- promień placu (marker + blip + zezwolenie na załadunek)
    blip = { sprite = 477, color = 5, scale = 0.9, label = 'CD – plac załadunkowy' },
    marker = { type = 1, color = { r = 90, g = 160, b = 255, a = 90 }, scale = { x = 6.0, y = 6.0, z = 1.0 } },
}

-- ── LAWETA ────────────────────────────────────────────────────────────────────
-- `tr2` = model przyczepy, na którą ładujemy auta (podany przez Ciebie).
Config.Trailer = {
    model = 'tr2',
    mode  = 'spawn',                          -- 'spawn' = skrypt stawia przyczepę na placu,
                                              -- 'static' = używamy przyczepy, która już stoi w świecie (MLO/mapper)
    coords = vector4(461.0, -1012.0, 30.2, 0.0),  -- gdzie ma stać przyczepa (tryb 'spawn')
    findRadius = 12.0,                        -- tryb 'static': w jakim promieniu szukamy przyczepy
    freeze = false,                           -- true = przyczepa stoi zablokowana (tylko do testów na placu)
    respawnIfMissing = true,                  -- przyczepa zniknęła (wybuchła/restart)? postaw nową na placu

    -- ── GNIAZDA (miejsca na auta) ─────────────────────────────────────────────
    --  offset  = pozycja auta względem przyczepy w jej własnym układzie:
    --            X = prawo/lewo, Y = przód/tył (plus = przód, w stronę zaczepu), Z = góra/dół
    --  rot     = obrót auta względem przyczepy (stopnie); rot.z = 0 → auto ustawione wzdłuż przyczepy
    --  bone    = kość przyczepy (0 = korzeń; zostaw 0, chyba że wiesz, co robisz)
    --
    --  WARTOŚCI STARTOWE – DOPASUJ DO SWOJEJ PRZYCZEPY:
    --   · wsiądź w auto, podjedź na plac, wpisz `/pod attach 1` (auto wskoczy na gniazdo 1),
    --   · popraw je w grze (albo zmień liczby tutaj) i wpisz `/pod slot 1` –
    --     komenda wypisze gotową linijkę offset/rot do wklejenia niżej.
    slots = {
        { offset = vector3(0.0,  2.6, 0.85), rot = vector3(0.0, 0.0, 0.0), bone = 0 },   -- gniazdo 1 (bliżej auta)
        { offset = vector3(0.0, -2.2, 0.85), rot = vector3(0.0, 0.0, 0.0), bone = 0 },   -- gniazdo 2
        -- { offset = vector3(-1.35, 0.2, 1.75), rot = vector3(0.0, 0.0, 0.0), bone = 0 }, -- gniazdo 3 (druga „półka”)
        -- { offset = vector3( 1.35, 0.2, 1.75), rot = vector3(0.0, 0.0, 0.0), bone = 0 }, -- gniazdo 4
    },

    -- ── PARAMETRY DOCZEPIANIA (AttachEntityToEntity) ───────────────────────────
    --  Gdy auto na lawecie drga/odpada/przenika przyczepę, pobaw się tymi dwiema opcjami:
    --   · collision  = true  → auto zderza się z przyczepą (czasem drga)
    --   · softPinning= true  → łagodniejsze doczepienie (mniej drgań, lekko „pływa”)
    attach = {
        softPinning = false,
        collision   = false,
        fixedRot    = true,
        vertexIndex = 2,
        placeOnGroundBeforeAttach = true,   -- najpierw postaw auto na ziemi, potem doczep (mniej szarpania)
        freezeDuringAttach = true,          -- zablokuj auto na moment doczepiania
    },

    autoAttachTruck = true,   -- gdy wsiądziesz autem z haczykiem blisko przyczepy, skrypt sam ją zaczepi
    truckModels = { 'packer', 'phantom', 'hauler', 'hauler2', 'tractor2', 'tractor3' },
}

-- ── AUTO DO CIĄGNIĘCIA LAWETY (pomocnik – możesz jeździć własnym) ─────────────
Config.Truck = {
    mode  = 'none',                                  -- 'none' = nie stawiamy auta; 'spawn' = stawiamy na placu
    model = 'packer',
    coords = vector4(461.0, -1018.0, 30.2, 0.0),     -- tylko dla mode = 'spawn'
    autoAttachTrailer = true,                        -- po wejściu do auta zaczep przyczepę (AttachVehicleToTrailer)
}

-- ── ODDANIE POJAZDÓW (miejsce odbioru) ────────────────────────────────────────
Config.Handover = {
    radius = 25.0,             -- z jakiej odległości od miejsca odbioru wolno oddawać auta

    -- Adres dostawy przysyła boss menu (punkt pracy zamawiającej, np. policja → komenda).
    -- `fallback` działa TYLKO wtedy, gdy zamówienie nie ma adresu (dana praca nie ma
    -- punktu w Config.Locations w d_bossmenu.lua). Podmień na swoją komendę.
    fallback = { x = 441.5, y = -982.5, z = 30.7, heading = 0.0, label = 'Komenda policji' },

    -- Gdzie „zjechać” autami z lawety podczas oddawania (układ względem przyczepy):
    unload = {
        side = 4.5,            -- X – na prawo od przyczepy (ujemne = na lewo)
        firstY = -1.0,         -- Y – gdzie staje pierwsze auto
        spacing = 6.5,         -- co ile stoi kolejne auto
        z = 0.0,               -- dodatek do wysokości (0 = na ziemi)
        useTrailerHeading = true,  -- true = auta ustawione tak jak przyczepa; false = jak gracz
    },

    keepVehicles = true,       -- true = oddane auta zostają na placu (widowiskowo); false = znikają
    maxServerDistance = 90.0,  -- zapas na weryfikację po stronie serwera (dystans gracz ↔ miejsce odbioru)
}

Config.AutoLoad = false                -- true = auta ładują się same, gdy stoisz przy lawecie (tryb testowy;
                                       --   to samo robi komenda `/pod auto` – ładuje jedna po drugiej bez wciskania E)
Config.Keys = { interact = 38 }        -- 38 = E
Config.Progress = { ms = 2500 }        -- czas „kręcenia się” przy załadunku/oddaniu (progres bar)
Config.Persist = true                  -- zapis zadań w bazie (tabela crp_cd_jobs) – przetrwa restart
Config.RefreshSeconds = 30             -- co ile odświeżać listę zadań z boss menu (synchronizacja w tle)

-- ── POWIADOMIENIA ─────────────────────────────────────────────────────────────
-- Działa z ox_lib (jeśli jest), w innym wypadku przez ESX, a na końcu przez chat.
function Config.Notify(text, tone)
    if GetResourceState('ox_lib') == 'started' and lib and lib.notify then
        lib.notify({ title = 'CD / dostawa', description = text, type = tone == 'error' and 'error' or (tone == 'success' and 'success' or 'inform') })
        return
    end
    if ESX and ESX.ShowNotification then ESX.ShowNotification(text) return end
    TriggerEvent('chat:addMessage', { args = { '[CD]', text }, color = { 90, 160, 255 } })
end
