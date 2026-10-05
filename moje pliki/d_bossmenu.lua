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
Config.Debug           = false        -- podświetlanie stref ox_target
Config.PlayerAccount   = 'bank'       -- konto gracza przy wpłatach/wypłatach: 'bank' | 'money'

-- ─────────────────────────────────────────────────────────────
--  BAZA DANYCH – nazwy kolumn w tabeli graczy (ESX: users)
-- ─────────────────────────────────────────────────────────────
Config.Db = {
    users      = 'users',
    identifier = 'identifier',
    firstname  = 'firstname',
    lastname   = 'lastname',
    ssn        = 'ssn',
    --phone      = 'phone_number'
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
    recordLimit    = 3000   -- ile wpisów dyscyplinarnych / awansów wczytać na firmę
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
        minGrade = 0,
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },   -- co pokazać w panelu
        supplier  = false,                                                -- true = firma może publikować ofertę dla innych firm
        licenses  = {
            { id = 'swat', label = 'Jednostka specjalna', icon = 'shield', desc = 'Udział w akcjach specjalnych.' }
        }
    },

    ems = {
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

    cardealer = {
        salaryMax = 200,
        features  = { licenses = false, badges = false, records = true },
        supplier  = true,
        supplierDesc = 'Akcesoria i dokumenty dla właścicieli pojazdów.',
        licenses  = {}
    }
}

-- ─────────────────────────────────────────────────────────────
--  PUNKTY PANELU (strefa ox_target + krzesło z animacją)
--  Wartości mcoords / bossmenucoords / chaircoords możesz podejrzeć w Config.Debug = true
-- ─────────────────────────────────────────────────────────────
Config.Locations = {
    ['mrpd'] = {
        job            = 'police',
        mcoords        = vec4(461.4712, -987.8772, 31.2, 0.4353),      -- środek punktu
        distance       = 20.0,                                         -- z jakiej odległości punkt się aktywuje
        bossmenucoords = vec4(461.5347, -986.2550, 30.6604, 180.0223), -- strefa ox_target „Otwórz Boss Menu”
        chaircoords    = vec4(461.7296, -985.3137, 30.4, 305.0)        -- gdzie spawnuje się krzesło
    }

    -- Przykład drugiego punktu:
    -- ['mechanic'] = {
    --     job            = 'mechanic',
    --     mcoords        = vec4(-347.1, -133.4, 39.0, 0.0),
    --     distance       = 20.0,
    --     bossmenucoords = vec4(-347.1, -133.4, 39.0, 0.0),
    --     chaircoords    = vec4(-348.2, -134.1, 38.6, 90.0)
    -- }
}

-- ─────────────────────────────────────────────────────────────
--  GARAŻ – zamówienia pojazdów dla firmy
--  Zamówienie trafia do firmy-dostawcy, która musi je przyjąć i dostarczyć.
-- ─────────────────────────────────────────────────────────────
Config.VehicleShop = {
    supplierJob = 'cardealer',
    expressFee  = 3000,       -- dopłata za szybki transport (za pojazd); można nadpisać per pojazd
    cartMax     = 10,         -- maks. pozycji w koszyku
    plateFormat = 'AAA 000',  -- A = litera, 0 = cyfra (max 8 znaków w ESX)
    ownedVehicles = {
        enabled = true,
        type    = 'car',
        -- właściciel wpisu w owned_vehicles: pracownik, któremu przydzielono auto, albo konto firmy
        owner   = function(job, identifier) return identifier or ('society:' .. job) end
    },
    catalog = {
        { model = 'flatbed',      name = 'MTL Flatbed',         category = 'Pojazdy serwisowe', price = 42000 },
        { model = 'towtruck',     name = 'Vapid Tow Truck',     category = 'Pojazdy serwisowe', price = 38000 },
        { model = 'utillitruck3', name = 'Utility Truck',       category = 'Pojazdy serwisowe', price = 26000 },
        { model = 'speedo',       name = 'Vapid Speedo',        category = 'Dostawcze',         price = 21000 },
        { model = 'burrito3',     name = 'Declasse Burrito',    category = 'Dostawcze',         price = 19000 },
        { model = 'bison',        name = 'Bravado Bison',       category = 'Pickupy',           price = 31000 },
        { model = 'sadler',       name = 'Vapid Sadler',        category = 'Pickupy',           price = 17000 },
        { model = 'sandking',     name = 'Vapid Sandking',      category = 'Terenowe',          price = 54000 },
        { model = 'caracara2',    name = 'Vapid Caracara 4x4',  category = 'Terenowe',          price = 72000, expressFee = 6500 },
        { model = 'schafter2',    name = 'Benefactor Schafter', category = 'Osobowe',           price = 28000 },
        { model = 'buffalo',      name = 'Bravado Buffalo',     category = 'Osobowe',           price = 195000 }
    }
}

-- ─────────────────────────────────────────────────────────────
--  ZAMÓWIENIA TOWARÓW (B2B)
-- ─────────────────────────────────────────────────────────────
Config.Goods = {
    maxLines = 20,       -- maks. pozycji w zamówieniu
    maxQty   = 99,       -- maks. sztuk jednej pozycji
    maxPrice = 1000000   -- maks. cena produktu w ofercie
}

-- ─────────────────────────────────────────────────────────────
--  HOOKI (serwer)
-- ─────────────────────────────────────────────────────────────

-- Status pracownika w panelu: 'duty' | 'break' | 'off'.
-- Domyślnie czyta state bag `duty`: true/'duty' = na służbie, 'break' = przerwa, false/'off' = poza służbą,
-- brak wartości = gracz online jest traktowany jako na służbie. Podłącz tu swój system służby.
Config.GetDutyStatus = function(src, xPlayer)
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
