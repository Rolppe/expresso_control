# EXPRESSO-IOS-ASENNUS-AGENTTI

## Task

Tee Macin GUI-istunnossa (LaunchAgent) ajettava skripti, jolla agentti rakentaa, allekirjoittaa ja asentaa
expresso-ios-äpin iPhoneen yhdellä `ssh dev-host` -komennolla, ja aja sillä yksi oikea asennus.

## Files

- may: `expresso-ios/mac/expresso-asennus.sh`, `expresso-ios/mac/com.example.expresso-asennus.plist` (uudet);
  Macilla `~/expresso-ios-asennus/**` ja `~/Library/LaunchAgents/com.example.expresso-asennus.plist`
- must not: Macin lähdeprojekti P (vain luku), `~/remote-koe-avaus/**`, `com.example.kauko-uusinta`, `remote/**`,
  `Infra/**`, sudo, `xcode-select -s`, simulaattorit, äpin käynnistys iPhonessa, `git commit`
- read: `expresso-ios/paketit/EXPRESSO-IOS-ASENNUS-AGENTTI.spec.md`; `remote/mac/kauko-uusinta.sh`, `remote/mac/com.example.kauko-uusinta.plist` (malli);
  `expresso-ios/REKISTERI.md` rivit 24–39 ja 101

## Do

Vakiot: `P="$HOME/Documents/Koodi/Silvia pico/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI"`,
`T=$HOME/expresso-ios-asennus`, `LAITE=YOUR_DEVICE_UDID`, label `com.example.expresso-asennus`.
Macissa ei ole `timeout`ia (`perl -e "alarm N; exec @ARGV" …`). Yksi ssh-komento enintään 590 s.

1. Kirjoita skripti spec-tiedoston mukaan (neljä tilaa: `--check`, ei argumenttia, `--tila`, `--agentti`).
2. Kirjoita plist: `Label`, `ProgramArguments` [`~/expresso-ios-asennus/expresso-asennus.sh`, `--agentti`],
   `LimitLoadToSessionType` Aqua, `StandardOutPath`/`StandardErrorPath` `$T/agentti.out`; ei `RunAtLoad`, ei `StartInterval`.
3. Asenna Macille: `mkdir -p` T; `scp` skripti → T (`chmod +x`), plist → `~/Library/LaunchAgents/`;
   `ssh dev-host 'launchctl bootstrap gui/501 ~/Library/LaunchAgents/com.example.expresso-asennus.plist'`.
4. Aja `--check`, sitten oikea asennus (ei argumenttia, tarvittaessa `--tila` kunnes valmis).
5. Jos ajo kaatuu, lue `$T/build.log` ja `$T/agentti.out`, korjaa skriptiä tai poissulkulistaa may-listan sisällä
   ja aja uudelleen; enintään 3 asennusajoa.
6. Kopioi lopullinen skripti niin, että repo ja Mac ovat tavu tavulta samat.

## Acceptance

```
ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --check'
ssh dev-host '~/expresso-ios-asennus/expresso-asennus.sh --tila'
test "$(ssh dev-host 'shasum < ~/expresso-ios-asennus/expresso-asennus.sh')" = "$(sha1sum < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)"
ssh dev-host 'grep -q "asennus valmis" ~/expresso-ios-asennus/asennus.loki && test ~/expresso-ios-asennus/projekti/build/ios/iphoneos/Runner.app/Frameworks/App.framework/App -nt "$HOME/Documents/Koodi/Silvia pico/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI/lib/core/standby_timeout.dart"'
```

## Budget

`test "$(wc -l < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)" -le 150`

## Stop

Kysy yksi kysymys ja lopeta, jos: `ssh dev-host` ei vastaa; `launchctl bootstrap` tai `kickstart` ei onnistu ssh:lta;
allekirjoitus kaatuu myös GUI-istunnossa (`errSecInternalComponent`, "No Accounts", provisioning) tai Mac näyttää
ikkunan, joka vaatii käyttäjän napautuksen; asennus kaatuu laitteen tilaan (ei yhteyttä, Locked, ei paritettu);
korjaus vaatisi muutoksen P:hen; kolme asennusajoa on käytetty.

## Report

```text
files changed : <paths>
acceptance    : <last 3 lines, exit code>
budget        : <verdict line>
iterations    : <n>
stopped       : <no | condition>
question      : <none | one question>
```
