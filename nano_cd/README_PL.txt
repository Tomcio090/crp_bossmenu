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
       ensure ox_target      (żeby ped na dokach miał target – bez tego działa [E])
       ensure ox_lib         (ładniejsza lista aut – bez tego lista idzie na czat)
       ensure crp_jobcore    (boss menu – kolejność dowolna)
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

     ★ UWAGA: dopiero teraz (przy przyjętym zamówieniu) w BAZIE POD CAR DEALEREM
       pojawia się zestaw: przyczepa `tr2` + auto do ciągnięcia (`Config.Base`).
       Gdy zadań nie ma, zestaw znika (Config.Base.removeWhenIdle), a auta
       stojące na gniazdach NIGDY nie są usuwane.

  3. Pracownik CD:
     · wchodzi na służbę w SYSTEMIE DUTY z `crp_jobcore` (punkt duty z targetem, ten sam,
       co dla `police` ⇄ `offpolice`; `nano_cd` nie ma własnego przełącznika służby),
     · `/pod wez` – bierze zadanie (można też wziąć z listy na dokach),
     · jedzie lawetą do DOKÓW (`Config.Docks`, ma blip),
     · podchodzi do PEDA na dokach i klika target (ox_target) → otwiera się lista aut
       z zamówienia (ox_lib). Wybiera auto → pojawia się ono na jednym z punktów
       `Config.Docks.spawnPoints`,
     · wjeżdża tym autem na lawetę – auto PRZYPIERA się do pierwszego wolnego gniazda
       (`AttachEntityToEntity`, z tablicą z zamówienia). Gdy gniazda się skończą:
       jedzie oddać auta i wraca po kolejną partię,
     · gdy wszystkie auta (bez ⚡) są na lawecie, dostaje blip do miejsca odbioru,
     · na miejscu (promień `Config.Handover.radius`) wciska [E] → auta zjeżdżają
       z lawety, a skrypt zgłasza `crp_bossmenu:server:deliveryDone`.
  4. Dopiero teraz boss menu: wpisuje pojazdy do garażu kupującego (z tymi tablicami,
     które przyjechały na lawecie), płaci firmie-dostawcy i zamyka zamówienie.
     Oddanie w złym miejscu jest odrzucane także po stronie serwera.

  Jeśli zamówienie ma więcej aut niż miejsc na lawecie (`Config.Trailer.slots`),
  pracownik wiezie pierwszą partię, oddaje ją i wraca po kolejną – zamówienie
  zamknie się dopiero po ostatniej partii.

───────────────────────────────────────────────────────────────────────────────
 3. KOMENDY (do testów i kalibracji)
───────────────────────────────────────────────────────────────────────────────
   /pod              stan zadań, zestawu, gniazd i aut na dokach (wypis w konsoli F8)
   /pod help         lista komend
   /pod wez [id]     weź zadanie (bez id – pierwsze wolne)
   /pod menu         lista aut do pobrania na dokach (to samo co z targetu)
   /pod pobierz [nr] pobierz auto nr z listy – działa bez ox_target i bez ox_lib
   /pod attach [n]   przypnij auto, którym jedziesz, do gniazda n (albo pierwszego wolnego)
   /pod oddaj        oddaj auta (działa tylko w miejscu odbioru)
   /pod przyczepa    postaw/znajdź zestaw (przyczepa + ciężarówka) w bazie
   /pod truck        postaw samo auto do ciągnięcia (`Config.Truck.model`)
   /pod sprzataj     usuń zestaw i auta pobrane na doki (porządki po testach)
   /pod slot [n]     wypisz offset/rot auta względem przyczepy – gotowa linijka
                     do wklejenia w `Config.Trailer.slots`
   /pod zapisz <co>  wypisz gotową linijkę do configu na podstawie tego, gdzie stoisz:
                     base | przyczepa | truck | doki | ped | punkt | oddanie
   /pod test         szybki test: bierze zadanie (zestaw sam się postawi w bazie)

   Służbę włącza się i wyłącza TAM, GDZIE CAŁY SERWER: w systemie duty `crp_jobcore`
   (punkt duty z targetem). `nano_cd` tylko czyta ten stan – patrz punkt 8.

───────────────────────────────────────────────────────────────────────────────
 4. USTAWIENIE WSPÓŁRZĘDNYCH (5 minut, komendą `/pod zapisz`)
───────────────────────────────────────────────────────────────────────────────
 Stań (albo wjedź autem) dokładnie w miejscu, które chcesz ustawić i wpisz komendę –
 dostaniesz w konsoli (F8) gotową linijkę do wklejenia w `config.lua`:

   1. baza pod car dealerem:  stań na środku placu →  /pod zapisz base
   2. miejsce przyczepy:      wjedź lawetą na miejsce →  /pod zapisz przyczepa
   3. miejsce ciężarówki:     stań/zajedź na miejsce →  /pod zapisz truck
   4. środek doków:           stań na dokach →  /pod zapisz doki
   5. ped na dokach:          stań tam, gdzie ma stać obsługa →  /pod zapisz ped
   6. punkty dla aut:         stań w każdym miejscu, gdzie ma pojawiać się auto
                              (np. w aucie, żeby wziąć też jego kierunek) →  /pod zapisz punkt
   7. miejsce oddania (zapas): stań na komendzie →  /pod zapisz oddanie

 Uwaga: adres oddania dla normalnych zamówień przychodzi z boss menu (punkt pracy
 kupującego). `Config.Handover.fallback` to tylko zapas dla prac bez punktu w panelu.

───────────────────────────────────────────────────────────────────────────────
 5. KALIBRACJA GNIAZD PRZYCZEPY `tr2` (najważniejsze!)
