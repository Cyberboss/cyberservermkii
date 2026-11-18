{ age-file, config, pkgs, lib, ... }:
let
  cert-path = secrets.cert.path;
  jsonFormat = pkgs.formats.json { };

  usergroup = "cloudflared";

  cfg = config.services.cloudflared;
  secrets = config.secrets.cloudflared;

  service-name = "cloudflared-tunnel-primary-tunnel";
  configure-service-name = "configure-cloudflared";
  state-directory = "/var/lib/${configure-service-name}/current";
  state-file =
    "${state-directory}/${(import ./tested-hash-file.nix) { inherit config; }}";
  run-configure = lib.getExe
    (pkgs.writeShellScriptBin "configure-cloudflared.sh" ''

      set -euxo pipefail

      if [ "$EUID" -ne 0 ]; then
          echo "Please run as root or with sudo."
          exit 1
      fi

      rm -rf ${state-directory}

      export TUNNEL_ORIGIN_CERT=${cert-path}
      ${builtins.concatStringsSep "\n" (map (published-route: ''

        ${
          lib.getExe config.services.cloudflared.package
        } tunnel route dns ${config.networking.hostName} ${published-route}
      '') (lib.attrNames cfg.tunnels.primary-tunnel.ingress))}

      mkdir -p ${state-directory}
      touch ${state-file}
    '');
in {
  imports = [ ../backups ];

  backups.cloudflared.restore-services =
    [ service-name ]; # Mainly for convienience of testing (dupe tunnels)

  services.cloudflared = {
    enable = true;
    certificateFile = cert-path;
    tunnels = {
      primary-tunnel = {
        credentialsFile = secrets.tunnel.path;
        default = "http_status:404";
      };
    };
  };

  users = {
    groups.${usergroup} = { };
    users.${usergroup} = {
      isSystemUser = true;
      group = usergroup;
    };
  };

  secrets.cloudflared.owner = usergroup;

  systemd.services = {
    "${service-name}" = {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = usergroup;
      };
      restartTriggers = secrets.restartTriggers;
    };
    "${configure-service-name}" = {
      description = "Configures cloudflared with the cloud.";
      unitConfig.ConditionPathExists = "!${state-file}";

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = configure-service-name;
        ExecStart = run-configure;
      };
      wantedBy = [ "${service-name}.service" ];
      before = [ "${service-name}.service" ];
      restartTriggers = secrets.restartTriggers;
    };
  };
}
