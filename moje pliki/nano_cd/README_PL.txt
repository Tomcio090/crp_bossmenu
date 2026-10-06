═══════════════════════════════════════════════════════════════════════════════
 nano_cd — nano skrypt dostawy pojazdów lawetą `tr2` (start prac nad skryptem CD/POD)
═══════════════════════════════════════════════════════════════════════════════

 To jest OSOBNY zasób. Nic nie trzeba zmieniać w `crp_jobcore` poza tym, że
 `Config.VehicleShop.delivery.resource` w `d_bossmenu.lua` musi się równać nazwie
 folderu tego zasobu (domyślnie: `nano_cd`).

───────────────────────────────────────────────────────────────────────────────
 1. INSTALACJA
───────────────────────────────────────────────────────────────────────────────
 · Wrzuć folder `nano_cd` do `resources/` (np. `resources/[crp]/nano_cd`).
   UWAGA: jeśli zmienisz nazwę folderu, popraw `Config.VehicleShop.delivery.resource`
   w `moje pliki/crp_jobcore/resources/bossmenu/d_bossmenu.lua`.
 · W `server.cfg` dopisz:
       ensure oxmysql
       ensure crp_jobcore      (boss menu – kolejność dowolna)
       ensure nano_cd
 · Tabela `crp_cd_jobs` tworzy się sama przy pierwszym starcie (zadania przeżywają restart).

───────────────────────────────────────────────────────────────────────────────
 2. JAK TO DZIAŁA (przepływ)
───────────────────────────────────────────────────────────────────────────────
  1. Firma (np. policja) zamawia pojazdy w Garażu boss menu.
     · zaznaczone ⚡ „szybki transport” → auto od razu w garażu (jak dotąd),
     · bez ⚡ → auta trzeba PRZYWIEŹĆ lawetą.
  2. Firma-dostawca (np. `centra_autos`) przyjmuje zamówienie w panelu.
     · pojazdy „bez szybkiego transportu” NIE wchodzą do garażu,
     · boss menu wysyła do tego zasobu zadanie: `crp_cd:server:start`
       (modele, nazwy, kategorie, TABLICE i adres oddania = punkt pracy kupującego,
       np. policja → komenda policji),
     · zamówienie dostaje w bazie znacznik `delivery = 'physical'`
       i do końca jazdy jest „W realizacji”.
  3. Pracownik CD:
     · `/pod sluzba` (jeśli `Config.AllowAnyone = false` i `Config.RequireDuty = true`),
     · jedzie na plac (`Config.Depot`, ma blip), ma tam przyczepę `tr2`,
     · zaczepia przyczepę do auta z hakiem (robisz to grą; skrypt zaczepi sam, gdy
       wsiądziesz w `packer`/`phantom`/`hauler` – `Config.Trailer.autoAttachTruck`),
     · przy lawecie wciska [E] i ładuje kolejne auta – każde jest DOCZEPIANE do gniazda
       (`AttachEntityToEntity`), z tablicą z zamówienia,
     · gdy wszystkie auta są na lawecie, dostaje blip do miejsca odbioru,
     · na miejscu (promień `Config.Handover.radius`) wciska [E] → auta zjeżdżają z lawety,
       a skrypt zgłasza `crp_bossmenu:server:deliveryDone`.
  4. Dopiero teraz boss menu: wpisuje pojazdy do garażu kupującego (z tymi tablicami,
     które przyjechały na lawecie), płaci firmie-dostawcy i zamyka zamówienie.
     Oddanie w złym miejscu jest odrzucane także po stronie serwera.

  Jeśli zamówienie ma więcej aut niż miejsc na lawecie (`Config.Trailer.slots`),
  pracownik wiezie pierwszą partię, oddaje ją i wraca po kolejną – zamówienie
  zamknie się dopiero po ostatniej partii.

───────────────────────────────────────────────────────────────────────────────
 3. KOMENDY (do testów i kalibracji)
───────────────────────────────────────────────────────────────────────────────
   /pod              stan zadań, przyczepy i gniazd (wypis w konsoli F8)
   /pod help         lista komend
   /pod sluzba       start/koniec służby CD
   /pod wez [id]     weź zadanie (bez id – pierwsze wolne)
   /pod test         SZYBKI TEST: stawia przyczepę (+ auto), bierze zadanie
                     i ładuje wszystkie auta automatycznie
   /pod auto         włącz/wyłącz automatyczny załadunek (tryb testowy)
   /pod przyczepa    postaw przyczepę na placu
   /pod truck        postaw auto do ciągnięcia (Config.Truck.model)
   /pod attach <n>   doczep swoje ostatnie auto do gniazda n (do kalibracji)
   /pod slot <n>     wypisz offset/rot auta względem przyczepy – gotowa linijka
                     do wklejenia w `Config.Trailer.slots`
   /pod oddaj        oddaj auta (działa tylko w miejscu odbioru)

