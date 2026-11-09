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
jd write-config      # jd's config.json, from system.ncl
jd scaffold          # create the folders and JDex notes system.ncl declares
jd check             # compare system.ncl with the disk and with extensions/
```

The example `system.ncl` uses this folder as the system's root and `jdex/`
as its JDex. Point `root` and `jdex.path` at your real folders before you
scaffold. `jdex` follows jd's config version 2: `{ path = "..." }` for a
folder of notes, plus `app = "obsidian"` (and `vault`) for an Obsidian
vault, or `{ app = "bear" }` for a JDex in Bear.

## The layers

Each layer works without the ones after it.

1. **Your system in Nickel.** `system.ncl` declares your systems, areas,
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
   | `jd project` | `system.ncl`, evaluated and checked |
   | `jd write-config` | write jd's `config.json` (won't replace a different one without `--force`) |
   | `jd scaffold` | create what's declared and missing; never deletes |
   | `jd check` | missing and undeclared folders, and extensions that don't match their declaration |

3. **Extensions inside jd.** `jd.nix` adds one line to jd that loads every
   `extensions/*.sh` before jd runs a command, plus any in
   `~/.config/johnnydecimal/ext/`. `jd_wrap FN` wraps one of jd's functions
   and `jd_command NAME FN` adds a command (see `jd-ext.sh`). The examples:
   `stats.sh` adds `jd stats`, and `autocommit.sh` commits the JDex after
   `jd new` when `JD_AUTOCOMMIT=1`. Work-package adapters go in
   `extensions/adapters/{tasks,notes}/`. Declare each extension in
   `system.ncl`.

   Other flakes can use the overlay: `pkgs.jd.withExtensions ./dir`.

4. **Organist.** `organist/` is the same development shell defined in
   Nickel with [Organist](https://github.com/nickel-lang/organist)
   (`cd organist && nix develop`; Organist writes `nickel.lock.ncl` into the
   current folder). It's a flake of its own, so it carries copies
   of `jd.nix`, `jd-ext.sh`, `system.ncl`, `extensions/`, `nickel/` and
   `nu/`. Edit them at the root and copy them over: `nix flake check` fails
   while they differ.

Files must be tracked by git for the flakes to see them.

## Upgrading jd

The package turns off jd's daily check for a newer version, and `jd update`
can't work, because the Nix store copy isn't a git clone. Change `version`,
`rev` and `hash` in `jd.nix` instead, then:

```sh
nix run .#generate   # rewrite nickel/generated/ from the new source
nix flake check      # contracts, extensions and nu/test.nu against it
```

Copy `jd.nix` and `nickel/generated/` into `organist/` as well.

## Checks

`nix flake check` checks that `nickel/generated/` is current, that the
`organist/` copies match, and runs `nu/test.nu`, which tests the contracts,
the Nushell commands and both extensions on a scratch copy of the repo.
