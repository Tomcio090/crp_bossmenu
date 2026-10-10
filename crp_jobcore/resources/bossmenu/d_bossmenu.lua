--[[
    d_bossmenu.lua – konfiguracja bossmenu (klient + serwer)

    Co tu ustawiasz:
      * Config.Jobs        – które firmy mają panel i co w nim jest (licencje, odznaki, wpisy, stawki),
      * Config.Locations   – gdzie stoją punkty panelu (strefa ox_target + krzesło),
      * Config.Db          – nazwy kolumn w tabeli graczy,
      * Config.Cache       – ile danych siedzi w pamięci serwera i jak często leci do bazy,
      * Config.VehicleShop – zamówienia pojazdów dla firmy,
      * Config.Goods       – zamówienia towarów między firmami (B2B).
]]

local Config = {}

-- ─────────────────────────────────────────────────────────────
--  PODSTAWY
-- ─────────────────────────────────────────────────────────────
Config.Command         = 'bossmenu'   -- komenda otwierająca panel (false = wyłączona)
Config.RequireLocation = false        -- true = panel tylko stojąc przy punkcie z Config.Locations
Config.AllowOffDuty    = true         -- true = panel działa też na pracy „off<job>” (offpolice, offambulance…),
                                      --        false = tylko na służbie (wtedy duty/off-job zamyka panel)
Config.Debug           = false        -- podświetlanie stref ox_target
Config.ShowOtherJobs   = true         -- true = w liście pracowników widać też osoby zatrudnione w tej firmie,
                                      --        ale aktualnie pracujące gdzie indziej (z plakietką „Inna praca: X”)
Config.PlayerAccount   = 'bank'       -- konto gracza przy wpłatach/wypłatach: 'bank' | 'money'

-- ─────────────────────────────────────────────────────────────
--  KRZESŁO / PANEL – blokada „jedna osoba naraz”
--  Panel pilnuje serwer: drugi gracz dostanie komunikat, kto go używa.
-- ─────────────────────────────────────────────────────────────
Config.Panel = {
    singleUser      = true,    -- false = wyłącza blokady (dwóch graczy może używać panelu równocześnie)
    seatTimeout     = 1800,    -- po ilu sekundach od zajęcia krzesła blokada wygasa (0 = nigdy)
    releaseDistance = 10.0,    -- gdy zajmujący odejdzie dalej niż X m od krzesła, blokada wraca do puli
    animRange       = 60.0     -- w jakim promieniu inni gracze widzą animację siedzenia
}

-- ─────────────────────────────────────────────────────────────
--  BAZA DANYCH – nazwy kolumn w tabeli graczy (ESX: users)
--
--  KAŻDĄ POZYCJĘ MOŻESZ ZAKOMENTOWAĆ – jeżeli nie masz takiej kolumny.
--  Wtedy pole będzie puste w panelu, ale nic się nie wysypie
--  (wcześniej brak `phone` wywalał cały plik s_data.lua przy starcie).
-- ─────────────────────────────────────────────────────────────
Config.Db = {
    -- przedrostek wszystkich tabel zasobu: prefix .. nazwa -> crp_jobcore_bossmenu_members
    -- zmieniasz tutaj (albo dodaj własny), a wszystkie zapytania podłapią nową nazwę
    prefix     = 'crp_jobcore_bossmenu_',

    users      = 'users',
    identifier = 'identifier',    -- bez tego nic nie działa (domyślnie 'identifier')
    firstname  = 'firstname',
    lastname   = 'lastname',
    ssn        = 'ssn',           -- brak kolumny? zakomentuj – zamiast SSN użyjemy identifiera
    -- phone   = 'phone_number'   -- brak kolumny? zakomentuj – telefon będzie pusty
    -- job     = 'job',           -- domyślnie 'job'
    -- grade   = 'job_grade'      -- domyślnie 'job_grade'

    -- migrate = false            -- wyłącza jednorazowe przenoszenie danych ze starych tabel bossmenu_*

    -- licencje: korzystamy z tabel ESX-a (esx_license), żeby widziały je też inne skrypty
    userLicenses = 'user_licenses',   -- nadane licencje: type, owner, time
    licenses     = 'licenses'         -- definicje licencji: type (albo name) + label
}

