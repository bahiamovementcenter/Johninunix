# Nushell front end for jd. In nu: `use jd.nu`, with this folder in
# NU_LIB_DIRS (the development shells set it), or `use nu/jd.nu` from the
# repository's top folder. The jd package installs it in share/johnnydecimal/nu.
#
#   jd 11.11            run jd; a target that is a folder changes into it
#   jd init [dir]       start a system: system.ncl, jd's config, then scaffold
#   jd ids [10-19|11]   the IDs on disk, as a table
#   jd project          system.ncl, evaluated and checked by Nickel
#   jd write-config     write jd's config.json from system.ncl
#   jd scaffold         create the folders and JDex notes system.ncl declares
#   jd check            compare system.ncl with the disk and with extensions/
#
# It wraps the jd program and never changes it. The commands that take
# --file read $env.JD_SYSTEM, or else system.ncl in the current folder.
# system.ncl can `import "johnny-decimal.ncl"`: Nickel looks for it in
# ../nickel from this file, where the repository and the package keep it.

const nickel_lib = path self | path dirname | path join ".." "nickel" | path expand

# Run jd. When jd resolves a folder, change into it.
export def --env --wrapped main [...args: string] {
  let r = with-env { JD_HOOK: "1" } { ^jd ...$args | complete }
  if $r.exit_code == 3 {
    # What jd said on the way, like the lines `jd new` prints, then the folder
    if $r.stderr != "" { print --stderr --no-newline $r.stderr }
    cd ($r.stdout | str trim)
    return
  }
  if $r.stdout != "" { print --no-newline $r.stdout }
  if $r.stderr != "" { print --stderr --no-newline $r.stderr }
  if $r.exit_code != 0 {
    error make --unspanned { msg: $"jd exited with status ($r.exit_code)" }
  }
}

# The JDex folder of a system (the file, for a JDex in Org), or null for
# none (or a JDex in Bear)
def jdex-path [s: record] {
  $s.jdex?.path?
}

# The headings of an Org file's lines: line (from 0), level, and path,
# the titles from the top joined by '/', with any tags left out. It's how
# jd's Org store (jdex/org.sh) reads the file.
def org-outline [lines: list<string>] {
  $lines | enumerate | reduce --fold { titles: [], rows: [] } { |it, acc|
    let m = $it.item | parse --regex '^(?<stars>\*+) (?<title>.*)$'
    if ($m | is-empty) {
      $acc
    } else {
      let level = $m.0.stars | str length
      let title = $m.0.title | str replace --regex '[ \t]+:[A-Za-z0-9_@#%:]+:[ \t]*$' '' | str trim --right
      let titles = $acc.titles | take ($level - 1) | append $title
      {
        titles: $titles
        rows: ($acc.rows | append { line: $it.index, level: $level, path: ($titles | str join "/") })
      }
    }
  } | get rows
}

def org-lines [file: string] {
  if ($file | path exists) { open --raw $file | lines } else { [] }
}

# Add heading `path` (titles joined by '/') at the end of its parent's
# subtree, as jd's Org store adds a note
def org-insert [lines: list<string>, path: string] {
  let parts = $path | split row "/"
  let level = $parts | length
  let heading = $"('' | fill --character '*' --width $level) ($parts | last)"
  let at = if $level == 1 {
    $lines | length
  } else {
    let outline = org-outline $lines
    let parent = $parts | drop | str join "/"
    let found = $outline | where path == $parent
    if ($found | is-empty) {
      error make --unspanned { msg: $"the Org file has no heading ($parent)" }
    }
    let start = $found.0.line
    $outline | where { |r| $r.line > $start and $r.level < $level } | get line | append ($lines | length) | first
  }
  if $at == ($lines | length) { $lines | append $heading } else { $lines | insert $at $heading }
}

# Does a planned entry exist? A folder or note on disk, or a heading in
# the Org file
def present [e: record] {
  if $e.type == "heading" {
    $e.heading in (org-outline (org-lines $e.file) | get path)
  } else {
    $e.target | path exists
  }
}

