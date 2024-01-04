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
    {
      nixosModules = {
        baseSystem = ./crosvm.nix;

        exampleConfiguration = ./configuration.nix;

        default = self.outputs.nixosModules.baseSystem;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        wrapPackage = nix-bubblewrap.lib.wrapPackage pkgs;

        buildImage = configuration:
          nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            customFormats = {"crosvm" = import ./crosvmFormat.nix;};
            format = "crosvm";
            modules = [configuration];
          };

        crosvm = {
          vmImage,
          vmmConfig,
          sharedDirs,
        }:
          wrapPackage {
            name = "crosvm";
            pkg = pkgs.crosvm;

            shareNet = true;

            extraBindPaths =
              builtins.map
              (sharedDir: {
                path = builtins.head (builtins.match "^([^\0\:]+):.*" sharedDir);
                mode = "rw";
              })
              sharedDirs;

            extraDepPkgs = [
              vmImage
              vmmConfig
            ];
            extraArgs = [
              "--dev /dev"
              "--dev-bind /dev/kvm /dev/kvm"
              "--dev-bind /dev/net/ /dev/net/"
              "--proc /proc"
              "--tmpfs /var/empty"
            ];
          };

        run-vm = {
          configuration,
          vmmConfig ? {}, # See https://crosvm.dev/book/running_crosvm/options.html#configuration-files
          sharedDirs ? [], # See https://crosvm.dev/book/devices/fs.html
        }: let
          vmImage = buildImage configuration;
          vmmConfigJson = (pkgs.formats.json {}).generate "vmConfig.json" vmmConfig;
          crosvmPackage = crosvm {
            vmImage = vmImage;
            vmmConfig = vmmConfigJson;
            sharedDirs = sharedDirs;
          };
          sharedDirArgs = builtins.concatStringsSep " " (map (dir: "--shared-dir ${dir}") sharedDirs);
        in
          pkgs.writeShellScriptBin "run-vm"
          ''
            exec ${crosvmPackage}/bin/crosvm run \
                --cfg ${vmmConfigJson} \
                ${sharedDirArgs} \
                -b "${vmImage}/root.squashfs,root,ro" \
                --initrd ${vmImage}/initrd \
                ${vmImage}/bzImage \
                -p "boot.shell_on_fail" \
                -p "init=$(cat ${vmImage}/init)"
          '';
      in {
        packages = {
          run-vm = run-vm;
          default = run-vm {
            configuration = self.outputs.nixosModules.exampleConfiguration;
            vmmConfig = {
              mem = {
                size = 2048;
              };
            };
          };
        };
      }
    );
}
