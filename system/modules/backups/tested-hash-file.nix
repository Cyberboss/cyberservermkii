{ config, ... }:
"${builtins.toJSON config.services.restic.backups.primary}.flag}"
