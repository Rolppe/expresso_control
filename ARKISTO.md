# expresso-ios — arkisto

Aktiivisesta rekisteristä poistettu tai muutettu tieto sanatarkasti, vanhin ensin (V-082, 28.9.2026).
Tästä ei poisteta mitään. Purku ei lue tätä tiedostoa: se luetaan vain vianselvityksessä, kun
halutaan tietää, mitä rekisterissä on joskus ollut. Kirjoittaja: `claude/siirto/tools/arkisto.mjs`.

## 5.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-ASENNUS — asenna iOS-äppi käyttäjän iPhoneen ilmaisella Apple ID:llä ja testaa BLE-yhteys keittimeen; vaatii käyttäjältä ensin Apple ID:n Xcodeen (Settings → Accounts) ja iPhonen kytkennän Maciin (Developer Mode päälle, luota tähän tietokoneeseen) — polut: expresso-ios/**, Macin `…/silvia_pico_flutter_UI/ios/` — aloitus: /rd EXPRESSO-IOS-ASENNUS

### Tarkoitus ja raja — poistettu tai muutettu

ennen muutoksia `~/expresso-ios-varmuus/20261005/`. **Sama `lib/` on yhteinen skoopin `infra expresso`
kanssa:** sen muutokset (esim. a741d90 valmiustila) tulevat iOS-äppiin seuraavassa käännöksessä.

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| Asennus iPhoneen ja BLE-testi keittimellä | ALUSTA valmis 5.10.2026; odottaa käyttäjän Apple ID -kirjautumista Xcodeen (Xcode näytti "Invalid credentials … missing Xcode-Token") | EXPRESSO-IOS-ASENNUS: käyttäjä lisää Apple ID:n Xcodeen (Settings → Accounts) ja kytkee iPhonen (Developer Mode päälle); agentti asentaa `flutter install`/`flutter run`; testi keittimen BLE:llä |
| 7 vrk:n uudelleenallekirjoitus | myöhemmin | ajastettu uudelleenasennus Macilta, kun iPhone on samassa verkossa |
| Täysi pariteetti (taustayhteys, ilmoitukset) | myöhemmin (käyttäjä 5.10.2026) | oma paketti BLE-version jälkeen; `UIBackgroundModes` (bluetooth-central) puuttuu Info.plististä |
| Xcode 27 + Flutter 3.41.6 -kierrot | käytössä 5.10.2026 (ALUSTA) | poista, kun Flutter tukee Xcode 27:ää: `ARCHS[sdk=iphonesimulator*]=arm64` Debug.xcconfigissa, xcrun-shim, build-symlinkit |

### Historia — poistettu tai muutettu

Historia: `expresso-ios/HISTORIA.md` (syntyy ensimmäisessä pakkauksessa), ei lueta purussa.

## 5.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-ASENNUS — asenna iOS-äppi käyttäjän iPhoneen ilmaisella Apple ID:llä ja testaa BLE-yhteys keittimeen; esiehdot valmiit 5.10.2026 (Apple ID Xcodessa, iPhone 15 Pro iOS 27.0.1 UDID YOUR_DEVICE_UDID kaapelilla, identiteetti "Apple Development: 78311409+Rolppe@users.noreply.github.com (YOUR_CERT_ID)"); ensin `flutter run --release -d YOUR_DEVICE_UDID` (DEVELOPER_DIR + shim-PATH), sitten ennen BLE-testiä kysy, onko käyttäjä keittimen ääressä; työ Macin `silvia_pico_flutter_UI/ios/`-kansiossa — polut: expresso-ios/** — aloitus: /rd EXPRESSO-IOS-ASENNUS

### Tarkoitus ja raja — poistettu tai muutettu

