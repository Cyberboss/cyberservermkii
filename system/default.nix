{ pkgs, lib, stdenv, globals, inputs, config, ... }:
let
  secrets = config.secrets.nix;
  update-script = pkgs.writeShellScriptBin "update-system" ''
    
        set -euxo pipefail
    
        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root or with sudo."
            exit 1
        fi
    
        nix flake update --flake ${globals.flake-path}
        nixos-rebuild switch
        cp ${globals.flake-path}/flake.lock ${globals.flake-lock-backup-path}
  '';
  build-script = pkgs.writeShellScriptBin "build-system" ''
    
        set -euxo pipefail
    
        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root or with sudo."
            exit 1
        fi
    
        nix flake update --flake ${globals.flake-path}
        nixos-rebuild build
  '';
  secrets-leak-script = pkgs.writeShellScriptBin "secrets-leak" ''
    
        set -euxo pipefail
    
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
    ./forgejo.nix
    ./jellyfin.nix
    ./motd.nix
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
    build-script
    update-script
    secrets-leak-script
    pkgs.google-authenticator
  ];

  systemd.services."getty@tty1".enable = true;

  services = {
    xserver.enable = false;
    openssh = {
      enable = true;
      settings = {
        KbdInteractiveAuthentication = true;
        AuthenticationMethods = "publickey,keyboard-interactive";
      };
    };
    fail2ban = {
      enable = true;
      maxretry = 5;
      bantime-increment.enable = true;
      ignoreIP = [ "192.168.0.0/16" ];
    };
  };

  security.pam.services.sshd.googleAuthenticator = {
    enable = true;
    allowNullOTP = true;
  };

  nixpkgs.overlays = lib.mkIf globals.use-lix [
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
    package = lib.mkIf globals.use-lix pkgs.lixPackageSets.stable.lix;
    settings.experimental-features = if globals.use-lix then [
      "nix-command"
      "flakes"
    ] else [
      "nix-command"
      "flakes"
      "ca-derivations"
    ];
    extraOptions = ''
      
            !include ${secrets.github_token_include.path}
    '';
  };
}
