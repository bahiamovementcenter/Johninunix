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

# jd isn't in Nixpkgs: build it from jd.nix, with the extensions in
# extensions/. The files shared with the plain flake (jd.nix, nickel/, nu/,
# extensions/, system.ncl) are copies, kept identical by the
# organist-copies check in ../flake.nix.
let jd_with_extensions =
  organist.nix.derivation.CallNix
  & {
    function = "{ callPackage, jd, extensions }: (callPackage jd { }).withExtensions extensions",
    args = {
      callPackage = organist.import_nix "nixpkgs#callPackage",
      jd = organist.nix.builtins.import_file "jd.nix",
      extensions = organist.nix.builtins.import_file "extensions",
    },
  }
in

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

      hooks.jd_paths = m%"
        export JD_CONFIG="${JD_CONFIG:-$PWD/.jd/config.json}"
        export JDD_ROOT="${JDD_ROOT:-$PWD}"
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