**Laite ja allekirjoitus (mitattu 5.10.2026):** `flutter devices`: iPhone 15 Pro, iOS 27.0.1, UDID YOUR_DEVICE_UDID, kaapelilla; `security find-identity`: "Apple Development: 78311409+Rolppe@users.noreply.github.com (YOUR_CERT_ID)" voimassa; Xcode-tili 78311409+Rolppe@users.noreply.github.com; Developer Mode oli jo päällä (käyttäjä).

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| Asennus iPhoneen ja BLE-testi keittimellä | kesken 5.10.2026 (ALUSTA valmis, esiehdot todennettu: Apple ID Xcodessa, iPhone kaapelilla); odottaa käyttäjää (keittimen ääreen BLE-testiä varten) | EXPRESSO-IOS-ASENNUS: `flutter run --release -d YOUR_DEVICE_UDID` (DEVELOPER_DIR + shim-PATH); kysy ennen BLE-testiä, onko käyttäjä keittimen ääressä |
| 7 vrk:n uudelleenallekirjoitus (kirjattu 5.10.2026) | avoin; odottaa konetta mac (myöhemmin) | ajastettu uudelleenasennus Macilta, kun iPhone on samassa verkossa |

### Avoimet asiat — valmis

| Asia | Tila | Seuraava askel |
|---|---|---|
| Agentin näkymä iPhoneen (5.10.2026) | todennettu: `xcrun devicectl device capture screenshot -d <UDID> --destination /tmp/x.png` + scp, ja `devicectl device process launch --console --terminate-existing` (FBP-iOS-loki; Dartin print ei näy) toimivat ssh:lla ilman kaapelia | käytä testeissä, älä kysy käyttäjältä ruudun sisältöä |

## 5.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-BLE-TESTI — BLE-korjaus (5.10.2026, `ble_repository.dart`: systemDevices-nimitarkistus + advName-osuma skannauksessa; varmuus `~/expresso-ios-varmuus/ble_repository.dart.20261005-ennen`) asennetaan iPhoneen: käyttäjä ajaa `flutter run --release -d YOUR_DEVICE_UDID` Macin Terminalissa (ssh-codesign kaatuu avainnippuun); sitten agentti todentaa itse: `xcrun devicectl device capture screenshot` (lämpötila ≠ 0.0) ja `devicectl device process launch --console --terminate-existing` (connect → 180a/2a29 löytyy, ei disconnectia); kysy ensin, onko käyttäjä keittimen ääressä — polut: expresso-ios/** — aloitus: /rd EXPRESSO-IOS-BLE-TESTI

### Tarkoitus ja raja — poistettu tai muutettu

**Laite ja allekirjoitus (mitattu 5.10.2026):** `flutter devices`: iPhone 15 Pro, iOS 27.0.1, UDID YOUR_DEVICE_UDID, kaapelilla; `security find-identity`: "Apple Development: 78311409+Rolppe@users.noreply.github.com (YOUR_CERT_ID)" voimassa; Xcode-tili 78311409+Rolppe@users.noreply.github.com; Developer Mode oli jo päällä (käyttäjä). `flutter devices` ilman `--device-timeout 30` ei aina näytä iPhonea (`devicectl list devices` näytti); Macissa ei ole `timeout`-komentoa.

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| BLE-testi keittimellä | kesken 5.10.2026: ensimmäinen ajo yhdisti väärään laitteeseen (data 0.0, console-loki: palvelut 180a/2a50, 1804, valmistajan UUIDit → disconnect). Juurisyyt: (A) `_tryKnownDevices` yhdisti `systemDevices([180A])`-laitteeseen ilman nimitarkistusta, (B) Picolla ei GAP-nimeä → iOS välimuistittaa platformName "MPY BTSTACK" ja skannaus ohitti Picon. Korjaus tehty Macilla (toteuttaja-sonnet, analyze 0, simulaattoribuild vihreä, diff todennettu), ei committia; odottaa asennusta | EXPRESSO-IOS-BLE-TESTI (ks. SEURAAVA); tarkista testissä, ettei korjaus A ohita oikeaa Picoa systemDevices-reitillä, jos iOS on nimennyt sen "MPY BTSTACK" (skannaus-, bonded- ja previous-reitit tavoittavat sen). Firmwaren `ble.config(gap_name='EspressoPico')` olisi juurikorjaus B:lle → kirjaa firmwaren omistajaskoopille `/vika`-reitillä (BLE-testin jälkeen) |

## 6.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-BLE-TESTI — NAYTTO valmis 6.10.2026 (Macin työkopio, ei vielä iPhonessa): kysy ensin, onko käyttäjä keittimen ääressä; käyttäjä ajaa Macin Terminalissa `flutter run --release` ja kytkee "Pidä näyttö päällä"; agentti todentaa kuvakaappauksella (lämpötila ≠ 0.0) ja console-lokilla (connect → 180a/2a29, ei disconnectia) — polut: expresso-ios/** — aloitus: /pura expresso-ios

