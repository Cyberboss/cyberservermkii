{ globals, ... }:
let
  root = globals.media-root;
  group = globals.media-group;
in {
  imports = [ ../modules/backups ./jellyfin.nix ];

  backups.media.paths = [ root ];

  users.groups.${media-group} = { };
  systemd.tmpfiles.rules = [
    "d ${root} 0750 root ${group} - -"
    "d ${root}/Books 0770 root ${group} - -"
    "d ${root}/Movies 0770 root ${group} - -"
    "d ${root}/Music 0770 root ${group} - -"
    "d ${root}/MusicVideos 0770 root ${group} - -"
    "d ${globals.immich-root} 0770 root ${group} - -"
    "d ${root}/Shows 0770 root ${group} - -"
    "d ${root}/YouTube 0770 root ${group} - -"
  ];
}
