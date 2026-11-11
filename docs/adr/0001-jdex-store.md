# ADR-0001: Make the JDex store pluggable, and add an Org store

**Status:** Proposed (prototype in this branch)
**Date:** 2026-11-11
**Deciders:** Ash

## Context

We want jd to work with an Org-mode JDex: notes as Org headings, opened in
Emacs, created by `jd new id` and `jd new wp`.

In jd 5.0.1 an adapter can't do that. Adapters only run during
`jd new wp`, and there are two kinds:

- **tasks** (`things`, `none`): create a project in a task app and write
  links into it.
- **notes** (`obsidian`, `bear`, `none`): print two link strings. They never
  read or write a note.

The work of keeping the JDex, which is finding, opening, numbering and
writing notes, is in jd's core. That core knows two layouts. A folder of
`.md` files (nested or flat) is read and written by `lib/jdex.sh` and
`lib/new.sh`. Bear is read and written by `lib/bear.sh`, and is chosen by
name in 18 places: `case $_JD_JDEX_KIND in … bear)` and
`if [ "$_JD_JDEX_KIND" = bear ]` in `jdex.sh` (3), `nav.sh` (3) and
`new.sh` (12). Any other app with a path is treated as a Markdown folder,
and an app without a path is "unsupported".

So Bear already proves that jd needs a second kind of JDex. It just isn't
pluggable.

Constraints:

- jd is never forked (README). Changes to jd's own files must be small,
  must fail loudly when upstream moves, and should be shaped so upstream
  could take them.
- Behaviour with a Markdown or Bear JDex must not change. jd's own suite
  (`test/run.sh`: 2759 cases in bash and zsh, including Bear through a
  stub `bearcli`) is the referee.
- Must work in bash 3.2 and zsh, with only jq, like the rest of jd.

## Decision

Add a third adapter kind, a **JDex store**: `lib/adapters/jdex/<app>.sh`.
When the system's `jdex.app` names a store, jd loads it and calls it
wherever it called Bear by name. Bear becomes the first store. Org is the
second, and lives in this repository.

The interface takes what Bear's code already does and gives each piece a
name:

| Function | Does | Bear |
| --- | --- | --- |
| `jd_jdex_load` | read the JDex once per shell; fail with a message | `_jd_bear_load` |
| `jd_jdex_find WHAT ARGS` | `area`/`category`/`id`/`wp`/`search…`, printing `locator⇥display⇥name` | `_jd_bear_find` |
| `jd_jdex_open LOC DISPLAY` | open one match | `_jd_bear_open` |
| `jd_jdex_open_app` | `jdex` with no target | `_jd_bear_open_app` |
| `jd_jdex_titles CONTAINER [wp]` | note titles in a container, for the next number | `_jd_bear_titles` |
| `jd_jdex_category C` | the container for category C | find + strip `bear:tag:` |
| `jd_jdex_wp_area` | the work package container, or the one the first note creates | `_jd_bear_wp_areas` + default |
| `jd_jdex_where NAME CONTAINER` | the `note …` line `jd new` prints | `Bear: name, #tag#` |
| `jd_jdex_write NAME CONTAINER` | create the note from stdin; print its link | `_jd_bear_create` |

Two words do the abstracting. A **container** is where notes go (a tag in
Bear, a heading path in Org). A **locator** is a match that jd hands back
to the store (`bear:note:<id>`, `org:<line>`). Neither one means anything
to jd. A store may also set `_JD_JDEX_LABEL`, `_JD_JDEX_UNIT` and
`_JD_JDEX_EXT` (its template extension, so Org reads `ID template.org`).

Markdown folders stay built in rather than becoming `jdex/markdown.sh`.
Moving them is the larger half of the change and isn't needed to unblock
Org (see Options).

### How it ships

- `pkgs/jd/jdex-store.patch` (6 files, +232 −73) is applied to jd's
  source with `applyPatches`. It adds `jdex/none.sh` (the reference list,
  never loaded), `jdex/bear.sh` (one-line wrappers over `lib/bear.sh`),
  `_jd_jdex_store` and `_jd_jdex_ext`, the 18 call sites, and a "JDex
  stores" section in `lib/adapters/README.md`. It is written as the
  upstream PR would be.
- `pkgs/jd/adapters/{jdex,notes}/org.sh` and
  `pkgs/jd/templates/Work package template.org` are copied into the
  patched source, so they're built in, and `nickel/generated/adapters.ncl`
  lists `jdex = { builtin = [bear, none, org], functions = […] }`.
