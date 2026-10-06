# nano_cd — jak to działa (od A do Z)

Ten plik to „mapa” skryptu: kto z kim gada, co gdzie leży i co się dzieje w każdej chwili.
Ma Ci wystarczyć, gdy będziesz przenosić te pliki do własnego zasobu CD/POD.

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
        ┌───────────────────────────────────────────────┐
        │  nano_cd (ten zasób) — wozi auta lawetą tr2   │
        │   plac CD → załadunek → jazda → miejsce odbioru│
        └───────────────────────┬───────────────────────┘
                                │ 3. oddanie: crp_bossmenu:server:deliveryDone
                                ▼   (orderId, tablice, final, kto)
        ┌──────────────────────────────────────────────────────────┐
        │  bossmenu: wpis pojazdów do garażu kupującego, przelew   │
        │  kasy firmie dostawcy, zamówienie → „Dostarczone”        │
        └──────────────────────────────────────────────────────────┘
```

**Podział odpowiedzialności:**
* `bossmenu` — pieniądze, zamówienie, garaż kupującego (`owned_vehicles`), status zamówienia.
* `nano_cd` — fizyczne auta: przyczepa, załadunek, jazda, rozładunek, pilnowanie miejsca oddania.
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

`express = true` (szybki transport) **nie jedzie lawetą** — takie auto jest już w garażu w chwili przyjęcia zamówienia. Ładujemy tylko pozycje bez `express`.

Numer `index` to pozycja auta w zamówieniu — po nim bossmenu wie, które auto oddajesz.

---

## 3. Cykl życia zadania (stany)

```
      start / resend
            │
            ▼
       ┌─────────┐   pracownik bierze zadanie (/pod wez)   ┌─────────┐
       │ pending │ ───────────────────────────────────────►│ loading │
       └─────────┘                                         └────┬────┘
            ▲                                                   │ wszystkie auta na lawecie
            │ kierowca wyszedł z serwera                        ▼
            │                                             ┌──────────┐
            └─────────────────────────────────────────────│ hauling  │
                                                          └────┬─────┘
                                   oddanie w miejscu odbioru    │
                                   ┌───────────────────────────┴──────────────────┐
                                   ▼                                              ▼
                        zostały auta (final = false)                   wszystko oddane (final = true)
                     wraca na plac, stan → loading                        stan done, zadanie znika
