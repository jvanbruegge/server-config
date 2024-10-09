{ linkwarden, ... }:

{
  imports = [
    "${linkwarden}/nixos/modules/services/web-apps/linkwarden.nix"
  ];

  services.linkwarden = {
    enable = true;
    package = linkwarden.legacyPackages.x86_64-linux.linkwarden.overrideAttrs (prev: {
      postPatch = ''
        ${prev.postPatch}

        substituteInPlace pages/api/v1/auth/*nextauth*.ts \
          --replace-fail 'AUTHENTIK_ISSUER,' 'AUTHENTIK_ISSUER, httpOptions: { timeout: Number(process.env.LINKWARDEN_OAUTH_TIMEOUT) },'
      '';
    });
    storageLocation = "/data/linkwarden";
    secretsFile = "/run/secrets/linkwarden";
    host = "0.0.0.0";
    openFirewall = true;
    database = {
      createDB = false;
      host = "localhost";
    };
    environment = {
      NEXTAUTH_URL = "https://linkwarden.cerberus-systems.de/api/v1/auth";
      RE_ARCHIVE_LIMIT = "0";
      NEXT_PUBLIC_CREDENTIALS_ENABLED = "false";
      NEXT_PUBLIC_AUTHENTIK_ENABLED = "true";
      AUTHENTIK_ISSUER = "https://authentik.cerberus-systems.de/application/o/linkwarden";
      LINKWARDEN_OAUTH_TIMEOUT = "30000";
    };
  };

  database.linkwarden = {};
  sops.secrets.linkwarden = {};
}