# The system.ncl to read: --file, else $env.JD_SYSTEM, else ./system.ncl
def system-file [file?: path] {
  $file | default $env.JD_SYSTEM? | default "system.ncl" | path expand
}

# A path from system.ncl: ~ is the home folder, and a relative path is
# relative to the folder system.ncl is in
def resolve [dir: string, p: string] {
  if ($p | str starts-with "~") { $p | path expand } else { $dir | path join $p | path expand }
}

# system.ncl as a record, with root and the JDex path made absolute
def load [file?: path] {
  let file = system-file $file
  let dir = $file | path dirname
  let project = ^nickel export --format json --import-path $nickel_lib $file | from json
  let systems = $project.config.systems | each { |s|
    let s = $s | upsert root (resolve $dir $s.root)
    let jdex = jdex-path $s
    if $jdex != null {
      $s | upsert jdex.path (resolve $dir $jdex)
    } else {
      $s
    }
  }
  $project | upsert config.systems $systems
}

# Everything the system declares: one folder in the root per entry, plus a
# folder (areas, categories) or a note (IDs) in a JDex folder, or a heading
# in a JDex in Org. A JDex in Bear has no folder, so nothing is planned
# there.
def plan [project: record] {
  $project.scaffold | each { |e|
    let s = $project.config.systems | where sys == $e.sys | first
    let in_root = { kind: $e.kind, type: "folder", target: ($s.root | path join $e.path) }
    let jdex = jdex-path $s
    if $jdex != null and $s.jdex?.app? == "org" {
      let in_jdex = { kind: $e.kind, type: "heading", target: $"($jdex)::($e.path)", file: $jdex, heading: $e.path }
      [$in_root $in_jdex]
    } else if $jdex != null {
      let in_jdex = if $e.kind == "id" {
        { kind: $e.kind, type: "note", target: ($jdex | path join $"($e.path).md") }
      } else {
        { kind: $e.kind, type: "folder", target: ($jdex | path join $e.path) }
      }
      [$in_root $in_jdex]
    } else {
      [$in_root]
    }
  } | flatten
}

def subdirs [dirs: list<string>, pattern: string] {
  $dirs | each { |d|
    ls --full-paths $d | where type == dir and ($it.name | path basename) =~ $pattern | get name
  } | flatten
}

# The areas, categories and IDs on disk under a root (none before it exists)
def jd-folders [root: string] {
  if not ($root | path exists) { return [] }
  let areas = subdirs [$root] '^\d0-\d9 '
  let categories = subdirs $areas '^\d\d '
  let ids = subdirs $categories '^\d\d\.\d\d '
  [
    ...($areas | each { |p| { kind: "area", path: $p } })
    ...($categories | each { |p| { kind: "category", path: $p } })
    ...($ids | each { |p| { kind: "id", path: $p } })
  ]
}

def functions-in [file: string] {
  open --raw $file | parse --regex '(?m)^(?<name>[A-Za-z_][A-Za-z0-9_]*)\(\)' | get name
}

def calls-in [file: string, helper: string] {
  open --raw $file | parse --regex ('(?m)^\s*' + $helper + '\s+(?<arg>\S+)') | get arg | sort
}

def row [kind: string, path: string, status: string, detail: string = ""] {
  { kind: $kind, path: $path, status: $status, detail: $detail }
}

