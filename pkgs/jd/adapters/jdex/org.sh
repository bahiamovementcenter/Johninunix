# jdex/org.sh - a JDex in one Org file
#
# '"jdex": { "app": "org", "path": "/home/you/jdex.org" }'. The path is
# the file. Its outline is the JDex:
#
#   * 10-19 Life admin                  an area
#   ** 11 Me                            a category
#   *** 11.11 Birth certificate         an ID
#   * W0000-9999 Work packages          the work package area
#   ** W0001~11.11 Renew it             a work package
#
# jd matches each heading by the number at its start, as it does a
# folder. Tags at the end of a heading are not part of its title.
#
# A container is a heading's path, its titles joined by '/':
# '10-19 Life admin/11 Me'. A locator is org:<line>.
#
# A note that jd writes is a heading at the end of its container, with a
# CUSTOM_ID: the ID, '11.11', or the work package's number, 'W0001'. A
# heading in the template becomes a heading below it.
#
# jd opens a heading with $JD_ORG_EDITOR, called with '+LINE FILE', or
# 'emacsclient -n' if that is not set.

_JD_JDEX_LABEL=Org
_JD_JDEX_UNIT=heading
_JD_JDEX_EXT=org

# One line for each heading: level, line, title and path, separated by
# a tab.
_jd_org_index() {
  awk '
    /^\*+ / {
      match($0, /^\*+/)
      lvl = RLENGTH
      t = substr($0, lvl + 2)
      sub(/[ \t]+:[A-Za-z0-9_@#%:]+:[ \t]*$/, "", t)
      sub(/[ \t]+$/, "", t)
      title[lvl] = t
      p = title[1]
      for (i = 2; i <= lvl; i++) p = p "/" title[i]
      printf "%d\t%d\t%s\t%s\n", lvl, NR, t, p
    }
  ' "$_JD_JDEX_PATH"
}

jd_jdex_load() {
  [ "${_JD_ORG_LOADED-}" = "$_JD_JDEX_PATH" ] && return 0
  if [ -z "$_JD_JDEX_PATH" ]; then
    _jd_nav_err "a JDex in Org requires jdex.path, the Org file"
    return 1
  fi
  if [ ! -f "$_JD_JDEX_PATH" ]; then
    _jd_nav_err "the JDex's Org file does not exist: $_JD_JDEX_PATH"
    return 1
  fi
  _JD_ORG_INDEX=$(_jd_org_index) || return 1
  _JD_ORG_LOADED=$_JD_JDEX_PATH
}

jd_jdex_find() {
  local what=$1 arg=${2-} us words
  jd_jdex_load || return 1
  shift
  case $what in search-area | search-category) shift ;; esac
  us=$(printf '\037')
  words=$(
    IFS=$us
    printf '%s' "$*"
  )
  printf '%s\n' "$_JD_ORG_INDEX" | _JD_ORG_WORDS=$words awk -F'\t' -v what="$what" -v arg="$arg" '
    function is(t, num) { return t == num || index(t, num " ") == 1 }
    function words(t,   i, lt) {
      lt = tolower(t)
      for (i = 1; i <= nw; i++) if (index(lt, tolower(w[i])) == 0) return 0
      return 1
    }
    function seg(p, n,   s) { split(p, s, "/"); return s[n] }
    function out(g) { printf "%s\torg:%s\t%s\t%s\n", g, $2, $4, $3 }
    function area(t) { return t ~ /^[0-9][0-9]-[0-9][0-9]( |$)/ }
    function warea(t) { return tolower(t) ~ /^w0000/ }
    function idlike(t) { return t ~ /^[0-9][0-9]\.[0-9][0-9]( |$)/ }
    function wplike(t) { return tolower(t) ~ /^w[0-9][0-9][0-9][0-9]([ ~]|$)/ }
    BEGIN {
      nw = (ENVIRON["_JD_ORG_WORDS"] == "") ? 0 : split(ENVIRON["_JD_ORG_WORDS"], w, "\037")
      la = tolower(arg)
    }
    {
      a = seg($4, 1)
      isid = ($1 == 3 && area(a) && idlike($3))
      iswp = ($1 == 2 && warea(a) && wplike($3))
    }
    what == "area" && $1 == 1 && is($3, arg) { out(1) }
    what == "category" && $1 == 2 && area(a) && is($3, arg) { out(1) }
    what == "id" && isid && is($3, arg) { out(1) }
    what == "wp" && iswp {
      lt = tolower($3)
      if (lt == la || index(lt, la " ") == 1 || index(lt, la "~") == 1) out(1)
    }
    what == "search-area" && isid && is(a, arg) && words($3) { out(1) }
    what == "search-category" && isid && is(seg($4, 2), arg) && words($3) { out(1) }
    what == "search" && isid && words($3) { out(1) }
    what == "search" && iswp && words($3) { out(2) }
  ' | sort -t "$(printf '\t')" -k1,1 -k3,3 | cut -f2-
}

# Open line $2 of the file.
_jd_org_edit() {
  if [ -n "${JD_ORG_EDITOR-}" ]; then
    eval "$JD_ORG_EDITOR \"+\$1\" \"\$_JD_JDEX_PATH\""
  elif command -v emacsclient >/dev/null 2>&1; then
    emacsclient -n "+$1" "$_JD_JDEX_PATH"
  else
    _jd_nav_err "set JD_ORG_EDITOR to open the JDex, or install emacsclient: $_JD_JDEX_PATH:$1"
    return 1
  fi
}

jd_jdex_open() {
  _jd_org_edit "${1#org:}" >/dev/null || return 1
  printf 'jd: opened %s in Org\n' "$2" >&2
}

jd_jdex_open_app() {
  _jd_org_edit 1 >/dev/null || return 1
  printf 'jd: opened %s\n' "$_JD_JDEX_PATH" >&2
}

# The titles of the headings directly below container $1.
jd_jdex_titles() {
  jd_jdex_load || return 1
  printf '%s\n' "$_JD_ORG_INDEX" | awk -F'\t' -v p="$1" '
    index($4, p "/") == 1 && index(substr($4, length(p) + 2), "/") == 0 { print $3 }
  '
}

jd_jdex_category() {
  jd_jdex_find category "$1" | cut -f2
}

jd_jdex_wp_area() {
  local jw
  jd_jdex_load || return 1
  jw=$(printf '%s\n' "$_JD_ORG_INDEX" | awk -F'\t' '$1 == 1 && tolower($3) ~ /^w0000/ { print $3 }')
  [ -n "$jw" ] || jw=$_JD_NEW_WP_AREA
  printf '%s\n' "$jw"
}

jd_jdex_where() { printf 'Org: %s, under %s in %s' "$1" "$2" "$_JD_JDEX_PATH"; }

# The CUSTOM_ID of note $1: 'W0001' or '11.11'.
_jd_org_cid() {
  case $1 in
    [Ww][0-9][0-9][0-9][0-9]*) printf '%s' "$1" | cut -c1-5 | tr 'a-z' 'A-Z' ;;
    *) printf '%s' "${1%% *}" ;;
  esac
}

