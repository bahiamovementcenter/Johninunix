{
  description = "My Johnny.Decimal system";

  inputs = {
    # jd, its Nickel contracts and its Nushell module, at matching versions.
    # `nix flake update johninunix` brings a newer jd.
    johninunix.url = "github:bahiamovementcenter/Johninunix";
    nixpkgs.follows = "johninunix/nixpkgs";
  };

  outputs =
    { johninunix, nixpkgs, ... }:
    let
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ johninunix.overlays.default ];
            }
          )
        );
    in
    {
      # jd with your extensions. The build fails if one doesn't fit this jd.
      packages = forEachSystem (pkgs: {
        default = pkgs.jd.withExtensions ./extensions;
      });

      # `nix flake check`: Nickel checks system.ncl against the contracts
      checks = forEachSystem (pkgs: {
        system = pkgs.runCommand "system-ncl" { nativeBuildInputs = [ pkgs.nickel ]; } ''
          nickel export --import-path ${pkgs.jd}/share/johnnydecimal/nickel ${./system.ncl} > $out
        '';
      });

      devShells = forEachSystem (
        pkgs:
        let
          jd = pkgs.jd.withExtensions ./extensions;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              jd
              pkgs.jdd # files new documents into the right folder by name
              pkgs.nickel # evaluates system.ncl
              pkgs.nushell # `use jd.nu` in nu
            ];

            # `import "johnny-decimal.ncl"` in Nickel, `use jd.nu` in nu
            NICKEL_IMPORT_PATH = "${jd}/share/johnnydecimal/nickel";
            NU_LIB_DIRS = "${jd}/share/johnnydecimal/nu";

            # jd.nu reads JD_SYSTEM; jd keeps its config where it always does
            # (`jd paths config`), so it works outside this shell too
            shellHook = ''
              export JD_SYSTEM="''${JD_SYSTEM:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)/system.ncl}"
            '';
          };
        }
      );

      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);
    };
}