───────────────────────────────────────────────────────────────────────────────
 4. KALIBRACJA GNIAZD PRZYCZEPY `tr2` (najważniejsze!)
───────────────────────────────────────────────────────────────────────────────
 Wartości w `Config.Trailer.slots` są STARTOWE – każda przyczepa (zwłaszcza własna,
 podmieniona na `tr2`) ma inne wymiary. Jak dopasować w 5 minut:
   1. `/pod przyczepa` – przyczepa staje na placu.
   2. Wsiądź w auto, które chcesz wozić, podjedź nim do przyczepy.
   3. `/pod attach 1` – auto wskoczy na gniazdo 1 (na sztywno, wg configu).
   4. Jeśli wygląda źle: popraw liczby w `Config.Trailer.slots` i powtórz,
      albo ustaw auto „na oko” w grze i wpisz `/pod slot 1` – komenda wypisze
      w konsoli (F8) gotową linijkę, np.
         { offset = vector3(0.00, 2.60, 0.85), rot = vector3(0, 0, 0), bone = 0 }, -- gniazdo 1
      którą wklejasz do configu.
   · offset = X (prawo/lewo), Y (przód/tył; plus = przód, w stronę zaczepu), Z (góra/dół)
   · gdy auto drga albo przenika przyczepę: `Config.Trailer.attach.collision = true`
     albo `softPinning = true`.

───────────────────────────────────────────────────────────────────────────────
 5. PODŁĄCZENIE WŁASNEGO SKRYPTU CD (gdy powstanie)
───────────────────────────────────────────────────────────────────────────────
 Ten zasób jest przygotowany na to, żeby zniknąć albo zostać częścią większego CD:
 · eventy (możesz ich słuchać u siebie):
      crp_cd:server:start    – nowe/odświeżone zadanie dostawy (payload jak niżej)
      crp_cd:server:cancel   – anulowanie zadania (orderId, powód)
      crp_cd:server:resend   – ponowne wysłanie zadania (boss menu → CD)
 · wywołania do boss menu (serwerowo, `TriggerEvent`):
      crp_bossmenu:server:deliveryDone    orderId, { {index=, plate=}, ... }, final, who
      crp_bossmenu:server:deliveryResend  (prośba: „wyślij ponownie aktywne zadania”)
 · exporty tego zasobu:
      exports.nano_cd:SetDuty(source, true/false)   – oznacz pracownika jako „na służbie”
      exports.nano_cd:Jobs()                        – lista zadań
      exports.nano_cd:Job(id)                       – jedno zadanie
      exports.nano_cd:Handin(id, plates, byName)     – ręczne domknięcie
 · payload zadania:
      { orderId = 'ord-12', id = 12, buyerJob, buyerLabel, supplierJob, total,
        destination = { x, y, z, heading, label } | nil,      -- punkt pracy kupującego
        items = { { index, model, name, category, express, plate }, ... } }
      (dla pozycji `express = true` pole `plate` jest puste – takich aut nie wieziemy)

───────────────────────────────────────────────────────────────────────────────
 6. NAJCZĘSTSZE PROBLEMY
───────────────────────────────────────────────────────────────────────────────
 · „Aut wjechało do garażu od razu, a miały jechać lawetą”
     → zasób `nano_cd` nie był uruchomiony (boss menu nie ma komu oddać zadania),
       albo kupujący zaznaczył ⚡ szybki transport.
 · „Wypisuję /pod, ale nie ma zadań”
     → nie jesteś na służbie (`/pod sluzba`) albo firma-dostawca nie przyjęła zamówienia.
 · „Nie mogę oddać aut – komunikat, że jestem za daleko”
     → jesteś poza promieniem `Config.Handover.radius` od punktu pracy kupującego.
       Dla zamówień policji ustaw w `d_bossmenu.lua` (Config.Locations) prawdziwy punkt
       dla pracy `police`, żeby adres był brany z panelu, a nie z `Config.Handover.fallback`.
 · „Auto na lawecie drga / spada”
     → patrz punkt 4 (kolizja/soft pinning) i sprawdź, czy offset Z jest dobry.
 · „Chcę z panelu zamknąć zamówienie ręcznie, mimo że laweta jedzie”
     → `Config.VehicleShop.delivery.manualOverride = true` w `d_bossmenu.lua`.
