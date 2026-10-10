{ config, lib, globals, ... }:
let
  samba-root = "/home/${usergroup}/data";
  shares-root = "${samba-root}/shares";
  private-share = "${shares-root}/private";
  usergroup = "samba";
in {
  imports = [ ./modules/backups ];

  users = {
    groups.${usergroup} = { };
    users.${usergroup} = {
      isSystemUser = true;
      createHome = true;
      group = usergroup;
      extraGroups = [ globals.media-group ];
    };
  };

  services = {
    samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = config.networking.hostName;
          "netbios name" = config.networking.hostName;
          security = "user";
          "hosts allow" = "${globals.subnet-16}.0.0/16 127.0.0.1 localhost";
          "hosts deny" = "0.0.0.0/0";
          "guest account" = "nobody";
          "map to guest" = "not a user";
        };
        private = {
          path = private-share;
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = usergroup;
          "force group" = usergroup;
        };
        media = {
          path = globals.media-root;
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0660";
          "force create mode" = "0660";
          "directory mask" = "0770";
          "force directory mode" = "0770";
          "force user" = usergroup;
          "force group" = globals.media-group;
        };
      };
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
  systemd.tmpfiles.rules = [
    "d ${samba-root} 0770 ${usergroup} ${usergroup} - -"
    "d ${private-share} 0770 ${usergroup} ${usergroup} - -"
  ];

  backups.samba.paths = [ samba-root ];
}
