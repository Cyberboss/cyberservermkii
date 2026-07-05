{ config, ... }: {
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
                    "hosts allow" = "192.168.0. 127.0.0.1 localhost";
                    "hosts deny" = "0.0.0.0/0";
                    "guest account" = "nobody";
                    "map to guest" = "bad user";
                };
                private = {
                    path = "/samba/shares/private";
                    browseable = "yes";
                    "read only" = "no";
                    "guest ok" = "no";
                    "create mask" = "0644";
                    "directory mask" = "0755";
                    "force user" = "samba";
                    "force group" = "samba";
                };
            };
        };
        samba-wsdd = {
            enable = true;
            openFirewall = true;
        };
    };
    systemd.tmpfiles.rules = [
        "d /samba/shares/private 0775 samba samba - -"
    ];
}
