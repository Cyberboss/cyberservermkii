{ pkgs, lib, inputs, config, ... }:
let
  secrets = config.secrets.resonite;
  rml-stressless-headless = {
    name = "StresslessHeadless";
    src = pkgs.fetchFromCodeberg {
      owner = "Raidriar";
      repo = "StresslessHeadless";
      rev = "2.2.1";
      hash = "sha256-CWArSJLbkKEkmmZHVggqJtIxqsFeB0rd7V1SF8RGuoY=";
    };
    environment-statement = headless-path: "ResonitePath=${headless-path}/../";
  };
  rml-headless-tweaks = {
    name = "HeadlessTweaks";
    src = pkgs.fetchFromGitHub {
      owner = "Cyberboss";
      repo = "HeadlessTweaks";
      rev = "dfc0b299dcf26d4562ebd13f4b3c1e35f4a295d1";
      hash = "sha256-6dmSX9GXLAouit3FuVkihojoQjsLKYqRowzGJ+kiXlE=";
    };
  };
  rml-resonance = {
    name = "Resonance";
    src = pkgs.fetchFromGitHub {
      owner = "SeyfertGames";
      repo = "Resonance";
      rev = "0bafb250fab71306eef2a23357d6249025f645ba";
      hash = "sha256-tdmY/uPnPGSPY39UKqAaIzf8WLgb/DLNMo8257XDnTo=";
    };
    environment-statement = headless-path:
      "ResonitePath=${headless-path}/ NoMinVer=true";
  };
  rml-fastsync = {
    name = "FastSync";
    src = pkgs.fetchFromForgejo {
      domain = "codeberg.org";
      owner = "Raidriar";
      repo = "FastSync";
      rev = "1.1.0";
      hash = "sha256-677XO0AfvJqAdzlKuoWvduHVax+wPzprPRWFZ1xZF3Q=";
    };
  };

  quic-port-dominions-flat = 23845;
  quic-port-outcast = 23846;

  jsonFormat = pkgs.formats.json { };

  DominionsFlat = "<color=#0900BDFF>Dominion</color>'s Flat";
  DominionsFlatNoRtf = "Dominion's Flat";

  tweaks-config = jsonFormat.generate "HeadlessTweaks.json" {
    version = "1.0.0";
    values = {
      DiscordLinkToSession = false;
      PermissionLevels = { U-1jLFy9ehNjs = "Owner"; };
      WorldScopedPermissions = {
        U-The-Honeybee = { "${DominionsFlatNoRtf}" = "Moderator"; };
        U-Charizmare = { "${DominionsFlatNoRtf}" = "Moderator"; };
        U-hartofstone = { "${DominionsFlatNoRtf}" = "Moderator"; };
        U-Cloud-Jumper = { OutCast = "Moderator"; };
        # Seyfert
        U-1iHTvyAEdSi = { OutCast = "Moderator"; };
      };
      DisableInteractivePrompt = true;
    };
  };

  stressless-config = jsonFormat.generate "StresslessHeadless.json" {
    version = "1.0.0";
    values = { };
  };

  tweaks-config-json = pkgs.runCommand "copy-tweaks" { } ''
    mkdir -p $out/etc
    cp ${tweaks-config} $out/etc/HeadlessTweaks.json
  '';

  stressless-config-json = pkgs.runCommand "copy-tweaks" { } ''
    mkdir -p $out/etc
    cp ${stressless-config} $out/etc/StresslessHeadless.json
  '';

  update-reason-file-path = config.resonite-dominion.update-reason-file-path;
  pre-system-update-script =
    pkgs.writeShellScriptBin "resonite-pre-system-update-script.sh" ''
      set -euxo pipefail

      echo "Operating System Update" > "${update-reason-file-path}"
    '';
  post-system-update-script =
    pkgs.writeShellScriptBin "resonite-post-system-update-script.sh" ''
      set -euxo pipefail

      rm -f "${update-reason-file-path}"
    '';
