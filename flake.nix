{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
        resonite-headless.url = "github:Cyberboss/resonite-headless-nix";
    };
    outputs = inputs@{ self, nixpkgs, inputs, ... }:
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
                    hardware-configuration
                    ./configuration.nix
                    ./state-version.nix
                ];
            };
        };
    };
}
