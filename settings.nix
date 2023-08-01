{ pkgs, ... }:
{
  nix = {
    nixPath = [ "nixpkgs=${pkgs.path}" ];
    extraOptions = "experimental-features = nix-command flakes";
  };

  _module.args.email = "jan@vanbruegge.de";
}