-- ─────────────────────────────────────────────────────────────
--  CACHE (serwer) – po to, żeby baza nie dostawała zapytań przy każdym otwarciu panelu
-- ─────────────────────────────────────────────────────────────
Config.Cache = {
    saveSeconds    = 60,    -- co ile sekund zrzucać naliczone godziny pracy do bazy (jedno zapytanie na firmę)
    rosterSeconds  = 300,   -- co ile sekund odświeżać listę pracowników przy otwartym panelu (0 = tylko po akcjach)
    refreshSeconds = 30,    -- co ile sekund odświeżać otwarty panel (0 = tylko po akcjach)
    logLimit       = 300,   -- ile ostatnich wpisów historii / transakcji trzymać
    orderLimit     = 150,   -- ile ostatnich zamówień trzymać
    recordLimit    = 3000,  -- ile wpisów dyscyplinarnych / awansów wczytać na firmę
    productsSeconds = 60    -- co ile sekund odświeżać cache oferty (0 = tylko po zmianach w panelu)
}

-- ─────────────────────────────────────────────────────────────
--  LICENCJE (tabele ESX: `licenses` + `user_licenses`)
--  Panel nie trzyma już własnej tabeli licencji – czyta i zapisuje do ESX-a,
--  dzięki czemu licencje widzą inne skrypty (MDT, policejob, esx_license...).
-- ─────────────────────────────────────────────────────────────
Config.Licenses = {
    mustExist    = true,           -- nadanie wymaga definicji typu w tabeli `licenses` (jak w esx_license)
    time         = -1,             -- -1 = bezterminowo (standard ESX)
    removeOnFire = false,          -- czy przy zwolnieniu odbierać licencje z listy danej firmy
    syncResource = 'esx_license'   -- jeśli działa, wołamy jego zdarzenie, żeby gracz online od razu widział zmianę
}

-- ─────────────────────────────────────────────────────────────
--  ZATRUDNIANIE
-- ─────────────────────────────────────────────────────────────
Config.Unemployed          = { job = 'unemployed', grade = 0 }  -- gdzie trafia zwolniony pracownik
Config.HireOnlyUnemployed  = true                               -- true = zatrudniaj tylko osoby bez pracy

-- Nazwa konta firmy w esx_addonaccount
Config.Society = function(job) return 'society_' .. job end

-- ─────────────────────────────────────────────────────────────
--  FIRMY Z PANELEM
--  Dostęp do panelu: gracz musi być w tej pracy i mieć stopień >= minGrade.
--  Bez minGrade panelem zarządza najwyższy stopień danej pracy.
-- ─────────────────────────────────────────────────────────────
Config.Jobs = {
    police = {
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },   -- co pokazać w panelu
        supplier  = false,                                                -- true = firma może publikować ofertę dla innych firm
        licenses  = {
            { id = 'swat', label = 'Jednostka specjalna', icon = 'shield', desc = 'Udział w akcjach specjalnych.' }
        }
    },

    -- Obsługujemy obie popularne nazwy pracy EMS. Usuń alias, którego nie ma w Twoim ESX,
    -- albo ustaw własny minGrade, jeśli próg zarządzania ma być inny niż najwyższy stopień.
    ems = {
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },
        licenses  = {}
    },
    ambulance = {
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },
        licenses  = {}
    },

    mechanic = {
        salaryMax = 150,
        features  = { licenses = true, badges = true, records = true },
        licenses  = {
            { id = 'tow',    label = 'Holowanie (laweta)',  icon = 'car-crane', desc = 'Obsługa lawety i holowanie pojazdów.' },
            { id = 'tuning', label = 'Tuning zaawansowany', icon = 'engine',    desc = 'Modyfikacje silnika i zawieszenia.' },
            { id = 'paint',  label = 'Lakiernictwo',        icon = 'brush',     desc = 'Malowanie i personalizacja nadwozia.' },
            { id = 'weld',   label = 'Spawanie',            icon = 'flame',     desc = 'Naprawy blacharskie i spawalnicze.' }
        }
    },

    centra_autos = {
        salaryMax = 200,
        features  = { licenses = false, badges = false, records = true },
        supplier  = true,
        supplierDesc = 'Salon samochodowy – dostarcza pojazdy innym firmom.',
        licenses  = {}
    }
}

