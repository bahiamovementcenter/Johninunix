# Nushell front end for jd. In nu, from this folder: `use nu/jd.nu`
#
#   jd 11.11            run jd; a target that is a folder changes into it
#   jd ids [10-19|11]   the IDs on disk, as a table
#   jd project          system.ncl, evaluated and checked by Nickel
#   jd write-config     write jd's config.json from system.ncl
#   jd scaffold         create the folders and JDex notes system.ncl declares
#   jd check            compare system.ncl with the disk and with extensions/
#
# It wraps the jd program and never changes it. The commands that take
# --file read $env.JD_SYSTEM, or else system.ncl in the current folder.

# Run jd. When jd resolves a folder, change into it.
export def --env --wrapped main [...args: string] {
  let r = with-env { JD_HOOK: "1" } { ^jd ...$args | complete }
  if $r.exit_code == 3 {
    cd ($r.stdout | str trim)
    return
  }
  if $r.stdout != "" { print --no-newline $r.stdout }
  if $r.stderr != "" { print --stderr --no-newline $r.stderr }
  if $r.exit_code != 0 {
    error make --unspanned { msg: $"jd exited with status ($r.exit_code)" }
  }
}

# The JDex folder of a system, or null for none (or a JDex in Bear)
def jdex-path [s: record] {
  $s.jdex?.path?
}

# The system.ncl to read: --file, else $env.JD_SYSTEM, else ./system.ncl
def system-file [file?: path] {
  $file | default $env.JD_SYSTEM? | default "system.ncl" | path expand
}

# system.ncl as a record, with root and the JDex path made absolute
def load [file?: path] {
  let file = system-file $file
  let dir = $file | path dirname
  let project = ^nickel export --format json $file | from json
  let systems = $project.config.systems | each { |s|
    let s = $s | upsert root ($dir | path join $s.root | path expand)
    let jdex = jdex-path $s
    if $jdex != null {
      $s | upsert jdex.path ($dir | path join $jdex | path expand)
    } else {
      $s
    }
  }
  $project | upsert config.systems $systems
}

# Everything the system declares: one folder in the root per entry, plus a
# folder (areas, categories) or a note (IDs) in a JDex folder. A JDex in
# Bear has no folder, so nothing is planned there.
def plan [project: record] {
  $project.scaffold | each { |e|
    let s = $project.config.systems | where sys == $e.sys | first
    let in_root = { kind: $e.kind, type: "folder", target: ($s.root | path join $e.path) }
    let jdex = jdex-path $s
    if $jdex != null {
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

# The areas, categories and IDs on disk under a root
def jd-folders [root: string] {
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

  let adapters = ["notes" "tasks"] | each { |kind|
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

# Create the folders and JDex notes that system.ncl declares and the disk
# lacks. It never deletes or renames anything.
export def scaffold [
  --file (-f): path # default: $env.JD_SYSTEM, else ./system.ncl
  --dry-run # list what it would create
] {
  let todo = plan (load $file) | where { |e| not ($e.target | path exists) }
  if not $dry_run {
    for e in $todo {
      if $e.type == "folder" {
        mkdir $e.target
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
    row $e.kind $e.target (if ($e.target | path exists) { "ok" } else { "missing" })
  }
  let undeclared = $project.config.systems | each { |s|
    jd-folders $s.root | where { |d| $d.path not-in $declared.target } | each { |d|
      row $d.kind $d.path "undeclared" "on disk, not in system.ncl"
    }
  } | flatten
  $structure | append $undeclared | append (check-extensions $project ($extensions | path expand))
}
