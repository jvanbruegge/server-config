{ config, lib, pkgs, domain, email, ... }:

let
  cfg = config.services.haproxy;

  noNewlines = s: lib.strings.concatLines (builtins.filter (s: s != "") (lib.strings.splitString "\n" s));
  indentStr = s: lib.strings.concatLines (builtins.map (x: "  ${x}") (lib.strings.splitString "\n" s));

  mkFrontend = cfg: noNewlines ''
    mode ${cfg.mode}
    bind ${cfg.bind.address}:${builtins.toString cfg.bind.port}${lib.strings.optionalString (cfg.bind.interface != null) " interface ${cfg.bind.interface}"} ${cfg.bind.extraOptions}
    ${lib.strings.concatLines (lib.attrsets.mapAttrsToList (name: x: "acl ${name} ${x}") cfg.acls)}
    ${lib.strings.concatMapStringsSep "\n" (x: "http-request ${x}") cfg.httpRequest}
    ${cfg.extraConfig}
    ${lib.strings.concatMapStringsSep "\n" (x: "use_backend ${x}") cfg.useBackend}
    ${lib.strings.optionalString (cfg.defaultBackend != null) "default_backend ${cfg.defaultBackend}"}
  '';

  mkBackend = cfg: noNewlines ''
    mode ${cfg.mode}
    ${lib.strings.optionalString (cfg.timeout.client != null) "timeout client ${cfg.timeout.client}"}
    ${lib.strings.optionalString (cfg.timeout.server != null) "timeout server ${cfg.timeout.server}"}
    ${lib.strings.optionalString (cfg.timeout.connect != null) "timeout connect ${cfg.timeout.connect}"}
    ${lib.strings.concatMapStringsSep "\n" (x: "server ${x}") cfg.servers}
  '';

  mkHAProxyConfig = cfg: ''
    global
      # needed for hot-reload to work without dropping packets in multi-worker mode
      stats socket /run/haproxy/haproxy.sock mode 600 expose-fd listeners level user
      log stdout format raw local0 info

    defaults
      log global
      option httplog
      option forwardfor
      timeout connect 1d
      timeout client 1d
      timeout server 1d

    ${lib.strings.concatStrings (lib.attrsets.mapAttrsToList (name: x: "frontend ${name}\n${indentStr (mkFrontend x)}") cfg.frontends)}
    ${lib.strings.concatStrings (lib.attrsets.mapAttrsToList (name: x: "backend ${name}\n${indentStr (mkBackend x)}") cfg.backends)}
    ${cfg.extraConfig}
  '';

  haproxyCfg = pkgs.writeText "haproxy.conf" (mkHAProxyConfig cfg.settings);

  certDomains = lib.attrsets.attrValues (builtins.mapAttrs (name: c: "${c.subdomain}.${cfg.settings.domain}") config.ingress) ++ cfg.settings.extraDomains;
  certbotDomains = lib.strings.concatMapStringsSep "\\\n  " (s: "-d ${s}") certDomains;
  certbotCmd = address: port: ''
    ${pkgs.certbot}/bin/certbot certonly --standalone --cert-name ${cfg.settings.domain} \
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
      ${pkgs.coreutils}/bin/ln -sf /etc/letsencrypt/live/${cfg.settings.domain}/privkey.pem /etc/letsencrypt/live/${cfg.settings.domain}/fullchain.pem.key
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

      settings = mkOption {
        type = types.submodule {
          options = {
            extraConfig = mkOption {
              type = types.lines;
              default = "";
            };

            domain = mkOption {
              type = types.str;
              default = domain;
            };

            extraDomains = mkOption {
              type = types.listOf types.str;
              default = [];
            };

            defaultFrontends = mkOption {
              type = types.bool;
              default = true;
            };

            frontends = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  mode = mkOption {
                    type = types.enum [ "http" "tcp" ];
                    default = "http";
                  };

                  bind = mkOption {
                    type = types.submodule {
                      options = {
                        address = mkOption {
                          type = types.str;
                          default = "";
                        };

                        port = mkOption {
                          type = types.port;
                        };

                        interface = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                        };

                        extraOptions = mkOption {
                          type = types.separatedString " ";
                          default = "";
                        };
                      };
                    };
                  };

                  acls = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                  };

                  httpRequest = mkOption {
                    type = types.listOf types.str;
                    default = [];
                  };

                  useBackend = mkOption {
                    type = types.listOf types.str;
                    default = [];
                  };

                  defaultBackend = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                  };

                  extraConfig = mkOption {
                    type = types.lines;
                    default = "";
                  };
                };
              });
            };

            backends = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  mode = mkOption {
                    type = types.enum [ "http" "tcp" ];
                    default = "http";
                  };

                  timeout = mkOption {
                    type = types.submodule {
                      options = {
                        client = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                        };
                        server = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                        };
                        connect = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                        };
                      };
                    };
                    default = {
                      client = null;
                      server = null;
                      connect = null;
                    };
                  };

                  servers = mkOption {
                    type = types.listOf types.str;
                    default = [];
                  };
                };
              });
            };
          };
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

    systemd.timers.certbot = mkIf cfg.letsencrypt {
      description = "certbot restart";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "certbot.service";
        OnCalendar = "daily";
      };
    };

    services.haproxy.settings = {
      frontends = mkIf cfg.settings.defaultFrontends {
        https = {
           bind = {
            address = "*";
            port = 443;
            extraOptions = "ssl crt /etc/letsencrypt/live/${cfg.settings.domain}/fullchain.pem";
          };
          httpRequest = [ "set-header X-Forwarded-Proto https" ];
          useBackend = lib.attrsets.mapAttrsToList (name: x:
            "${name} if { hdr(host) -i ${x.subdomain}.${cfg.settings.domain} }"
          ) config.ingress;
        };

        http = mkIf cfg.letsencrypt {
          bind = {
            address = "*";
            port = 80;
          };
          acls.letsencrypt = "path_beg /.well-known/acme-challenge/";
          httpRequest = [ "redirect scheme https code 301 unless letsencrypt" ];
          useBackend = [ "certbot if letsencrypt" ];
        };

        stats = mkIf cfg.stats.enable {
          bind = {
            address = "127.0.0.1";
            port = cfg.stats.port;
          };
          extraConfig = ''
            stats enable
            stats uri /
            stats refresh 10s
          '';
        };
      };

      backends = builtins.mapAttrs (name: x: { servers = [ "${name} ${x.address}:${builtins.toString x.port}" ]; }) config.ingress
        // lib.attrsets.optionalAttrs cfg.letsencrypt {
          certbot.servers = [ "certbot 127.0.0.1:8403" ];
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
        RestartSec = 30;
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
