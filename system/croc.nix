{ globals, ... }: {
  services = {
    croc = {
      enable = true;
      openFirewall = true;
    };
  };
}
