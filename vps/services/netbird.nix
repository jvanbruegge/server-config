{ pkgs, lib, domain, utils, ... }:
let
  NETBIRD_DOMAIN = "netbird.${domain}";
  client_id = "kLVxL9B0tZNwR8VYWWE8DHoXpvjLDnErpkgTEQDa";
in {
  sops.secrets = {
    netbird_authentik_password.owner = "netbird";
    turn_secret.owner = "netbird";
    coturn = {
      owner = "turnserver";
      group = "netbird";
      mode = "0440";
    };
  };

  services.haproxy.settings = {
    extraDomains = [
      "netbird.${domain}"
    ];
    frontends.https = {
      useBackend = [
        "netbird-signal if { path_beg /signalexchange.SignalExchange/ } { hdr(host) -i netbird.${domain} }"
        "netbird-management if { path_beg /management.ManagementService/ } { hdr(host) -i netbird.${domain} }"
        "netbird-management if { path_beg /api } { hdr(host) -i netbird.${domain} }"
        "netbird-dashboard if { hdr(host) -i netbird.${domain} }"
      ];
      httpRequest = [
        "set-log-level silent if { path_beg /signalexchange.SignalExchange/ } { hdr(host) -i netbird.${domain} }"
      ];
    };
    backends = {
      netbird-dashboard.servers = [ "netbird 127.0.0.1:8080" ];
      netbird-signal = {
        timeout.client = "3600s";
        timeout.server = "3600s";
        servers = [ "netbird-signal 127.0.0.1:10000 check proto h2" ];
      };
      netbird-management.servers = [ "netbird-management 127.0.0.1:10001 check proto h2" ];
    };
  };

  services.netbird = {
    enable = true;

    server = {
      management = {
        enable = true;
        port = 10001;
        oidcConfigEndpoint = "https://authentik.${domain}/application/o/netbird/.well-known/openid-configuration";
        domain = NETBIRD_DOMAIN;
        turnDomain = NETBIRD_DOMAIN;
        dnsDomain = "net.${domain}";
        singleAccountModeDomain = "net.${domain}";

        settings = {
          TURNConfig = {
            Turns = [ {
              Proto = "udp";
              URI = "turn:${NETBIRD_DOMAIN}:3478";
              Username = "netbird";
              Password._secret = "/run/secrets/coturn";
            }];

            Secret._secret = "/run/secrets/turn_secret";
          };

          DataStoreEncryptionKey = null;

          HttpConfig = {
            AuthAudience = client_id;
            AuthUserIDClaim = "sub";
          };

          IdpManagerConfig = {
            ManagerType = "authentik";
            ClientConfig = {
              Issuer = "https://authentik.${domain}/application/o/netbird/";
              ClientID = client_id;
              TokenEndpoint = "https://authentik.${domain}/application/o/token/";
              ClientSecret = "";
            };
            ExtraConfig = {
              Password._secret = "/run/secrets/netbird_authentik_password";
              Username = "netbird";
            };
          };

          PKCEAuthorizationFlow.ProviderConfig = {
            Audience = client_id;
            ClientID = client_id;
            ClientSecret = "";
            AuthorizationEndpoint = "https://authentik.${domain}/application/o/authorize/";
            TokenEndpoint = "https://authentik.${domain}/application/o/token/";
            RedirectURLs = [ "http://localhost:53000" ];
          };
        };
      };

      signal = {
        enable = true;
        port = 10000;
        domain = NETBIRD_DOMAIN;
      };

      dashboard = {
        enable = true;
        enableNginx = lib.mkForce true;
        domain = NETBIRD_DOMAIN;
        managementServer = "https://${NETBIRD_DOMAIN}";
        settings = {
          AUTH_AUTHORITY = "https://authentik.${domain}/application/o/netbird/";
          AUTH_SUPPORTED_SCOPES = "openid profile email offline_access api";
          AUTH_AUDIENCE = client_id;
          AUTH_CLIENT_ID = client_id;
        };
      };

      coturn = {
        enable = true;
        passwordFile = "/run/secrets/coturn";
        domain = NETBIRD_DOMAIN;
      };
    };
  };

  users.users.netbird = {
    name = "netbird";
    group = "netbird";
    isSystemUser = true;
  };
  users.groups.netbird = {};

  systemd.services.netbird-management.serviceConfig = {
    User = "netbird";
    Group = "netbird";
  };
  systemd.services.netbird-signal.serviceConfig = {
    User = "netbird";
    Group = "netbird";
    ExecStart = lib.mkForce (utils.escapeSystemdExecArgs [
      (lib.getExe' pkgs.netbird "netbird-signal")
      "run"
      # Port to listen on
      "--port"
      "10000"
      # Log to stdout
      "--log-file"
      "console"
      # Log level
      "--log-level"
      "INFO"
      "--metrics-port"
      "9091"
    ]);
  };

  security.acme.certs = lib.mkForce {};

  services.nginx.virtualHosts."${NETBIRD_DOMAIN}".listen = [ {
    addr = "127.0.0.1";
    port = 8080;
  } ];

}
