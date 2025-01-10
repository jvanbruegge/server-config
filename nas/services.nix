{ ... }:
{
  services.netbird.enable = true;

  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = "192.168.0.1:53";
        http = "127.0.0.1:4000";
      };
      upstreams.groups.default = [
        "https://dns.digitale-gesellschaft.ch/dns-query"
        "https://mozilla.cloudflare-dns.com/dns-query"
        "1.1.1.1"
        "8.8.8.8"
      ];
      customDNS.zone = ''
        $ORIGIN nas.cerberus-systems.de.
        * 3600 CNAME @
        @ 3600 A 192.168.178.10
      '';
    };
  };

}
