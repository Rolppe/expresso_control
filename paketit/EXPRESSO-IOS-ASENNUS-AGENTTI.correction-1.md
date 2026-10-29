# EXPRESSO-IOS-ASENNUS-AGENTTI — correction 1

Suunnittelijan hyväksyntäajo 6.10.2026 23.07.26–23.07.51: `build ok 7 s`, sitten `virhe: install`
(`build.log`: CoreDeviceError 3002, kAMDRemoteConnectError 0xE8000112). Sama asennus onnistui 43 s myöhemmin
(23.08.34 "App installed", iPhone lukossa) → virhe oli hetkellinen, ja skriptistä puuttuu uusintayritys. Puute oli
specissä; spec on päivitetty (`--agentti`-kohta).

## Do

1. `--agentti`: yritä `devicectl device install app` enintään 3 kertaa, 15 s tauko yritysten välissä. Epäonnistunut
   yritys kirjaa `$T/asennus.loki`iin `install yritys <n> epäonnistui`; kolmannen jälkeen `virhe: install`, exit 2
   kuten ennen.
2. Testikytkin: jos `$T/testi-virhe` on olemassa, poista se ja käsittele ensimmäinen yritys epäonnistuneena
   kutsumatta devicectl:ia.
3. Kopioi skripti Macille niin, että repo ja Mac ovat tavu tavulta samat. Muuta ei muuteta (may-lista ennallaan).

## Acceptance

```
ssh dev-host 'touch ~/expresso-ios-asennus/testi-virhe && ~/expresso-ios-asennus/expresso-asennus.sh'
ssh dev-host 'tail -3 ~/expresso-ios-asennus/asennus.loki | grep -q "install yritys 1 epäonnistui" && tail -1 ~/expresso-ios-asennus/asennus.loki | grep -q "asennus valmis" && test ! -e ~/expresso-ios-asennus/testi-virhe'
test "$(ssh dev-host 'shasum < ~/expresso-ios-asennus/expresso-asennus.sh')" = "$(sha1sum < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)"
test "$(wc -l < ~/palvelin/expresso-ios/mac/expresso-asennus.sh)" -le 150
```
