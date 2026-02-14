{
  lib,
  config,
  ...
}:
let
  parts = config.kurisu.partitions;
  cfg = config.kurisu.partitions.zfs-single-root;
in
{
  imports = [ ];

  options.kurisu.partitions.zfs-single-root = {
    diskName = lib.mkOption {
      type = lib.types.str;
      example = "/dev/nvme0n1";
      description = "The main disk for zfs to do partition";
    };
  };

  config = lib.mkIf (parts.enable && parts.profile == "zfs-single-root") {
    kurisu.partitions.devices = {
      disk = {
        main = {
          type = "disk";
          device = cfg.diskName;
          content = {
            type = "gpt";
            partitions = {
              esp = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              swap = {
                size = "16G";
                content = {
                  type = "swap";
                  resumeDevice = true;
                };
              };
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "zroot";
                };
              };
            };
          };
        };
      };

      zpool = {
        zroot = {
          type = "zpool";
          rootFsOptions = {
            mountpoint = "none";
            compression = "zstd";
            xattr = "sa";
            acltype = "posixacl";
            normalization = "formD";
            atime = "off";
          };

          options.ashift = 12;

          datasets = {
            "root" = {
              type = "zfs_fs";
              mountpoint = "/";
            };

            "root/nix" = {
              type = "zfs_fs";
              options = {
                mountpoint = "/nix";
                "com.sun:auto-snapshot" = "false";
              };
              mountpoint = "/nix";
            };

            # Mozart's Sonata No.11
            "root/sonata" = {
              type = "zfs_fs";
              options = {
                encryption = "aes-256-gcm";
                keyformat = "passphrase";
                keylocation = "prompt";
              };
              mountpoint = "/sonata";
            };
          };
        };
      };
    };
  };
}
