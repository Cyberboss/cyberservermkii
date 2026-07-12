{ config, secrets, ... }:
let
    service-name = "jellyfin";
    home-directory = "/home/${service-name}";
    data-directory = "${home-directory}/data";
    libraries-directory = "${home-directory}/libraries";
    domain = "${service-name}.${secrets.tld}";
    service-port = "8096";
in
{
    services.${service-name} = {
        enable = true;
        openFirewall = true;
        user = service-name;
        group = service-name;
        dataDir = data-directory;
        logDir = "/var/log/${service-name}";
    };

    imports = [
        ./modules/cloudflared.nix
    ];

    services.cloudflared.tunnels.primary-tunnel.ingress.${domain} = "http://localhost:${service-port}";
    
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
        mkdir -p ${libraries-directory}
        chown ${service-name}:${service-name} ${libraries-directory}
        chmod 0770 ${libraries-directory}
    '';

    backups.jellyfin = [
      config.services.${service-name}.dataDir
      libraries-directory
    ];
}
