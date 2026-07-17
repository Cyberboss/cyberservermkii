{ pkgs, lib, config, secrets, ... }:
let
    cfg = config.backups;
    paths = lib.lists.uniqueStrings (lib.lists.flatten (builtins.attrValues (lib.mapAttrs (name: value: value.paths) cfg)));
    all-pre-scripts = builtins.attrValues (lib.mapAttrs (name: value: value.pre) cfg);
    all-post-scripts = builtins.attrValues (lib.mapAttrs (name: value: value.post) cfg);
    to-env-file = (file-name: attrset: pkgs.writeText file-name (
        pkgs.lib.concatStringsSep "\n" (
            pkgs.lib.mapAttrsToList (name: value: "${name}=${value}") attrset
        )
    ));
    script-template = name: array: (pkgs.writeShellScriptBin name ''
# 1. Define your array of scripts
scripts=(
    "${(builtins.concatStringsSep "\"\n\"" array)}"
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
    '');

    pre-script = lib.mkIf (all-pre-scripts != [ ]) "${(script-template "backup-prepare" all-pre-scripts)}";
    post-script = lib.mkIf (all-pre-scripts != [ ]) "${(script-template "backup-cleanup" all-post-scripts)}";
in
{
    options.backups = lib.mkOption {
      description = ''
        Backup specifications.
      '';
      type = lib.types.attrsOf (
         lib.types.submodule (
          { name, ... }:
          {
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
            };
          }
      ));
      
      default = { };
      example = {
        some-service = {
          pre = "/pre/backup/script.sh";
          paths = [
            /backup/path/1
            /backup/path/2
          ];
          post = "/post/backup/script.sh";
        };
      };
    };

    config.services.restic.backups.primary = {
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

        repository = secrets.restic.repository;
        passwordFile = "${pkgs.writeText "restic" secrets.restic.encryption-password}";
        environmentFile = "${to-env-file "restic-env" secrets.restic.environment}";
        backupPrepareCommand = pre-script;
        backupCleanupCommand = post-script;
    };
}
