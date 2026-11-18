{ pkgs, lib, config, globals, ... }:
let
  cfg = config.backups;
  paths = lib.lists.uniqueStrings (lib.lists.flatten
    (builtins.attrValues (lib.mapAttrs (name: value: value.paths) cfg)));
  script-aggregator = selector:
    builtins.filter (x: x != null)
    (builtins.attrValues (lib.mapAttrs (name: value: (selector value)) cfg));
  all-pre-scripts = script-aggregator (x: x.pre);
  all-post-scripts = script-aggregator (x: x.post);
  all-restore-services = lib.lists.uniqueStrings (lib.lists.flatten
    (builtins.attrValues
      (lib.mapAttrs (name: value: value.restore-services) cfg)));
  all-restore-scripts = script-aggregator (x: x.restore-script);
  to-env-file = (file-name: attrset:
    pkgs.writeText file-name (lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: value: "${name}=${value}") attrset)));
  script-template = name: array:
    if array != [ ] then
      lib.getExe (pkgs.writeShellScriptBin name ''
        set -euxo pipefail

        if [ "$EUID" -ne 0 ]; then
            echo "Please run as root or with sudo."
            exit 1
        fi

        scripts=(
            "${
              (builtins.concatStringsSep ''
                "
                "'' array)
            }"
        )

        pids=()

        for script in "''${scripts[@]}"; do
            # Run the script in the background
            $script &

            # Capture the PID of the last backgrounded process and store it
            pids+=($!)
        done

        exit_code=0
        for pid in "''${pids[@]}"; do
            if ! wait "$pid"; then
                exit_code=1
            fi
        done

        if [ $exit_code -ne 0 ]; then
            echo "One or more scripts failed."
            exit 1
        fi
      '')
    else
      null;

  pre-script = script-template "backup-prepare.sh" all-pre-scripts;
  post-script = script-template "backup-cleanup.sh" all-post-scripts;
  restore-script-core =
    script-template "backup-restore-core.sh" all-restore-scripts;

  secrets = config.secrets.restic;

  test-backups-service-name = "backups-test";
  backups-test-state-directory = "/var/lib/${test-backups-service-name}";
  backups-test-state-file = "${backups-test-state-directory}/${
      (import ./tested-hash-file.nix) { inherit config; }
    }";
  backups-test-script = lib.getExe
    (pkgs.writeShellScriptBin "backups-test.sh" ''
      set -euxo pipefail

      if [ "$EUID" -ne 0 ]; then
          echo "Please run as root or with sudo."
          exit 1
      fi

      sleep 30

      rm -rf ${backups-test-state-directory}

      trap '${post-script}' EXIT

      ${pre-script}

      trap - EXIT

      ${post-script}

      mkdir -p ${backups-test-state-directory}
      touch ${backups-test-state-file}
    '');
  restore-command = dry-run:
    "${
      lib.getExe pkgs.restic
    } restore --target / --verify --password-file ${secrets.password.path} --repository-file ${secrets.repository.path} --ownership-by-name ${
      if dry-run then "--dry-run" else ""
    } latest";
  restore-script = pkgs.writeShellScriptBin
    "backup-restore-YES-REALLY_FOR_REALZ_NOT_A_DRILL" ''
      set -euxo pipefail

      if [ "$EUID" -ne 0 ]; then
          echo "Please run as root or with sudo."
          exit 1
      fi

      ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && { echo "Error: Connected to the internet!" >&2; exit 1; }

      systemctl stop ${builtins.concatStringsSep " " all-restore-services}

      read -p "Reconnect internet and press enter to perform dry-run..."

      set -a
      source ${secrets.environment.path}
      set +a

      ${restore-command true}

      read -p "Reconnect internet and press enter to DELETE CURRENT DATA and restore..."

      ${lib.concatMapStringsSep "\n" (path: "rm -rf ${path}/*") paths}
      ${restore-command false}
      ${restore-script-core}

      read -p "Restoration complete. Disconnect internet prior to continuing if this is a test. Press enter to reboot..."

      reboot
    '';
in {
  options.backups = lib.mkOption {
    description = ''
      Backup specifications.
    '';
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        restore-services = lib.mkOption {
          type = lib.types.listOf lib.types.nonEmptyStr;
          example = [ "some-service" ];
          description = ''
            Service names that must stop before a restore.
          '';
        };
        restore-script = lib.mkOption {
          type = lib.types.nullOr lib.types.nonEmptyStr;
          default = null;
          description = ''
            Script performing restore actions taking the restore root as input
          '';
        };
        pre = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          example = "/path/to/script.sh";
          description = ''
            The script to run that must complete before the backup begins. These scripts run in parallel
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
            The script to run that must complete before the backup begins. These scripts run in parallel
          '';
        };
      };
    }));

    example = {
      some-service = {
        restore-services = [ "some-systemd-service" ];
        pre = "/pre/backup/script.sh";
        paths = [ /backup/path/1 /backup/path/2 ];
        post = "/post/backup/script.sh";
      };
    };
  };

  imports = [ ../secrets ];

  config = {
    environment.systemPackages = [ restore-script ];

    backups.system-configuration.paths =
      [ globals.flake-lock-backup-path globals.host-key-path ];

    users = {
      users.restic = {
        group = "restic";
        isSystemUser = true;
      };
      groups.restic = { };
    };

    security.wrappers.restic = {
      source = lib.getExe pkgs.restic;
      owner = "restic";
      group = "restic";
      permissions = "u=rx,g=,o=";
      capabilities = "cap_dac_read_search+ep";
    };

    services.restic.backups.primary = {
      initialize = true;
      paths = paths;
      user = "restic";
      package = pkgs.writeShellScriptBin "restic" ''
        exec /run/wrappers/bin/restic "$@"
      '';
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
      unitConfig.ConditionPathExists = "!${backups-test-state-file}";

      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = test-backups-service-name;
        StateDirectory = test-backups-service-name;
        ExecStart = backups-test-script;
      };
      wantedBy = [ "multi-user.target" "sysinit-reactivation.target" ];
      after = [ "sysinit-reactivation.target" ];
      before = [ "restic-backups-primary.service" ];
    };
  };
}
