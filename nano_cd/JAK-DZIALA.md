# nano_cd — jak to działa (od A do Z)

Ten plik to „mapa” skryptu: kto z kim gada, co gdzie leży i co się dzieje w każdej chwili.
Ma Ci wystarczyć, gdy będziesz przenosić te pliki do własnego zasobu CD/POD.

Wersja przepływu: **baza (przyczepa + ciężarówka) pod car dealerem, auta odbierane na dokach
od peda z targetem (ox_target + lista ox_lib), zestaw pojawia się dopiero po przyjęciu zamówienia.**

---

## 1. Kto jest kim

```
  KUPUJĄCY (np. policja)          DOSTAWCA (centra_autos)              PRACOWNIK CD
        │                                │                                  │
        │ 1. zamawia auta w garażu       │                                  │
        │    (boss menu, ⚡ = express)     │                                  │
        └──────────────┬─────────────────┘                                  │
                       │ 2. firma-dostawca klika „Akceptuj”                 │
                       ▼                                                    │
        ┌──────────────────────────────────────────────────────────┐        │
        │  crp_jobcore / bossmenu  (s_main.lua)                    │        │
        │   • auta z ⚡ → od razu wpis do garażu + kasa            │        │
        │   • bez ⚡   → delivery = 'physical'                     │        │
        │   • wysyła zadanie:  crp_cd:server:start  ───────────────┼───────►│
        └──────────────────────────────────────────────────────────┘        │
                                                                            │
                       ┌────────────────────────────────────────────────────┘
                       ▼
        ┌──────────────────────────────────────────────────────────────┐
        │  nano_cd (ten zasób)                                         │
        │   BAZA pod car dealerem: przyczepa `tr2` + ciężarówka        │
        │            (pojawia się TYLKO, gdy jest zadanie)             │
        │   DOKI: ped + target → lista aut z zamówienia → auto na      │
        │         punkcie → wjeżdżasz nim na lawetę (samo się przypina)│
        │   MIEJSCE ODBIORU: rozładunek → zgłoszenie „oddane”          │
        └───────────────────────┬──────────────────────────────────────┘
                                │ 3. crp_bossmenu:server:deliveryDone
                                ▼   (orderId, tablice, final, kto)
        ┌──────────────────────────────────────────────────────────┐
        │  bossmenu: wpis pojazdów do garażu kupującego, przelew   │
        │  kasy firmie dostawcy, zamówienie → „Dostarczone”        │
        └──────────────────────────────────────────────────────────┘
```

**Podział odpowiedzialności:**
* `bossmenu` — pieniądze, zamówienie, garaż kupującego (`owned_vehicles`), status zamówienia.
* `nano_cd` — fizyczne auta: zestaw, pobranie aut na dokach, przypięcie do lawety, jazda, rozładunek.
* `nano_cd` **nigdy** sam nie wpisuje aut do garażu ani nie rusza kasy — tylko zgłasza „oddane”.

---

## 2. Kontrakt eventów (to musi zostać, gdy przeniesiesz pliki)

| Kierunek | Event | Argumenty |
|---|---|---|
| bossmenu → nano_cd | `crp_cd:server:start` | `{ id/orderId, buyerJob, buyerLabel, supplierJob, total, destination = { x, y, z, heading, label } \| nil, items = { { index, model, name, category, express, plate }, … } }` |
| bossmenu → nano_cd | `crp_cd:server:resend` | to samo co `start` (ponowne wysłanie po restarcie) |
| bossmenu → nano_cd | `crp_cd:server:cancel` | `'ord-12'` / `12` / `{ id = … }`, powód |
| nano_cd → bossmenu | `crp_bossmenu:server:deliveryDone` | `orderId, { { index = 1, plate = 'ABC 123' }, … }, final (bool), kto (nazwa) ` |
| nano_cd → bossmenu | `crp_bossmenu:server:deliveryResend` | nic (odpowiedź przez callback, opcjonalnie) |

`express = true` (szybki transport) **nie jedzie lawetą** — takie auto jest już w garażu w chwili przyjęcia zamówienia.
Na dokach lista pokazuje wyłącznie pozycje bez `express`, nie załadowane i nie oddane.

Numer `index` to pozycja auta w zamówieniu — po nim bossmenu wie, które auto oddajesz.

---

## 3. Cykl życia zadania (stany)

