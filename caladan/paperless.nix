{ pkgs, lib, domain, ... }:
let
  scanbdConf = pkgs.writeText "scanbd.conf" ''
    global {
      debug = true
      # debug-level = 7
      user = paperless
      group = paperless
      scriptdir = /etc/scanbd/scripts
      pidfile = /var/run/scanbd.pid
      timeout = 500
      environment {
        device = "SCANBD_DEVICE"
        action = "SCANBD_ACTION"
      }

      multiple_actions = false
      action scan {
        filter = "^monitor-button$"
        numerical-trigger {
          from-value = 1
          to-value = 0
        }
        desc = "Scan to file"
        script = "scan.script"
      }
    }
  '';

  scanScript = pkgs.writeScript "scanbd_scan.script" ''
    #!${pkgs.bash}/bin/bash
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.sane-backends ]}
    date="$(date -Iseconds)"
    dir="$(mktemp -d)"
    file="$dir/Scan $date.pdf"

    export SANE_CONFIG_DIR=/etc/sane-config
    export LD_LIBRARY_PATH=/etc/sane-libs

    echo "Scanning $file"
    scanimage -d "$SCANBD_DEVICE" --resolution 400 --scan-area A4 -o "$file" --format pdf
    chown paperless:paperless "$file"
    mv "$file" "/data/paperless/consume/"
    rm -d $dir
  '';
in {
  ingress.paperless = {
    subdomain = "paperless";
    port = 28981;
  };

  services.paperless = {
    enable = true;
    dataDir = "/data/paperless/data";
    mediaDir = "/data/paperless/media";
    consumptionDir = "/data/paperless/consume";
    passwordFile = "/run/secrets/paperlessPassword";
    address = "0.0.0.0";
    settings = {
      PAPERLESS_URL = "https://paperless.caladan.${domain}";
      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      PAPERLESS_SOCIAL_AUTO_SIGNUP = "True";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_ACCOUNT_DEFAULT_HTTP_PROTOCOL = "https";
    };
  };

  services.borgbackup.jobs.paperless = import ../backup.nix domain "caladan" "paperless" {
    paths = [
      "/data/paperless/data"
      "/data/paperless/media"
    ];
  };

  services.udev.extraRules = ''
    ENV{ID_VENDOR_ID}=="04b8", ENV{ID_MODEL_ID}=="0130", GROUP="paperless", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/sys/devices/virtual/misc/perfection_v500", ENV{SYSTEMD_WANTS}+="scanbd.service"
  '';

  systemd.services.paperless-scheduler.serviceConfig.EnvironmentFile = "/run/secrets/paperless";
  systemd.services.paperless-task-queue.serviceConfig.EnvironmentFile = "/run/secrets/paperless";
  systemd.services.paperless-consumer.serviceConfig.EnvironmentFile = "/run/secrets/paperless";
  systemd.services.paperless-web.serviceConfig.EnvironmentFile = "/run/secrets/paperless";

  environment.etc = {
    "scanbd/scanbd.conf".source = scanbdConf;
    "scanbd/scripts/scan.script".source = scanScript;
    "scanbd/scripts/test.script".source = "${pkgs.scanbd}/etc/scanbd/test.script";
    "scanbd/sane.d/dll.conf".text = "epkowa";
    "scanbd/sane.d/epkowa.conf".source = "${pkgs.epkowa}/etc/sane.d/epkowa.conf";
  };

  systemd.services.scanbd = {
    description = "Scanner button polling service";
    after = [ "sys-devices-virtual-misc-perfection_v500.device" ];
    bindsTo = [ "sys-devices-virtual-misc-perfection_v500.device" ];
    environment = {
      SANE_CONFIG_DIR = "/etc/sane-config";
      LD_LIBRARY_PATH = "/etc/sane-libs";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.scanbd}/bin/scanbd -c /etc/scanbd/scanbd.conf -f";
    };
  };

  networking.firewall.interfaces.wt0.allowedTCPPorts = [ 28981 ];

  nixpkgs.config.allowlistedLicenses = with lib.licenses; [ epson ];
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.epkowa ];
    disabledDefaultBackends = [
      "net" "abaton" "agfafocus" "apple" "artec" "artec_eplus48u"
      "as6e" "avision" "bh" "canon" "canon630u" "canon_dr"
      "canon_lide70" "cardscan" "coolscan" "coolscan3"
      "dell1600n_net" "dmc" "epjitsu" "epson2" "epsonds"
      "escl" "fujitsu" "genesys" "gt68xx" "hp" "hp3500"
      "hp3900" "hp4200" "hp5400" "hp5590" "hpljm1005" "hpsj5s"
      "hs2p" "ibm" "kodak" "kodakaio"
      "kvs1025" "kvs20xx" "kvs40xx" "leo"
      "lexmark" "ma1509" "magicolor" "matsushita" "microtek"
      "microtek2" "mustek" "mustek_usb" "mustek_usb2" "nec"
      "niash" "pie" "pieusb" "pint" "pixma" "plustek"
      "qcam" "ricoh" "ricoh2" "rts8891" "s9036"
      "sceptre" "sharp" "sm3600" "sm3840" "snapscan"
      "sp15c" "tamarack" "teco1" "teco2" "teco3"
      "u12" "umax" "umax1220u" "v4l" "xerox_mfp"
    ];
  };

  sops.secrets.paperlessPassword.owner = "paperless";
  sops.secrets.paperless = {};

  services.samba.shares.paperless = {
    path = "/data/paperless";
    browseable = "yes";
    "read only" = "no";
    "guest ok" = "no";
    "directory mask" = "0755";
    "create mask" = "0644";
    "force user" = "paperless";
    "force group" = "paperless";
  };
}
