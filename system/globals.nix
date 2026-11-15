let media-root = "/media";
in {
  hostName = "cyberservermkii";

  tld = "dextraspace.net";

  use-lix = true;

  flake-path = "/etc/nixos";
  flake-lock-backup-path = "/var/lib/flake-lock-backups";

  host-key-path = "/etc/ssh/ssh_host_ed25519_key";

  media-group = "media";
  media-root = media-root;
  immich-root = "${media-root}/Immich";

  subnet-16 = "192.168";
}
