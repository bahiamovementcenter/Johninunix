# Johninunix

A [Johnny.Decimal](https://johnnydecimal.com) environment built with Nix,
[Nickel](https://nickel-lang.org) and [Nushell](https://www.nushell.sh),
around the official [jd](https://github.com/johnnydecimal/cli.johnnydecimal.com)
command-line tool. jd itself is never forked: it's fetched at a release tag
(the `jd-src` flake input), and everything here is layered around it.

For your own system, start a repository from the template:

```sh
mkdir my-system && cd my-system && git init
nix flake init -t github:bahiamovementcenter/Johninunix
```

It has a `system.ncl`, an `extensions/` folder and a shell with jd, and it
takes jd, the contracts and `jd.nu` from this repository as one input.
Set `root` and `jdex` in `system.ncl` to your folders, then
`git add -A && nix develop`. `nix flake update johninunix` brings a newer
jd along with contracts that match it.

To work on this repository itself:

```sh
nix develop          # jd, jdd, nickel, nu
nu
use jd.nu
jd write-config      # jd's config.json, from the system in $env.JD_SYSTEM
jd scaffold          # create the folders and JDex notes it declares
jd check             # compare it with the disk and with its extensions/
```

The shell points `JD_SYSTEM` at `example/system.ncl`, and `JD_CONFIG` and
`JDD_ROOT` into `example/`, from any folder in the repository. It also puts
`nickel/` on `NICKEL_IMPORT_PATH` and `nu/` on `NU_LIB_DIRS`, so a
`system.ncl` can `import "johnny-decimal.ncl"` and nu can `use jd.nu`. The example
system's root is `example/` and its JDex is `example/jdex/`, so scaffolding
never writes into the tool's own files (`example/.gitignore` ignores what it
creates). Point `root` and `jdex.path` at your real folders, or set
`JD_SYSTEM` to your own `system.ncl`, before you scaffold for real.

To start a system from nothing, `jd init` writes a starter `system.ncl`
into a folder, writes jd's config from it, scaffolds it, and points
`JD_SYSTEM` at it:

```nu
$env.JD_CONFIG = "/tmp/jd-try/.jd/config.json"   # keep a trial away from your real config
jd init /tmp/jd-try --jdex org                   # or folder (default), obsidian, bear
jd new id 11 Car
```

In a `system.ncl`, a path that starts with `~` is in your home folder, and
any other relative path is relative to the file. `jdex` follows jd's config
version 2: `{ path = "..." }` for a folder of
notes, plus `app = "obsidian"` (and `vault`) for an Obsidian vault,
`{ app = "bear" }` for a JDex in Bear, or
`{ app = "org", path = "jdex.org" }` for a JDex in one Org file.

### A JDex in Org

This package's jd has a patch, `pkgs/jd/jdex-store.patch`, that makes the
place the JDex lives pluggable: a *JDex store* is one file,
`lib/adapters/jdex/<app>.sh`, and Bear is now one of them (see
`docs/adr/0001-jdex-store.md`). `pkgs/jd/adapters/jdex/org.sh` is a
second: the JDex is the outline of one Org file.

```org
* 10-19 Life admin
** 11 Me
*** 11.11 Passport
* W0000-9999 Work packages
** W0001~11.11 Renew it
:PROPERTIES:
:CUSTOM_ID: W0001
:END:
```

`jdex 11.11` opens the heading with `$JD_ORG_EDITOR +LINE FILE` (or
`emacsclient -n`); `jd new id` and `jd new wp` add a heading at the end of
its category or the work package area, from `ID template.org` and
`Work package template.org`; and `jd scaffold` in `jd.nu` writes the
declared areas, categories and IDs into the file as headings.

## Layout

| Folder | What's in it |
| --- | --- |
| `pkgs/jd/` | `jd.nix`, the package; `jdex-store.patch`, its change to jd; `adapters/` and `templates/`, the Org store it adds; `jd-ext.sh`, the extension loader it installs; `check-extensions.sh`, its build-time check |
| `docs/adr/` | the design decisions |
| `nickel/` | `johnny-decimal.ncl`, the contracts, and `generated/`, facts read from the pinned jd |
| `nu/` | `jd.nu`, the Nushell module |
| `example/` | an example `system.ncl` and its `extensions/` |
| `scripts/` | `generate.nu`, which writes `nickel/generated/` |
| `tests/` | `test.nu` and `template.nu`; `reject/`, declarations the contracts must reject; `bad-extensions/`, extensions the build must reject; `org/`, the Org store end to end |
| `templates/default/` | the template for your own system's repository |
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
2. **A Nushell front end.** `use jd.nu` gives:

   | Command | What it does |
   | --- | --- |
   | `jd 11.11` | run jd; a target that is a folder changes into it |
   | `jd init [dir]` | start a system: a starter `system.ncl` (`--sys`, `--title`, `--jdex folder\|obsidian\|org\|bear`), jd's config, then scaffold |
   | `jd ids [10-19\|11]` | the IDs on disk, as a table |
   | `jd project` | the system, evaluated and checked |
   | `jd write-config` | write jd's `config.json` (won't replace a different one without `--force`) |
   | `jd scaffold` | create what's declared and missing; never deletes |
   | `jd check` | missing and undeclared folders, and extensions that don't match their declaration |

   The commands read `$env.JD_SYSTEM`, or `system.ncl` in the current
   folder; `--file` overrides both. `jd check` looks for `extensions/` next
   to that `system.ncl`.

   The jd package carries both layers: `share/johnnydecimal/nickel/` holds
   the contracts and `share/johnnydecimal/nu/` holds `jd.nu`, which finds
   the contracts beside it. So a system outside this repository gets the
   ones that match its jd.
3. **Extensions inside jd.** `pkgs/jd/jd.nix` adds one line to jd that
   loads every `*.sh` in the folder given to `jd.withExtensions` before jd
   runs a command, plus any in `~/.config/johnnydecimal/ext/`. `jd_wrap FN`
   wraps one of jd's functions and `jd_command NAME FN` adds a command (see
   `pkgs/jd/jd-ext.sh`). The shell's jd has the example's two:
   `example/extensions/stats.sh` adds `jd stats`, and `autocommit.sh`
   commits the JDex after `jd new` when `JD_AUTOCOMMIT=1`. Work-package
   adapters go in `extensions/adapters/{tasks,notes}/`, and JDex stores in
   `extensions/adapters/jdex/`. Declare each
   extension in the `system.ncl` next to it.

   `jd.withExtensions` checks the extensions when it builds jd, and the
   build fails if one wraps a function jd doesn't define (or two wrap the
   same one), adds one of jd's own commands or the same command twice, or
   is an adapter that lacks a function jd calls. Other flakes can use the
   overlay: `pkgs.jd.withExtensions ./dir`.
