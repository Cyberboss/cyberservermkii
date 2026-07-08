{ pkgs, hostName, secrets, ... }:
let
    update-script = pkgs.writeShellScriptBin "update-system" ''
        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root or with sudo."
            exit 1
        fi
        nix flake update --flake /etc/nixos && nixos-rebuild switch
    '';
in
{
    boot.loader = {
        systemd-boot = {
            configurationLimit = 3;
            enable = true;
        };
        efi.canTouchEfiVariables = true;
    };

    networking = {
        hostName = hostName;
        networkmanager.enable = true;
    };

    time.timeZone = "America/Toronto";

    i18n.defaultLocale = "en_CA.UTF-8";

    users.users = {
        dominion = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNL86w85bS/+5aDj8fe4gZ2obLiiRn+1lXhWA2tX7Jt eddsa-key-20241023"
            ];
        };
        root.hashedPassword = "!";
    };

    environment.systemPackages = [ update-script ];
    
    systemd.services."getty@tty1".enable = true;

    services = {
        xserver.enable = false;
        openssh.enable = true;
    };
    
    nixpkgs.overlays = [ (final: prev: {
        inherit (prev.lixPackageSets.stable)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena;
    }) ];

    nix = {
        gc = {
            automatic = true;
            persistent = true;
            dates = "daily";
            options = "--delete-old";
        };
        package = pkgs.lixPackageSets.stable.lix;
        settings = {
            experimental-features = [ "nix-command" "flakes" ];
            #substitute = false;
            access-tokens = [
                "github.com=${secrets.github-token}"
            ];
        };
    };
}
