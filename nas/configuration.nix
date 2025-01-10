{ ... }:
{
  imports = [
    ./services.nix
    ../settings.prod.nix
  ];

  _module.args.server = "nas";

  services.openssh.enable = true;

  security.sudo.configFile = ''
    Defaults:root,%wheel env_keep+=LOCALE_ARCHIVE
    Defaults:root,%wheel env_keep+=NIX_PATH
    Defaults lecture = never
  '';
  time.timeZone = "Europe/Berlin";

  users = import ../users.nix;

  sops = {
    defaultSopsFile = ../secrets/nas.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  services.resolved.enable = true;
  networking.nameservers = [ "1.1.1.1#one.one.one.one" "1.0.0.1#one.one.one.one" ];
  networking.hostName = "nas";

  nix.settings."trusted-users" = [ "root" "@wheel" ];

  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "24.11";
}
