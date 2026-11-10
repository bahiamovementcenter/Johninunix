# Tests templates/default, from a copy of it, with the jd package's own
# jd.nu and contracts (NU_LIB_DIRS and NICKEL_IMPORT_PATH). The flake's
# `template` check runs it.
use std/assert
use jd.nu

def main [] {
  ^nickel export system.ncl | ignore
  let project = jd project --file system.ncl
  assert equal ($project.config.systems | length) 1
  assert equal $project.config.version 2
  assert equal $project.config.systems.0.root ($env.HOME | path join "Documents")
  # Nothing is on disk here, so only the extensions can be checked
  let problems = jd check --file system.ncl | where kind not-in [area category id] and status != "ok"
  assert equal $problems [] $"jd check found problems:\n($problems | table)"
  print "ok"
}
