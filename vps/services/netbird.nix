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

  services.netbird.server = {
    enable = true;
    domain = NETBIRD_DOMAIN;

    relay = {
      authSecretFile = "/run/secrets/relay_secret";
      package = netbird.legacyPackages.x86_64-linux.netbird-server;
      settings.NB_EXPOSED_ADDRESS = "rels://netbird.cerberus-systems.de:443";
    };
    signal = {
      port = 10000;
      package = netbird.legacyPackages.x86_64-linux.netbird-server;
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
      package = netbird.legacyPackages.x86_64-linux.netbird-server;

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
      package = pkgs.netbird-dashboard.overrideAttrs (prev: rec {
        version = "2.11.0";
        src = pkgs.fetchFromGitHub {
          owner = "netbirdio";
          repo = "dashboard";
          tag = "v${version}";
          hash = "sha256-JHpFxWhN5ZXd0Yn0AY98pl/nrby+RsWO6l8qUospkak=";
        };
        npmDepsHash = "sha256-TELyc62l/8IaX9eL2lxRFth0AAZ4LXsV2WNzXSHRnTw=";
        npmDeps = pkgs.fetchNpmDeps {
          inherit src;
          name = "${prev.pname}-${version}-npm-deps";
          hash = npmDepsHash;
        };
      });
      settings = {
        AUTH_AUTHORITY = "https://authentik.${domain}/application/o/netbird/";
        AUTH_SUPPORTED_SCOPES = "openid profile email offline_access api";
        AUTH_AUDIENCE = client_id;
        AUTH_CLIENT_ID = client_id;
      };
    };
  };
}