# Each extensions/*.sh against its declaration in system.ncl, each adapter
# against the functions its kind must define, and each adapter a system names
def check-extensions [project: record, dir: string] {
  let files = if ($dir | path exists) { ls $dir | where name =~ '\.sh$' | get name } else { [] }
  let names = $files | each { |f| $f | path basename }
  let declared = $project.extensions | columns

  let found = $files | each { |f|
    let name = $f | path basename
    if $name not-in $declared {
      row "extension" $f "undeclared" "not in system.ncl's extensions"
    } else {
      let want = $project.extensions | get $name
      let wraps = calls-in $f "jd_wrap"
      let commands = calls-in $f "jd_command"
      if $wraps != ($want.wraps | sort) {
        row "extension" $f "mismatch" $"wraps ($wraps | str join ', '), declared ($want.wraps | str join ', ')"
      } else if $commands != ($want.commands | sort) {
        row "extension" $f "mismatch" $"adds ($commands | str join ', '), declared ($want.commands | str join ', ')"
      } else {
        row "extension" $f "ok"
      }
    }
  }
  let lost = $declared | where { |n| $n not-in $names } | each { |n|
    row "extension" ($dir | path join $n) "missing" "declared in system.ncl, no such file"
  }

  let adapters = ["jdex" "notes" "tasks"] | each { |kind|
    let kind_dir = $dir | path join "adapters" $kind
    let spec = $project.adapters | get $kind
    let files = if ($kind_dir | path exists) { ls $kind_dir | where name =~ '\.sh$' | get name } else { [] }
    {
      kind: $kind
      names: ($spec.builtin | append ($files | each { |f| $f | path parse | get stem }))
      rows: ($files | each { |f|
        let absent = $spec.functions | where { |fn| $fn not-in (functions-in $f) }
        if ($absent | is-empty) {
          row "adapter" $f "ok"
        } else {
          row "adapter" $f "mismatch" $"does not define ($absent | str join ', ')"
        }
      })
    }
  }
  # The note app is the JDex's app, and the task app is workPackages.tasks.app
  let used = $project.config.systems | each { |s|
    [
      { kind: "notes", name: $s.jdex?.app? }
      { kind: "tasks", name: $s.workPackages?.tasks?.app? }
    ] | where name != null | each { |u|
      let known = $adapters | where kind == $u.kind | first | get names
      if $u.name in $known {
        row "adapter" $"($s.sys) ($u.kind)" "ok" $u.name
      } else {
        row "adapter" $"($s.sys) ($u.kind)" "missing" $"no ($u.kind) adapter named ($u.name)"
      }
    }
  } | flatten

  $found | append $lost | append ($adapters | get rows | flatten) | append $used
}

# The IDs on disk in a system, filtered by area (10-19) or category (11)
export def ids [
  target?: string     # an area like 10-19 or a category like 11
  --system (-s): string # a system other than the default
] {
  let root = (if $system == null { ^jd } else { ^jd --system $system }) | str trim
  let ids = jd-folders $root | where kind == "id" | each { |r|
    let parts = $r.path | path split | last 3
    let base = $parts.2 | parse --regex '^(?<id>\d\d\.\d\d) ?(?<name>.*)$' | first
    { id: $base.id, name: $base.name, category: $parts.1, area: $parts.0, path: $r.path }
  }
  if $target == null {
    $ids
  } else if $target =~ '^\d0-\d9$' {
    $ids | where { |r| $r.area | str starts-with $target }
  } else if $target =~ '^\d\d$' {
    $ids | where { |r| $r.id | str starts-with $"($target)." }
  } else {
    error make --unspanned { msg: $"'($target)' is not an area like 10-19 or a category like 11" }
  }
}

# system.ncl, evaluated and checked by Nickel
export def project [
  --file (-f): path # default: $env.JD_SYSTEM, else ./system.ncl
] {
  load $file
}

# Write jd's config.json (at `jd paths config`) from system.ncl
export def write-config [
  --file (-f): path # default: $env.JD_SYSTEM, else ./system.ncl
  --force # replace a config.json that differs
] {
  let new = load $file | get config | to json --indent 2
  let target = ^jd paths config | str trim
  if ($target | path exists) and (open --raw $target) != $new and not $force {
    error make --unspanned { msg: $"($target) exists and differs from system.ncl. Pass --force to replace it" }
  }
  mkdir ($target | path dirname)
  $new | save --force $target
  $target
}