───────────────────────────────────────────────────────────────────────────────
 Wartości w `Config.Trailer.slots` są STARTOWE – każda przyczepa (zwłaszcza własna,
 podmieniona na `tr2`) ma inne wymiary. Jak dopasować w 5 minut:
   1. `/pod przyczepa` – przyczepa staje w bazie.
   2. Wsiądź w auto, które chcesz wozić, i wjedź nim na lawetę.
   3. `/pod attach 1` – auto wskoczy na gniazdo 1 (na sztywno, wg configu).
   4. Jeśli wygląda źle: popraw liczby w `Config.Trailer.slots` i powtórz,
      albo ustaw auto „na oko” w grze i wpisz `/pod slot 1` – komenda wypisze
      w konsoli (F8) gotową linijkę, np.
         { offset = vector3(0.00, 2.60, 0.85), rot = vector3(0, 0, 0), bone = 0 },
      którą wklejasz do configu.
   · offset = X (prawo/lewo), Y (przód/tył; plus = przód, w stronę zaczepu), Z (góra/dół)
   · gdy auto drga albo przenika przyczepę: `Config.Trailer.attach.collision = true`
     albo `softPinning = true`.
   · przypinanie na dokach: auto łapie się, gdy podjedziesz nim do przyczepy bliżej niż
     `Config.Trailer.attachRadius` i wolniej niż `Config.Trailer.attachMaxSpeed`.

───────────────────────────────────────────────────────────────────────────────
 6. PODŁĄCZENIE WŁASNEGO SKRYPTU CD (gdy powstanie)
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
 7. SŁUŻBA (DUTY) – JEDEN SYSTEM NA CAŁYM SERWERZE
───────────────────────────────────────────────────────────────────────────────
 `nano_cd` NIE MA własnej służby – korzysta z systemu duty z `crp_jobcore`
 (przełączanie `centra_autos` ⇄ `offcentra_autos`, dokładnie tak samo jak
 `police` ⇄ `offpolice`; punkt duty z targetem ustawiasz w
 `crp_jobcore/resources/duty/d_duty.lua`).

 Skąd `nano_cd` wie, że jesteś na służbie:
   · w pierwszej kolejności pyta export:   exports.crp_jobcore:IsOnDuty(source)
     (dodany w `resources/duty/s_duty.lua`: true / false / 'break'),
   · jeśli exportu nie ma (np. starsza wersja crp_jobcore) – czyta ten sam state bag
     `duty`, który czyta panel boss menu (true/'duty' = na służbie, false/'off' = poza,
     'break' = przerwa). Przerwa jest traktowana jak brak służby.
   · gdy nie ma ani exportu, ani state bagu (np. `nano_cd` na serwerze bez crp_jobcore)
     – uznaje, że gracz jest na służbie i patrzy tylko na pracę z `Config.Job`.

 W configu są do tego dwie rzeczy:
   · `Config.Job` – praca firmy wożącej pojazdy (bez `off`), domyślnie `centra_autos`
     (ta sama firma, która przyjmuje zamówienia w panelu),
   · `Config.RequireDuty` – czy służba jest wymagana (domyślnie tak).
 Gdy pracownik zejdzie ze służby, `nano_cd` sam zwraca jego zadanie na listę
 (ktoś inny może je wziąć) i czyści mu listę zadań w NUI/HUD.

───────────────────────────────────────────────────────────────────────────────
 8. NAJCZĘSTSZE PROBLEMY
───────────────────────────────────────────────────────────────────────────────
 · „Aut wjechało do garażu od razu, a miały jechać lawetą”
     → zasób `nano_cd` nie był uruchomiony (boss menu nie ma komu oddać zadania),
       albo kupujący zaznaczył ⚡ szybki transport.
 · „Nie ma peda na dokach / target nic nie pokazuje”
     → sprawdź `Config.Docks.ped.coords` (`/pod zapisz ped`) i czy `ox_target` wystartował.
       Bez ox_target podejdź do peda i wciśnij [E] (albo `/pod menu`, `/pod pobierz 1`).
 · „Wybrane auto nie pojawiło się na dokach”
     → wszystkie `Config.Docks.spawnPoints` są zajęte (podjedź, załaduj i wróć)
       albo wszystkie gniazda lawety są pełne – komunikaty mówią o tym wprost.
 · „Auto nie chce się przypiąć do lawety”
     → musisz podjechać nim naprawdę blisko przyczepy i prawie stanąć
       (`attachRadius` / `attachMaxSpeed`), a przyczepa musi stać (zestaw jest w bazie).
       Awaryjnie: `/pod attach 1`.
 · „Przyczepa nie pojawia się sama”
     → zestaw stawia tylko osoba, która MA wzięte zadanie (`/pod wez`) i tylko wtedy,
       gdy jest co wieźć. Wymuś: `/pod przyczepa`.
 · „Wypisuję /pod, ale nie ma zadań”
     → nie jesteś na służbie (wejdź na służbę w systemie duty `crp_jobcore`)
       albo firma-dostawca nie przyjęła zamówienia.
 · „Nie mogę oddać aut – komunikat, że jestem za daleko”
     → jesteś poza promieniem `Config.Handover.radius` od punktu pracy kupującego.
       Dla zamówień policji ustaw w `d_bossmenu.lua` (Config.Locations) prawdziwy punkt
       dla pracy `police`, żeby adres był brany z panelu, a nie z `Config.Handover.fallback`.
 · „Auto na lawecie drga / spada”
     → patrz punkt 5 (kolizja/soft pinning) i sprawdź, czy offset Z jest dobry.
 · „Chcę z panelu zamknąć zamówienie ręcznie, mimo że laweta jedzie”
     → `Config.VehicleShop.delivery.manualOverride = true` w `d_bossmenu.lua`.
