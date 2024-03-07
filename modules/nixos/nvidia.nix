{config, ...}: {
  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
  #Nvidia settings for hybrid graphics(AMD video cores and Nvidia)

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    #powerManagement = {
    #enabled = true;
    #finegrained = true; #maybe comment this out idk what it does
    #};

    #uses beta drivers
    package = config.boot.kernelPackages.nvidiaPackages.beta;

    #Fixes a glitch
    nvidiaPersistenced = true;
    #Required for amdgpu and nvidia gpu pairings
    modesetting.enable = true;
    prime = {
      offload.enable = true;
      #sync.enable = true;

      amdgpuBusId = "PCI:8:0:0";

      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
