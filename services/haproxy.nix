{ pkgs, lib, ... }:
{
  services.haproxy = {
    enable = true;
    stats.enable = true;
  };

  /*services.certbot = {
    enable = true;
    port = 8888;
    address = "127.0.0.1";
  };*/

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