### Tarkoitus ja raja — poistettu tai muutettu

`path_provider` (pubspec.yaml, luettu 5.10.2026). Dart-koodi vartioi Android-natiivikutsut jo
**Laite ja allekirjoitus (mitattu 5.10.2026):** `flutter devices`: iPhone 15 Pro, iOS 27.0.1, UDID YOUR_DEVICE_UDID, kaapelilla; `security find-identity`: "Apple Development: 78311409+Rolppe@users.noreply.github.com (YOUR_CERT_ID)" voimassa; Xcode-tili 78311409+Rolppe@users.noreply.github.com; Developer Mode oli jo päällä (käyttäjä). `flutter devices` ilman `--device-timeout 30` ei aina näytä iPhonea (`devicectl list devices` näytti); Macissa ei ole `timeout`-komentoa. iPhone "available (paired)" 5.10.2026 21.06; BLE-korjaus asennettu: `~/expresso-ios-build/iphoneos/Runner.app` ja `Release-iphoneos/Runner.app` 21.09:38, korjattu `ble_repository.dart` 21.01:29 (`stat`).

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| BLE-testi keittimellä | kesken 5.10.2026; korjaus (A systemDevices-nimitarkistus, B advName-osuma) asennettu iPhoneen 21.09, todennus puuttuu (lukitusnäyttö esti ajon 21.52) (todenna viim. 19.10.2026) | NAYTTO:n jälkeen käyttäjä ajaa `flutter run --release` Macin Terminalissa ja kytkee asetuksen; agentti: kuvakaappaus (lämpötila ≠ 0.0) + console-loki (connect → 180a/2a29, ei disconnectia); kysy ensin onko käyttäjä keittimen ääressä. Tarkista, ettei A ohita oikeaa Picoa ("MPY BTSTACK"); firmwaren `ble.config(gap_name='EspressoPico')` → `/vika infra expresso` testin jälkeen |
| EXPRESSO-IOS-NAYTTO | valmis 6.10.2026 Macilla (ei iPhonessa); shared_preferences + wakelock_plus 1.7.0, `lib/core/keep_screen_on.dart`, SwitchListTile asetusnäkymässä; hyväksyntä 0 pääistunnossa, analyze 7→7, sim- ja release-käännös 0, savutesti elossa | asennus iPhoneen käyttäjän `flutter run --release` -ajossa BLE-testin yhteydessä; lib/ yhteinen Android-äpin kanssa → kerro skoopille `infra expresso` uusista riippuvuuksista |

## 6.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-BLE-TESTI — NAYTTO-build asennettu iPhoneen 6.10.2026 ja äppi käynnissä; käyttäjä keittimen ääressä: hän kytkee "Pidä näyttö päällä", agentti todentaa kuvakaappauksella (lämpötila ≠ 0.0) ja console-lokilla (connect → 180a/2a29, ei disconnectia) — polut: expresso-ios/** — aloitus: /pura expresso-ios

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| BLE-testi keittimellä | kesken 6.10.2026 (NAYTTO-build asennettu iPhoneen 07.48, äppi käynnissä, todennus puuttuu); odottaa käyttäjää (todenna viim. 20.10.2026) | käyttäjä kytkee "Pidä näyttö päällä" ja sanoo valmis → agentti: kuvakaappaus (`xcrun devicectl device capture screenshot`) lämpötila ≠ 0.0 + console-loki (connect → 180a/2a29, ei disconnectia); sen jälkeen kytkimen säilyminen uudelleenkäynnistyksessä, ettei A ohita oikeaa Picoa ("MPY BTSTACK") ja `/vika infra expresso` (firmwaren `ble.config(gap_name='EspressoPico')`) |

## 6.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-BLE-TESTI — odottaa V-205:tä (infra expresso: Pico sallii vain yhden BLE-yhteyden, OnePlussan Android-äppi varaa sen); korjauksen ja flashauksen jälkeen käyttäjä keittimen ääressä, agentti todentaa kuvakaappauksella (lämpötila ≠ 0.0) ja console-lokilla (connect → 180a/2a29, ei disconnectia) Android-äpin ollessa yhteydessä — polut: expresso-ios/** — aloitus: /pura expresso-ios

