{...}:
let
    service-name = "jellyfin";
    home-directory = "/home/${service-name}/data";
in
{
    services.${service-name} = {
        enable = true;
        openFirewall = true;
        user = service-name;
        group = service-name;
        dataDir = home-directory;
    };
    
    users = {
      groups."${service-name}" = { };
      users."${service-name}" = {
        isSystemUser = true;
        createHome = true;
        group = service-name;
        home = home-directory;
      };
    };
}
