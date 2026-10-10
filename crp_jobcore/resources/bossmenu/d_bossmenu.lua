local Config = {}

Config.Command         = false
Config.RequireLocation = true
Config.AllowOffDuty    = false
Config.Debug           = false
Config.ShowOtherJobs   = true
Config.PlayerAccount   = 'money'

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
    -- phone   = 'phone_number'   -- brak kolumny? zakomentuj – numer weźmiemy z tabeli telefonu (niżej)
    -- job     = 'job',           -- domyślnie 'job'
    -- grade   = 'job_grade'      -- domyślnie 'job_grade'

    -- migrate = false            -- wyłącza jednorazowe przenoszenie danych ze starych tabel bossmenu_*

    -- licencje: korzystamy z tabel ESX-a (esx_license), żeby widziały je też inne skrypty
    userLicenses = 'user_licenses',   -- nadane licencje: type, owner, time
    licenses     = 'licenses',        -- definicje licencji: type (albo name) + label

    -- ─────────────────────────────────────────────────────────────
    --  TELEFONY – numer pracownika z tabeli skryptu telefonu (LB Phone: `phone_phones`)
    --
    --  Numer dopasowujemy po charidzie gracza – tym samym, który zapisujemy w
    --  crp_jobcore_bossmenu_members.identifier. Gdy jedna postać ma kilka numerów,
    --  bierzemy ten używany najpóźniej (`lastSeen`), a przy remisie większe `order`.
    --  Numer z tej tabeli ma pierwszeństwo nad kolumną `phone` z tabeli graczy;
    --  gdy nic nie znajdziemy, zostaje właśnie ona (albo pole puste).
    --  Odświeża się razem z listą pracowników (Config.Cache.rosterSeconds wyżej).
    --
    --  Chcesz wyłączyć? Ustaw phones = false.
    -- ─────────────────────────────────────────────────────────────
    phones = {
        table    = 'phone_phones',   -- tabela telefonu
        number   = 'phone_number',   -- kolumna z numerem
        lastSeen = 'last_seen',      -- kolumna „kiedy ostatnio używany” ('' = bez sortowania)

        -- gdzie skrypt trzyma charid gracza (LB Phone zależy to od trybu telefonów-przedmiotów):
        id       = 'id',             -- bez metadanych: id = identifier gracza (jedna komórka na postać)
        owner    = 'owner_id',       -- z metadanymi: owner_id = identifier gracza, id = unikalny telefon
        -- match = 'id'              -- wymuszamy jedną kolumnę ('id' albo 'owner'); domyślnie szukamy w obu

        -- rozstrzygnięcie remisu w `lastSeen`: wygrywa większa wartość
        -- order = 'id'
    }
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
    removeOnFire = true,          -- czy przy zwolnieniu odbierać licencje z listy danej firmy
    syncResource = 'esx_license'   -- jeśli działa, wołamy jego zdarzenie, żeby gracz online od razu widział zmianę
}

-- ─────────────────────────────────────────────────────────────
--  ZATRUDNIANIE
-- ─────────────────────────────────────────────────────────────
Config.Unemployed          = { job = 'unemployed', grade = 0 }  -- gdzie trafia zwolniony pracownik
Config.HireOnlyUnemployed  = true                               -- true = zatrudniaj tylko osoby bez pracy

-- Nazwa konta firmy w esx_addonaccount
Config.Society = function(job) return 'society_' .. job end