### Tarkoitus ja raja — poistettu tai muutettu

kulkee nyt Zeron kautta), Androidin keep-alive-palvelu ja painokehoteilmoitus. Firmware ja
**Simulaattorikehitys ja demotila (6.10.2026):** iOS-simulaattorissa ei ole CoreBluetoothia, joten `lib/features/ble/demo_pico.dart` simuloi Picon: `BLERepository.demoMode` = `bool.fromEnvironment('EXPRESSO_DEMO')`, ja sen ollessa päällä `enableBackgroundWatch`/`startScan`/`sendCommand`/`disconnect` ohjautuvat demoon (live-paketti 200 ms välein, settings-paketti `sync`:iin ja asetusmuutoksiin, uutto käynnistyy itse 30 s joutokäynnin jälkeen: PRE_INFUSION → BREW 25 s → SOFT_RELEASE → IDLE). Ilman lippua koodi on ennallaan (Android ja iPhone). Oma simulaattori `iPhone 15 Pro expresso` (iOS 27.0, UDID F47C2720-C9C5-48E7-B776-F597F234A110); remoten `iPhone 15 Pro` (ACB1207B-…) on skoopin `remote`, siihen ei kosketa. Ajo: `flutter build ios --simulator --debug --dart-define=EXPRESSO_DEMO=true` (PATH ja DEVELOPER_DIR kuten yllä), `xcrun simctl install F47C2720-C9C5-48E7-B776-F597F234A110 ~/expresso-ios-build/iphonesimulator/Runner.app`, `xcrun simctl launch --terminate-running-process F47C2720-C9C5-48E7-B776-F597F234A110 io.github.rolppe.silviaPicoUi`, kuvakaappaus `xcrun simctl io <UDID> screenshot <png>`. Varmuuskopio ennen muutosta ja kuvakaappaukset `~/expresso-ios-varmuus/20261006-demo/`. Havainto (todentamatta): firmware lähettää `weight`/`flow` (`bluetooth_handler.py:83`, `flow_payload`), äppi lukee `weight_g`/`weight_abs_g`/`flow_g_s` (`machine_data_notifier.dart:151-167`); demo käyttää äpin avaimia. Mac (16 Gt): kahdella simulaattorilla vapaita sivuja vähän (`vm_stat` 4250 × 16 kt).

### Päätökset — poistettu tai muutettu

- **Pääistunto 6.10.2026:** demo on käännöslippu, ei ajonaikainen asetus → Android- ja iPhone-käännökset ennallaan; brew_log-multipack ja kalibrointikomennot eivät ole demossa (komennot ohitetaan).

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| Simulaattorikehitys demotilassa | kesken 6.10.2026 (demo käytössä; brew_log-multipack puuttuu, uuttolokin näkymät eivät saa dataa); odottaa käyttäjää (jatkokehityksen sisältö) | käyttäjä valitsee jatkon (esim. täysi pariteetti: ilmoitukset, taustatila) |
| Täysi pariteetti (taustayhteys, ilmoitukset) | avoin (myöhemmin, käyttäjä 5.10.2026) | oma paketti BLE-version jälkeen; `UIBackgroundModes` (bluetooth-central) puuttuu Info.plististä |

## 6.10.2026 — expresso-ios

### Päätökset — poistettu tai muutettu

- **Pääistunto 6.10.2026:** demo on käännöslippu, ei ajonaikainen asetus → Android- ja iPhone-käännökset ennallaan; kalibrointikomennot eivät ole demossa (komennot ohitetaan).

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| Simulaattorikehitys demotilassa | kesken 6.10.2026 (näkymäkierros tehty ohjaimella: uuttoloki, asetukset, kalibroinnit, vaakanäkymä; neljä iOS-korjausta, ks. Näkymäkierros; Vaihda-tyytyväisyys todennettu 20.28–20.30, ks. Tyytyväisyysvalinta; painekalibroinnin ajo demossa 20.38–20.39, ks. Painekalibrointi demossa) | käyttäjä valitsee jatkon (asteikkokalibrointia ei voi ajaa: firmwaressa ei `cal:`-käsittelijää, ehdotettu käyttäjälle `/vika infra expresso`) |

