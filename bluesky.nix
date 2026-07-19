{ config, globals, lib, ... }:
let
    service-port = "3000";
    domain = "bsky.${globals.tld}";
    pds-domain = "pds.${domain}";
    secrets = config.secrets.bluesky;
in
{
    services.bluesky-pds = {
        enable = true;
        environmentFiles = [ secrets.environment.path ];
        settings.PDS_HOSTNAME = domain;
    };

    imports = [
        ./modules/cloudflared.nix
        ./modules/backups.nix
    ];

    services.cloudflared.tunnels.primary-tunnel.ingress.${pds-domain} = "http://localhost:${service-port}";

    backups.bluesky.paths = [
        config.services.bluesky-pds.settings.PDS_DATA_DIRECTORY
    ];
}
