{ lib, pkgs, config, ... }:
let
  makeServarrConfig = service-name:
    let db-username = config.services.${service-name}.user;
    in {
      networking.firewall.allowedTCPPorts =
        [ config.services.${service-name}.settings.port ];

      services = {
        "${service-name}" = {
          enable = true;
          settings = {
            postgres.host = "127.0.0.1";
            postgres.logdb = "${db-username}-log";
            postgres.maindb = "${db-username}-main";
            postgres.password = db-username;
            postgres.user = db-username;
          };
        };
        postgresql = {
          ensureDatabases = [ "${db-username}-log" "${db-username}-main" ];
          ensureUsers = [{ name = db-username; }];
        };
      };

      backups.${service-name} = {
        pre = lib.getExe (pkgs.writeShellScriptBin "stop-${service-name}.sh" ''
          set -euxo pipefail
          echo "Stopping ${service-name}..."
          systemctl stop ${service-name}
        '');
        paths = [ config.services.${service-name}.dataDir ];
        post = lib.getExe
          (pkgs.writeShellScriptBin "start-${service-name}.sh" ''
            set -euxo pipefail
            echo "Starting ${service-name}..."
            systemctl start ${service-name}
          '');
      };
    };

  makeServarrConfigs = service-names: {
    imports = [ ./modules/backups.nix ./modules/postgres.nix ];
    config = builtins.foldl' lib.recursiveUpdate { }
      ((builtins.map makeServarrConfig service-names) ++ [{
        services.postgresql = {
          authentication = ''
            #type database DBuser origin-address auth-method
            # this is for local database access with psql
            local all all trust
            ${lib.concatStringsSep "\n" (builtins.map (service-name:
              let db-username = config.services.${service-name}.user;
              in ''
                # this is for ${service-name} to connect
                host ${db-username}-log ${db-username} 127.0.0.1/32 trust
                host ${db-username}-log ${db-username} ::1/128 trust
                host ${db-username}-main ${db-username} 127.0.0.1/32 trust
                host ${db-username}-main ${db-username} ::1/128 trust
              '') service-names)}
          '';
        };
      }]);
  };
in makeServarrConfigs [ "radarr" ]