## 6.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-BLE-TESTI — odottaa V-205:tä (infra expresso: Pico sallii vain yhden BLE-yhteyden, OnePlussan Android-äppi varaa sen); korjauksen ja flashauksen jälkeen käyttäjä asentaa release-version Macin Terminalista ja on keittimen ääressä, agentti todentaa kuvakaappauksella (lämpötila ≠ 0.0) ja console-lokilla (connect → 180a/2a29, ei disconnectia) Android-äpin ollessa yhteydessä; samalla pariteetti: uutto iPhone lukittuna → ilmoitus "Uutto tallennettu" (salli ilmoitukset) ja BLE säilyy taustalla — polut: expresso-ios/** — aloitus: /pura expresso-ios

### Tarkoitus ja raja — poistettu tai muutettu

**Yhteiskäyttö Android-äpin kanssa (mitattu 6.10.2026):** BLE-testi ei löydä Picoa, koska OnePlussan Android-äppi `com.example.silvia_pico_ui` pitää GATT-yhteyttä EspressoPicoon (palvelimella `adb -s 127.0.0.1:5555 shell dumpsys bluetooth_manager`: `connected: 1`, mtu 517). iPhonen kuvakaappaus 6.10. 08.03: BT-kuvake punainen, lämpötila 0.0 °C, Mode IDLE; console-loki 08.03.56–08.04.40: `connectedPeripherals: 0`, kolme 15 s skannausta, ei yhtään connect-kutsua. Syy firmwaressa (`Infra/iot/expresso/KEHITYSYHTEYS.md:161`, MicroPython v1.28.0): `MAX_NR_HCI_CONNECTIONS 1` → yksi yhteys kerrallaan, ja `Infra/iot/expresso/pico/bluetooth_handler.py:204-220` käynnistää mainonnan vain katkaisussa → yhteyden aikana Pico ei mainosta. 5.10.2026:n "vihreä BT-ikoni, kaikki arvot 0.0" selittyy todennäköisesti samalla (ei todennettu). Korjaus kuuluu skoopille `infra expresso` (V-205, oma MicroPython-käännös); tämä skooppi ei muuta firmwarea.

### Päätökset — poistettu tai muutettu

- **Käyttäjä 6.10.2026:** Android-äppiä OnePlussassa ei pysäytetä iPhone-testin ajaksi ("siellä toimiva kehitys on tärkeää"); vuorottelu (force-stop) hylätty.

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| BLE-testi keittimellä | kesken 6.10.2026 (yritys 08.03: Picoa ei löydy, Android-äppi varaa Picon ainoan BLE-yhteyden); odottaa skooppia infra expresso (V-205: Picon kahden yhteyden firmware; todenna viim. 20.10.2026) | kun V-205 korjattu ja flashattu: käyttäjä keittimen ääressä, "Pidä näyttö päällä" päällä → agentti kuvakaappaus (lämpötila ≠ 0.0) + console-loki (connect → 180a/2a29, ei disconnectia) Android-äpin ollessa yhteydessä samaan aikaan; sen jälkeen kytkimen säilyminen uudelleenkäynnistyksessä, ettei A ohita oikeaa Picoa ("MPY BTSTACK") ja firmwaren `ble.config(gap_name='EspressoPico')` ehdotetaan skoopille infra expresso /vika-reitillä |
| 7 vrk:n uudelleenallekirjoitus (kirjattu 5.10.2026) | avoin; odottaa konetta mac (myöhemmin). **Este mitattu 5.10.2026:** `ssh dev-host flutter build ios --release` kaatuu codesigniin `errSecInternalComponent` — login-avainnippu on ssh-istunnossa lukossa (`security show-keychain-info` → "User interaction is not allowed"); käyttäjän ajo Macin Terminalissa onnistui | ajastettu uudelleenasennus Macilta, kun iPhone on samassa verkossa — ajon pitää tapahtua Macin graafisessa istunnossa (esim. LaunchAgent), ei ssh:lla |
| Täysi pariteetti (taustayhteys, ilmoitukset) | kesken 6.10.2026 (toteutettu ja todennettu simulaattorissa: lomake + lupakysely; laitetodennus puuttuu; todenna viim. 20.10.2026) | todenna iPhonella BLE-testin yhteydessä: release-asennus Macin Terminalista (ssh:lla codesign kaatuu), uutto iPhonen ollessa lukittuna → ilmoitus "Uutto tallennettu", yhteys säilyy taustalla |

