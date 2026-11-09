{
  description = "An Organist-based Johnny Decimal development environment";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # unstable Nixpkgs
    organist = {
      url = "github:nickel-lang/organist";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The repository root: jd with the example extensions, nickel/ and nu/
    johninunix = {
      url = "path:..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # The development shell is defined in project.ncl
  outputs =
    { organist, ... }@inputs:
    organist.flake.outputsFromNickel ./. inputs {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    };
}
