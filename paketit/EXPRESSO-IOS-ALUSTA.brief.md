# EXPRESSO-IOS-ALUSTA — iOS-alusta espressokeittimen Flutter-sovellukseen, simulaattorikäännös vihreäksi

Skooppi `expresso-ios` (rekisteri `expresso-ios/REKISTERI.md`, Tarkoitus ja raja). Työ tehdään Macilla
`ssh dev-host` -yhteydellä palvelimelta. Jokainen Mac-komento alkaa näin (polussa välilyönti):

    ssh dev-host 'export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/opt/homebrew/bin:$PATH; P="$HOME/src/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI"; cd "$P" && …'

Ei sudoa (`xcode-select` osoittaa CommandLineToolsiin; `DEVELOPER_DIR` ohittaa sen). Aikaraja jokaiseen
komentoon (`timeout` tai Bash-työkalun timeout), ei putkea paluukoodia vaativiin komentoihin.

Lue ensin: `pubspec.yaml`, `lib/features/ble/ble_repository.dart:134-200` (iOS-haara käyttää
`Permission.bluetooth`), `lib/features/usb/pico_usb_channel.dart:40-60`, `.metadata`.

## Tee

1. **Varmuuskopio:** `rsync -a --exclude build --exclude build.bak-20260917 --exclude .dart_tool ./
   ~/expresso-ios-varmuus/20261005/` ja tiivisteet `find android lib pubspec.yaml pubspec.lock -type f | sort |
   xargs shasum > ~/expresso-ios-varmuus/ennen.sha` (paluukoodi näkyviin).
2. **CocoaPods:** `brew install cocoapods` (ei sudoa), sitten `pod --version`.
3. **iOS-alusta:** `flutter create --platforms=ios --org io.github.rolppe .` — lisää vain `ios/`-hakemiston
   (iOS-bundle `io.github.rolppe.silviaPicoUi`; `com.example` ei kelpaa ilmaiseen Apple ID -allekirjoitukseen).
   Androidin applicationId pysyy `com.example.silvia_pico_ui`. Jos komento loisi tai muuttaisi tiedostoja
   `android/`- tai `lib/`-hakemistossa, palauta ne varmuuskopiosta.
4. **Info.plist** (`ios/Runner/Info.plist`): `NSBluetoothAlwaysUsageDescription` = "Yhteys espressokeittimeen
   (EspressoPico) Bluetoothilla." ja `CFBundleDisplayName` = "eXpresso". Käytä `/usr/libexec/PlistBuddy`ia.
5. **Podfile** (`ios/Podfile`, synty ensimmäisessä `pod install`/`flutter build ios` -ajossa): `platform :ios,
   '13.0'`; `post_install`-lohkoon permission_handlerin makrot `GCC_PREPROCESSOR_DEFINITIONS`:
   `PERMISSION_BLUETOOTH=1`, muut 0:t jätetään oletukseksi.
6. **Käännös:** `flutter pub get` ja `timeout 1500 flutter build ios --simulator --debug`. Jos Dart-käännös kaatuu
   iOS:llä, korjaa vain `Platform.isAndroid`/`isIOS`-vartiolla `lib/`-tiedostoon; kirjaa jokainen muutos.
7. **Savutesti simulaattorissa:** `xcrun simctl boot "iPhone 17"` (tai `xcrun simctl list devices available`
   ensimmäinen iPhone), `xcrun simctl install booted build/ios/iphonesimulator/Runner.app`,
   `xcrun simctl launch booted io.github.rolppe.silviaPicoUi`, 20 s, sitten `xcrun simctl spawn booted
   launchctl list | grep -i silvia` (prosessi elossa), `xcrun simctl io booted screenshot
   ~/expresso-ios-varmuus/sim.png`, `xcrun simctl shutdown booted`. Simulaattorissa ei ole Bluetoothia:
   "ei laitetta" on odotettu, kaatuminen ei.
8. **Android ennallaan:** `shasum -c ~/expresso-ios-varmuus/ennen.sha` — android/ ja pubspec.* täsmäävät;
   lib/-erot vain kohdan 6 kirjatut.

## Hyväksyntä (pääistunto ajaa itse)

```
ssh dev-host 'P="$HOME/src/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI"; /usr/libexec/PlistBuddy -c "Print :NSBluetoothAlwaysUsageDescription" "$P/ios/Runner/Info.plist" && grep -q PERMISSION_BLUETOOTH=1 "$P/ios/Podfile" && test -d "$P/build/ios/iphonesimulator/Runner.app" && grep -q silviaPicoUi "$P/ios/Runner.xcodeproj/project.pbxproj"'
```

## Älä

- Älä aja sudoa, `xcode-select -s`:ää, `xcodebuild -license`:ä tai Android-käännöstä.
- Älä muuta `android/`-, `macos/`- tai `pubspec.yaml`-sisältöä, firmwarea (`pico/`) tai BLE-protokollaa.
- Älä allekirjoita, älä asenna fyysiseen laitteeseen, älä kirjaudu Apple ID:llä.
- Älä poista `build/`- tai `build.bak-*`-hakemistoja. Älä committaa palvelimen repoon.

## Stop

Kysy yksi kysymys ja lopeta, jos: `brew install cocoapods` vaatii salasanan tai sudon; `flutter create` muuttaisi
`android/`-tiedostoja eikä palautus onnistu; tai Dart-korjaus vaatisi muutoksen jaettuun logiikkaan ilman
Platform-vartiota.

## Raportoi (enintään 25 riviä)

Komennot paluukoodeineen (1–8); uudet ja muutetut tiedostot; pod- ja Flutter-versiot; simulaattorin malli ja iOS;
savutestin tulos (prosessi elossa, kuvakaappauksen polku); lib/-muutokset riveineen; avoimet riskit
oikealle iPhonelle (allekirjoitus, BLE-lupa, taustatila).
