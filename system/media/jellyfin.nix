{ lib, config, globals, pkgs, ... }:
let
  service-name = "jellyfin";
  secrets = config.secrets.jellyfin;
  data-directory = config.services.${service-name}.dataDir;
  backups-directory = "${data-directory}/data/backups";
  libraries-directory = globals.media-root;
  seerr-service-name = "seerr";
  service-port = 8096;
  seerr-port = config.services.seerr.port;
  jellyroller = lib.getExe (pkgs.rustPlatform.buildRustPackage rec {
    pname = "jellyroller";
    version = "1.2.1";

    meta.mainProgram = pname;
    src = pkgs.fetchFromGitHub {
      owner = "LSchallot";
      repo = "JellyRoller";
      rev = "v${version}";
      hash = "sha256-nvM7qE7RajUCBmSo05pvVLkZ2RpLhGUuEGG4/Sht38A=";
    };

    cargoHash = "sha256-KABhOiPWpLY/y5LfgFwk+vqBdwurrFRy+dVJ29DZzqU=";
  });

  jellyroller-config-attrs = {
    status = "configured";
    comfy = true;
    server_url = "http://localhost:${toString service-port}";
    os = "linux";
    token = "apiKey";
  };
  tomlFormat = pkgs.formats.toml { };
  jellyroller-config-filename = "jellyroller.toml";
  jellyroller-config =
    tomlFormat.generate jellyroller-config-filename jellyroller-config-attrs;

  delete-jellyfin-backups = lib.getExe
    (pkgs.writeShellScriptBin "delete-jellyfin-backup.sh" ''
      set -euxo pipefail

      shopt -s dotglob
      rm -rf ${backups-directory}/*
    '');
in {
  imports = [ ../modules/cloudflared ../modules/backups ];

  cloudflared = {
    "${service-name}".port = service-port;
    "${seerr-service-name}".port = seerr-port;
  };

  services = {
    "${service-name}" = {
      enable = true;
      user = service-name;
      group = service-name;
      logDir = "/var/log/${service-name}";
      openFirewall = true;
    };
    "${seerr-service-name}".enable = true;
  };

  users.users.${service-name} = {
    isSystemUser = true;
    createHome = true;
    group = service-name;
    extraGroups = [ globals.media-group ];
  };

  backups = {
    jellyfin = {
      restore-services = [ service-name ];
      pre = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''
        set -euxo pipefail

        ${delete-jellyfin-backups}

        mkdir -p $RUNTIME_DIRECTORY/jellyroller
        cp ${jellyroller-config} $RUNTIME_DIRECTORY/jellyroller/${jellyroller-config-filename}

        set +x
        echo "api_key = \"$(cat ${secrets.api_key.path})\"" >> $RUNTIME_DIRECTORY/jellyroller/${jellyroller-config-filename}
        set -x

        export XDG_CONFIG_HOME=$RUNTIME_DIRECTORY
        systemctl start jellyfin
        ${jellyroller} create-backup

        ZIP_PATH="${backups-directory}/$(ls -1 "${backups-directory}" | head -n 1)"

        ${lib.getExe pkgs.unzip} -q "$ZIP_PATH" -d ${backups-directory}
        rm $ZIP_PATH
      '');
      paths = [ data-directory ];
      post = delete-jellyfin-backups;
    };
    seerr = {
      restore-services = [ seerr-service-name ];
      pre = lib.getExe (pkgs.writeShellScriptBin "backup-seerr-pre.sh" ''
        set -euxo pipefail

        systemctl stop seerr
      '');
      paths = [ config.services.seerr.configDir ];
      post = lib.getExe (pkgs.writeShellScriptBin "backup-seerr-post.sh" ''
        set -euxo pipefail

        systemctl start seerr
      '');
    };
  };
}