# Write note $1 at the end of container $2. A work package area that is
# not in the file yet is added at its end.
jd_jdex_write() {
  local name=$1 container=$2 row lvl line end cid body tmp
  jd_jdex_load || return 1
  body=$(
    cat
    printf x
  )
  body=${body%x}
  row=$(printf '%s\n' "$_JD_ORG_INDEX" | awk -F'\t' -v p="$container" '$4 == p { print $1 "\t" $2; exit }')
  if [ -z "$row" ]; then
    case $container in
      */*)
        _jd_nav_err "the Org file has no heading $container"
        return 1
        ;;
    esac
    printf '\n* %s\n' "$container" >>"$_JD_JDEX_PATH" || return 1
    _JD_ORG_LOADED=''
    jd_jdex_load || return 1
    row=$(printf '%s\n' "$_JD_ORG_INDEX" | awk -F'\t' -v p="$container" '$4 == p { print $1 "\t" $2; exit }')
  fi
  lvl=${row%%"$(printf '\t')"*}
  line=${row#*"$(printf '\t')"}
  # The last line of the container's subtree.
  end=$(awk -v start="$line" -v lvl="$lvl" '
    NR > start && /^\*+ / { match($0, /^\*+/); if (RLENGTH <= lvl) { print NR - 1; found = 1; exit } }
    END { if (!found) print NR }
  ' "$_JD_JDEX_PATH")
  cid=$(_jd_org_cid "$name")
  tmp="$_JD_JDEX_PATH.jd-tmp"
  BODY=$body awk -v end="$end" -v stars="$(printf '%*s' $((lvl + 1)) '' | tr ' ' '*')" \
    -v name="$name" -v cid="$cid" '
    function note(   n, i, b, l) {
      printf "%s %s\n:PROPERTIES:\n:CUSTOM_ID: %s\n:END:\n", stars, name, cid
      b = ENVIRON["BODY"]
      sub(/\n+$/, "", b)
      if (b == "") return
      n = split(b, l, "\n")
      for (i = 1; i <= n; i++) {
        if (l[i] ~ /^\*+ /) l[i] = stars l[i]
        print l[i]
      }
    }
    { print }
    NR == end { note(); done = 1 }
    END { if (!done) note() }
  ' "$_JD_JDEX_PATH" >"$tmp" && mv -- "$tmp" "$_JD_JDEX_PATH" || {
    rm -f -- "$tmp"
    return 1
  }
  _JD_ORG_LOADED=''
  printf 'file:%s::#%s' "$_JD_JDEX_PATH" "$cid"
}
