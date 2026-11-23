{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    resonite-headless.url = "github:Cyberboss/resonite-headless-nix";
    resonite-dominion.url = "github:Cyberboss/resonite-dominion";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gitea-mirror = {
      url =
        "github:Cyberboss/gitea-mirror/DominionFixes"; # Unpin me after https://github.com/RayLabsHQ/gitea-mirror/pull/350 is merged
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, ... }: {
    build-system = hardware-configuration: backup-restore-configuration:
      let
        globals = (import ./system/globals.nix {
          inherit backup-restore-configuration;
        });
      in {
        "${globals.hostName}" = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = { inherit inputs globals; };

          modules = [ hardware-configuration ./system ];
        };
      };
  };
}
