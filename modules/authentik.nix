{ config, lib, pkgs, domain, email, ... }:

let
  cfg = config.services.authentik;
in with lib; {
  options.services.authentik = {
    enable = mkEnableOption (lib.mdDoc "authentik, the open-source Identity Provider that emphasizes flexibility and versatility");
    package = mkPackageOption pkgs "authentik" {
      default = [ "authentik" ];
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
    };
    outposts.ldap = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption (lib.mdDoc "the authentik ldap outpost");
          package = mkPackageOption pkgs "authentik-outposts.ldap" {
            default = [ "authentik-outposts" "ldap" ];
          };
          host = mkOption {
            type = types.str;
            default = "127.0.0.1";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.authentik-server = {
      description = "authentik server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/ak server";
        EnvironmentFile = "/run/secrets/authentik";
        User = "authentik";
        Group = "authentik";
        Restart = "always";
        RestartSec = 3;
        RuntimeDirectory = "authentik";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        ConfigurationDirectory = "authentik";
      };
    };

    systemd.services.authentik-worker = {
      description = "authentik worker";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/ak worker";
        EnvironmentFile = "/run/secrets/authentik";
        User = "authentik";
        Group = "authentik";
        Restart = "always";
        RestartSec = 3;
        RuntimeDirectory = "authentik";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        ConfigurationDirectory = "authentik";
      };
    };

    systemd.services.authentik-ldap-outpost = mkIf cfg.outposts.ldap.enable {
      description = "authentik ldap outpost";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.outposts.ldap.package}/bin/ldap";
        EnvironmentFile = "/run/secrets/authentik-ldap";
        Environment = [
          "AUTHENTIK_LISTEN__LDAPS=127.0.0.1:6636"
          "AUTHENTIK_LISTEN__LDAP=127.0.0.1:3389"
          "AUTHENTIK_HOST=https://authentik.vps-dev.cerberus-systems.de/"
        ];
        User = "authentik";
        Group = "authentik";
        Restart = "always";
        RestartSec = 3;
        RuntimeDirectory = "authentik";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        ConfigurationDirectory = "authentik";
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      };
    };

    services.redis.servers.authentik = {
      enable = true;
      port = 6379;
    };
  };
}
