{ config, pkgs, globals, lib, inputs, ... }:
let
  domain = "git.${globals.tld}";
  mirror-domain = "git-mirror.${globals.tld}";
  secrets = config.secrets.forgejo;
  backup-location = config.services.forgejo.dump.backupDir;
  local-service-url = "http://localhost:${toString local-service-port}";

  local-service-port = config.services.forgejo.settings.server.HTTP_PORT;
  local-mirror-url =
    "http://localhost:${toString config.services.gitea-mirror.port}";
  mirror-enabled = config.services.gitea-mirror.enable;
  delete-forgejo-backups = lib.getExe
    (pkgs.writeShellScriptBin "delete-forgejo-backup.sh" ''
      set -euxo pipefail
      echo "Removing Forgejo backups..."

      shopt -s dotglob
      rm -rf ${backup-location}/*
    '');
in {
  imports = [
    ./modules/backups.nix
    ./modules/cloudflared.nix
    ./modules/docker.nix
    ./modules/postgres.nix
    ./modules/secrets

    inputs.gitea-mirror.nixosModules.default
  ];

  networking.firewall.allowedTCPPorts = [ local-service-port ];

  services = {
    cloudflared.tunnels.primary-tunnel.ingress = {
      "${domain}" = local-service-url;
      "${mirror-domain}" = lib.mkIf mirror-enabled local-mirror-url;
    };

    forgejo = {
      enable = true;

      database = {
        createDatabase = true;
        type = "postgres";
      };

      dump = {
        enable = true;
        type = "tar";
        file = "forgejo.dmp --skip-log"; # psycho argument injection
      };

      lfs.enable = true;

      settings = {
        actions = {
          ENABLED = true;
          DEFAULT_ACTIONS_URL = "github";
        };
        log.ROOT_PATH = "/var/log/forgejo";
        service.DISABLE_REGISTRATION = true;
        session.COOKIE_SECURE = true;
        server = {
          ROOT_URL = "https://${domain}";
          HTTP_PORT = 3002;
          SSH_PORT = lib.head config.services.openssh.ports;
        };
      };
    };

    gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.local = {
        enable = true;
        name = "Local";
        tokenFile = secrets.runnerEnvironment.path;
        url = local-service-url;
        labels = [ "ubuntu-latest:docker://node:18-bullseye" ];
      };
    };

    gitea-mirror = {
      enable = true;

      # Perfect chronological order
      mirrorIssueConcurrency = 1;
      mirrorPullRequestConcurrency = 1;

      environmentFile = secrets.mirrorEnvironment.path;
    };
  };

  systemd = {
    services.forgejo.serviceConfig.LogDirectory = "forgejo";
    timers.forgejo-dump.wantedBy = lib.mkForce [ ];
  };

  backups = {
    forgejo = {
      pre = lib.getExe (pkgs.writeShellScriptBin "backup-forgejo.sh" ''
        set -euxo pipefail

        ${delete-forgejo-backups}

        echo "Creating Forgejo backup..."
        systemctl start forgejo-dump
        ${
          lib.getExe pkgs.gnutar
        } -xf ${backup-location}/forgejo.dmp.tar -C ${backup-location}
        rm ${backup-location}/forgejo.dmp.tar
        rm ${backup-location}/forgejo-db.sql
      '');
      paths = [ backup-location ];
      post = delete-forgejo-backups;
    };
    gitea-mirror = lib.mkIf mirror-enabled {
      pre = lib.getExe (pkgs.writeShellScriptBin "stop-gitea-mirror.sh" ''
        set -euxo pipefail

        echo "Stopping Gitea Mirror..."
        systemctl stop gitea-mirror
      '');
      paths = [ config.services.gitea-mirror.dataDir ];
      post = lib.getExe (pkgs.writeShellScriptBin "start-gitea-mirror.sh" ''
        set -euxo pipefail

        echo "Starting Gitea Mirror..."
        systemctl start gitea-mirror
      '');
    };
  };
}