-- ─────────────────────────────────────────────────────────────
--  PUNKTY PANELU (strefa ox_target + krzesło z animacją)
--  Wartości mcoords / bossmenucoords / chaircoords możesz podejrzeć w Config.Debug = true
-- ─────────────────────────────────────────────────────────────
    -- ── PRZYKŁADY na Twój przypadek (odkomentuj, jeśli masz takie prace w ESX) ──
    -- Praca „law” widzi listę policji i szeryfa – szczegóły ustawia się w Config.ViewJobs poniżej.
    --['law'] = {
    --    minGrade = 0,
    --    salaryMax = 250,
    --    features  = { licenses = true, badges = true, records = true },
    --    licenses  = {},
    --    viewJobs  = { police = true, sheriff = true }      -- to samo co w Config.ViewJobs.law
    --},
    --['sheriff'] = {
    --    minGrade = 0,
    --    salaryMax = 180,
    --    features  = { licenses = true, badges = true, records = true },
    --    licenses  = {}
    --},

-- ─────────────────────────────────────────────────────────────
--  PODGLĄD LISTY PRACOWNIKÓW INNYCH PRAC (tylko do czytania)
--
--  Praca po lewej widzi listę pracowników z prac po prawej – bez możliwości
--  zatrudniania, zwalniania czy zmiany stopnia (to nadal robi tylko ich własna firma).
--  Przykład z życia: praca „law” widzi listę policji i szeryfa.
-- ─────────────────────────────────────────────────────────────
Config.ViewJobs = {
    --['law'] = { police = true, sheriff = true },
    --['police'] = { sheriff = true },          -- policja widzi szeryfów
    --['sheriff'] = { police = true },          -- i odwrotnie
}

Config.Locations = {
    ['mrpd'] = {
        job            = 'police',
        mcoords        = vec4(461.4712, -987.8772, 31.2, 0.4353),      -- środek punktu
        distance       = 20.0,                                         -- z jakiej odległości punkt się aktywuje
        bossmenucoords = vec4(461.5347, -986.2550, 30.6604, 180.0223), -- strefa ox_target „Otwórz Boss Menu”
        chaircoords    = vec4(461.7296, -985.3137, 30.4, 305.0)        -- gdzie spawnuje się krzesło
    },
    ['centra_autos'] = {
        job            = 'centra_autos',
        mcoords        = vec4(-924.9637, -1169.8820, 4.9501, 138.3062),      -- środek punktu
        distance       = 20.0,                                         -- z jakiej odległości punkt się aktywuje
        bossmenucoords = vec4(-924.3383, -1167.5292, 4.7838, 196.5054), -- strefa ox_target „Otwórz Boss Menu”
        chaircoords    = vec4(-924.7601, -1166.9054, 4.6, 2.7027)        -- gdzie spawnuje się krzesło
    },

    -- UWAGA: wpis 'mrpd1' (policja) miał IDENTYCZNE współrzędne co 'mrpd' (centra_autos), przez co
    -- w jednym miejscu pojawiały się dwa krzesła i dwie strefy ox_target. Wstaw własne współrzędne,
    -- jeśli chcesz osobny punkt dla policji:
    --['mrpd1'] = {
    --    job            = 'police',
    --    mcoords        = vec4(441.5, -982.5, 30.7, 0.0),
    --    distance       = 20.0,
    --    bossmenucoords = vec4(441.5, -982.5, 30.7, 0.0),
    --    chaircoords    = vec4(442.3, -983.1, 30.4, 90.0)
    --}

    -- Punkt dla kilku prac naraz: zamiast `job` podaj `jobs` (klucz = praca, wartość = minimalny stopień).
    --['office'] = {
    --    jobs           = { police = 10, mechanic = 4 },
    --    mcoords        = vec4(-347.1, -133.4, 39.0, 0.0),
    --    distance       = 20.0,
    --    bossmenucoords = vec4(-347.1, -133.4, 39.0, 0.0),
    --    chaircoords    = vec4(-348.2, -134.1, 38.6, 90.0)
    --}
}

