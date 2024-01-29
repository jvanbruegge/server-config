{ config, lib, pkgs, domain, email, ... }:

let
  cfg = config.services.haproxy;
  indent = str: lib.strings.concatStringsSep "\n  " (lib.strings.splitString "\n" str);

  stats = ''
    frontend stats
      mode http
      bind 127.0.0.1:${builtins.toString cfg.stats.port}
      stats enable
      stats uri /
      stats refresh 10s
  '';

  domains = lib.strings.concatStringsSep "  " (lib.attrsets.attrValues (builtins.mapAttrs (name: c: ''
    use_backend ${name} if { hdr(host) -i ${c.subdomain}.${domain} }
  '') config.ingress));

  certDomains = lib.attrsets.attrValues (builtins.mapAttrs (name: c: "${c.subdomain}.${domain}") config.ingress) ++ [ "netbird.${domain}" ];
  certbotDomains = lib.strings.concatMapStringsSep "\\\n  " (s: "-d ${s}") certDomains;

  backends = lib.strings.concatStringsSep "\n" (lib.attrsets.attrValues (builtins.mapAttrs (name: c: ''
    backend ${name}
      mode http
      server ${name} ${c.address}:${builtins.toString c.port}
  '') config.ingress));

  haproxyCfg = pkgs.writeText "haproxy.conf" ''
    global
      # needed for hot-reload to work without dropping packets in multi-worker mode
      stats socket /run/haproxy/haproxy.sock mode 600 expose-fd listeners level user
      log stdout format raw local0 info

    defaults
      log global
      option httplog
      timeout connect 5s
      timeout client 50s
      timeout server 50s

    #TODO: put in options
    frontend ldaps
      mode tcp
      bind :636
      default_backend ldaps

    backend ldaps
      mode tcp
      server authentik 127.0.0.1:6636

    backend netbird-signal
      mode http
      server netbird-signal 127.0.0.1:10000
    backend netbird-management
      mode http
      server netbird-management 127.0.0.1:10001

    frontend http
      mode http
      bind *:80
      acl letsencrypt path_beg /.well-known/acme-challenge/
      http-request redirect scheme https code 301 unless letsencrypt
      use_backend certbot if letsencrypt

    frontend https
      mode http
      bind *:443 ssl crt /etc/letsencrypt/live/${domain}/fullchain.pem
      http-request set-header X-Forwarded-Proto https
      use_backend netbird-signal if { hdr(host) -i netbird.${domain} } { path_beg /signalexchange.SignalExchange/ }
      use_backend netbird-management if { hdr(host) -i netbird.${domain} } { path_beg /management.ManagementService/ }
      use_backend netbird-management if { hdr(host) -i netbird.${domain} } { path_beg /api }
      #use_backend netbird-signal if { hdr(host) -i netbird.${domain} }
      ${domains}
    ${if cfg.stats.enable then stats else ""}
    ${backends}
    backend certbot
      mode http
      server certbot 127.0.0.1:8403
  '';

  certbotCmd = address: port: ''
    ${pkgs.certbot}/bin/certbot certonly --standalone --cert-name ${domain} \
      --http-01-port ${builtins.toString port} --http-01-address ${address} \
      --non-interactive --keep --agree-tos --email ${email} --expand \
      ${certbotDomains}
  '';

  certbotScript = pkgs.writeScript "certbot.sh" ''
    #!${pkgs.bash}/bin/bash

    all_good=true
    output=$(${pkgs.certbot}/bin/certbot certificates | grep Domains)

    set -euo pipefail
    for d in ${lib.concatStringsSep " " certDomains}; do
      if ! echo "$output" | grep -q $d; then
        all_good=false
        break
      fi
    done
    if ! $all_good; then
      ${certbotCmd "0.0.0.0" 80}
      ${pkgs.coreutils}/bin/ln -sf /etc/letsencrypt/live/${domain}/privkey.pem /etc/letsencrypt/live/${domain}/fullchain.pem.key
    fi
  '';
