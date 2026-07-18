{ pkgs, secrets, inputs, config, ... }:
let
    rml-stressless-headless-source = pkgs.fetchurl {
        url = "https://codeberg.org/Raidriar/StresslessHeadless/releases/download/2.2.1/StresslessHeadless.dll";
        sha256 = "sha256-DipeSX1F604p/zMAyjggab6O2kOfnjibfdURAhSz4cU=";
    };
    rml-headless-tweaks-source = pkgs.fetchurl {
        url = "https://github.com/Cyberboss/HeadlessTweaks/releases/download/2.3.0-preview12/HeadlessTweaks.dll";
        sha256 = "sha256-jKnYc9eEX7T7wwhbcr2w5HAwD6FukZfnj3Fq4XKYZ64=";
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

    DominionsFlat = "<color=#0900BDFF>Dominion</color>'s Flat";
    DominionsFlatNoRtf = "Dominion's Flat";

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
            WorldScopedPermissions = {
                U-The-Honeybee = {
                    "${DominionsFlatNoRtf}" = "Moderator";
                };
                U-Charizmare = {
                    "${DominionsFlatNoRtf}" = "Moderator";
                };
                U-hartofstone = {
                    "${DominionsFlatNoRtf}" = "Moderator";
                };
                U-Cloud-Jumper = {
                    OutCast = "Moderator";
                };
                # Seyfert
                U-1iHTvyAEdSi = {
                    OutCast = "Moderator";
                };
            };
            DisableInteractivePrompt = true;
        };
    };

    stressless-config = jsonFormat.generate "StresslessHeadless.json" {
        version = "1.0.0";
        values = {
            #RunAudioWaveformTexture = false;
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
    imports = [
        inputs.resonite-headless.nixosModules.default
        inputs.resonite-dominion.nixosModules.default
    ];

    sops.secrets.resonite.owner = config.services.resonite-headless.username;

    services = {
        resonite-dominion = {
            enable = true;
            shutdown-seconds = 600;
        };
        resonite-headless = {
            enable = true;
            steam-username = secrets.steam.username;
            steam-password = secrets.steam.password;
            headless-code = secrets.resonite.headless-code;
            enable-rml = true;
            disable-ready-notify = true;
            auto-update-interval = "5m";
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
                loginCredential = secrets.resonite.username;
                loginPassword = secrets.resonite.password;
                allowedUrlHosts = [ "ws://localhost:24444" ];
                startWorlds = [
                    {
                        "$schema" = "https://raw.githubusercontent.com/Yellow-Dog-Man/JSONSchemas/main/schemas/HeadlessConfig.schema.json";
                        sessionName = DominionsFlat;
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
                    {
                        "$schema" = "https://raw.githubusercontent.com/Yellow-Dog-Man/JSONSchemas/main/schemas/HeadlessConfig.schema.json";
                        sessionName = "OutCast";
                        customSessionId = "U-1nPiX9NfQQ4:OutCast";
                        accessLevel = "RegisteredUsers";
                        description = "World by WispoWoo, Ported to Resonite by Seyfert & Cloud_Jumper, Headless provided by Dominion.";
                        hideFromPublicListing = false;
                        tags = [ ];
                        loadWorldUrl = "resrec:///G-1nmN4fjhq9g/R-019f161a-6d7c-77a1-809a-fe40fcca0da9";
                        defaultUserRoles = {
                            Dominion = "Admin";
                            Seyfert = "Admin";
                            Cloud_Jumper = "Admin";
                            kittysquirrel = "Builder";
                        };
                        autoInviteUsernames = [ ];
                        inviteRequestHandlerUsernames = [
                            "Seyfert"
                        ];
                        autoInviteMessage = "OutCast Online";
                        idleRestartInterval = 14400;
                        saveOnExit = false;
                        autoSleep = true;
                        enableResoniteLink = false;
                    }
                ];
            };
        };
    };
}