```

Stan trzyma **serwer** (`CD.jobs[id]`), klient dostaje tylko kopię (`Snapshot`) i pyta serwer o każdy fakt
(„załadowane”, „oddane”). Dzięki temu restart zasobu nic nie gubi (patrz punkt 5).

---

## 4. Załadunek i doczepienie (część fizyczna, `client.lua`)

1. **Przyczepa `tr2`** — `Config.Trailer.mode = 'spawn'` (skrypt ją stawia) albo `'static'` (używa tej, która
   już stoi w świecie — MLO/mapper). Gdy wybuchnie/zniknie, a `respawnIfMissing = true` i laweta jest pusta,
   skrypt stawia nową.
2. **Auto do ciągnięcia** — `Config.Truck` (`mode = 'spawn'` postawi `packer`), a `Config.Trailer.autoAttachTruck`
   sam zaczepia przyczepę, gdy wsiądziesz autem z listy `truckModels` i podjedziesz bliżej niż 25 m
   (`AttachVehicleToTrailer`).
3. **Gniazda** — `Config.Trailer.slots` to lista miejsc na lawecie. Każde ma `offset` (pozycja auta w układzie
   przyczepy: X = prawo/lewo, Y = przód/tył, Z = góra/dół), `rot` (obrót) i `bone` (kość przyczepy, 0 = korzeń).
4. **Doczepienie auta** — `AttachEntityToEntity(auto, przyczepa, bone, offset, rot, … )`:
   skrypt tworzy auto (model z zamówienia), ustawia mu tablicę **tę samą**, którą potem dostanie garaż
   (`SetVehicleNumberPlateText`), stawia na ziemi, doczepia do gniazda, gasi silnik.
   Jeśli auto drga/odpada → `Config.Trailer.attach`: `softPinning`, `collision`, `fixedRot`, `vertexIndex`.
5. **Załadunek w grze** — stoisz na placu (`Config.Depot.radius`) blisko przyczepy (< 12 m), masz zadanie
   i wolne gniazdo → tekst `[E] Załaduj na lawetę: Nazwa (gniazdo 1/2)` → `Progress` (pasek z ox_lib)
   → auto wskakuje na gniazdo → klient wysyła `nano_cd:server:loaded`.
   `Config.AutoLoad = true` albo `/pod auto` ładuje bez wciskania E (tryb testowy).
6. **Zostały auta, a brak gniazd?** Komunikat „Wszystkie gniazda zajęte – zawieź auta i wróć”. To normalne
   przy zamówieniu większym niż liczba gniazd: robisz dwa kursy, a zamówienie zamyka się dopiero po ostatniej partii.

---

## 5. Oddanie pojazdów (najważniejsze, bo tu jest całe bezpieczeństwo)

* Klient pozwala oddawać tylko gdy jesteś w promieniu `Config.Handover.radius` od **miejsca odbioru**
  (adres przyszedł z boss menu: punkt pracy kupującego, np. komenda policji; gdy zamówienie adresu nie ma →
  `Config.Handover.fallback`).
* Serwer sprawdza to **jeszcze raz** (`Config.Handover.maxServerDistance`, domyślnie 90 m) — nawet gdyby ktoś
  wysłał event ręcznie z drugiego końca mapy, nic nie odda.
* Rozładunek: auta zjeżdżają obok przyczepy według `Config.Handover.unload` (`side`, `firstY`, `spacing`,
  `useTrailerHeading`), `keepVehicles = true` zostawia je na miejscu (widowiskowo), `false` usuwa.
* Dopiero wtedy leci `crp_bossmenu:server:deliveryDone(orderId, tablice, final, kto)`:
  * `final = false` → część aut oddana: bossmenu wpisuje **te** auta do garażu, zamówienie zostaje otwarte,
    Ty wracasz na plac po resztę;
  * `final = true` → wpis do garażu, przelew `total` na konto firmy dostawcy, status „Dostarczone”,
    zadanie znika z listy i z bazy.

---

## 6. Trwałość (restart serwera / zasobu)

* Wszystkie zadania są zapisywane w tabeli **`crp_cd_jobs`** (`id`, `data` = całe zadanie w JSON, `state`).
  Tabela tworzy się sama (`CREATE TABLE IF NOT EXISTS`), więc nic nie musisz wgrywać ręcznie.
* `SaveJob` przy każdej zmianie stanu, `DropJob` gdy zadanie zniknie (oddane / anulowane).
* Po starcie zasobu serwer: tworzy tabelę → wczytuje zadania → zadania ze stanu `hauling`/`handover`
  wracają do `pending` → po 2 sekundach pyta boss menu `deliveryResend`, żeby dostać aktualną listę.
* `Config.RefreshSeconds` (30 s): jeśli ktoś jest na służbie, nano_cd i tak co pół minuty pyta boss menu
  o wznowienie zadań — to łapie sytuacje „boss menu wystartowało po nas”.
* Kierowca wyszedł z serwera → zadanie wraca na listę (`pending`, `claimedBy = nil`), auta na lawecie
  zostają w świecie, ale zadanie jest wolne dla kogoś innego.

---

## 7. Uprawnienia i służba

| Opcja | Znaczenie |
|---|---|
| `Config.AllowAnyone = true` | tryb testowy: każdy może wziąć zadanie i załadować auta |
| `Config.Job = 'cd'` | nazwa pracy CD/POD w ESX (używana, gdy `AllowAnyone = false`) |
| `Config.RequireDuty = true` | zadanie można wziąć dopiero na służbie (`/pod sluzba` lub `SetDuty`) |
| `Config.AutoDuty = true` | wejście w strefę placu samo ustawia „na służbie” (wygodne w testach) |

Dla przyszłego, pełnego skryptu CD: `exports.nano_cd:SetDuty(source, true/false)` — ustawiasz służbę
ze swojego skryptu i nic więcej nie trzeba zmieniać.
Jest też `exports.nano_cd:Handin(id, plates, byName)` — wymuszenie oddania z zewnątrz (np. z konsoli
albo z Twojego panelu), oraz `exports.nano_cd:Jobs()` / `:Job(id)` do podejrzenia stanu.

---

## 8. Komendy w grze (do testów i kalibracji)

| Komenda | Co robi |
|---|---|
| `/pod` | stan: służba, przyczepa, zajęte gniazda, wszystkie zadania |
| `/pod help` | lista komend |
| `/pod sluzba` | start/koniec służby |
| `/pod wez [id]` | weź zadanie (bez id = pierwsze wolne) |
| `/pod test` | szybki test: przyczepa + auto + wzięcie zadania + auto-załadunek |
| `/pod auto` | automatyczny załadunek bez wciskania E |
| `/pod przyczepa`, `/pod truck` | postaw przyczepę / auto do ciągnięcia |
| `/pod attach 1` | doczep swoje auto do gniazda 1 (kalibracja „na oko”) |
| `/pod slot 1` | wypisz gotową linijkę `offset`/`rot` gniazda 1 do wklejenia w config |
| `/pod oddaj` | oddaj auta (działa tylko w miejscu odbioru) |

**Kalibracja gniazd:** wsiądź autem, podjedź na plac, `/pod attach 1`, popraw auto w grze jak Ci pasuje,
`/pod slot 1` → wklej wypisaną linijkę do `Config.Trailer.slots`. To samo dla gniazda 2, 3, 4…

---

## 9. Co poustawiać przed testem (jedno poprawnie = jeden punkt)

1. `Config.Depot.coords` + `radius` — plac CD (duży, płaski teren).
2. `Config.Trailer.coords` — gdzie ma stać przyczepa; `Config.Trailer.mode = 'spawn'` lub `'static'`.
3. `Config.Trailer.slots` — gniazda (patrz kalibracja wyżej). Ile gniazd = ile aut na jeden kurs.
4. `Config.Handover.fallback` — adres dla zamówień bez adresu z panelu (prace bez punktu w `Config.Locations`).
5. `Config.Handover.radius` (klient) i `maxServerDistance` (serwer) — promień oddania.
6. `Config.AllowAnyone = false` + `Config.Job = 'cd'` + `RequireDuty = true` — dopiero gdy wdrożysz pełny skrypt CD.

Nazwa folderu (`nano_cd`) **musi** się zgadzać z `Config.VehicleShop.delivery.resource` w `d_bossmenu.lua`.
Gdy nie ma tego zasobu w ogóle — bossmenu działa jak dawniej: auta wchodzą do garażu od razu.

---

## 10. Test na żywo w 6 krokach

1. W boss menu (jako policja) zamów 2–3 pojazdy **bez ⚡**; firma-dostawca klika „Akceptuj”.
2. W konsoli klienta: `/pod` → widać nowe zadanie (stan `pending`).
3. `/pod test` (albo `/pod wez` + jazda na plac + `[E]`) → auta wjeżdżają na gniazda lawety `tr2`.
4. Jedź do miejsca odbioru — blip „Odbiór: …” prowadzi; na miejscu `[E] Oddaj pojazdy`.
5. Sprawdź: auta stoją obok lawety z **własnymi tablicami**, a w garażu kupującego są wpisy;
   zamówienie w panelu = „Dostarczone”, kasa u dostawcy.
6. Zamów 3 auta mając 2 gniazda → po pierwszym kursie zamówienie **zostaje otwarte** („zostało 1 pojazd”),
   wracasz na plac, ładujesz ostatnie, oddajesz → wtedy się zamyka.