in
with lib;
{
  disabledModules = [ "services/networking/haproxy.nix" ];

  options = {
    services.haproxy = {
      enable = mkEnableOption (lib.mdDoc "HAProxy, the reliable, high performance TCP/HTTP load balancer.");

      package = mkOption {
        type = types.package;
        default = pkgs.haproxy;
        defaultText = literalExpression "pkgs.haproxy";
        description = lib.mdDoc "HAProxy package to use.";
      };

      letsencrypt = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic certificate generation with letsencrypt";
      };

      user = mkOption {
        type = types.str;
        default = "haproxy";
        description = lib.mdDoc "User account under which haproxy runs.";
      };

      group = mkOption {
        type = types.str;
        default = "haproxy";
        description = lib.mdDoc "Group account under which haproxy runs.";
      };

      stats = {
        enable = mkEnableOption (lib.mdDoc "the stats page");

        subdomain = mkOption {
          type = types.str;
          default = "stats";
          description = lib.mdDoc "The subdomain to serve the stats from";
        };

        port = mkOption {
          type = types.port;
          default = 8404;
          description = lib.mdDoc "The internal port to serve the stats from";
        };
      };
    };

    ingress = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          subdomain = mkOption { type = types.str; };
          letsencrypt = mkOption {
            type = types.bool;
            default = true;
            description = "Enable automatic TLS certificates with letsencrypt";
          };
          address = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Address of service to proxy to";
          };
          port = mkOption {
            type = types.port;
            default = 8080;
            description = "Port of the service to proxy to";
          };
        };
      });
      default = {};
      description = "Configure the reverse proxy to forward requests for a given domain";
    };
  };

  config = mkIf cfg.enable {
    # configuration file indirection is needed to support reloading
    environment.etc."haproxy.cfg".source = haproxyCfg;

    ingress.haproxy-stats = mkIf cfg.stats.enable {
      subdomain = cfg.stats.subdomain;
      port = cfg.stats.port;
    };

    systemd.services.certbot = mkIf cfg.letsencrypt {
      description = "certbot";
      after = [ "network.target" "haproxy.service" ];
      wants = [ "haproxy.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = certbotCmd "127.0.0.1" 8403;
        Restart = "no";
        User = cfg.user;
        Group = cfg.group;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter = "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        StateDirectory = "letsencrypt";
        LogsDirectory = "letsencrypt";
        ConfigurationDirectory = "letsencrypt";
      };
    };

    systemd.services.haproxy = {
      description = "HAProxy";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStartPre = [
          # create certificate with certbot
          "${pkgs.bash}/bin/bash -x ${certbotScript}"
          # when the master process receives USR2, it reloads itself using exec(argv[0]),
          # so we create a symlink there and update it before reloading
          "${pkgs.coreutils}/bin/ln -sf ${cfg.package}/sbin/haproxy /run/haproxy/haproxy"
          # when running the config test, don't be quiet so we can see what goes wrong
          "/run/haproxy/haproxy -c -f ${haproxyCfg}"
        ];
        ExecStart = "/run/haproxy/haproxy -Ws -f /etc/haproxy.cfg -p /run/haproxy/haproxy.pid";
        # support reloading
        ExecReload = [
          "${cfg.package}/sbin/haproxy -c -f ${haproxyCfg}"
          "${pkgs.coreutils}/bin/ln -sf ${cfg.package}/sbin/haproxy /run/haproxy/haproxy"
          "${pkgs.coreutils}/bin/kill -USR2 $MAINPID"
        ];
        KillMode = "mixed";
        SuccessExitStatus = "143";
        Restart = "always";
        RestartSec = 3;
        RuntimeDirectory = "haproxy";
        # upstream hardening options
        User = cfg.user;
        Group = cfg.group;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        StateDirectory = "letsencrypt";
        LogsDirectory = "letsencrypt";
        ConfigurationDirectory = "letsencrypt";
        # needed in case we bind to port < 1024
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      };
    };

    users.users = lib.optionalAttrs (cfg.user == "haproxy") {
      haproxy = {
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "haproxy") {
      haproxy = {};
    };
  };
}
