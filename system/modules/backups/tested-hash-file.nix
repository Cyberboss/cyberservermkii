{ config, globals, ... }:
"${
  builtins.hashString "sha256" (if globals.backup-restore-safety-key then
    "BACKUPTEST"
  else
    builtins.toJSON config.services.restic.backups.primary)
}.flag"
