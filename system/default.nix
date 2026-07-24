{ pkgs, globals, config, ... }:
let
  secrets = config.secrets.nix;
  update-script = pkgs.writeShellScriptBin "update-system" ''
    set -xeuo pipefail

    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root or with sudo."
        exit 1
    fi

    nix flake update --flake /etc/nixos
    nixos-rebuild switch
  '';
  secrets-leak-script = pkgs.writeShellScriptBin "secrets-leak" ''
    set -xeuo pipefail

    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root or with sudo."
        exit 1
    fi

    nix-collect-garbage -d

    journalctl --rotate
    journalctl --vacuum-time=1s
    rm -rf /var/log/journal/*
    rm -rf /run/log/journal/*
    systemctl restart systemd-journald
  '';
in {
  imports = [
    ./state-version.nix
    ./users

    ./bluesky.nix
    ./croc.nix
    ./jellyfin.nix
    ./resonite.nix
    ./samba.nix
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

  environment.systemPackages = [
    update-script
    secrets-leak-script
    inputs.nix-fast-build.packages.${pkgs.system}.default
  ];

  systemd.services."getty@tty1".enable = true;

  services = {
    xserver.enable = false;
    openssh.enable = true;
  };

  nixpkgs.overlays = [
    (final: prev: {
      inherit (prev.lixPackageSets.stable)
        nixpkgs-review nix-eval-jobs nix-fast-build colmena;
    })
  ];

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
