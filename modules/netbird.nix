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
    environment.etc."netbird/management.json".text = builtins.toJSON {
      Stuns = [{
        Proto = "udp";
        URI = "stun:${domain}:3478";
        Username = "";
        Password = null;
      }];
      TURNConfig = {
        Turns = [ {
          Proto = "udp";
          URI = "turn:${domain}:3478";
          Username = "$COTURN_USER";
          Password = "$COTURN_PASSWORD";
        } ];
        CredentialTTL = "12h";
        Secret = "secret";
        TimeBasedCredentials = false;
      };
      Signal = {
        Proto = "https";
        URI = "netbird.${domain}";
        Username = "";
        Password = null;
      };
      Datadir = "";
      DataStoreEncryptionKey = "$DATASTORE_ENC_KEY";
      StoreConfig = {
        Engine = "jsonfile";
      };
      HttpConfig = {
        Address = "127.0.0.1:10001";
        AuthIssuer = "https://authentik.${domain}/application/o/netbird/";
        AuthAudience = "$NETBIRD_CLIENT_ID";
        AuthKeysLocation = "https://authentik.${domain}/application/o/netbird/jwks/";
        AuthUserIdClaim = "";
        CertFile = "";
        CertKey = "";
        IdpSignKeyRefreshEnabled = false;
        OIDCConfigEndpoint = "https://authentik.${domain}/application/o/netbird/.well-known/openid-configuration";
      };
      IdpManagerConfig = {
        ManagerType = "authentik";
        ClientConfig = {
          Issuer = "https://authentik.${domain}/application/o/netbird/";
          TokenEndpoint = "https://authentik.${domain}/application/o/token/";
          ClientID = "$NETBIRD_CLIENT_ID";
          ClientSecret = "$NETBIRD_CLIENT_SECRET";
          GrantType = "client_credentials";
        };
        ExtraConfig = {
          Username = "netbird";
          Password = "$NETBIRD_AUTHENTIK_PASSWORD";
        };
      };
      PKCEAuthorizationFlow = {
        ProviderConfig = {
          Audience = "";
          ClientID = "$NETBIRD_CLIENT_ID";
          ClientSecret = "$NETBIRD_CLIENT_SECRET";
          Domain = "";
          AuthorizationEndpoint = "https://authentik.${domain}/application/o/authorize/";
          TokenEndpoint = "https://authentik.${domain}/application/o/token/";
          Scope = "openid profile email offline_access api";
          RedirectURLs = [ "http://localhost:53000" ];
          UseIDToken = false;
        };
      };
    };

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

    users.users.netbird = {
      name = "netbird";
      group = "netbird";
      isSystemUser = true;
    };
    users.groups.netbird = {};

    systemd.services.netbird-management = {
      description = "netbird management server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = [
          "${pkgs.envsubst}/bin/envsubst -i /etc/netbird/management.json -o /run/netbird/management.json"
        ];
        ExecStart = "${cfg.package}/bin/netbird-mgmt management --log-file console --disable-anonymous-metrics=true --port 10001 --config /run/netbird/management.json --log-level debug --disable-single-account-mode";
        EnvironmentFile = "/run/secrets/netbird";
        User = "netbird";
        Group = "netbird";
        Restart = "always";
        RestartSec = 3;
        NoNewPrivileges = true;
        RuntimeDirectory = "netbird";
        StateDirectory = "netbird";
        ConfigurationDirectory = "netbird";
        CacheDirectory = "netbird";
        LogsDirectory = "netbird";
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        SystemCallFilter= "~@cpu-emulation @keyring @module @obsolete @raw-io @reboot @swap @sync";
      };
    };

    systemd.services.netbird-signal = {
      description = "netbird signal server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/netbird-signal run --port 10000 --log-file console";
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
    };
  };
}
