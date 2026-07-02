#!/bin/bash
# Test harness for the idempotent Flameshot INI patch used in install.sh.
# Verifies: no duplicate [General], no duplicate key, value coercion to true,
# preservation of unrelated settings, and idempotency across repeated runs.
set -e

patch() {
  local FLAMESHOT_INI="$1"
  mkdir -p "$(dirname "$FLAMESHOT_INI")"
  touch "$FLAMESHOT_INI"
  awk '
    BEGIN { in_general = 0; done = 0; general_seen = 0 }
    /^\[/ {
        if (in_general && !done) { print "useX11LegacyScreenshot=true"; done = 1 }
        in_general = ($0 == "[General]")
        if (in_general) general_seen = 1
        print
        next
    }
    {
        if (in_general && $0 ~ /^useX11LegacyScreenshot[[:space:]]*=/) {
            print "useX11LegacyScreenshot=true"
            done = 1
            next
        }
        print
    }
    END {
        if (in_general && !done) { print "useX11LegacyScreenshot=true"; done = 1 }
        if (!general_seen) {
            if (NR > 0) print ""
            print "[General]"
            print "useX11LegacyScreenshot=true"
        }
    }
  ' "$FLAMESHOT_INI" > "$FLAMESHOT_INI.tmp" && mv "$FLAMESHOT_INI.tmp" "$FLAMESHOT_INI"
}

check() {
  local name="$1" file="$2"
  # Must have exactly one [General], exactly one useX11LegacyScreenshot=true
  local gcount kcount tcount
  gcount=$(grep -c '^\[General\]$' "$file" || true)
  kcount=$(grep -c '^useX11LegacyScreenshot=' "$file" || true)
  tcount=$(grep -c '^useX11LegacyScreenshot=true$' "$file" || true)
  if [ "$gcount" != "1" ] || [ "$kcount" != "1" ] || [ "$tcount" != "1" ]; then
    echo "FAIL [$name]: [General]=$gcount key=$kcount true=$tcount"
    echo "----- file -----"; cat "$file"; echo "----------------"
    return 1
  fi
  echo "PASS [$name]"
}

run_case() {
  local name="$1" content="$2"; shift 2
  local d; d=$(mktemp -d)
  local f="$d/.config/flameshot/flameshot.ini"
  mkdir -p "$(dirname "$f")"
  printf '%s' "$content" > "$f"
  patch "$f"; check "$name (1st)" "$f"
  # idempotency: run twice more, output must be byte-identical
  cp "$f" "$f.after1"
  patch "$f"; patch "$f"
  if ! diff -q "$f.after1" "$f" >/dev/null; then
    echo "FAIL [$name]: not idempotent"; diff "$f.after1" "$f"; return 1
  fi
  check "$name (idempotent)" "$f"
  # extra assertions
  for pat in "$@"; do
    if ! grep -qF "$pat" "$f"; then echo "FAIL [$name]: missing preserved line '$pat'"; cat "$f"; return 1; fi
  done
  rm -rf "$d"
}

# 1. Empty / non-existent file
run_case "empty" ""

# 2. No [General] section, other sections present (preserve them)
run_case "no-general" $'[Shortcuts]\nTYPE_COPY=Return\n' "[Shortcuts]" "TYPE_COPY=Return"

# 3. [General] exists without the key, plus unrelated keys (preserve)
run_case "general-no-key" $'[General]\ndisabledTrayIcon=false\nsavePath=/home/x/Pictures\n' "disabledTrayIcon=false" "savePath=/home/x/Pictures"

# 4. Key already present but wrong value -> coerce to true
run_case "wrong-value" $'[General]\nuseX11LegacyScreenshot=false\ncontrastOpacity=100\n' "contrastOpacity=100"

# 5. Key already true (no-op)
run_case "already-true" $'[General]\nuseX11LegacyScreenshot=true\n'

# 6. [General] not last: another section after it, key must land in General
run_case "general-then-other" $'[General]\nfoo=bar\n\n[Shortcuts]\nTYPE_COPY=Return\n' "foo=bar" "[Shortcuts]" "TYPE_COPY=Return"

# 7. Section before General, General has key wrong value
run_case "other-then-general" $'[Shortcuts]\nTYPE_COPY=Return\n\n[General]\nuseX11LegacyScreenshot=0\nsavePath=/x\n' "[Shortcuts]" "savePath=/x"

echo "ALL TESTS PASSED"
