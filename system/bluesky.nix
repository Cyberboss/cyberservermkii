{ config, pkgs, globals, lib, ... }:
let
  service-port = 3000;
  domain = "bsky.${globals.tld}";
  pds-domain = "bsky-pds.${globals.tld}";
  secrets = config.secrets.bluesky;
  service-name = "bluesky-pds";
in {
  imports = [ ./modules/cloudflared ./modules/backups ];

  services = {
    "${service-name}" = {
      enable = true;
      goat.enable = true;
      pdsadmin.enable = true;
      environmentFiles = [ secrets.environment.path ];
      settings = {
        PDS_HOSTNAME = pds-domain;
        PORT = service-port;
      };
    };
  };

  cloudflared.${pds-domain}.port = service-port;

  systemd.services.bluesky-pds.restartTriggers = secrets.restartTriggers;

  backups.bluesky = {
    restore-services = [ service-name ];
    pre = lib.getExe (pkgs.writeShellScriptBin "stop-bluesky-pds.sh" ''
      set -euxo pipefail

      systemctl stop bluesky-pds
    '');
    paths = [ config.services.bluesky-pds.settings.PDS_DATA_DIRECTORY ];
    post = lib.getExe (pkgs.writeShellScriptBin "start-bluesky-pds.sh" ''
      set -euxo pipefail

      systemctl start bluesky-pds
    '');
  };
}
