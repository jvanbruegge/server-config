{ pkgs, lib, config, domain, utils, netbird, ... }:
let
  NETBIRD_DOMAIN = "netbird.${domain}";
  client_id = "kLVxL9B0tZNwR8VYWWE8DHoXpvjLDnErpkgTEQDa";
in {
  disabledModules = [
    "services/networking/netbird/server.nix"
    "services/networking/netbird/signal.nix"
    "services/networking/netbird/management.nix"
    "services/networking/netbird/dashboard.nix"
    "services/networking/netbird/coturn.nix"
  ];

  imports = [
    "${netbird}/nixos/modules/services/networking/netbird/server.nix"
  ];

  documentation.nixos.enable = false;

  services.netbird.enable = true;

  users.users.netbird = {
    name = "netbird";
    group = "netbird";
    isSystemUser = true;
  };
  users.groups.netbird = {};

  sops.secrets = {
    netbird_authentik_password.owner = "netbird";
    turn_secret.owner = "netbird";
    relay_secret.owner = "netbird";
    netbird_encryption_key.owner = "netbird";
    coturn = {
      owner = "turnserver";
      group = "netbird";
      mode = "0440";
    };
  };

  ingress.netbird = {
    subdomain = "netbird";
    port = 8080;
    proxyProtocol = true;
  };

  services.nginx.defaultListen = [ {
    addr = "127.0.0.1";
    port = 8080;
    proxyProtocol = true;
  } ];

  services.nginx.virtualHosts."${NETBIRD_DOMAIN}" = {
    locations."/" = lib.mkForce {
      root = config.services.netbird.server.dashboard.finalDrv;
      tryFiles = "$uri $uri.html $uri/ =404";
    };
    forceSSL = false;
  };

  systemd.services.netbird-relay.script =
    let cfg = config.services.netbird.server.relay;
    in lib.mkForce ''
      export NB_AUTH_SECRET="$(<${cfg.authSecretFile})"
      ${lib.getExe' cfg.package "netbird-relay"} -H 127.0.0.1:9400
    '';

  services.netbird.server = {
    enable = true;
    domain = NETBIRD_DOMAIN;

    relay = {
      enable = true;
      authSecretFile = "/run/secrets/relay_secret";
      package = pkgs.netbird-relay;
      settings = {
        NB_EXPOSED_ADDRESS = "rels://netbird.cerberus-systems.de:443/relay";
      };
    };
    signal = {
      port = 10000;
      package = pkgs.netbird-signal;
    };
    proxy = {
      domain = NETBIRD_DOMAIN;
      enableNginx = true;
      managementAddress = "[::1]:10001";
      signalAddress = "[::1]:10000";
      relayAddress = "[::1]:33080";
    };

    management = {
      port = 10001;
      package = pkgs.netbird-management;

      singleAccountModeDomain = "net.${domain}";
      dnsDomain = "net.${domain}";

      oidcConfigEndpoint = "https://authentik.${domain}/application/o/netbird/.well-known/openid-configuration";
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
        Signal.URI = "${NETBIRD_DOMAIN}:443";
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

        HttpConfig = {
          AuthAudience = client_id;
          AuthUserIDClaim = "sub";
        };

        PKCEAuthorizationFlow.ProviderConfig = {
          Audience = client_id;
          ClientID = client_id;
          ClientSecret = "";
          AuthorizationEndpoint = "https://authentik.${domain}/application/o/authorize/";
          TokenEndpoint = "https://authentik.${domain}/application/o/token/";
          RedirectURLs = [ "http://localhost:53000" ];
        };
        DataStoreEncryptionKey._secret = "/run/secrets/netbird_encryption_key";
      };
    };

    coturn = {
      enable = true;
      passwordFile = "/run/secrets/coturn";
    };

    dashboard = {
      enableNginx = true;
      domain = "localhost";
      package = pkgs.netbird-dashboard;
      settings = {
        AUTH_AUTHORITY = "https://authentik.${domain}/application/o/netbird/";
        AUTH_SUPPORTED_SCOPES = "openid profile email offline_access api";
        AUTH_AUDIENCE = client_id;
        AUTH_CLIENT_ID = client_id;
      };
    };
  };
}
