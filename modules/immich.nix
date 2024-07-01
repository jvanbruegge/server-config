{ config, lib, pkgs, self, ... }:
let
  cfg = config.services.immich;
in with lib; {
  options.services.immich = {
    enable = mkEnableOption "Immich";
    package = mkPackageOption self.packages.${pkgs.stdenv.system} "immich" {};
    mediaLocation = mkOption {
      type = types.path;
      default = "/var/lib/immich";
    };
    environment = mkOption {
      type = types.submodule {
        freeformType = types.attrsOf types.str;
      };
      default = {};
    };
    secretsFile = mkOption {
      type = types.path;
    };
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
    };
    port = mkOption {
      type = types.port;
      default = 3001;
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
    };
    user = mkOption {
      type = types.str;
      default = "immich";
    };
    group = mkOption {
      type = types.str;
      default = "immich";
    };
    machine-learning.enable = mkEnableOption "immich-machine-learning" // { default = true; };
    database = {
      createDB = mkOption {
        type = types.bool;
        default = true;
      };
      name = mkOption {
        type = types.str;
        default = "immich";
      };
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
      };
      user = mkOption {
        type = types.str;
        default = "immich";
      };
      setupPgvectors = mkOption {
        type = types.bool;
        default = true;
      };
    };
    redis = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
      };
      serverName = mkOption {
        type = types.str;
        default = "immich";
      };
      port = mkOption {
        type = types.port;
        default = 6379;
      };
    };
  };

  config = mkIf cfg.enable {
    services.postgresql = {
      enable = mkIf cfg.database.createDB true;
      ensureDatabases = mkIf cfg.database.createDB [ cfg.database.name ];
      ensureUsers = mkIf cfg.database.createDB [ {
        name = cfg.database.user;
        ensureDBOwnership = true;
        ensureClauses.login = true;
      } ];
      extraPlugins = mkIf cfg.database.setupPgvectors (ps: with ps; [ pgvecto-rs ]);
      settings = mkIf cfg.database.setupPgvectors {
        shared_preload_libraries = [ "vectors.so" ];
        search_path = "\"$user\", public, vectors";
      };
    };
    systemd.services.postgresql.serviceConfig.ExecStartPost = mkIf cfg.database.setupPgvectors [ ''
      +${pkgs.bash}/bin/bash -c '${pkgs.sudo}/bin/sudo -i -u postgres psql -d "${cfg.user}" -c "CREATE EXTENSION IF NOT EXISTS vectors; CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE; ALTER SCHEMA vectors OWNER TO ${cfg.database.user}; GRANT SELECT ON TABLE pg_vector_index_stat TO ${cfg.database.user};"'
    ''];

    services.redis.servers = mkIf cfg.redis.enable {
      "${cfg.redis.serverName}" = {
        enable = true;
        port = cfg.redis.port;
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.immich-server = {
      description = "immich server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        REDIS_HOSTNAME = cfg.redis.host;
        DB_HOSTNAME = cfg.database.host;
        HOST = cfg.host;
        IMMICH_PORT = toString cfg.port;
        IMMICH_MEDIA_LOCATION = cfg.mediaLocation;
        DB_DATABASE_NAME = cfg.database.name;
      } // cfg.environment;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/server";
        EnvironmentFile = cfg.secretsFile;
        StateDirectory = "immich";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = 3;
      };
    };

    systemd.services.immich-machine-learning = mkIf cfg.machine-learning.enable {
      description = "immich machine learning";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package.machine-learning}/bin/machine-learning";
        CacheDirectory = "immich";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = 3;
      };
    };

    users.users = mkIf (cfg.user == "immich") {
      immich = {
        name = "immich";
        group = cfg.group;
        isSystemUser = true;
      };
    };
    users.groups = mkIf (cfg.group == "immich") {
      immich = {};
    };
  };
}
