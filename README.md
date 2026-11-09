# Johninunix

A [Johnny.Decimal](https://johnnydecimal.com) environment built with Nix,
[Nickel](https://nickel-lang.org) and [Nushell](https://www.nushell.sh),
around the official [jd](https://github.com/johnnydecimal/cli.johnnydecimal.com)
command-line tool. jd itself is never forked: it's fetched at a pinned
revision, and everything here is layered around it.

```sh
nix develop          # jd, jdd, nickel, nu
nu
use nu/jd.nu
jd write-config      # jd's config.json, from the system in $env.JD_SYSTEM
jd scaffold          # create the folders and JDex notes it declares
jd check             # compare it with the disk and with its extensions/
```

The shell points `JD_SYSTEM` at `example/system.ncl`, and `JD_CONFIG` and
`JDD_ROOT` into `example/`, from any folder in the repository. The example
system's root is `example/` and its JDex is `example/jdex/`, so scaffolding
never writes into the tool's own files (`example/.gitignore` ignores what it
creates). Point `root` and `jdex.path` at your real folders, or set
`JD_SYSTEM` to your own `system.ncl`, before you scaffold for real.

`jdex` follows jd's config version 2: `{ path = "..." }` for a folder of
notes, plus `app = "obsidian"` (and `vault`) for an Obsidian vault, or
`{ app = "bear" }` for a JDex in Bear.

## Layout

| Folder | What's in it |
| --- | --- |
| `pkgs/jd/` | `jd.nix`, the package, and `jd-ext.sh`, the extension loader it installs |
| `nickel/` | `johnny-decimal.ncl`, the contracts, and `generated/`, facts read from the pinned jd |
| `nu/` | `jd.nu`, the Nushell module |
| `example/` | an example `system.ncl` and its `extensions/` |
| `scripts/` | `generate.nu`, which writes `nickel/generated/` |
| `tests/` | `test.nu`, and `reject/`: declarations the contracts must reject |
| `organist/` | the same shell defined with Organist |

## The layers

Each layer works without the ones after it.

1. **Your system in Nickel.** A `system.ncl` declares your systems, areas,
   categories and IDs, and your extensions. The contracts in
   `nickel/johnny-decimal.ncl` check them against the Johnny.Decimal rules
   (areas like `10-19`, categories inside their area, `.06`–`.08` left free)
   and add the [standard zeros](https://johnnydecimal.com/documentation/the-standard-zeros).
   `nickel/generated/` holds facts read from the pinned jd: its functions,
   commands and adapter interface. Extensions are checked against them, so a
   jd upgrade that renames a function an extension wraps fails evaluation
   instead of breaking at run time.
2. **A Nushell front end.** `use nu/jd.nu` gives:

   | Command | What it does |
   | --- | --- |
   | `jd 11.11` | run jd; a target that is a folder changes into it |
   | `jd ids [10-19\|11]` | the IDs on disk, as a table |
   | `jd project` | the system, evaluated and checked |
   | `jd write-config` | write jd's `config.json` (won't replace a different one without `--force`) |
   | `jd scaffold` | create what's declared and missing; never deletes |
   | `jd check` | missing and undeclared folders, and extensions that don't match their declaration |

   The commands read `$env.JD_SYSTEM`, or `system.ncl` in the current
   folder; `--file` overrides both. `jd check` looks for `extensions/` next
   to that `system.ncl`.
3. **Extensions inside jd.** `pkgs/jd/jd.nix` adds one line to jd that
   loads every `*.sh` in the folder given to `jd.withExtensions` before jd
   runs a command, plus any in `~/.config/johnnydecimal/ext/`. `jd_wrap FN`
   wraps one of jd's functions and `jd_command NAME FN` adds a command (see
   `pkgs/jd/jd-ext.sh`). The shell's jd has the example's two:
   `example/extensions/stats.sh` adds `jd stats`, and `autocommit.sh`
   commits the JDex after `jd new` when `JD_AUTOCOMMIT=1`. Work-package
   adapters go in `extensions/adapters/{tasks,notes}/`. Declare each
   extension in the `system.ncl` next to it.

   Other flakes can use the overlay: `pkgs.jd.withExtensions ./dir`.
4. **Organist.** `organist/` is the same development shell defined in
   Nickel with [Organist](https://github.com/nickel-lang/organist)
   (`cd organist && nix develop`; Organist writes `nickel.lock.ncl` into the
   current folder). It's a flake of its own, and it takes jd and its
   extensions from the root flake through a `path:..` input, so nothing is
   copied. Its shell sets the same `JD_SYSTEM`, `JD_CONFIG` and `JDD_ROOT`;
   from `organist/`, `use ../nu/jd.nu`.

Files must be tracked by git for the flakes to see them.

## Upgrading jd

The package turns off jd's daily check for a newer version, and `jd update`
can't work, because the Nix store copy isn't a git clone. Change `version`,
`rev` and `hash` in `pkgs/jd/jd.nix` instead, then:

```sh
nix run .#generate   # rewrite nickel/generated/ from the new source
nix flake check      # contracts, extensions and tests/test.nu against it
```

## Checks

`nix flake check` checks that `nickel/generated/` is current and runs
`tests/test.nu` on a copy of the files it uses. That tests every
declaration in `tests/reject/` (each names the message it must fail with
on its first line), the Nushell commands, and both example extensions.
`nix fmt` formats the Nix files.