## 6.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-PARITEETTI — käyttäjä asentaa release-version Macin Terminalista (mukana valmiustila-asetus) ja on keittimellä, Android-äppi suljettuna; iPhone lukittuna uutto → ilmoitus "Uutto tallennettu" (salli ilmoitukset) ja BLE säilyy taustalla, agentti todentaa console-lokilla ja kuvakaappauksella; samalla valmiustila-asetuksen laitetesti; ennen allekirjoituksen vanhenemista ~12.10.2026 — polut: expresso-ios/** — aloitus: /pura expresso-ios

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| Valmiustilan aika -asetus | kesken 6.10.2026 (todennettu simulaattorissa, laitetesti puuttuu; todenna viim. 20.10.2026); odottaa käyttäjää (iPhone-asennus Macin Terminalista) | laitetesti: valinta → Picon `STBY timeout_min=` (pico_dev `stby?`/sarjaloki infra expressolta) tai ajastettu siirtymä `IDLE · STANDBY`; sen jälkeen firmware-ehdotus /vika infra expresso (ks. Päätökset) |
| 7 vrk:n uudelleenallekirjoitus (kirjattu 5.10.2026; allekirjoitus vanhenee n. 12.10.2026) | avoin; odottaa konetta mac (myöhemmin). **Este mitattu 5.10.2026:** `ssh dev-host flutter build ios --release` kaatuu codesigniin `errSecInternalComponent` — login-avainnippu on ssh-istunnossa lukossa (`security show-keychain-info` → "User interaction is not allowed"); käyttäjän ajo Macin Terminalissa onnistui | ajastettu uudelleenasennus Macilta, kun iPhone on samassa verkossa — ajon pitää tapahtua Macin graafisessa istunnossa (esim. LaunchAgent), ei ssh:lla |
| Täysi pariteetti (taustayhteys, ilmoitukset) | kesken 6.10.2026 (toteutettu ja todennettu simulaattorissa: lomake + lupakysely; laitetodennus puuttuu; todenna viim. 20.10.2026) | todenna iPhonella (SEURAAVA PAKETTI): release-asennus Macin Terminalista (ssh:lla codesign kaatuu) ennen 12.10.2026, uutto iPhonen ollessa lukittuna → ilmoitus "Uutto tallennettu", yhteys säilyy taustalla |

