{ lib, pkgs, config, ... }:
let
  backup-location = config.services.postgresqlBackup.location;
  delete-postgres-backups = lib.getExe
    (pkgs.writeShellScriptBin "delete-postgres-backup.sh" ''
      set -euxo pipefail
      echo "Removing Postgres backups..."

      shopt -s dotglob
      rm -rf ${config.services.postgresqlBackup.location}/*
    '');
in {
  imports = [ ./backups.nix ];

  services = {
    postgresql = {
      enable = true;
      enableTCPIP = true;
    };
    postgresqlBackup = {
      enable = true;
      compression = "none";
    };
  };

  systemd.services.postgresqlBackup.startAt = lib.mkForce [ ];

  backups.postgresql = {
    pre = lib.getExe (pkgs.writeShellScriptBin "backup-postgres.sh" ''
      set -euxo pipefail

      ${delete-postgres-backups}

      echo "Creating Postgres backup..."
      systemctl start postgresqlBackup
    '');
    paths = [ backup-location ];
    post = delete-postgres-backups;
  };
}
