{
  disko.devices = {
    disk.os = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-XPG_GAMMIX_S7_2L4529116HT7";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            name = "ESP";
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          root = {
            name = "root";
            size = "150G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };

          docker = {
            name = "docker";
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib/docker";
            };
          };
        };
      };
    };

    disk.recovery-a = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_C1D3079C060900487976";
      content = {
        type = "gpt";
        partitions.recovery = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "recovery";
          };
        };
      };
    };

    disk.recovery-b = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-MSI_M450_1TB_511230613094007997";
      content = {
        type = "gpt";
        partitions.recovery = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "recovery";
          };
        };
      };
    };

    disk.recovery-c = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SanDisk_Ultra_3D_NVMe_21283F802986";
      content = {
        type = "gpt";
        partitions.recovery = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "recovery";
          };
        };
      };
    };

    disk.recovery-d = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SanDisk_Ultra_3D_NVMe_21283G802405";
      content = {
        type = "gpt";
        partitions.recovery = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "recovery";
          };
        };
      };
    };

    zpool.recovery = {
      type = "zpool";
      mode = "raidz2";
      options = {
        ashift = "12";
        autotrim = "on";
      };
      rootFsOptions = {
        acltype = "posixacl";
        atime = "off";
        compression = "zstd";
        mountpoint = "none";
        xattr = "sa";
      };
      datasets = {
        appdata = {
          type = "zfs_fs";
          mountpoint = "/srv/recovery/appdata";
        };
        "appdata/caddy" = {
          type = "zfs_fs";
          mountpoint = "/srv/recovery/appdata/caddy";
        };
        "appdata/step-ca" = {
          type = "zfs_fs";
          mountpoint = "/srv/recovery/appdata/step-ca";
        };
        backups = {
          type = "zfs_fs";
          mountpoint = "/srv/recovery/backups";
        };
        "backups/step-ca" = {
          type = "zfs_fs";
          mountpoint = "/srv/recovery/backups/step-ca";
        };
        mirror = {
          type = "zfs_fs";
          mountpoint = "/srv/recovery/mirror";
        };
        pxe = {
          type = "zfs_fs";
          mountpoint = "/srv/recovery/pxe";
        };
      };
    };
  };
}