## 7.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-VALMIUSTILA-LAITE — valmiustilan aika + lämpötila keittimellä: flash (stbt 14772b0 + V-154-SYY 9103dc2, käyttäjän lupa ja läsnäolo), iPhone-asennus tehty 6.10.2026 23.11 (stbt-käännös, `ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh'`), äpissä 15 min + 70 °C → Picon sarjaloki STBY timeout_min=15, STBT temp=70, STBY_ON target=70, kytkin → STBY_OFF (flash infra expresson pico_dev-työkalulla, V-220) — polut: expresso-ios/** — aloitus: /pura expresso-ios

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| Valmiustilan aika + lämpötila (60–95 °C) -asetus | kesken 6.10.2026 (todennettu simulaattorissa 22.20, laitetesti puuttuu; todenna viim. 20.10.2026); odottaa käyttäjää (flashin lupa ja läsnäolo) | SEURAAVA PAKETTI: flash (stbt + V-154-SYY, infra expresson pico_dev, V-220) → iPhone-asennus (tehty 6.10.2026 23.11, ks. Agentin oma iPhone-asennus) → äpissä 15 min + 70 °C → Picon sarjaloki `STBY timeout_min=15`, `STBT temp=70`, 15 min jälkeen `STBY_ON … target=70`, kytkin → `STBY_OFF reason=switch`; äppi ennen flashia: vanha firmware ei tunne `stbt:`ia |
| Agentin oma iPhone-asennus (käyttäjä 6.10.2026 ~22.05: "tämä ominaisuus pitää saada korjattua siten että saat asennuksen itse toimimaan"; kattaa myös 7 vrk:n uudelleenallekirjoituksen) | korjattu 6.10.2026 (EXPRESSO-IOS-ASENNUS-AGENTTI + -AJASTUS: asennus, `--uusi` ja ajastuksen päätöshaarat todennettu); odottaa ajoa (ensimmäinen ajastettu uusinta, vaatii avatun Mac-näytön; todenna viim. 12.10.2026). **Juurisyy (mitattu 5.10. ja 6.10.2026 22.56):** ssh-istunto ei pääse login-avainnippuun (`security show-keychain-info` → "User interaction is not allowed") → codesign `errSecInternalComponent`; aiemmat asennukset olivat käyttäjän Terminal-ajoja, ja 6.10. ~22.00 "Error running application" oli lukitun iPhonen käynnistysvirhe. **Ratkaisu:** LaunchAgent `com.example.expresso-asennus` (GUI-istunto, ei RunAtLoad/StartInterval, vain `launchctl kickstart`; lähde `expresso-ios/mac/`, Macilla `~/expresso-ios-asennus/expresso-asennus.sh`). Ilman argumenttia (ssh): rsync-peili projektista `~/expresso-ios-asennus/projekti/`iin → kickstart → odotus ≤ 540 s → lokirivit ja exit; `--agentti`: `flutter build ios --release` + `devicectl device install app` (3 yritystä 15 s välein; kAMDRemoteConnectError oli hetkellinen 23.07 ja 23.10); `--check` (preflight-rivi), `--tila` (odota/lue viimeisin ajo; 4 = kesken); lokit `asennus.loki`, `build.log`. **Todennettu 6.10.2026 23.11.33:** ajo exit 0, 9 s; `devicectl device info apps`: eXpresso `io.github.rolppe.silviaPicoUi` 1.0.0; binäärissä `stbt:` (21.59:n käännöksessä 0); asennus onnistuu iPhonen ollessa lukossa. Ensimmäinen ajo 343 s: Macissa dartvm-ikkuna (käyttäjä ohitti kysymyksen lajista), ei toistunut seuraavissa ajoissa. **Uusinta (correction-2, todennettu 23.17.34):** tavallinen uudelleenasennus ei uusi profiilia (Xcode käyttää voimassa olevaa), joten `--uusi` siirtää expresson profiilin (`…io.github.rolppe.silviaPicoUi`) hakemistoon `~/expresso-ios-asennus/vanhat-profiilit/` ennen käännöstä, palauttaa sen käännösvirheessä ja vaatii, että uusi vanhenee myöhemmin (muuten `virhe: profiili ei uusiutunut`, exit 7): 2026-10-12T17:35:27Z → 2026-10-13T20:17:22Z (profiili `6912e2b9…`); remoten profiilit koskematta **Ajastus (EXPRESSO-IOS-ASENNUS-AJASTUS, 6.10.2026 23.35):** sama LaunchAgent `StartInterval` 1800 + `RunAtLoad`; ajastettu ajo (= `--agentti` ilman `tilaus`-merkkiä) laskee H:n tiedostosta `asennettu.mobileprovision`: H ≥ 48 → `ajastus.loki` `ok H=`; näyttö lukossa → `lukittu H=` + Macin ilmoitus "avaa Macin näyttö" kun H < 36 (enintään kerran 6 h); iPhone ei tavoitettavissa → `laite poissa H=`; muuten `uusinta H=` ja uusinta kuten `--uusi` (profiilia ei siirretä, jos PP:ssä on jo asennettua uudempi). `--ajastus [H]` ajaa päätöksen heti (H = testitunnit), `testi-lukko` pakottaa lukkotilan, `--check` näyttää H:n. **Mitattu 23.30–23.32:** Macin näyttö lukossa → tavallinen asennus toimii, profiilin uusinta kaatuu (Xcode "No Accounts"; tili on tallessa); tilattu `--uusi` lukittuna → `virhe: Macin näyttö lukossa`, exit 8. Todennettu itse: `ok H=167`, `lukittu H=10`, exit 8, tavallinen asennus exit 0; **todentamatta:** ajastettu uusinta näyttö auki (briefin hyväksyntärivi 4), `laite poissa` -haara ja ilmoitus | ensimmäinen ajastettu uusinta noin 11.10.2026 klo 23.17 jälkeen (H < 48, Mac-näyttö auki): `ssh dev-host 'tail -3 ~/expresso-ios-asennus/ajastus.loki ~/expresso-ios-asennus/asennus.loki'` → `uusinta valmis profiili=<myöhempi kuin 2026-10-13T20:17:22Z>`; aiemmin näytön ollessa auki: `ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --ajastus 10'`; käsin: `--uusi` |
| Täysi pariteetti (taustayhteys, ilmoitukset) | kesken 6.10.2026 (toteutettu ja todennettu simulaattorissa: lomake + lupakysely; laitetodennus puuttuu; todenna viim. 20.10.2026) | todenna iPhonella (ei SEURAAVA, käyttäjä 6.10.2026 ~22.10): release-asennus ennen allekirjoituksen vanhenemista ~12.10.2026 (ssh:lla codesign kaatuu; ks. Agentin oma iPhone-asennus), uutto iPhonen ollessa lukittuna → ilmoitus "Uutto tallennettu", yhteys säilyy taustalla |
| Pysyvä `xcode-select` | avoin; odottaa käyttäjää (kirjattu 6.10.2026; valinnainen, zshrc-kierto riittää) | `sudo xcode-select -s /Applications/Xcode.app` (käyttäjän sudo) |

