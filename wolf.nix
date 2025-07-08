{
  ...
}:
{
  systemd.services.wolf-gamestreaming = {
    description = "Podman Wolf Gamestreaming";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      TimeoutStartSec = "900";
      # Restart = "on-failure";
      Restart = "no";
      RestartSec = "5";
      StartLimitBurst = 5;

      # Pre-start commands to make directories (ignore failure)
      ExecStartPre = ''
        /run/current-system/sw/bin/mkdir -p /tmp/sockets
      '';

      # Run the podman container with all the relevant args
      ExecStart = ''
        /run/current-system/sw/bin/podman run --rm --name wolf \
          --hostname wolf \
          --cap-add=SYS_PTRACE \
          --cap-add=NET_ADMIN \
          --network host \
          --security-opt label=disable \
          --ipc=host \
          --device-cgroup-rule "c 13:* rmw" \
          --device /dev/dri \
          --device /dev/uinput \
          -e WOLF_STOP_CONTAINER_ON_EXIT=TRUE \
          -e WOLF_LOG_LEVEL=DEBUG \
          -e WOLF_RENDER_NODE=/dev/dri/renderD128 \
          -e WOLF_APPS_STATE_FOLDER=/etc/wolf \
          -e GST_DEBUG=2 \
          -v /dev/input:/dev/input:ro \
          -v /run/udev:/run/udev:ro \
          -v /etc/wolf:/etc/wolf:rw \
          -v /tmp/sockets:/tmp/sockets:rw \
          -v /run/podman/podman.sock:/var/run/docker.sock:ro \
          ghcr.io/games-on-whales/wolf:stable
      '';

      ExecStop = "/run/current-system/sw/bin/podman rm --force wolf";
    };

    wantedBy = [ "multi-user.target" ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      47984
      47989
      48010
    ];
    allowedUDPPorts = [
      47999
      48000
      48010
      48100
      48200
    ];
  };
}
