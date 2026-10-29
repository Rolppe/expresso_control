# EXPRESSO-IOS-ASENNUS-AGENTTI — spec: expresso-asennus.sh

Vakiot (P, T, LAITE, label) briefin Do-osan alusta. Bash, `set -u`,
`PATH=$HOME/expresso-ios-shim:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin`,
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, `LANG=en_US.UTF-8`. Neljä tilaa:

- `--check`: yksi rivi `preflight: xcode=<on|ei> flutter=<on|ei> lahde=<on|ei> agentti=<on|ei> laite=<tila|ei>`;
  exit 0 vain kun neljä ensimmäistä ovat `on` (lahde = `$P/pubspec.yaml` luettavissa, agentti =
  `launchctl print gui/501/<label>` onnistuu, laite = `devicectl list devices` -rivin State).
- ei argumenttia (ssh-istunto): `rsync -a --delete "$P/" "$T/projekti/"` ilman `build`, `build.bak-*`,
  `.dart_tool`, `.idea`, `.flutter-plugins-dependencies*`, `android`, `macos`, `ios/Pods`, `ios/.symlinks`,
  `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`; poista `$T/tila`;
  `launchctl kickstart gui/501/<label>`; jatka kuten `--tila`.
- `--tila`: odota enintään 540 s, että `$T/tila` alkaa `valmis`; tulosta viimeisen ajon `$T/asennus.loki`-rivit;
  exit = tilan `exit=<n>`; yhä kesken → `kesken`, exit 4; tilaa ei ole → exit 5.
- `--agentti` (LaunchAgent, GUI-istunto): mkdir-lukko `$T/lukko` kuten mallissa; `$T/tila` = `kaynnissa`;
  `cd "$T/projekti" && flutter build ios --release` → `$T/build.log`;
  `xcrun devicectl device install app --device $LAITE build/ios/iphoneos/Runner.app` → samaan lokiin;
  asennusta yritetään enintään 3 kertaa 15 s välein (correction-1: kAMDRemoteConnectError oli hetkellinen),
  epäonnistunut yritys → `install yritys <n> epäonnistui`; tiedosto `$T/testi-virhe` = ensimmäinen yritys
  epäonnistuu kutsumatta devicectl:ia, ja tiedosto poistetaan;
  `$T/asennus.loki`iin aikaleimalla `aloitus`, `build ok <s> s`, ja joko `virhe: build`, `virhe: install` tai
  `asennus valmis profiili=<ExpirationDate>` (`embedded.mobileprovision`, kuten mallissa); lopuksi
  `$T/tila` = `valmis exit=<n>`.

- `--uusi` (ssh-istunto, correction-2): `touch $T/uusi`, sitten kuten ei argumenttia. `--agentti`: jos `$T/uusi` on,
  poista se, lue vanha ExpirationDate ja siirrä ennen käännöstä hakemistosta
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` hakemistoon `$T/vanhat-profiilit/` (tyhjennetään ensin)
  ne profiilit, joiden `Entitlements.application-identifier` päättyy `.io.github.rolppe.silviaPicoUi` (malli:
  `kauko-uusinta.sh` rivit 83–101); käännösvirhe → profiilit takaisin (`mv -n`); asennuksen jälkeen uuden
  `embedded.mobileprovision`in ExpirationDate pitää olla vanhaa myöhempi, muuten `virhe: profiili ei uusiutunut`,
  exit 7; onnistuessa loppurivi on `uusinta valmis profiili=<uusi>` (ei `asennus valmis`).

Peili siksi, että ssh-istunto lukee `~/Documents`in mutta LaunchAgent ei välttämättä (TCC; suunnittelijan oletus,
ei mitattu), ja sen xattrit kaatavat CodeSignin (REKISTERI.md:33); peilissä `build/` on oikea hakemisto.
