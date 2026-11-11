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
