{ config, ... }:
let
  config-hash = builtins.hashString "sha256"
    (builtins.toJSON config.services.restic.backups.primary);
in "${backups-test-state-directory}/${config-hash}.flag"