- The PR #4 build check (`check-extensions.sh`) accepts drop-in stores in
  `extensions/adapters/jdex/` without changes, because the kind now has a
  `none.sh`.

### The Org store

One Org file is the JDex (`jdex = { app = "org", path = "jdex.org" }`).
Level-1 headings are areas, level 2 categories (or work packages under
`* W0000…`), and level 3 IDs. Headings are matched by their leading number,
like folders, and tags are ignored. `jd new` appends a heading at the end
of its container with a `CUSTOM_ID` (`11.21`, `w0001`), and template
headings are demoted below it. `notes/org.sh` links with
`file:…::#w0001` and `[[*11.11 Title]]`. Opening uses
`$JD_ORG_EDITOR +LINE FILE`, or `emacsclient -n`. On our side,
`jd scaffold` writes the declared outline into the file and `jd check`
reads it.

## Options Considered

### Option A: Store interface as a patch, shaped for upstream (chosen)

| Dimension | Assessment |
| --- | --- |
| Complexity | Medium: 18 mechanical call-site changes, 9 functions |
| Upgrade risk | Patch fails to apply → build stops; jd's suite runs in `nix flake check` |
| Behaviour change | None measured: 2759/2759 upstream cases pass, the same as unpatched |
| Upstream fit | Same "one file per app" rule as `lib/adapters/README.md` |

**Pros:** It's small, Bear becomes an ordinary client of the interface, any
app can be added as a file, and it works as a drop-in extension.
**Cons:** It's a patch we carry until upstream takes it. Markdown is
still special-cased.

### Option B: Wrap jd's functions from an extension (`jd_wrap`)

| Dimension | Assessment |
| --- | --- |
| Complexity | High: most branches sit inside `_jd_new_id` and `_jd_new_wp` (100+ lines each) |
| Upgrade risk | High: we'd copy whole functions, and drift silently within them |

**Pros:** No patch.
**Cons:** Wrapping only works at function boundaries. We'd fork the two
largest functions in jd, which is a fork in all but name.

### Option C: Also move Markdown into `jdex/markdown.sh`

| Dimension | Assessment |
| --- | --- |
| Complexity | High: nested/flat lookup, folder notes, `.md` paths in `new.sh`, `_jd_nav_make_id`, move journal |
| Payoff | Uniform core; a store for "Markdown with another extension" for free |

**Pros:** The cleanest end state.
**Cons:** It roughly triples the patch, and it touches the paths that most
people use. It's better proposed upstream once A is accepted.

### Option D: Org links only (no store)

`notes/org.sh` and a `tasks/org.sh` over a Markdown JDex. This works with
stock jd, but the notes stay Markdown, so it isn't an Org backend.

## Trade-off Analysis

The choice comes down to carrying a patch (A) versus forking functions
(B). A's patch is a set of targeted call-site swaps, which are easy to
re-apply and loud when they break. B's wrappers would silently fall behind
upstream. C is A plus a large, risky change to the Markdown path. Its value
is consistency rather than capability, so it waits for upstream interest.
D doesn't meet the goal.

## Consequences

- **Easier:** any JDex app is one file: Org, a single Markdown index, Logseq,
  a database. Bear's code paths in the core collapse to `store`.
- **Easier:** a drop-in store in `extensions/adapters/jdex/` gets the same
  build-time function check as tasks and notes adapters.
- **Harder:** a jd upgrade can now fail at the patch step, and has to be
  rebased (README: Upgrading jd).
- **Revisit:**
  - Propose the patch upstream. Drop it here if it's accepted.
  - Option C (Markdown as a store).
  - `jd move` with a store. It already moves only folders for Bear, so
    it's no worse, but an Org store could rename the heading too.
  - Org with one file per note (org-roam style), as a second Org store.
  - `org-protocol://` links as an option in `notes/org.sh`.
  - `jd scaffold` inserts missing headings but never reorders them.

## Action Items

1. [x] `jdex-store.patch`: the interface, Bear as a store, README section
2. [x] `nix flake check` runs jd's own suite on the patched jd
3. [x] `jdex/org.sh`, `notes/org.sh`, Org work package template
4. [x] `jd.nu`: scaffold and check with an Org JDex; Nickel docs
5. [x] Tests: `tests/org/test.sh` (jd), `tests/org/test.nu` (jd.nu)
6. [x] Real Emacs (nixpkgs `emacs-nox`) in `nix flake check`: `tests/org/emacs.sh`
7. [ ] Ash: try it on your own Org file
8. [ ] Decide whether to open the upstream PR
