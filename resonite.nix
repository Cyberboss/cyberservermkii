{ pkgs, secrets, ... }:
let
    rml-stressless-headless = "${(pkgs.fetchurl rec {
        url = "https://codeberg.org/Raidriar/StresslessHeadless/releases/download/2.2.1/StresslessHeadless.dll";
        sha256 = "sha256-DipeSX1F604p/zMAyjggab6O2kOfnjibfdURAhSz4cU=";
        
        downloadToTemp = true;
        postFetch = "install -D $downloadedFile $out/" + builtins.baseNameOf url;
    })}/bin/StresslessHeadless.dll";
    rml-headless-tweaks = "${(pkgs.fetchurl rec {
        url = "https://github.com/New-Project-Final-Final-WIP/HeadlessTweaks/releases/download/v2.2.0/HeadlessTweaks.dll";
        sha256 = "sha256-TDr1o+FDoxecv8btP6QYc9H7KXEC8ySma9JEfgwnplo=";

        downloadToTemp = true;
        postFetch = "install -D $downloadedFile $out/" + builtins.baseNameOf url;
    })}/bin/HeadlessTweaks.dll";

    jsonFormat = pkgs.formats.json {};
    
    tweaks-config = jsonFormat.generate "HeadlessTweaks.json" {
        PermissionLevels = {
            U-1jLFy9ehNjs = "Owner";
        };
    };

    tweaks-config-json = pkgs.runCommand "copy-tweaks" {} ''
        mkdir -p $out/etc
        cp ${tweaks-config} $out/etc/HeadlessTweaks.json
    '';
in
{
    services.resonite-headless = {
        enable = true;
        steam-username = secrets.steam-username;
        steam-password = secrets.steam-password;
        headless-code = secrets.resonite-headless-code;
        enable-rml = true;
        rml-mods = [
            rml-stressless-headless
            rml-headless-tweaks
        ];
        rml-configs = [
            "${tweaks-config-json}/etc/HeadlessTweaks.json"
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
}
