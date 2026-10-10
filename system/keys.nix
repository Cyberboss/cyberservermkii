{ globals, ... }:
let
  service-port = 4440;
  service-address = "http://127.0.0.1:${toString service-port}";
  domain = "keys.dominion.universal-defense-matrix.${globals.tld}";
in {
  imports = [ ./modules/cloudflared.nix ];

  services = {
    cloudflared.tunnels.primary-tunnel.ingress.${domain} = service-address;
    caddy = {
      enable = true;
      virtualHosts."${service-address}".extraConfig = ''
        respond "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJNL86w85bS/+5aDj8fe4gZ2obLiiRn+1lXhWA2tX7Jt

        -----BEGIN PGP PUBLIC KEY BLOCK-----

        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
        =wx9x
        -----END PGP PUBLIC KEY BLOCK-----" 200
      '';
    };
  };
}
