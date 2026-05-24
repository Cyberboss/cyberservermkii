{ config, lib, pkgs, hostName, secrets, ... }:
let
    update-script = pkgs.writeShellScriptBin "update-system" ''
        nix flake update /etc/nixos
        nixos-rebuild switch
    '';
in
{
    boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
    };

    networking = {
        hostName = hostName;
        networkmanager.enable = true;
    };

    time.timeZone = "America/Toronto";

    i18n.defaultLocale = "en_CA.UTF-8";

    users.users.dominion = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNL86w85bS/+5aDj8fe4gZ2obLiiRn+1lXhWA2tX7Jt eddsa-key-20241023"
        ];
    };

    environment.systemPackages = [ update-script ];

    services.openssh.enable = true;
    
    nixpkgs.overlays = [ (final: prev: {
        inherit (prev.lixPackageSets.stable)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena;
    }) ];

    nix = {
        package = pkgs.lixPackageSets.stable.lix;
        settings = {
            experimental-features = [ "nix-command" "flakes" ];
            accesstokens = [
                "github.com=${secrets.github-token}"
            ];
        };
    };
}
