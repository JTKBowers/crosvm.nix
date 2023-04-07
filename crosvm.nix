{
  config,
  modulesPath,
  ...
}: {
  imports = [
    # "${toString modulesPath}/installer/cd-dvd/iso-image.nix"
    ./crosvmModule.nix
  ];

  # crosvm.kernelPath = "${config.system.build.toplevel}";
  boot.loader.grub.enable = false;
  fileSystems = {
    "/" = {
      fsType = "tmpfs";
      options = ["mode=0755"];
    };
    "/nix" = {
      device = "/dev/root";
      fsType = "squashfs";
    };
  };

  boot.initrd.kernelModules = [
    "squashfs"
    "virtio_blk"
    # "virtio_pmem"
    "virtio_console"
    "virtio_pci"
    "virtio_mmio"
  ];
}