-- ─────────────────────────────────────────────────────────────
--  GARAŻ – zamówienia pojazdów dla firmy
--  Zamówienie trafia do firmy-dostawcy, która musi je przyjąć i dostarczyć.
-- ─────────────────────────────────────────────────────────────
Config.VehicleShop = {
    supplierJob = 'centra_autos',
    expressFee  = 3000,       -- domyślna dopłata za szybki transport; firma może ustawić własną per pojazd

    -- Katalogiem pojazdów zarządza firma-dostawca w panelu (zakładka Oferta):
    -- dodaje pojazdy (model + nazwa + cena), ustawia widoczność i dopłatę za szybki transport.
    -- Uwaga: `supplierJob` musi być pracą, która naprawdę istnieje w ESX (tu: centra_autos).
    -- ── DOSTAWA POJAZDÓW „NA ŻYWO” (gdy kupujący NIE wybrał szybkiego transportu) ──
    --  Obsługuje ją osobny zasób (nano skrypt `nano_cd`, w przyszłości własny skrypt CD).
    --  bossmenu tylko przekazuje mu zamówienie i odbiera potwierdzenie oddania aut.
    --  Gdy zasób nie jest uruchomiony, wszystko działa po staremu (auta od razu w garażu).
    delivery = {
        resource       = 'nano_cd',                   -- nazwa zasobu obsługującego dostawę ('' = wyłączone)
        event          = 'crp_cd:server:start',       -- event startu zadania (bossmenu → zasób CD)
        cancelEvent    = 'crp_cd:server:cancel',      -- event anulowania zadania
        resendEvent    = 'crp_cd:server:resend',      -- event ponownego wysłania zadań (np. po restarcie CD)
        manualOverride = false                        -- true = panel może „Dostarczono” nawet przy dostawie fizycznej
    },

    cartMax     = 10,         -- maks. pozycji w koszyku
    plateFormat = 'AAA 000',  -- A = litera, 0 = cyfra (max 8 znaków w ESX)
    -- ── wpis w tabeli `owned_vehicles` (garaż gracza/firmy) ────────────────────────────
    --  Zasób NIE wpisuje nazw kolumn na sztywno: przy pierwszym użyciu czyta strukturę tabeli
    --  (SHOW COLUMNS) i wstawia tylko kolumny, które naprawdę istnieją. Dzięki temu działa i na
    --  klasycznym ESX (`type`, `stored`), i na polskich edycjach (`typ`, `vin`, `state`, `owner_type`…).
    --  Kolumny mające wartość domyślną (state, isPolice, mileage, cansell, owner_type) zostają
    --  na wartościach z bazy – chyba że wypiszesz je w `extra`.
    ownedVehicles = {
        enabled = true,
        table   = 'owned_vehicles',
        type    = 'car',          -- wartość kolumny typu (`typ` w nowszych bazach, `type` w klasycznym ESX)

        -- 'auto'  = tak, jak jest zapisane w innych pojazdach w bazie (zalecane),
        -- 'hash'  = liczba (GetHashKey), 'string' = nazwa modelu, np. "stanier"
        modelFormat = 'auto',
        vin     = nil,            -- nil = wygeneruj 17 znaków, gdy tabela wymaga kolumny `vin`; '' = pomiń
        debug   = false,          -- true = wypisze w konsoli, co dokładnie poszło do owned_vehicles

        -- nazwy kolumn w Twojej tabeli (pierwsza istniejąca wygrywa) – podmień, jeśli masz inne
        columns = {
            owner = { 'owner' }, plate = { 'plate' }, vehicle = { 'vehicle' },
            type = { 'typ', 'type' }, stored = { 'stored' }, vin = { 'vin' }
        },
        -- kolumny, których nie da się wywnioskować (np. flaga garażu policyjnego, stan, numer garażu)
        -- np.: extra = { isPolice = 1, state = 3, garage = 1 }
        extra = {},

        -- właściciel wpisu: pracownik, któremu przydzielono auto, albo konto firmy
        owner   = function(job, identifier) return identifier or ('society:' .. job) end
    },
    seedCatalog = false,      -- jednorazowe przeniesienie listy niżej do oferty dostawcy; false = katalog robisz sam w panelu

    -- Lista poniżej to gotowa podpowiedź (modele z GTA). Przy seedCatalog = false NIE jest nigdzie
    -- przenoszona – wpisujesz pojazdy w panelu (Oferta → Dodaj produkt). Włącz seedCatalog = true
    -- tylko wtedy, gdy chcesz je jednorazowo wgrać do oferty salonu.
    catalog = false
}

