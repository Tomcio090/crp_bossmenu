Config = {}

Config.Debug = false
Config.Job = 'centra_autos'
Config.RequireDuty = true

Config.Base = {
    coords = vector3(-914.0663, -1171.6893, 4.9069),

    radius = 45.0,

    blip = { sprite = 477, color = 5, scale = 0.9, label = 'CD – baza (car dealer)' },

    marker = { type = 1, color = { r = 90, g = 160, b = 255, a = 90 }, scale = { x = 6.0, y = 6.0, z = 1.0 } },

    trailerCoords = vector4(-914.1580, -1163.6470, 4.8340, 206.5749),

    truckCoords = vector4(-910.7054, -1169.7985, 4.9047, 210.5949),

    removeWhenIdle = true,
.
    removeDistance = 25.0,
}

-- ── LAWETA (PRZYCZEPA `tr2`) ──────────────────────────────────────────────────

Config.Trailer = {
    model = 'tr2',

    -- 'spawn'  = skrypt stawia przyczepę w Config.Base.trailerCoords (pod car dealerem).
    -- 'static' = używamy przyczepy, która już stoi w świecie (MLO/mapper).
    mode = 'spawn',

    -- Tryb 'static': w jakim promieniu od Config.Base.trailerCoords szukać przyczepy.
    findRadius = 12.0,

    -- true = przyczepa stoi zablokowana (przydatne tylko do testów na placu).
    freeze = false,

    -- true = przyczepa zniknęła (wybuchła/restart), a jest aktywne zadanie → postaw nową.
    respawnIfMissing = true,

    -- Z jakiej odległości od przyczepy auto wjeżdżające tyłem/przodem liczy się jako
    -- „na lawecie” i zostaje przypięte do gniazda (w metrach).
    attachRadius = 3.6,

    -- Maksymalna prędkość auta (m/s), przy której przypinamy je do gniazda.
    -- 2.5 m/s to około 9 km/h – auto musi praktycznie stanąć na lawecie.
    attachMaxSpeed = 2.5,

    -- ── GNIAZDA (MIEJSCA NA AUTA) ─────────────────────────────────────────────
    --  offset = pozycja auta względem przyczepy w jej układzie:
    --           X = prawo/lewo, Y = przód/tył (plus = przód, w stronę zaczepu), Z = góra/dół
    --  rot    = obrót auta względem przyczepy (stopnie); rot.z = 0 → auto wzdłuż przyczepy
    --  bone   = kość przyczepy (0 = korzeń; zostaw 0, chyba że wiesz, co robisz)
    --
    --  Kalibracja w grze: wjedź autem na lawetę, wpisz `/pod attach 1`, popraw auto
    --  ręcznie, potem `/pod slot 1` – dostaniesz gotową linijkę do wklejenia tutaj.
    --  Liczba gniazd = ile aut zabierasz na jeden kurs.
    slots = {
        { offset = vector3(0.0, 2.6, 0.85), rot = vector3(0.0, 0.0, 0.0), bone = 0 },
        { offset = vector3(0.0, -2.2, 0.85), rot = vector3(0.0, 0.0, 0.0), bone = 0 },
    },

    -- ── PARAMETRY DOCZEPIANIA (AttachEntityToEntity) ──────────────────────────
    --  Gdy auto na lawecie drga / odpada / przenika przyczepę, pobaw się tymi opcjami:
    --   · softPinning = true → łagodniejsze doczepienie (mniej drgań, lekko „pływa”)
    --   · collision   = true → auto zderza się z przyczepą (czasem drga bardziej)
    --   · fixedRot    = true → auto trzyma zadany obrót gniazda
    attach = {
        softPinning = false,
        collision = false,
        fixedRot = true,
        vertexIndex = 2,
    },

    -- true = gdy podjedziesz ciężarówką z listy `truckModels`, przyczepa sama się zaczepi.
    autoAttachTruck = true,

    -- Modele aut, które mogą ciągnąć przyczepę (używane przy auto-doczepianiu).
    truckModels = { 'packer', 'phantom', 'hauler', 'hauler2', 'tractor2', 'tractor3' },
}

-- ── AUTO DO CIĄGNIĘCIA LAWETY ─────────────────────────────────────────────────

Config.Truck = {

    -- 'spawn' = skrypt stawia auto w Config.Base.truckCoords (pod car dealerem).
    -- 'none'  = nie stawiamy auta – pracownik przyjeżdża własnym.
    mode = 'spawn',

    -- Model auta do ciągnięcia (musi być na liście Config.Trailer.truckModels).
    model = 'packer',

    -- true = po wejściu do tego auta przyczepa zaczepia się sama (AttachVehicleToTrailer).
    autoAttachTrailer = true,
}

-- ── DOKI (ODBIÓR AUT Z ZAMÓWIENIA) ────────────────────────────────────────────
-- Tu pracownik CD podjeżdża lawetą po auta. Przy pedzie jest target (ox_target),
-- a pod nim lista aut z aktualnego zamówienia (ox_lib). Wybrane auto pojawia się
-- na jednym z `spawnPoints`, a Ty wjeżdżasz nim na lawetę.

