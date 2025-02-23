{ pkgs, ... }:
{
  imports = [
    ./services.nix
    ../settings.prod.nix
    ../users.nix
  ];

  _module.args.server = "nas";

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
  ];

  security.sudo.configFile = ''
    Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
    Defaults:root,%wheel env_keep+=NIX_PATH
    Defaults lecture = never
  '';
  time.timeZone = "Europe/Berlin";

  sops = {
    defaultSopsFile = ../secrets/nas.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  users.users.borg = {
    home = "/home/borg";
    createHome = true;
  };
  services.borgbackup.repos = {
    vps = {
      allowSubRepos = true;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINOqoqdYDfG046ljQazMwBGQ8l3o/4jRNLrmHuOrA30K"
      ];
      path = "/mnt/backup/borg/vps";
    };
    nas = {
      allowSubRepos = true;
      authorizedKeys = [ "" ];
      path = "/mnt/backup/borg/nas";
    };
  };

  services.resolved.enable = true;
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  networking.hostName = "nas";

  nix.settings."trusted-users" = [ "root" "@wheel" ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "24.11";
}
