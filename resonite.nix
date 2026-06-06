{ pkgs, secrets, ... }:
let
    rml-stressless-headless-source = pkgs.fetchurl {
        url = "https://codeberg.org/Raidriar/StresslessHeadless/releases/download/2.2.1/StresslessHeadless.dll";
        sha256 = "sha256-DipeSX1F604p/zMAyjggab6O2kOfnjibfdURAhSz4cU=";
    };
    rml-headless-tweaks-source = pkgs.fetchurl {
        url = "https://github.com/Cyberboss/HeadlessTweaks/releases/download/2.3.0-preview1/HeadlessTweaks.dll";
        sha256 = "sha256-Ztcr2xGi5LN1iTyeFMW0/wl0w0qSjmmZLlzmtMgCslY=";
    };

    rml-stressless-headless = "${pkgs.runCommand "StresslessHeadless.dll" { } ''
        mkdir -p $out/bin
        cp ${rml-stressless-headless-source} $out/bin/StresslessHeadless.dll
    ''}/bin/StresslessHeadless.dll";

    rml-headless-tweaks = "${pkgs.runCommand "HeadlessTweaks.dll" { } ''
        mkdir -p $out/bin
        cp ${rml-headless-tweaks-source} $out/bin/HeadlessTweaks.dll
    ''}/bin/HeadlessTweaks.dll";

    jsonFormat = pkgs.formats.json {};
    
    tweaks-config = jsonFormat.generate "HeadlessTweaks.json" {
        version = "1.0.0";
        values = {
            UseDiscordWebhook = false;
            DiscordWebhookID = null;
            DiscordWebhookKey = null;
            DiscordWebhookUsername = null;
            DiscordWebhookAvatar = null;
            DiscordWebhookThreadID = null;
            DiscordWebhookEnabledEvents = {
                EngineStart = false;
            };
            AutoInviteOptOut = [];
            WorldRoster = {};
            SessionIdToName = {};
            DefaultSessionAccessLevel = {};
            DiscordWebhookEventColors = {};
            DiscordLinkToSession = true;
            PermissionLevels = {
                U-1jLFy9ehNjs = "Owner";
            };
            DisableInteractivePrompt = true;
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
                    sessionName = "<color=#0900BDFF>Dominion</color>'s Flat";
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
                        Seyfert = "Builder";
                        Charizmare = "Builder";
                        HamoCorp = "Builder";
                        Shywizz = "Builder";
                        "The Honeybee" = "Builder";
                        Zandario = "Builder";
                        "Grandpa Vape" = "Builder";
                        hartofstone = "Builder";
                        "ItsAPuddin" = "Builder";
                        SvenTheRedPanda = "Builder";
                    };
                    autoInviteUsernames = [ ];
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



