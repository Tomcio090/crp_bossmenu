Config = {}

-- ─────────────────────────────────────────────────────────────
--  OGÓLNE
-- ─────────────────────────────────────────────────────────────
Config.Command         = 'bossmenu'  -- komenda otwierająca panel (nil = wyłączona)
Config.InteractKey     = 38          -- [E] przy punktach z Config.Locations
Config.RequireLocation = false       -- true = panel da się otworzyć tylko stojąc przy punkcie z Config.Locations
Config.RefreshInterval = 30          -- co ile sekund odświeżać dane otwartych paneli (0 = tylko po akcjach)
Config.PlayerAccount   = 'bank'      -- konto gracza przy wpłacie/wypłacie z konta firmy: 'bank' | 'money'
Config.BossGradeName   = 'boss'      -- (tylko klient) grade_name szefa – do pokazania markera, gdy nie ustawiono minGrade
Config.Debug           = false

-- Nazwy kolumn w tabeli graczy (ESX: users). Zmień pod swoją bazę.
Config.Db = {
    users      = 'users',
    identifier = 'identifier',
    firstname  = 'firstname',
    lastname   = 'lastname',
    ssn        = 'ssn',            -- osobna kolumna z SSN
    phone      = 'phone_number'    -- numer telefonu (w UI: phonenumber)
}

Config.Unemployed = { job = 'unemployed', grade = 0 }   -- gdzie trafia zwolniony pracownik
Config.HireOnlyUnemployed = true                         -- zatrudniać tylko osoby bez pracy (job = Unemployed.job)

-- Nazwa konta firmy w esx_addonaccount
Config.Society = function(job) return 'society_' .. job end

-- ─────────────────────────────────────────────────────────────
--  FIRMY, KTÓRE MAJĄ BOSSMENU
--  Dostęp: grade >= minGrade (domyślnie: najwyższy stopień danej firmy = szef).
--  UWAGA: UI traktuje NAJWYŻSZY stopień jako „szefa” – nie da się go zwolnić ani zmienić.
-- ─────────────────────────────────────────────────────────────
Config.Jobs = {
    mechanic = {
        -- minGrade  = 4,
        salaryMax = 150,                                     -- maks. stawka za godzinę (UI i serwer)
        features  = { licenses = true, badges = true, records = true },
        supplier  = false,                                   -- true = firma może publikować ofertę dla innych firm (aplikacja Zamówienia → Oferta)
        licenses  = {                                        -- id zapisywane w bazie; icon = nazwa ikony z obiektu ICONS w bossmenu.js
            { id = 'tow',    label = 'Holowanie (laweta)',   icon = 'car-crane', desc = 'Obsługa lawety i holowanie pojazdów.' },
            { id = 'tuning', label = 'Tuning zaawansowany',  icon = 'engine',    desc = 'Modyfikacje silnika i zawieszenia.' },
            { id = 'paint',  label = 'Lakiernictwo',         icon = 'brush',     desc = 'Malowanie i personalizacja nadwozia.' },
            { id = 'weld',   label = 'Spawanie',             icon = 'flame',     desc = 'Naprawy blacharskie i spawalnicze.' }
        }
    },

    cardealer = {
        salaryMax = 200,
        features  = { licenses = false, badges = false, records = true },
        supplier  = true,
        supplierDesc = 'Akcesoria i dokumenty dla właścicieli pojazdów.',
        licenses  = {}
    },

    police = {
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },
        licenses  = {
            { id = 'swat', label = 'Jednostka specjalna', icon = 'shield', desc = 'Udział w akcjach specjalnych.' }
        }
    },

    ems = {
        salaryMax = 180,
        features  = { licenses = true, badges = true, records = true },
        licenses  = {}
    }
}

-- Punkty otwierania panelu (marker + [E]). Puste = tylko komenda / export.
Config.Locations = {
    -- { job = 'mechanic', coords = vec3(-347.1, -133.4, 39.0), radius = 2.0 },
}

