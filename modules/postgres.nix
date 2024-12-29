{ config, lib, pkgs, domain, server, ... }:

let
  cfg = config.database;
in with lib; {
  options.database = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        superuser = mkOption {
          type = types.bool;
          default = false;
        };
      };
    });
    default = {};
  };

  config = mkIf (builtins.attrNames cfg != []) {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      ensureDatabases = builtins.attrNames cfg;
      ensureUsers = attrsets.mapAttrsToList (name: opts: {
        inherit name;
        ensureDBOwnership = true;
        ensureClauses = {
          login = true;
          superuser = opts.superuser;
        };
      }) cfg;
    };

    sops.secrets.postgresql = {};

    systemd.services.postgresql.serviceConfig.ExecStartPost = [
      "+${pkgs.bash}/bin/bash -x ${../scripts/set_postgres_passwords.sh} ${pkgs.sudo}/bin/sudo"
    ];

    services.postgresqlBackup = {
      enable = true;
      startAt = "*-*-* 23:00:00";
    };

    services.borgbackup.jobs.postgresql = import ../backup.nix domain server "postgresql" {
      paths = [ "/var/backup/postgresql" ];
    };
  };
}
