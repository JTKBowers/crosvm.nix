{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-bubblewrap = {
      url = "github:JTKBowers/nix-bubblewrap";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };
  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    flake-utils,
    nix-bubblewrap,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        wrapPackage = nix-bubblewrap.lib.wrapPackage pkgs;
      in {
        packages = rec {
          iso = nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            format = "iso";
            modules = [./configuration.nix];
          };

          stdenv = pkgs.stdenv;

          run-vm = stdenv.mkDerivation {
            name = "run-vm";

            buildInputs = with pkgs; [p7zip];

            unpackPhase = "true";

            installPhase = ''
              mkdir -p "$out/data"
              mkdir -p "/tmp/iso"
              7z x ${iso}/iso/nixos.iso -o/tmp/iso
              mv /tmp/iso/boot/bzImage $out/data/
              mv /tmp/iso/boot/initrd $out/data/
              init=$(grep -Po '(?<=linux\ /boot/bzImage\ \$\{isoboot\} init=/nix/store/)[^ ]*' -m 1 /tmp/iso/EFI/boot/grub.cfg) # Read the path to the stage 2 init - it is a store path so it changes with each build.

              mkdir -p "$out/bin"
              echo "#! ${stdenv.shell}" >> "$out/bin/run-vm"
              echo "exec ${pkgs.crosvm}/bin/crosvm run -b "${iso}/iso/nixos.iso,root,ro" --initrd $out/data/initrd $out/data/bzImage" -p "init=nix/store/$init" -p "boot.shell_on_fail" >> "$out/bin/run-vm"
              chmod 0755 "$out/bin/run-vm"
            '';
          };

          default = wrapPackage {
            name = "run-vm";
            pkg = run-vm;
            extraArgs = [
              "--dev /dev"
              "--dev-bind /dev/kvm /dev/kvm"
              "--proc /proc"
              "--tmpfs /var/empty"
            ];
          };
        };
      }
    );
}
