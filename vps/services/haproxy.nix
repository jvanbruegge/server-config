{ pkgs, lib, domain, ... }:
{
  services.haproxy = {
    enable = true;
    stats.enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  ingress.audiobookshelf = {
    subdomain = "audiobookshelf";
    address = "caladan.net.${domain}";
    port = 8234;
  };

  ingress.immich = {
    subdomain = "immich";
    address = "caladan.net.${domain}";
    port = 2283;
  };

  ingress.linkwarden = {
    subdomain = "linkwarden";
    address = "caladan.net.${domain}";
    port = 3000;
  };
}
