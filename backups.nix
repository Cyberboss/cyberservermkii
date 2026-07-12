{ config, ... }:
let
in
{
    options.backups =  lib.mkOption {
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
}
