{ config, pkgs, globals, lib, ... }:
let
  service-port = 3000;
  domain = "bsky.${globals.tld}";
  pds-domain = "bsky-pds.${globals.tld}";
  secrets = config.secrets.bluesky;
in {
  imports = [ ./modules/cloudflared.nix ./modules/backups ];

  services = {
    bluesky-pds = {
      enable = true;
      package = pkgs.bluesky-pds.override { nodejs_24 = pkgs.nodejs_22; };
      goat.enable = true;
      pdsadmin.enable = true;
      environmentFiles = [ secrets.environment.path ];
      settings = {
        PDS_HOSTNAME = pds-domain;
        PORT = service-port;
      };
    };

    cloudflared.tunnels.primary-tunnel.ingress.${pds-domain} =
      "http://localhost:${toString service-port}";
  };

  systemd.services.bluesky-pds.restartTriggers = secrets.restartTriggers;

  backups.bluesky = {
    pre = lib.getExe (pkgs.writeShellScriptBin "stop-bluesky-pds.sh" ''
      set -euxo pipefail

      echo "Stopping Bluesky PDS..."
      systemctl stop bluesky-pds
    '');
    paths = [ config.services.bluesky-pds.settings.PDS_DATA_DIRECTORY ];
    post = lib.getExe (pkgs.writeShellScriptBin "start-bluesky-pds.sh" ''
      set -euxo pipefail

      echo "Starting Bluesky PDS..."
      systemctl start bluesky-pds
    '');
  };
}
