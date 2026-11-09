# Tests the layers together. Run from the repository's top folder, on a copy
# you don't mind changing: it scaffolds the example system in example/ and
# writes its config. The flake's `system` check runs it on a copy in the Nix
# sandbox.
use std/assert
use ../nu/jd.nu

# Each tests/reject/*.ncl must fail, with the message its first line names:
# `# expect: <message>`
def rejects [file: path] {
  let message = open --raw $file | lines | first | parse '# expect: {m}' | get 0.m
  let r = ^nickel export $file | complete
  assert ($r.exit_code != 0) $"Nickel accepted ($file), which should fail with: ($message)"
  assert ($r.stderr | str contains $message) $"($file): expected '($message)' in:\n($r.stderr)"
}

def main [] {
  let top = $env.PWD
  let example = $top | path join "example"
  $env.JD_SYSTEM = $example | path join "system.ncl"
  $env.JD_CONFIG = $example | path join ".jd" "config.json"
  $env.GIT_AUTHOR_NAME = "test"
  $env.GIT_AUTHOR_EMAIL = "test@example.com"
  $env.GIT_COMMITTER_NAME = "test"
  $env.GIT_COMMITTER_EMAIL = "test@example.com"

  print "layer 1: the contracts reject what breaks the rules"
  let cases = glob ($top | path join "tests" "reject" "*.ncl")
  assert (($cases | length) > 0) "no files in tests/reject"
  for f in $cases { rejects $f }

  print "layer 2: the nu module writes, scaffolds and checks the example system"
  assert equal (jd project | get config.systems | length) 1
  jd write-config | ignore
  assert ($env.JD_CONFIG | path exists)
  let config = open $env.JD_CONFIG
  assert equal $config.version 2 "jd 5 reads config version 2"
  assert equal $config.systems.0.jdex.path ($example | path join "jdex")
  assert ((jd scaffold | length) > 0)
  assert equal (jd scaffold --dry-run) []
  assert ($example | path join "10-19 Life admin" | path exists) "scaffold wrote outside example/"
  let problems = jd check | where status != "ok"
  assert equal $problems [] $"jd check found problems:\n($problems | table)"
  jd 11.11
  assert ($env.PWD | str ends-with "11.11 Passport")
  cd $top

  # From another folder, JD_SYSTEM finds system.ncl, and check finds
  # example/extensions/ beside it
  cd organist
  assert equal (jd project | get config.systems.0.sys) "P76"
  let problems = jd check | where status != "ok"
  assert equal $problems [] $"jd check from organist/ found problems:\n($problems | table)"
  cd $top

  print "layer 3: extensions inside jd"
  let jdex = $example | path join "jdex"
  ^jd new id 11 Test entry o+e>| ignore
  assert equal (jd ids 11 | where name == "Test entry" | get id) ["11.12"]
  assert (jd check | where status == "undeclared" | get path | any { |p| $p | str ends-with "11.12 Test entry" })
  # 11 has its 7 standard zeros, 11.11 and 11.12; 12 has its 7 zeros
  assert ((^jd stats) | str contains "16 10-19 Life admin")
  ^git -C $jdex init -q
  with-env { JD_AUTOCOMMIT: "1" } { ^jd new id 12 Boiler o+e>| ignore }
  assert equal (^git -C $jdex log --format=%s | str trim) "jd new: 12.11 Boiler"
  ^jd new id 12 Roof o+e>| ignore
  assert equal (^git -C $jdex log --format=%s | lines | length) 1 "autocommit ran without JD_AUTOCOMMIT=1"
  assert not ($"($env.JD_CONFIG).v1" | path exists) "jd rewrote the config: system.ncl wrote an old version"

  print "ok"
}
