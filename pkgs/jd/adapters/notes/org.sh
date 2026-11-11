# notes/org.sh - links into a JDex in one Org file (jdex/org.sh)
#
# The link to the work package's note is an Org link to its CUSTOM_ID,
# which jdex/org.sh writes:
#
#   file:/home/you/jdex.org::#w0216
#
# The link to the ID's own note is a link to its heading, by its title,
# which works in the same file whether or not the heading has an ID:
#
#   [[*21.41 Videos]]

jd_notes_check() { return 0; }

jd_notes_url() {
  printf 'file:%s::#%s' "$_JD_NEW_JDEX" "$(printf '%s' "$_JD_NEW_NUM" | tr 'A-Z' 'a-z')"
}

jd_notes_parent_link() {
  printf '[[*%s]]' "$_JD_NEW_PARENT_NOTE"
}
