# EXPRESSO-IOS-ASENNUS-AJASTUS — correction 1

Vastaus Stop-kysymykseen: Apple ID:tä ei kirjata uudelleen. Mitattu 6.10.2026 23.32: Xcoden tili on tallessa
(`defaults read com.apple.dt.Xcode DVTDeveloperAccountManagerAppleIDLists` → 78311409+Rolppe@users.noreply.github.com), mutta Macin näyttö
on lukossa (`CGSSessionScreenIsLocked` true, näyttö sammui 23.21). `--uusi` onnistui 23.17 näytön ollessa auki; lukittuna
tavallinen asennus onnistui 23.30, uusinta kaatui 23.32 ("No Accounts"). Puute oli specissä: lukkotarkistus puuttui
(mallissa se on, `kauko-uusinta.sh` rivit 38–39 ja 52–53). Spec on päivitetty (kohta 7).

## Do

1. Toteuta specin kohta 7 skriptiin (lukkotarkistus, `testi-lukko`, `lukittu H=`, `--uusi` → exit 8, ei ilmoitusta
   testitunneilla). `bash -n` puhtaaksi.
2. Kopioi skripti Macille (tavu tavulta sama kuin repossa). Plist ei muutu. Poista Macilta testiajon 23.32 jättämä
   `~/expresso-ios-asennus/ilmoitus.stamp`.
3. Aja Acceptance-rivit. Älä aja oikeaa uusintaa (`--ajastus 10` ilman `testi-lukko`a tai `--uusi`): näyttö on lukossa.
4. Aja lopuksi tavallinen asennus (ei argumenttia) → `asennus valmis`, exit 0.

## Acceptance

```
ssh dev-host 'echo 1 > ~/expresso-ios-asennus/testi-lukko && ~/expresso-ios-asennus/expresso-asennus.sh --ajastus 10 && tail -1 ~/expresso-ios-asennus/ajastus.loki | grep -q "lukittu H=10$" && test ! -e ~/expresso-ios-asennus/testi-lukko && test ! -e ~/expresso-ios-asennus/ilmoitus.stamp'
ssh dev-host 'echo 1 > ~/expresso-ios-asennus/testi-lukko; ~/expresso-ios-asennus/expresso-asennus.sh --uusi; test $? = 8 && tail -1 ~/expresso-ios-asennus/asennus.loki | grep -q "virhe: Macin näyttö lukossa$"'
ssh dev-host 'ls ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/6912e2b9-5f13-46bf-b781-dfc436c28033.mobileprovision && test -z "$(ls ~/expresso-ios-asennus/vanhat-profiilit/)"'
ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --ajastus && tail -1 ~/expresso-ios-asennus/ajastus.loki | grep -q "ok H=1[0-9][0-9]$"'
ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh && tail -1 ~/expresso-ios-asennus/asennus.loki | grep -q "asennus valmis profiili=2026-10-13T20:17:22Z$"'
test "$(ssh dev-host 'shasum < ~/expresso-ios-asennus/expresso-asennus.sh')" = "$(sha1sum < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)"
test "$(wc -l < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)" -le 190
```
