# EXPRESSO-IOS-ASENNUS-AJASTUS

## Task

Lisää expresso-ios:n asennusskriptiin ajastettu allekirjoituksen uusinta: LaunchAgent tarkistaa 30 min välein ja
uusii profiilin ja asennuksen itse, kun profiilia on alle 48 h jäljellä.

## Files

- may: `expresso-ios/mac/expresso-asennus.sh`, `expresso-ios/mac/com.example.expresso-asennus.plist`; Macilla
  `~/expresso-ios-asennus/**`, `~/Library/LaunchAgents/com.example.expresso-asennus.plist` ja expresson profiili
  (tunniste päättyy `.io.github.rolppe.silviaPicoUi`) hakemistossa `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`
- must not: Macin lähdeprojekti `~/Documents/**`, `~/remote-koe-avaus/**`, `com.example.kauko-uusinta`, remoten
  profiilit (`com.example.remote*`), `remote/**`, `Infra/**`, sudo, simulaattorit, äpin käynnistys iPhonessa, `git commit`
- read: `expresso-ios/paketit/EXPRESSO-IOS-ASENNUS-AJASTUS.spec.md`, `expresso-ios/mac/expresso-asennus.sh`,
  `remote/mac/kauko-uusinta.sh` (malli)

## Do

`T=$HOME/expresso-ios-asennus`, label `com.example.expresso-asennus`. Mac-komennot `ssh dev-host '…'`; Macissa ei ole
`timeout`ia. Yksi ssh-komento enintään 590 s.

1. Toteuta specin kohdat 1–5 skriptiin; nykyisten tilojen (`--check`, ei argumenttia, `--tila`, `--uusi`) käytös ja
   lokirivit eivät muutu muuten kuin specin mukaan. `bash -n` puhtaaksi.
2. Päivitä plist (specin kohta 6).
3. Kopioi skripti ja plist Macille (tavu tavulta samat kuin repossa) ja lataa agentti uudelleen:
   `launchctl bootout gui/501/com.example.expresso-asennus`, sitten `launchctl bootstrap gui/501 <plist>`.
4. Aja `ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --ajastus'` → odotus `ok H=<yli 100>`, ei uutta
   `aloitus`-riviä `asennus.loki`ssa.
5. Aja kerran `ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --ajastus 10'` → odotus `uusinta H=10` ja
   `uusinta valmis profiili=<myöhempi kuin 2026-10-13T20:17:22Z>`. Enintään 2 tällaista ajoa.
6. Aja lopuksi tavallinen asennus (ei argumenttia) → `asennus valmis`, exit 0.

## Acceptance

```
ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --check'
ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --ajastus && tail -1 ~/expresso-ios-asennus/ajastus.loki | grep -q "ok H=1[0-9][0-9]$"'
ssh dev-host 'launchctl print gui/501/com.example.expresso-asennus | grep -q "run interval = 1800 seconds"'
ssh dev-host 'grep -q "uusinta H=10$" ~/expresso-ios-asennus/ajastus.loki && x=$(security cms -D -i ~/expresso-ios-asennus/asennettu.mobileprovision | plutil -extract ExpirationDate raw -); [[ "$x" > "2026-10-13T20:17:22Z" ]]'
ssh dev-host 'ls ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/00ab71c2-6270-42ef-91a1-b61d2faa8d64.mobileprovision ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/b69b069d-fd30-4204-9d6f-3c924ed1f7c6.mobileprovision'
test "$(ssh dev-host 'shasum < ~/expresso-ios-asennus/expresso-asennus.sh')" = "$(sha1sum < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)"
test "$(ssh dev-host 'shasum < ~/Library/LaunchAgents/com.example.expresso-asennus.plist')" = "$(sha1sum < ~/palvelin/expresso-ios/mac/com.example.expresso-asennus.plist)"
```

## Budget

`test "$(wc -l < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)" -le 190`

## Stop

Kysy yksi kysymys ja lopeta, jos: `ssh dev-host` ei vastaa; `bootout`/`bootstrap`/`kickstart` ei onnistu ssh:lta; käännös
kaatuu allekirjoitukseen tai provisioning-virheeseen (varmista ensin, että profiili palasi paikalleen); asennus
kaatuu laitteen tilaan kolmella yrityksellä; Mac näyttää ikkunan, joka vaatii käyttäjän napautuksen; kaksi
`--ajastus 10` -ajoa on käytetty.

## Report

```text
files changed : <paths>
acceptance    : <last 3 lines, exit code>
budget        : <verdict line>
iterations    : <n>
stopped       : <no | condition>
question      : <none | one question>
```