```
      start / resend
            │
            ▼
       ┌─────────┐   pracownik bierze zadanie (/pod wez albo z listy na dokach)   ┌─────────┐
       │ pending │ ─────────────────────────────────────────────────────────────►│ loading │
       └─────────┘                                                               └────┬────┘
            ▲                                                                       │ wszystkie auta na lawecie
            │ kierowca wyszedł z serwera                                            ▼
            │                                                                  ┌──────────┐
            └──────────────────────────────────────────────────────────────────│ hauling  │
                                                                               └────┬─────┘
                                          oddanie w miejscu odbioru                 │
                                   ┌────────────────────────────────────────────────┴───┐
                                   ▼                                                    ▼
                        zostały auta (final = false)                      wszystko oddane (final = true)
                     wraca na doki, stan → loading                           stan done, zadanie znika
```

Stan trzyma **serwer** (`CD.jobs[id]`), klient dostaje tylko kopię (`Snapshot`) i zgłasza fakty
(„auto przypięte”, „oddane”). Dzięki temu restart zasobu nic nie gubi.

---

## 4. Zestaw w bazie pod car dealerem (leniwe respienie)

* `Config.Base` = **baza pod car dealerem**: `coords` (blip + marker + strefa auto-służby),
  `trailerCoords` (gdzie staje przyczepa), `truckCoords` (gdzie staje auto do ciągnięcia).
* Zestaw (przyczepa `tr2` + ciężarówka) **nie stoi na świecie od startu zasobu**:
  pojawia się dopiero, gdy jest co wieźć — konkretnie gdy *Ty* masz wzięte zadanie
  (`IShouldHaveRig`). Wymuszenie: `/pod przyczepa`, `/pod truck`.
* Znikają, gdy nie ma już żadnego zadania, laweta jest pusta, nic nie czeka na dokach
  i odejdziesz od przyczepy dalej niż `Config.Base.removeDistance`
  (przełącznik: `Config.Base.removeWhenIdle`). **Aut nigdy nie usuwamy przy sprzątaniu.**
* Gdy przyczepa wybuchnie w trakcie zadania, a `Config.Trailer.respawnIfMissing = true` —
  zestaw wraca do bazy.
* Auto-doczepienie: wsiadasz w model z `Config.Trailer.truckModels` i podjeżdżasz do przyczepy
  → `AttachVehicleToTrailer` sam ją zaczepia (`Config.Trailer.autoAttachTruck`).
* Tryb `Config.Trailer.mode = 'static'` obsługuje przyczepę postawioną w świecie (MLO/mapper) —
  wtedy skrypt jej **nie tworzy**, tylko szuka w promieniu `findRadius` od `Config.Base.trailerCoords`.
* Zestaw stawia tylko jedna osoba (ta, która wiezie), a jeśli przyczepa już stoi w bazie,
  drugi klient ją **odnajduje**, zamiast stawiać kolejną.

---

## 5. Doki: ped + target + lista aut

* Na dokach stoi **ped** (`Config.Docks.ped`: model, `coords`, scenka, nieśmiertelny, zablokowany).
  Klient najpierw szuka peda tego modelu w promieniu 3 m i dopiero gdy go nie ma — tworzy nowego,
  więc nie ma dublowania przy kilku graczach.
* Na pedzie (obok peda) jest **strefa ox_target** (`Config.Docks.target`: `label`, `icon`, `distance`, `size`),
  która otwiera **listę z ox_lib** (`lib.registerContext` → `lib.showContext`).
* Bez `ox_target`: podejdź do peda (< 4 m) i wciśnij **[E]** (`Config.Keys.interact`).
  Bez `ox_lib`: lista leci na czat (F8), a auta pobierasz komendą `/pod pobierz <nr>`.
* Lista pokazuje tylko to, co ma sens:
  * auto bez szybkiego transportu, jeszcze nie załadowane i nie oddane,
  * gdy auta nie ma wziętego zadania → proponuje wzięcie wolnego zadania (`Config.Docks.allowTakeJobHere`),
  * gdy gniazda lawety są pełne → mówi wprost: „zawieź auta i wróć”,
  * pozycja pobrana już na doki jest oznaczona „już na dokach”.
* Wybór pozycji z listy **respuje** to auto na pierwszym wolnym punkcie z `Config.Docks.spawnPoints`
  (x, y, z, heading), ustawia jej **tablicę z zamówienia**, kluczyki (jeśli ustawisz
  `Config.Docks.keyEvent`) i zaznacza je w swoim stanie (żeby nie zrespować go drugi raz).
* Punkty na dokach zajęte? Komunikat zamiast respienia auta w drugim aucie.

---

## 6. Załadunek: przypięcie auta do lawety

