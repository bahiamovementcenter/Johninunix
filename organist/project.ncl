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

# jd with the extensions in ../extensions, from the root flake (the
# `johninunix` input). This folder holds only the Organist files: system.ncl,
# nickel/ and nu/ are read from the root through JD_SYSTEM.
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

      # Run from organist/, so the project is the folder above
      hooks.jd_paths = m%"
        export JD_SYSTEM="${JD_SYSTEM:-$(cd .. && pwd)/system.ncl}"
        export JD_CONFIG="${JD_CONFIG:-$(cd .. && pwd)/.jd/config.json}"
        export JDD_ROOT="${JDD_ROOT:-$(cd .. && pwd)}"
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
