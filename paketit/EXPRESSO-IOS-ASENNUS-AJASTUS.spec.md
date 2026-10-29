# EXPRESSO-IOS-ASENNUS-AJASTUS — spec

Muutokset tiedostoon `expresso-ios/mac/expresso-asennus.sh` (nykyiset tilat säilyvät) ja plistiin. Malli =
`remote/mac/kauko-uusinta.sh`. Uudet tiedostot T:ssä: `tilaus`, `asennettu.mobileprovision`, `ajastus.loki`,
`testi-tunnit`, `ilmoitus.stamp`. PP = `~/Library/Developer/Xcode/UserData/Provisioning Profiles`.

1. **Tilaus:** ei argumenttia- ja `--uusi`-tila tekevät `touch $T/tilaus` ennen kickstartia. `--agentti` poistaa
   `tilaus`-tiedoston heti lukon jälkeen; jos se oli olemassa, ajo on tilattu ja toimii täsmälleen kuten nyt.
2. **Asennettu profiili:** jokaisen onnistuneen asennuksen jälkeen
   `cp "$APP/embedded.mobileprovision" "$T/asennettu.mobileprovision"` ja `rm -f $T/ilmoitus.stamp`.
3. **Ajastettu ajo** = `--agentti` ilman tilausta. Lukon jälkeen:
   - H = täydet tunnit `asennettu.mobileprovision`in (puuttuessa `$APP/embedded.mobileprovision`in) ExpirationDateen
     (mallin rivit 22–36); jos `$T/testi-tunnit` on, H = sen sisältö ja tiedosto poistetaan.
   - H ≥ 48 → `ajastus.loki`in aikaleimalla `ok H=<H>`; `tila` = `valmis exit=0`; exit 0. Ei riviä `asennus.loki`iin.
   - H < 48 ja laitteen State (`devicectl list devices`) ei ole `connected` eikä `available (paired)` →
     `ajastus.loki`: `laite poissa H=<H>`; ilmoita; `tila` = `valmis exit=0`; exit 0. Profiileihin ei kosketa.
   - muuten `ajastus.loki`: `uusinta H=<H>`, sitten käännös ja asennus kuten tilatussa ajossa. Profiili siirretään
     sivuun (kuten `--uusi`, loppurivi `uusinta valmis profiili=…`) vain, jos PP:ssä ei ole expresson profiilia, jonka
     ExpirationDate on myöhempi kuin `asennettu.mobileprovision`in; jos sellainen on (aiempi uusinta jäi asentamatta),
     käännä ja asenna siirtämättä (loppurivi `asennus valmis profiili=…`). Virheessä (exit 1, 2, 7): ilmoita.
   - **ilmoita** (mallin rivit 68–74): vain kun H < 36, enintään kerran 6 h (`ilmoitus.stamp`):
     `display notification "eXpresso vanhenee <pp.kk. hh.mm> — Mac hereille, iPhone samaan verkkoon" with title "eXpresso"`.
4. **`--ajastus [H]`** (ssh-istunto): jos H on annettu, kirjoita se `testi-tunnit`iin; poista `tila`; kickstart ilman
   tilausta; odota kuten `--tila`; tulosta `ajastus.loki`n viimeinen rivi ja sitten `--tila`n tulosteet; exit kuten `--tila`.
5. **`--check`:** preflight-rivin loppuun ` H=<H>` (asennetun profiilin tunnit, ei testi-tunteja).
6. **plist:** lisää `StartInterval` 1800 ja `RunAtLoad` true.
7. **Näytön lukko (correction-1):** `LUKITTU` kuten mallin rivit 38–39; jos `$T/testi-lukko` on, `LUKITTU` = sen sisältö
   (0/1) ja tiedosto poistetaan. Profiilin uusinta vaatii avatun näytön (lukittuna Xcode: "No Accounts"); allekirjoitus
   olemassa olevalla profiililla toimii lukittunakin.
   - Ajastettu ajo, H < 48 ja lukittu → `ajastus.loki`: `lukittu H=<H>`; ilmoita tekstillä
     `eXpresso vanhenee <pp.kk. hh.mm> — avaa Macin näyttö`; `tila` = `valmis exit=0`; exit 0; profiileihin ei kosketa.
     Tarkistus tehdään ennen laitetarkistusta.
   - Tilattu `--uusi` ja lukittu → `asennus.loki`: `aloitus`, `virhe: Macin näyttö lukossa`; `tila` = `valmis exit=8`;
     exit 8; profiileihin ei kosketa, ei käännöstä.
   - Testitunneilla (`testi-tunnit`) ajettu ajo ei näytä ilmoitusta eikä kirjoita leimaa.
