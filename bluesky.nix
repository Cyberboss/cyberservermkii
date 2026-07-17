{ config, secrets, lib, ... }:
let
    service-port = "3000";
    domain = "bsky.${secrets.tld}";
    pds-domain = "pds.${domain}";
in
{
    services.bluesky-pds = {
        enable = true;
        settings = {
            PDS_HOSTNAME = domain;
            PDS_ADMIN_PASSWORD = secrets.bluesky.password;
            PDS_JWT_SECRET = secrets.bluesky.jwt-secret;
            PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX = secrets.bluesky.rotation-key;
        };
    };

    imports = [
        ./modules/cloudflared.nix
    ];

    services.cloudflared.tunnels.primary-tunnel.ingress.${pds-domain} = "http://localhost:${service-port}";

    backups.bluesky.paths = [
        config.services.bluesky-pds.settings.PDS_DATA_DIRECTORY
    ];
}
