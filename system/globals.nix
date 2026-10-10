{
  hostName = "cyberservermkii";

  tld = "dextraspace.net";

  use-lix = true;

  flake-path = "/etc/nixos";
  flake-lock-backup-path = "/var/lib/flake.lock.lastsuccessful";

  media-root = "/media";
  immich-root = "${media-root}/PersonalPhotos";

  subnet-16 = "192.168";
}
