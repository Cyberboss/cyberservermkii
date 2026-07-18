{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        sops-nix = {
            url = "github:Mic92/sops-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        resonite-headless.url = "github:Cyberboss/resonite-headless-nix";
        resonite-dominion.url = "github:Cyberboss/resonite-dominion";
    };
    outputs = inputs@{ self, nixpkgs, ... }:
    let
        hostName = "cyberservermkii";
    in {
        build-system = hardware-configuration: secrets: {
            ${hostName} = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";

                specialArgs = {
                    inherit hostName secrets inputs;
                };

                modules = [
                    ./state-version.nix
                    hardware-configuration
                    ./configuration.nix
                    ./bluesky.nix
                    ./jellyfin.nix
                    ./resonite.nix
                    ./samba.nix
                ];
            };
        };
    };
}
