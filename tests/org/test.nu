# jd.nu with a JDex in Org: scaffold writes the outline into jdex.org, and
# check reads it. Then jd itself adds an ID to the file. The flake's `org`
# check runs it on a copy of tests/org/, with the jd package's jd.nu and
# contracts.
use std/assert
use jd.nu

def main [] {
  $env.JD_SYSTEM = $env.PWD | path join "system.ncl"
  $env.JD_CONFIG = $env.PWD | path join ".jd" "config.json"
  jd write-config | ignore

  let made = jd scaffold
  assert equal ($made | where type == "heading" | length) 7
  assert equal (open --raw jdex.org | lines) [
    "* 10-19 Life admin"
    "** 11 Me"
    "*** 11.11 Passport"
    "*** 11.12 Bank"
    "** 12 House"
    "* 20-29 Work"
    "** 21 Clients"
  ]
  assert equal (jd scaffold --dry-run) []
  let problems = jd check | where status != "ok"
  assert equal $problems [] $"jd check found problems:\n($problems | table)"

  # A heading added by hand is kept, and one that's missing is reported
  "* 10-19 Life admin\n** 11 Me\n*** 11.11 Passport\n*** 11.13 Mine\n* 20-29 Work\n** 21 Clients\n" | save --force jdex.org
  let missing = jd check | where status == "missing" | get path
  assert equal ($missing | each { |t| $t | split row "::" | last }) [
    "10-19 Life admin/11 Me/11.12 Bank"
    "10-19 Life admin/12 House"
  ]
  jd scaffold | ignore
  assert equal (open --raw jdex.org | lines) [
    "* 10-19 Life admin"
    "** 11 Me"
    "*** 11.11 Passport"
    "*** 11.13 Mine"
    "*** 11.12 Bank"
    "** 12 House"
    "* 20-29 Work"
    "** 21 Clients"
  ]

  # jd reads the same outline: the next ID in 11 is 11.14
  ^jd new id 11 Car o+e>| ignore
  assert ("root/10-19 Life admin/11 Me/11.14 Car" | path exists)
  assert ((open --raw jdex.org | lines) | any { |l| $l == "*** 11.14 Car" })
  print "ok"
}

# `jd init` starts a system from nothing, in each JDex kind it writes to disk
def "main init" [] {
  # A machine that already has a system: jd's own config, and JD_CONFIG
  # pointing at it, as the development shell does. init must leave it alone.
  let existing = $env.PWD | path join "existing" "config.json"
  mkdir ($existing | path dirname)
  '{"version": 2, "systems": []}' | save $existing
  for kind in [org folder] {
    $env.JD_CONFIG = $existing
    let dir = $env.PWD | path join $"init-($kind)"
    jd init $dir --jdex $kind --sys "E76" --title "Experiments" | ignore
    assert equal $env.JD_SYSTEM ($dir | path join "system.ncl")
    assert equal $env.JD_CONFIG ($dir | path join ".jd" "config.json")
    assert equal (open $env.JD_CONFIG | get systems.0.sys) "E76"
    assert equal (open --raw $existing) '{"version": 2, "systems": []}'
    assert ($dir | path join "10-19 Life admin" "11 Me" "11.11 Passport" | path exists)
    if $kind == "org" {
      # The standard zeros are on by default, so 11.00 to 11.09 come first
      let headings = open --raw ($dir | path join "jdex.org") | lines
      assert equal ($headings | first 3) ["* 10-19 Life admin" "** 11 Me" "*** 11.00 JDex"]
      assert ("*** 11.11 Passport" in $headings)
      assert ("** 12 House" in $headings)
      # system.ncl starts work packages at W0011, as the Johnny.Decimal docs advise
      do { jd new wp 11.11 "First one" } | ignore
      assert ("** W0011~11.11 First one" in (open --raw ($dir | path join "jdex.org") | lines))
    } else {
      assert ($dir | path join "jdex" "10-19 Life admin" "11 Me" "11.11 Passport.md" | path exists)
    }
    assert equal (jd check | where status != "ok") []
    let again = try { jd init $dir --jdex $kind; "replaced" } catch { "refused" }
    assert equal $again "refused"
    # --force replaces system.ncl and the folder's config, here with a new sys
    jd init $dir --jdex $kind --sys "E77" --force | ignore
    assert equal (open $env.JD_CONFIG | get systems.0.sys) "E77"
  }
  print "ok"
}
