{ age-file, config, pkgs, lib, globals, ... }:
let
  jsonFormat = pkgs.formats.json { };

  usergroup = "cloudflared";

  cfg = config.services.cloudflared;
  secrets = config.secrets.cloudflared;

  cert-path = secrets.cert.path;

  service-name = "cloudflared-tunnel-primary-tunnel";
  configure-service-name = "configure-cloudflared";
  state-directory = "/var/lib/${configure-service-name}/current";
  state-file =
    "${state-directory}/${(import ./tested-hash-file.nix) { inherit config; }}";

  cloudflared-uid = 989;
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
  all-subdomains = lib.attrNames config.cloudflared;
  all-ports = lib.unique
    (map (subdomain: config.cloudflared.${subdomain}.port) all-subdomains);
in {
  options.cloudflared = lib.mkOption {
    description = ''
      Cloudflared tunnel specifications. The service name will be what's used for the subdomain.
    '';
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          description = ''
            Local port for the internal service.
          '';
        };
      };
    }));

    example.some-service.port = 1234;
  };

  imports = [ ../secrets ../backups ];

  config = {
    assertions = [{
      assertion = builtins.length all-subdomains == builtins.length all-ports;
      message =
        "Mismatch in specified cloudflared subdomains and ports! Please verify: ${
          (builtins.toJSON config.cloudflared)
        }";
    }];

    backups.cloudflared.restore-services =
      [ service-name ]; # Mainly for convienience of testing (dupe tunnels)

    services.cloudflared = {
      enable = true;
      certificateFile = cert-path;
      tunnels.primary-tunnel = {
        credentialsFile = secrets.tunnel.path;
        default = "http_status:404";
        ingress = builtins.listToAttrs (map (subdomain: {
          name = "${subdomain}.${globals.tld}";
          value =
            "http://localhost:${toString config.cloudflared.${subdomain}.port}";
        }) all-subdomains);
      };
    };

    users = {
      groups.${usergroup} = { };
      users.${usergroup} = {
        isSystemUser = true;
        group = usergroup;
        uid = cloudflared-uid;
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

    networking.nftables.ruleset = ''
      table inet cloudflared_filter {
        chain output {
          type filter hook output priority 0; policy accept;

          # Match only packets originating from the cloudflared user
          meta skuid ${toString cloudflared-uid} goto cloudflared_out
        }

        chain cloudflared_out {
          # Allow established connections
          ct state established,related accept

          # Allow ONLY specific local ports on loopback
          oifname "lo" tcp dport { ${
            builtins.concatStringsSep ", "
            (map builtins.toString all-ports)
          } } accept

          # Block all other loopback/LAN traffic (e.g. SSH, databases, other local apps)
          ip daddr { 127.0.0.0/8, ${globals.subnet-16}.0.0/16 } drop
          ip6 daddr { ::1/128, fc00::/7, fe80::/10 } drop

          # Allow outbound internet to Cloudflare edge (ports 7844 QUIC/HTTPS + DNS 53)
          tcp dport { 53, 443, 7844 } accept
          udp dport { 53, 7844 } accept

          # Drop everything else
          drop
        }
      }
    '';
  };
}
