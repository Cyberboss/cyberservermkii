{ globals, ... }:
let
  port = 9009;
  domain = "croc.${globals.tld}";
in {
  imports = [ ./modules/cloudflared.nix ];
  services.croc = {
    enable = true;
    openFirewall = true;
    ports = [ port ];
  };

  cloudflared.tunnels.primary-tunnel.ingress.${domain} =
    "http://localhost:${port}";
}
