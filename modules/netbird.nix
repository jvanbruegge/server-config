{ config, lib, pkgs, domain, email, nixpkgs-authentik, ... }:

let
  cfg = config.services.netbird;
in with lib; {
  disabledModules = [ "services/networking/netbird.nix" ];

  options.services.netbird = {
    enable = mkEnableOption (lib.mdDoc "netbird, the private WireGuard®-based mesh network with SSO/MFA and simple access controls.");
    package = mkPackageOption pkgs "netbird" {
      default = [ "netbird" ];
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
    };
    # TODO: Expose more options
    createCoturn = mkOption {
      type = types.bool;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    /*environment.etc."netbird/management.json".text = builtins.toJSON {
      Stuns = [{
        Proto = "udp";
        URI = "stun:
      }]
    };*/
    networking.firewall = {
      allowedUDPPortRanges = with config.services.coturn; [ {
        from = min-port;
        to = max-port;
      } ];
      allowedUDPPorts = [ 3478 ];
      allowedTCPPortRanges = [ ];
      allowedTCPPorts = [ 3478 ];
    };

    services.coturn = mkIf cfg.createCoturn {
      enable = true;
      lt-cred-mech = true;
      no-cli = true;
      extraConfig = ''
        fingerprint
        no-software-attribute
        external-ip=${domain}
      '';
    };

    systemd.services.coturn.serviceConfig = {
      EnvironmentFile = "/run/secrets/netbird";
      ExecStart = lib.mkForce ''
        ${pkgs.coturn}/bin/turnserver -c /run/coturn/turnserver.cfg --user="''${COTURN_USER}:''${COTURN_PASSWORD}"
      '';
    };

    /*systemd.services.netbird-management = {
      description = "netbird management server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/netbird-mgmt --log-file console --disable-anonymous-metrics=true";
        EnvironmentFile = "/run/secrets/netbird";
        User = "netbird";
        Group = "netbird";
        Restart = "always";
        RestartSec = 3;
        NoNewPrivileges = true;
        RuntimeDirectory = "netbird";
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
        ConfigurationDirectory = "netbird";
      };
    };

    systemd.services.netbird-signal = {
      description = "netbird signal server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/netbird-signal --log-file console";
        EnvironmentFile = "/run/secrets/netbird";
        User = "netbird";
        Group = "netbird";
        Restart = "always";
        RestartSec = 3;
        RuntimeDirectory = "netbird";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
      };
    };*/
  };
}
