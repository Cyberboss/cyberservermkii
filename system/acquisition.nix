{ lib, pkgs, config, ... }:
let
  makeServarrConfig = service-name: {
    services.${service-name} = {
      enable = true;
      settings = {
        postgres.host = "127.0.0.1";
        postgres.logdb = "${service-name}-log";
        postgres.maindb = "${service-name}-main";
        postgres.password = config.services.${service-name}.user;
        # Not secure if the port is exposed
        postgres.user = config.services.${service-name}.user;
        server.port = config.services.postgresql.settings.port;
      };
    };

    backups.${service-name} = {
      pre = lib.getExe (pkgs.writeShellScriptBin "stop-${service-name}.sh" ''
        set -euxo pipefail
        systemctl stop ${service-name}
      '');
      paths = [ config.services.radarr.dataDir ];
      pre = lib.getExe (pkgs.writeShellScriptBin "start-${service-name}.sh" ''
        set -euxo pipefail
        systemctl start ${service-name}
      '');
    };
  };
in {
  imports = [ ./modules/backups.nix ./modules/postgres.nix ];
  config = (makeServarrConfig "radarr");
}
