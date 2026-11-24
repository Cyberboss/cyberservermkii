{ backup-restore-configuration }:
let
  media-root = "/media";
  backup-restore-safety-key =
    (import backup-restore-configuration).backup-restore-safety-key;
  ## CONTEXT DEPENDENT
  hostName = "cyberservermkii";
in {
  hostName =
    if backup-restore-safety-key then "${hostName}-BACKUPRESTORE" else hostName;
  tld = "dextraspace.net";
  subnet-16 = "192.168";
  backup-restore-subnet-16 = "172.27";
  ## END CONTEXT DEPENDENT

  backup-restore-safety-key = backup-restore-safety-key;

  use-lix = true;

  flake-path = "/etc/nixos";
  flake-lock-backup-path = "/var/backup/flake-lock";

  host-key-path = "/etc/ssh/ssh_host_ed25519_key";

  media-group = "media";
  media-root = media-root;
  immich-root = "${media-root}/Immich";
}
