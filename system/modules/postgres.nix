{ lib, pkgs, config, globals, ... }:
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
  imports = [ ./backups ];

  services = {
    postgresql = {
      enable = true;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        # TYPE  DATABASE        USER            ADDRESS                 METHOD
        local   all             all                                     trust
        host    all             all             127.0.0.1/32            trust
        host    all             all             ::1/128                 trust

        host    all             dominion             ${globals.subnet-16}.0.0/16          scram-sha-256
      '';

      settings.listen_addresses = "*";
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
