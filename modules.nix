{
  imports = [
    ./settings.nix
    ./modules/postgres.nix
    ./modules/haproxy.nix
    ./modules/authentik.nix
    ./modules/immich.nix
  ];
}
