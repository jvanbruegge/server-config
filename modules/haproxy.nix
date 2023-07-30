{ config, lib, pkgs, ... }:

let
  cfg = config.services.haproxy;

  haproxyCfg = pkgs.writeText "haproxy.conf" ''
    global
      # needed for hot-reload to work without dropping packets in multi-worker mode
      stats socket /run/haproxy/haproxy.sock mode 600 expose-fd listeners level user

    ${cfg.config}
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

      config = mkOption {
        type = types.lines;
        description = lib.mdDoc ''
          Contents of the HAProxy configuration file,
          {file}`haproxy.conf`.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    # configuration file indirection is needed to support reloading
    environment.etc."haproxy.cfg".source = haproxyCfg;

    systemd.services.haproxy = {
      description = "HAProxy";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStartPre = [
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
        RuntimeDirectory = "haproxy";
        # upstream hardening options
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        # needed in case we bind to port < 1024
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      };
    };
  };
}
