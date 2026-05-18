{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    };
    outputs = inputs@{ self, nixpkgs, ... }:
    let
        localHostName = "cyberservermkii";
    in {
        hostName = localHostName;
        buildSystem = { secrets, ... }: {
            imports = [ 
                (import ./configuration.nix  {
                    hostName = localHostName;
                })
            ];
        };
    }
}
