{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-fast-build = {
      url = "github:Mic92/nix-fast-build";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    resonite-headless.url = "github:Cyberboss/resonite-headless-nix";
    resonite-dominion.url = "github:Cyberboss/resonite-dominion";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, ... }:
    let globals = import ./system/globals.nix;
    in {
      build-system = hardware-configuration: {
        "${globals.hostName}" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = { inherit inputs globals; };

          modules = [ hardware-configuration ./system ];
        };
      };
    };
}