# A starter system.ncl. Its root is the folder it's in, and so is its JDex.
def starter [sys: string, title: string, jdex: string] {
  let jdex_record = match $jdex {
    "folder" => '{ path = "jdex" }'
    "obsidian" => '{ app = "obsidian", path = "jdex" }'
    "org" => '{ app = "org", path = "jdex.org" }'
    "bear" => '{ app = "bear" }'
    _ => (error make --unspanned { msg: $"--jdex is folder, obsidian, org or bear, not ($jdex)" })
  }
  [
    $"# ($sys) ($title). Written by `jd init`; it's yours to edit. Declare your"
    "# areas, categories and IDs here, then `jd scaffold` creates what's missing."
    "# Relative paths are relative to this file."
    'let jd = import "johnny-decimal.ncl" in'
    "jd.project {"
    "  systems = ["
    "    {"
    $"      sys = \"($sys)\","
    $"      title = \"($title)\","
    '      root = ".",'
    $"      jdex = ($jdex_record),"
    "      default = true,"
    "      areas = {"
    '        "10-19" = {'
    '          name = "Life admin",'
    "          categories = {"
    '            "11" = { name = "Me", ids = { "11.11" = "Passport" } },'
    '            "12" = { name = "House" },'
    "          },"
    "        },"
    "      },"
    "    },"
    "  ],"
    "}"
    ""
  ] | str join "\n"
}

# Start a system in a folder: write a starter system.ncl, write jd's config
# from it into the folder's .jd/config.json, and scaffold it. It sets
# $env.JD_SYSTEM and $env.JD_CONFIG to the new files, so jd and the other
# commands use this system. It won't replace a system.ncl without --force.
#
# The config goes in the folder, not jd's default one in ~/.config, because
# jd keeps one config for every system: writing there would fail, or with
# --force overwrite, the config of whatever system the machine already has.
export def --env init [
  dir?: path # default: the current folder
  --sys: string = "P76" # a letter and two digits
  --title: string = "Personal"
  --jdex: string = "folder" # folder, obsidian, org (one Org file) or bear
  --force # replace an existing system.ncl and its .jd/config.json
] {
  let dir = $dir | default $env.PWD | path expand
  let file = $dir | path join "system.ncl"
  if ($file | path exists) and not $force {
    error make --unspanned { msg: $"($file) exists. Pass --force to replace it" }
  }
  mkdir $dir
  starter $sys $title $jdex | save --force $file
  $env.JD_SYSTEM = $file
  $env.JD_CONFIG = $dir | path join ".jd" "config.json"
  let config = write-config --file $file --force=$force
  let made = scaffold --file $file
  print --stderr $"jd: wrote ($file) and ($config), and created ($made | length) entries. JD_SYSTEM and JD_CONFIG point at them for this shell"
  $made
}

# Create the folders and JDex notes that system.ncl declares and the disk
# lacks. It never deletes or renames anything.
export def scaffold [
  --file (-f): path # default: $env.JD_SYSTEM, else ./system.ncl
  --dry-run # list what it would create
] {
  let todo = plan (load $file) | where { |e| not (present $e) }
  if not $dry_run {
    for e in $todo {
      if $e.type == "folder" {
        mkdir $e.target
      } else if $e.type == "heading" {
        mkdir ($e.file | path dirname)
        org-insert (org-lines $e.file) $e.heading | str join "\n" | $in + "\n" | save --force $e.file
      } else {
        mkdir ($e.target | path dirname)
        touch $e.target
      }
    }
  }
  $todo | select type target
}

# Compare system.ncl with the disk (missing, undeclared) and with the
# files in extensions/ (missing, undeclared, mismatch)
export def check [
  --file (-f): path # default: $env.JD_SYSTEM, else ./system.ncl
  --extensions (-e): path # default: extensions/ beside system.ncl
] {
  let project = load $file
  let extensions = $extensions | default (system-file $file | path dirname | path join "extensions")
  let declared = plan $project
  let structure = $declared | each { |e|
    row $e.kind $e.target (if (present $e) { "ok" } else { "missing" })
  }
  let undeclared = $project.config.systems | each { |s|
    jd-folders $s.root | where { |d| $d.path not-in $declared.target } | each { |d|
      row $d.kind $d.path "undeclared" "on disk, not in system.ncl"
    }
  } | flatten
  $structure | append $undeclared | append (check-extensions $project ($extensions | path expand))
}
