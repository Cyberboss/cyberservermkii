{ config, ... }:
"${
  builtins.hashString "sha256"
  (builtins.toJSON config.services.restic.backups.primary)
}.flag"
