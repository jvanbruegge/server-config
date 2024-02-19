domain: path: config: {
  encryption.mode = "none";
  environment.BORG_RSH = "ssh -i /run/secrets/borg_ssh_key";
  repo = "ssh://borg@nas.net.${domain}/mnt/backup/borg/vps-dev/${path}";
  compression = "auto,zstd";
  startAt = "daily";
  prune.keep = {
    daily = 7;
    weekly = 4;
    monthly = 6;
  };
} // config
