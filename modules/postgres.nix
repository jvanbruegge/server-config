{ config, lib, pkgs, domain, email, nixpkgs-authentik, ... }:

let
  cfg = config.database;
in with lib; {
  options.database = mkOption {
    type = types.attrsOf (types.submodule {
      options = { };
    });
  };

  config = {
    services.postgresql = {
      enable = true;
      ensureDatabases = builtins.attrNames cfg;
      ensureUsers = attrsets.mapAttrsToList (name: opts: {
        inherit name;
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }) cfg;
    };

    sops.secrets.postgresql = {};

    systemd.services.postgresql.serviceConfig.ExecStartPost = [
      "+${pkgs.bash}/bin/bash -x ${../scripts/set_postgres_passwords.sh} ${pkgs.sudo}/bin/sudo"
    ];
  };
}
