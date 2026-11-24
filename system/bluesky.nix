{ config, pkgs, globals, lib, ... }:
let
  service-port = 3000;
  pds-subdomain = "bsky-pds";
  secrets = config.secrets.bluesky;
  service-name = "bluesky-pds";
in {
  imports = [ ./modules/cloudflared.nix ./modules/backups ];

  services = {
    "${service-name}" = {
      enable = !globals.backup-restore-safety-key;
      goat.enable = true;
      pdsadmin.enable = true;
      environmentFiles = [ secrets.environment.path ];
      settings = {
        PDS_HOSTNAME = "${pds-subdomain}.${globals.tld}";
        PORT = service-port;
      };
    };
  };

  cloudflared.${pds-subdomain}.port = service-port;

  systemd.services.bluesky-pds.restartTriggers = secrets.restartTriggers;

  backups.bluesky = {
    restore-services =
      lib.mkIf (!globals.backup-restore-safety-key) [ service-name ];
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
