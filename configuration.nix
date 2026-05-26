{ pkgs, hostName, secrets, ... }:
let
    update-script = pkgs.writeShellScriptBin "update-system" ''
        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root or with sudo."
            exit 1
        fi
        nix flake update --flake /etc/nixos && nixos-rebuild switch
    '';

    rml-stressless-headless = pkgs.fetchurl {
        url = "https://codeberg.org/Raidriar/StresslessHeadless/releases/download/2.2.1/StresslessHeadless.dll";
        sha256 = "sha256-DipeSX1F604p/zMAyjggab6O2kOfnjibfdURAhSz4cU=";
    };
    rml-headless-tweaks = pkgs.fetchurl {
        url = "https://github.com/New-Project-Final-Final-WIP/HeadlessTweaks/releases/download/v2.2.0/HeadlessTweaks.dll";
        sha256 = "sha256-TDr1o+FDoxecv8btP6QYc9H7KXEC8ySma9JEfgwnplo=";
    };
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
        resonite-headless = {
            enable = true;
            steam-username = secrets.steam-username;
            steam-password = secrets.steam-password;
            headless-code = secrets.resonite-headless-code;
            enable-rml = true;
            rml-mods = [
                rml-stressless-headless
                rml-headless-tweaks
            ];
            config-json = {
                loginCredential = secrets.resonite-username;
                loginPassword = secrets.resonite-password;
                startWorlds = [
                    {
                        "$schema" = "https://raw.githubusercontent.com/Yellow-Dog-Man/JSONSchemas/main/schemas/HeadlessConfig.schema.json";
                        sessionName = "Dominion's Flat";
                        customSessionId = "U-1nPiX9NfQQ4:DominionsFlat";
                        accessLevel = "ContactsPlus";
                        description = "Dominion's personal hideaway. Come say hello!";
                        hideFromPublicListing = false;
                        tags = [
                            "after"
                            "glow"
                            "cozy"
                            "cyberpunk"
                            "home" 
                            "apartment" 
                            "social" 
                            "afterglow"
                            "after glow"
                            "dominion"
                            "flat" 
                            "memes" 
                            "workshop"
                        ];
                        loadWorldUrl = "resrec:///U-1nPiX9NfQQ4/R-019e5c2f-d6a6-76c6-af08-5333624a2b0a";
                        defaultUserRoles = {
                            Dominion = "Admin";
                        };
                        autoInviteUsernames = [
                            "Dominion"
                        ];
                        inviteRequestHandlerUsernames = [
                            "Dominion"
                        ];
                        autoInviteMessage = "Astral connection re-established.";
                        idleRestartInterval = 14400;
                        saveOnExit = false;
                        autoSleep = true;
                        enableResoniteLink = false;
                    }
                ];
            };
        };
    };
    
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
            access-tokens = [
                "github.com=${secrets.github-token}"
            ];
        };
    };
}