in {
  imports = [
    ./modules/secrets
    ./modules/update-dependencies.nix
    ./modules/wan.nix

    inputs.resonite-headless.nixosModules.default
    inputs.resonite-dominion.nixosModules.default
  ];

  update-dependencies.resonite = {
    pre = lib.getExe pre-system-update-script;
    post = lib.getExe post-system-update-script;
  };

  secrets.resonite.owner = config.services.resonite-headless.username;

  systemd.services.resonite-headless.serviceConfig = {
    after = [ "update-wan-ip.service" ];
    requires = [ "update-wan-ip.service" ];
  };

  networking.firewall.allowedUDPPorts =
    [ quic-port-dominions-flat quic-port-outcast ];
  services = {
    resonite-dominion = {
      enable = true;
      shutdown-seconds = 600;
    };
    resonite-headless = {
      quic-wan-ip-file = config.wan-ip-file;
      depotdownloader-env-file = secrets.depotdownloader.path;
      enable-rml = true;
      disable-ready-notify = true;
      auto-update-interval = "5m";
      rml-mod-sources = [
        rml-stressless-headless
        rml-headless-tweaks
        rml-resonance
        rml-fastsync
      ];
      additional-restart-triggers = secrets.credentials.restartTriggers;
      rml-configs = [
        "${tweaks-config-json}/etc/HeadlessTweaks.json"
        "${stressless-config-json}/etc/StresslessHeadless.json"
      ];
      credentials-file = secrets.credentials.path;
      config-json = {
        allowedUrlHosts = [ "ws://localhost:24444" ];
        startWorlds = [
          {
            "$schema" =
              "https://raw.githubusercontent.com/Yellow-Dog-Man/JSONSchemas/main/schemas/HeadlessConfig.schema.json";
            sessionName = DominionsFlat;
            customSessionId = "U-1nPiX9NfQQ4:DominionsFlat";
            accessLevel = "ContactsPlus";
            description = "Dominion's personal hideaway. Come say hello!";
            forcePorts.quic = quic-port-dominions-flat;
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
              "quic"
            ];
            loadWorldUrl =
              "resrec:///G-1nmN4fjhq9g/R-019ea2c0-0b13-704d-8890-b28d22b80757";
            defaultUserRoles = {
              Charizmare = "Admin";
              Dominion = "Admin";
              HamoCorp = "Builder";
              "The Honeybee" = "Admin";
              hartofstone = "Admin";
              GrandpaVape = "Builder";
              "ItsAPuddin" = "Builder";
              Jinxtiest = "Builder";
              ManiaDeluxe = "Builder";
              Seyfert = "Builder";
              Shywizz = "Builder";
              SvenTheRedPanda = "Builder";
              VirisTheDragon = "Builder";
              Water = "Builder";
              Zandario = "Builder";
            };
            autoInviteUsernames = [ ];
            inviteRequestHandlerUsernames = [ "Dominion" ];
            autoInviteMessage = "Astral connection re-established.";
            idleRestartInterval = 14400;
            saveOnExit = false;
            autoSleep = true;
            enableResoniteLink = false;
          }
          {
            "$schema" =
              "https://raw.githubusercontent.com/Yellow-Dog-Man/JSONSchemas/main/schemas/HeadlessConfig.schema.json";
            sessionName = "OutCast";
            customSessionId = "U-1nPiX9NfQQ4:OutCast";
            accessLevel = "RegisteredUsers";
            description =
              "World by WispoWoo, Ported to Resonite by Seyfert & Cloud_Jumper, Headless provided by Dominion.";
            forcePorts.quic = quic-port-outcast;
            hideFromPublicListing = false;
            tags = [ "quic" ];
            loadWorldUrl =
              "resrec:///G-1nmN4fjhq9g/R-019f161a-6d7c-77a1-809a-fe40fcca0da9";
            defaultUserRoles = {
              Dominion = "Admin";
              Seyfert = "Admin";
              Cloud_Jumper = "Admin";
              kittysquirrel = "Builder";
            };
            autoInviteUsernames = [ ];
            inviteRequestHandlerUsernames = [ "Seyfert" ];
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
