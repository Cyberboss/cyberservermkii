{ pkgs, lib, config, secrets, ... }:
let
    paths = lib.lists.uniqueStrings (lib.lists.flatten (builtins.attrValues config.backups));
    to-env-file = (file-name: attrset: pkgs.writeText file-name (
        pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (name: value: "${name}=${value}") attrset
        )
    ));
in
{
    options.backups = lib.mkOption {
      description = ''
        Backup specifications.
      '';
      type = lib.types.attrsOf (lib.types.listOf lib.types.nonEmptyStr);
      default = { };
      example = {
        some-service = [
            "/var/logs/some-service"
            "/home/some-service/data"
            "/some-service"
        ];
      };
    };

    config.services.restic.backups.primary = {
        initialize = true;
        paths = paths;
        timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
        };

        pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 6"
            "--keep-yearly 1"
        ];

        repository = secrets.restic.repository.address;
        passwordFile = "${pkgs.writeText "restic" secrets.restic.encryption-password}";
        repositoryFile = to-env-file "restic-env" secrets.restic.repository.config;
    };
}
