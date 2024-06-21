{ config, lib, pkgs, self, ... }:
let
  cfg = config.services.immich;
in with lib; {
  options.services.immich = {
    enable = mkEnableOption "Immich";
  };

  config = mkIf cfg.enable {
    services.postgresql = {
      package = pkgs.postgresql_16;
      extraPlugins = ps: with ps; [ pgvecto-rs ];
      settings = {
        shared_preload_libraries = [ "vectors.so" ];
        search_path = "\"$user\", public, vectors";
      };
    };
    systemd.services.postgresql.serviceConfig.ExecStartPost = [ ''
      +${pkgs.bash}/bin/bash -c '${pkgs.sudo}/bin/sudo -i -u postgres psql -d immich -c "CREATE EXTENSION IF NOT EXISTS vectors; CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE; ALTER SCHEMA vectors OWNER TO immich; GRANT SELECT ON TABLE pg_vector_index_stat TO immich;"'
    ''];

    services.redis.servers.immich = {
      enable = true;
      port = 6379;
    };

    networking.firewall.allowedTCPPorts = [ 3001 ];

    systemd.services.immich-server = {
      description = "immich server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        REDIS_HOSTNAME = "127.0.0.1";
        DB_HOSTNAME = "127.0.0.1";
        HOST = "0.0.0.0";
        IMMICH_PORT = "3001";
        LOG_LEVEL = "verbose";
        IMMICH_MEDIA_LOCATION = "/var/lib/immich";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${self.packages.x86_64-linux.immich}/bin/server";
        EnvironmentFile = "/run/secrets/immich";
        StateDirectory = "immich";
        User = "immich";
        Group = "immich";
        Restart = "always";
        RestartSec = 3;
      };
    };

    systemd.services.immich-machine-learning = {
      description = "immich machine learning";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        LOG_LEVEL = "verbose";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${self.packages.x86_64-linux.immich.machine-learning}/bin/machine-learning";
        #EnvironmentFile = "/run/secrets/immich";
        #StateDirectory = "immich";
        CacheDirectory = "immich";
        User = "immich";
        Group = "immich";
        Restart = "always";
        RestartSec = 3;
      };
    };

    database.immich = {};

    users.users.immich = {
      name = "immich";
      group = "immich";
      isSystemUser = true;
    };
    users.groups.immich = {};

    sops.secrets.immich = {};
  };
}
