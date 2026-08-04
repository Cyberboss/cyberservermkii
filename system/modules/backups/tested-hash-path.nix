{ config, ... }:
let
  config-hash = builtins.hashString "sha256"
    (builtins.toJSON config.services.restic.backups.primary);
in "/var/lib/backups-test/${config-hash}.flag"
