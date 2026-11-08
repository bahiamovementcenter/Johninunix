# Extension loader for jd, installed by jd.nix as lib/ext.sh. bin/jd sources
# it after its own lib/*.sh and before it runs a command, so an extension can
# redefine any of jd's functions.
#
# Extensions are loaded from lib/ext/*.sh (bundled by `jd.withExtensions`),
# then from $XDG_CONFIG_HOME/johnnydecimal/ext/*.sh (no rebuild needed).
# Declare each one in system.ncl, so `jd check` can verify it against the
# functions and commands of the pinned jd (nickel/generated/).

# jd_wrap FN: rename jd's function FN to FN__orig. The extension then defines
# FN again and calls FN__orig from it. One wrapper per function.
jd_wrap() {
  if ! declare -F "$1" >/dev/null; then
    printf 'jd: an extension wraps %s, which jd %s does not define\n' "$1" "$_JD_CLI_VERSION" >&2
    exit 1
  fi
  if declare -F "$1__orig" >/dev/null; then
    printf 'jd: two extensions wrap %s\n' "$1" >&2
    exit 1
  fi
  eval "$(declare -f "$1" | sed "1s/^$1 /$1__orig /")"
}

# jd_command NAME FN: 'jd NAME ARGS...' runs 'FN SYS ARGS...'. SYS is the
# system given with --system, or '' for the default one.
_jd_ext_commands=''
jd_command() { _jd_ext_commands="$_jd_ext_commands $1=$2"; }

# jd_root SYS: print the root folder of a system ('' for the default one).
jd_root() { JD_HOOK='' _jd_nav "${1-}"; }

for _jd_ext in "$_JD_CLI_DIR"/lib/ext/*.sh "${XDG_CONFIG_HOME:-$HOME/.config}"/johnnydecimal/ext/*.sh; do
  [ -f "$_jd_ext" ] && . "$_jd_ext"
done
unset _jd_ext

if [ -n "$_jd_ext_commands" ]; then
  eval "$(declare -f _jd_nav | sed '1s/^_jd_nav /_jd_ext_nav /')"
  _jd_nav() {
    local pair
    for pair in $_jd_ext_commands; do
      if [ "${2-}" = "${pair%%=*}" ]; then
        local sys=$1
        shift 2
        "${pair#*=}" "$sys" "$@"
        return
      fi
    done
    _jd_ext_nav "$@"
  }
fi
