{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    resonite-headless.url = "github:Cyberboss/resonite-headless-nix";
    resonite-dominion.url = "github:Cyberboss/resonite-dominion";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gitea-mirror.url =
      "github:RayLabsHQ/gitea-mirror/1bca7df5ab5a41c570f5989e5d83be297b7338b8";
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
