{
  description = "A Nix-flake-based Johnny Decimal development environment";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # unstable Nixpkgs

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            };
          }
        );
    in
    {
      # `pkgs.jd` for other flakes; `pkgs.jd.withExtensions ./dir` adds extensions
      overlays.default = final: prev: { jd = final.callPackage ./pkgs/jd/jd.nix { }; };

      packages = forEachSupportedSystem (
        { pkgs, ... }:
        {
          # jd with the example system's extensions
          default = pkgs.jd.withExtensions ./example/extensions;
          inherit (pkgs) jd;

          # Facts about the pinned jd, as Nickel (see scripts/generate.nu)
          generated = pkgs.runCommand "jd-generated" { nativeBuildInputs = [ pkgs.nushell ]; } ''
            nu ${./scripts/generate.nu} ${pkgs.jd.src} $out ${pkgs.jd.version} \
              ${pkgs.jd.upstream.owner} ${pkgs.jd.upstream.repo} ${pkgs.jd.upstream.rev}
          '';
        }
      );

      # `nix run .#generate` rewrites nickel/generated/ after you change pkgs/jd/jd.nix
      apps = forEachSupportedSystem (
        { pkgs, system }:
        {
          generate = {
            type = "app";
            program = pkgs.lib.getExe (
              pkgs.writeShellScriptBin "generate" ''
                rm -rf nickel/generated
                cp -r --no-preserve=mode ${self.packages.${system}.generated} nickel/generated
              ''
            );
          };
        }
      );

      checks = forEachSupportedSystem (
        { pkgs, system }:
        {
          generated = pkgs.runCommand "jd-generated-is-current" { } ''
            diff -r ${self.packages.${system}.generated} ${./nickel/generated} \
              || { echo 'nickel/generated/ is out of date: run nix run .#generate' >&2; exit 1; }
            touch $out
          '';

          # Runs tests/test.nu on a copy of the files it uses
          system =
            pkgs.runCommand "jd-system-test"
              {
                nativeBuildInputs = [
                  self.packages.${system}.default
                  pkgs.nickel
                  pkgs.nushell
                  pkgs.git
                ];
                src = pkgs.lib.fileset.toSource {
                  root = ./.;
                  fileset = pkgs.lib.fileset.unions [
                    ./example
                    ./nickel
                    ./nu
                    ./organist
                    ./tests
                  ];
                };
              }
              ''
                export HOME=$TMPDIR
                cp -r --no-preserve=mode $src work && cd work
                nu tests/test.nu
                touch $out
              '';
        }
      );

      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          default = pkgs.mkShellNoCC {
            packages = [
              self.packages.${system}.default # jd: find, create and move IDs
              pkgs.jdd # Johnny Decimal daemon: files new documents into the right folder by name
              pkgs.nickel # evaluates system.ncl
              pkgs.nushell # nu/jd.nu: `use nu/jd.nu` in nu
              self.formatter.${system}
            ];

            # jd reads its config from JD_CONFIG, and jdd from the JDD_* variables.
            # Write the config from system.ncl with `jd write-config` in nu.
            env = {
              JDD_LOG_LEVEL = "info";
            };

            # Everything is relative to the repository's top folder, so the
            # shell is the same from any folder inside it
            shellHook = ''
              _jd_top=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              export JD_SYSTEM="''${JD_SYSTEM:-$_jd_top/example/system.ncl}"
              export JD_CONFIG="''${JD_CONFIG:-$_jd_top/example/.jd/config.json}"
              export JDD_ROOT="''${JDD_ROOT:-$_jd_top/example}"
              unset _jd_top
            '';
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-tree);
    };
}