Config.Jobs = {
    police = {
        minGrade = 13,
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },
        supplier  = false,
        licenses  = {
            { id = 'swat', label = 'Jednostka specjalna', icon = 'shield', desc = 'Udział w akcjach specjalnych.' }
        }
    },
    sheriff = {
        minGrade = 9,
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },
        supplier  = false,
        licenses  = {
            { id = 'swat', label = 'Jednostka specjalna', icon = 'shield', desc = 'Udział w akcjach specjalnych.' }
        }
    },
    law = {
        minGrade = 0,
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },
        supplier  = false,
        licenses  = {
            { id = 'swat', label = 'Jednostka specjalna', icon = 'shield', desc = 'Udział w akcjach specjalnych.' }
        },
        -- praca „law” przełącza panel na policję i szeryfa i zarządza nimi jak swoją firmą
        -- (ludzie, stawki, finanse, garaż, zamówienia, historia) — to samo co Config.ManageJobs.law
        manageJobs = { police = true, sheriff = true },
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
    -- Praca „law” ZARZĄDZA policją i szeryfem (pełny panel: ludzie, stawki, finanse, garaż).
    -- Można to ustawić tutaj (manageJobs) albo w Config.ManageJobs poniżej.
    --['law'] = {
    --    minGrade = 0,
    --    salaryMax = 250,
    --    features  = { licenses = true, badges = true, records = true },
    --    licenses  = {},
    --    manageJobs = { police = true, sheriff = true }     -- to samo co w Config.ManageJobs.law
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
--  Do czytania można też dodać `viewJobs` w Config.Jobs[job].
-- ─────────────────────────────────────────────────────────────
Config.ViewJobs = {
    --['police'] = { sheriff = true },          -- policja widzi szeryfów
    --['sheriff'] = { police = true },          -- i odwrotnie
}

-- ─────────────────────────────────────────────────────────────
--  ZARZĄDZANIE INNYMI PRACAMI (pełny panel, nie podgląd)
--
--  Praca po lewej może przełączyć panel na pracę po prawej i zarządzać nią
--  dokładnie tak, jakby to była jej własna firma: pracownicy (zatrudnianie,
--  zwalnianie, stopnie, odznaki, licencje, wpisy, notatki, godziny), stawki,
--  finanse, garaż, zamówienia i historia. Można też wpisać `manageJobs`
--  bezpośrednio w Config.Jobs[job] (tak jest ustawiona praca „law”).
--
--  Uwaga: szef zarządzanej pracy (najwyższy stopień) nie jest chroniony –
--  praca nadrzędna może go zdegradować lub zwolnić. Chroniona jest tylko
--  własna osoba (nie da się wykonać akcji na sobie).
-- ─────────────────────────────────────────────────────────────
Config.ManageJobs = {
    --['law'] = { police = true, sheriff = true },   -- to samo co Config.Jobs.law.manageJobs
}

Config.Locations = {
    ['mrpd'] = {
        jobs           = { police = 13, sheriff = 9, law = 0 },
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
}

-- ─────────────────────────────────────────────────────────────
--  GARAŻ – zamówienia pojazdów dla firmy
--  Zamówienie trafia do firmy-dostawcy, która musi je przyjąć i dostarczyć.
-- ─────────────────────────────────────────────────────────────
Config.VehicleShop = {
    supplierJob = 'centra_autos',
    expressFee  = 3000,
    delivery = {
        resource       = 'nano_cd',                   -- nazwa zasobu obsługującego dostawę ('' = wyłączone)
        event          = 'crp_cd:server:start',       -- event startu zadania (bossmenu → zasób CD)
        cancelEvent    = 'crp_cd:server:cancel',      -- event anulowania zadania
        resendEvent    = 'crp_cd:server:resend',      -- event ponownego wysłania zadań (np. po restarcie CD)
        manualOverride = false                        -- true = panel może „Dostarczono” nawet przy dostawie fizycznej
    },

    cartMax     = 10,         -- maks. pozycji w koszyku
    plateFormat = 'AAA 000',
    ownedVehicles = {
        enabled = true,
        table   = 'owned_vehicles',
        type    = 'car',
        modelFormat = 'auto',
        vin     = nil,
        debug   = false,
        columns = {
            owner = { 'owner' }, plate = { 'plate' }, vehicle = { 'vehicle' },
            type = { 'typ', 'type' }, stored = { 'stored' }, vin = { 'vin' }
        },
        extra = {},

        owner   = function(job, identifier) return identifier or ('society:' .. job) end
    },
    seedCatalog = false,
    catalog = false
}

Config.Goods = {
    maxLines = 20,
    maxQty   = 99,
    maxPrice = 100000000,
    expressFee = 0
}

Config.GetDutyStatus = function(src, xPlayer)
    local jobName = xPlayer and xPlayer.job and xPlayer.job.name
    local offBase = type(jobName) == 'string' and jobName:match('^off(.+)$')
    if Config.AllowOffDuty ~= false and offBase and Config.Jobs[offBase] then return 'off' end

    local v = Player(src).state.duty
    if v == 'break' then return 'break' end
    if v == false or v == 'off' then return 'off' end
    return 'duty'
end

Config.GoodsDelivery = function(order)
    TriggerEvent('crp_bossmenu:goodsDelivered', order)
end

Config.Discord = {
    botName = 'CRP Bossmenu',
    colors  = { plus = 5763719, minus = 15548997, commend = 5763719, reprimand = 15548997, promo = 3447003, test = 9807270 }
}

return Config
