# Checks a folder of extensions against the jd they were installed into.
# jd.nix runs it when it builds `jd.withExtensions DIR`, and any problem
# fails the build, so an extension that doesn't fit this jd never reaches
# your PATH.
#
#   bash check-extensions.sh OUT DIR
#
# It checks what doesn't need system.ncl: `jd check` also compares each
# extension with its declaration there.
set -eu
out=$1
ext=$2
problems=0

fail() {
  printf 'jd extensions: %s\n' "$*" >&2
  problems=$((problems + 1))
}

# Functions defined at the start of a line, like `_jd_stats() {`
defined() { grep -hoE '^[A-Za-z_][A-Za-z0-9_]*\(\)' "$@" | sed 's/()$//' | sort -u; }

# 1. Load them all into jd, as it does before every command. jd_wrap stops
# on a function this jd doesn't define, or one that two extensions wrap.
mkdir -p "$TMPDIR/home/.config"
if ! loaded=$(HOME=$TMPDIR/home XDG_CONFIG_HOME=$TMPDIR/home/.config "$out/bin/jd" version 2>&1); then
  fail "loading them into jd failed: $loaded"
fi

# 2. Commands: not one of jd's own, added once, and run by a function
# that an extension defines
builtins=$(grep -oE '"[^"]+"' "$out/share/johnnydecimal/nickel/generated/commands.ncl" | tr -d '"')
seen=''
for f in "$ext"/*.sh; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  while read -r cmd fn; do
    [ -n "$cmd" ] || continue
    if printf '%s\n' $builtins | grep -qxF "$cmd"; then
      fail "$name: jd $cmd is one of jd's own commands"
    fi
    case " $seen " in
      *" $cmd "*) fail "$name: jd $cmd is added twice" ;;
    esac
    seen="$seen $cmd"
    if ! defined "$ext"/*.sh | grep -qxF "$fn"; then
      fail "$name: jd $cmd runs $fn, which no extension defines"
    fi
  done <<EOF
$(sed -nE 's/^[[:space:]]*jd_command[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+).*/\1 \2/p' "$f")
EOF
done

# 3. Adapters: each kind is one jd has, and each adapter defines every
# function that kind's `none` adapter does
if [ -d "$ext/adapters" ]; then
  for dir in "$ext"/adapters/*/; do
    kind=$(basename "$dir")
    none=$out/share/johnnydecimal/cli/lib/adapters/$kind/none.sh
    if [ ! -f "$none" ]; then
      fail "adapters/$kind: jd has no $kind adapters"
      continue
    fi
    for f in "$dir"*.sh; do
      [ -e "$f" ] || continue
      absent=$(defined "$f" | comm -23 <(defined "$none") -)
      if [ -n "$absent" ]; then
        fail "adapters/$kind/$(basename "$f") does not define:" $absent
      fi
    done
  done
fi

if [ "$problems" -gt 0 ]; then
  printf 'jd extensions: %d problem(s) with %s\n' "$problems" "$ext" >&2
  exit 1
fi