* Wjeżdżasz pobranym autem na przyczepę. Gdy jesteś bliżej niż `Config.Trailer.attachRadius`
  i wolniej niż `Config.Trailer.attachMaxSpeed`, skrypt **przypina** auto do pierwszego wolnego
  gniazda (`AttachEntityToEntity`): gasi silnik, ustawia tablicę, zgłasza serwerowi `loaded`.
* Ręcznie (kalibracja / awaryjnie): `/pod attach 1` — bierze to samo, co auto na gnieździe.
* Gniazda = `Config.Trailer.slots` (offset/rot/bone). Ile gniazd = ile aut na jeden kurs.
* `Config.AutoLoad = true` → przypina natychmiast; `false` → najpierw pasek postępu.
* Chcesz dokładniejsze przypięcie? Patrz sekcja „kalibracja gniazd” niżej (`/pod attach`, `/pod slot`).

---

## 7. Oddanie pojazdów (miejsce odbioru)

* Klient pozwala oddawać tylko gdy jesteś w promieniu `Config.Handover.radius` od **miejsca odbioru**
  (adres przyszedł z boss menu: punkt pracy kupującego, np. komenda policji; gdy zamówienie adresu
  nie ma → `Config.Handover.fallback`).
* Serwer sprawdza to **jeszcze raz** (`Config.Handover.maxServerDistance`) — ręczne odpalenie eventu
  z drugiego końca mapy nic nie da.
* Rozładunek: auta zjeżdżają obok przyczepy według `Config.Handover.unload` (`side`, `firstY`,
  `spacing`, `useTrailerHeading`), `keepVehicles = true` zostawia je na miejscu, `false` usuwa.
* Dopiero wtedy leci `crp_bossmenu:server:deliveryDone(orderId, tablice, final, kto)`:
  * `final = false` → część aut oddana: bossmenu wpisuje **te** auta do garażu, zamówienie zostaje
    otwarte, Ty wracasz na doki po resztę;
  * `final = true` → wpis do garażu, przelew `total` na konto firmy dostawcy, status „Dostarczone”,
    zadanie znika z listy i z bazy.

---

## 8. Trwałość (restart serwera / zasobu)

* Wszystkie zadania są zapisywane w tabeli **`crp_cd_jobs`** (`id`, `data` = całe zadanie w JSON, `state`).
  Tabela tworzy się sama (`CREATE TABLE IF NOT EXISTS`).
* `SaveJob` przy każdej zmianie stanu, `DropJob` gdy zadanie zniknie (oddane / anulowane).
* Po starcie zasobu serwer: tworzy tabelę → wczytuje zadania → `hauling` wraca do `pending`
  → po 2 s pyta boss menu `deliveryResend` o aktualną listę.
* `Config.RefreshSeconds` (30 s): gdy ktoś jest na służbie, nano_cd i tak co pół minuty pyta
  boss menu o wznowienie zadań — łapie sytuację „boss menu wystartowało po nas”.
* Kierowca wyszedł z serwera → zadanie wraca na listę (`pending`, `claimedBy = nil`), auta
  czekające na dokach są usuwane po anulowaniu zadania, a auta na lawecie zostają w świecie.

---

## 9. Uprawnienia i służba (JEDEN system duty — z crp_jobcore)

`nano_cd` **nie ma własnej służby**. Wożenie wymaga dwóch rzeczy:

| Warunek | Skąd |
|---|---|
| praca = firma wożąca (`Config.Job`, domyślnie `centra_autos`), z pominięciem `off` na początku | ESX (`xPlayer.job.name`) |
| na służbie (gdy `Config.RequireDuty = true`) | system duty z crp_jobcore |

Służbę czytamy tak:
1. `exports.crp_jobcore:IsOnDuty(source)` — dodane w `resources/duty/s_duty.lua`
   (zwraca `true` / `false` / `'break'`),
2. gdy tego exportu nie ma → state bag `duty` (ten sam, który czyta panel boss menu:
   `true`/`'duty'` = na służbie, `false`/`'off'` = poza, `'break'` = przerwa),
3. gdy nie ma ani jednego, ani drugiego → uznajemy, że gracz jest na służbie
   (żeby `nano_cd` działał też na serwerze bez crp_jobcore), i patrzymy tylko na pracę.

Wejście/zejście ze służby = zmiana pracy (`centra_autos` ⇄ `offcentra_autos`) przez punkt
duty z targetem. `nano_cd` słucha `esx:setJob`:
* wejście na służbę → wysyła pracownikowi aktualną listę zadań,
* zejście → zwraca jego zadanie na listę (ktoś inny może je wziąć) i czyści mu listę.

