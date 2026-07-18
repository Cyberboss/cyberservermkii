{
  age-file,
  config,
  pkgs,
  lib,
  secrets,
  ...
}: let
  published-route-script-name-map = builtins.listToAttrs (map (published-route: { name = "cloudflared-publish-route-${published-route}"; value = published-route; }) (lib.attrNames cfg.tunnels.primary-tunnel.ingress));
  cert-path = secrets.cloudflared.cert.path;
  jsonFormat = pkgs.formats.json {};

  cfg = config.services.cloudflared;
  attrset = {
    tunnels = cfg.tunnels;
    certificateFile = cfg.certificateFile;
  };
  attrsetJSON = builtins.toJSON attrset;
  attrsetHash = builtins.hashString "sha256" attrsetJSON;
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
    lib.stringAfter ["users"] ''
      STATE_DIR="/var/lib/cloudflared-tunnel-attrset-hashes"
      HASH_FILE="$STATE_DIR/${script-name}.hash"

      # Ensure state directory exists
      mkdir -p "$STATE_DIR"

      NEW_HASH="${attrsetHash}"

      # Check if hash file exists and compare
      if [ ! -f "$HASH_FILE" ] || [ "$(cat "$HASH_FILE")" != "$NEW_HASH" ]; then
        echo "Tunnel ${script-name} changed! Running activation actions..."

        mkdir -p /root/.cloudflared
        cp ${cert-path} /root/.cloudflared/cert.pem
        ${config.services.cloudflared.package}/bin/cloudflared tunnel route dns ${config.networking.hostName} ${published-route}
        rm -rf /root/.cloudflared

        # Save the new hash so we don't run this again unless the attrset changes
        echo "${attrsetHash}" > "$HASH_FILE"
      fi
    ''
    ) published-route-script-name-map;
}
