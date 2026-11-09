let inputs = import "./nickel.lock.ncl" in
let organist = inputs.organist in

# `mkShell` adds each package's `dev` output (headers, pkg-config files) to the
# shell, while Organist adds the default output. This restores the former.
let with_dev_outputs =
  std.record.map (fun _name drv =>
    organist.nix.derivation.CallNix
    & {
      function = "{ package }: package.dev or package",
      args.package = drv,
    }
  )
in

# jd with the example system's extensions, from the root flake (the
# `johninunix` input). This folder holds only the Organist files: the
# system, nickel/ and nu/ are read from the root through JD_SYSTEM.
let jd_with_extensions = organist.import_nix "johninunix#default" in

organist.OrganistExpression
& {
  Schema,
  config | Schema = {
    shells = organist.shells.Bash,

    shells.build.packages = {},

    shells.dev = {
      # No C compiler in the shell, like `mkShellNoCC`
      env.stdenv = organist.import_nix "nixpkgs#stdenvNoCC",

      # jd reads its config from JD_CONFIG, and jdd from the JDD_* variables.
      # Write the config from system.ncl with `jd write-config` in nu.
      env.JDD_LOG_LEVEL = "info",

      # The same paths as the root flake's shell: relative to the
      # repository's top folder, from any folder inside it
      hooks.jd_paths = m%"
        _jd_top=$(git rev-parse --show-toplevel 2>/dev/null || (cd .. && pwd))
        export JD_SYSTEM="${JD_SYSTEM:-$_jd_top/example/system.ncl}"
        export JD_CONFIG="${JD_CONFIG:-$_jd_top/example/.jd/config.json}"
        export JDD_ROOT="${JDD_ROOT:-$_jd_top/example}"
        unset _jd_top
      "%,

      packages =
        with_dev_outputs {
          jd = jd_with_extensions, # find, create and move IDs
          jdd = organist.import_nix "nixpkgs#jdd", # files new documents into the right folder by name
          nickel = organist.import_nix "nixpkgs#nickel", # evaluates system.ncl
          nushell = organist.import_nix "nixpkgs#nushell", # nu/jd.nu: `use nu/jd.nu` in nu
          nixfmt = organist.import_nix "nixpkgs#nixfmt",
        },
    },
  },
}
  | organist.modules.T
