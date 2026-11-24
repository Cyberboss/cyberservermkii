{ globals, ... }:
let
  root = globals.media-root;
  group = globals.media-group;

  non-immich-media-locations =
    [ "Adult" "HomeVideos" "Movies" "Music" "MusicVideos" "Shows" "YouTube" ];

  non-immich-media-paths =
    map (subdir: "${root}/${subdir}") non-immich-media-locations;
in {
  imports = [ ../modules/backups ./immich.nix ./jellyfin.nix ./kavita.nix ];

  backups.media = {
    restore-services = [ ];
    paths = non-immich-media-paths;
  };

  users.groups.${group} = { };
  systemd.tmpfiles.rules = [
    "d ${root} 0750 root ${group} - -"
    "d ${globals.immich-root} 0770 root ${group} - -"
  ] ++ map (path: "d ${path} 0770 root ${group} - -") non-immich-media-paths;
}
