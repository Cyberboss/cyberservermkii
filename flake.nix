{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    };
    outputs = inputs@{ self, nixpkgs, ... }:
    let
        hostName = "cyberservermkii";
    in {
        hostName = hostName;
        buildSystem = local-config: secrets: {
            nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                    local-config
                    (import ./configuration.nix  {
                        self = self;
                        hostName = hostName;
                        secrets = secrets;
                    })
                ];
            };
        };
    };
}
