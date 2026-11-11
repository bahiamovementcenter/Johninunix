# The Org JDex store (pkgs/jd/adapters/jdex/org.sh), end to end, through
# the jd program. Run by `nix flake check` (checks.org), in a temporary
# folder, with jd on PATH.
set -u
t=$PWD
fails=0
ok() { printf 'ok - %s\n' "$1"; }
no() { printf 'not ok - %s\n' "$1"; fails=$((fails + 1)); }
has() { # NAME FILE TEXT
  if grep -qF -- "$3" "$2"; then ok "$1"; else no "$1: no '$3' in $2"; sed 's/^/    /' "$2"; fi
}

export HOME=$t/home JD_CONFIG=$t/config.json JD_ORG_EDITOR="$t/editor"
mkdir -p "$HOME" "root/10-19 Life admin/11 Me/11.11 Birth certificate" "root/10-19 Life admin/11 Me/11.20 Manual"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>%s/opened\n' "$t" >editor
chmod +x editor

cat >jdex.org <<'ORG'
#+title: P76 JDex

* 10-19 Life admin
** 11 Me :me:
*** 11.11 Birth certificate
Where it is.
*** 11.20 Manual
** 12 House
* 20-29 Work
ORG

cat >config.json <<JSON
{ "version": 2, "systems": [ { "sys": "P76", "default": true, "root": "$t/root",
  "jdex": { "app": "org", "path": "$t/jdex.org" } } ] }
JSON

# Open an ID, an area, and the file
jd jdex 11.11 2>err
has 'jdex 11.11 opens its heading' opened "+5 $t/jdex.org"
has 'jdex 11.11 says what it opened' err 'opened 10-19 Life admin/11 Me/11.11 Birth certificate in Org'
jd jdex 12 2>err
has 'jdex 12 opens the category' opened "+8 $t/jdex.org"
jd jdex 11 2>err
has 'jdex 11 finds the category, with its tag left out' err 'opened 10-19 Life admin/11 Me in Org'
jd jdex 2>err
has 'jdex alone opens the file' opened "+1 $t/jdex.org"
jd jdex birth 2>err
has 'jdex searches the titles' err 'opened 10-19 Life admin/11 Me/11.11 Birth certificate in Org'

# A new ID: the next free number in the category
jd new id 11 Passport --json >out 2>err || no "new id: $(cat err)"
has 'new id: next number after 11.20' jdex.org '*** 11.21 Passport'
has 'new id: CUSTOM_ID' jdex.org ':CUSTOM_ID: 11.21'
has 'new id: link in --json' out "file:$t/jdex.org::#11.21"
[ -d "root/10-19 Life admin/11 Me/11.21 Passport" ] && ok 'new id: folder' || no 'new id: folder'
awk '/11.21 Passport/ { a = NR } /^\*\* 12 House/ { b = NR } END { exit !(a && b && a < b) }' jdex.org &&
  ok 'new id: at the end of its category' || no 'new id: at the end of its category'

# A new work package: the area is added, the template's headings go below
jd new wp 11.11 Renew it --json >out 2>err || no "new wp: $(cat err)"
has 'new wp: area added' jdex.org '* W0000-9999 Work packages'
has 'new wp: note' jdex.org '** W0001~11.11 Renew it'
has 'new wp: CUSTOM_ID' jdex.org ':CUSTOM_ID: W0001'
has 'new wp: parent link' jdex.org '- Parent :: [[*11.11 Birth certificate]]'
has 'new wp: its own link' jdex.org "- JDex :: [[file:$t/jdex.org::#W0001][JDex]]"
has "new wp: the template's heading is below the note" jdex.org '*** Scope'
grep -q 'Tasks ::' jdex.org && no 'new wp: an empty tasks link is left out' || ok 'new wp: an empty tasks link is left out'
[ -d "root/W0000-9999 Work packages/W0001~11.11 Renew it" ] && ok 'new wp: folder' || no 'new wp: folder'
[ -f "root/W0000-9999 Work packages/W0003 Templates for area W0000-9999/Work package template.org" ] &&
  ok 'new wp: jd copied its Org template into W0003' || no 'new wp: jd copied its Org template into W0003'

jd new wp 11.21 Second one >/dev/null 2>err || no "second wp: $(cat err)"
has 'second wp: next number' jdex.org '** W0002~11.21 Second one'
[ "$(grep -c '^\* W0000' jdex.org)" -eq 1 ] && ok 'second wp: one area' || no 'second wp: one area'

# W0003 and W0009 are the area's templates and archive folders, so jd steps
# over them (wp-numbers.patch)
jd new wp 11.21 Third >/dev/null 2>err || no "third wp: $(cat err)"
has 'third wp: W0004, past the templates folder W0003' jdex.org '** W0004~11.21 Third'
for i in 5 6 7 8; do jd new wp 11.21 "Number $i" >/dev/null 2>err || no "wp $i: $(cat err)"; done
jd new wp 11.21 Tenth >/dev/null 2>err || no "tenth wp: $(cat err)"
has 'then W0010, past the archive W0009' jdex.org '** W0010~11.21 Tenth'

jd jdex w0002 2>err
has 'jdex W0002 opens the work package' err 'opened W0000-9999 Work packages/W0002~11.21 Second one in Org'

# An ID that is in the JDex and not in the filesystem: jd creates its folder
rm -r "root/10-19 Life admin/11 Me/11.20 Manual"
jd 11.20 >/dev/null 2>err
[ -d "root/10-19 Life admin/11 Me/11.20 Manual" ] && ok 'jd 11.20 creates the folder from the JDex' ||
  no "jd 11.20 creates the folder from the JDex: $(cat err)"

# workPackages.firstNumber: a system that leaves W0000-W0009 to the area
mkdir -p first/root "first/root/10-19 A/11 B/11.11 C"
printf '* 10-19 A\n** 11 B\n*** 11.11 C\n' >first/jdex.org
cat >first/config.json <<JSON
{ "version": 2, "systems": [ { "sys": "P76", "default": true, "root": "$t/first/root",
  "jdex": { "app": "org", "path": "$t/first/jdex.org" }, "workPackages": { "firstNumber": 10 } } ] }
JSON
JD_CONFIG=$t/first/config.json jd new wp 11.11 One >/dev/null 2>err || no "firstNumber: $(cat err)"
has 'firstNumber 10: the first work package is W0010' first/jdex.org '** W0010~11.11 One'
sed -i 's/"firstNumber": 10/"firstNumber": "ten"/' first/config.json
JD_CONFIG=$t/first/config.json jd new wp 11.11 Two >/dev/null 2>err && no 'firstNumber "ten" is refused' ||
  has 'firstNumber "ten" is refused' err 'workPackages.firstNumber is'

printf '\n--- jdex.org\n'
cat jdex.org
[ "$fails" -eq 0 ] || { printf '%s failed\n' "$fails"; exit 1; }
