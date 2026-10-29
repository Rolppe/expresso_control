#!/bin/bash
# expresso-ios: rakenna, allekirjoita ja asenna iPhoneen (build GUI-istunnon LaunchAgentissa).
# Käyttö: expresso-asennus.sh [--check | --tila | --uusi | --ajastus [H] | --agentti]   (ei argumenttia = peilaa, käynnistä agentti, odota)
set -u
export PATH=${MAC_PROJ:-$HOME/Projects}/expresso/expresso-ios-shim:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export LANG=en_US.UTF-8
P="$HOME/src/eXpresso_Grok/legacy/latest/silvia_pico_flutter_UI"
T=${MAC_PROJ:-$HOME/Projects}/expresso/expresso-ios-asennus
LAITE=YOUR_DEVICE_UDID
LABEL=com.example.expresso-asennus
APP=$T/projekti/build/ios/iphoneos/Runner.app
LOKI=$T/asennus.loki
TILA="${1:-}"
mkdir -p "$T"
loki() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOKI"; }
aloki() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$T/ajastus.loki"; }
profexp() { security cms -D -i "$1" 2>/dev/null | plutil -extract ExpirationDate raw - 2>/dev/null; }
omapro() { security cms -D -i "$1" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null \
  | grep -q '\.io\.github\.rolppe\.silviaPicoUi$'; }
laitetila() { xcrun devicectl list devices 2>/dev/null | grep "$LAITE" | sed "s/.*$LAITE (UDID) *//; s/  .*//"; }
# Asennetun profiilin jäljellä olevat tunnit (H) ja vanhenemisaika epochina (VANH)
PROF=$T/asennettu.mobileprovision; [ -f "$PROF" ] || PROF=$APP/embedded.mobileprovision
NYT=$(date +%s); VANH=""; E=$(profexp "$PROF")
[ -n "$E" ] && VANH=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$E" +%s 2>/dev/null)
if [ -n "$VANH" ]; then H=$(( (VANH - NYT) / 3600 )); else H=0; VANH=$NYT; fi
TESTI=0
ilmoita() {
  [ "$H" -lt 36 ] && [ "$TESTI" = 0 ] || return 0
  [ -f "$T/ilmoitus.stamp" ] && [ -n "$(find "$T/ilmoitus.stamp" -mmin -360 2>/dev/null)" ] && return 0
  osascript -e "display notification \"eXpresso vanhenee $(date -r "$VANH" '+%d.%m. %H.%M') — ${1:-Mac hereille, iPhone samaan verkkoon}\" with title \"eXpresso\"" >/dev/null 2>&1
  touch "$T/ilmoitus.stamp"
}

if [ "$TILA" = "--check" ]; then
  XC=ei; [ -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ] && XC=on
  FL=ei; command -v flutter >/dev/null 2>&1 && FL=on
  LA=ei; [ -r "$P/pubspec.yaml" ] && LA=on
  AG=ei; launchctl print "gui/501/$LABEL" >/dev/null 2>&1 && AG=on
  LT=ei
  RIVI=$(xcrun devicectl list devices 2>/dev/null | grep "$LAITE")
  [ -n "$RIVI" ] && LT=$(echo "$RIVI" | sed "s/.*$LAITE (UDID) *//; s/  .*//")
  echo "preflight: xcode=$XC flutter=$FL lahde=$LA agentti=$AG laite=$LT H=$H"
  [ "$XC" = on ] && [ "$FL" = on ] && [ "$LA" = on ] && [ "$AG" = on ]
  exit $?
fi

