{ pkgs, ...}: {

  imports = [
    ./configuration.nix
  ];

  environment.systemPackages = with pkgs; [
    neovim
    borgbackup
    tmux
  ];

}
