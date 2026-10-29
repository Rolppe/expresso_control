# EXPRESSO-WIFI-APPI vaiheet 2–4 äpissä — brief (20.10.2026)

Suunnitelma: `~/palvelin/Infra/iot/expresso/paketit/WIFI-APPI.md` (luvut 1, 2, 4, 5 ja 7 — lue ne).
Firmware on valmis ja laitteella (Pico 192.0.2.13, UDP 47211, commit 39aec74): protokolla `pico/wifilink.py`
(lue koko tiedosto: se on ainoa totuus protokollasta). Käyttäjä 20.10.2026: äppi suoraan Picoon Wi-Fillä, BLE säilyy,
"kaikki toiminnot säästyy".

## Projekti

Macilla (`ssh dev-host`, aina `timeout`): `"$HOME/src/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI"`
(lainausmerkit: välilyönnit). Käännösympäristö ja ansat: `~/palvelin/expresso-ios/REKISTERI.md`
rivit 23–45 (PATH-shim, DEVELOPER_DIR, build-symlinkit, XCUITest-ohjain `expresso-ios/uitest/`).
**Ensin varmuuskopio:** `~/expresso-ios-varmuus/20261020/` (lib, ios, pubspec.yaml, pubspec.lock, test).

## Tehtävät

1. `lib/features/link/machine_link.dart`: abstrakti `MachineLink` — `isConnectedStream`, `isConnected`,
   `dataStream`, `sendCommand(String)`, `requestPendingBrewLog()`, `onAppResumed()`, `onAppPaused()`,
   `startScan({force})`, `disconnect()`, `deviceSummary()`. `BLERepository implements MachineLink` ilman
   käytöksen muutosta (vain `implements` ja tarvittaessa ohuet delegaatit).
2. `WifiRepository implements MachineLink` (`dart:io RawDatagramSocket`, `crypto`-paketin HMAC-SHA256):
   - `EXA1 hello` 2 s välein, kunnes `{"type":"hello","boot":…}`; uusi boot-id → alkusarja uudelleen.
   - komento `EXA1 <boot> <seq> <mac16> <cmd>`, mac16 = HMAC-SHA256(avain, "<boot> <seq> <cmd>") 16 ensimmäistä
     heksaa; **testivektori:** avain = tavut 0..31, viesti `abcd1234 7 stbt:90` → `131fc9407df6b680`.
     seq kasvava (aloitus esim. epoch-sekunnit), ack-odotus 300 ms, 3 uudelleenyritystä, `stale` → hello ja uusi
     yritys, `denied`/`unknown` → loki.
   - `sub` 5 s välein; `isConnected` = paketti saatu 3 s sisällä; alkusarja yhdistyessä `sync`, `sync` (400 ms),
     `brew_log?` (700 ms) — kuten `ble_repository.dart:912-920`.
   - `dataStream`: jokainen datagrammi JSON-oliona, paitsi `type` ack/hello/wifi_key.
   - `onAppPaused` sulkee soketin (iOS keskeyttää sen kuitenkin), `onAppResumed` avaa ja hello.
   - osoite ja avain `WifiKeyStore`sta (alla); ilman avainta ei yhdistä.
3. `LinkSelector implements MachineLink` omistaa BLE- ja Wi-Fi-linkin. Tila `linkMode` (shared_preferences:
   `auto`|`wifi`|`ble`, oletus `auto`). auto: aktiivinen = Wi-Fi kun se on yhdistetty, muuten BLE; vaihto 3 s
   hystereesillä, ei kesken uuttolokin (`brew_log`-osa saatu < 2 s sitten). Vain aktiivisen linkin `dataStream`
   välitetään; `sendCommand` aktiiviseen. **BLE pysyy käynnissä aina** (taustatila, T12): selector ei koskaan
   pysäytä BLE:n skannausta/yhteyttä. `bleRepositoryProvider`in kuluttajat (core/providers.dart, ble_notifier.dart,
   brew_log_notifier.dart, standby_timeout.dart, calibration_view.dart, pressure_calibration_view.dart,
   machine_data_notifier.dart) saavat selectorin (`MachineLink`); jos jokin käyttää BLE-spesifiä APIa, säilytä se
   BLE:lle erikseen ja kirjaa raporttiin.
4. `WifiKeyStore` (`flutter_secure_storage` → Keychain): `{key, host, port}`. Kun BLE yhdistyy eikä avainta ole,
   lähetä BLE:llä suoraan `wifi:key?` ja tallenna BLE-`dataStream`ista tuleva `{"type":"wifi_key",…}`.
   Asetuksiin myös käsin liitettävä avain (piilotettu kenttä "Wi-Fi-avain") simulaattoria ja vianetsintää varten.
   **Avainta ei koskaan lokiin, DLogiin eikä printiin.**
5. Asetukset-näkymä: "Yhteys: Automaattinen / Wi-Fi / Bluetooth" ja tilarivi (aktiivinen linkki, Pico boot,
   viimeisin paketti). Pääkuvan BT-ikoni näyttää Wi-Fi-ikonin, kun Wi-Fi on aktiivinen.
6. `ios/Runner/Info.plist`: `NSLocalNetworkUsageDescription` (suomeksi: "Yhteys espressokeittimeen kotiverkossa").
7. Testit (`flutter test`): `wifi_repository_test.dart` paikallista vale-Picoa vastaan (RawDatagramSocket
   127.0.0.1): hello, testivektori, ack-uudelleenyritys, toistettu ack, stale → hello, suodatus; `link_selector_test`:
   auto-vaihto ja hystereesi, ei vaihtoa kesken lokin, vain aktiivisen datan välitys, BLE ei pysähdy.

## Rajat

- Älä muuta firmwarea (`Infra/iot/expresso/pico`) äläkä protokollaa; ristiriita → raportoi.
- Älä asenna iPhoneen, älä committaa (pääistunto päättää), älä aja `flutter clean` build-symlinkkien yli.
- `DemoPico` (`EXPRESSO_DEMO`) jatkaa toimimista.
- Jokaisella komennolla aikaraja; pitkät buildit lokiin ja paluukoodi.

## Todennus ja raportti (≤ 40 riviä)

`flutter analyze` (ei uusia virheitä vs. varmuuskopio), `flutter test` (tulos ja exit), iOS-simulaattorikäännös
rekisterin ohjeella (exit). Jos ehdit: XCUITest-ohjaimella simulaattorissa avain liitetään asetuksiin (avaimen saat
pääistunnolta pyytämällä — älä lue sitä Picolta itse), tila Wi-Fi, ja pääkuvaan tulee lämpötila oikealta Picolta.
Raportti: muutetut tiedostot (+/- rivit), testien tulokset, avoimet kohdat, BLE-spesifit riippuvuudet.
