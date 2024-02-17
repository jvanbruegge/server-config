{ pkgs, lib, domain, config, ... }:
let
  NETBIRD_DOMAIN = "netbird.${domain}";
in {
  services.netbird-server = {
    enable = true;

    enableNginx = true;
    enableCoturn = true;
    setupAutoOidc = true;
    enableACME = false;

    ports = {
      signal = 10000;
      management = 10001;
    };

    management.dnsDomain = "net.${domain}";

    idpManagerExtraConfig = {
      Username = "netbird";
      Password = "$NETBIRD_AUTHENTIK_PASSWORD";
    };

    settings = {
      inherit NETBIRD_DOMAIN;
      NETBIRD_AUTH_AUDIENCE = "$NETBIRD_AUTH_CLIENT_ID";
      NETBIRD_AUTH_CLIENT_ID = "$NETBIRD_AUTH_CLIENT_ID";
      NETBIRD_AUTH_CLIENT_SECRET = "";
      NETBIRD_AUTH_DEVICE_AUTH_CLIENT_ID="$NETBIRD_AUTH_CLIENT_ID";
      NETBIRD_AUTH_DEVICE_AUTH_AUDIENCE="$NETBIRD_AUTH_CLIENT_ID";
      NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT = "https://authentik.${domain}/application/o/netbird/.well-known/openid-configuration";
      NETBIRD_AUTH_PKCE_USE_ID_TOKEN = false;
      NETBIRD_MGMT_IDP = "authentik";
      NETBIRD_AUTH_DEVICE_AUTH_PROVIDER = "hosted";
      NETBIRD_IDP_MGMT_CLIENT_ID = "$NETBIRD_AUTH_CLIENT_ID";
      NETBIRD_AUTH_SUPPORTED_SCOPES = [ "openid" "profile" "email" "offline_access" "api" "groups" ];
      TURN_PASSWORD = "$TURN_PASSWORD";
      TURN_USER = "self";
    };
  };

  systemd.services.netbird-setup = {
    serviceConfig.EnvironmentFile = [ "/run/secrets/netbird" ];
  };

  services.coturn.extraConfig = lib.mkForce ''
    fingerprint
    no-software-attribute
    external-ip=${NETBIRD_DOMAIN}
  '';

  systemd.services.coturn.serviceConfig = {
    EnvironmentFile = "/run/secrets/netbird";
    ExecStart = lib.mkForce ''
      ${pkgs.coturn}/bin/turnserver -c /run/coturn/turnserver.cfg --user="''${TURN_USER}:''${TURN_PASSWORD}"
    '';
  };

  services.nginx = {
    enable = true;
    defaultListen = [ {
      addr = "127.0.0.1";
      port = 8080;
    } ];
  };

  sops.secrets.netbird = {};
}
