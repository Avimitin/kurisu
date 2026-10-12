{ ... }:
{
  # Declarative fresh-install layout. Applying disko's disko mode ERASES this
  # SSD; an ordinary nixos-rebuild does not repartition it.
  disko.devices.disk.system = {
    type = "disk";
    device = "/dev/disk/by-id/ata-SAMSUNG_MZNTE128HMGR-00000_S1EBNYAFB06206";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
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
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
