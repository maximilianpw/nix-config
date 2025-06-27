{
  config,
  lib,
  ...
}: {
  # NVIDIA graphics configuration for hybrid systems

  # Enable OpenGL with NVIDIA support
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Use NVIDIA drivers
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Use stable drivers instead of beta for better reliability
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Enable persistence daemon for better performance
    nvidiaPersistenced = true;

    # Required for modern systems
    modesetting.enable = true;

    # Power management settings
    powerManagement = {
      enable = lib.mkDefault false; # Can cause issues, enable only if needed
      finegrained = lib.mkDefault false; # Experimental feature
    };

    # NVIDIA Settings application
    nvidiaSettings = true;

    # Prime configuration for hybrid graphics (AMD + NVIDIA)
    prime = {
      # Use offload mode for better battery life
      offload = {
        enable = true;
        enableOffloadCmd = true; # Provides nvidia-offload command
      };

      # Bus IDs - verify these with lspci
      amdgpuBusId = "PCI:8:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # NVIDIA-specific environment variables
  environment.variables = {
    # Force NVIDIA for specific applications if needed
    # __NV_PRIME_RENDER_OFFLOAD = "1";
    # __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };
}
