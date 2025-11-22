{ domain, ... }:
{
  services.opencloud = {
    enable = true;
    url = "https://cloud.caladan.${domain}";
    stateDir = "/data/opencloud";
    environment = {
      OC_OIDC_ISSUER = "https://authentik.${domain}/application/o/opencloud-web/";
      OC_EXCLUDE_RUN_SERVICES = "idp";
      PROXY_TLS = "false";
      PROXY_USER_OIDC_CLAIM = "preferred_username";
      PROXY_USER_CS3_CLAIM = "username";
      PROXY_CSP_CONFIG_FILE_LOCATION = "/etc/opencloud/csp.yaml";
    };
    settings = {
      web.web.config.oidc.scope = "openid profile email";
      proxy = {
        auto_provision_accounts = true;
        oidc.rewrite_well_known = true;
        role_assignment = {
          driver = "oidc";
          oidc_role_mapper = {
            role_claim = "groups";
            role_mapping = [
              {
                role_name = "admin";
                claim_value = "jellyfin-admins";
              }
              {
                role_name = "user";
                claim_value = "partner";
              }
            ];
          };
        };
      };
      csp.directives = {
        child-src = [ "'self'" ];
        connect-src = [
          "'self'"
          "blob:"
          "https://authentik.${domain}"
          "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
          "https://update.opencloud.eu/"
        ];
        default-src = [ "'none'" ];
        font-src = [ "'self'"];
        frame-ancestors = [ "'self'" ];
        frame-src = [
          "'self'"
          "blob:"
          "https://embed.diagrams.net/"
        ];
        img-src = [
          "'self'"
          "data:"
          "blob:"
          "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
        ];
        manifest-src = [ "'self'" ];
        media-src = [ "'self'" ];
        object-src = [
          "'self'"
          "blob:"
        ];
        script-src = [
          "'self'"
          "'unsafe-inline'"
          "'unsafe-eval'"
          "https://authentik.${domain}"
        ];
        style-src = [
          "'self'"
          "'unsafe-inline'"
        ];
      };
    };
  };

  ingress.cloud = {
    subdomain = "cloud";
    port = 9200;
  };
}
