{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ ];

  boot = {
    loader.grub.enable = true;
    loader.grub.device   = "/dev/sda";
    supportedFilesystems = ["nfs4"];
  };

  boot.initrd.availableKernelModules = [ "ata_piix" "ahci" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/b5daa9c0-8e58-444f-b35d-601d19c9bfda";
      fsType = "ext4";
    };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s3.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s8.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  virtualisation.virtualbox.guest.enable = true;
}
