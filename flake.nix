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
          vmImage = nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            customFormats = {"crosvm" = import ./crosvmFormat.nix;};
            format = "crosvm";
            modules = [./configuration.nix];
          };

          stdenv = pkgs.stdenv;

          run-vm = stdenv.mkDerivation {
            name = "run-vm";

            buildInputs = with pkgs; [p7zip];

            unpackPhase = "true";

            installPhase = ''
              mkdir -p "$out/bin"
              echo "#! ${stdenv.shell}" >> "$out/bin/run-vm"
              echo "exec ${pkgs.crosvm}/bin/crosvm run -b "${vmImage}/root.squashfs,root,ro" --initrd ${vmImage}/initrd ${vmImage}/bzImage" -p "boot.shell_on_fail" -p "init=$(cat ${vmImage}/init)" >> "$out/bin/run-vm"
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
