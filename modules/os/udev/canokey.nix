{ lib, config, ... }:
let
  cfg = config.kurisu.os.canokey;
in
{
  imports = [ ];

  options.kurisu.os.canokey = {
    enableRootlessAccess = lib.mkEnableOption "allow users without root privileges to use Canokey";

    accessGroup = lib.mkOption {
      type = lib.types.str;
      default = "plugdev";
      example = "plugdev";
      description = "Allow user to access Canokey when they are in the group";
    };
  };

  # All FIDO2 SSH key is harden with `-O verify-required` when generate key
  # using ssh-keygen Thus the ssh agent have nothing to do with caching key,
  # password is always required at signing and identify.
  config = lib.mkIf cfg.enableRootlessAccess {
    programs.ssh.startAgent = false;

    users.groups.${cfg.accessGroup} = { };

    services.udev.extraRules = ''
      # GnuPG/pcsclite
      SUBSYSTEM!="usb", GOTO="canokeys_rules_end"
      ACTION!="add|change", GOTO="canokeys_rules_end"
      ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="42d4", ENV{ID_SMARTCARD_READER}="1"
      LABEL="canokeys_rules_end"

      # FIDO2
      # note that if you find this line in 70-fido.rules, you can ignore it
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="42d4", TAG+="uaccess", GROUP="plugdev", MODE="0660"

      # make this usb device accessible for users, used in WebUSB
      # note if you use "plugdev", make sure you have this group and the wanted user is in that group
      SUBSYSTEMS=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="42d4", GROUP="${cfg.accessGroup}", MODE="0660"
      #SUBSYSTEMS=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="42d4", TAG+="uaccess"
    '';
  };
}
