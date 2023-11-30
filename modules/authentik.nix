{ config, lib, pkgs, domain, email, nixpkgs-authentik, ... }:

let
  cfg = config.services.authentik;
in with lib; {
  options.services.authentik = {
    enable = mkEnableOption (lib.mdDoc "authentik, the open-source Identity Provider that emphasizes flexibility and versatility");
    package = mkPackageOption nixpkgs-authentik.legacyPackages.x86_64-linux "authentik" {
      default = [ "authentik" ];
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

    services.redis.servers.authentik = {
      enable = true;
      port = 6379;
    };
  };
}