W configu są tylko dwa klucze: `Config.Job` i `Config.RequireDuty`.
Zasoby, które chcą sprawdzić służbę u siebie: `exports.crp_jobcore:IsOnDuty(source)`
oraz `exports.crp_jobcore:DutyJobs()`.
Z tego zasobu przydają się: `exports.nano_cd:Handin(id, plates, byName)`,
`exports.nano_cd:Jobs()`, `exports.nano_cd:Job(id)`.

---

## 10. Komendy w grze

| Komenda | Co robi |
|---|---|
| `/pod` | stan: służba, zestaw, gniazda, pobrane i do pobrania |
| `/pod help` | lista komend |
| `/pod wez [id]` | weź zadanie (bez id = pierwsze wolne) |
| `/pod menu` | lista aut do pobrania na dokach (to samo co z targetu) |
| `/pod pobierz [nr]` | pobierz auto nr z listy (bez ox_lib / bez targetu) |
| `/pod attach [n]` | przypnij auto, którym jedziesz, do gniazda n (albo pierwszego wolnego) |
| `/pod oddaj` | oddaj auta (tylko w miejscu odbioru) |
| `/pod przyczepa`, `/pod truck` | postaw/znajdź zestaw albo samo auto do ciągnięcia |
| `/pod sprzataj` | usuń zestaw i auta pobrane na doki |
| `/pod slot [n]` | wypisz offset/rot gniazda n (kalibracja) |
| `/pod zapisz <co>` | wypisz gotową linijkę do configu: `base`, `przyczepa`, `truck`, `doki`, `ped`, `punkt`, `oddanie` |
| `/pod test` | szybki test: bierze zadanie (zestaw sam się postawi w bazie) |

Służbę włącza się w systemie duty `crp_jobcore` (punkt duty z targetem) — nie ma tu komendy do duty.

---

## 11. Co poustawiać przed testem (wszystko przez `/pod zapisz`)

1. `Config.Base.coords` — baza pod car dealerem (stań na placu → `/pod zapisz base`).
2. `Config.Base.trailerCoords` — gdzie staje przyczepa (`/pod zapisz przyczepa`, najlepiej z lawety).
3. `Config.Base.truckCoords` — gdzie staje ciężarówka (`/pod zapisz truck`).
4. `Config.Docks.coords` — środek doków (`/pod zapisz doki`).
5. `Config.Docks.ped.coords` — gdzie stoi obsługa doków (`/pod zapisz ped`).
6. `Config.Docks.spawnPoints` — punkty, na których pojawiają się auta (`/pod zapisz punkt`, co najmniej
   tyle, ile masz gniazd).
7. `Config.Trailer.slots` — kalibracja gniazd (`/pod attach 1`, `/pod slot 1`).
8. `Config.Handover.fallback` — zapasowy adres oddania (`/pod zapisz oddanie`).
9. `Config.Job` (firma wożąca) i `Config.RequireDuty` — sprawdź, czy zgadzają się z Twoim
   systemem duty w `crp_jobcore` (punkt duty musi obejmować tę pracę w `d_duty.lua`).

Nazwa folderu (`nano_cd`) **musi** się zgadzać z `Config.VehicleShop.delivery.resource` w `d_bossmenu.lua`.
Gdy tego zasobu nie ma w ogóle — bossmenu działa jak dawniej: auta wchodzą do garażu od razu.

---

## 12. Test na żywo w 6 krokach

1. W boss menu (jako policja) zamów 2–3 pojazdy **bez ⚡**; firma-dostawca klika „Akceptuj”.
2. `/pod` → widać nowe zadanie; w bazie pod car dealerem pojawia się przyczepa + ciężarówka.
3. `/pod wez`, zaczep lawetę (samo się zaczepi) i jedź na doki.
4. Przy pedzie: target (albo [E]) → wybierz auto → pojawia się na punkcie → wjedź nim na lawetę
   (przypnie się samo). Powtórz dla kolejnych aut z zamówienia.
5. Jedź do miejsca odbioru (blip) i wciśnij [E] → auta zjeżdżają z lawety z własnymi tablicami.
6. Sprawdź: wpisy w garażu kupującego, status „Dostarczone”, kasa u dostawcy. Zamów 3 auta mając
   2 gniazda → po pierwszym kursie zamówienie zostaje otwarte („zostało 1 pojazd”), wracasz na doki
   po ostatnie auto.
