{ config, globals, lib, pkgs, ... }:
let
  service-name = "immich";
  upload-location = subdirectory:
    "${config.services.${service-name}.mediaLocation}/${subdirectory}";
  service-names =
    [ "${service-name}-server" "${service-name}-machine-learning" ];
  service-names-str = builtins.concatStringsSep " " service-names;
in {
  imports = [ ../modules/cloudflared ../modules/backups ];

  users.users.${service-name} = {
    isSystemUser = true;
    createHome = true;
    group = service-name;
    extraGroups = [ globals.media-group ];
  };

  services."${service-name}" = {
    enable = true;
    mediaLocation = globals.immich-root;
    openFirewall = true;
    host = "";
    accelerationDevices = null;
  };

  cloudflared.${service-name}.port = config.services.immich.port;

  backups.immich = {
    restore-services = service-names;
    pre = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''
      set -euxo pipefail

      systemctl stop ${service-names-str}
    '');
    paths = [
      # https://docs.immich.app/administration/backup-and-restore/#filesystem
      (upload-location "library")
      (upload-location "upload")
      (upload-location "profiles")
    ];
    post = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''
      set -euxo pipefail

      systemctl start ${service-names-str}
    '');
  };
}
