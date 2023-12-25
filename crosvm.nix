{
  config,
  modulesPath,
  ...
}: {
  imports = [
    ./crosvmModule.nix
  ];

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

  networking.dhcpcd.enable = false;
  documentation.man.enable = false;
  documentation.nixos.enable = false;
  environment.defaultPackages = [];

  boot.initrd.kernelModules = [
    "squashfs"
    "virtio_blk"
    # "virtio_pmem"
    "virtio_console"
    "virtio_pci"
    "virtio_mmio"
  ];
}