-- ─────────────────────────────────────────────────────────────
--  ZAMÓWIENIA TOWARÓW (B2B)
-- ─────────────────────────────────────────────────────────────
Config.Goods = {
    maxLines = 20,       -- maks. pozycji w zamówieniu
    maxQty   = 99,       -- maks. sztuk jednej pozycji
    maxPrice = 100000000, -- maks. cena produktu/dopłaty w ofercie (9 cyfr – wcześniej 1 000 000, czyli 7)

    -- Szybki transport towarów (B2B). Dopłatę za sztukę ustawia dostawca na produkcie
    -- (Oferta → produkt → „Szybki transport (za sztukę)”), a kupujący zaznacza ją w koszyku.
    -- Poniższa wartość to tylko domyślna kwota, gdy produkt nie ma własnej: 0 = brak domyślnej.
    expressFee = 0
}

-- ─────────────────────────────────────────────────────────────
--  HOOKI (serwer)
-- ─────────────────────────────────────────────────────────────

-- Status pracownika w panelu: 'duty' | 'break' | 'off'.
-- Domyślnie czyta state bag `duty`: true/'duty' = na służbie, 'break' = przerwa, false/'off' = poza służbą,
-- brak wartości = gracz online jest traktowany jako na służbie. Podłącz tu swój system służby.
Config.GetDutyStatus = function(src, xPlayer)
    local jobName = xPlayer and xPlayer.job and xPlayer.job.name
    local offBase = type(jobName) == 'string' and jobName:match('^off(.+)$')
    if Config.AllowOffDuty ~= false and offBase and Config.Jobs[offBase] then return 'off' end

    local v = Player(src).state.duty
    if v == 'break' then return 'break' end
    if v == false or v == 'off' then return 'off' end
    return 'duty'
end

-- Wywoływane po oznaczeniu zamówienia towarów jako „Dostarczono”.
-- order = { id, buyerJob, supplierJob, total, items = { { model/name, price, qty } } }
-- Przykład (ox_inventory, stash firmy):
--   for _, it in ipairs(order.items) do exports.ox_inventory:AddItem('society_' .. order.buyerJob, it.itemName, it.qty) end
Config.GoodsDelivery = function(order)
    TriggerEvent('crp_bossmenu:goodsDelivered', order)
end

-- Kolory embedów Discord (webhooki)
Config.Discord = {
    botName = 'CRP Bossmenu',
    colors  = { plus = 5763719, minus = 15548997, commend = 5763719, reprimand = 15548997, promo = 3447003, test = 9807270 }
}

return Config
