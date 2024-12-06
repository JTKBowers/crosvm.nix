{
  config,
  lib,
  pkgs,
  ...
}: let
  closureInfo = pkgs.closureInfo {
    rootPaths = [config.system.build.toplevel];
  };
  root = pkgs.stdenvNoCC.mkDerivation {
    binPath = with pkgs;
      lib.makeBinPath (
        [
          nix
          pkgs.squashfsTools
        ]
        ++ stdenv.initialPath
      );
    name = "root.squashfs";

    nativeBuildInputs = [pkgs.squashfsTools];

    unpackPhase = "true";
    dontFixup = true;
    installPhase = ''
      export PATH=$binPath

      root="$PWD/root"
      mkdir -p $root

      # Provide a Nix database
      export NIX_STATE_DIR=$TMPDIR/state
      nix-store --load-db < ${closureInfo}/registration

      nix-env --store "$PWD/root" --substituters "" \
        --extra-substituters "auto?trusted=1" \
        -p "$PWD"/root/nix/var/nix/profiles/system --set ${config.system.build.toplevel}

      # Build it into a squashfs image
      mksquashfs $root/nix/* $out \
        -no-hardlinks -keep-as-directory -all-root -b 1048576 -comp xz -Xdict-size 100% \
        -processors $NIX_BUILD_CORES
    '';
  };
in {
  config = {
    system.build.crosvmImage = pkgs.stdenvNoCC.mkDerivation {
      name = "crosvmImage";

      unpackPhase = "true";
      dontFixup = true;
      installPhase = ''
        mkdir -p $out
        ln -s '${config.system.build.toplevel}/kernel' $out/bzImage
        ln -s '${config.system.build.toplevel}/initrd' $out/initrd
        echo '${config.system.build.toplevel}/init' > $out/init
        ln -s '${config.system.build.toplevel}/kernel-params' $out/kernel-params
        ln -s '${root}' $out/root.squashfs
      '';
    };
  };
}