4. **Organist.** `organist/` is the same development shell defined in
   Nickel with [Organist](https://github.com/nickel-lang/organist)
   (`cd organist && nix develop`; Organist writes `nickel.lock.ncl` into the
   current folder). It's a flake of its own, and it takes jd and its
   extensions from the root flake through a `path:..` input, so nothing is
   copied. Its shell sets the same variables as the root one.

Files must be tracked by git for the flakes to see them.

## Upgrading jd

The package turns off jd's daily check for a newer version, and `jd update`
can't work, because the Nix store copy isn't a git clone. Change the tag in
the `jd-src` input in `flake.nix` instead (the package reads jd's version
from its source), then:

```sh
nix flake update jd-src                        # lock the new tag
nix run .#generate                             # rewrite nickel/generated/ from it
(cd organist && nix flake update johninunix)   # Organist's copy of the lock
nix flake check                                # everything below, against it
```

The package carries two patches to jd. `jdex-store.patch` is the JDex
store above. `wp-numbers.patch` fixes a jd 5.0.1 bug: in a new system the
third work package fails, because the first one creates the folder
`W0003 Templates for area W0000-9999` and the third is numbered W0003.
With the patch, jd steps over W0003 and W0009, the templates and the
archive. `system.ncl` also sets `workPackages.firstNumber` to 11 for
every system, so your first work package is W0011, as the Johnny.Decimal
docs advise, and W0000 to W0010 stay with the area. Set
`work_packages.first_number` to change it. jd's own default, used by a
config that doesn't come from `system.ncl`, is still W0001.

If a patch no longer applies, the build stops there. Rebase it on the new
tag: apply it in a checkout of the tag, fix what's rejected, and write it
out again with `git diff`.

## Checks

`nix flake check` checks that `nickel/generated/` is current and runs:

- `tests/test.nu`, on a copy of the files it uses. It tests every
  declaration in `tests/reject/` (each names the message it must fail with
  on its first line), the Nushell commands, and both example extensions.
- `tests/template.nu`, on a copy of the template, with the contracts and
  `jd.nu` from the package rather than from the repository.
- the build-time extension check on `tests/bad-extensions/`, which must
  report each message in its `expected.txt`.
- jd's own test suite (`test/run.sh`, in bash and zsh), on the patched
  jd, so the patch can't change what jd does with a Markdown or Bear JDex.
- `tests/org/`: the Org store through jd itself (`test.sh`); with real
  Emacs from nixpkgs, which parses what jd wrote, follows its links, passes
  `org-lint`, and is opened by `jdex` through `emacsclient` (`emacs.sh`);
  and `jd scaffold` and `jd check` with an Org JDex (`test.nu`).

`nix fmt` formats the Nix files.
