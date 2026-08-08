{ lib, config, globals, pkgs, ... }:
let
  service-name = "jellyfin";
  secrets = config.secrets.jellyfin;
  home-directory = "/home/${service-name}";
  data-directory = config.services.${service-name}.dataDir;
  backups-directory = "${data-directory}/data/backups";
  libraries-directory = "${home-directory}/libraries";
  domain = "${service-name}.${globals.tld}";
  seerr-domain = "seerr.${globals.tld}";
  service-port = "8096";
  local-url = "http://localhost:${service-port}";
  seerr-port = config.services.seerr.port;
  jellyroller = lib.getExe (pkgs.rustPlatform.buildRustPackage rec {
    pname = "jellyroller";
    version = "1.1.5";

    meta.mainProgram = pname;
    src = pkgs.fetchFromGitHub {
      owner = "LSchallot";
      repo = "JellyRoller";
      rev =
        "63bd89b4d885b72bc2af58516e60e848795c2e7f"; # v1.1.5 with fixed Cargo.lock
      hash = "sha256-BNq825zFfA9st7d1tU1f3wvpZbXD0OVhrFz++smNVr4=";
    };

    cargoHash = "sha256-Y1ZSLdorAhbrBHr/3GPhHObi2DBjf0FWiuPIznKVGyo=";
  });

  jellyroller-config-attrs = {
    status = "configured";
    comfy = true;
    server_url = local-url;
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
      echo "Removing Jellyfin backups..."
      shopt -s dotglob
      rm -rf ${backups-directory}/*
      echo "Done removing Jellyfin backups"
    '');
in {
  imports = [ ../modules/cloudflared.nix ../modules/backups ];

  services = {
    cloudflared.tunnels.primary-tunnel.ingress = {
      "${domain}" = local-url;
      "${seerr-domain}" = "http://localhost:${toString seerr-port}";
    };
    "${service-name}" = {
      enable = true;
      user = service-name;
      group = service-name;
      logDir = "/var/log/${service-name}";
    };
    seerr.enable = true;
  };

  users = {
    groups.${service-name} = { };
    users.${service-name} = {
      isSystemUser = true;
      createHome = true;
      group = service-name;
      home = home-directory;
    };
  };

  systemd.tmpfiles.rules =
    [ "d ${libraries-directory} 0775 ${service-name} ${service-name} - -" ];

  system.activationScripts.makeJellyfinLibrariesDir =
    lib.stringAfter [ "users" ] ''

      mkdir -p ${libraries-directory}/Movies
      mkdir -p ${libraries-directory}/Music
      mkdir -p ${libraries-directory}/Shows
      mkdir -p ${libraries-directory}/Books
      mkdir -p ${libraries-directory}/Personal
      mkdir -p ${libraries-directory}/MusicVideos
      chown -R ${service-name}:${service-name} ${libraries-directory}
      chmod -R 0770 ${libraries-directory}
      chmod 0750 ${libraries-directory}
      chmod 0710 ${home-directory}
    '';

  backups = {
    jellyfin-data = {
      pre = lib.getExe (pkgs.writeShellScriptBin "backup-jellyfin.sh" ''

        set -euxo pipefail

        ${delete-jellyfin-backups}

        echo "Creating Jellyfin backup..."
        mkdir -p $RUNTIME_DIRECTORY/jellyroller
        cp ${jellyroller-config} $RUNTIME_DIRECTORY/jellyroller/${jellyroller-config-filename}

        set +x
        echo "api_key = \"$(cat ${secrets.api_key.path})\"" >> $RUNTIME_DIRECTORY/jellyroller/${jellyroller-config-filename}
        set -x

        export XDG_CONFIG_HOME=$RUNTIME_DIRECTORY
        systemctl start jellyfin
        ${jellyroller} create-backup
        echo "Done creating Jellyfin backup"

        ZIP_PATH="${backups-directory}/$(ls -1 "${backups-directory}" | head -n 1)"

        echo "Unzipping $ZIP_PATH"

        ${lib.getExe pkgs.unzip} -q "$ZIP_PATH" -d ${backups-directory}
        rm $ZIP_PATH
      '');
      paths = [ data-directory ];
      post = delete-jellyfin-backups;
    };
    jellyfin-libraries.paths = [ libraries-directory ];
  };
}
