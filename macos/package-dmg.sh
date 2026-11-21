#!/bin/sh
set -eu

APP=$1
DMG=$2
WORK=$3
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
VOLUME=ZapretMac
BUILD_VOLUME="ZapretMac-Build-$$"
MOUNT="/Volumes/$BUILD_VOLUME"
DEVICE=

case "$APP:$DMG:$WORK" in
    *.app:*.dmg:*/dmg-work) ;;
    *) echo 'invalid DMG packaging paths'; exit 1 ;;
esac

/bin/rm -rf "$WORK"
/bin/mkdir -p "$WORK/image/.background"
/usr/bin/ditto "$APP" "$WORK/image/ZapretMac.app"
/bin/ln -s /Applications "$WORK/image/Applications"
/bin/cp "$ROOT/macos/Resources/dmg-background.png" "$WORK/image/.background/dmg-background.png"

cleanup() {
    /usr/bin/hdiutil detach "${DEVICE:-$MOUNT}" -quiet >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP

/usr/bin/hdiutil create -quiet -format UDRW -volname "$BUILD_VOLUME" -srcfolder "$WORK/image" "$WORK/ZapretMac-rw.dmg"
/usr/bin/hdiutil attach -quiet -nobrowse -readwrite "$WORK/ZapretMac-rw.dmg"
DEVICE=$(/usr/sbin/diskutil info "$MOUNT" | /usr/bin/awk '/Device Node:/ { print $3; exit }')
[ -n "$DEVICE" ]

/usr/bin/osascript <<EOF
tell application "Finder"
    tell disk "$BUILD_VOLUME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 1000, 700}
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 14
        set background picture of viewOptions to POSIX file "$MOUNT/.background/dmg-background.png"
        set position of item "ZapretMac.app" of container window to {225, 300}
        set position of item "Applications" of container window to {675, 300}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

/usr/sbin/diskutil rename "$MOUNT" "$VOLUME" >/dev/null
/bin/sync
/usr/bin/hdiutil detach "$DEVICE" -quiet
/bin/rm -f "$DMG"
/usr/bin/hdiutil convert -quiet "$WORK/ZapretMac-rw.dmg" -format UDZO -o "$DMG"
/usr/bin/hdiutil verify -quiet "$DMG"
