{ pkgs, lib, config, ... }:
let
  backup-location = "/var/cache/mariadb.sql";
  delete-mariadb-backups = lib.getExe
    (pkgs.writeShellScriptBin "delete-mariadb-backup.sh" ''
      set -euxo pipefail
      echo "Removing MariaDB backups..."

      rm -f ${backup-location}
    '');
in {
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

  backups.mariadb = {
    pre = lib.getExe (pkgs.writeShellScriptBin "backup-mariadb.sh" ''
      set -euxo pipefail

      ${delete-mariadb-backups}

      echo "Creating MariaDB backup..."
      ${pkgs.mariadb}/bin/mysqldump -u root -p --all-databases > ${backup-location}
    '');
    paths = [ backup-location ];
    post = delete-mariadb-backups;
  };
}
