{ pkgs, lib, domain, config, ... }:
let
  cfg = config.services.haproxy;
in {
  services.haproxy = {
    enable = true;
    stats.enable = true;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.haproxy.settings = {
    defaultFrontends = false;
    frontends = {
        https = {
          bind = {
            address = "*";
            port = 443;
          };
          mode = "tcp";

          acls = {
            caladan = "req_ssl_sni -m end caladan.${domain}";
            nas = "req_ssl_sni -m end nas.${domain}";
          };

          useBackend = [
            "caladanHttps if caladan"
            "nasHttps if nas"
            "httpsLocal unless caladan nas"
          ];

          extraConfig = ''
            tcp-request inspect-delay 5s
            tcp-request content accept if { req_ssl_hello_type 1 }
          '';
        };
        httpsLocal = {
           bind = {
            address = "127.0.0.1";
            port = 4443;
            extraOptions = "ssl crt /etc/letsencrypt/live/${cfg.settings.domain}/fullchain.pem accept-proxy alpn h2,http/1.1";
          };
          httpRequest = [ "set-header X-Forwarded-Proto https" ];
          useBackend = lib.attrsets.mapAttrsToList (name: x:
            "${name} if { hdr(host) -i ${x.subdomain}.${cfg.settings.domain} }"
          ) config.ingress ++ [
            "netbird if { path_beg /relay }"
          ];
        };

        http = {
          bind = {
            address = "*";
            port = 80;
          };
          acls.letsencrypt = "path_beg /.well-known/acme-challenge/";
          httpRequest = [ "redirect scheme https code 301 unless letsencrypt" ];
          useBackend = [
            "caladan if letsencrypt { hdr(host) -i -m end caladan.${domain} }"
            "nas if letsencrypt { hdr(host) -i -m end nas.${domain} }"
            "certbot if letsencrypt"
          ];
        };
    };
    backends = {
      httpsLocal = {
        mode = "tcp";
        servers = [ "httpsLocal 127.0.0.1:4443 send-proxy-v2" ];
      };
      caladanHttps = {
        servers = [ "caladanHttps caladan.net.cerberus-systems.de:443" ];
        mode = "tcp";
      };
      nasHttps = {
        servers = [ "nasHttps nas.net.cerberus-systems.de:443" ];
        mode = "tcp";
      };
      caladan.servers = [ "caladan caladan.net.cerberus-systems.de:80" ];
      nas.servers = [ "nas nas.net.cerberus-systems.de:80" ];
    };
  };

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

  ingress.booklore = {
    subdomain = "booklore";
    address = "caladan.net.${domain}";
    port = 8080;
  };
}
