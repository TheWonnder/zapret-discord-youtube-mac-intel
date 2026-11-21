#!/bin/sh
set -eu

SOURCE=$1
DATA_ROOT=$2
TARGET_APP=$3
USER_UID=$4
USER_GID=$5
BASE='/Library/Application Support/ZapretMac'
TARGET_PAYLOAD="$TARGET_APP/Contents/Resources/Payload"
UPSTREAM='https://github.com/Flowseal/zapret-discord-youtube/archive/refs/heads/main.tar.gz'
IPSET_URL='https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/.service/ipset-service.txt'

case "$DATA_ROOT" in
    /Users/*/'Library/Application Support/ZapretMac') ;;
    *) echo 'invalid user data path'; exit 1 ;;
esac
case "$TARGET_APP" in
    *.app) ;;
    *) echo 'invalid application path'; exit 1 ;;
esac
case "$USER_UID:$USER_GID" in
    *[!0-9:]*|:|*:|:*) echo 'invalid user id'; exit 1 ;;
esac
[ -d "$SOURCE" ]
[ -x "$SOURCE/bin/utunws" ]
[ -f "$SOURCE/strategies.tsv" ]
[ -d "$TARGET_PAYLOAD" ]
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET_APP/Contents/Info.plist")" = 'io.github.flowseal.zapretmac.app' ]
[ ! -L "$DATA_ROOT" ]
[ ! -L "$DATA_ROOT/lists" ]

TMP=$(/usr/bin/mktemp -d /tmp/zapret-config-update.XXXXXX)
/bin/chmod 755 "$TMP"
trap '/bin/rm -rf "$TMP"' EXIT INT TERM HUP

/usr/bin/curl -fL --retry 2 --connect-timeout 10 --max-time 120 -o "$TMP/upstream.tar.gz" "$UPSTREAM"
/bin/mkdir -p "$TMP/upstream"
/usr/bin/tar -xzf "$TMP/upstream.tar.gz" -C "$TMP/upstream"
WINDOWS=
for DIR in "$TMP/upstream"/*; do
    if [ -f "$DIR/general.bat" ]; then
        WINDOWS=$DIR
        break
    fi
done
[ -n "$WINDOWS" ]

/usr/bin/ditto "$SOURCE" "$TMP/Payload"
/bin/mkdir -p "$TMP/Payload/strategies" "$TMP/Payload/bin" "$TMP/Payload/default-lists"

convert_strategy() {
    /usr/bin/awk '
        function flush_profile(    i, arg, skip) {
            if (count == 0) return
            skip = 0
            for (i = 1; i <= count; i++) {
                if (profile[i] ~ /^--filter-(tcp|udp)=%GameFilter/) skip = 1
            }
            if (!skip) {
                if (written++) print "--new"
                for (i = 1; i <= count; i++) {
                    arg = profile[i]
                    if (arg ~ /^--wf-/) continue
                    gsub(/%BIN%/, "@BASE@/bin/", arg)
                    gsub(/%LISTS%/, "@LISTS@/", arg)
                    if (arg == "--ipset=@LISTS@/ipset-all.txt") arg = "--ipset=@IPSET@"
                    gsub(/\^!/, "!", arg)
                    if (arg ~ /@/) printf "\"%s\"\n", arg
                    else print arg
                }
            }
            delete profile
            count = 0
        }
        function process_line(line,    position, args, total, i) {
            sub(/\r$/, "", line)
            if (continuation != "") {
                line = continuation line
                continuation = ""
            }
            if (line ~ /[[:space:]]\^$/) {
                sub(/[[:space:]]\^$/, "", line)
                continuation = line " "
                return
            }
            position = index(line, "--wf-tcp=")
            if (position > 0) {
                line = substr(line, position)
                active = 1
            }
            if (!active) return
            gsub(/\"/, "", line)
            total = split(line, args, /[[:space:]]+/)
            for (i = 1; i <= total; i++) {
                if (args[i] == "") continue
                if (args[i] == "--new") flush_profile()
                else profile[++count] = args[i]
            }
        }
        { process_line($0) }
        END {
            if (continuation != "") process_line("")
            flush_profile()
        }
    ' "$1" > "$2"
    /usr/bin/grep -q '^--filter-' "$2"
}

: > "$TMP/Payload/strategies.tsv"
while IFS="$(printf '\t')" read -r ID NAME; do
    [ -n "$ID" ] || continue
    if [ -f "$WINDOWS/$NAME.bat" ]; then
        convert_strategy "$WINDOWS/$NAME.bat" "$TMP/Payload/strategies/$ID.conf.in"
        printf '%s\t%s\n' "$ID" "$NAME" >> "$TMP/Payload/strategies.tsv"
    fi
done < "$SOURCE/strategies.tsv"

for BAT in "$WINDOWS"/general*.bat; do
    NAME=$(/usr/bin/basename "$BAT" .bat)
    if /usr/bin/awk -F '\t' -v name="$NAME" '$2 == name { found = 1 } END { exit !found }' "$TMP/Payload/strategies.tsv"; then
        continue
    fi
    if [ "$NAME" = general ]; then
        ID=general
    else
        ID=$(printf '%s\n' "$NAME" | /usr/bin/tr 'A-Z' 'a-z' | /usr/bin/sed -e 's/^general (/general-/' -e 's/)$//' -e 's/ /-/g')
    fi
    if ! printf '%s\n' "$ID" | /usr/bin/grep -Eq '^general(-[a-z0-9]+)*$'; then
        echo "unsupported strategy name: $NAME"; exit 1
    fi
    convert_strategy "$BAT" "$TMP/Payload/strategies/$ID.conf.in"
    printf '%s\t%s\n' "$ID" "$NAME" >> "$TMP/Payload/strategies.tsv"
done

for FILE in "$WINDOWS"/bin/*.bin; do
    /bin/cp "$FILE" "$TMP/Payload/bin/"
done
for NAME in list-general.txt list-google.txt list-exclude.txt ipset-exclude.txt; do
    /usr/bin/awk '{ sub(/\r$/, ""); print }' "$WINDOWS/lists/$NAME" > "$TMP/Payload/default-lists/$NAME"
done
/usr/bin/curl -fL --retry 2 --connect-timeout 10 --max-time 120 -o "$TMP/ipset-all.txt" "$IPSET_URL"
/usr/bin/awk '{ sub(/\r$/, ""); print }' "$TMP/ipset-all.txt" > "$TMP/Payload/default-lists/ipset-all.txt"

STRATEGY_COUNT=0
while IFS="$(printf '\t')" read -r ID NAME; do
    [ -n "$ID" ] || continue
    /usr/bin/sed -e "s|@BASE@|$TMP/Payload|g" -e "s|@LISTS@|$TMP/Payload/default-lists|g" -e "s|@IPSET@|$TMP/Payload/default-lists/ipset-all.txt|g" "$TMP/Payload/strategies/$ID.conf.in" > "$TMP/check.conf"
    printf '\n--dry-run\n' >> "$TMP/check.conf"
    if ! "$TMP/Payload/bin/utunws" "@$TMP/check.conf" > "$TMP/check.log" 2>&1; then
        echo "strategy validation failed: $NAME"
        /bin/cat "$TMP/check.log"
        exit 1
    fi
    STRATEGY_COUNT=$((STRATEGY_COUNT + 1))
done < "$TMP/Payload/strategies.tsv"
[ "$STRATEGY_COUNT" -gt 0 ]

/usr/bin/ditto "$TARGET_PAYLOAD" "$TMP/Payload.backup"
if ! /usr/bin/rsync -a --delete "$TMP/Payload/" "$TARGET_PAYLOAD/" || ! /usr/bin/codesign --force --deep --sign - "$TARGET_APP" || ! /usr/bin/codesign --verify --deep --strict "$TARGET_APP"; then
    /usr/bin/rsync -a --delete "$TMP/Payload.backup/" "$TARGET_PAYLOAD/"
    /usr/bin/codesign --force --deep --sign - "$TARGET_APP" >/dev/null 2>&1 || true
    echo 'failed to update application resources'; exit 1
fi

/bin/mkdir -p "$BASE"
/usr/bin/rsync -a --delete "$TMP/Payload/" "$BASE/"
/usr/bin/touch "$BASE/ipset-any.txt"
for NAME in install.sh run.sh restart.sh stop.sh test-strategies.sh update-app.sh update-configs.sh watchdog.sh bin/utunws; do
    /bin/chmod 755 "$BASE/$NAME"
done
for NAME in list-general.txt list-google.txt list-exclude.txt ipset-exclude.txt ipset-all.txt; do
    /usr/bin/install -m 0644 "$TMP/Payload/default-lists/$NAME" "$DATA_ROOT/lists/$NAME"
    /usr/sbin/chown "$USER_UID:$USER_GID" "$DATA_ROOT/lists/$NAME"
done
/bin/mkdir -p "$BASE/lists"
for NAME in list-general.txt list-general-user.txt list-google.txt list-exclude.txt list-exclude-user.txt ipset-all.txt ipset-exclude.txt ipset-exclude-user.txt; do
    /usr/bin/install -m 0644 "$DATA_ROOT/lists/$NAME" "$BASE/lists/$NAME"
done
/usr/sbin/chown -R root:wheel "$BASE"

SELECTED=$(/usr/bin/tr -d '[:space:]' < "$DATA_ROOT/selected-strategy" 2>/dev/null || true)
if ! /usr/bin/awk -F '\t' -v id="$SELECTED" '$1 == id { found = 1 } END { exit !found }' "$TMP/Payload/strategies.tsv"; then
    printf 'general-simple-fake\n' > "$DATA_ROOT/selected-strategy"
    /usr/sbin/chown "$USER_UID:$USER_GID" "$DATA_ROOT/selected-strategy"
fi

if /usr/bin/pgrep -x utunws >/dev/null 2>&1; then
    "$BASE/restart.sh"
fi
printf 'Updated %s strategies from Flowseal\n' "$STRATEGY_COUNT"
