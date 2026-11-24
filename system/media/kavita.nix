{ globals, config, lib, pkgs, ... }:
let
  service-name = "kavita";
  cfg = config.services.kavita;
in {
  imports =
    [ ../modules/cloudflared.nix ../modules/backups ../modules/secrets ];

  secrets.kavita.owner = service-name;
  users.users.${service-name}.extraGroups = [ globals.media-group ];

  services."${service-name}" = {
    enable = true;
    settings.Port = 8675;
    credentials.token_key = config.secrets.kavita.token_key.path;
  };

  systemd.services.kavita.restartTriggers =
    config.secrets.kavita.restartTriggers;

  cloudflared."${service-name}".port = cfg.settings.Port;

  backups."${service-name}" = {
    restore-services = [ service-name ];
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
