{ lib, config, secrets, pkgs, ... }:
let
    service-name = "jellyfin";
    home-directory = "/home/${service-name}";
    data-directory = "${home-directory}/data";
    libraries-directory = "${home-directory}/libraries";
    domain = "${service-name}.${secrets.tld}";
    service-port = "8096";
    local-url = "http://localhost:${service-port}";
    jellyroller = pkgs.rustPlatform.buildRustPackage rec {
      pname = "jellyroller";
      version = "1.1.3";

      src = pkgs.fetchFromGitHub {
        owner = "LSchallot";
        repo = "JellyRoller";
        rev = "v${version}";
        hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      };

      # Automatically vendored Cargo dependencies
      # (Newer Nixpkgs versions prefer `cargoHash` over `cargoSha256`)
      cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    jellyroller-config = {
      status = "configured";
      comfy = true;
      server_url = local-url;
      os = "linux";
      api_key = secrets.jellyfin.api-key;
      token = "apiKey";
    };
    tomlFormat = pkgs.formats.toml { };
    jellyroller-config-path = tomlFormat.generate "jellyroller.toml" jellyroller-config;
in
{
    services = {
      "${service-name}" = {
        enable = true;
        openFirewall = true;
        user = service-name;
        group = service-name;
        dataDir = data-directory;
        logDir = "/var/log/${service-name}";
      };
      seerr = {
        enable = true;
        openFirewall = true;
      };
    };

    imports = [
        ./modules/cloudflared.nix
    ];

    services.cloudflared.tunnels.primary-tunnel.ingress.${domain} = local-url;
    
    users = {
      groups.${service-name} = { };
      users.${service-name} = {
        isSystemUser = true;
        createHome = true;
        group = service-name;
        home = home-directory;
      };
    };

    systemd.tmpfiles.rules = [
        "d ${libraries-directory} 0775 ${service-name} ${service-name} - -"
    ];
    
    system.activationScripts.makeJellyfinLibrariesDir = lib.stringAfter [ "users" ] ''
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

    backups.jellyfin = {
      pre = ''
        set -euxo pipefail
        export XDG_CONFIG_HOME=${jellyroller-config-path}
        ${jellyroller}/bin/jellyroller create-backup
      '';
      paths = [
        config.services.${service-name}.dataDir
        libraries-directory
      ];
      post = ''
        set -euxo pipefail
        shopt -s dotglob
        rm -rf ${data-directory}/backups/*
      '';
    };
}
