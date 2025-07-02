{ config, lib, pkgs, ... }:

{

  options = {
    # Define any custom options here if needed.
  };

  config = {
    boot.kernelParams = [ "nvidia_drm.fbdev=1" "nvidia-drm.modeset=1" "module_blacklist=i915" ];
    boot.initrd.kernelModules = [ "nvidia" "i915" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    hardware.graphics = {
      enable = true;
      # driSupport = true;
      # driSupport32Bit = true;
    };

    environment.systemPackages = with pkgs; [
      libva-utils
      vdpauinfo
      vulkan-tools
      vulkan-validation-layers
      libvdpau-va-gl
      egl-wayland
      wgpu-utils
      mesa
      libglvnd
      #  nvtop
      nvitop
      libGL
    ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # prime = {
      #   nvidiaBusId = "PCI:1:0";
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
