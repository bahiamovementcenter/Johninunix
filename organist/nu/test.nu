# Tests the layers together. Run from the template's folder, on a copy you
# don't mind changing: it scaffolds the example system and writes a config.
# The flake's `system` check runs it on a copy in the Nix sandbox.
use std/assert
use jd.nu

# Nickel must reject this declaration with this message
def rejects [message: string, areas: string, extensions: string = "{}", fields: string = ""] {
  $'let jd = import "nickel/johnny-decimal.ncl" in jd.project { systems = [{ sys = "P76", title = "T", root = ".", ($fields) areas = ($areas) }], extensions = ($extensions) }'
  | save --force bad.ncl
  let r = ^nickel export bad.ncl | complete
  rm bad.ncl
  assert ($r.exit_code != 0) $"Nickel accepted a declaration that should fail with: ($message)"
  assert ($r.stderr | str contains $message) $"expected '($message)' in:\n($r.stderr)"
}

def main [] {
  $env.JD_CONFIG = $env.PWD | path join ".jd" "config.json"
  $env.GIT_AUTHOR_NAME = "test"
  $env.GIT_AUTHOR_EMAIL = "test@example.com"
  $env.GIT_COMMITTER_NAME = "test"
  $env.GIT_COMMITTER_EMAIL = "test@example.com"

  print "layer 1: the contracts reject what breaks the rules"
  let one = '{ "10-19" = { name = "A" } }'
  rejects "is not a range like 10-19" '{ "10-29" = { name = "A" } }'
  rejects "category '21' is not in area 10-19" '{ "10-19" = { name = "A", categories = { "21" = { name = "C" } } } }'
  rejects "reserved by the standard zeros" '{ "10-19" = { name = "A", categories = { "11" = { name = "C", ids = { "11.07" = "X" } } } } }'
  rejects "is not a function in jd" $one '{ "x.sh" = { description = "d", wraps = ["_jd_nope"] } }'
  rejects "is built into jd" $one '{ "x.sh" = { description = "d", commands = ["new"] } }'
  rejects "two extensions wrap _jd_new" $one '{ "a.sh" = { description = "d", wraps = ["_jd_new"] }, "b.sh" = { description = "d", wraps = ["_jd_new"] } }'
  rejects "a jdex needs a path, unless its app is bear" $one "{}" 'jdex = { app = "obsidian" },'
  rejects "an app is a name of a-z, 0-9, _ and -" $one "{}" 'jdex = { app = "../x", path = "j" },'
  rejects "an app is a name of a-z, 0-9, _ and -" $one "{}" 'work_packages = { tasks = { app = "Things" } },'

  print "layer 2: the nu module writes, scaffolds and checks the example system"
  assert equal (jd project | get config.systems | length) 1
  jd write-config | ignore
  assert ($env.JD_CONFIG | path exists)
  let config = open $env.JD_CONFIG
  assert equal $config.version 2 "jd 5 reads config version 2"
  assert equal $config.systems.0.jdex.path ($env.PWD | path join "jdex")
  assert ((jd scaffold | length) > 0)
  assert equal (jd scaffold --dry-run) []
  let problems = jd check | where status != "ok"
  assert equal $problems [] $"jd check found problems:\n($problems | table)"
  jd 11.11
  assert ($env.PWD | str ends-with "11.11 Passport")
  cd -

  print "layer 3: extensions inside jd"
  ^jd new id 11 Test entry o+e>| ignore
  assert equal (jd ids 11 | where name == "Test entry" | get id) ["11.12"]
  assert (jd check | where status == "undeclared" | get path | any { |p| $p | str ends-with "11.12 Test entry" })
  # 11 has its 7 standard zeros, 11.11 and 11.12; 12 has its 7 zeros
  assert ((^jd stats) | str contains "16 10-19 Life admin")
  ^git -C jdex init -q
  with-env { JD_AUTOCOMMIT: "1" } { ^jd new id 12 Boiler o+e>| ignore }
  assert equal (^git -C jdex log --format=%s | str trim) "jd new: 12.11 Boiler"
  ^jd new id 12 Roof o+e>| ignore
  assert equal (^git -C jdex log --format=%s | lines | length) 1 "autocommit ran without JD_AUTOCOMMIT=1"
  assert not ($"($env.JD_CONFIG).v1" | path exists) "jd rewrote the config: system.ncl wrote an old version"

  print "ok"
}
