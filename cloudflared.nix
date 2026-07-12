{
  age-file,
  config,
  pkgs,
  lib,
  secrets,
  ...
}: let
  published-route-script-name-map = builtins.listToAttrs (map (published-route: { name = "cloudflared-publish-route-${published-route}"; value = published-route; }) (lib.attrNames config.services.cloudflared.tunnels.primary-tunnel.ingress));
  cert-path = pkgs.writeText "cloudflared-cert" secrets.cloudflared.cert;
  jsonFormat = pkgs.formats.json {};
in {
  services.cloudflared = {
    enable = true;
    certificateFile = cert-path;
    tunnels = {
      primary-tunnel = {
        credentialsFile = jsonFormat.generate "cloudflared-tunnel.json" secrets.cloudflared.tunnel;
        default = "http_status:404";
      };
    };
  };

  system.activationScripts = builtins.mapAttrs (script-name: published-route:
    # Register the tunnel with DNS
    # Need the cert in-place temporarily for this
    pkgs.lib.stringAfter ["users"] ''
      mkdir -p /root/.cloudflared
      cp ${cert-path} /root/.cloudflared/cert.pem
      ${config.services.cloudflared.package}/bin/cloudflared tunnel route dns ${config.networking.hostName} ${published-route}
      rm -rf /root/.cloudflared
    ''
    ) published-route-script-name-map;
}
