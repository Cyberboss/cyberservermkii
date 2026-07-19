{ config, globals, lib, ... }:
let
  service-port = "3000";
  pds-domain = "bsky-pds.${globals.tld}";
  secrets = config.secrets.bluesky;
in {
  imports = [ ./modules/cloudflared.nix ./modules/backups.nix ];

  services = {
    bluesky-pds = {
      enable = true;
      goat.enable = true;
      pdsadmin.enable = true;
      environmentFiles = [ secrets.environment.path ];
      settings.PDS_HOSTNAME = domain;
    };

    cloudflared.tunnels.primary-tunnel.ingress.${pds-domain} =
      "http://localhost:${service-port}";
  };

  systemd.services.bluesky-pds.restartTriggers = secrets.restartTriggers;

  backups.bluesky.paths =
    [ config.services.bluesky-pds.settings.PDS_DATA_DIRECTORY ];
}
