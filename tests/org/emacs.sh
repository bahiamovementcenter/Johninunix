# The Org store with real Emacs: jd writes the file, Org parses it and
# follows the links jd wrote, and `jdex` opens headings in a running
# Emacs through emacsclient (JD_ORG_EDITOR unset). Run by `nix flake
# check` (checks.org-emacs), in a temporary folder, with jd and Emacs on
# PATH.
set -u
t=$PWD
fails=0
ok() { printf 'ok - %s\n' "$1"; }
no() { printf 'not ok - %s\n' "$1"; fails=$((fails + 1)); }
same() { # NAME WANT GOT
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1"; printf '    want: %s\n    got:  %s\n' "$2" "$3"; fi
}

export HOME=$t/home JD_CONFIG=$t/config.json XDG_RUNTIME_DIR=$t/run
unset JD_ORG_EDITOR
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "root/10-19 Life admin/11 Me/11.11 Birth certificate"
chmod 700 "$XDG_RUNTIME_DIR"

cat >jdex.org <<'ORG'
#+title: P76 JDex

* 10-19 Life admin
** 11 Me :me:
*** 11.11 Birth certificate
** 12 House
ORG
cat >config.json <<JSON
{ "version": 2, "systems": [ { "sys": "P76", "default": true, "root": "$t/root",
  "jdex": { "app": "org", "path": "$t/jdex.org" } } ] }
JSON

jd new id 11 Passport >/dev/null 2>&1 || no 'jd new id'
jd new wp 11.11 Renew it >/dev/null 2>&1 || no 'jd new wp'

# Org's own reading of the file jd wrote
el() { emacs -Q --batch "$t/jdex.org" --eval "$1" 2>/dev/null; }
same 'Org reads the outline jd wrote' \
  '1 10-19 Life admin|2 11 Me|3 11.11 Birth certificate|3 11.12 Passport|2 12 House|1 W0000-9999 Work packages|2 W0001~11.11 Renew it|3 Scope|' \
  "$(el '(org-map-entries (lambda () (princ (format "%d %s|" (org-current-level) (org-get-heading t t t t)))))')"
same 'the CUSTOM_ID link jd wrote reaches the work package' 'W0001~11.11 Renew it' \
  "$(el '(progn (org-link-search "#w0001") (princ (org-get-heading t t t t)))')"
same 'the parent link reaches the ID' '11.11 Birth certificate' \
  "$(el '(progn (org-link-search "*11.11 Birth certificate") (princ (org-get-heading t t t t)))')"
same 'the ID has its CUSTOM_ID property' '11.12' \
  "$(el '(progn (org-link-search "*11.12 Passport") (princ (org-entry-get nil "CUSTOM_ID")))')"
same 'the file:...::#w0001 link jd printed opens the work package' 'W0001~11.11 Renew it' \
  "$(emacs -Q --batch --eval "(progn (require 'org) (org-link-open-from-string \"[[file:$t/jdex.org::#w0001]]\") (princ (org-get-heading t t t t)))" 2>/dev/null)"
same 'org-lint finds nothing' '' \
  "$(el '(progn (require (quote org-lint)) (dolist (r (org-lint)) (princ (format "%S\n" r))))')"

# jdex opens headings in a running Emacs
emacs -Q --daemon >/dev/null 2>&1 || no 'emacs --daemon'
at() { emacsclient --eval "(with-current-buffer (get-file-buffer \"$t/jdex.org\") (substring-no-properties (format \"%s %s\" major-mode (org-get-heading t t t t))))" 2>/dev/null | tr -d '"'; }
jd jdex 11.12 2>err
same 'jdex 11.12 opens the heading in Emacs' 'org-mode 11.12 Passport' "$(at)"
jd jdex w0001 2>err
same 'jdex W0001 moves Emacs to the work package' 'org-mode W0001~11.11 Renew it' "$(at)"
emacsclient --eval '(kill-emacs)' >/dev/null 2>&1

[ "$fails" -eq 0 ] || { printf '%s failed\n' "$fails"; cat jdex.org; exit 1; }
