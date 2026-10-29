# EXPRESSO-IOS-ASENNUS-AGENTTI — correction 2

Uudelleenasennus ei uusi allekirjoitusprofiilia: neljän ajon jälkeen `embedded.mobileprovision` vanhenee yhä
2026-10-12T17:35:27Z (Xcode käyttää voimassa olevaa profiilia `781e0c2d-0f8b-475d-94d9-3d091ea0f066`, mitattu
6.10.2026 23.15). Käyttäjä 6.10.2026: uusinta lisätään nyt. Spec on päivitetty (`--uusi`-kohta).

## Do

1. Lisää skriptiin tila `--uusi` ja `--agentti`-haaran uusintakäsittely specin `--uusi`-kohdan mukaan. Koske vain
   profiileihin, joiden tunniste päättyy `.io.github.rolppe.silviaPicoUi` — ei remoten (`com.example.remote*`)
   profiileihin. Lisää `--uusi` skriptin käyttöriville.
2. Kopioi skripti Macille (repo ja Mac tavu tavulta samat) ja aja `ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --uusi'`
   kerran (tarvittaessa `--tila` kunnes valmis).
3. Jos käännös kaatuu provisioning-virheeseen, varmista että profiili palasi paikalleen, ja lopeta Stop-kysymykseen
   (älä vaihda käännöskomentoa). Enintään 2 uusinta-ajoa.

## Acceptance

```
ssh dev-host 'tail -1 ~/expresso-ios-asennus/asennus.loki | grep -q "uusinta valmis profiili=" && test ! -e ~/expresso-ios-asennus/uusi'
ssh dev-host 'x=$(security cms -D -i ~/expresso-ios-asennus/projekti/build/ios/iphoneos/Runner.app/embedded.mobileprovision | plutil -extract ExpirationDate raw -); [[ "$x" > "2026-10-12T17:35:27Z" ]]'
ssh dev-host 'ls ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/00ab71c2-6270-42ef-91a1-b61d2faa8d64.mobileprovision ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/b69b069d-fd30-4204-9d6f-3c924ed1f7c6.mobileprovision'
test "$(ssh dev-host 'shasum < ~/expresso-ios-asennus/expresso-asennus.sh')" = "$(sha1sum < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)"
test "$(wc -l < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)" -le 150
```
