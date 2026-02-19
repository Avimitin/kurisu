{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kurisu.os.graphic;
in
{
  imports = [ ];

  config = lib.mkIf (cfg.enable && cfg.platform == "intel") {
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };

    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    services.xserver.videoDrivers = [ "modesetting" ];
  };
}
