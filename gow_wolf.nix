{
  config,
  lib,
  pkgs,
  ...
}:

let
  # An object containing user configuration (in /etc/nixos/configuration.nix)
  cfg = config.extraServices.gow_wolf;
in
{
  # Create the main option to toggle the service state
  options.extraServices.gow_wolf = {
    enable = lib.mkEnableOption "gow_wolf";

    # Other options to go here
    gpu_type = lib.mkOption {
      type = lib.types.enum [
        "amd"
        "nvidia"
        "software"
      ];
      default = "nvidia";
      example = "nvidia";
      description = "Which GPU backend to use.";
    };
  };

  # Everything that should be done when/if the service is enabled
  config = lib.mkIf cfg.enable (
    let
      # The docker-compose.yml file (as a JSON)
      wolfDevices =
        if cfg.gpu_type == "amd" then
          [
            "/dev/dri"
          ]
        else if cfg.gpu_type == "nvidia" then
          [
            "/dev/dri"
            "/dev/nvidia-uvm"
            "/dev/nvidia-uvm-tools"
            "/dev/nvidia-caps/nvidia-cap1"
            "/dev/nvidia-caps/nvidia-cap2"
            "/dev/nvidiactl"
            "/dev/nvidia0"
            "/dev/nvidia-modeset"
          ]
        else
          [ ];

      wolfEnvironment =
        if cfg.gpu_type == "software" then
          [
            "WOLF_RENDER_NODE=software"
          ]
        else if cfg.gpu_type == "nvidia" then
          [
            "NVIDIA_DRIVER_VOLUME_NAME=nvidia-driver-vol"
          ]
        else
          [ ];

      wolfVolumes =
        if cfg.gpu_type == "nvidia" then
          [
            "nvidia-driver-vol:/usr/nvidia:rw"
          ]
        else
          [ ];

      nvidiaVolume =
        if cfg.gpu_type == "nvidia" then
          {
            volumes = {
              nvidia-driver-vol = {
                external = true;
              };
            };
          }
        else
          { };

      dockerComposeConfig = {
        services.wolf = {
          image = "ghcr.io/games-on-whales/wolf:stable";
          environment = wolfEnvironment ++ [
            "XDG_RUNTIME_DIR=/tmp/sockets"
            "HOST_APPS_STATE_FOLDER=/etc/wolf"
          ];
          volumes = wolfVolumes ++ [
            "/etc/wolf/:/etc/wolf"
            "/tmp/sockets:/tmp/sockets:rw"
            "/var/run/docker.sock:/var/run/docker.sock:rw"
            "/dev/:/dev/:rw"
            "/run/udev:/run/udev:rw"
          ];
          device_cgroup_rules = [ "c 13:* rmw" ];
          devices = wolfDevices ++ [
            "/dev/uinput"
            "/dev/uhid"
          ];
          network_mode = "host";
          restart = "unless-stopped";
          # restart = "no";
        };
        # builtins.trace nvidiaVolume;
        # volumes.nvidia-driver-vol = {
        #   external = true;
        # };
      }
      // nvidiaVolume;
    in
    {
      #######################################################
      # GOW - Wolf Setup
      #######################################################
      # Required packages
      environment.systemPackages = with pkgs; [
        docker
        docker-compose
        moonlight-qt
      ];

      # Open selected port in the firewall.
      # We can reference the port that the user configured.
      networking.firewall = {
        allowedTCPPorts = [
          # Wolf - Game streaming
          47984 # Wolf - https
          47989 # Wolf - http
          48010 # Wolf - rtsp
        ];
        allowedUDPPorts = [
          # Wolf - Game streaming
          47998
          47999 # Wolf - Control
          48000
          48100
          48200
        ];
      };

      # Enable Docker
      virtualisation.docker.enable = true;

      # Enable PulseAudio
      # sound.enable = true;
      services.pulseaudio.enable = true;
      services.pulseaudio.support32Bit = true;

      # Extra groups (not entirely sure this is needed)
      # users.groups.ops.gid = 1000;
      # users.extraUsers.ops.extraGroups = [
      #   "audio"
      #   "ops"
      # ];

      # Create the necessary directories
      systemd.tmpfiles.rules = [
        "d /etc/wolf 0755 root root"
        "d /tmp/sockets 0755 root root"
        "d /ROMs 0755 ops users"
      ];

      virtualisation.docker.daemon.settings = {
        data-root = "/docker/daemon";
      };

      environment.etc."wolf/docker-compose.yml".text = builtins.toJSON dockerComposeConfig;

      # Build out the nvidia-driver-vol if gpu is nvidia
      systemd.services.nvidiaDriverVolumeSetup = lib.mkIf (cfg.gpu_type == "nvidia") {
        description = "One-time NVIDIA driver Docker volume builder for GOW";
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "build-nvidia-volume and nvidia-caps" ''
            set -euo pipefail
            export PATH=$PATH:/run/current-system/sw/bin

            MARKER=/etc/wolf/.nvidia-driver-vol-ready
            NVIDIA_CAPS=/dev/nvidia-caps
            if [ ! -d "$NVIDIA_CAPS" ]; then
              echo "Building NVIDIA-CAPS"
                nvidia-container-cli --load-kmods info
            fi

            if [ ! -f "$MARKER" ]; then
              echo "Building NVIDIA driver volume - Started"
              ${pkgs.curl}/bin/curl https://raw.githubusercontent.com/games-on-whales/gow/master/images/nvidia-driver/Dockerfile \
                | ${pkgs.docker}/bin/docker build -t gow/nvidia-driver:latest -f - --build-arg NV_VERSION=$(cat /sys/module/nvidia/version) .
              ${pkgs.docker}/bin/docker create --rm --mount source=nvidia-driver-vol,destination=/usr/nvidia gow/nvidia-driver:latest sh

              echo "Building NVIDIA driver volume - Finished"
              touch "$MARKER"
            fi
          '';
        };

        # Ensure it runs after Docker is ready
        after = [ "docker.service" ];
        before = [ "wolf.service" ];
        requires = [ "docker.service" ];
      };

      # Ensure the wolf service is started via docker-compose
      systemd.services.wolf = {
        description = "Wolf Docker Compose Service";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f /etc/wolf/docker-compose.yml up";
          ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f /etc/wolf/docker-compose.yml down";
          Restart = "on-failure"; # Usually
          # Restart = "no"; # While debugging
          WorkingDirectory = "/etc/wolf";
        };

        # Make sure we don't start it until docker is up (and nvidia volume setup)
        after = [
          "docker.service"
        ]
        ++ lib.optional (cfg.gpu_type == "nvidia") "nvidiaDriverVolumeSetup.service";
        requires = [
          "docker.service"
        ]
        ++ lib.optional (cfg.gpu_type == "nvidia") "nvidiaDriverVolumeSetup.service";
      };
    }
  );
}
