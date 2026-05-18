{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    };
    outputs = inputs@{ self, nixpkgs, pkgs, lib, ... }:
    let
        localHostName = "cyberservermkii";
    in {
        hostName = localHostName;
        buildSystem = { secrets, config, ... }: nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ 
                (import ./configuration.nix  {
                    inherit pkgs config lib;
                    hostName = localHostName;
                })
            ];
        };
    };
}
