{ config, pkgs, globals, lib, ... }:
let
  domain = "git.${globals.tld}";
  secrets = config.secrets.gitea;
  backup-location = config.services.gitea.dump.file;
in {
  imports = [
    ./modules/backups.nix
    ./modules/cloudflared.nix
    ./modules/postgres.nix
    ./modules/secrets
  ];

  services = {
    cloudflared.tunnels.primary-tunnel.ingress.${domain} =
      "http://localhost:${config.services.gitea.settings.server.HTTP_PORT}";
    gitea = {
      enable = true;
      database = {
        createDatabase = true;
        type = "postgres";
        passwordFile = secrets.databasePassword.path;
      };
      dump.enable = true;
      lfs.enable = true;
      settings = {
        log.ROOT_PATH = "/var/log/gitea";
        service.DISABLE_REGISTRATION = true;
      };
    };
    gitea-actions-runner.instances.primary = {
      enable = true;
      tokenFile = secrets.runnerToken.path;
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
      rm -rf ${backup-location}
    '');
  };
}
