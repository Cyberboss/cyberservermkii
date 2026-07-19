{ config, lib, ... }:
let
  samba-root = "/home/${usergroup}/data";
  shares-root = "${samba-root}/shares";
  private-share = "${shares-root}/private";
  usergroup = "samba";
in {
  imports = [ ./modules/backups.nix ];

  users = {
    groups.samba = { };
    users.samba = {
      isSystemUser = true;
      createHome = true;
      group = usergroup;
      extraGroups = [ "jellyfin" ];
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
          "hosts allow" = "192.168.2. 127.0.0.1 localhost";
          "hosts deny" = "0.0.0.0/0";
          "guest account" = "nobody";
          "map to guest" = "bad user";
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
        jellyfin = {
          path = "/home/jellyfin/libraries";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0660";
          "directory mask" = "0770";
          "force user" = usergroup;
          "force group" = "jellyfin";
        };
      };
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
  systemd.tmpfiles.rules =
    [ "d ${private-share} 0775 ${usergroup} ${usergroup} - -" ];

  system.activationScripts.makeSambaShares = lib.stringAfter [ "users" ] ''
    
            mkdir -p ${private-share}
            chown -R ${usergroup}:${usergroup} ${samba-root}
            chmod 0770 ${samba-root}
  '';

  backups.samba.paths = [ samba-root ];
}
