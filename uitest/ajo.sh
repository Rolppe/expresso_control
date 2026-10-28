#!/bin/bash
# Macilla: bash $MAC_PROJ/expresso/expresso-ohjain/ajo.sh [build] [askeleet/<nimi>.txt]
# Askeleet /tmp/expresso-ohjain/askeleet.txt; annettu askeltiedosto kopioidaan sen tilalle.
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH=/opt/homebrew/bin:$PATH
UDID=F47C2720-C9C5-48E7-B776-F597F234A110
cd "$(dirname "$0")"
mkdir -p /tmp/expresso-ohjain
BUILD=
for a in "$@"; do
  case "$a" in
    build) BUILD=1 ;;
    *) cp "$a" /tmp/expresso-ohjain/askeleet.txt ;;
  esac
done
if [ -n "$BUILD" ] || [ ! -d dd ]; then
  xcodegen generate -q
  xcodebuild build-for-testing -project ExpressoOhjain.xcodeproj -scheme OhjainHost \
    -destination "id=$UDID" -derivedDataPath dd -quiet
fi
xcodebuild test-without-building -project ExpressoOhjain.xcodeproj -scheme OhjainHost \
  -destination "id=$UDID" -derivedDataPath dd -only-testing:OhjainUITests/Ohjain/testAskeleet > /tmp/expresso-ohjain/ajo.log 2>&1 && rc=0 || rc=$?
grep -E "OHJAIN:|error:|ei löydy|TEST (SUCCEEDED|FAILED)" /tmp/expresso-ohjain/ajo.log || true
echo "AJO: exit $rc (koko loki /tmp/expresso-ohjain/ajo.log)"
exit $rc
