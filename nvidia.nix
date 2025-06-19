{ config, lib, pkgs, ... }:

{

  options = {
    # Define any custom options here if needed.
  };

  config = {
    boot.kernelParams = [ "nvidia_drm.fbdev=1" "nvidia-drm.modeset=1" "module_blacklist=i915" ];

    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
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
      nvtop
      nvitop
      libGL
    ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      forceFullCompositionPipeline = true;
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };
  };
}
