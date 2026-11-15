let media-root = "/media";
in {
  ## CONTEXT DEPENDENT
  hostName = "cyberservermkii";
  tld = "dextraspace.net";
  subnet-16 = "192.168";
  ## END CONTEXT DEPENDENT

  use-lix = true;

  flake-path = "/etc/nixos";
  flake-lock-backup-path = "/var/backup/flake-lock";

  host-key-path = "/etc/ssh/ssh_host_ed25519_key";

  media-group = "media";
  media-root = media-root;
  immich-root = "${media-root}/Immich";
}
