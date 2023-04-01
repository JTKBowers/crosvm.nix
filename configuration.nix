{
  config,
  pkgs,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = "23.05";

  boot.initrd.kernelModules = [
    "virtio_blk"
    # "virtio_pmem"
    "virtio_console"
    "virtio_pci"
    "virtio_mmio"
  ];
}