-- ─────────────────────────────────────────────────────────────
--  GARAŻ – zakup pojazdów dla firmy
--  Zamówienie trafia do firmy-dostawcy (supplierJob), która musi je zaakceptować i dostarczyć.
-- ─────────────────────────────────────────────────────────────
Config.VehicleShop = {
    supplierJob = 'cardealer',
    expressFee  = 3000,        -- dopłata za szybki transport (za pojazd), można nadpisać per pojazd: expressFee = 6500
    cartMax     = 10,
    plateFormat = 'AAA 000',   -- A = litera, 0 = cyfra (max 8 znaków w ESX)
    ownedVehicles = {          -- wpis do owned_vehicles przy dostawie / przydziale
        enabled = true,
        type    = 'car',
        -- właściciel w owned_vehicles: pracownik, któremu przydzielono auto, albo konto firmy
        owner   = function(job, identifier) return identifier or ('society:' .. job) end
    },
    catalog = {
        { model = 'flatbed',      name = 'MTL Flatbed',          category = 'Pojazdy serwisowe', price = 42000 },
        { model = 'towtruck',     name = 'Vapid Tow Truck',      category = 'Pojazdy serwisowe', price = 38000 },
        { model = 'utillitruck3', name = 'Utility Truck',        category = 'Pojazdy serwisowe', price = 26000 },
        { model = 'speedo',       name = 'Vapid Speedo',         category = 'Dostawcze',         price = 21000 },
        { model = 'burrito3',     name = 'Declasse Burrito',     category = 'Dostawcze',         price = 19000 },
        { model = 'bison',        name = 'Bravado Bison',        category = 'Pickupy',           price = 31000 },
        { model = 'sadler',       name = 'Vapid Sadler',         category = 'Pickupy',           price = 17000 },
        { model = 'sandking',     name = 'Vapid Sandking',       category = 'Terenowe',          price = 54000 },
        { model = 'caracara2',    name = 'Vapid Caracara 4x4',   category = 'Terenowe',          price = 72000, expressFee = 6500 },
        { model = 'schafter2',    name = 'Benefactor Schafter',  category = 'Osobowe',           price = 28000 },
        { model = 'buffalo',      name = 'Bravado Buffalo',      category = 'Osobowe',           price = 195000 }
    }
}

-- ─────────────────────────────────────────────────────────────
--  ZAMÓWIENIA TOWARÓW (B2B)
-- ─────────────────────────────────────────────────────────────
Config.Goods = {
    maxLines = 20,        -- maks. pozycji w zamówieniu
    maxQty   = 99,        -- maks. sztuk jednej pozycji
    maxPrice = 1000000    -- maks. cena produktu w ofercie
}

-- ─────────────────────────────────────────────────────────────
--  HOOKI (serwer)
-- ─────────────────────────────────────────────────────────────

-- Status pracownika online: 'duty' | 'break' | 'off'.
-- Domyślnie czyta state bag gracza `duty`: true/'duty' = na służbie, 'break' = przerwa, false = poza służbą,
-- brak wartości = gracz online traktowany jest jako „na służbie”. Podepnij tu swój system służby.
Config.GetDutyStatus = function(src, xPlayer)
    local v = Player(src).state.duty
    if v == 'break' then return 'break' end
    if v == false or v == 'off' then return 'off' end
    return 'duty'
end

-- Wywoływane po oznaczeniu zamówienia towarów jako „Dostarczono”. Tu przekaż produkty zamawiającej firmie.
-- order = { id, buyerJob, supplierJob, total, items = { { id, name, price, qty } } }
-- Przykład (ox_inventory, stash firmy):
--   for _, it in ipairs(order.items) do exports.ox_inventory:AddItem('society_' .. order.buyerJob, it.itemName, it.qty) end
Config.GoodsDelivery = function(order)
    TriggerEvent('crp_bossmenu:goodsDelivered', order)   -- podepnij własny handler tego eventu
end

-- Kolor/tytuły embedów Discord
Config.Discord = {
    botName = 'CRP Bossmenu',
    colors  = { plus = 5763719, minus = 15548997, commend = 5763719, reprimand = 15548997, promo = 3447003, test = 9807270 }
}