### Viat — poistettu tai muutettu

| Vika | Tila |
|---|---|
| Luovutin release-asennuksen käyttäjälle 6.10.2026 ~21.58, vaikka remote-skoopissa on 5.10.2026 alkaen toimiva agentin oma asennus (GUI-LaunchAgent `com.example.kauko-uusinta`, xcodebuild + `devicectl device install app`); en tarkistanut muiden skooppien ratkaisuja, ja luovutus-vahdin huomautukseen vastasin perustelemalla luovutuksen enkä etsimällä keinoa (TYOTAVAT 20, V-033). Käyttäjän ajo kaatui "Error running application" -virheeseen, koska iPhone oli lukossa | korjattu 6.10.2026 (EXPRESSO-IOS-ASENNUS-AGENTTI: agentin oma asennus `expresso-asennus.sh`, todennettu 23.11.33) |

### Viat — valmis

| Vika | Tila |
|---|---|
| Luovutin release-asennuksen käyttäjälle 6.10.2026 ~21.58, vaikka remote-skoopissa on 5.10.2026 alkaen toimiva agentin oma asennus (GUI-LaunchAgent `com.example.kauko-uusinta`, xcodebuild + `devicectl device install app`); en tarkistanut muiden skooppien ratkaisuja, ja luovutus-vahdin huomautukseen vastasin perustelemalla luovutuksen enkä etsimällä keinoa (TYOTAVAT 20, V-033). Käyttäjän ajo kaatui "Error running application" -virheeseen, koska iPhone oli lukossa | korjattu 6ac1b09 7.10.2026 (EXPRESSO-IOS-ASENNUS-AGENTTI: agentin oma asennus `expresso-asennus.sh`, todennettu 7.10.2026 09.23) |

## 7.10.2026 — expresso-ios

### (alku) — poistettu tai muutettu

SEURAAVA PAKETTI: EXPRESSO-IOS-PARITEETTI-LAITE — täysi pariteetti iPhonella: agentti asentaa (expresso-asennus.sh), käyttäjä tekee uuton iPhone lukittuna → ilmoitus "Uutto tallennettu", BLE-yhteys säilyy taustalla (console-loki + kuvakaappaus); vaatii käyttäjän läsnäolon — polut: expresso-ios/** — aloitus: /pura expresso-ios

### Avoimet asiat — poistettu tai muutettu

| Asia | Tila | Seuraava askel |
|---|---|---|
| BLE-testi keittimellä | kesken 6.10.2026 (ydinosa läpäisty 21.15 Android-äppi suljettuna, ks. Yhteiskäyttö; V-205 ei enää estä; todenna viim. 20.10.2026) | pariteettiosa (ks. Täysi pariteetti); sen jälkeen kytkimen säilyminen uudelleenkäynnistyksessä ja firmwaren `ble.config(gap_name='EspressoPico')` ehdotus infra expressolle /vika-reitillä |
| Täysi pariteetti (taustayhteys, ilmoitukset) | kesken 6.10.2026 (toteutettu ja todennettu simulaattorissa: lomake + lupakysely; asennus nyt agentin; laitetodennus puuttuu; todenna viim. 20.10.2026) | todenna iPhonella: uutto lukitulla iPhonella → ilmoitus "Uutto tallennettu", yhteys säilyy taustalla; vaatii käyttäjän (uutto) (ei SEURAAVA, käyttäjä 6.10.2026 ~22.10) |
