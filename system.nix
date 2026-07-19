{ pkgs, globals, config, ... }:
let
    secrets = config.secrets.nix;
    update-script = pkgs.writeShellScriptBin "update-system" ''
        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root or with sudo."
            exit 1
        fi
        nix flake update --flake /etc/nixos && nixos-rebuild switch
    '';
in
{
    imports = [
      ./users
    ];

    boot.loader = {
        systemd-boot = {
            configurationLimit = 3;
            enable = true;
        };
        efi.canTouchEfiVariables = true;
    };

    networking = {
        hostName = globals.hostName;
        networkmanager.enable = true;
    };

    time.timeZone = "America/Toronto";

    i18n.defaultLocale = "en_CA.UTF-8";

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
        settings.experimental-features = [ "nix-command" "flakes" ];
        extraOptions = ''
          !include ${secrets.github_token_include.path}
        '';
    };
}
