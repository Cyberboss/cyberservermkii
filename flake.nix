{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    };
    outputs = inputs@{ config, lib, ... }:
    let
        hostName = "cyberservermkii";
    in {
        hostName = hostName;
        buildSystem = local-config: secrets: {
            nixosConfigurations.${hostName} = lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                    local-config
                    (import ./configuration.nix  {
                        inherit config lib;
                        hostName = hostName;
                        secrets = secrets;
                    })
                ];
            };
        };
    };
}
