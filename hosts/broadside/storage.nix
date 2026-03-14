{
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "b0425eed";

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  systemd.tmpfiles.rules = [
    "d /srv/recovery 0755 root root -"
    "d /srv/recovery/appdata 0755 root root -"
    "d /srv/recovery/appdata/caddy 0755 root root -"
    "d /srv/recovery/appdata/step-ca 0750 root root -"
    "d /srv/recovery/backups 0755 root root -"
    "d /srv/recovery/backups/step-ca 0750 root root -"
    "d /srv/recovery/mirror 0755 root root -"
    "d /srv/recovery/mirror/repos 0755 root root -"
    "d /srv/recovery/mirror/snapshots 0755 root root -"
    "d /srv/recovery/pxe 0755 root root -"
  ];
}
