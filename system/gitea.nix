{ config, pkgs, globals, lib, ... }:
let
  domain = "git.${globals.tld}";
  secrets = config.secrets.gitea;
  backup-location = config.services.gitea.dump.backupDir;
  local-service-url = "http://localhost:${
      toString config.services.gitea.settings.server.HTTP_PORT
    }";
in {
  imports = [
    ./modules/backups.nix
    ./modules/cloudflared.nix
    ./modules/docker.nix
    ./modules/postgres.nix
    ./modules/secrets
  ];

  services = {
    cloudflared.tunnels.primary-tunnel.ingress.${domain} = local-service-url;
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
        server.ROOT_URL = "https://${domain}";
      };
    };
    gitea-actions-runner.instances.local = {
      enable = true;
      name = "Local";
      tokenFile = secrets.runnerToken.path;
      url = local-service-url;
      labels = [ "ubuntu-latest:docker://node:18-bullseye" ];
    };
  };

  systemd = {
    services.gitea.serviceConfig.LogDirectory = "gitea";
    timers.gitea-dump.wantedBy = lib.mkForce [ ];
  };

  backups.gitea = {
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
}
