{ config, globals, lib, pkgs, ... }:
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
      host = "";
      accelerationDevices = null;
    };
    cloudflared.tunnels.primary-tunnel.ingress = {
      "${domain}" = "http://localhost:${toString config.services.immich.port}";
    };
  };

  backups.immich = {
    pre = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''
      set -euxo pipefail

      systemctl stop immich-machine-learning
      systemctl stop immich-server
    '');
    post = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''
      set -euxo pipefail

      systemctl start immich-machine-learning
      systemctl start immich-server
    '');
  };
}
