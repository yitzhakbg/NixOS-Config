{
  config,
  lib,
  pkgs,
  ...
}:

{

  options = {
    # Define any custom options here if needed.
  };

  config = {
    boot.kernelParams = [
      "nvidia_drm.fbdev=1"
      "nvidia-drm.modeset=1"
      "module_blacklist=i915"
    ];
    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ];

    hardware.graphics = {
      enable = true;
      # driSupport = true;
      # driSupport32Bit = true;
    };

    environment.variables = {
      GBM_BACKEND = "nvidia-drm";
      #__GLX_VENDOR_LIBRARY_NAME = "nvidia";
      MOZ_DISABLE_RDD_SANDBOX = "1";
      LIBVA_DRIVER_NAME = "nvidia";
      #NIXOS_OZONE_WL= "1";
      WLR_NO_HARDWARE_CURSORS = "1";
      #MOZ_ENABLE_WAYLAND = "1";
      NVD_BACKEND = "direct";
      #XDG_SESSION_TYPE = "wayland";
    };
    # nixGL.vulkan.enable = true;
    environment.systemPackages = with pkgs; [
      libva-utils
      vdpauinfo
      vulkan-tools
      vulkan-validation-layers
      libvdpau-va-gl
      # egl-wayland
      wgpu-utils
      mesa
      libglvnd
      #  nvtop
      nvitop
      libGL
      libnvidia-container
    ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # prime = {
      #   nvidiaBusId = "PCI:1:0:0";
      #   offload = {
      #     enable = true;
      #     enableOffloadCmd = true;
      #   };
      # };
      forceFullCompositionPipeline = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };
  };
}
