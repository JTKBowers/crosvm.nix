{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    nixos-generators,
    flake-utils,
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

        buildImage = {
          configuration,
          specialArgs ? {},
        }:
          nixos-generators.nixosGenerate {
            system = "x86_64-linux";
            customFormats = {"crosvm" = import ./crosvmFormat.nix;};
            format = "crosvm";
            modules = [configuration];
            inherit specialArgs;
          };

        run-vm = {
          crosvmPackage ? pkgs.crosvm,
          configuration,
          vmmConfig ? {}, # See https://crosvm.dev/book/running_crosvm/options.html#configuration-files
          sharedDirs ? [], # See https://crosvm.dev/book/devices/fs.html
          extraArguments ? [],
          specialArgs ? {},
        }: let
          vmImage = buildImage {inherit configuration specialArgs;};
          vmmConfigJson = (pkgs.formats.json {}).generate "vmConfig.json" vmmConfig;
          sharedDirArgs = map (dir: "--shared-dir ${dir}") sharedDirs;
          extraArguments' = builtins.concatStringsSep " " (extraArguments ++ sharedDirArgs);
        in
          pkgs.writeShellScriptBin "run-vm"
          ''
            exec ${crosvmPackage}/bin/crosvm run \
                --cfg ${vmmConfigJson} \
                -b "${vmImage}/root.squashfs,root,ro" \
                ${extraArguments'} \
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
