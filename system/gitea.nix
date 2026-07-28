{ config, pkgs, globals, lib, inputs, ... }:
let
  domain = "git.${globals.tld}";
  mirror-domain = "git-mirror.${globals.tld}";
  secrets = config.secrets.gitea;
  backup-location = config.services.gitea.dump.backupDir;
  local-service-url = "http://localhost:${
      toString config.services.gitea.settings.server.HTTP_PORT
    }";
  local-mirror-url =
    "http://localhost:${toString config.services.gitea-mirror.port}";
in {
  imports = [
    ./modules/backups.nix
    ./modules/cloudflared.nix
    ./modules/docker.nix
    ./modules/postgres.nix
    ./modules/secrets

    inputs.gitea-mirror.nixosModules.default
  ];

  services = {
    cloudflared.tunnels.primary-tunnel.ingress = {
      "${domain}" = local-service-url;
      "${mirror-domain}" = local-mirror-url;
    };

    gitea = {
      enable = true;

      database = {
        createDatabase = true;
        type = "postgres";
      };

      dump = {
        enable = true;
        file = "gitea.dmp --skip-db --skip-log"; # psycho argument injection
      };

      lfs.enable = true;

      settings = {
        log.ROOT_PATH = "/var/log/gitea";
        service.DISABLE_REGISTRATION = true;
        session.COOKIE_SECURE = true;
        server = {
          ROOT_URL = "https://${domain}";
          HTTP_PORT = 3002;
        };
      };
    };

    gitea-actions-runner.instances.local = {
      enable = true;
      name = "Local";
      tokenFile = secrets.runnerEnvironment.path;
      url = local-service-url;
      labels = [ "ubuntu-latest:docker://node:18-bullseye" ];
    };

    gitea-mirror = {
      enable = true;
      openFirewall = true;

      # Perfect chronological order
      mirrorIssueConcurrency = 1;
      mirrorIssueConcurrency = 1;

      environmentFile = secrets.mirrorEnvironment.path;
    };
  };

  systemd = {
    services.gitea.serviceConfig.LogDirectory = "gitea";
    timers.gitea-dump.wantedBy = lib.mkForce [ ];
  };

  backups = {
    gitea = {
      pre = lib.getExe (pkgs.writeShellScriptBin "backup-gitea.sh" ''
        set -euxo pipefail

        echo "Creating Gitea backup..."
        systemctl start gitea-dump
      '');
      paths = [ backup-location ];
      post = lib.getExe (pkgs.writeShellScriptBin "delete-gitea-backup.sh" ''
        set -euxo pipefail
        echo "Removing Gitea backups..."

        shopt -s dotglob
        rm -rf ${backup-location}/*
      '');
    };
    gitea-mirror = {
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
