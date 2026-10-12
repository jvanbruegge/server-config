{ pkgs, domain, config, ... }:
{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "shelly"
    ];
    customComponents = with pkgs.home-assistant-custom-components; [
      auth_oidc
      dwd
    ];
    config = {
      default_config = {};
      "automation ui" = "!include automations.yaml";
      auth_oidc = {
        client_id = "9QlffQMkanh5cR3pMOT2Df5aOCoL4E7uJ8fxkSv2";
        discovery_url = "https://authentik.${domain}/application/o/home-assistant/.well-known/openid-configuration";
        display_name = "Authentik";
        features.default_redirect = true;
        roles.admin = "jellyfin-admins";
      };
      template = [
        {
          trigger = [
            {
              platform = "time_pattern";
              hours = "/1"; #Update every hour
            }
            {
              platform = "homeassistant";
              event = "start";
            }
          ];
          action = [{
            service = "weather.get_forecasts";
            data.type = "daily";
            target.entity_id = "weather.munchen_stadt";
            response_variable = "daily";
          }];
          sensor = [{
            name = "Weather Daily Forecast";
            unique_id = "weather_daily_forecast";
            state = "{{ daily['weather.munchen_stadt'].forecast[0].temperature }}";
            attributes.forecast = "{{ daily['weather.munchen_stadt'].forecast }}";
          }];
        }
      ];
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
