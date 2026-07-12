{ config, lib, ... }: 
let
    samba-root = "/home/${usergroup}/data";
    shares-root = "${samba-root}/shares";
    private-share = "${shares-root}/private";
    usergroup = "samba";
in
{
    users = {
      groups.samba = { };
      users.samba = {
        isSystemUser = true;
        createHome = true;
        group = usergroup;
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
            };
        };
        samba-wsdd = {
            enable = true;
            openFirewall = true;
        };
    };

    backups.samba = [
        samba-root
    ];
}
