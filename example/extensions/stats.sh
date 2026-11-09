# 'jd stats': how many IDs each area of the system has.
jd_command stats _jd_ext_stats

_jd_ext_stats() {
  local root
  root=$(jd_root "$1") || return 1
  find "$root" -mindepth 3 -maxdepth 3 -type d -name '[0-9][0-9].[0-9][0-9]*' \
    | awk -F/ '{ print $(NF - 2) }' | sort | uniq -c
}