Config.Docks = {

    -- Środek doków (blip, znacznik, podpowiedzi). PODMIEŃ.
    coords = vector3(1221.3972, -3000.8982, 5.865),

    -- Promień strefy doków – w niej pokazujemy podpowiedzi o załadunku.
    radius = 70.0,

    -- Blip doków na mapie.
    blip = { sprite = 478, color = 3, scale = 0.9, label = 'Doki – odbiór pojazdów (CD)' },

    -- Znacznik (marker) na ziemi przy dokach.
    marker = { type = 1, color = { r = 90, g = 160, b = 255, a = 90 }, scale = { x = 4.0, y = 4.0, z = 1.0 } },

    -- ── PED OBSŁUGUJĄCY ODBIÓR ────────────────────────────────────────────────
    ped = {

        -- Model peda (kobieta/mężczyzna z doków).
        model = 's_m_m_dockwork_01',

        -- Gdzie ma stać ped: x, y, z, heading. PODMIEŃ.
        coords = vector4(1221.3972, -3000.8982, 5.8654, 89.9467),

        -- Scenka, którą odgrywa ped ('' = stoi bez scenki).
        scenario = 'WORLD_HUMAN_CLIPBOARD',

        -- true = ped jest nieśmiertelny (nie da się go zabić).
        invincible = true,

        -- true = ped stoi w miejscu (nie ucieka, nie chodzi).
        freeze = true,
    },

    -- ── TARGET (ox_target) ────────────────────────────────────────────────────
    --  Gdy ox_target nie działa, skrypt pokazuje znacznik i klawisz [E] – działa tak samo.
    target = {

        -- Etykieta pozycji w target.
        label = 'Odbiór pojazdów (CD)',

        -- Ikona (FontAwesome) w target.
        icon = 'fa-solid fa-truck-ramp-box',

        -- Z jakiej odległości target da się kliknąć.
        distance = 2.5,

        -- Rozmiar strefy wokół peda, w której działa target.
        size = vector3(1.4, 1.4, 1.8),
    },

    -- ── GDZIE POJAWIAJĄ SIĘ AUTA ──────────────────────────────────────────────
    --  x, y, z, heading. Jedno miejsce = jedno auto (skrypt wybiera wolne).
    --  Ustaw ich co najmniej tyle, ile masz gniazd na lawecie. PODMIEŃ.
    spawnPoints = {
        vector4(1214.3400, -2990.2830, 5.8654, 47.2294),
        vector4(1214.3420, -2981.7222, 5.8654, 71.2091),
        vector4(1214.7487, -2978.8403, 5.8654, 53.5430),
    },

    -- Event do kluczyków, który ma dostać pracownik po pobraniu auta.
    -- Dla qs-vehiclekeys: 'vehiclekeys:client:SetOwner'; puste '' = nic nie wołamy.
    keyEvent = '',

    -- true = z listy na dokach można też wziąć zadanie, którego nikt jeszcze nie wiezie.
    allowTakeJobHere = true,
}

-- ── ODDANIE POJAZDÓW (MIEJSCE ODBIORU) ────────────────────────────────────────
-- Adres dostawy przysyła boss menu (punkt pracy zamawiającej, np. policja → komenda).

Config.Handover = {

    -- Z jakiej odległości od miejsca odbioru wolno oddać auta (klient – podpowiedź i [E]).
    radius = 25.0,

    fallback = {
        x = 441.5,
        y = -982.5,
        z = 30.7,
        heading = 0.0,
        label = 'Komenda policji',
    },

    -- Gdzie mają „zjechać” auta z lawety przy oddawaniu (układ względem przyczepy).
    unload = {
        side = 4.5,
        firstY = -1.0,
        spacing = 6.5,
        z = 0.0,
        useTrailerHeading = true,
    },

    -- true = oddane auta zostają na miejscu (widowiskowo); false = znikają po oddaniu.
    keepVehicles = true,

    -- Zapas na weryfikację po stronie serwera: maksymalna odległość gracza od miejsca
    -- odbioru, przy której serwer przyjmie zgłoszenie „oddane” (w metrach).
    maxServerDistance = 35.0,
}

-- ── ZACHOWANIE SKRYPTU ────────────────────────────────────────────────────────

-- true = auto przypina się do lawety natychmiast; false = z paskiem postępu (Config.Progress).
Config.AutoLoad = true

-- Klawisz interakcji (fallback, gdy nie ma ox_target): 38 = E.
Config.Keys = { interact = 38 }

-- Czas paska postępu przy przypinaniu auta (Config.AutoLoad = false).
Config.Progress = { ms = 2500 }

-- true = zadania zapisywane w bazie (`crp_cd_jobs`), więc przetrwają restart zasobu.
Config.Persist = true

-- Co ile sekund (mając kogoś na służbie) dopytywać boss menu o aktualne zadania.
Config.RefreshSeconds = 30

-- ── POWIADOMIENIA ─────────────────────────────────────────────────────────────
-- Kolejność: ox_lib → ESX → chat. Nie musisz tego zmieniać.

function Config.Notify(text, tone)
    if GetResourceState('ox_lib') == 'started' and lib and lib.notify then
        lib.notify({
            title = 'CD / dostawa',
            description = text,
            type = tone == 'error' and 'error' or (tone == 'success' and 'success' or 'inform'),
        })
        return
    end
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(text)
        return
    end
    TriggerEvent('chat:addMessage', { args = { '[CD]', text }, color = { 90, 160, 255 } })
end
