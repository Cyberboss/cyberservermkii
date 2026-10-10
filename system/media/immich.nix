{ config, globals, ... }:
let
  domain = "immich.${globals.tld}";
  service-name = "immich";
in {
  imports = [ ../modules/cloudflared.nix ../modules/backups ];

  users.users.${service-name} = {
    isSystemUser = true;
    createHome = true;
    group = service-name;
    extraGroups = [ globals.media-group ];
  };

  services = {
    "${service-name}" = {
      enable = true;
      mediaLocation = globals.immich-root;
      openFirewall = true;
      accelerationDevices = null;
    };
    cloudflared.tunnels.primary-tunnel.ingress = {
      "${domain}" = "http://localhost:${toString config.services.immich.port}";
    };
  };
}
