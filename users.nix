{ ... }:
let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINO/Wpf4KuBlZFM7Jcw39X2yqTZHOJeCYJ37+b+Cle8b jan@Jan-Work";
  key2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTiDPq62zteYB6/ZNqgpGckqqeg/d75+mDL7/euoilL jan@nixos";
in {
  users.users.root.openssh.authorizedKeys.keys = [ key key2 ];

  users.users.jan = {
    name = "jan";
    isNormalUser = true;
    group = "users";
    extraGroups = [ "wheel" ];
    createHome = true;

    openssh.authorizedKeys.keys = [ key key2 ];
  };
}
