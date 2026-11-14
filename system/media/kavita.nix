{ globals, config, lib, pkgs, ... }:
let
  service-name = "kavita";
  cfg = config.services.kavita;
  domain = "kavita.${globals.tld}";
in {
  imports = [ ../modules/cloudflared.nix ../modules/backups ];

  secrets.kavita.owner = service-name;
  users.users.${service-name}.extraGroups = [ globals.media-group ];

  services = {
    "${service-name}" = {
      enable = true;
      settings.Port = 8675;
      credentials.token_key = config.secrets.kavita.token_key.path;
    };

    cloudflared.tunnels.primary-tunnel.ingress = {
      "${domain}" = "http://localhost:${toString cfg.settings.Port}";
    };
  };

  backups.kavita = {
    pre = lib.getExe (pkgs.writeShellScriptBin "backup-kavita.sh" ''
      set -euxo pipefail

      systemctl stop kavita
    '');
    paths = [ cfg.dataDir ];
    post = lib.getExe (pkgs.writeShellScriptBin "backup-kavita.sh" ''
      set -euxo pipefail

      systemctl start kavita
    '');
  };
}
