{ config, globals, lib, pkgs, ... }:
let
  domain = "immich.${globals.tld}";
  service-name = "immich";
  upload-location = subdirectory:
    "${config.services.${service-name}.mediaLocation}/${subdirectory}";
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
    restore-services = [ "system-immich.slice" ];
    pre = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''
      set -euxo pipefail

      systemctl stop system-immich.slice
    '');
    paths = [
      # https://docs.immich.app/administration/backup-and-restore/#filesystem
      (upload-location "library")
      (upload-location "upload")
      (upload-location "profiles")
    ];
    post = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''
      set -euxo pipefail

      systemctl start system-immich.slice
    '');
  };
}
