# EXPRESSO-IOS-NAYTTO — asetus "Pidä näyttö päällä" Flutter-äppiin (wakelock_plus)

Skooppi `expresso-ios` (rekisteri `expresso-ios/REKISTERI.md`). Käyttäjä 5.10.2026: "Äppiin pitää saada optio
että se pitää näytön aktiivisena". Työ Macilla `ssh dev-host` -yhteydellä. Jokainen Mac-komento alkaa näin:

    ssh dev-host 'export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=$HOME/expresso-ios-shim:/opt/homebrew/bin:$PATH; P="$HOME/src/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI"; cd "$P" && …'

Macissa ei ole `timeout`-komentoa: käytä `perl -e "alarm N; exec @ARGV" …` tai Bash-työkalun timeoutia.
Ei putkea paluukoodia vaativiin komentoihin. `lib/` on yhteinen Android-äpin (skooppi `infra expresso`) kanssa:
asetus tulee molempiin, se on tarkoitus.

Lue ensin: `pubspec.yaml`; asetusnäkymä ja asetusten tallennus (`grep -rln -i -E "settings|asetu|SharedPreferences" lib`);
`lib/main.dart`.

## Tee

1. **Varmuuskopio:** `mkdir -p ~/expresso-ios-varmuus/20261005-naytto && cp -p pubspec.yaml pubspec.lock
   ~/expresso-ios-varmuus/20261005-naytto/` ja jokainen muokattava `lib/`-tiedosto samaan ennen muokkausta.
2. **Riippuvuus:** `flutter pub add wakelock_plus`, sitten `flutter pub get` (paluukoodi näkyviin).
3. **Asetus:** lisää olemassa olevaan asetusmalliin ja -tallennukseen kenttä `keepScreenOn` (bool, oletus `false`,
   säilyy uudelleenkäynnistyksen yli samalla mekanismilla kuin muut asetukset).
   **Päätös 6.10.2026 (käyttäjä, Stop-kysymys):** äpissä ei ollut asetustallennusta → lisää `shared_preferences`
   (`flutter pub add shared_preferences` vaiheessa 2) ja uusi Riverpod-provider, joka lataa arvon käynnistyksessä.
4. **Käyttöliittymä:** asetusnäkymään `SwitchListTile`, otsikko "Pidä näyttö päällä", alateksti
   "Näyttö ei sammu, kun äppi on auki". Noudata näkymän nykyistä tyyliä ja lokalisointitapaa.
5. **Toiminta:** `WakelockPlus.enable()` / `disable()` aina kun arvo muuttuu, ja tallennettu arvo sovelletaan
   äpin käynnistyessä (asetusten latauksen jälkeen). Virhe kirjataan, ei kaada äppiä.
6. **Tarkistus:** `flutter analyze lib` — ei uusia virheitä tai varoituksia muutetuissa tiedostoissa (vertaa
   ennen/jälkeen-lukua, kirjaa molemmat).
7. **Käännökset:** `flutter build ios --simulator --debug` ja `flutter build ios --release --no-codesign`
   (kumpikin enintään 1500 s). Allekirjoitus jää käyttäjän `flutter run --release` -ajoon.
8. **Savutesti:** `xcrun simctl boot "iPhone 17"`, `install booted build/ios/iphonesimulator/Runner.app`,
   `launch booted io.github.rolppe.silviaPicoUi`, 15 s, kuvakaappaus `~/expresso-ios-varmuus/naytto-sim.png`,
   `xcrun simctl shutdown booted`. Prosessin pitää olla elossa.

## Hyväksyntä (pääistunto ajaa itse)

```
ssh dev-host 'P="$HOME/src/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI"; grep -q "^  wakelock_plus:" "$P/pubspec.yaml" && grep -rq "WakelockPlus.enable" "$P/lib" && grep -rq "Pidä näyttö päällä" "$P/lib" && test "$P/build/ios/iphonesimulator/Runner.app" -nt "$P/pubspec.yaml" && test "$P/build/ios/iphoneos/Runner.app" -nt "$P/pubspec.yaml"'
```

## Älä

- Älä muuta BLE-protokollaa, `ble_repository.dart`:ia, firmwarea, `android/`-hakemistoa tai muita asetuksia.
- Älä aja sudoa, `xcode-select -s`:ää tai Android-käännöstä. Älä allekirjoita äläkä asenna iPhoneen.
- Älä poista `build/`-symlinkkejä (`build/ios` → `~/expresso-ios-build`). Älä committaa palvelimen repoon.

## Stop

Kysy yksi kysymys ja lopeta, jos: asetuksille ei löydy pysyvää tallennusta (ei SharedPreferences tms.);
`wakelock_plus` ei asennu Flutter 3.41.6:een; tai käännös kaatuu muuhun kuin tämän muutoksen virheeseen.

## Raportoi (enintään 20 riviä)

Komennot paluukoodeineen (1–8); muutetut tiedostot ja rivimäärät; wakelock_plus-versio; analyze ennen/jälkeen;
asetuksen tallennusmekanismi; savutestin tulos ja kuvakaappauksen polku.
