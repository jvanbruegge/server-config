{ pkgs, ... }:
{
  nix = {
    nixPath = [ "nixpkgs=${pkgs.path}" ];
    extraOptions = "experimental-features = nix-command flakes";
  };

  environment.systemPackages = with pkgs; [
    nettools
  ];

  _module.args.email = "jan@vanbruegge.de";
}
