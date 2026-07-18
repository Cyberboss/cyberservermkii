{ inputs, ... }:
{
    imports = [
        inputs.sops-nix.nixosModules.sops
    ];

    sops = {
        defaultSopsFile = ./../secrets.yml;
        defaultSopsFormat = "yaml";
        age.keyFile = "/etc/nixos/age.txt";
    };
}
