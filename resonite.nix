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
    rml-resonance-source = pkgs.fetchurl {
        url = "https://github.com/SeyfertGames/Resonance/releases/download/v2.0.0/Resonance.dll";
        sha256 = "sha256-RMe0XEoUu4wsjRmq6CV/WREU/kqs72qWbO/mvyXqjNo=";

    };

    rml-stressless-headless = "${pkgs.runCommand "StresslessHeadless.dll" { } ''
        mkdir -p $out/bin
        cp ${rml-stressless-headless-source} $out/bin/StresslessHeadless.dll
    ''}/bin/StresslessHeadless.dll";

    rml-headless-tweaks = "${pkgs.runCommand "HeadlessTweaks.dll" { } ''
        mkdir -p $out/bin
        cp ${rml-headless-tweaks-source} $out/bin/HeadlessTweaks.dll
    ''}/bin/HeadlessTweaks.dll";

    rml-resonance = "${pkgs.runCommand "Resonance.dll" { } ''
        mkdir -p $out/bin
        cp ${rml-headless-tweaks-source} $out/bin/Resonance.dll
    ''}/bin/Resonance.dll";

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
                U-The-Honeybee = "Moderator";
                U-Charizmare = "Moderator";
                U-hartofstone = "Moderator";
            };
            DisableInteractivePrompt = true;
        };
    };

    stressless-config = jsonFormat.generate "StresslessHeadless.json" {
        version = "1.0.0";
        values = {
            RunAudioWaveformTexture = false;
        };
    };

    tweaks-config-json = pkgs.runCommand "copy-tweaks" {} ''
        mkdir -p $out/etc
        cp ${tweaks-config} $out/etc/HeadlessTweaks.json
    '';

    stressless-config-json = pkgs.runCommand "copy-tweaks" {} ''
        mkdir -p $out/etc
        cp ${stressless-config} $out/etc/StresslessHeadless.json
    '';
in
{
    services.resonite-dominion.enable = true;
    services.resonite-headless = {
        enable = true;
        steam-username = secrets.steam-username;
        steam-password = secrets.steam-password;
        headless-code = secrets.resonite-headless-code;
        enable-rml = true;
        rml-mods = [
            rml-stressless-headless
            rml-headless-tweaks
            rml-resonance
        ];
        rml-configs = [
            "${tweaks-config-json}/etc/HeadlessTweaks.json"
            "${stressless-config-json}/etc/StresslessHeadless.json"
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
                    loadWorldUrl = "resrec:///G-1nmN4fjhq9g/R-019ea2c0-0b13-704d-8890-b28d22b80757";
                    defaultUserRoles = {
                        Charizmare = "Admin";
                        Dominion = "Admin";
                        HamoCorp = "Builder";
                        "The Honeybee" = "Admin";
                        hartofstone = "Admin";
                        GrandpaVape = "Builder";
                        "ItsAPuddin" = "Builder";
                        Jinxtiest = "Builder";
                        Seyfert = "Builder";
                        Shywizz = "Builder";
                        SvenTheRedPanda = "Builder";
                        VirisTheDragon = "Builder";
                        Water = "Builder";
                        Zandario = "Builder";
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

    systemd.services"${service-name}".serviceConfig.ExecStop = "${resonite-dominion}/bin/resonite-dominion-ctl stop";
}
