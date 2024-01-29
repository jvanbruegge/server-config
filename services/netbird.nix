{ pkgs, lib, domain, config, ... }:
{
  services.netbird = {
    enable = true;
  };

  sops.secrets.netbird = {};
}