if [ "$TILA" = "--agentti" ]; then
  LUKKO=$T/lukko
  [ -d "$LUKKO" ] && [ -n "$(find "$LUKKO" -maxdepth 0 -mmin +120 2>/dev/null)" ] && rmdir "$LUKKO"
  mkdir "$LUKKO" 2>/dev/null || { loki "ohitus: lukko varattu"; exit 0; }
  trap 'rmdir "$LUKKO" 2>/dev/null' EXIT
  LUKITTU=0
  ioreg -n Root -d1 -a 2>/dev/null | grep -A1 CGSSessionScreenIsLocked | grep -q '<true/>' && LUKITTU=1
  [ -f "$T/testi-lukko" ] && { LUKITTU=$(cat "$T/testi-lukko"); rm -f "$T/testi-lukko"; }
  TILATTU=0; [ -e "$T/tilaus" ] && { rm -f "$T/tilaus"; TILATTU=1; }
  vi() { [ "$TILATTU" = 0 ] && ilmoita; return 0; }
  if [ "$TILATTU" = 0 ]; then
    [ -f "$T/testi-tunnit" ] && { TESTI=1; H=$(cat "$T/testi-tunnit"); rm -f "$T/testi-tunnit"; }
    if [ "$H" -ge 48 ]; then
      aloki "ok H=$H"; echo "valmis exit=0" > "$T/tila"; exit 0
    fi
    if [ "$LUKITTU" = 1 ]; then
      ilmoita "avaa Macin näyttö"; aloki "lukittu H=$H"; echo "valmis exit=0" > "$T/tila"; exit 0
    fi
    LT=$(laitetila)
    if [ "$LT" != connected ] && [ "$LT" != "available (paired)" ]; then
      ilmoita; aloki "laite poissa H=$H"; echo "valmis exit=0" > "$T/tila"; exit 0
    fi
    aloki "uusinta H=$H"
  fi
  echo kaynnissa > "$T/tila"
  loki aloitus
  if [ "$TILATTU" = 1 ] && [ "$LUKITTU" = 1 ] && [ -e "$T/uusi" ]; then
    rm -f "$T/uusi"; loki "virhe: Macin näyttö lukossa"; echo "valmis exit=8" > "$T/tila"; exit 8
  fi
  A=$(date +%s)
  PP="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"; SIVU=$T/vanhat-profiilit
  UUSINTA=0; VANHA=""; SIIRRA=0
  if [ -e "$T/uusi" ]; then
    rm -f "$T/uusi"; SIIRRA=1
    VANHA=$(profexp "$APP/embedded.mobileprovision")
  elif [ "$TILATTU" = 0 ]; then
    # Aiempi uusinta jäi asentamatta, jos PP:ssä on asennettua uudempi expresson profiili: ei siirretä sivuun
    VANHA=$(profexp "$PROF"); SIIRRA=1
    for p in "$PP"/*.mobileprovision; do
      omapro "$p" && E=$(profexp "$p") && [[ "$E" > "$VANHA" ]] && SIIRRA=0
    done
  fi
  if [ "$SIIRRA" = 1 ]; then
    UUSINTA=1
    rm -rf "$SIVU"; mkdir -p "$SIVU"
    for p in "$PP"/*.mobileprovision; do omapro "$p" && mv "$p" "$SIVU/"; done
  fi
  if ! (cd "$T/projekti" && flutter build ios --release > "$T/build.log" 2>&1); then
    [ "$UUSINTA" = 1 ] && mv -n "$SIVU"/*.mobileprovision "$PP"/ 2>/dev/null
    vi; loki "virhe: build"; echo "valmis exit=1" > "$T/tila"; exit 1
  fi
  loki "build ok $(( $(date +%s) - A )) s"
  OK=0
  for n in 1 2 3; do
    if [ "$n" = 1 ] && [ -e "$T/testi-virhe" ]; then
      rm -f "$T/testi-virhe"
    elif xcrun devicectl device install app --device "$LAITE" "$APP" >> "$T/build.log" 2>&1; then
      OK=1; break
    fi
    loki "install yritys $n epäonnistui"
    [ "$n" -lt 3 ] && sleep 15
  done
  if [ "$OK" != 1 ]; then
    vi; loki "virhe: install"; echo "valmis exit=2" > "$T/tila"; exit 2
  fi
  cp "$APP/embedded.mobileprovision" "$T/asennettu.mobileprovision"; rm -f "$T/ilmoitus.stamp"
  EXP=$(profexp "$APP/embedded.mobileprovision")
  if [ "$UUSINTA" = 1 ]; then
    if [ -z "$EXP" ] || [ -z "$VANHA" ] || ! [[ "$EXP" > "$VANHA" ]]; then
      vi; loki "virhe: profiili ei uusiutunut ($EXP)"; echo "valmis exit=7" > "$T/tila"; exit 7
    fi
    loki "uusinta valmis profiili=$EXP"
  else
    loki "asennus valmis profiili=$EXP"
  fi
  echo "valmis exit=0" > "$T/tila"
  exit 0
fi

if [ "$TILA" = "--ajastus" ]; then
  [ -n "${2:-}" ] && echo "$2" > "$T/testi-tunnit"
  rm -f "$T/tila"
  launchctl kickstart "gui/501/$LABEL" || { echo "virhe: kickstart"; exit 3; }
elif [ "$TILA" != "--tila" ]; then
  [ "$TILA" = "--uusi" ] && touch "$T/uusi"
  touch "$T/tilaus"
  mkdir -p "$T/projekti"
  rsync -a --delete \
    --exclude=/build --exclude='/build.bak-*' --exclude=/.dart_tool --exclude=/.idea \
    --exclude='/.flutter-plugins-dependencies*' --exclude=/android --exclude=/macos \
    --exclude=/ios/Pods --exclude=/ios/.symlinks \
    --exclude=/ios/Flutter/Generated.xcconfig --exclude=/ios/Flutter/flutter_export_environment.sh \
    "$P/" "$T/projekti/" || { echo "virhe: rsync"; exit 3; }
  rm -f "$T/tila"
  launchctl kickstart "gui/501/$LABEL" || { echo "virhe: kickstart"; exit 3; }
fi

# --tila: odota enintään 540 s
i=0
while [ $i -lt 180 ]; do
  [ -f "$T/tila" ] && grep -q '^valmis' "$T/tila" && break
  [ -f "$T/tila" ] || [ "${1:-}" != "--tila" ] || { echo "ei tilaa"; exit 5; }
  sleep 3; i=$((i + 1))
done
if [ -f "$T/tila" ] && grep -q '^valmis' "$T/tila"; then
  [ "$TILA" = "--ajastus" ] && tail -1 "$T/ajastus.loki"
  awk '/ aloitus$/ {b=""} {b = b $0 "\n"} END {printf "%s", b}' "$LOKI" 2>/dev/null
  exit "$(sed 's/.*exit=//' "$T/tila")"
fi
echo kesken
exit 4
