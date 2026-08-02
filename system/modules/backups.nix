{ pkgs, lib, config, ... }:
let
  cfg = config.backups;
  paths = lib.lists.uniqueStrings (lib.lists.flatten
    (builtins.attrValues (lib.mapAttrs (name: value: value.paths) cfg)));
  script-aggregator = selector:
    builtins.filter (x: x != null)
    (builtins.attrValues (lib.mapAttrs (name: value: (selector value)) cfg));
  all-pre-scripts = script-aggregator (x: x.pre);
  all-dependencies = lib.lists.uniqueStrings (lib.lists.flatten
    (builtins.attrValues (lib.mapAttrs
      (name: value: (builtins.map (dep: "${dep}.service") value.dependencies))
      cfg)));
  all-post-scripts = script-aggregator (x: x.post);
  to-env-file = (file-name: attrset:
    pkgs.writeText file-name (lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: value: "${name}=${value}") attrset)));
  script-template = name: array: pre:
    if array != [ ] then
      lib.getExe (pkgs.writeShellScriptBin name ''
        set -euxo pipefail

        ${if pre then
          (builtins.concatStringsSep "\n"
            (builtins.map (service: "systemctl start ${service}")
              all-dependencies))
        else
          ""}

        # 1. Define your array of scripts
        scripts=(
            "${
              (builtins.concatStringsSep ''
                "
                "'' array)
            }"
        )

        # Initialize an array to keep track of background PIDs
        pids=()

        # 2. Spawn each script asynchronously
        for script in "''${scripts[@]}"; do
            echo "Launching $script..."

            # Run the script in the background
            $script &

            # Capture the PID of the last backgrounded process and store it
            pids+=($!)
        done

        echo "All jobs launched. Waiting for completion..."

        # 3. Wait for all tracking PIDs to finish and check exit codes
        exit_code=0
        for pid in "''${pids[@]}"; do
            if ! wait "$pid"; then
                echo "Process with PID $pid failed!"
                exit_code=1
            fi
        done

        # 4. Final verification
        if [ $exit_code -eq 0 ]; then
            echo "All scripts finished successfully!"
        else
            echo "One or more scripts failed."
            exit 1
        fi
      '')
    else
      null;

  pre-script = script-template "backup-prepare.sh" all-pre-scripts;
  post-script = script-template "backup-cleanup.sh" all-post-scripts;

  secrets = config.secrets.restic;

  test-backups-service-name = "backups-test";
  backups-test-state-directory = "/var/lib/${test-backups-service-name}";

  config-hash = builtins.hashString "sha256"
    (builtins.toJSON config.services.restic.backups.primary);
in {
  options.backups = lib.mkOption {
    description = ''
      Backup specifications.
    '';
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        pre = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          example = "/path/to/script.sh";
          description = ''
            The script to run that must complete before the backup begins
          '';
        };
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.nonEmptyStr;
          example = [
            "/var/logs/some-service"
            "/home/some-service/data"
            "/some-service"
          ];
          description = ''
            Paths to backup
          '';
          default = [ ];
        };
        post = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          example = "/path/to/script.sh";
          description = ''
            The script to run that must complete before the backup begins
          '';
        };
        dependencies = lib.mkOption {
          type = lib.types.listOf lib.types.nonEmptyStr;
          default = [ ];
          example = [ "service1" "service2" ];
          description = ''
            An array of systemd service names (Excluding ".service") that should be running prior to the backup starting.
          '';
        };
      };
    }));

    example = {
      some-service = {
        pre = "/pre/backup/script.sh";
        paths = [ /backup/path/1 /backup/path/2 ];
        post = "/post/backup/script.sh";
      };
    };
  };

  imports = [ ./secrets ];

  config = {
    services.restic.backups.primary = {
      initialize = true;
      paths = paths;
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        Persistent = true;
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
        "--keep-yearly 1"
      ];

      repositoryFile = secrets.repository.path;
      passwordFile = secrets.password.path;
      environmentFile = secrets.environment.path;
      backupPrepareCommand = pre-script;
      backupCleanupCommand = post-script;

      extraOptions = [ "--compression=max" ];
    };

    systemd.services.${test-backups-service-name} = {
      description =
        "Backups test service. Runs backup pre and post actions without performing the restic sync.";
      serviceConfig = {
        Type = "oneshot";
        User =
          config.systemd.services.restic-backups-primary.serviceConfig.User;
        RuntimeDirectory = test-backups-service-name;
        StateDirectory = test-backups-service-name;
        ExecStartPre = lib.getExe
          (pkgs.writeShellScriptBin "clear-backups-test-state.sh" ''
            sudo -xeou pipefail

            rm -rf ${backups-test-state-directory}
          '');
        ExecStart = pre-script;
        ExecStopPost = post-script;
        ConditionPathExists =
          "!${backups-test-state-directory}/${config-hash}.flag";
      };
      wantedBy = [ "multi-user.target" ];
      after = all-dependencies;
    };
  };
}
