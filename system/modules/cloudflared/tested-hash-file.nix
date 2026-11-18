{ config, ... }:
"${
  builtins.hashString "sha256" (builtins.toJSON {
    cloudflared-conf = config.services.cloudflared.tunnels;
    cloudflared-secrets = config.secrets.cloudflared;
  })
}.flag"
