{ config, pkgs, domain, ... }:
let
  name = "wlp41s0f4u1";
  name2G = "wlp41s0f3u4";

  commonRadioSettings = {
    countryCode = "GB";
    wifi4.capabilities = [
      "LDPC"
      "HT40+"
      "HT40-"
      "GF"
      "SHORT-GI-20"
      "SHORT-GI-40"
      "TX-STBC"
      "RX-STBC1"
    ];
  };
in {
  networking.useNetworkd = true;

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.all.use_tempaddr" = 0;

    "net.ipv6.conf.ppp0.accept_ra" = 2;
    "net.ipv6.conf.ppp0.autoconf" = 1;
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [ "br0" ];
    externalInterface = "ppp0";
  };

  networking.firewall = {
    allowedUDPPorts = [ 67 68 546 ];
    extraCommands = ''
      iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS  --clamp-mss-to-pmtu
    '';
  };

  # WAN connection
  services.pppd = {
    enable = true;
    peers.BT.config = ''
      plugin pppoe.so

      # network interface
      enp39s0

      +ipv6 ipv6cp-use-ipaddr

      # login name
      name "bthomehub@btbroadband.com"
      password "BT"
      persist
      defaultroute
      noauth
    '';
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    netdevs.br0 = {
      enable = true;
      netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };
    };

    networks."50-lan" = {
      enable = true;

      matchConfig.Name = "enp37s0";
      networkConfig.Bridge = "br0";
    };

    networks."80-bridge" = {
      enable = true;

      matchConfig.Name = "br0";
      networkConfig = {
        Address = "192.168.0.1/24";
        DHCPServer = true;
        #IPMasquerade = "both";
        /*IPv6SendRA = true;
        DHCPv6PrefixDelegation = true;
        IPv6PrivacyExtensions = true;*/
      };

      dhcpServerConfig = {
        PoolOffset = 50;
        PoolSize = 100;
        EmitDNS = true;
        DNS = [ "192.168.0.1" ];
      };
    };
  };

  sops.secrets.wlan = {};

  services.hostapd = {
    enable = true;

    radios = {
      ${name} = commonRadioSettings // {
        band = "5g";
        channel = 36;

        wifi5.capabilities = [
          "RXLDPC"
          "SHORT-GI-80"
          "RX-ANTENNA-PATTERN"
          "TX-ANTENNA-PATTERN"
        ];

        networks.${name} = {
          settings.bridge = "br0";
          ssid = "THE_PENGUIN";
          authentication = {
            saePasswordsFile = config.sops.secrets.wlan.path;
            wpaPasswordFile = config.sops.secrets.wlan.path;
            mode = "wpa3-sae-transition";
          };
        };
      };

      ${name2G} = commonRadioSettings // {
        band = "2g";
        channel = 7;
        networks.${name2G} = {
          settings.bridge = "br0";
          ssid = "THE_PENGUIN";
          authentication = {
            saePasswordsFile = config.sops.secrets.wlan.path;
            wpaPasswordFile = config.sops.secrets.wlan.path;
            mode = "wpa3-sae-transition";
          };
        };
      };
    };
  };
}
