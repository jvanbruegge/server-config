{ pkgs, domain, config, ... }:
{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "shelly"
    ];
    customComponents = with pkgs.home-assistant-custom-components; [
      auth_oidc
    ];
    config = {
      default_config = {};
      http = {
        server_host = "127.0.0.1";
        trusted_proxies = [ "127.0.0.1" "::1" ];
        use_x_forwarded_for = true;
      };
      "automation ui" = "!include automations.yaml";
      auth_oidc = {
        client_id = "9QlffQMkanh5cR3pMOT2Df5aOCoL4E7uJ8fxkSv2";
        discovery_url = "https://authentik.${domain}/application/o/home-assistant/.well-known/openid-configuration";
        display_name = "Authentik";
        features.default_redirect = true;
        roles.admin = "jellyfin-admins";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass"
  ];

  ingress.home-assistant = {
    subdomain = "home-assistant";
    port = 8123;
  };
}
