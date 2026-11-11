{
  description = "A Nix-flake-based Johnny Decimal development environment";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # unstable Nixpkgs

    # jd's source, at a release tag. To upgrade, change the tag, then run
    # `nix flake update jd-src` and `nix run .#generate`.
    jd-src = {
      url = "git+https://github.com/johnnydecimal/cli.johnnydecimal.com?ref=refs/tags/v5.0.1&shallow=1";
      flake = false;
    };
  };

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
      overlays.default = final: prev: {
        jd = final.callPackage ./pkgs/jd/jd.nix { src = inputs.jd-src; };
      };

      # `nix flake init -t github:bahiamovementcenter/Johninunix`: a repository
      # for your own system, with this one as an input
      templates.default = {
        path = ./templates/default;
        description = "Your own Johnny.Decimal system: system.ncl, extensions/ and a shell with jd";
        welcomeText = ''
          Your system is in system.ncl. Set its root and JDex to your folders,
          then: git add -A, nix develop, nu, use jd.nu, jd check.
        '';
      };

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

      # `nix run .#generate` rewrites nickel/generated/ after you change jd-src
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

          # jd's own test suite, run against the package's source, with this
          # repository's patches applied. Covers Markdown and Bear JDexes.
          upstream =
            pkgs.runCommand "jd-upstream-tests"
              {
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.zsh
                  pkgs.bash
                  pkgs.git
                  pkgs.fish
                ];
              }
              ''
                export HOME=$TMPDIR
                cp -r --no-preserve=mode ${pkgs.jd}/share/johnnydecimal/cli jd && cd jd
                chmod +x bin/* test/run.sh
                patchShebangs bin test
                JD_TEST_SHELLS="${pkgs.bash}/bin/bash ${pkgs.zsh}/bin/zsh" sh test/run.sh > $TMPDIR/log 2>&1 || { grep -A6 "^not ok" $TMPDIR/log; tail -3 $TMPDIR/log; exit 1; }
                tail -5 $TMPDIR/log
                touch $out
              '';

          # The Org JDex store, end to end (tests/org/test.sh)
          # tests/org/emacs.sh: the same store with real Emacs, which parses
          # what jd wrote, follows its links, and is opened by `jdex`
          org-emacs =
            pkgs.runCommand "jd-org-emacs-test"
              {
                nativeBuildInputs = [
                  pkgs.jd
                  pkgs.emacs-nox
                ];
              }
              ''
                mkdir work && cd work
                bash ${./tests/org/emacs.sh}
                touch $out
              '';

          # tests/org/test.nu: jd.nu's scaffold and check, with the same file
          org =
            pkgs.runCommand "jd-org-test"
              {
                nativeBuildInputs = [
                  pkgs.jd
                  pkgs.nickel
                  pkgs.nushell
                ];
                NICKEL_IMPORT_PATH = "${pkgs.jd}/share/johnnydecimal/nickel";
                NU_LIB_DIRS = "${pkgs.jd}/share/johnnydecimal/nu";
              }
              ''
                export HOME=$TMPDIR
                mkdir sh && (cd sh && bash ${./tests/org/test.sh})
                cp -r --no-preserve=mode ${./tests/org} nu && cd nu
                nu test.nu
                nu test.nu init
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

          # The template's system, through the contracts and jd.nu in the
          # package, with the template's extensions built in
          template =
            let
              jd = pkgs.jd.withExtensions ./templates/default/extensions;
            in
            pkgs.runCommand "jd-template-test"
              {
                nativeBuildInputs = [
                  jd
                  pkgs.nickel
                  pkgs.nushell
                ];
                NICKEL_IMPORT_PATH = "${jd}/share/johnnydecimal/nickel";
                NU_LIB_DIRS = "${jd}/share/johnnydecimal/nu";
              }
              ''
                export HOME=$TMPDIR
                cp -r --no-preserve=mode ${./templates/default} system && cd system
                nu ${./tests/template.nu}
                touch $out
              '';

          # tests/bad-extensions/ has one of each problem that building
          # jd.withExtensions must refuse, and expected.txt the messages. The package is built without its
          # check here, so that the check can be run and its messages read.
          bad-extensions =
            let
              dir = ./tests/bad-extensions;
              unchecked = (pkgs.jd.withExtensions dir).overrideAttrs { doInstallCheck = false; };
            in
            pkgs.runCommand "jd-bad-extensions-test" { } ''
              if bash ${./pkgs/jd/check-extensions.sh} ${unchecked} ${dir} 2> err; then
                echo "check-extensions.sh accepted tests/bad-extensions" >&2
                exit 1
              fi
              cat err
              while IFS= read -r line; do
                grep -qF -- "$line" err || { echo "expected: $line" >&2; exit 1; }
              done < ${dir}/expected.txt
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
              pkgs.nushell # `use jd.nu` in nu
              self.formatter.${system}
            ];

            # jd reads its config from JD_CONFIG, and jdd from the JDD_* variables.
            # Write the config from system.ncl with `jd write-config` in nu.
            env = {
              JDD_LOG_LEVEL = "info";
            };

            # Everything is relative to the repository's top folder, so the
            # shell is the same from any folder inside it. Nickel and nu find
            # the contracts and jd.nu in the repository, so changes to them
            # take effect at once (the package has its own copies).
            shellHook = ''
              _jd_top=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              export NICKEL_IMPORT_PATH="$_jd_top/nickel''${NICKEL_IMPORT_PATH:+:$NICKEL_IMPORT_PATH}"
              export NU_LIB_DIRS="$_jd_top/nu''${NU_LIB_DIRS:+:$NU_LIB_DIRS}"
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
